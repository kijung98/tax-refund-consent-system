-- ============================================================
-- 국세환급금 동의서 업무보조 시스템 - DB 스키마 (Supabase/Postgres)
-- ============================================================
-- 사용법: Supabase 대시보드 > SQL Editor 에서 이 파일 전체를 붙여넣고 실행
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1. submissions (접수 단위 - 모든 서식의 공통 부모 테이블)
-- ------------------------------------------------------------
create table if not exists submissions (
  id uuid primary key default gen_random_uuid(),
  reception_number text unique not null,
  status text not null default '신규', -- 신규 / 확인중 / 확인완료 / 출력완료 / 처리완료
  staff_name text,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. 접수번호 자동 생성 (당일 기준 3자리 일련번호, 예: 202609190001 -> 여기선 7자리: YYYYMMDD + 3자리)
-- ------------------------------------------------------------
create table if not exists reception_counter (
  date_key text primary key,
  counter integer not null default 0
);

create or replace function generate_reception_number()
returns text as $$
declare
  today text := to_char(now(), 'YYYYMMDD');
  next_no integer;
begin
  insert into reception_counter(date_key, counter)
  values (today, 1)
  on conflict (date_key)
  do update set counter = reception_counter.counter + 1
  returning counter into next_no;

  return today || lpad(next_no::text, 3, '0'); -- 예: 20260919001
end;
$$ language plpgsql;

-- ------------------------------------------------------------
-- 3. FORM B - 종합부동산세 공동명의 1주택자 특례(변경)신청서
--    (종합부동산세법 시행규칙 별지 제2호의7서식) - 이번 업무의 핵심 서식
-- ------------------------------------------------------------
create table if not exists form_b_joint_home (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references submissions(id) on delete cascade,

  -- 신청인(= 원칙적으로 지분율이 높거나 같은 배우자, 즉 아래 납세의무자와 동일인)
  applicant_name text not null,
  applicant_rrn text not null,       -- 주민등록번호 (운영 전 암호화/마스킹 필요 - README 참고)
  applicant_address text,
  applicant_phone text,

  -- ① 신청유형
  request_type text not null,        -- 최초 / 변경_지분율 / 변경_납세의무자 / 특례취소

  -- ② 납세의무자(지분율이 같거나 높은 사람)
  taxpayer_name text not null,
  taxpayer_rrn text not null,

  -- ③ 납세의무자의 배우자
  spouse_name text not null,
  spouse_rrn text not null,

  -- 점검항목 3개 (모두 충족해야 특례 적용 가능)
  check_ownership_ratio boolean not null default false,       -- 지분율 배우자보다 높거나 같음
  check_spouse_no_other_house boolean not null default false, -- 배우자 명의 다른 주택 없음
  check_household_no_other_house boolean not null default false, -- 배우자 제외 세대원 소유 주택 없음

  -- 국세청 2026년 자동계산 안내 참고사항 (공식 서식 항목은 아니며, 시스템 편의 항목)
  nts_notice_result text,            -- 신청유리 / 취소유리 / 모름 / 안내못받음

  -- 신청서 원문 확인문구 대응: "배우자의 동의를 받아 신청했음을 확인합니다"
  consent_confirmed boolean not null default false,

  -- 전자서명 (base64 PNG)
  applicant_signature text,

  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 4. FORM A - 국세환급금양도요구서 (국세기본법 시행규칙 별지 제24호의2서식)
--    ※ 2단계 개발 대상 - 테이블 구조만 우선 생성, 입력 화면은 추후 제작
-- ------------------------------------------------------------
create table if not exists form_a_transfer (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references submissions(id) on delete cascade,

  transferor_name text,      -- 양도자
  transferor_rrn text,
  transferor_biz_no text,
  transferor_address text,
  transferor_phone text,

  transferee_name text,      -- 양수자
  transferee_rrn text,
  transferee_biz_no text,
  transferee_address text,
  transferee_phone text,

  refund_items jsonb,          -- 국세환급금명세서 [{세목, 납부기한, 계, 내국세, 교육세, 가산금, 국세환급가산금}]
  transfer_amount_items jsonb, -- 양도하려는 금액 (동일 구조)

  transferor_signature text,
  transferee_signature text,

  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 5. FORM C - 국세환급금 충당청구(동의)서 (국세기본법 시행규칙 별지 제19호의2서식)
--    ※ 2단계 개발 대상 - 테이블 구조만 우선 생성, 입력 화면은 추후 제작
-- ------------------------------------------------------------
create table if not exists form_c_offset (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references submissions(id) on delete cascade,

  claimant_name text,      -- 청구인
  claimant_rrn text,
  claimant_biz_no text,
  claimant_address text,
  claimant_phone text,

  refund_items jsonb,   -- 국세환급금내역
  offset_items jsonb,   -- 충당청구(동의)내역
  balance numeric,      -- 잔액

  agent_name text,       -- 대리인(있는 경우만)
  agent_relation text,
  agent_phone text,

  claimant_signature text,

  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 6. Row Level Security (RLS)
-- ------------------------------------------------------------
-- ⚠️ 아래 정책은 "프로토타입" 단계용입니다. 익명 사용자가 제출(insert)/조회(select)를
-- 모두 할 수 있게 열어둔 상태이므로, 실제 운영 전에는 반드시 다음을 적용하세요.
--   1) 관리자 조회는 Supabase Auth 로그인 사용자만 가능하도록 정책 강화
--   2) 납세자는 본인이 방금 제출한 건만 (또는 제출 즉시 클라이언트에서 보관한 id로만) 조회 가능하도록 제한
--   3) update/delete는 관리자 역할에만 허용
-- README.md의 "보안 체크리스트" 섹션 참고

alter table submissions enable row level security;
alter table form_b_joint_home enable row level security;
alter table form_a_transfer enable row level security;
alter table form_c_offset enable row level security;

create policy "prototype_insert_submissions" on submissions for insert with check (true);
create policy "prototype_select_submissions" on submissions for select using (true);
create policy "prototype_update_submissions" on submissions for update using (true);

create policy "prototype_insert_form_b" on form_b_joint_home for insert with check (true);
create policy "prototype_select_form_b" on form_b_joint_home for select using (true);

create policy "prototype_insert_form_a" on form_a_transfer for insert with check (true);
create policy "prototype_select_form_a" on form_a_transfer for select using (true);

create policy "prototype_insert_form_c" on form_c_offset for insert with check (true);
create policy "prototype_select_form_c" on form_c_offset for select using (true);
