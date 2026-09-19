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
  applicant_rrn bytea not null,      -- 주민등록번호 (pgp_sym_encrypt로 암호화 저장 - 아래 7번 참고)
  applicant_address text,
  applicant_phone text,

  -- ① 신청유형
  request_type text not null,        -- 최초 / 변경_지분율 / 변경_납세의무자 / 특례취소

  -- ② 납세의무자(지분율이 같거나 높은 사람)
  taxpayer_name text not null,
  taxpayer_rrn bytea not null,

  -- ③ 납세의무자의 배우자
  spouse_name text not null,
  spouse_rrn bytea not null,

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
  transferor_rrn bytea,      -- 주민등록번호 (암호화 저장)
  transferor_biz_no text,
  transferor_address text,
  transferor_phone text,

  transferee_name text,      -- 양수자
  transferee_rrn bytea,      -- 주민등록번호 (암호화 저장)
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
  claimant_rrn bytea,      -- 주민등록번호 (암호화 저장)
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
-- 6. 주민등록번호 암호화 — 키 설정 (⭐ 반드시 한 번 실행 필요)
-- ------------------------------------------------------------
-- 아래 한 줄을 실행해서 암호화에 쓸 비밀키를 DB에 설정하세요.
-- 이 키는 브라우저(js/config.js 등)에는 절대 들어가지 않고, DB 안에만 존재합니다.
-- 'REPLACE_WITH_YOUR_OWN_SECRET_KEY' 부분을 충분히 길고 복잡한 문자열로 바꿔서 실행하세요.
-- (예: 영문+숫자+특수문자 20자 이상. 키를 잊어버리면 기존 암호화된 데이터를 복호화할 수 없습니다 —
--  꼭 별도의 안전한 곳에 키를 메모해 두세요.)
--
--   alter database postgres set app.encryption_key = 'REPLACE_WITH_YOUR_OWN_SECRET_KEY';
--
-- ⚠️ 위 명령은 이 schema.sql 파일에 자동 포함되어 있지 않습니다. 반드시 직접 키 값을
-- 정해서 SQL Editor에 따로 한 번 실행해 주세요 (전체 스키마 실행 전이든 후든 상관없습니다).

-- ------------------------------------------------------------
-- 6-1. 납세자 제출용 함수 (암호화 후 저장)
-- ------------------------------------------------------------
-- 프론트엔드는 더 이상 form_b_joint_home 등 테이블에 직접 insert하지 않고,
-- 아래 함수를 호출한다 (js/supabase-client.js 참고). 함수 안에서 주민등록번호를
-- pgp_sym_encrypt로 암호화한 뒤 저장하므로, 브라우저에는 암호화된 값이 오갈 일이 없다.

create or replace function submit_form_b(payload jsonb)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_key text := current_setting('app.encryption_key', true);
  v_reception_number text;
  v_submission_id uuid;
begin
  if v_key is null or v_key = '' then
    raise exception '암호화 키가 설정되지 않았습니다. schema.sql 6번 안내대로 app.encryption_key를 먼저 설정해 주세요.';
  end if;

  v_reception_number := generate_reception_number();

  insert into submissions (reception_number, status)
  values (v_reception_number, '신규')
  returning id into v_submission_id;

  insert into form_b_joint_home (
    submission_id, applicant_name, applicant_rrn, applicant_address, applicant_phone,
    request_type, taxpayer_name, taxpayer_rrn, spouse_name, spouse_rrn,
    check_ownership_ratio, check_spouse_no_other_house, check_household_no_other_house,
    nts_notice_result, consent_confirmed, applicant_signature
  ) values (
    v_submission_id,
    payload->>'applicant_name',
    pgp_sym_encrypt(payload->>'applicant_rrn', v_key),
    payload->>'applicant_address',
    payload->>'applicant_phone',
    payload->>'request_type',
    payload->>'taxpayer_name',
    pgp_sym_encrypt(payload->>'taxpayer_rrn', v_key),
    payload->>'spouse_name',
    pgp_sym_encrypt(payload->>'spouse_rrn', v_key),
    coalesce((payload->>'check_ownership_ratio')::boolean, false),
    coalesce((payload->>'check_spouse_no_other_house')::boolean, false),
    coalesce((payload->>'check_household_no_other_house')::boolean, false),
    payload->>'nts_notice_result',
    coalesce((payload->>'consent_confirmed')::boolean, false),
    payload->>'applicant_signature'
  );

  return v_reception_number;
end;
$$;

create or replace function submit_form_a(payload jsonb)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_key text := current_setting('app.encryption_key', true);
  v_reception_number text;
  v_submission_id uuid;
