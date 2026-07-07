import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/rental_item_model.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/reservation_model.dart';
import '../../../data/datasources/supabase_client.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/reservation_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/rental_provider.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/dolpin_button.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/safe_badge.dart';
import '../../../data/datasources/payment_service.dart';
import '../application/reservation_checkout_controller.dart';
import 'payment_screen.dart';

class ReservationScreen extends ConsumerWidget {
  const ReservationScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(rentalDetailProvider(itemId));

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.bookRental)),
      body: itemAsync.when(
        data: (item) => _ReservationBody(item: item),
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(rentalDetailProvider(itemId)),
        ),
      ),
    );
  }
}

class _ReservationBody extends ConsumerStatefulWidget {
  const _ReservationBody({required this.item});
  final RentalItemModel item;

  @override
  ConsumerState<_ReservationBody> createState() => _ReservationBodyState();
}

class _ReservationBodyState extends ConsumerState<_ReservationBody> {
  DateTimeRange? _dateRange;
  bool _isLoading = false;

  int get _days => _dateRange != null
      ? ReservationCheckoutPolicy.rentalDays(_dateRange!.start, _dateRange!.end)
      : 0;
  int get _rentalFee => widget.item.dailyPrice * _days;
  int get _total => _rentalFee + widget.item.deposit;

  Future<void> _selectDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      final end = range.end.isAfter(range.start)
          ? range.end
          : range.start.add(const Duration(days: 1));
      setState(() => _dateRange = DateTimeRange(start: range.start, end: end));
    }
  }

  Future<void> _proceed() async {
    if (_dateRange == null) return;

    final l = AppLocalizations.of(context)!;
    final item = widget.item;
    if (!ReservationCheckoutPolicy.isWithinAvailability(
      item: item,
      rentalDate: _dateRange!.start,
      returnDate: _dateRange!.end,
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.datesOutsideAvailability)));
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    if (!ReservationCheckoutPolicy.isCheckoutCurrencyConfigured(
      item.currency,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.paymentNotConfigured(item.currency))),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ref
            .read(reservationRepositoryProvider)
            .createIntent(
              itemId: item.id,
              rentalDate: _dateRange!.start,
              returnDate: _dateRange!.end,
            ),
        ref.read(authRepositoryProvider).getProfile(item.lenderId),
      ]);

      if (!mounted) return;
      final reservationResult = results[0];
      final profileResult = results[1] as Result<UserModel?>;

      if (reservationResult.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.reservationFailed}: ${reservationResult.failure.message}',
            ),
          ),
        );
        return;
      }

      final lenderName = profileResult.when(
        success: (user) => user?.nickname ?? l.guest,
        failure: (_) => l.guest,
      );
      final reservation = reservationResult.value as ReservationModel;

      // Navigate to payment screen (KRW only for now)
      if (item.currency == 'KRW') {
        final gateway =
            ref.read(paymentServiceProvider).gatewayForCurrency('KRW')
                as PortOneGateway;
        final userProfile = ref.read(currentUserProvider).valueOrNull;
        final params = gateway.buildParams(
          reservationId: reservation.id,
          amount: reservation.totalPaid,
          itemName: item.title,
          buyerName: userProfile?.nickname ?? l.guest,
          buyerTel: userProfile?.phone ?? '',
        );
        final attemptResult = await ref
            .read(reservationRepositoryProvider)
            .startPaymentAttempt(
              reservationId: reservation.id,
              merchantUid: params.merchantUid,
            );
        if (attemptResult.isFailure) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(attemptResult.failure.message)),
          );
          return;
        }

        if (!mounted) return;
        final paymentResult = await Navigator.push<PaymentResult>(
          context,
          MaterialPageRoute(builder: (_) => PaymentScreen(params: params)),
        );

        if (!mounted) return;
        if (paymentResult == null ||
            paymentResult.status != PaymentStatus.success) {
          await ref.read(reservationRepositoryProvider).cancel(reservation.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.reservationFailed),
            ),
          );
          return;
        }
        final impUid = paymentResult.impUid;
        if (impUid == null || impUid.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.paymentVerificationFailed)));
          context.goNamed(
            'reservationDetail',
            pathParameters: {'id': reservation.id},
          );
          return;
        }

        final authJwt = ref
            .read(supabaseProvider)
            .auth
            .currentSession
            ?.accessToken;
        final verificationResult = await const PaymentVerificationRetrier()
            .verify(gateway: gateway, paymentRef: impUid, authJwt: authJwt);
        if (!mounted) return;
        if (verificationResult.isFailure ||
            verificationResult.value.status != PaymentStatus.success) {
          if (verificationResult.isFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(verificationResult.failure.message)),
            );
            context.goNamed(
              'reservationDetail',
              pathParameters: {'id': reservation.id},
            );
            return;
          }
          if (verificationResult.value.status != PaymentStatus.success) {
            await ref
                .read(reservationRepositoryProvider)
                .cancel(reservation.id);
          }
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.paymentVerificationFailed)));
          return;
        }

        var roomId = verificationResult.value.roomId;
        if (roomId == null || roomId.isEmpty) {
          final roomResult = await ref
              .read(chatRepositoryProvider)
              .getOrCreateRoom(
                userId,
                item.lenderId,
                itemId: item.id,
                reservationId: reservation.id,
              );
          if (roomResult.isSuccess) {
            roomId = roomResult.value;
          }
        }

        if (!mounted) return;
        if (roomId == null || roomId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.chatWillBeAvailableAfterConfirmation)),
          );
          context.goNamed(
            'reservationDetail',
            pathParameters: {'id': reservation.id},
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reservationCreated),
            backgroundColor: AppColors.success,
          ),
        );
        context.pushReplacementNamed(
          'chatRoom',
          pathParameters: {'roomId': roomId, 'userId': item.lenderId},
          queryParameters: {'name': lenderName},
        );
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.reservationFailed}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final item = widget.item;
    final currency = item.currency;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.photos.isNotEmpty
                    ? CachedImage(
                        imageUrl: item.photos.first,
                        width: 80,
                        height: 80,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.surfaceLight,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyFormatter.format(item.dailyPrice, currency)} ${l.perDay}',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _selectDates,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    _dateRange != null
                        ? DateFormatter.rentalPeriod(
                            _dateRange!.start,
                            _dateRange!.end,
                          )
                        : l.selectRentalDates,
                    style: TextStyle(
                      color: _dateRange != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (_dateRange != null)
                    Text(
                      l.dayCount(_days),
                      style: const TextStyle(color: AppColors.primary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l.priceSummary,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _PriceRow(
            label: l.rentalFeeLabel(
              CurrencyFormatter.format(item.dailyPrice, currency),
              _days,
            ),
            value: CurrencyFormatter.format(_rentalFee, currency),
          ),
          const SizedBox(height: 8),
          _PriceRow(
            label: l.depositRefundable,
            value: CurrencyFormatter.format(item.deposit, currency),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.divider),
          ),
          _PriceRow(
            label: l.total,
            value: CurrencyFormatter.format(_total, currency),
            isBold: true,
          ),
          const SizedBox(height: 24),
          SafeBadge(label: l.escrowProtectedFull),
          const SizedBox(height: 40),
          DolpinButton(
            label: l.proceedToPayment,
            isLoading: _isLoading,
            onPressed: _dateRange != null ? _proceed : null,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}
