import 'package:dolpin/core/errors/result.dart';
import 'package:dolpin/data/repositories/report_repository.dart';
import 'package:dolpin/features/explore/application/item_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('ItemDetailController', () {
    test('delegates item reports to the report repository', () async {
      final reportRepository = _FakeReportRepository();
      final controller = ItemDetailController(
        reportRepository: reportRepository,
      );

      final result = await controller.reportItem(
        reporterId: 'reporter-1',
        itemId: 'item-1',
        reason: 'fraud',
        description: 'not real',
      );

      expect(result.isSuccess, isTrue);
      expect(reportRepository.reportPayload, {
        'reporterId': 'reporter-1',
        'reportedItemId': 'item-1',
        'reason': 'fraud',
        'description': 'not real',
      });
    });
  });
}

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository() : super(MockSupabaseClient());

  Map<String, dynamic>? reportPayload;

  @override
  Future<Result<void>> submitReport({
    required String reporterId,
    String? reportedUserId,
    String? reportedItemId,
    required String reason,
    String? description,
  }) async {
    reportPayload = {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reportedItemId': reportedItemId,
      'reason': reason,
      'description': description,
    }..removeWhere((_, value) => value == null);
    return const Success<void>(null);
  }
}
