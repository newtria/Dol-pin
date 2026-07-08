import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/reservation_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/reservation_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../application/reservation_action_controller.dart';
import '../application/reservation_detail_action_presenter.dart';
import '../widgets/reservation_detail_sections.dart';

class ReservationDetailScreen extends ConsumerWidget {
  const ReservationDetailScreen({super.key, required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationAsync = ref.watch(
      reservationDetailProvider(reservationId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.myRentals)),
      body: reservationAsync.when(
        data: (reservation) => _ReservationDetailBody(reservation: reservation),
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(reservationDetailProvider(reservationId)),
        ),
      ),
    );
  }
}

class _ReservationDetailBody extends ConsumerStatefulWidget {
  const _ReservationDetailBody({required this.reservation});

  final ReservationModel reservation;

  @override
  ConsumerState<_ReservationDetailBody> createState() =>
      _ReservationDetailBodyState();
}

class _ReservationDetailBodyState
    extends ConsumerState<_ReservationDetailBody> {
  bool _isBusy = false;

  ReservationModel get reservation => widget.reservation;

  Future<void> _runAction<T>(
    Future<Result<T>> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _isBusy = true);
    try {
      final result = await action();
      if (!mounted) return;
      result.when(
        success: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: AppColors.success,
            ),
          );
          ref.invalidate(reservationDetailProvider(reservation.id));
          final userId = ref.read(currentUserIdProvider);
          if (userId != null) {
            ref.invalidate(borrowerReservationsProvider(userId));
            ref.invalidate(lenderReservationsProvider(userId));
          }
        },
        failure: (f) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(f.message)));
        },
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmReturn() async {
    if (_isBusy) return;
    final l = AppLocalizations.of(context)!;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (photo == null) return;

    await _runAction(
      () => ref
          .read(reservationActionControllerProvider)
          .confirmReturnPhoto(
            userId: userId,
            reservation: reservation,
            file: File(photo.path),
          ),
      successMessage: l.returnConfirmed,
    );
  }

  Future<void> _dispute() async {
    final l = AppLocalizations.of(context)!;
    final reason = await _promptOptionalText(
      title: l.disputeReason,
      hint: l.describeIssue,
    );
    if (!mounted) return;
    await _runAction(
      () => ref
          .read(reservationActionControllerProvider)
          .openDispute(reservation.id, reason: reason),
      successMessage: l.disputeOpened,
    );
  }

  Future<void> _settle() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await _confirmAction(
      title: l.settleDeposit,
      message: l.confirmSettlementMessage,
    );
    if (!confirmed || !mounted) return;
    await _runAction(
      () => ref.read(reservationActionControllerProvider).settle(reservation),
      successMessage: l.reservationSettled,
    );
  }

  Future<void> _refundPaid() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await _confirmAction(
      title: l.cancelAndRefund,
      message: l.confirmRefundMessage,
    );
    if (!confirmed || !mounted) return;
    await _runAction(
      () =>
          ref.read(reservationActionControllerProvider).refundPaid(reservation),
      successMessage: l.reservationCancelled,
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _openChat() async {
    if (_isBusy) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _isBusy = true);
    try {
      final result = await ref
          .read(reservationActionControllerProvider)
          .openChat(reservation: reservation, currentUserId: userId);
      if (!mounted) return;
      result.when(
        success: (target) => context.pushNamed(
          'chatRoom',
          pathParameters: {
            'roomId': target.roomId,
            'userId': target.otherUserId,
          },
          queryParameters: {
            'name':
                target.partnerNickname ?? AppLocalizations.of(context)!.guest,
          },
        ),
        failure: (failure) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message))),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<String?> _promptOptionalText({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final status = ReservationStatus.fromString(reservation.status);
    final isBorrower = userId == reservation.borrowerId;
    final isLender = userId == reservation.lenderId;
    final canOpenChat = ref
        .read(reservationActionControllerProvider)
        .canOpenChat(reservation);
    final legalTargets = userId == null
        ? const <ReservationStatus>{}
        : ref
              .read(reservationActionControllerProvider)
              .legalNextStates(reservation: reservation, userId: userId);
    final actions = ReservationActionPresenter.actionsFor(
      reservation: reservation,
      status: status,
      legalTargets: legalTargets,
      isBorrower: isBorrower,
      isLender: isLender,
      canOpenChat: userId != null && canOpenChat,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ReservationStatusHeader(status: status),
        const SizedBox(height: 20),
        ReservationDetailsSummary(reservation: reservation),
        const SizedBox(height: 12),
        ReservationActionButtons(
          isBusy: _isBusy,
          actions: actions,
          onAction: _handleAction,
        ),
      ],
    );
  }

  void _handleAction(ReservationDetailActionType action) {
    final l = AppLocalizations.of(context)!;
    switch (action) {
      case ReservationDetailActionType.openChat:
        unawaited(_openChat());
        break;
      case ReservationDetailActionType.cancel:
        unawaited(
          _runAction(
            () => ref
                .read(reservationActionControllerProvider)
                .cancel(reservation.id),
            successMessage: l.reservationCancelled,
          ),
        );
        break;
      case ReservationDetailActionType.confirmPickup:
        unawaited(
          _runAction(
            () => ref
                .read(reservationActionControllerProvider)
                .confirmPickup(reservation.id),
            successMessage: l.pickupConfirmed,
          ),
        );
        break;
      case ReservationDetailActionType.refundPaid:
        unawaited(_refundPaid());
        break;
      case ReservationDetailActionType.confirmReturn:
        unawaited(_confirmReturn());
        break;
      case ReservationDetailActionType.settle:
        unawaited(_settle());
        break;
      case ReservationDetailActionType.dispute:
        unawaited(_dispute());
        break;
    }
  }
}
