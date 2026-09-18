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

/**
 * FORM B(공동명의 1주택자 특례신청서) 제출
 * @param {object} payload - form_b_joint_home 테이블 컬럼과 동일한 키를 가진 객체
 * @returns {string} 접수번호
 */
async function submitFormB(payload) {
  const receptionNumber = await generateReceptionNumber();

  const { data: submission, error: subErr } = await supabaseClient
    .from('submissions')
    .insert({ reception_number: receptionNumber, status: '신규' })
    .select()
    .single();

  if (subErr) throw subErr;

  const { error: formErr } = await supabaseClient
    .from('form_b_joint_home')
    .insert({ submission_id: submission.id, ...payload });

  if (formErr) throw formErr;

  return receptionNumber;
}

/**
 * 관리자: 제출 목록 조회 (검색/필터 포함)
 */
async function listSubmissions({ keyword = '', status = '', dateFrom = '', dateTo = '' } = {}) {
  let query = supabaseClient
    .from('submissions')
    .select('*, form_b_joint_home(*)')
    .order('created_at', { ascending: false });

  if (status) query = query.eq('status', status);
  if (dateFrom) query = query.gte('created_at', dateFrom);
  if (dateTo) query = query.lte('created_at', dateTo + 'T23:59:59');

  const { data, error } = await query;
  if (error) throw error;

  if (!keyword.trim()) return data;

  const kw = keyword.trim();
  return data.filter(row => {
    const f = row.form_b_joint_home?.[0];
    const inReception = row.reception_number.includes(kw);
    if (!f) return inReception;
    return (
      inReception ||
      (f.applicant_name && f.applicant_name.includes(kw)) ||
      (f.spouse_name && f.spouse_name.includes(kw)) ||
      (f.taxpayer_name && f.taxpayer_name.includes(kw)) ||
      (f.applicant_phone && f.applicant_phone.includes(kw))
    );
  });
}

/**
 * 관리자: 단일 접수건 상세 조회
 */
async function getSubmissionDetail(submissionId) {
  const { data, error } = await supabaseClient
    .from('submissions')
    .select('*, form_b_joint_home(*)')
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
