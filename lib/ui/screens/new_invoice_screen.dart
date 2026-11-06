import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/invoice.dart';
import '../../app.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../widgets/common.dart';
import '../widgets/contact_picker.dart';

/// Raise a new invoice.
///
/// Creates a **draft** and nothing more. Sending is a separate, explicit tap on
/// the detail screen, because emailing a customer cannot be undone and a
/// fat-fingered tap on a phone should not be able to do it in one step.
///
/// GST is not editable here: whether line amounts include GST, and which tax
/// rate each line carries, come from the workspace's own settings and chart of
/// accounts, which the mobile API does not expose. The screen says so rather
/// than offering a GST control that would be a guess.
class NewInvoiceScreen extends ConsumerStatefulWidget {
  const NewInvoiceScreen({super.key});

  @override
  ConsumerState<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends ConsumerState<NewInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  Contact? _contact;
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  final List<_LineController> _lines = [_LineController()];
  bool _submitting = false;

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  /// Sum of the lines, as a Decimal throughout. Whether GST sits on top of this
  /// or inside it is the server's call, so the label calls it a subtotal rather
  /// than a total.
  Decimal get _subtotal =>
      _lines.fold(Decimal.zero, (total, line) => total + (line.lineTotal ?? Decimal.zero));

  DateTime get _effectiveDueDate =>
      _dueDate ?? Dates.addDays(_issueDate, _contact?.paymentTermsDays ?? 14);