begin
  if v_key is null or v_key = '' then
    raise exception '암호화 키가 설정되지 않았습니다. schema.sql 6번 안내대로 app.encryption_key를 먼저 설정해 주세요.';
  end if;

  v_reception_number := generate_reception_number();

  insert into submissions (reception_number, status)
  values (v_reception_number, '신규')
  returning id into v_submission_id;

  insert into form_a_transfer (
    submission_id,
    transferor_name, transferor_rrn, transferor_biz_no, transferor_address, transferor_phone,
    transferee_name, transferee_rrn, transferee_biz_no, transferee_address, transferee_phone,
    refund_items, transfer_amount_items,
    transferor_signature, transferee_signature
  ) values (
    v_submission_id,
    payload->>'transferor_name',
    pgp_sym_encrypt(payload->>'transferor_rrn', v_key),
    payload->>'transferor_biz_no',
    payload->>'transferor_address',
    payload->>'transferor_phone',
    payload->>'transferee_name',
    pgp_sym_encrypt(payload->>'transferee_rrn', v_key),
    payload->>'transferee_biz_no',
    payload->>'transferee_address',
    payload->>'transferee_phone',
    payload->'refund_items',
    payload->'transfer_amount_items',
    payload->>'transferor_signature',
    payload->>'transferee_signature'
  );

  return v_reception_number;
end;
$$;

create or replace function submit_form_c(payload jsonb)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_key text := current_setting('app.encryption_key', true);
  v_reception_number text;
  v_submission_id uuid;
begin
  if v_key is null or v_key = '' then
    raise exception '암호화 키가 설정되지 않았습니다. schema.sql 6번 안내대로 app.encryption_key를 먼저 설정해 주세요.';
  end if;

  v_reception_number := generate_reception_number();

  insert into submissions (reception_number, status)
  values (v_reception_number, '신규')
  returning id into v_submission_id;

  insert into form_c_offset (
    submission_id,
    claimant_name, claimant_rrn, claimant_biz_no, claimant_address, claimant_phone,
    refund_items, offset_items, balance,
    agent_name, agent_relation, agent_phone,
    claimant_signature
  ) values (
    v_submission_id,
    payload->>'claimant_name',
    pgp_sym_encrypt(payload->>'claimant_rrn', v_key),
    payload->>'claimant_biz_no',
    payload->>'claimant_address',
    payload->>'claimant_phone',
    payload->'refund_items',
    payload->'offset_items',
    (payload->>'balance')::numeric,
    payload->>'agent_name',
    payload->>'agent_relation',
    payload->>'agent_phone',
    payload->>'claimant_signature'
  );

  return v_reception_number;
end;
$$;

-- ------------------------------------------------------------
-- 6-2. 관리자 조회용 함수 (복호화 후 반환, 로그인한 관리자만 호출 가능)
-- ------------------------------------------------------------
-- p_id를 넘기면 해당 건 1개만, 생략하면 전체 목록을 반환한다.
-- 로그인하지 않은 상태(anon)로 호출하면 예외를 던져서 차단한다.

