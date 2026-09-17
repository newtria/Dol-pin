import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('storage return-photo contract', () {
    late String migration;
    late String storageService;
    late String reservationRepository;

    setUpAll(() {
      migration = File(
        'supabase/migrations/016_storage_rls.sql',
      ).readAsStringSync();
      storageService = File(
        'lib/data/datasources/storage_service.dart',
      ).readAsStringSync();
      reservationRepository = File(
        'lib/data/repositories/reservation_repository.dart',
      ).readAsStringSync();
    });

    test('uploads return evidence under the RLS-approved path shape', () {
      expect(storageService, contains('uploadReturnPhoto'));
      expect(storageService, contains('returns/\$reservationId/\$userId/'));
      expect(migration, contains('returns/<reservation_id>/<borrower_id>'));
      expect(migration, contains("(storage.foldername(name))[1] = 'returns'"));
      expect(
        migration,
        contains("(storage.foldername(name))[3] = auth.uid()::text"),
      );
      expect(migration, contains('r.borrower_id = auth.uid()'));
      expect(migration, contains("r.status = 'picked_up'"));
    });

    test('binds uploaded return evidence through an authenticated RPC', () {
      expect(
        reservationRepository,
        contains('DbFunctions.confirmReservationReturn'),
      );
      expect(reservationRepository, contains('p_return_photo'));
      expect(reservationRepository, isNot(contains(".update({'return_photo'")));
    });
  });
}
