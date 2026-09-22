import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/share_helper.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/rental_item_model.dart';
import '../../../providers/rental_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/dialogs/report_dialog.dart';
import '../application/item_detail_controller.dart';
import '../widgets/item_detail_sections.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(rentalDetailProvider(itemId));

    return Scaffold(
      body: itemAsync.when(
        data: (item) => _ItemDetailBody(item: item),
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(rentalDetailProvider(itemId)),
        ),
      ),
      bottomNavigationBar: itemAsync.whenOrNull(
        data: (item) => ItemBookBar(item: item),
      ),
    );
  }
}

class _ItemDetailBody extends ConsumerStatefulWidget {
  const _ItemDetailBody({required this.item});
  final RentalItemModel item;

  @override
  ConsumerState<_ItemDetailBody> createState() => _ItemDetailBodyState();
}

class _ItemDetailBodyState extends ConsumerState<_ItemDetailBody> {
  Future<void> _shareItem() async {
    final l = AppLocalizations.of(context)!;
    final item = widget.item;
    final price = CurrencyFormatter.format(item.dailyPrice, item.currency);
    final url = 'https://dolpin.app/item/${item.id}';
    final message = '${l.checkOutThisItem(item.title, price)}\n$url';
    await shareWithFallback(context, url: url, message: message);
  }

  Future<void> _reportItem() async {
    final l = AppLocalizations.of(context)!;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final result = await ReportDialog.show(context, widget.item.title);
    if (result != null && mounted) {
      final res = await ref
          .read(itemDetailControllerProvider)
          .reportItem(
            reporterId: userId,
            itemId: widget.item.id,
            reason: result['reason']!,
            description: result['description'],
          );
      if (!mounted) return;
      res.when(
        success: (_) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.reportSubmitted))),
        failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.reportFailed}: ${f.message}')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return CustomScrollView(
      slivers: [
        ItemDetailHeaderSliver(
          item: item,
          onShare: _shareItem,
          onReport: _reportItem,
        ),
        SliverToBoxAdapter(child: ItemDetailContent(item: item)),
      ],
    );
  }
}