create or replace function admin_list_submissions(p_id uuid default null)
returns table (
  id uuid,
  reception_number text,
  status text,
  staff_name text,
  created_at timestamptz,
  form_type text,
  form_data jsonb
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_key text := current_setting('app.encryption_key', true);
begin
  if auth.role() <> 'authenticated' then
    raise exception '관리자 로그인이 필요합니다.';
  end if;
  if v_key is null or v_key = '' then
    raise exception '암호화 키가 설정되지 않았습니다. schema.sql 6번 안내대로 app.encryption_key를 먼저 설정해 주세요.';
  end if;

  return query
  select
    s.id, s.reception_number, s.status, s.staff_name, s.created_at,
    case when b.id is not null then 'B' when a.id is not null then 'A' when c.id is not null then 'C' end,
    case
      when b.id is not null then jsonb_build_object(
        'applicant_name', b.applicant_name,
        'applicant_rrn', pgp_sym_decrypt(b.applicant_rrn, v_key),
        'applicant_address', b.applicant_address,
        'applicant_phone', b.applicant_phone,
        'request_type', b.request_type,
        'taxpayer_name', b.taxpayer_name,
        'taxpayer_rrn', pgp_sym_decrypt(b.taxpayer_rrn, v_key),
        'spouse_name', b.spouse_name,
        'spouse_rrn', pgp_sym_decrypt(b.spouse_rrn, v_key),
        'check_ownership_ratio', b.check_ownership_ratio,
        'check_spouse_no_other_house', b.check_spouse_no_other_house,
        'check_household_no_other_house', b.check_household_no_other_house,
        'nts_notice_result', b.nts_notice_result,
        'consent_confirmed', b.consent_confirmed,
        'applicant_signature', b.applicant_signature
      )
      when a.id is not null then jsonb_build_object(
        'transferor_name', a.transferor_name,
        'transferor_rrn', pgp_sym_decrypt(a.transferor_rrn, v_key),
        'transferor_biz_no', a.transferor_biz_no,
        'transferor_address', a.transferor_address,
        'transferor_phone', a.transferor_phone,
        'transferee_name', a.transferee_name,
        'transferee_rrn', pgp_sym_decrypt(a.transferee_rrn, v_key),
        'transferee_biz_no', a.transferee_biz_no,
        'transferee_address', a.transferee_address,
        'transferee_phone', a.transferee_phone,
        'refund_items', a.refund_items,
        'transfer_amount_items', a.transfer_amount_items,
        'transferor_signature', a.transferor_signature,
        'transferee_signature', a.transferee_signature
      )
      when c.id is not null then jsonb_build_object(
        'claimant_name', c.claimant_name,
        'claimant_rrn', pgp_sym_decrypt(c.claimant_rrn, v_key),
        'claimant_biz_no', c.claimant_biz_no,
        'claimant_address', c.claimant_address,
        'claimant_phone', c.claimant_phone,
        'refund_items', c.refund_items,
        'offset_items', c.offset_items,
        'balance', c.balance,
        'agent_name', c.agent_name,
        'agent_relation', c.agent_relation,
        'agent_phone', c.agent_phone,
        'claimant_signature', c.claimant_signature
      )
      else null
    end
  from submissions s
  left join form_b_joint_home b on b.submission_id = s.id
  left join form_a_transfer a on a.submission_id = s.id
  left join form_c_offset c on c.submission_id = s.id
  where (p_id is null or s.id = p_id)
  order by s.created_at desc;
end;
$$;

-- 함수 실행권한: 제출 함수는 납세자(anon)도 호출 가능, 조회 함수는 로그인 사용자만
revoke all on function submit_form_b(jsonb) from public;
grant execute on function submit_form_b(jsonb) to anon, authenticated;

revoke all on function submit_form_a(jsonb) from public;
grant execute on function submit_form_a(jsonb) to anon, authenticated;

revoke all on function submit_form_c(jsonb) from public;
grant execute on function submit_form_c(jsonb) to anon, authenticated;

revoke all on function admin_list_submissions(uuid) from public;
grant execute on function admin_list_submissions(uuid) to authenticated;

-- ------------------------------------------------------------
-- 7. Row Level Security (RLS) — 운영 수준
-- ------------------------------------------------------------
-- 정책 원칙:
--   1) 제출(insert)은 납세자가 로그인 없이 할 수 있어야 하므로 누구나(anon) 허용
--   2) 조회(select)/상태변경(update)은 관리자 로그인(Supabase Auth) 사용자만 허용
--      → admin/login.html 에서 로그인해야 admin/index.html 등에서 데이터가 보인다
--   3) 삭제(delete)는 어떤 역할에도 허용하지 않음 (정책을 만들지 않으면 자동 차단됨)
--
-- ⚠️ 이미 예전 스키마로 설치를 마치셨다면, 이 파일을 처음부터 다시 실행하지 말고
-- 아래 두 마이그레이션 파일을 순서대로 실행하세요 (기존 데이터가 보존됩니다):
--   1) sql/migration-001-admin-auth.sql   (관리자 로그인/RLS 강화)
--   2) sql/migration-002-encrypt-rrn.sql  (주민등록번호 암호화 전환)

alter table submissions enable row level security;
alter table form_b_joint_home enable row level security;
alter table form_a_transfer enable row level security;
alter table form_c_offset enable row level security;

create policy "taxpayer_insert_submissions" on submissions for insert with check (true);
create policy "admin_select_submissions" on submissions for select using (auth.role() = 'authenticated');
create policy "admin_update_submissions" on submissions for update using (auth.role() = 'authenticated');

create policy "taxpayer_insert_form_b" on form_b_joint_home for insert with check (true);
create policy "admin_select_form_b" on form_b_joint_home for select using (auth.role() = 'authenticated');

create policy "taxpayer_insert_form_a" on form_a_transfer for insert with check (true);
create policy "admin_select_form_a" on form_a_transfer for select using (auth.role() = 'authenticated');

create policy "taxpayer_insert_form_c" on form_c_offset for insert with check (true);
create policy "admin_select_form_c" on form_c_offset for select using (auth.role() = 'authenticated');
