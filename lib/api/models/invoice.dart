import 'package:decimal/decimal.dart';

import '../../core/money.dart';
import 'page.dart';

/// Invoice lifecycle as the API reports it.
///
/// `submitted` is what an invoice becomes once it has been emailed — the send
/// call flips it there. There is no separate "sent" state.
enum InvoiceStatus {
  draft,
  submitted,
  authorised,
  paid,
  voided,
  unknown;

  static InvoiceStatus parse(Object? raw) => switch (asString(raw)?.toLowerCase()) {
    'draft' => InvoiceStatus.draft,
    'submitted' => InvoiceStatus.submitted,
    'authorised' || 'authorized' => InvoiceStatus.authorised,
    'paid' => InvoiceStatus.paid,
    'voided' => InvoiceStatus.voided,
    _ => InvoiceStatus.unknown,
  };

  String get label => switch (this) {
    InvoiceStatus.draft => 'Draft',
    InvoiceStatus.submitted => 'Sent',
    InvoiceStatus.authorised => 'Awaiting payment',
    InvoiceStatus.paid => 'Paid',
    InvoiceStatus.voided => 'Voided',
    InvoiceStatus.unknown => 'Unknown',
  };

  /// Wire value for the `status` query parameter.
  String get wire => this == InvoiceStatus.unknown ? 'all' : name;

  bool get isSendable => this == InvoiceStatus.draft || this == InvoiceStatus.authorised;
}

class ContactRef {
  const ContactRef({required this.id, required this.name, this.email});

  final String id;
  final String name;
  final String? email;

  factory ContactRef.fromJson(Map<String, dynamic> json) => ContactRef(
    id: asStringOr(json['id'], ''),
    name: asStringOr(json['name'], 'Customer'),
    email: asString(json['email']),
  );
}

class InvoiceSummary {
  const InvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    this.reference,
    required this.status,
    this.date,
    this.dueDate,
    this.total,
    this.amountDue,
    this.amountPaid,
    required this.currencyCode,
    required this.sentToContact,
    required this.overdue,
    this.contact,
  });

  final String id;
  final String invoiceNumber;
  final String? reference;
  final InvoiceStatus status;
  final DateTime? date;
  final DateTime? dueDate;
  final Decimal? total;
  final Decimal? amountDue;
  final Decimal? amountPaid;
  final String currencyCode;
  final bool sentToContact;

  /// Computed server-side so every client agrees, and so a phone with a wrong
  /// clock cannot mislabel a row. Never recompute it here.
  final bool overdue;
  final ContactRef? contact;

  String get contactName => contact?.name ?? 'No customer';

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    final contact = asMap(json['contact']);
    return InvoiceSummary(
      id: asStringOr(json['id'], ''),
      invoiceNumber: asStringOr(json['invoiceNumber'], '—'),
      reference: asString(json['reference']),
      status: InvoiceStatus.parse(json['status']),
      date: DateTime.tryParse('${json['date']}')?.toLocal(),
      dueDate: DateTime.tryParse('${json['dueDate']}')?.toLocal(),
      total: Money.parse(json['total']),
      amountDue: Money.parse(json['amountDue']),
      amountPaid: Money.parse(json['amountPaid']),
      currencyCode: asStringOr(json['currencyCode'], 'AUD'),
      sentToContact: asBool(json['sentToContact']),
      overdue: asBool(json['overdue']),
      contact: contact == null ? null : ContactRef.fromJson(contact),
    );
  }
}

class InvoiceLineItem {
  const InvoiceLineItem({
    this.id,
    this.description,
    this.quantity,
    this.unitAmount,
    this.taxAmount,
    this.lineAmount,
    this.accountCode,
    this.taxType,
  });

  final String? id;
  final String? description;

  /// Decimal string at 4dp — not rounded to cents, so a rate of 0.3333 hours
  /// survives the round trip.
  final Decimal? quantity;
  final Decimal? unitAmount;
  final Decimal? taxAmount;
  final Decimal? lineAmount;
  final String? accountCode;
  final String? taxType;

