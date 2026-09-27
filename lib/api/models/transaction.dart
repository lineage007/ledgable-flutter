import 'package:decimal/decimal.dart';

import '../../core/formatters.dart';
import '../../core/money.dart';
import 'page.dart';

/// A bank transaction in the review queue.
///
/// `total` is an integer count of **cents**, not dollars — the one place the
/// API departs from money-as-a-string, because the column is an integer in the
/// database. Negative for outflows.
class TransactionRecord {
  const TransactionRecord({
    required this.id,
    this.name,
    this.description,
    this.merchant,
    this.totalCents,
    this.currencyCode,
    this.type,
    this.categoryCode,
    this.issuedAt,
    required this.createdAt,
    this.postingStatus,
  });

  final String id;
  final String? name;
  final String? description;
  final String? merchant;
  final int? totalCents;
  final String? currencyCode;

  /// `"income"` or `"expense"`.
  final String? type;

  /// Null means the transaction is still in the review queue.
  final String? categoryCode;
  final DateTime? issuedAt;
  final DateTime createdAt;
  final String? postingStatus;

  bool get needsReview => categoryCode == null;

  bool get isIncome => type == 'income' || (totalCents != null && totalCents! > 0 && type == null);

  Decimal? get amount => totalCents == null ? null : Money.fromCents(totalCents!);

  /// Magnitude, for a UI that shows direction with an arrow rather than a sign.
  Decimal? get absAmount => amount?.abs();

  /// Best available label. Merchant is the most recognisable when present —
  /// a bank `description` is often a payment-processor string nobody reads.
  String get title => merchant ?? name ?? description ?? 'Transaction';

  /// Secondary line, suppressed when it would just repeat [title].
  String? get subtitle {
    final candidates = [description, name].whereType<String>().where((value) => value != title);
    return candidates.isEmpty ? null : candidates.first;
  }

  /// The date to show: when the bank issued it, falling back to when Ledgable
  /// first saw it.
  DateTime get effectiveDate => issuedAt ?? createdAt;

  factory TransactionRecord.fromJson(Map<String, dynamic> json) => TransactionRecord(
    id: asStringOr(json['id'], ''),
    name: asString(json['name']),
    description: asString(json['description']),
    merchant: asString(json['merchant']),
    totalCents: asInt(json['total']),
    currencyCode: asString(json['currencyCode']),
    type: asString(json['type']),
    categoryCode: asString(json['categoryCode']),
    issuedAt: DateTime.tryParse('${json['issuedAt']}')?.toLocal(),
    createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
    postingStatus: asString(json['postingStatus']),
  );

  TransactionRecord copyWith({String? categoryCode, bool clearCategory = false}) =>
      TransactionRecord(
        id: id,
        name: name,
        description: description,
        merchant: merchant,
        totalCents: totalCents,
        currencyCode: currencyCode,
        type: type,
        categoryCode: clearCategory ? null : (categoryCode ?? this.categoryCode),
        issuedAt: issuedAt,
        createdAt: createdAt,
        postingStatus: postingStatus,
      );
}

/// The result of `POST /transactions/{id}/categorise`.
///
/// [previousCategoryCode] is what makes undo possible: categorising is
/// reversible by categorising again, and the API hands back the prior value
/// precisely so the client can offer that.
class CategorisationResult {
  const CategorisationResult({
    required this.transactionId,
    required this.previousCategoryCode,
    required this.categoryCode,
  });

  final String transactionId;
  final String? previousCategoryCode;
  final String categoryCode;

  bool get isUndoable => previousCategoryCode != null;

  factory CategorisationResult.fromJson(Map<String, dynamic> json) => CategorisationResult(
    transactionId: asStringOr(json['transactionId'], ''),
    previousCategoryCode: asString(json['previousCategoryCode']),
    categoryCode: asStringOr(json['categoryCode'], ''),
  );
}

/// A category the user can assign.
///
/// The mobile API has no `/categories` endpoint, so this list is derived from
/// the codes the workspace has actually used on its already-categorised
/// transactions. That is an honest source — it cannot invent a code the
/// workspace does not hold, and the categories in recent use are the ones most
/// likely wanted next. It cannot offer a category the workspace has created but
/// never used; a real endpoint is filed as a handoff.
class CategoryOption {
  const CategoryOption({required this.code, required this.usageCount});

  final String code;

  /// How many of the sampled transactions carry this code. Drives the order, so
  /// the codes a business uses every week sit at the top of the picker.
  final int usageCount;

  /// Sentence case via the shared humaniser, so the picker and the rest of the
  /// app agree — "Materials and parts", with GST and PAYG left upper-cased. A
  /// bare account code like "620" has nothing to humanise and is shown as it is.
  String get label => RegExp(r'^\d+$').hasMatch(code.trim()) ? code : humanise(code);
}
