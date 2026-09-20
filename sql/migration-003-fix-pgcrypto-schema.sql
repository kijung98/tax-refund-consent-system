-- ============================================================
-- 마이그레이션 003: pgcrypto 함수 인식 오류 수정
-- ============================================================
-- 증상: 제출 시 "(개발 확인용) function pgp_sym_encrypt(text, text)
-- does not exist" 오류가 뜨는 경우 이 파일을 실행하세요.
--
-- 원인: Supabase는 암호화 함수(pgcrypto)를 public 스키마가 아니라
-- extensions 스키마에 설치합니다. 함수들이 public 스키마만 보도록
-- 설정되어 있어서 바로 옆의 extensions 스키마를 못 찾은 것입니다.
--
-- 이 파일은 테이블이나 데이터는 전혀 건드리지 않고, 문제가 된 함수
-- 4개만 고쳐서 다시 만듭니다 (몇 번을 실행해도 안전합니다).
-- ============================================================

create or replace function submit_form_b(payload jsonb)
returns text
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_key text := (select key_value from app_secrets where key_name = 'encryption_key');
  v_reception_number text;
  v_submission_id uuid;
begin
  if v_key is null or v_key = '' then
    raise exception '암호화 키가 설정되지 않았습니다. schema.sql 6번 안내대로 app_secrets 테이블에 encryption_key 값을 먼저 넣어 주세요.';
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
set search_path = public, extensions, pg_temp
as $$
declare
  v_key text := (select key_value from app_secrets where key_name = 'encryption_key');
  v_reception_number text;
  v_submission_id uuid;
begin
  if v_key is null or v_key = '' then
    raise exception '암호화 키가 설정되지 않았습니다. schema.sql 6번 안내대로 app_secrets 테이블에 encryption_key 값을 먼저 넣어 주세요.';
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
set search_path = public, extensions, pg_temp
as $$
declare
  v_key text := (select key_value from app_secrets where key_name = 'encryption_key');
  v_reception_number text;
  v_submission_id uuid;
begin
  if v_key is null or v_key = '' then
    raise exception '암호화 키가 설정되지 않았습니다. schema.sql 6번 안내대로 app_secrets 테이블에 encryption_key 값을 먼저 넣어 주세요.';
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
set search_path = public, extensions, pg_temp
as $$
declare
  v_key text := (select key_value from app_secrets where key_name = 'encryption_key');
begin
  if auth.role() <> 'authenticated' then
    raise exception '관리자 로그인이 필요합니다.';
  end if;
  if v_key is null or v_key = '' then
    raise exception '암호화 키가 설정되지 않았습니다. schema.sql 6번 안내대로 app_secrets 테이블에 encryption_key 값을 먼저 넣어 주세요.';
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

revoke all on function submit_form_b(jsonb) from public;
grant execute on function submit_form_b(jsonb) to anon, authenticated;

revoke all on function submit_form_a(jsonb) from public;
grant execute on function submit_form_a(jsonb) to anon, authenticated;

revoke all on function submit_form_c(jsonb) from public;
grant execute on function submit_form_c(jsonb) to anon, authenticated;

revoke all on function admin_list_submissions(uuid) from public;
grant execute on function admin_list_submissions(uuid) to authenticated;
