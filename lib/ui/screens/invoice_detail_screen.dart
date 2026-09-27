import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/invoice.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../widgets/common.dart';

/// One invoice, and the button that emails it.
///
/// Sending is not reversible — once enqueued the send is committed — so it sits
/// behind a confirmation that names the recipient. A phone is a place where taps
/// happen by accident, and "we emailed your customer" is not something an undo
/// can fix.
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _sending = false;

  Future<void> _send(InvoiceDetail invoice) async {
    final contact = invoice.contact;
    var recipient = contact?.email;

    // No address on file: ask for one rather than letting the API refuse.
    if (recipient == null || !recipient.contains('@')) {
      recipient = await _askForEmail(invoice);
      if (recipient == null) return;
    } else {
      final confirmed = await _confirmSend(invoice, recipient);
      if (confirmed != true) return;
    }

    setState(() => _sending = true);
    try {
      final result = await ref
          .read(invoicesRepositoryProvider)
          .send(invoice.id, sendToEmail: recipient == contact?.email ? null : recipient);
      if (!mounted) return;
      showSuccessToast(context, '${result.invoiceNumber} is on its way to ${result.sentToEmail}.');
      ref.invalidate(invoiceDetailProvider(widget.invoiceId));
      ref.invalidate(invoiceListProvider);
    } on Object catch (error) {
      if (!mounted) return;
      showErrorToast(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool?> _confirmSend(InvoiceDetail invoice, String recipient) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send this invoice?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${invoice.invoiceNumber} for ${Money.format(invoice.total)} goes to '
              '$recipient.',
              style: Theme.of(dialogContext).textTheme.bodyLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'Emailing a customer cannot be undone.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askForEmail(InvoiceDetail invoice) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Where should it go?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${invoice.contactName} has no email address on file.',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter an email address';
                  if (!text.contains('@') || text.length < 5) {
                    return 'That does not look like an email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Text(
                'This sends the invoice once. Add the address to the contact on the '
                'web so it is there next time.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Send'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(invoiceDetailProvider(widget.invoiceId));
    final canWrite = ref.watch(canWriteProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (snapshot) {
          AsyncData(:final value) => value.invoiceNumber,
          _ => 'Invoice',
        }),
      ),
      body: SafeArea(
        child: switch (snapshot) {
          AsyncError(:final error) => ListView(
            padding: const EdgeInsets.only(top: 60),
            children: [
              ErrorView(
                error: error,
                onRetry: () => ref.invalidate(invoiceDetailProvider(widget.invoiceId)),
              ),
            ],
          ),
          AsyncData(:final value) => _InvoiceBody(
            invoice: value,
            canWrite: canWrite,
            sending: _sending,
            onSend: () => _send(value),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({
    required this.invoice,
    required this.canWrite,
    required this.sending,
    required this.onSend,
  });

  final InvoiceDetail invoice;
  final bool canWrite;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    // The summary needs an overdue flag, and the detail payload does not carry
    // one — it is computed server-side on the list. Derive the pill from the
    // status alone here rather than recomputing overdue from the device clock,
    // which the API deliberately avoids.
    final (statusLabel, statusTone) = switch (invoice.status) {
      InvoiceStatus.paid => ('Paid', PillTone.positive),
      InvoiceStatus.draft => ('Draft', PillTone.neutral),
      InvoiceStatus.voided => ('Voided', PillTone.neutral),
      InvoiceStatus.submitted => ('Sent', PillTone.accent),
      InvoiceStatus.authorised => ('Awaiting payment', PillTone.warning),
      InvoiceStatus.unknown => (invoice.status.label, PillTone.neutral),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        LedgerCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.contactName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  StatusPill(label: statusLabel, tone: statusTone),
                ],
              ),
              if (invoice.contact?.email != null) ...[
                const SizedBox(height: 4),
                Text(invoice.contact!.email!, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 20),
              Text(
                invoice.status == InvoiceStatus.paid ? 'Paid' : 'Amount due',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Money.format(
                    invoice.status == InvoiceStatus.paid ? invoice.total : invoice.amountDue,
                  ),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 36,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (invoice.isPartlyPaid) ...[
                const SizedBox(height: 6),
                Text(
                  '${Money.format(invoice.amountPaid)} of '
                  '${Money.format(invoice.total)} already paid',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        LedgerCard(
          child: Column(
            children: [
              DetailRow(label: 'Issued', value: Dates.format(invoice.date)),
              DetailRow(label: 'Due', value: Dates.format(invoice.dueDate)),
              if (invoice.reference != null)
                DetailRow(label: 'Reference', value: invoice.reference!),
              if (invoice.currencyCode != 'AUD')
                DetailRow(label: 'Currency', value: invoice.currencyCode),
            ],
          ),
        ),
        if (invoice.lineItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Lines',
            // "$100 plus GST" and "$100 including GST" are different invoices,
            // so which one this is belongs on screen.
            subtitle: switch (invoice.lineAmountTypes) {
              'Inclusive' => 'Amounts include GST',
              'Exclusive' => 'Amounts exclude GST',
              'NoTax' => 'No GST on this invoice',
              _ => null,
            },
          ),
          LedgerCard(
            child: Column(
              children: [
                for (var i = 0; i < invoice.lineItems.length; i++) ...[
                  if (i > 0) Divider(height: 20, color: colors.border),
                  _LineItemRow(line: invoice.lineItems[i]),
                ],
                Divider(height: 24, color: colors.border),
                DetailRow(label: 'Subtotal', value: Money.format(invoice.subtotal)),
                DetailRow(label: 'GST', value: Money.format(invoice.totalTax)),
                DetailRow(label: 'Total', value: Money.format(invoice.total), emphasise: true),
              ],
            ),
          ),
        ],
        if (invoice.payments.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Payments'),
          LedgerCard(
            child: Column(
              children: [
                for (final payment in invoice.payments)
                  DetailRow(
                    label: [
                      Dates.format(payment.date),
                      if (payment.reference != null) payment.reference!,
                    ].join(' · '),
                    value: Money.format(payment.amount),
                    valueColor: colors.positive,
                  ),
              ],
            ),
          ),
        ],
        if (invoice.notes != null) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Notes'),
          LedgerCard(child: Text(invoice.notes!, style: Theme.of(context).textTheme.bodyMedium)),
        ],
        const SizedBox(height: 24),
        if (canWrite && invoice.status.isSendable)
          ElevatedButton.icon(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(invoice.sentToContact ? 'Send again' : 'Send to ${invoice.contactName}'),
          )
        else if (invoice.sentToContact)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 16, color: colors.positive),
              const SizedBox(width: 8),
              Text('Already sent to this customer', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          'Recording a payment, voiding, and editing an invoice are done in '
          'Ledgable on the web.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({required this.line});

  final InvoiceLineItem line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.description ?? 'Line', style: Theme.of(context).textTheme.bodyLarge),
              if (line.quantity != null && line.unitAmount != null)
                Text(
                  '${line.quantityLabel} × ${Money.format(line.unitAmount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          Money.format(line.lineAmount),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
