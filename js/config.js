// ============================================================
// Supabase 접속 설정
// ⚠️ 실제 배포 전 아래 두 값을 본인의 Supabase 프로젝트 값으로 반드시 교체하세요.
//
// 확인 방법:
//   1. https://supabase.com 에서 무료 프로젝트 생성
//   2. 왼쪽 메뉴 Project Settings > API 이동
//   3. "Project URL" -> url 에 붙여넣기
//   4. "anon public" 키 -> anonKey 에 붙여넣기
//   5. SQL Editor 에서 sql/schema.sql 파일 내용을 실행 (테이블 생성)
//
// ⚠️ anonKey는 "공개해도 되는" 키이지만, 그래도 GitHub에는 가급적
//    이 파일 자체를 올리지 않거나(.gitignore), 별도 비공개 저장소를
//    사용하는 것을 권장합니다. (README "보안 체크리스트" 참고)
// ============================================================

const SUPABASE_CONFIG = {
  url: 'https://YOUR_PROJECT_ID.supabase.co',
  anonKey: 'YOUR_SUPABASE_ANON_KEY'
};
