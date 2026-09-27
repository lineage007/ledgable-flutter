import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/invoice.dart';
import '../../data/invoices_repository.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import 'common.dart';

/// Choose a customer for an invoice.
///
/// Filtered to customers: this picker only feeds accounts-receivable invoices,
/// and offering the whole counterparty file would invite invoicing a supplier by
/// mistake.
Future<Contact?> showContactPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Contact>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ContactPickerSheet(),
  );
}

class _ContactPickerSheet extends ConsumerStatefulWidget {
  const _ContactPickerSheet();

  @override
  ConsumerState<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends ConsumerState<_ContactPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Contact> _contacts = [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Searches server-side, debounced. A client-side filter would only see the
  /// first page, which on a workspace with hundreds of contacts means the
  /// customer you are looking for is usually not in it.
  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(contactsRepositoryProvider)
          .list(search: query, type: ContactType.customer, limit: 50);
      if (!mounted) return;
      setState(() {
        _contacts = page.items;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.c;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose a customer', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search customers',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: _onQueryChanged,
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch ((_loading, _error)) {
                (true, _) => const Center(child: CircularProgressIndicator()),
                (_, final Object error) => ErrorView(
                  error: error,
                  compact: true,
                  onRetry: () => _search(_searchController.text),
                ),
                _ when _contacts.isEmpty => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _searchController.text.trim().isEmpty
                        ? 'No customers in this workspace yet. Add one in Ledgable '
                              'on the web, then come back.'
                        : 'No customer matches that.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                _ => ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _contacts.length,
                  itemBuilder: (_, index) {
                    final contact = _contacts[index];
                    return ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.person_rounded, size: 18, color: colors.accent),
                      ),
                      title: Text(contact.name),
                      subtitle: Text(
                        contact.email ?? contact.bestPhone ?? 'No contact details',
                        style: contact.canBeEmailed
                            ? null
                            : Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: colors.warning),
                      ),
                      trailing: Text(
                        '${contact.paymentTermsDays}d',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () => Navigator.of(context).pop(contact),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
