import 'package:flutter/material.dart';
// Migrated from `iamport_flutter` (deprecated by PortOne) to `portone_flutter`.
// The widget class name stays `IamportPayment` for V1 backwards compatibility;
// only the package name changes. portone_flutter 0.12 keeps the flat
// `lib/iamport_payment.dart` layout; the 1.0 line moves to
// `lib/v1/iamport_payment.dart` and adds a V2 widget at
// `lib/v2/portone_payment.dart`. We pin to 0.12 due to a `json_annotation`
// conflict with `custom_lint` — see pubspec.yaml for the rationale.
import 'package:portone_flutter/iamport_payment.dart';
import 'package:portone_flutter/model/payment_data.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/env.dart';
import '../../../data/datasources/payment_service.dart';
import '../../../l10n/app_localizations.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key, required this.params});
  final PortOnePaymentParams params;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return IamportPayment(
      appBar: AppBar(
        title: Text(l.proceedToPayment),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      initialChild: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              l.proceedToPayment,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
      userCode: Env.portOneImpCode,
      data: PaymentData(
        pg: params.pgProvider,
        payMethod: params.payMethod,
        name: params.itemName,
        merchantUid: params.merchantUid,
        amount: params.amount,
        buyerName: params.buyerName,
        buyerTel: params.buyerTel,
        buyerEmail: params.buyerEmail,
        appScheme: 'com.dolpin.app',
      ),
      callback: (Map<String, String> result) {
        Navigator.pop(
          context,
          PaymentResult(
            merchantUid: result['merchant_uid'] ?? params.merchantUid,
            impUid: result['imp_uid'],
            status: result['success'] == 'true'
                ? PaymentStatus.success
                : PaymentStatus.failed,
            amount: params.amount,
            currency: 'KRW',
          ),
        );
      },
    );
  }
}