  Future<void> _pickContact() async {
    final chosen = await showContactPicker(context, ref);
    if (chosen == null) return;
    setState(() {
      _contact = chosen;
      // Propose the terms this customer is actually on rather than a blanket 14
      // days, unless the user has already set a date by hand.
      _dueDate ??= null;
    });
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final initial = isDueDate ? _effectiveDueDate : _issueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // An invoice dated years out is a data-entry slip, not a use case.
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: isDueDate ? 'Payment due' : 'Invoice date',
    );
    if (picked == null) return;
    setState(() {
      if (isDueDate) {
        _dueDate = picked;
      } else {
        _issueDate = picked;
      }
    });
  }

  void _addLine() => setState(() => _lines.add(_LineController()));

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    setState(() => _lines.removeAt(index).dispose());
  }

  Future<void> _submit() async {
    final contact = _contact;
    if (contact == null) {
      showErrorToast(context, StateError('Choose a customer first.'));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final drafts = <DraftLine>[];
    for (final line in _lines) {
      final draft = line.toDraftLine();
      if (draft != null) drafts.add(draft);
    }
    if (drafts.isEmpty) {
      showErrorToast(context, StateError('Add at least one line with an amount.'));
      return;
    }

    if (_effectiveDueDate.isBefore(DateTime(_issueDate.year, _issueDate.month, _issueDate.day))) {
      showErrorToast(context, StateError('The due date cannot be before the invoice date.'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final created = await ref
          .read(invoicesRepositoryProvider)
          .createDraft(
            contactId: contact.id,
            date: _issueDate,
            dueDate: _effectiveDueDate,
            lines: drafts,
            reference: _referenceController.text,
            notes: _notesController.text,
          );
      if (!mounted) return;
      ref.invalidate(invoiceListProvider);
      showSuccessToast(
        context,
        '${created.invoiceNumber} saved as a draft. Send it when you are ready.',
      );
      // Land on the draft, not back on the list: sending is the next step and it
      // lives there.
      context.pushReplacement(Routes.invoiceDetail(created.id));
    } on ArgumentError {
      if (!mounted) return;
      showErrorToast(
        context,
        StateError(
          'One of the amounts has more than two decimal places. '
          'Round it to the cent and try again.',
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      showErrorToast(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.c;

    return Scaffold(
      appBar: AppBar(title: const Text('New invoice')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const SectionHeader(title: 'Customer'),
              LedgerCard(
                onTap: _submitting ? null : _pickContact,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _contact == null ? Icons.person_search_rounded : Icons.person_rounded,
                        size: 20,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _contact?.name ?? 'Choose a customer',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _contact == null ? colors.textSecondary : null,
                            ),
                          ),
                          if (_contact != null)
                            Text(
                              _contact!.email ?? 'No email on file',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _contact!.canBeEmailed ? null : colors.warning,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Dates'),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Invoice date',
                      value: Dates.format(_issueDate),
                      onTap: _submitting ? null : () => _pickDate(isDueDate: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Due',
                      value: Dates.format(_effectiveDueDate),
                      hint: _dueDate == null && _contact != null
                          ? '${_contact!.paymentTermsDays} day terms'
                          : null,
                      onTap: _submitting ? null : () => _pickDate(isDueDate: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(
                title: 'Lines',
                action: TextButton.icon(
                  onPressed: _submitting ? null : _addLine,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add line'),
                ),
              ),
              for (var i = 0; i < _lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _LineEditor(
                  controller: _lines[i],
                  index: i,
                  canRemove: _lines.length > 1,
                  enabled: !_submitting,
                  onRemove: () => _removeLine(i),
                  onChanged: () => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),
              LedgerCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Subtotal', value: Money.format(_subtotal), emphasise: true),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 13, color: colors.textTertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ledgable applies GST and your invoice numbering when it '
                            'saves the draft, using this workspace’s settings.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Optional'),
              TextFormField(
                controller: _referenceController,
                enabled: !_submitting,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Reference',
                  hintText: 'Purchase order, job number',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                enabled: !_submitting,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Notes for the customer',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting || _contact == null ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save as draft'),
              ),
              const SizedBox(height: 10),
              Text(
                'Nothing is emailed yet. You send it from the invoice itself.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Holds the controllers for one editable line.
class _LineController {
  _LineController()
    : description = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      unitPrice = TextEditingController();

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  Decimal? get quantityValue => Decimal.tryParse(quantity.text.trim());

  Decimal? get unitPriceValue => Decimal.tryParse(unitPrice.text.trim());

  Decimal? get lineTotal {
    final qty = quantityValue;
    final price = unitPriceValue;
    if (qty == null || price == null) return null;
    return qty * price;
  }

  bool get isBlank => description.text.trim().isEmpty && unitPrice.text.trim().isEmpty;

  /// Null for a line the user left empty, so a stray extra row does not fail
  /// the whole invoice.
  DraftLine? toDraftLine() {
    if (isBlank) return null;
    final qty = quantityValue;
    final price = unitPriceValue;
    if (qty == null || price == null) return null;
    return DraftLine(description: description.text, quantity: qty, unitPrice: price);
  }

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.controller,
    required this.index,
    required this.canRemove,
    required this.enabled,
    required this.onRemove,
    required this.onChanged,
  });

  final _LineController controller;
  final int index;
  final bool canRemove;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Line ${index + 1}', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              if (controller.lineTotal != null)
                Text(
                  Money.format(controller.lineTotal),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.c.textPrimary,
                  ),
                ),
              if (canRemove)
                IconButton(
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove line ${index + 1}',
                ),
            ],
          ),
          TextFormField(
            controller: controller.description,
            enabled: enabled,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What for',
              hintText: 'Labour, materials, callout',
              counterText: '',
            ),
            onChanged: (_) => onChanged(),
            validator: (value) {
              if (controller.isBlank) return null;
              return (value ?? '').trim().isEmpty ? 'Describe this line' : null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller.quantity,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  onChanged: (_) => onChanged(),
                  validator: (value) {
                    if (controller.isBlank) return null;
                    final parsed = Decimal.tryParse((value ?? '').trim());
                    if (parsed == null) return 'Enter a number';
                    if (parsed <= Decimal.zero) return 'Must be more than zero';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: controller.unitPrice,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Price each', prefixText: r'$ '),
                  onChanged: (_) => onChanged(),
                  validator: (value) {
                    if (controller.isBlank) return null;
                    final text = (value ?? '').trim();
                    final parsed = Decimal.tryParse(text);
                    if (parsed == null) return 'Enter an amount';
                    if (parsed <= Decimal.zero) return 'Must be more than zero';
                    // The API rejects a fractional unitPriceCents rather than
                    // rounding it, so catch it here where it can be explained.
                    if (parsed.scale > 2) return 'Cents only — two decimal places';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, this.hint, this.onTap});

  final String label;
  final String value;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Icon(Icons.event_rounded, size: 16, color: colors.textTertiary),
              ],
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(hint!, style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
