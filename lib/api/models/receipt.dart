import 'package:decimal/decimal.dart';

import '../../core/money.dart';
import 'page.dart';

/// Where a receipt is in the OCR pipeline.
enum OcrStatus {
  pending,
  processing,
  completed,
  failed,

  /// OCR was not attempted — a PDF that is already a tax invoice, for example.
  skipped;

  static OcrStatus parse(Object? raw) => switch (asString(raw)?.toUpperCase()) {
    'PROCESSING' => OcrStatus.processing,
    'COMPLETED' => OcrStatus.completed,
    'FAILED' => OcrStatus.failed,
    'SKIPPED' => OcrStatus.skipped,
    _ => OcrStatus.pending,
  };

  /// Whether polling should stop. `SKIPPED` is terminal too — nothing further
  /// is coming, and a client that keeps polling it burns the upload budget.
  bool get isTerminal =>
      this == OcrStatus.completed || this == OcrStatus.failed || this == OcrStatus.skipped;

  String get label => switch (this) {
    OcrStatus.pending => 'Queued',
    OcrStatus.processing => 'Reading receipt',
    OcrStatus.completed => 'Read',
    OcrStatus.failed => 'Could not read',
    OcrStatus.skipped => 'Not scanned',
  };

  /// Wire value for the `ocrStatus` query parameter.
  String get wire => name.toUpperCase();
}

/// Where a human has got to with an extraction.
enum ReviewStatus {
  extracted,
  reviewed,
  rejected,
  matched,
  posted;

  static ReviewStatus? parse(Object? raw) => switch (asString(raw)?.toUpperCase()) {
    'EXTRACTED' => ReviewStatus.extracted,
    'REVIEWED' => ReviewStatus.reviewed,
    'REJECTED' => ReviewStatus.rejected,
    'MATCHED' => ReviewStatus.matched,
    'POSTED' => ReviewStatus.posted,
    _ => null,
  };

  String get label => switch (this) {
    ReviewStatus.extracted => 'Needs review',
    ReviewStatus.reviewed => 'Reviewed',
    ReviewStatus.rejected => 'Rejected',
    ReviewStatus.matched => 'Matched to a transaction',
    ReviewStatus.posted => 'Posted',
  };
}

/// Per-field OCR confidence, for highlighting what to check.
class FieldConfidence {
  const FieldConfidence({
    this.vendor,
    this.vendorAbn,
    this.totalAmount,
    this.taxAmount,
    this.transactionDate,
  });

  final double? vendor;
  final double? vendorAbn;
  final double? totalAmount;
  final double? taxAmount;
  final double? transactionDate;

  static const unknown = FieldConfidence();

  factory FieldConfidence.fromJson(Map<String, dynamic>? json) => FieldConfidence(
    vendor: asDouble(json?['vendor']),
    vendorAbn: asDouble(json?['vendorAbn']),
    totalAmount: asDouble(json?['totalAmount']),
    taxAmount: asDouble(json?['taxAmount']),
    transactionDate: asDouble(json?['transactionDate']),
  );
}

/// One OCR attempt on a receipt.
class Extraction {
  const Extraction({
    this.id,
    this.vendor,
    this.totalAmount,
    this.taxAmount,
    this.transactionDate,
    this.confidence,
    this.reviewStatus,
    this.extractedAt,
    this.provider,
    this.vendorAbn,
    this.vendorGstRegistered,
    this.paymentMethod,
    this.fieldConfidence = FieldConfidence.unknown,
    this.reviewedAt,
  });

  final String? id;
  final String? vendor;

  /// GST-inclusive total as read off the receipt.
  final Decimal? totalAmount;

  /// GST component as read off the receipt.
  final Decimal? taxAmount;
  final DateTime? transactionDate;

  /// Overall confidence, 0–1.
  final double? confidence;
  final ReviewStatus? reviewStatus;
  final DateTime? extractedAt;
  final String? provider;
  final String? vendorAbn;

  /// From an ABR lookup of the vendor ABN.
  final bool? vendorGstRegistered;
  final String? paymentMethod;
  final FieldConfidence fieldConfidence;
  final DateTime? reviewedAt;

  /// Below this, the spec says to prompt the user to confirm rather than
  /// presenting the reading as settled.
  static const lowConfidenceThreshold = 0.7;

  bool get isLowConfidence => confidence != null && confidence! < lowConfidenceThreshold;

  /// A supplier that is not GST-registered cannot charge GST, so a non-zero tax
  /// amount alongside `vendorGstRegistered: false` is a real problem on a BAS,
  /// not a rounding quirk. Surfaced as a prompt on the review screen.
  bool get hasGstMismatch =>
      vendorGstRegistered == false && taxAmount != null && taxAmount != Decimal.zero;

  /// The GST a 10% rate implies for this total, used to flag a reading that is
  /// internally inconsistent. Australian GST is 1/11th of a GST-inclusive
  /// total, not 10% of it — 10% of the inclusive figure overstates the credit.
  Decimal? get impliedGst {
    final total = totalAmount;
    if (total == null || total == Decimal.zero) return null;
    return (total / Decimal.fromInt(11)).toDecimal(scaleOnInfinitePrecision: 2);
  }

