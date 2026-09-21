-- ============================================================
-- 마이그레이션 005: 관리자 로그인 다시 활성화 (원복)
-- ============================================================
-- migration-004로 임시로 꺼뒀던 관리자 로그인 보호를 다시 켭니다.
-- 실제 납세자에게 QR/링크를 공유하기 전에 반드시 실행하세요.
--
-- 이 파일 실행 후, js/auth-guard.js 의 ADMIN_AUTH_DISABLED_TEMP 값도
-- true -> false 로 바꿔서 다시 배포해야 완전히 원복됩니다 (DB와 화면 양쪽 다 필요).
-- ============================================================

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

-- 익명(anon) 사용자의 실행 권한 회수, 로그인 사용자만 다시 허용
revoke all on function admin_list_submissions(uuid) from public;
revoke all on function admin_list_submissions(uuid) from anon;
grant execute on function admin_list_submissions(uuid) to authenticated;

-- 임시로 추가했던 익명 상태변경 허용 정책 제거
drop policy if exists "temp_anon_update_submissions" on submissions;