  /// `2 × $45.00`, with the quantity rendered without trailing zeros.
  String get quantityLabel {
    final qty = quantity;
    if (qty == null) return '';
    final trimmed = qty.toString().contains('.')
        ? qty.toString().replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : qty.toString();
    return trimmed;
  }

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) => InvoiceLineItem(
    id: asString(json['id']),
    description: asString(json['description']),
    quantity: Money.parse(json['quantity']),
    unitAmount: Money.parse(json['unitAmount']),
    taxAmount: Money.parse(json['taxAmount']),
    lineAmount: Money.parse(json['lineAmount']),
    accountCode: asString(json['accountCode']),
    taxType: asString(json['taxType']),
  );
}

class InvoicePayment {
  const InvoicePayment({required this.id, this.date, this.amount, this.reference});

  final String id;
  final DateTime? date;
  final Decimal? amount;
  final String? reference;

  factory InvoicePayment.fromJson(Map<String, dynamic> json) => InvoicePayment(
    id: asStringOr(json['id'], ''),
    date: DateTime.tryParse('${json['date']}')?.toLocal(),
    amount: Money.parse(json['amount']),
    reference: asString(json['reference']),
  );
}

class InvoiceDetail {
  const InvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    this.reference,
    required this.status,
    this.date,
    this.dueDate,
    this.subtotal,
    this.totalTax,
    this.total,
    this.amountDue,
    this.amountPaid,
    required this.currencyCode,
    this.lineAmountTypes,
    this.notes,
    this.terms,
    required this.sentToContact,
    this.onlinePaymentUrl,
    this.contact,
    this.lineItems = const [],
    this.payments = const [],
  });

  final String id;
  final String invoiceNumber;
  final String? reference;
  final InvoiceStatus status;
  final DateTime? date;
  final DateTime? dueDate;
  final Decimal? subtotal;

  /// GST total.
  final Decimal? totalTax;
  final Decimal? total;
  final Decimal? amountDue;
  final Decimal? amountPaid;
  final String currencyCode;

  /// `Exclusive`, `Inclusive` or `NoTax` — whether line amounts include GST.
  /// Shown on the detail screen because "$100 plus GST" and "$100 including
  /// GST" are different invoices.
  final String? lineAmountTypes;
  final String? notes;
  final String? terms;
  final bool sentToContact;
  final String? onlinePaymentUrl;
  final Contact? contact;
  final List<InvoiceLineItem> lineItems;
  final List<InvoicePayment> payments;

  bool get isPartlyPaid =>
      amountPaid != null &&
      amountPaid! > Decimal.zero &&
      amountDue != null &&
      amountDue! > Decimal.zero;

  String get contactName => contact?.name ?? 'No customer';

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    final contact = asMap(json['contact']);
    return InvoiceDetail(
      id: asStringOr(json['id'], ''),
      invoiceNumber: asStringOr(json['invoiceNumber'], '—'),
      reference: asString(json['reference']),
      status: InvoiceStatus.parse(json['status']),
      date: DateTime.tryParse('${json['date']}')?.toLocal(),
      dueDate: DateTime.tryParse('${json['dueDate']}')?.toLocal(),
      subtotal: Money.parse(json['subtotal']),
      totalTax: Money.parse(json['totalTax']),
      total: Money.parse(json['total']),
      amountDue: Money.parse(json['amountDue']),
      amountPaid: Money.parse(json['amountPaid']),
      currencyCode: asStringOr(json['currencyCode'], 'AUD'),
      lineAmountTypes: asString(json['lineAmountTypes']),
      notes: asString(json['notes']),
      terms: asString(json['terms']),
      sentToContact: asBool(json['sentToContact']),
      onlinePaymentUrl: asString(json['onlinePaymentUrl']),
      contact: contact == null ? null : Contact.fromJson(contact),
      lineItems: asMapList(json['lineItems']).map(InvoiceLineItem.fromJson).toList(growable: false),
      payments: asMapList(json['payments']).map(InvoicePayment.fromJson).toList(growable: false),
    );
  }
}

