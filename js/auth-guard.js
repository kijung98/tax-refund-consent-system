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

// ============================================================
// ⚠️⚠️⚠️ 테스트 모드 스위치 ⚠️⚠️⚠️
// true로 두면 로그인 없이 관리자 화면에 바로 들어갈 수 있습니다 (개발/확인용).
// 실제 납세자에게 QR/링크를 공유하기 전에는 반드시 false로 되돌리고,
// sql/migration-005-restore-admin-auth.sql 도 함께 실행해야 합니다.
// (이 파일의 스위치만 false로 바꾸는 것으로는 부족합니다 - DB 쪽 잠금도
//  sql/migration-004-temp-disable-admin-auth.sql 로 함께 풀어놓은 상태라서,
//  반드시 migration-005를 실행해서 DB 쪽도 같이 되돌려야 진짜 보안이 걸립니다.)
const ADMIN_AUTH_DISABLED_TEMP = true;

/**
 * 로그인 세션이 없으면 로그인 페이지로 돌려보낸다.
 * (테스트 모드일 때는 로그인 확인을 건너뛰고 더미 세션을 반환한다)
 * @returns {object|null} 로그인된 경우(또는 테스트 모드) session 객체, 아니면 null
 */
async function requireAdminAuth() {
  if (ADMIN_AUTH_DISABLED_TEMP) {
    return { user: { email: '(테스트 모드 - 로그인 비활성화됨)' }, __testMode: true };
  }

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
 * 테스트 모드일 때는 눈에 띄는 경고 배너를 대신 표시한다.
 * @param {string} targetElementId - 삽입할 위치의 엘리먼트 id
 * @param {object} session - requireAdminAuth()가 반환한 session
 */
function renderAdminBar(targetElementId, session) {
  const el = document.getElementById(targetElementId);
  if (!el) return;

  if (session.__testMode) {
    el.innerHTML = `<span style="background:#FFF4E0; color:#8A5300; padding:5px 12px; border-radius:999px; font-size:12px; font-weight:700;">⚠️ 테스트 모드: 로그인 비활성화됨</span>`;
    return;
  }

  el.innerHTML = `
    <span class="text-sm text-muted">${session.user.email}</span>
    <button class="btn btn-secondary btn-sm" id="admin-logout-btn" style="margin-left:8px;">로그아웃</button>
  `;
  document.getElementById('admin-logout-btn').addEventListener('click', adminLogout);
}
