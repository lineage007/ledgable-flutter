import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/receipt.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../widgets/common.dart';

/// What Ledgable read off a receipt, and whether it looks right.
///
/// This screen's job is honesty about confidence. OCR on a crumpled thermal
/// receipt is not reliable, and an accounting app that presents a guess as a
/// fact produces a wrong BAS. So: low overall confidence says so, the
/// lowest-confidence fields are marked individually, and two Australian GST
/// checks are run against what was read — whether the tax line is roughly one
/// eleventh of a GST-inclusive total, and whether a supplier that is not
/// GST-registered has somehow charged GST.
///
/// Editing an extraction is web-only today: the mobile API exposes no PATCH for
/// it. The screen says so rather than offering fields that cannot save.
class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  ConsumerState<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  StreamSubscription<ReceiptDetail>? _poll;
  ReceiptDetail? _receipt;
  Object? _error;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll?.cancel();
    setState(() {
      _error = null;
      _timedOut = false;
    });

    _poll = ref
        .read(receiptsRepositoryProvider)
        .pollUntilSettled(widget.receiptId)
        .listen(
          (receipt) {
            if (!mounted) return;
            setState(() => _receipt = receipt);
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _error = error);
          },
          onDone: () {
            if (!mounted) return;
            // The stream ends either at a terminal status or at the timeout. If
            // OCR is still running, say so instead of leaving a spinner.
            final status = _receipt?.ocrStatus;
            if (status != null && !status.isTerminal) {
              setState(() => _timedOut = true);
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          IconButton(
            onPressed: _startPolling,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Check again',
          ),
        ],
      ),
      body: SafeArea(
        child: switch ((receipt, _error)) {
          // An error wins over a partial receipt: a failed poll must not leave a
          // half-read extraction on screen looking authoritative.
          (_, final Object error) => ListView(
            padding: const EdgeInsets.only(top: 60),
            children: [ErrorView(error: error, onRetry: _startPolling)],
          ),
          (null, _) => const _ReadingReceipt(status: OcrStatus.pending),
          (final ReceiptDetail value, _) => _ReceiptBody(
            receipt: value,
            timedOut: _timedOut,
            onCheckAgain: _startPolling,
          ),
        },
      ),
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody({required this.receipt, required this.timedOut, required this.onCheckAgain});

  final ReceiptDetail receipt;
  final bool timedOut;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    if (!receipt.ocrStatus.isTerminal) {
      return _ReadingReceipt(
        status: receipt.ocrStatus,
        timedOut: timedOut,
        onCheckAgain: onCheckAgain,
      );
    }

    if (receipt.ocrStatus == OcrStatus.failed) {
      return _CouldNotRead(receipt: receipt);
    }

    final extraction = receipt.canonical;
    if (extraction == null) {
      return _CouldNotRead(receipt: receipt);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (extraction.isLowConfidence) ...[
          _Advisory(
            tone: PillTone.warning,
            icon: Icons.help_outline_rounded,
            title: 'Check these figures',
            message:
                'Ledgable is only '
                '${((extraction.confidence ?? 0) * 100).round()}% sure it read this '
                'receipt correctly. Compare them with the paper before you rely on '
                'them.',
          ),
          const SizedBox(height: 12),
        ],
        if (extraction.hasGstMismatch) ...[
          _Advisory(
            tone: PillTone.negative,
            icon: Icons.report_gmailerrorred_rounded,
            title: 'GST charged by a supplier that is not registered',
            message:
                'The ABN lookup says this supplier is not registered for GST, '
                'so it cannot charge GST. Claiming the GST on this receipt would '
                'overstate your credits. Check the receipt and fix it on the web.',
          ),
          const SizedBox(height: 12),
        ] else if (extraction.gstAboveMaximum) ...[
          _Advisory(
            tone: PillTone.warning,
            icon: Icons.calculate_outlined,
            title: 'The GST figure does not add up',
            message:
                'GST on a total of ${Money.format(extraction.totalAmount)} can be '
                'at most ${Money.format(extraction.impliedGst)}, one eleventh. The '
                'receipt reads ${Money.format(extraction.taxAmount)}, which is more. '
                'Worth a second look.',
          ),
          const SizedBox(height: 12),
        ] else if (extraction.gstBelowFullRate) ...[
          // Not an error: a receipt mixing GST-free items (basic food, for
          // one) carries less than one eleventh, and telling the user it
          // "should" be one eleventh would push them to overclaim.
          _Advisory(
            tone: PillTone.neutral,
            icon: Icons.calculate_outlined,
            title: 'Less GST than a fully taxable total',
            message:
                'If every item on a total of ${Money.format(extraction.totalAmount)} '
                'were taxable, GST would be ${Money.format(extraction.impliedGst)}. '
                'The receipt reads ${Money.format(extraction.taxAmount)}. That is '
                'normal when some items are GST-free. If none are, check the figure.',
          ),
          const SizedBox(height: 12),
        ],
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      extraction.vendor ?? 'Vendor not found',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (extraction.reviewStatus != null)
                    StatusPill(
                      label: extraction.reviewStatus!.label,
                      tone: switch (extraction.reviewStatus!) {
                        ReviewStatus.matched || ReviewStatus.posted => PillTone.positive,
                        ReviewStatus.rejected => PillTone.negative,
                        ReviewStatus.extracted => PillTone.warning,
                        ReviewStatus.reviewed => PillTone.accent,
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _FieldRow(
                label: 'Total',
                value: Money.format(extraction.totalAmount),
                confidence: extraction.fieldConfidence.totalAmount,
                emphasise: true,
              ),
              _FieldRow(
                label: 'GST',
                value: Money.format(extraction.taxAmount),
                confidence: extraction.fieldConfidence.taxAmount,
              ),
              _FieldRow(
                label: 'Date',
                value: Dates.format(extraction.transactionDate),
                confidence: extraction.fieldConfidence.transactionDate,
              ),
              if (extraction.vendorAbn != null)
                _FieldRow(
                  label: 'Supplier ABN',
                  value: _formatAbn(extraction.vendorAbn!),
                  confidence: extraction.fieldConfidence.vendorAbn,
                  trailing: extraction.vendorGstRegistered == null
                      ? null
                      : StatusPill(
                          label: extraction.vendorGstRegistered!
                              ? 'GST registered'
                              : 'Not GST registered',
                          tone: extraction.vendorGstRegistered!
                              ? PillTone.positive
                              : PillTone.warning,
                        ),
                ),
              if (extraction.paymentMethod != null)
                _FieldRow(label: 'Paid by', value: humanise(extraction.paymentMethod)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Record', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DetailRow(label: 'File', value: receipt.fileName),
              DetailRow(label: 'Added', value: Dates.formatWithTime(receipt.createdAt)),
              if (receipt.retentionExpiresAt != null)
                DetailRow(label: 'Kept until', value: Dates.format(receipt.retentionExpiresAt)),
              DetailRow(
                label: 'Matched to a transaction',
                value: receipt.isMatched
                    ? '${receipt.linkedTransactionIds.length} '
                          '${receipt.linkedTransactionIds.length == 1 ? 'transaction' : 'transactions'}'
                    : 'Not yet',
              ),
              if (extraction.provider != null)
                DetailRow(label: 'Read by', value: extraction.provider!),
            ],
          ),
        ),
        if (receipt.extractions.length > 1) ...[
          const SizedBox(height: 16),
          Text(
            'Ledgable read this receipt ${receipt.extractions.length} times. The '
            'figures above are from the most recent attempt.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 20),
        _Advisory(
          tone: PillTone.neutral,
          icon: Icons.open_in_new_rounded,
          title: 'Changing these figures',
          message:
              'Correcting what was read, and matching a receipt to a bank '
              'transaction by hand, are done in Ledgable on the web. The phone '
              'captures and checks; the browser edits.',
        ),
      ],
    );
  }

  /// ABNs are conventionally written as 11 digits in 2-3-3-3 groups. Formatting
  /// it makes a misread digit easier to spot against the paper.
  static String _formatAbn(String abn) {
    final digits = abn.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return abn;
    return '${digits.substring(0, 2)} ${digits.substring(2, 5)} '
        '${digits.substring(5, 8)} ${digits.substring(8)}';
  }
}

