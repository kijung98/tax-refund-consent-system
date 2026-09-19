// ============================================================
// Supabase 연동 래퍼 함수
// 사용 전 HTML에서 아래 순서로 스크립트를 로드해야 합니다:
//
//   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
//   <script src="../js/config.js"></script>
//   <script src="../js/supabase-client.js"></script>
//
// ⚠️ 주민등록번호 암호화(2026-xx 적용) 이후, 제출/조회는 테이블에 직접 접근하지 않고
// 모두 DB 함수(submit_form_a/b/c, admin_list_submissions)를 통해서만 처리합니다.
// 암호화·복호화는 전부 DB 안에서 일어나며, 이 JS 파일에는 암호화 키가 전혀 없습니다.
// ============================================================

const supabaseClient = window.supabase.createClient(
  SUPABASE_CONFIG.url,
  SUPABASE_CONFIG.anonKey
);

/**
 * FORM B(공동명의 1주택자 특례신청서) 제출
 * @param {object} payload - taxpayer/form.html의 collectPayload() 결과
 * @returns {string} 접수번호
 */
async function submitFormB(payload) {
  const { data, error } = await supabaseClient.rpc('submit_form_b', { payload });
  if (error) throw error;
  return data;
}

/**
 * FORM A(국세환급금양도요구서) 제출
 */
async function submitFormA(payload) {
  const { data, error } = await supabaseClient.rpc('submit_form_a', { payload });
  if (error) throw error;
  return data;
}

/**
 * FORM C(국세환급금 충당청구(동의)서) 제출
 */
async function submitFormC(payload) {
  const { data, error } = await supabaseClient.rpc('submit_form_c', { payload });
  if (error) throw error;
  return data;
}

/**
 * admin_list_submissions RPC가 반환한 평평한(flat) 한 행을
 * 기존 화면 코드(admin/index.html, admin/detail.html, excel-export.js, print/*)가
 * 그대로 쓸 수 있도록 예전과 같은 중첩 구조로 되돌린다.
 * { id, reception_number, ..., form_b_joint_home: [...], form_a_transfer: [...], form_c_offset: [...] }
 */
function reshapeAdminRow(row) {
  const base = {
    id: row.id,
    reception_number: row.reception_number,
    status: row.status,
    staff_name: row.staff_name,
    created_at: row.created_at,
    form_b_joint_home: [],
    form_a_transfer: [],
    form_c_offset: []
  };
  if (row.form_type === 'B') base.form_b_joint_home = [row.form_data];
  else if (row.form_type === 'A') base.form_a_transfer = [row.form_data];
  else if (row.form_type === 'C') base.form_c_offset = [row.form_data];
  return base;
}

/**
 * 관리자: 제출 목록 조회 (검색/필터 포함)
 * 주민등록번호는 admin_list_submissions RPC 내부에서 로그인한 관리자에게만 복호화되어 온다.
 */
async function listSubmissions({ keyword = '', status = '', dateFrom = '', dateTo = '' } = {}) {
  const { data, error } = await supabaseClient.rpc('admin_list_submissions');
  if (error) throw error;

  let rows = data.map(reshapeAdminRow);

  if (status) rows = rows.filter(r => r.status === status);
  if (dateFrom) rows = rows.filter(r => new Date(r.created_at) >= new Date(dateFrom));
  if (dateTo) rows = rows.filter(r => new Date(r.created_at) <= new Date(dateTo + 'T23:59:59'));

  const kw = keyword.trim();
  if (!kw) return rows;

  return rows.filter(row => {
    const b = row.form_b_joint_home?.[0];
    const a = row.form_a_transfer?.[0];
    const c = row.form_c_offset?.[0];
    if (row.reception_number.includes(kw)) return true;

    if (b && (
      (b.applicant_name && b.applicant_name.includes(kw)) ||
      (b.spouse_name && b.spouse_name.includes(kw)) ||
      (b.taxpayer_name && b.taxpayer_name.includes(kw)) ||
      (b.applicant_phone && b.applicant_phone.includes(kw))
    )) return true;

    if (a && (
      (a.transferor_name && a.transferor_name.includes(kw)) ||
      (a.transferee_name && a.transferee_name.includes(kw)) ||
      (a.transferor_phone && a.transferor_phone.includes(kw))
    )) return true;

    if (c && (
      (c.claimant_name && c.claimant_name.includes(kw)) ||
      (c.claimant_phone && c.claimant_phone.includes(kw))
    )) return true;

    return false;
  });
}

/**
 * 관리자: 단일 접수건 상세 조회
 */
async function getSubmissionDetail(submissionId) {
  const { data, error } = await supabaseClient.rpc('admin_list_submissions', { p_id: submissionId });
  if (error) throw error;
  if (!data || data.length === 0) throw new Error('접수 정보를 찾을 수 없습니다.');
  return reshapeAdminRow(data[0]);
}

/**
 * 관리자: 처리상태 변경
 * (주민등록번호가 없는 테이블이라 암호화와 무관 - 기존과 동일하게 직접 update)
 */
async function updateStatus(submissionId, status, staffName) {
  const { error } = await supabaseClient
    .from('submissions')
    .update({ status, staff_name: staffName || null, updated_at: new Date().toISOString() })
    .eq('id', submissionId);
  if (error) throw error;
}
