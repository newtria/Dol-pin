import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/rental_item_model.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/reservation_model.dart';
import '../../../data/models/user_model.dart';
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
import 'payment_screen.dart';

class ReservationScreen extends ConsumerWidget {
  const ReservationScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(rentalDetailProvider(itemId));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.bookRental),
      ),
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

  int get _days =>
      _dateRange != null ? _dateRange!.duration.inDays.clamp(1, 365) : 0;
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
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  Future<void> _proceed() async {
    if (_dateRange == null) return;

    final item = widget.item;
    if (item.availableFrom != null && item.availableTo != null) {
      if (_dateRange!.start.isBefore(item.availableFrom!) ||
          _dateRange!.end.isAfter(item.availableTo!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.datesOutsideAvailability)),
        );
        return;
      }
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ref.read(reservationRepositoryProvider).create({
          'item_id': item.id,
          'borrower_id': userId,
          'lender_id': item.lenderId,
          'rental_date': _dateRange!.start.toIso8601String().split('T').first,
          'return_date': _dateRange!.end.toIso8601String().split('T').first,
          'rental_fee': _rentalFee,
          'deposit': item.deposit,
          'total_paid': _total,
          'currency': item.currency,
          'status': ReservationStatus.pending.value,
        }),
        ref.read(authRepositoryProvider).getProfile(item.lenderId),
      ]);

      if (!mounted) return;
      final reservationResult = results[0] as Result<ReservationModel>;
      final profileResult = results[1] as Result<UserModel?>;

      if (reservationResult.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.reservationFailed}: ${reservationResult.failure.message}')),
        );
        return;
      }

      final lenderName = profileResult.when(
        success: (user) => user?.nickname ?? 'User',
        failure: (_) => 'User',
      );

      // Navigate to payment screen (KRW only for now)
      if (item.currency == 'KRW') {
        final gateway = ref.read(paymentServiceProvider).gatewayForCurrency('KRW') as PortOneGateway;
        final userProfile = ref.read(currentUserProvider).valueOrNull;
        final params = gateway.buildParams(
          // `value` is a ReservationModel (Freezed); .toString() inlines the
          // whole model. The server-side `extractReservationId` parser
          // requires the bare uuid in the merchant_uid `dolpin_<uuid>_<epoch>`.
          reservationId: reservationResult.value.id,
          amount: _total,
          itemName: item.title,
          buyerName: userProfile?.nickname ?? 'User',
          buyerTel: userProfile?.phone ?? '',
        );

        if (!mounted) return;
        final paymentResult = await Navigator.push<PaymentResult>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(params: params),
          ),
        );

        if (!mounted) return;
        if (paymentResult == null || paymentResult.status != PaymentStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.reservationFailed)),
          );
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.reservationCreated),
          backgroundColor: AppColors.success,
        ),
      );
      context.pushReplacementNamed(
        'chatRoom',
        pathParameters: {'userId': item.lenderId},
        queryParameters: {'name': lenderName},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.reservationFailed}: $e')),
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
                            _dateRange!.start, _dateRange!.end)
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _PriceRow(
            label: l.rentalFeeLabel(CurrencyFormatter.format(item.dailyPrice, currency), _days),
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
