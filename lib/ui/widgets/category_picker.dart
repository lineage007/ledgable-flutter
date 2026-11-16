import 'package:flutter/material.dart';

import '../../api/models/transaction.dart';
import '../../theme.dart';

/// Choose a category for a transaction.
///
/// Two ways in, because the API leaves the client no complete list to show. The
/// options are the codes this workspace has actually used — real, but not
/// exhaustive — so the sheet also takes a code typed by hand for a category
/// created on the web and never used yet. Without that second path a user could
/// see a category in the browser and have no way to apply it on the phone.
Future<String?> showCategoryPicker(
  BuildContext context, {
  required List<CategoryOption> options,
  required String transactionTitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) =>
        _CategoryPickerSheet(options: options, transactionTitle: transactionTitle),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({required this.options, required this.transactionTitle});

  final List<CategoryOption> options;
  final String transactionTitle;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CategoryOption> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    return widget.options
        .where(
          (option) =>
              option.code.toLowerCase().contains(query) ||
              option.label.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  /// Whether what has been typed could be applied as a code in its own right.
  /// Only offered when it does not already match a listed option, so the two
  /// paths never present the same choice twice.
  String? get _typedCode {
    final typed = _query.trim();
    if (typed.isEmpty || typed.length > 50) return null;
    final alreadyListed = widget.options.any(
      (option) => option.code.toLowerCase() == typed.toLowerCase(),
    );
    return alreadyListed ? null : typed;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final filtered = _filtered;
    final typed = _typedCode;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Categorise', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    widget.transactionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    autofocus: widget.options.isEmpty,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Search, or type a category code',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (typed != null)
                    ListTile(
                      leading: Icon(Icons.keyboard_rounded, color: colors.accent),
                      title: Text('Use "$typed"'),
                      subtitle: const Text('A code from your chart of accounts'),
                      onTap: () => Navigator.of(context).pop(typed),
                    ),
                  if (filtered.isEmpty && typed == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Text(
                        widget.options.isEmpty
                            ? 'This workspace has not categorised anything yet, so there '
                                  'is nothing to suggest. Type the category code you use in '
                                  'Ledgable on the web.'
                            : 'No category matches that. Type a code to use it anyway.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  for (final option in filtered)
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.sell_outlined, size: 18, color: colors.accent),
                      ),
                      title: Text(option.label),
                      subtitle: Text(
                        option.usageCount == 1
                            ? '${option.code} · used once recently'
                            : '${option.code} · used ${option.usageCount} times recently',
                      ),
                      onTap: () => Navigator.of(context).pop(option.code),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
