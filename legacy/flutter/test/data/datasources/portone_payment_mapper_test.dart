import 'package:dolpin/data/datasources/payment_service.dart';
import 'package:dolpin/data/datasources/portone_payment_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PortOnePaymentMapper', () {
    test('maps verify-payment JSON into PaymentResult', () {
      final result = PortOnePaymentMapper.fromVerificationJson({
        'merchant_uid': 'merchant-1',
        'imp_uid': 'imp-1',
        'reservation_id': 'reservation-1',
        'room_id': 'room-1',
        'status': 'success',
        'amount': 1000.0,
        'currency': 'KRW',
      });

      expect(result.merchantUid, 'merchant-1');
      expect(result.impUid, 'imp-1');
      expect(result.reservationId, 'reservation-1');
      expect(result.roomId, 'room-1');
      expect(result.status, PaymentStatus.success);
      expect(result.amount, 1000);
      expect(result.currency, 'KRW');
    });

    test('uses safe defaults for incomplete provider JSON', () {
      final result = PortOnePaymentMapper.fromVerificationJson({});

      expect(result.merchantUid, '');
      expect(result.status, PaymentStatus.failed);
      expect(result.amount, 0);
      expect(result.currency, 'KRW');
    });
  });
}
