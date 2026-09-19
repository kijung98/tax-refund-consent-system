// ============================================================
// 관리자 인증 가드
// admin/index.html, admin/detail.html, admin/qr.html 각각의
// 스크립트 최상단에서 requireAdminAuth()를 호출해서 사용한다.
//
// 사용 전 HTML에서 아래 순서로 로드되어 있어야 합니다:
//   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
//   <script src="../js/config.js"></script>
//   <script src="../js/supabase-client.js"></script>
//   <script src="../js/auth-guard.js"></script>
// ============================================================

/**
 * 로그인 세션이 없으면 로그인 페이지로 돌려보낸다.
 * @returns {object|null} 로그인된 경우 session 객체, 아니면 null (이미 리다이렉트 처리됨)
 */
async function requireAdminAuth() {
  const { data: { session }, error } = await supabaseClient.auth.getSession();
  if (error || !session) {
    window.location.href = 'login.html';
    return null;
  }
  return session;
}

/**
 * 로그아웃 후 로그인 페이지로 이동한다.
 */
async function adminLogout() {
  await supabaseClient.auth.signOut();
  window.location.href = 'login.html';
}

/**
 * 관리자 페이지 상단에 로그인된 이메일 + 로그아웃 버튼을 표시한다.
 * @param {string} targetElementId - 삽입할 위치의 엘리먼트 id
 * @param {object} session - requireAdminAuth()가 반환한 session
 */
function renderAdminBar(targetElementId, session) {
  const el = document.getElementById(targetElementId);
  if (!el) return;
  el.innerHTML = `
    <span class="text-sm text-muted">${session.user.email}</span>
    <button class="btn btn-secondary btn-sm" id="admin-logout-btn" style="margin-left:8px;">로그아웃</button>
  `;
  document.getElementById('admin-logout-btn').addEventListener('click', adminLogout);
}
