# dol-pin (돌핀)

> **Your concert, one tap away. Safe. Fast. Local.**

K-pop 콘서트 물품 C2C 대여 마켓플레이스.

X(트위터) DM 거래의 사기 위험, 번개장터의 대여 기능 부재, 인도네시아 수작업 대여 계정의 비효율을 하나의 앱으로 해결한다.

## Stack

- **Frontend**: Flutter (iOS / Android)
- **Backend**: Supabase (Auth, Database, Storage, Edge Functions)
- **AI**: Gemini (물품 인증)
- **i18n**: KO / EN / JA / ID

## Core Features (Late MVP)

- 콘서트 기반 물품 필터링
- KRW / PortOne 기준 예약 결제 검증
- 예약 기반 채팅
- 픽업, 반납 사진 업로드, 보증금 반환 흐름
- 운영자 분쟁 해결 Edge Function
- 대여자 신뢰 표시 모델

## Roadmap

- Bluetooth 정품 인증 (응원봉) — Phase 2. 현재 `BluetoothService`는 stub이며
  UI에서 노출되지 않는다. 실제 구현은 `flutter_blue_plus` + 제조사별 BLE
  characteristic 스펙 확보가 전제.
- 자동 전후 사진 판정 — 현재는 등록 사진 분석과 반납 사진 업로드 검증 중심이다.
- 자동 lender payout — 현재 대여료 지급은 운영/배치 정산 대상이다.

## Target Market

- Phase 1: KRW 결제가 가능한 한국 중심 MVP
- Phase 2: Indonesia / Japan localization + payment adapter hardening
- Phase 3: Global expansion

## Release Gates

```bash
mise exec -- flutter analyze
mise exec -- flutter test
node scripts/release-preflight.mjs --structure-only
```

실제 staging/production 배포 전에는 `docs/ops-runbook.md`의 full preflight,
Supabase migration/function deploy, PortOne sandbox receipt, iOS lifecycle gate를
모두 통과시킨다.
