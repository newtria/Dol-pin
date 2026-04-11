# dol-pin (돌핀)

> **Your concert, one tap away. Safe. Fast. Local.**

K-pop 콘서트 물품 C2C 대여 마켓플레이스.

X(트위터) DM 거래의 사기 위험, 번개장터의 대여 기능 부재, 인도네시아 수작업 대여 계정의 비효율을 하나의 앱으로 해결한다.

## Stack

- **Frontend**: Flutter (iOS / Android)
- **Backend**: Supabase (Auth, Database, Storage, Edge Functions)
- **AI**: Gemini (물품 인증)
- **i18n**: KO / EN / JA / ID

## Core Features (MVP)

- 콘서트 기반 물품 필터링
- Escrow 결제 (보증금 + 대여료)
- 실시간 채팅
- 대여자 등급 시스템
- 대여 전/후 사진 비교 (Gemini VLM 기반 자동 태그 + 반납 검증)

## Roadmap

- Bluetooth 정품 인증 (응원봉) — Phase 2. 현재 `BluetoothService`는 stub이며
  UI에서 노출되지 않는다. 실제 구현은 `flutter_blue_plus` + 제조사별 BLE
  characteristic 스펙 확보가 전제.

## Target Market

- Phase 1: Korea + Indonesia + Japan
- Phase 2: Global (SEA, NA, EU)