/// The `201` from `POST /invoices`. Always a draft: sending is a separate,
/// explicit call, because emailing a customer cannot be undone and a
/// fat-fingered tap on a phone should not be able to do it in one step.
class CreatedInvoice {
  const CreatedInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.contactId,
    this.total,
    required this.status,
  });

  final String id;

  /// Assigned server-side — invoice numbering is not the client's business.
  final String invoiceNumber;
  final String contactId;
  final Decimal? total;
  final String status;

  factory CreatedInvoice.fromJson(Map<String, dynamic> json) => CreatedInvoice(
    id: asStringOr(json['id'], ''),
    invoiceNumber: asStringOr(json['invoiceNumber'], '—'),
    contactId: asStringOr(json['contactId'], ''),
    total: Money.parse(json['total']),
    status: asStringOr(json['status'], 'draft'),
  );
}

/// The result of `POST /invoices/{id}/send`. Not reversible.
class InvoiceSendResult {
  const InvoiceSendResult({
    required this.emailJobId,
    required this.invoiceNumber,
    required this.status,
    required this.sentToEmail,
  });

  final String emailJobId;
  final String invoiceNumber;
  final String status;
  final String sentToEmail;

  factory InvoiceSendResult.fromJson(Map<String, dynamic> json) {
    final invoice = asMap(json['invoice']) ?? const {};
    return InvoiceSendResult(
      emailJobId: asStringOr(json['emailJobId'], ''),
      invoiceNumber: asStringOr(invoice['invoiceNumber'], '—'),
      status: asStringOr(invoice['status'], 'submitted'),
      sentToEmail: asStringOr(invoice['sentToEmail'], ''),
    );
  }
}

/// A line the user is building on the new-invoice screen.
///
/// Held as a [Decimal] unit price and converted to integer cents only at the
/// moment of sending, so nothing in the editor rounds an amount.
class DraftLine {
  DraftLine({required this.description, required this.quantity, required this.unitPrice});

  String description;
  Decimal quantity;
  Decimal unitPrice;

  Decimal get lineTotal => quantity * unitPrice;

  bool get isValid =>
      description.trim().isNotEmpty && quantity > Decimal.zero && unitPrice > Decimal.zero;

  /// The request shape `CreateInvoiceRequest.lines` expects. Quantity goes as a
  /// number; the unit price goes as integer cents, and [Money.toCents] throws
  /// rather than rounds if the editor somehow produced sub-cent precision.
  Map<String, dynamic> toJson() => {
    'description': description.trim(),
    'quantity': quantity.toDouble(),
    'unitPriceCents': Money.toCents(unitPrice),
  };
}

class Contact {
  const Contact({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.mobile,
    required this.isCustomer,
    required this.isSupplier,
    required this.defaultCurrency,
    required this.paymentTermsDays,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? mobile;
  final bool isCustomer;
  final bool isSupplier;
  final String defaultCurrency;

  /// Drives the default due date on a new invoice, so the app proposes the
  /// terms this customer is actually on rather than a blanket 14 days.
  final int paymentTermsDays;

  String? get bestPhone => mobile ?? phone;

  /// An invoice cannot be emailed to a contact with no address on file. The
  /// send screen uses this to ask for one instead of failing at the API.
  bool get canBeEmailed => email != null && email!.contains('@');

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: asStringOr(json['id'], ''),
    name: asStringOr(json['name'], 'Contact'),
    email: asString(json['email']),
    phone: asString(json['phone']),
    mobile: asString(json['mobile']),
    isCustomer: asBool(json['isCustomer'], fallback: true),
    isSupplier: asBool(json['isSupplier']),
    defaultCurrency: asStringOr(json['defaultCurrency'], 'AUD'),
    paymentTermsDays: asInt(json['paymentTermsDays']) ?? 14,
  );
}