/// A value with its OCR confidence made visible when it is worth doubting.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    this.confidence,
    this.emphasise = false,
    this.trailing,
  });

  final String label;
  final String value;
  final double? confidence;
  final bool emphasise;
  final Widget? trailing;

  /// Below this a field is worth checking individually, matching the threshold
  /// the API documents for overall confidence.
  static const _threshold = Extraction.lowConfidenceThreshold;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final doubtful = confidence != null && confidence! < _threshold;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (doubtful) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.priority_high_rounded, size: 14, color: colors.warning),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Constrained: this column carries a figure, a "check this" caption and
          // sometimes a GST-registration pill, and together they are wider than
          // the space left beside the label on a 390px handset.
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: (emphasise ? theme.textTheme.headlineSmall : theme.textTheme.bodyLarge)
                      ?.copyWith(
                        color: doubtful ? colors.warning : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                if (doubtful)
                  Text(
                    'Low confidence — check this',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.warning),
                  ),
                if (trailing != null) ...[const SizedBox(height: 6), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Advisory extends StatelessWidget {
  const _Advisory({
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
  });

  final PillTone tone;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final accent = switch (tone) {
      PillTone.negative => colors.negative,
      PillTone.warning => colors.warning,
      PillTone.positive => colors.positive,
      PillTone.accent => colors.accent,
      PillTone.neutral => colors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: accent, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingReceipt extends StatelessWidget {
  const _ReadingReceipt({required this.status, this.timedOut = false, this.onCheckAgain});

  final OcrStatus status;
  final bool timedOut;
  final VoidCallback? onCheckAgain;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!timedOut) const CircularProgressIndicator(),
            if (timedOut) Icon(Icons.hourglass_bottom_rounded, size: 40, color: context.c.warning),
            const SizedBox(height: 20),
            Text(
              timedOut ? 'Still reading it' : status.label,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              timedOut
                  ? 'This one is taking longer than usual. It is saved and Ledgable '
                        'will keep working on it — you can leave this screen and come '
                        'back to it in Receipts.'
                  : 'Your receipt is saved. Ledgable is reading the vendor, total '
                        'and GST off it now.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (timedOut && onCheckAgain != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onCheckAgain,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Check again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CouldNotRead extends StatelessWidget {
  const _CouldNotRead({required this.receipt});

  final ReceiptDetail receipt;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final skipped = receipt.ocrStatus == OcrStatus.skipped;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          skipped ? Icons.description_outlined : Icons.image_not_supported_outlined,
          size: 44,
          color: skipped ? colors.textTertiary : colors.warning,
        ),
        const SizedBox(height: 20),
        Text(
          skipped ? 'Not scanned' : 'Ledgable could not read this one',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          skipped
              ? 'This file was stored without being scanned. It still counts as a '
                    'record and is kept for seven years.'
              : 'The file is saved and still counts as a record. Photographing it '
                    'again in better light usually works — flat, well lit, and with '
                    'the whole receipt in frame.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (receipt.ocrLastError != null) ...[
          const SizedBox(height: 20),
          LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What went wrong', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                SelectableText(receipt.ocrLastError!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        LedgerCard(
          child: Column(
            children: [
              DetailRow(label: 'File', value: receipt.fileName),
              DetailRow(label: 'Added', value: Dates.formatWithTime(receipt.createdAt)),
              if (receipt.retentionExpiresAt != null)
                DetailRow(label: 'Kept until', value: Dates.format(receipt.retentionExpiresAt)),
            ],
          ),
        ),
      ],
    );
  }
}
