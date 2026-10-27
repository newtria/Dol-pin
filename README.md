# dol-pin (돌핀)

K-pop 콘서트에서 사용하는 한정된 품목을 개인 간 빌려 쓰는 C2C 대여 서비스입니다.
응원봉·촬영 기기·슬로건·의상 등 콘서트 물품이라는 제품 범위를 유지합니다.

현재 모바일 앱은 **React Native + Expo**, 소비자 웹은 **Next.js**입니다.
공통 Supabase backend와 TypeScript API 계약을 사용합니다.
기존 Flutter 클라이언트는 `legacy/flutter/`에 보관하며 현재 실행·빌드·CI 대상에 포함하지 않습니다.
현재 거래 통화는 한국 원화(KRW)입니다.

## 로컬 실행

Node.js 22.22 이상(저장소 기준 22.22.3), 실행 중인 Docker 호환 런타임,
Supabase CLI 2.107.0 이상이 필요합니다. 별도의 Supabase 클라우드 프로젝트나
이전 개발자의 `.env`, 외장 디스크, 절대 경로 설정은 필요하지 않습니다.

```bash
git clone https://github.com/heznpc/Dol-pin.git
cd Dol-pin
npm ci
npm run setup:local
npm run web
```

`npm ci`는 공개 제외 파일을 확인하는 Git 훅도 설치합니다. `setup:local`은 로컬
Supabase 시작, 미적용 마이그레이션 적용, 복구 작업 예약, 두 클라이언트의
`.env.local` 생성을 처리합니다. 재실행해도 DB를 초기화하지 않으며 기존 환경 파일의
다른 설정은 보존합니다. 생성된 파일에는 공개 클라이언트 키만 들어갑니다.

별도 터미널에서 거래·계정 API를 시작합니다.

```bash
npm run backend
```

웹은 `http://127.0.0.1:3000`, 로컬 가입 확인 메일함은 `http://127.0.0.1:55324`입니다.
회원가입·거래 동의 화면에는 개발용 안내 URL이 자동 설정됩니다. 이 안내는 개발 모드와
로컬 DB 조합에서만 열리며 실제 서비스 약관으로 사용할 수 없습니다.
실제 결제·소셜 로그인·알림 발송과 서비스 배포에는 각 제공자의 키와 정식 약관 URL이
별도로 필요합니다. 해당 설정 항목은 각 앱의 `.env.example`에 있습니다.

iOS Simulator를 사용하려면 macOS, Xcode와 iOS Simulator 런타임, CocoaPods(`pod`)가
추가로 필요합니다. 위 웹·backend를 켠 상태에서 사용 가능한 기기의 UDID를 지정합니다.

```bash
xcrun simctl list devices available
npm run ios:build -- <SIMULATOR_UDID>
npm run ios:open -- <SIMULATOR_UDID>
```

Metro 개발 서버만 필요하면 `npm run mobile`을 사용합니다. 기본 iOS 실행·QA는
위 전용 앱 경로이며, 소스 변경 후에는 다시 빌드합니다.
기본 로컬 주소는 웹·iOS Simulator용입니다. 실기기나 Android Emulator는 호스트 접근
주소가 달라 네트워크 설정이 필요합니다.

`supabase/config.toml`의 전화번호/OTP fixture와 dummy SMS 설정은 로컬 검증용입니다.
실서비스 SMS 설정을 대체하지 않습니다.

```bash
npm run typecheck
npm run typecheck -w @dolpin/web
npm run test:public
npm run test:setup
bash scripts/test-db.sh
node scripts/check-local-auth.mjs
node scripts/check-local-products.mjs
node scripts/check-local-rentals.mjs
npm run build -w @dolpin/web
npm run export -w @dolpin/mobile
```

## 저장소 기준

| 경로 | 역할 |
| --- | --- |
| `apps/mobile/` | 현행 React Native + Expo 앱, `npm run ios:open -- <UDID>` |
| `apps/web/` | 현행 Next.js 웹, `npm run web` |
| `packages/` | 공통 타입·입력 계약·API 클라이언트 |
| `supabase/` | 공통 DB·Edge Functions, PortOne 호환 처리 포함 |
| `legacy/flutter/` | 이전 Flutter 소스·테스트·네이티브 프로젝트의 보관본 |

루트 `mise.toml`은 Node.js를 지정합니다. npm workspace, CI, Dependabot은 현행
클라이언트와 backend를 대상으로 하며 Flutter SDK·pub 의존성을 설치하지 않습니다.
이전 구현의 기준과 경로는 [보관 안내](legacy/flutter/README.md)를 참고하세요.

README·CONTRIBUTING 등 공개 개발 문서는 커밋할 수 있습니다. 조사·기획·작업 메모는
`docs/`, `research/`, `notes/`, `reports/`, `scenarios/` 등 `.gitignore`에 지정한 로컬
작업 경로에 보관합니다. `npm run check:public`과 pre-push 훅은 제외 파일이 강제로
추가되거나 푸시할 중간 커밋에 남아 있는 경우에도 검사합니다. 이 검사는 파일 경로를
검사하므로 공개 파일 본문에 비밀키나 내부 자료를 넣지 않아야 합니다.
