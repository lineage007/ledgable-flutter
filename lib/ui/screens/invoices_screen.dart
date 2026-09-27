import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/invoice.dart';
import '../../app.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../shell.dart';
import '../widgets/common.dart';

/// Customer invoices, with a status filter and a way to raise a new one.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  static const _filters = <(String, InvoiceStatus?)>[
    ('All', null),
    ('Unpaid', InvoiceStatus.authorised),
    ('Sent', InvoiceStatus.submitted),
    ('Drafts', InvoiceStatus.draft),
    ('Paid', InvoiceStatus.paid),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(invoiceListProvider);
    final active = ref.watch(invoiceFilterProvider);
    final canWrite = ref.watch(canWriteProvider);

    return Scaffold(
      appBar: WorkspaceAppBar(
        title: 'Invoices',
        actions: [
          if (canWrite)
            IconButton(
              onPressed: () => context.push(Routes.newInvoice),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'New invoice',
            ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                for (final (label, status) in _filters) ...[
                  ChoiceChip(
                    label: Text(label),
                    selected: active == status,
                    onSelected: (_) => ref.read(invoiceFilterProvider.notifier).state = status,
                    selectedColor: context.c.accentSoft,
                    labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: active == status ? context.c.accent : context.c.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(invoiceListProvider.future),
              child: switch (snapshot) {
                AsyncError(:final error) => ListView(
                  padding: const EdgeInsets.only(top: 60),
                  children: [
                    ErrorView(error: error, onRetry: () => ref.invalidate(invoiceListProvider)),
                  ],
                ),
                AsyncData(:final value) when value.isEmpty => ListView(
                  padding: const EdgeInsets.only(top: 40),
                  children: [
                    SizedBox(
                      height: 360,
                      child: EmptyState(
                        icon: Icons.description_rounded,
                        title: active == null ? 'No invoices yet' : 'Nothing here',
                        message: active == null
                            ? 'Raise an invoice and send it straight from your phone. '
                                  'Ledgable numbers it for you.'
                            : 'No invoices match this filter.',
                        action: active == null && canWrite
                            ? ElevatedButton.icon(
                                onPressed: () => context.push(Routes.newInvoice),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('New invoice'),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                AsyncData(:final value) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: value.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _InvoiceRow(invoice: value.items[index]),
                ),
                _ => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: const [
                    _InvoiceSkeleton(),
                    SizedBox(height: 10),
                    _InvoiceSkeleton(),
                    SizedBox(height: 10),
                    _InvoiceSkeleton(),
                  ],
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The tone an invoice's status pill takes.
///
/// Overdue outranks the status: an authorised invoice that is three weeks late
/// is a problem, and showing it in the same neutral tone as one due next month
/// buries the thing the user needs to see.
(String, PillTone) invoicePillFor(InvoiceSummary invoice) {
  if (invoice.overdue && invoice.status != InvoiceStatus.paid) {
    return ('Overdue', PillTone.negative);
  }
  return switch (invoice.status) {
    InvoiceStatus.paid => ('Paid', PillTone.positive),
    InvoiceStatus.draft => ('Draft', PillTone.neutral),
    InvoiceStatus.voided => ('Voided', PillTone.neutral),
    InvoiceStatus.submitted => ('Sent', PillTone.accent),
    InvoiceStatus.authorised => ('Awaiting payment', PillTone.warning),
    InvoiceStatus.unknown => (invoice.status.label, PillTone.neutral),
  };
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final InvoiceSummary invoice;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final (label, tone) = invoicePillFor(invoice);
    final accent = switch (tone) {
      PillTone.negative => colors.negative,
      PillTone.positive => colors.positive,
      PillTone.warning => colors.warning,
      PillTone.accent => colors.accent,
      PillTone.neutral => colors.border,
    };

    return LedgerCard(
      accent: accent,
      onTap: () => context.push(Routes.invoiceDetail(invoice.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.contactName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(invoice.invoiceNumber, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    // The amount still owing is the number that matters on a
                    // list; the total is on the detail screen.
                    Money.format(invoice.amountDue ?? invoice.total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusPill(label: label, tone: tone),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event_rounded, size: 13, color: colors.textTertiary),
              const SizedBox(width: 6),
              Text(
                invoice.status == InvoiceStatus.paid
                    ? 'Paid in full'
                    : 'Due ${Dates.relative(invoice.dueDate).toLowerCase()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!invoice.sentToContact && invoice.status != InvoiceStatus.paid) ...[
                const Spacer(),
                Text(
                  'Not sent yet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.warning),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceSkeleton extends StatelessWidget {
  const _InvoiceSkeleton();

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SkeletonBlock(width: 140, height: 16)),
              SizedBox(width: 12),
              SkeletonBlock(width: 80, height: 18),
            ],
          ),
          SizedBox(height: 14),
          SkeletonBlock(width: 120, height: 10),
        ],
      ),
    );
  }
}