  /// True when the GST read off the receipt is more than five cents away from
  /// one eleventh of the total. Five cents absorbs the rounding a till does
  /// per line without flagging every receipt.
  bool get gstLooksOff {
    final read = taxAmount;
    final implied = impliedGst;
    if (read == null || implied == null || read == Decimal.zero) return false;
    final gap = (read - implied).abs();
    return gap > Decimal.parse('0.05');
  }

  factory Extraction.fromJson(Map<String, dynamic> json) => Extraction(
    id: asString(json['id']),
    vendor: asString(json['vendor']),
    totalAmount: Money.parse(json['totalAmount']),
    taxAmount: Money.parse(json['taxAmount']),
    transactionDate: DateTime.tryParse('${json['transactionDate']}')?.toLocal(),
    confidence: asDouble(json['confidence']),
    reviewStatus: ReviewStatus.parse(json['reviewStatus']),
    extractedAt: DateTime.tryParse('${json['extractedAt']}')?.toLocal(),
    provider: asString(json['provider']),
    vendorAbn: asString(json['vendorAbn']),
    vendorGstRegistered: json['vendorGstRegistered'] is bool
        ? json['vendorGstRegistered'] as bool
        : null,
    paymentMethod: asString(json['paymentMethod']),
    fieldConfidence: FieldConfidence.fromJson(asMap(json['fieldConfidence'])),
    reviewedAt: DateTime.tryParse('${json['reviewedAt']}')?.toLocal(),
  );
}

class ReceiptSummary {
  const ReceiptSummary({
    required this.id,
    required this.fileName,
    this.mimeType,
    this.fileSize,
    required this.ocrStatus,
    required this.archived,
    this.createdAt,
    this.linkedTransactionIds = const [],
    this.extraction,
  });

  final String id;
  final String fileName;
  final String? mimeType;
  final int? fileSize;
  final OcrStatus ocrStatus;
  final bool archived;
  final DateTime? createdAt;
  final List<String> linkedTransactionIds;
  final Extraction? extraction;

  bool get isMatched => linkedTransactionIds.isNotEmpty;

  /// Vendor if OCR found one, otherwise the file name — better than "Untitled"
  /// when a scan failed.
  String get displayTitle => extraction?.vendor ?? fileName;

  factory ReceiptSummary.fromJson(Map<String, dynamic> json) {
    final extraction = asMap(json['extraction']);
    return ReceiptSummary(
      id: asStringOr(json['id'], ''),
      fileName: asStringOr(json['fileName'], 'Receipt'),
      mimeType: asString(json['mimeType']),
      fileSize: asInt(json['fileSize']),
      ocrStatus: OcrStatus.parse(json['ocrStatus']),
      archived: asBool(json['archived']),
      createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal(),
      linkedTransactionIds: asStringList(json['linkedTransactionIds']),
      extraction: extraction == null ? null : Extraction.fromJson(extraction),
    );
  }
}

class ReceiptDetail {
  const ReceiptDetail({
    required this.id,
    required this.fileName,
    this.mimeType,
    this.fileSize,
    required this.ocrStatus,
    this.ocrLastError,
    required this.archived,
    this.createdAt,
    this.retentionExpiresAt,
    this.linkedTransactionIds = const [],
    this.extractions = const [],
  });

  final String id;
  final String fileName;
  final String? mimeType;
  final int? fileSize;
  final OcrStatus ocrStatus;
  final String? ocrLastError;
  final bool archived;
  final DateTime? createdAt;

  /// Seven-year Australian record-keeping deadline for this receipt. Five years
  /// is the ATO's floor; Ledgable commits to seven.
  final DateTime? retentionExpiresAt;
  final List<String> linkedTransactionIds;

  /// Newest first; the first element is canonical.
  final List<Extraction> extractions;

  Extraction? get canonical => extractions.isEmpty ? null : extractions.first;

  bool get isMatched => linkedTransactionIds.isNotEmpty;

  factory ReceiptDetail.fromJson(Map<String, dynamic> json) => ReceiptDetail(
    id: asStringOr(json['id'], ''),
    fileName: asStringOr(json['fileName'], 'Receipt'),
    mimeType: asString(json['mimeType']),
    fileSize: asInt(json['fileSize']),
    ocrStatus: OcrStatus.parse(json['ocrStatus']),
    ocrLastError: asString(json['ocrLastError']),
    archived: asBool(json['archived']),
    createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal(),
    retentionExpiresAt: DateTime.tryParse('${json['retentionExpiresAt']}')?.toLocal(),
    linkedTransactionIds: asStringList(json['linkedTransactionIds']),
    extractions: asMapList(json['extractions']).map(Extraction.fromJson).toList(growable: false),
  );
}

/// The `202` from `POST /receipts`. Never the finished extraction — OCR runs on
/// background compute, so the capture screen gets one contract to handle.
class ReceiptUploadAccepted {
  const ReceiptUploadAccepted({required this.receiptId, required this.ocrStatus});

  final String receiptId;
  final OcrStatus ocrStatus;

  factory ReceiptUploadAccepted.fromJson(Map<String, dynamic> json) => ReceiptUploadAccepted(
    receiptId: asStringOr(json['receiptId'], ''),
    ocrStatus: OcrStatus.parse(json['ocrStatus']),
  );
}
