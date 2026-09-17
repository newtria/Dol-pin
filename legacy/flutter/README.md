# Flutter 보관본 — 현행 앱 아님

현재 앱은 `../../apps/mobile`의 React Native + Expo, 웹은 `../../apps/web`의
Next.js입니다. 앱 실행·빌드·CI·의존성 업데이트는 저장소 루트의 npm 명령을 사용합니다.

이 디렉터리는 기존 Flutter 소스, 테스트, iOS/Android 프로젝트와 SDK 설정을
삭제하지 않고 모아 둔 참고 자료입니다. 2026-09-17에 분리했으며 보관 직전
기준 커밋은 `3c3057768b54ee2d3a4f6d592181170510ea785a`입니다.

- `lib/`, `test/`, `ios/`, `android/`, `pubspec.*`, `analysis_options.yaml`,
  `mise.toml`, `TODO.md`와 Flutter 전용 이미지 디렉터리를 그대로 옮겼습니다.
- 당시 루트 `.env.example`도 보존합니다. 현재 환경 설정은 루트와 각 앱의 예제를 사용합니다.
- npm workspace, 현행 CI와 Dependabot 대상이 아닙니다. 현재 서버와의 실행 호환성을 보장하지 않습니다.
- 당시 테스트 일부는 저장소 루트의 서버·문서를 상대 경로로 읽습니다.
  당시 전체 환경을 재현해야 하면 위 기준 커밋을 별도 checkout으로 확인하세요.
- 공통 서버의 거래·결제·환불·분쟁 처리는 루트 `supabase/`에 남아 있습니다.
- `TODO.md`는 당시 계획 기록이며 현행 제품 범위나 진행 상태가 아닙니다.
