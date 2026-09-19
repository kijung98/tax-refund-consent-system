-- ============================================================
-- 마이그레이션 001: 관리자 인증 기반 RLS로 전환
-- ============================================================
-- 이미 schema.sql을 실행해서 익명 전체허용 상태로 운영 중이었다면,
-- schema.sql을 처음부터 다시 실행하지 말고 이 파일만 실행하세요.
-- 기존 데이터(submissions 등)는 그대로 유지됩니다.
--
-- 사용법: Supabase 대시보드 > SQL Editor 에서 이 파일 전체를 실행
-- ============================================================

-- 기존 "프로토타입" 정책 제거 (있을 때만 - 없어도 오류 없이 넘어감)
drop policy if exists "prototype_insert_submissions" on submissions;
drop policy if exists "prototype_select_submissions" on submissions;
drop policy if exists "prototype_update_submissions" on submissions;

drop policy if exists "prototype_insert_form_b" on form_b_joint_home;
drop policy if exists "prototype_select_form_b" on form_b_joint_home;

drop policy if exists "prototype_insert_form_a" on form_a_transfer;
drop policy if exists "prototype_select_form_a" on form_a_transfer;

drop policy if exists "prototype_insert_form_c" on form_c_offset;
drop policy if exists "prototype_select_form_c" on form_c_offset;

-- 새 정책 생성 (이미 있다면 오류가 나므로, 처음 한 번만 실행하세요)
create policy "taxpayer_insert_submissions" on submissions for insert with check (true);
create policy "admin_select_submissions" on submissions for select using (auth.role() = 'authenticated');
create policy "admin_update_submissions" on submissions for update using (auth.role() = 'authenticated');

create policy "taxpayer_insert_form_b" on form_b_joint_home for insert with check (true);
create policy "admin_select_form_b" on form_b_joint_home for select using (auth.role() = 'authenticated');

create policy "taxpayer_insert_form_a" on form_a_transfer for insert with check (true);
create policy "admin_select_form_a" on form_a_transfer for select using (auth.role() = 'authenticated');

create policy "taxpayer_insert_form_c" on form_c_offset for insert with check (true);
create policy "admin_select_form_c" on form_c_offset for select using (auth.role() = 'authenticated');
