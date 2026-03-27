import 'package:flutter/material.dart';
import 'package:iamport_flutter/iamport_payment.dart';
import 'package:iamport_flutter/model/payment_data.dart';
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
        Navigator.pop(context, PaymentResult(
          transactionId: result['imp_uid'] ?? '',
          status: result['success'] == 'true' ? PaymentStatus.success : PaymentStatus.failed,
          amount: params.amount,
          currency: 'KRW',
        ));
      },
    );
  }
}
