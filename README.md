# dol-pin (돌핀)

K-pop 콘서트에서 사용하는 한정된 품목을 개인 간 빌려 쓰는 C2C 대여 서비스입니다.
응원봉·촬영 기기·슬로건·의상 등 콘서트 물품이라는 제품 범위를 유지합니다.

현재 모바일 앱은 **React Native + Expo**, 소비자 웹은 **Next.js**입니다.
공통 Supabase backend와 TypeScript API 계약을 사용합니다.
기존 Flutter 클라이언트는 `legacy/flutter/`에 보관하며 현재 실행·빌드·CI 대상에 포함하지 않습니다.
현재 거래 통화는 한국 원화(KRW)입니다.

## Currently implemented

| 영역 | 코드와 실구동으로 확인한 범위 |
| --- | --- |
| 모바일 | React Native + Expo: 이메일 가입·로그인, 보조 전화번호·소셜 인증, 프로필, 물품 탐색·등록·사진 업로드·상세 |
| 소비자 웹 | Next.js: 동일 backend를 통한 인증·탐색·등록·상세 |
| 예약 | 모바일·웹의 요청, 대여자 수락/거절, 요청 취소, 거래 목록·상세 |
| 서버 권한 | RPC 역할 검사, 직접 거래 UPDATE 차단, RLS, 상품 허용 필드·Storage 경로 제한 |
| 일관성 | 서버 요금 계산, 당일 대여, 동시 수락 충돌 제약, 수락 조건 snapshot, 명령 재시도·이력 |
| 만료 | 매분 미결제 예약 만료. 결제 결과 불명 작업은 해제하지 않고 보존 |
| 상태 관리 | 서버 데이터는 TanStack Query, 웹 검색은 URL, 모바일 탐색·예약 초안은 Zustand, 폼은 RHF + Zod |

**전체 거래 서비스는 아직 출시 가능한 상태가 아닙니다.** 새 클라이언트의
토스 결제·인수·비공개 반납 증빙·환불·복구 명령은 구현했고, 실제 로컬 DB와
결제사 모의 응답을 사용한 자동 QA로 검증합니다. 실제 PG 승인·환불과 배포 환경 복구는 미검증입니다.
Flutter 보관본의 기능을 현행 앱의 구현으로 취급하지 않습니다.
서버의 PortOne 호환 처리는 `supabase/`에서 유지합니다. 기존 운영자 분쟁 해결 Edge Function도
보존하지만 새 `/ops` 권한·복구 경로에는 아직 연결하지 않았습니다.

검증은 로컬 Supabase의 실제 Auth/Storage/PostgreSQL, iPhone 17e 시뮬레이터,
Next.js production 브라우저에서 수행했습니다. 화면의 상품·계정은 합성
검증 데이터이며 실제 사용자·매출·운영 실적을 뜻하지 않습니다.

- [검증 기록](docs/rewrite-verification.md)
- [RN 예약 요청](docs/verification/rn-rental-request.png)
- [RN에서 수락한 거래의 웹 화면](docs/verification/web-rn-rental.png)
- [웹 예약 초안 복원](docs/verification/web-rental-draft.png)

iOS 로컬 실행은 Expo Go 대신 전용 앱을 사용합니다. 빌드·실행·반복 시작 QA는
[iOS 실행 안내](docs/ios-runtime.md)를 따릅니다.

## Design intent

```text
React Native + Expo ─┐
                     ├─ 공통 API 계약 ─ Supabase Auth / RLS / Storage
Next.js consumer ────┘                       │
                                      PostgreSQL RPC
                                  예약 권한·잠금·원자 변경·이력
                                             │
                                      Edge Functions
                                      결제·웹훅·복구
                                             │
                                      Toss / PortOne
```

클라이언트는 거래 상태를 직접 쓰지 않습니다. DB 내부의 원자 변경은 RPC,
외부 결제 시스템과의 통신은 Edge Functions가 담당합니다. 타입과 입력
계약을 공유하며 금융 권한·상태 전이 규칙은 클라이언트에 복제하지 않습니다.

각 거래 단위는 RN → 실제 backend 검증 → Web 순서로 연결합니다.
PortOne V1/V2는 [비교 ADR](docs/adr/004-portone-version-investigation.md)에
따라 실제 테스트 채널과 앱 복귀 검증 후 결정합니다.

- [기존 코드 감사](docs/legacy-audit.md)
- [아키텍처](docs/architecture.md)
- [상태 전이와 구현된 예약 계약](docs/rental-state-machine.md)
- [전체 실행 계획](docs/rewrite-plan.md)

자동 거래 QA 실행 방법과 복구 배포 조건: [QA 안내](docs/qa.md).

## Planned

- 실제 PG 테스트 채널의 승인·취소 및 네이티브 결제 앱 복귀 검증
- 배포 환경의 Vault·복구 스케줄 구성과 운영 모니터링
- 결제사 외부에서 발생한 수동 취소·분쟁의 운영 대응
- `/ops` 거래 조사·분쟁·reconciliation
- 교차 클라이언트 거래 E2E와 재현 가능한 시연

기존 예약 생성 RPC의 일반 클라이언트 권한은 회수했습니다. 새 결제 경로 검증
전에 이 migration만 운영 DB에 먼저 배포하지 않습니다.

## Non-goals

범용 렌탈·중고거래로의 확장, 해외 결제, Bluetooth 정품 인증, 추가 AI,
추천·커뮤니티 고도화, 자동 대여료 지급, 가짜 지표 dashboard, microservices,
Kafka와 full event sourcing은 이번 재편 범위에서 제외합니다.

## Redacted

실제 사용자 정보, 개인 연락처, PG 자격증명, 운영 거래·분쟁 기록은 포함하지
않습니다. 공개 예제에는 합성 사진과 로컬 테스트 데이터만 사용합니다.

## 로컬 실행

Node.js 22.22 이상, Docker 호환 런타임, Supabase CLI가 필요합니다.
대용량 VM·이미지·의존성을 외장 SSD에 두는 구성은 [로컬 런타임 안내](docs/local-runtime.md)를 참고하세요.

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
실서비스 SMS 설정을 대체하지 않습니다. Next 개발 모드의 IAB 로딩 문제는
검증 기록에 남겼으며, 브라우저 실구동 증거는 `build` + `start` 기준입니다.

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
