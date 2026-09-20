// ============================================================
// Supabase 접속 설정
// ⚠️ 실제 배포 전 아래 두 값을 본인의 Supabase 프로젝트 값으로 반드시 교체하세요.
//
// 확인 방법:
//   1. https://supabase.com 에서 무료 프로젝트 생성
//   2. 왼쪽 메뉴 Project Settings > API Keys 이동
//   3. "Project URL" -> url 에 붙여넣기
//   4. "Publishable key" (sb_publishable_로 시작, 예전 이름 "anon public") 값을
//      복사 -> anonKey 에 붙여넣기
//   5. SQL Editor 에서 sql/schema.sql 파일 내용을 실행 (테이블 생성)
//
// 🚫 절대 넣으면 안 되는 값: "Secret key"(sb_secret_로 시작, 예전 이름
//    "service_role"). 이 키는 보안 규칙을 전부 무시하고 DB 전체에 접근할 수
//    있는 관리자 키라서, 이 파일(공개 GitHub 저장소)에 넣으면 누구나 그 키로
//    전체 데이터(주민등록번호 포함)를 읽고 지울 수 있게 됩니다.
//    반드시 "Publishable key"만 사용하세요.
//
// ⚠️ anonKey(Publishable key)는 "공개해도 되는" 키이지만, 그래도 GitHub에는 가급적
//    이 파일 자체를 올리지 않거나(.gitignore), 별도 비공개 저장소를
//    사용하는 것을 권장합니다. (README "보안 체크리스트" 참고)
// ============================================================

const SUPABASE_CONFIG = {
  url: 'https://YOUR_PROJECT_ID.supabase.co',
  anonKey: 'YOUR_SUPABASE_PUBLISHABLE_KEY'
};
