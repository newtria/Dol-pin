enum PaymentStatus {
  success,
  pending,
  failed;

  static PaymentStatus fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => failed);
}

/// Payment result data.
///
/// Two distinct identifiers live here because PortOne (and most PG providers)
/// expose a merchant-side order id and a PG-side transaction id that are
/// generated at different points in the flow:
///
///   * [merchantUid] — our own order id, generated client-side before payment
///     is initiated (e.g. `dolpin_<reservationId>_<epoch>`). Always set.
///   * [impUid]      — PortOne's imp_uid, issued **after** PortOne charges the
///     card. Null until the PortOne WebView callback fires.
///
/// The old single-field `transactionId` conflated the two and made it
/// impossible for callers to know which identifier to pass to server-side
/// verification or refund endpoints.
class PaymentResult {
  const PaymentResult({
    required this.merchantUid,
    this.impUid,
    this.reservationId,
    this.roomId,
    required this.status,
    required this.amount,
    required this.currency,
  });

  final String merchantUid;
  final String? impUid;
  final String? reservationId;
  final String? roomId;
  final PaymentStatus status;
  final int amount;
  final String currency;
}

/// Parameters for PortOne payment screen
class PortOnePaymentParams {
  final String merchantUid;
  final String pgProvider;
  final String payMethod;
  final int amount;
  final String itemName;
  final String buyerName;
  final String buyerTel;
  final String buyerEmail;

  const PortOnePaymentParams({
    required this.merchantUid,
    required this.pgProvider,
    required this.payMethod,
    required this.amount,
    required this.itemName,
    required this.buyerName,
    required this.buyerTel,
    this.buyerEmail = '',
  });
}
