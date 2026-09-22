// ============================================================
// Supabase 접속 설정 (실제 값이 이미 입력되어 있습니다)
//
// 이 파일은 kijung98/tax-refund-consent-system 프로젝트용으로 이미
// 실제 Publishable key가 채워져 있으므로, zip을 풀어 GitHub 저장소에
// 그대로 업로드하시면 바로 동작합니다.
//
// ✅ Publishable key(sb_publishable_로 시작)는 브라우저에 노출되어도
//    안전하도록 설계된 공개키입니다. RLS(행 단위 보안 정책)로 실제
//    데이터 접근이 통제되므로 GitHub 공개 저장소에 있어도 문제 없습니다.
//
// 🚫 절대 넣으면 안 되는 값: "Secret key"(sb_secret_로 시작, 예전 이름
//    "service_role"). 이 키는 보안 규칙을 전부 무시하고 DB 전체에 접근할 수
//    있는 관리자 키라서, 이 파일에 넣으면 누구나 그 키로 전체 데이터
//    (주민등록번호 포함)를 읽고 지울 수 있게 됩니다.
//    반드시 "Publishable key"만 사용하세요.
//
// 🔄 다른 Supabase 프로젝트로 옮길 때만 아래 두 값을 교체하시면 됩니다:
//   1. Supabase Dashboard > Project Settings > API Keys
//   2. "Project URL" -> url 에 붙여넣기
//   3. "Publishable key" -> anonKey 에 붙여넣기
// ============================================================

const SUPABASE_CONFIG = {
  url: 'https://vsjipvktmlbsrbcjfbwu.supabase.co',
  anonKey: 'sb_publishable_oCw7h_75W1f9Zzgla873gg_e-nnjNRd'
};
