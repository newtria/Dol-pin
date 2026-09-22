# dol-pin (돌핀)

K-pop 콘서트에서 사용하는 한정된 품목을 개인 간 빌려 쓰는 C2C 대여 서비스입니다.
응원봉·촬영 기기·슬로건·의상 등 콘서트 물품이라는 제품 범위를 유지합니다.

현재 모바일 앱은 **React Native + Expo**, 소비자 웹은 **Next.js**입니다.
공통 Supabase backend와 TypeScript API 계약을 사용합니다.
기존 Flutter 클라이언트는 `legacy/flutter/`에 보관하며 현재 실행·빌드·CI 대상에 포함하지 않습니다.
현재 거래 통화는 한국 원화(KRW)입니다.

## 로컬 실행

Node.js 22.22 이상, Docker 호환 런타임, Supabase CLI가 필요합니다.

```bash
npm ci
supabase start -x vector,logflare
node scripts/setup-local-env.mjs
## iOS: 사용 가능한 기기의 UDID를 지정
xcrun simctl list devices available
npm run ios:build -- <SIMULATOR_UDID>
npm run ios:open -- <SIMULATOR_UDID>
# 별도 터미널
npm run web
```

Metro 개발 서버만 필요하면 `npm run mobile`을 사용합니다. 기본 iOS 실행·QA는
위 전용 앱 경로이며, 소스 변경 후에는 다시 빌드합니다.

`supabase/config.toml`의 전화번호/OTP fixture와 dummy SMS 설정은 로컬 검증용입니다.
실서비스 SMS 설정을 대체하지 않습니다.

```bash
npm run typecheck
npm run typecheck -w @dolpin/web
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
