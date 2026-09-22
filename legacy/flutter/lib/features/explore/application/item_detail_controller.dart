import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../data/repositories/report_repository.dart';

final itemDetailControllerProvider = Provider<ItemDetailController>((ref) {
  return ItemDetailController(
    reportRepository: ref.watch(reportRepositoryProvider),
  );
});

class ItemDetailController {
  const ItemDetailController({required ReportRepository reportRepository})
    : _reportRepository = reportRepository;

  final ReportRepository _reportRepository;

  Future<Result<void>> reportItem({
    required String reporterId,
    required String itemId,
    required String reason,
    String? description,
  }) {
    return _reportRepository.submitReport(
      reporterId: reporterId,
      reportedItemId: itemId,
      reason: reason,
      description: description,
    );
  }
}
