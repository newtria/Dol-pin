import 'payment_models.dart';

class PortOnePaymentMapper {
  const PortOnePaymentMapper._();

  static PaymentResult fromVerificationJson(Map<String, dynamic> data) {
    return PaymentResult(
      merchantUid: data['merchant_uid'] as String? ?? '',
      impUid: data['imp_uid'] as String?,
      reservationId: data['reservation_id'] as String?,
      roomId: data['room_id'] as String?,
      status: PaymentStatus.fromString(data['status'] as String? ?? ''),
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'KRW',
    );
  }
}
