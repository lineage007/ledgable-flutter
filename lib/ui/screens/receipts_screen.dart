import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/page.dart';
import '../../api/models/receipt.dart';
import '../../app.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../shell.dart';
import '../widgets/common.dart';

final _receiptsProvider = FutureProvider.autoDispose<Paged<ReceiptSummary>>((ref) {
  ref.watch(authControllerProvider.select((state) => state.activeWorkspaceId));
  return ref.watch(receiptsRepositoryProvider).list(limit: 50);
});

/// Receipts already captured, newest first.
class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_receiptsProvider);
    final canWrite = ref.watch(canWriteProvider);

    return Scaffold(
      appBar: const WorkspaceAppBar(title: 'Receipts'),
      body: RefreshIndicator(
        onRefresh: () => refreshQuietly(() => ref.refresh(_receiptsProvider.future)),
        child: switch (snapshot) {
          AsyncError(:final error) => ListView(
            padding: const EdgeInsets.only(top: 80),
            children: [ErrorView(error: error, onRetry: () => ref.invalidate(_receiptsProvider))],
          ),
          AsyncData(:final value) when value.isEmpty => ListView(
            padding: const EdgeInsets.only(top: 60),
            children: [
              SizedBox(
                height: 400,
                child: EmptyState(
                  icon: Icons.photo_camera_rounded,
                  title: 'No receipts yet',
                  message:
                      'Photograph a receipt and Ledgable reads the vendor, '
                      'total and GST off it. It keeps the image for seven years.',
                  action: canWrite
                      ? ElevatedButton.icon(
                          onPressed: () => context.push(Routes.receiptCapture),
                          icon: const Icon(Icons.photo_camera_rounded),
                          label: const Text('Add a receipt'),
                        )
                      : null,
                ),
              ),
            ],
          ),
          AsyncData(:final value) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: value.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _ReceiptRow(receipt: value.items[index]),
          ),
          _ => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: const [
              _ReceiptSkeleton(),
              SizedBox(height: 10),
              _ReceiptSkeleton(),
              SizedBox(height: 10),
              _ReceiptSkeleton(),
            ],
          ),
        },
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.receipt});

  final ReceiptSummary receipt;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final extraction = receipt.extraction;
    final (tone, icon) = switch (receipt.ocrStatus) {
      OcrStatus.completed => (PillTone.positive, Icons.check_rounded),
      OcrStatus.failed => (PillTone.negative, Icons.error_outline_rounded),
      OcrStatus.skipped => (PillTone.neutral, Icons.remove_rounded),
      _ => (PillTone.warning, Icons.hourglass_empty_rounded),
    };

    return LedgerCard(
      onTap: () => context.push(Routes.receiptReview(receipt.id)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_rounded, size: 20, color: colors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [Dates.relative(receipt.createdAt), if (receipt.isMatched) 'matched'].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (extraction?.totalAmount != null)
                Text(
                  Money.format(extraction!.totalAmount),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 4),
              StatusPill(label: receipt.ocrStatus.label, tone: tone, icon: icon),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptSkeleton extends StatelessWidget {
  const _ReceiptSkeleton();

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      child: Row(
        children: [
          SkeletonBlock(width: 42, height: 42, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: 130, height: 14),
                SizedBox(height: 8),
                SkeletonBlock(width: 80, height: 10),
              ],
            ),
          ),
          SkeletonBlock(width: 64, height: 20, radius: 999),
        ],
      ),
    );
  }
}
