// ============================================================
// Supabase 접속 설정
// 기정님의 실제 프로젝트 값이 채워진 버전입니다.
// 이 파일을 저장소의 js/config.js 에 그대로 덮어씌우세요.
//
// 🚫 절대 넣으면 안 되는 값: "Secret key"(sb_secret_로 시작, 예전 이름
//    "service_role"). 이 키는 보안 규칙을 전부 무시하고 DB 전체에 접근할 수
//    있는 관리자 키라서, 이 파일(공개 GitHub 저장소)에 넣으면 누구나 그 키로
//    전체 데이터(주민등록번호 포함)를 읽고 지울 수 있게 됩니다.
//    반드시 "Publishable key"만 사용하세요. (아래 값은 Publishable key입니다)
// ============================================================

const SUPABASE_CONFIG = {
  url: 'https://vsjipvktmlbsrbcjfbwu.supabase.co',
  anonKey: 'sb_publishable_oCw7h_75W1f9Zzgla873gg_e-nnjNRd'
};
