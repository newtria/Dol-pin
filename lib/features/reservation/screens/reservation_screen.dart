import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/rental_item_model.dart';
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

  ReservationCheckoutQuote? get _quote {
    final dateRange = _dateRange;
    if (dateRange == null) return null;
    return ReservationCheckoutPolicy.quote(
      item: widget.item,
      rentalDate: dateRange.start,
      returnDate: dateRange.end,
    );
  }

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
      final selection = ReservationCheckoutPolicy.normalizeSelection(
        range.start,
        range.end,
      );
      setState(
        () => _dateRange = DateTimeRange(
          start: selection.rentalDate,
          end: selection.returnDate,
        ),
      );
    }
  }

  Future<void> _proceed() async {
    final quote = _quote;
    if (quote == null) return;

    final l = AppLocalizations.of(context)!;
    final item = widget.item;
    if (quote.validationError ==
        ReservationCheckoutValidationError.datesOutsideAvailability) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.datesOutsideAvailability)));
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    if (quote.validationError ==
        ReservationCheckoutValidationError.paymentNotConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.paymentNotConfigured(item.currency))),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userProfile = ref.read(currentUserProvider).valueOrNull;
      final attemptResult = await ref
          .read(reservationCheckoutControllerProvider)
          .startPortOneCheckout(
            item: item,
            rentalDate: quote.selection.rentalDate,
            returnDate: quote.selection.returnDate,
            buyerName: userProfile?.nickname ?? l.guest,
            buyerTel: userProfile?.phone ?? '',
            fallbackLenderName: l.guest,
          );
      if (!mounted) return;
      if (attemptResult.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l.reservationFailed}: ${attemptResult.failure.message}',
            ),
          ),
        );
        return;
      }

      final attempt = attemptResult.value;
      final paymentResult = await Navigator.push<PaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(params: attempt.paymentParams),
        ),
      );
      if (!mounted) return;

      final completionResult = await ref
          .read(reservationCheckoutControllerProvider)
          .completePortOneCheckout(
            attempt: attempt,
            paymentResult: paymentResult,
            currentUserId: userId,
          );
      if (!mounted) return;
      if (completionResult.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l.reservationFailed}: ${completionResult.failure.message}',
            ),
          ),
        );
        return;
      }

      final completion = completionResult.value;
      final failure = completion.failure;
      if (failure != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }

      switch (completion.nextStep) {
        case CheckoutNextStep.chat:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.reservationCreated),
              backgroundColor: AppColors.success,
            ),
          );
          context.pushReplacementNamed(
            'chatRoom',
            pathParameters: {
              'roomId': completion.roomId!,
              'userId': completion.lenderId,
            },
            queryParameters: {'name': completion.lenderName},
          );
          break;
        case CheckoutNextStep.reservationDetail:
          if (failure == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.chatWillBeAvailableAfterConfirmation)),
            );
          }
          context.goNamed(
            'reservationDetail',
            pathParameters: {'id': completion.reservationId},
          );
          break;
        case CheckoutNextStep.stay:
          if (failure == null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.reservationFailed)));
          }
          break;
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
    final quote = _quote;
    final days = quote?.days ?? 0;
    final rentalFee = quote?.rentalFee ?? 0;
    final total = quote?.total ?? item.deposit;

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
                      l.dayCount(days),
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
              days,
            ),
            value: CurrencyFormatter.format(rentalFee, currency),
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
            value: CurrencyFormatter.format(total, currency),
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
