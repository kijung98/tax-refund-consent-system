-- ============================================================
-- 마이그레이션 002: 주민등록번호 암호화 전환
-- ============================================================
-- 이미 schema.sql(또는 migration-001)을 실행해서 주민등록번호가 평문(text)으로
-- 저장되어 있었다면, 이 파일을 실행해서 암호화(bytea) 방식으로 전환합니다.
-- 기존에 저장된 주민등록번호 값도 이 과정에서 함께 암호화됩니다 (데이터 유지).
--
-- 사용법:
--   1) 아래 키 설정 줄의 값을 원하는 비밀키로 바꿔서 먼저 실행
--   2) 이 파일 나머지 전체를 Supabase SQL Editor에서 실행
-- ============================================================

-- ------------------------------------------------------------
-- 1단계: 암호화 키 설정 (⭐ 아래 값을 직접 바꾼 뒤 이 줄만 먼저 실행하세요)
-- ------------------------------------------------------------
-- alter database postgres set app.encryption_key = 'REPLACE_WITH_YOUR_OWN_SECRET_KEY';

-- ------------------------------------------------------------
-- 2단계: 키가 설정됐는지 확인 (설정 안 됐으면 아래에서 바로 오류로 멈춤)
-- ------------------------------------------------------------
do $$
begin
  if current_setting('app.encryption_key', true) is null
     or current_setting('app.encryption_key', true) = '' then
    raise exception '먼저 1단계의 alter database 명령으로 암호화 키를 설정한 뒤 다시 실행해 주세요.';
  end if;
end $$;

-- ------------------------------------------------------------
-- 3단계: 기존 평문 컬럼을 암호화(bytea)로 전환
-- (컬럼이 이미 bytea라면 이 블록은 오류 없이 건너뜁니다)
-- ------------------------------------------------------------
do $$
begin
  if (select data_type from information_schema.columns
      where table_name = 'form_b_joint_home' and column_name = 'applicant_rrn') = 'text' then
    alter table form_b_joint_home
      alter column applicant_rrn type bytea using pgp_sym_encrypt(applicant_rrn, current_setting('app.encryption_key')),
      alter column taxpayer_rrn type bytea using pgp_sym_encrypt(taxpayer_rrn, current_setting('app.encryption_key')),
      alter column spouse_rrn type bytea using pgp_sym_encrypt(spouse_rrn, current_setting('app.encryption_key'));
  end if;

  if (select data_type from information_schema.columns
      where table_name = 'form_a_transfer' and column_name = 'transferor_rrn') = 'text' then
    alter table form_a_transfer
      alter column transferor_rrn type bytea using pgp_sym_encrypt(transferor_rrn, current_setting('app.encryption_key')),
      alter column transferee_rrn type bytea using pgp_sym_encrypt(transferee_rrn, current_setting('app.encryption_key'));
  end if;

  if (select data_type from information_schema.columns
      where table_name = 'form_c_offset' and column_name = 'claimant_rrn') = 'text' then
    alter table form_c_offset
      alter column claimant_rrn type bytea using pgp_sym_encrypt(claimant_rrn, current_setting('app.encryption_key'));
  end if;
end $$;

-- ------------------------------------------------------------
-- 4단계: 제출/조회용 함수 생성 (schema.sql 6번 섹션과 동일한 내용)
-- ------------------------------------------------------------

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
    raise exception '암호화 키가 설정되지 않았습니다.';
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
    raise exception '암호화 키가 설정되지 않았습니다.';
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
    raise exception '암호화 키가 설정되지 않았습니다.';
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

create or replace function admin_list_submissions(p_id uuid default null)
returns table (
  id uuid, reception_number text, status text, staff_name text, created_at timestamptz,
  form_type text, form_data jsonb
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
    raise exception '암호화 키가 설정되지 않았습니다.';
  end if;

  return query
  select
    s.id, s.reception_number, s.status, s.staff_name, s.created_at,
    case when b.id is not null then 'B' when a.id is not null then 'A' when c.id is not null then 'C' end,
    case
      when b.id is not null then jsonb_build_object(
        'applicant_name', b.applicant_name, 'applicant_rrn', pgp_sym_decrypt(b.applicant_rrn, v_key),
        'applicant_address', b.applicant_address, 'applicant_phone', b.applicant_phone,
        'request_type', b.request_type, 'taxpayer_name', b.taxpayer_name,
        'taxpayer_rrn', pgp_sym_decrypt(b.taxpayer_rrn, v_key),
        'spouse_name', b.spouse_name, 'spouse_rrn', pgp_sym_decrypt(b.spouse_rrn, v_key),
        'check_ownership_ratio', b.check_ownership_ratio,
        'check_spouse_no_other_house', b.check_spouse_no_other_house,
        'check_household_no_other_house', b.check_household_no_other_house,
        'nts_notice_result', b.nts_notice_result, 'consent_confirmed', b.consent_confirmed,
        'applicant_signature', b.applicant_signature
      )
      when a.id is not null then jsonb_build_object(
        'transferor_name', a.transferor_name, 'transferor_rrn', pgp_sym_decrypt(a.transferor_rrn, v_key),
        'transferor_biz_no', a.transferor_biz_no, 'transferor_address', a.transferor_address,
        'transferor_phone', a.transferor_phone,
        'transferee_name', a.transferee_name, 'transferee_rrn', pgp_sym_decrypt(a.transferee_rrn, v_key),
        'transferee_biz_no', a.transferee_biz_no, 'transferee_address', a.transferee_address,
        'transferee_phone', a.transferee_phone,
        'refund_items', a.refund_items, 'transfer_amount_items', a.transfer_amount_items,
        'transferor_signature', a.transferor_signature, 'transferee_signature', a.transferee_signature
      )
      when c.id is not null then jsonb_build_object(
        'claimant_name', c.claimant_name, 'claimant_rrn', pgp_sym_decrypt(c.claimant_rrn, v_key),
        'claimant_biz_no', c.claimant_biz_no, 'claimant_address', c.claimant_address,
        'claimant_phone', c.claimant_phone,
        'refund_items', c.refund_items, 'offset_items', c.offset_items, 'balance', c.balance,
        'agent_name', c.agent_name, 'agent_relation', c.agent_relation, 'agent_phone', c.agent_phone,
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
