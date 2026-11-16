import '../api/api_client.dart';
import '../api/models/invoice.dart';
import '../api/models/page.dart';
import '../core/formatters.dart';

class InvoicesRepository {
  InvoicesRepository(this._client);

  final ApiClient _client;

  /// Accounts-receivable invoices only. Bills appear under `/approvals`.
  Future<Paged<InvoiceSummary>> list({
    InvoiceStatus? status,
    int limit = 25,
    int offset = 0,
  }) async {
    final body = await _client.get(
      '/invoices',
      query: {
        'limit': limit,
        'offset': offset,
        if (status != null && status != InvoiceStatus.unknown) 'status': status.wire,
      },
    );
    return Paged<InvoiceSummary>(
      items: asMapList(body['invoices']).map(InvoiceSummary.fromJson).toList(growable: false),
      page: Page.fromJson(asMap(body['page'])),
    );
  }

  Future<InvoiceDetail> detail(String invoiceId) async =>
      InvoiceDetail.fromJson(await _client.get('/invoices/$invoiceId'));

  /// Create a **draft**. Sending is a separate, explicit call.
  Future<CreatedInvoice> createDraft({
    required String contactId,
    required DateTime dueDate,
    required List<DraftLine> lines,
    DateTime? date,
    String? reference,
    String? notes,
  }) async {
    final body = await _client.post(
      '/invoices',
      body: {
        'contactId': contactId,
        'dueDate': Dates.toIso(dueDate),
        if (date != null) 'date': Dates.toIso(date),
        if (reference != null && reference.trim().isNotEmpty) 'reference': reference.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'lines': lines.map((line) => line.toJson()).toList(growable: false),
      },
    );
    return CreatedInvoice.fromJson(asMap(body['invoice']) ?? body);
  }

  /// Email an invoice. **Not reversible** — once enqueued the send is
  /// committed, so the UI must confirm before calling this.
  ///
  /// Omitting [sendToEmail] sends to the address on file.
  Future<InvoiceSendResult> send(String invoiceId, {String? sendToEmail}) async {
    final trimmed = sendToEmail?.trim();
    final body = await _client.post(
      '/invoices/$invoiceId/send',
      body: trimmed == null || trimmed.isEmpty ? null : {'sendToEmail': trimmed},
    );
    return InvoiceSendResult.fromJson(body);
  }
}

/// Which side of the ledger a contact is on, for the picker filter.
enum ContactType {
  customer,
  supplier,
  all;

  String get wire => name;
}

class ContactsRepository {
  ContactsRepository(this._client);

  final ApiClient _client;

  /// Bank details, tax numbers and addresses are omitted by the API — the
  /// picker needs a name and a way to recognise the right person, and shipping
  /// a workspace's whole counterparty file to every handset is a larger
  /// exposure than the feature is worth.
  Future<Paged<Contact>> list({
    String? search,
    ContactType type = ContactType.all,
    int limit = 25,
    int offset = 0,
  }) async {
    final trimmed = search?.trim();
    final body = await _client.get(
      '/contacts',
      query: {
        'limit': limit,
        'offset': offset,
        'type': type.wire,
        if (trimmed != null && trimmed.isNotEmpty)
          'search': trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed,
      },
    );
    return Paged<Contact>(
      items: asMapList(body['contacts']).map(Contact.fromJson).toList(growable: false),
      page: Page.fromJson(asMap(body['page'])),
    );
  }
}
