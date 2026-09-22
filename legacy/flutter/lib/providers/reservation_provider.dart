import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/reservation_model.dart';
import '../data/repositories/reservation_repository.dart';

final borrowerReservationsProvider = FutureProvider.autoDispose
    .family<List<ReservationModel>, String>((ref, borrowerId) async {
      final result = await ref
          .watch(reservationRepositoryProvider)
          .getByBorrower(borrowerId);
      return result.when(success: (list) => list, failure: (f) => throw f);
    });

final lenderReservationsProvider = FutureProvider.autoDispose
    .family<List<ReservationModel>, String>((ref, lenderId) async {
      final result = await ref
          .watch(reservationRepositoryProvider)
          .getByLender(lenderId);
      return result.when(success: (list) => list, failure: (f) => throw f);
    });

final reservationDetailProvider = FutureProvider.autoDispose
    .family<ReservationModel, String>((ref, id) async {
      final result = await ref.watch(reservationRepositoryProvider).getById(id);
      return result.when(success: (res) => res, failure: (f) => throw f);
    });
