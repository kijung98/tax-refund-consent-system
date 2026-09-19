// ============================================================
// Supabase 연동 래퍼 함수
// 사용 전 HTML에서 아래 순서로 스크립트를 로드해야 합니다:
//
//   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
//   <script src="../js/config.js"></script>
//   <script src="../js/supabase-client.js"></script>
// ============================================================

const supabaseClient = window.supabase.createClient(
  SUPABASE_CONFIG.url,
  SUPABASE_CONFIG.anonKey
);

/**
 * 접수번호 생성 (DB 함수 generate_reception_number 호출)
 * DB 연결 실패시 클라이언트에서 임시 생성(충돌 가능성 있음 - 정식 운영에서는 DB 함수 사용 권장)
 */
async function generateReceptionNumber() {
  const { data, error } = await supabaseClient.rpc('generate_reception_number');
  if (error) {
    console.error('접수번호 생성 오류:', error);
    const today = new Date();
    const y = today.getFullYear();
    const m = String(today.getMonth() + 1).padStart(2, '0');
    const d = String(today.getDate()).padStart(2, '0');
    const rand = String(Math.floor(Math.random() * 900) + 100);
    return `${y}${m}${d}${rand}`;
  }
  return data;
}

async function insertSubmissionWithForm(tableName, payload) {
  const receptionNumber = await generateReceptionNumber();

  const { data: submission, error: subErr } = await supabaseClient
    .from('submissions')
    .insert({ reception_number: receptionNumber, status: '신규' })
    .select()
    .single();

  if (subErr) throw subErr;

  const { error: formErr } = await supabaseClient
    .from(tableName)
    .insert({ submission_id: submission.id, ...payload });

  if (formErr) throw formErr;

  return receptionNumber;
}

/**
 * FORM B(공동명의 1주택자 특례신청서) 제출
 */
async function submitFormB(payload) {
  return insertSubmissionWithForm('form_b_joint_home', payload);
}

/**
 * FORM A(국세환급금양도요구서) 제출
 */
async function submitFormA(payload) {
  return insertSubmissionWithForm('form_a_transfer', payload);
}

/**
 * FORM C(국세환급금 충당청구(동의)서) 제출
 */
async function submitFormC(payload) {
  return insertSubmissionWithForm('form_c_offset', payload);
}

const SUBMISSION_SELECT = '*, form_b_joint_home(*), form_a_transfer(*), form_c_offset(*)';

/**
 * 관리자: 제출 목록 조회 (검색/필터 포함)
 * FORM A, B, C 를 모두 함께 가져온다. (한 접수건에는 셋 중 하나만 존재)
 */
async function listSubmissions({ keyword = '', status = '', dateFrom = '', dateTo = '' } = {}) {
  let query = supabaseClient
    .from('submissions')
    .select(SUBMISSION_SELECT)
    .order('created_at', { ascending: false });

  if (status) query = query.eq('status', status);
  if (dateFrom) query = query.gte('created_at', dateFrom);
  if (dateTo) query = query.lte('created_at', dateTo + 'T23:59:59');

  const { data, error } = await query;
  if (error) throw error;

  if (!keyword.trim()) return data;

  const kw = keyword.trim();
  return data.filter(row => {
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
 * 관리자: 단일 접수건 상세 조회 (FORM A/B/C 모두 포함해서 가져옴)
 */
async function getSubmissionDetail(submissionId) {
  const { data, error } = await supabaseClient
    .from('submissions')
    .select(SUBMISSION_SELECT)
    .eq('id', submissionId)
    .single();
  if (error) throw error;
  return data;
}

/**
 * 관리자: 처리상태 변경
 */
async function updateStatus(submissionId, status, staffName) {
  const { error } = await supabaseClient
    .from('submissions')
    .update({ status, staff_name: staffName || null, updated_at: new Date().toISOString() })
    .eq('id', submissionId);
  if (error) throw error;
}
