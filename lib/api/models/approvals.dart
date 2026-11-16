import 'package:decimal/decimal.dart';

import '../../core/money.dart';
import 'invoice.dart' show ContactRef;
import 'page.dart';

/// NES leave types.
///
/// `PERSONAL` is the single sick + carer's balance — under the National
/// Employment Standards they are one entitlement of 10 days a year for a
/// full-time employee, not two separate balances. The label reflects that so
/// nobody reads the app as implying a second allowance exists.
enum LeaveType {
  annual,
  personal,
  compassionate,
  unpaid,
  longService,
  other;

  static LeaveType parse(Object? raw) => switch (asString(raw)?.toUpperCase()) {
    'ANNUAL' => LeaveType.annual,
    'PERSONAL' => LeaveType.personal,
    'COMPASSIONATE' => LeaveType.compassionate,
    'UNPAID' => LeaveType.unpaid,
    'LONG_SERVICE' => LeaveType.longService,
    _ => LeaveType.other,
  };

  String get label => switch (this) {
    LeaveType.annual => 'Annual leave',
    LeaveType.personal => "Personal / carer's leave",
    LeaveType.compassionate => 'Compassionate leave',
    LeaveType.unpaid => 'Unpaid leave',
    LeaveType.longService => 'Long service leave',
    LeaveType.other => 'Leave',
  };
}

class BillApproval {
  const BillApproval({
    required this.id,
    required this.billNumber,
    this.reference,
    required this.status,
    this.date,
    this.dueDate,
    this.total,
    this.amountDue,
    required this.currencyCode,
    this.supplier,
    required this.deepLink,
  });

  final String id;
  final String billNumber;
  final String? reference;
  final String status;
  final DateTime? date;
  final DateTime? dueDate;
  final Decimal? total;
  final Decimal? amountDue;
  final String currencyCode;
  final ContactRef? supplier;

  /// Web path to act on this item. Approvals are read-only in v1, so this is
  /// the only way to act — see [Approvals].
  final String deepLink;

  String get supplierName => supplier?.name ?? 'Unknown supplier';

  factory BillApproval.fromJson(Map<String, dynamic> json) {
    final supplier = asMap(json['supplier']);
    return BillApproval(
      id: asStringOr(json['id'], ''),
      billNumber: asStringOr(json['billNumber'], '—'),
      reference: asString(json['reference']),
      status: asStringOr(json['status'], ''),
      date: DateTime.tryParse('${json['date']}')?.toLocal(),
      dueDate: DateTime.tryParse('${json['dueDate']}')?.toLocal(),
      total: Money.parse(json['total']),
      amountDue: Money.parse(json['amountDue']),
      currencyCode: asStringOr(json['currencyCode'], 'AUD'),
      supplier: supplier == null ? null : ContactRef.fromJson(supplier),
      deepLink: asStringOr(json['deepLink'], '/bills'),
    );
  }
}

class PayRunApproval {
  const PayRunApproval({
    required this.id,
    this.periodStart,
    this.periodEnd,
    this.payDate,
    this.grossTotal,
    this.taxTotal,
    this.superTotal,
    this.netTotal,
    required this.deepLink,
  });

  final String id;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? payDate;
  final Decimal? grossTotal;

  /// PAYG withholding.
  final Decimal? taxTotal;

  /// Super guarantee for the period.
  final Decimal? superTotal;
  final Decimal? netTotal;
  final String deepLink;

  factory PayRunApproval.fromJson(Map<String, dynamic> json) => PayRunApproval(
    id: asStringOr(json['id'], ''),
    periodStart: DateTime.tryParse('${json['periodStart']}')?.toLocal(),
    periodEnd: DateTime.tryParse('${json['periodEnd']}')?.toLocal(),
    payDate: DateTime.tryParse('${json['payDate']}')?.toLocal(),
    grossTotal: Money.parse(json['grossTotal']),
    taxTotal: Money.parse(json['taxTotal']),
    superTotal: Money.parse(json['superTotal']),
    netTotal: Money.parse(json['netTotal']),
    deepLink: asStringOr(json['deepLink'], '/payroll'),
  );
}

class LeaveApproval {
  const LeaveApproval({
    required this.id,
    required this.leaveType,
    this.startDate,
    this.endDate,
    this.hours,
    this.notes,
    this.employee,
    required this.deepLink,
  });

  final String id;
  final LeaveType leaveType;
  final DateTime? startDate;
  final DateTime? endDate;
  final Decimal? hours;
  final String? notes;
  final ContactRef? employee;
  final String deepLink;

  String get employeeName => employee?.name ?? 'Employee';

  /// `7.6 hours` reads better than `7.60 hours`, and hours arrive as a decimal
  /// string because a half-day is 3.8 on a 38-hour week.
  String get hoursLabel {
    final value = hours;
    if (value == null) return '—';
    final text = value.toString();
    final trimmed = text.contains('.')
        ? text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : text;
    return '$trimmed ${trimmed == '1' ? 'hour' : 'hours'}';
  }

  factory LeaveApproval.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    return LeaveApproval(
      id: asStringOr(json['id'], ''),
      leaveType: LeaveType.parse(json['leaveType']),
      startDate: DateTime.tryParse('${json['startDate']}')?.toLocal(),
      endDate: DateTime.tryParse('${json['endDate']}')?.toLocal(),
      hours: Money.parse(json['hours']),
      notes: asString(json['notes']),
      employee: employee == null ? null : ContactRef.fromJson(employee),
      deepLink: asStringOr(json['deepLink'], '/payroll/leave'),
    );
  }
}

/// `GET /approvals` — everything waiting on the signed-in user.
///
/// **Read-only in v1, by design rather than omission.** Approving a pay run
/// commits PAYG withholding and super guarantee liabilities; approving leave
/// deducts an accrued balance. Those state machines live inside the payroll
/// routes, and putting an approve button here before they are shared services
/// would mean a second copy of the transition rules that could drift from the
/// first. Each item carries a `deepLink` to the web page that can act on it.
class Approvals {
  const Approvals({
    required this.bills,
    required this.payRuns,
    required this.leave,
    required this.billCount,
    required this.payRunCount,
    required this.leaveCount,
  });

  final List<BillApproval> bills;
  final List<PayRunApproval> payRuns;
  final List<LeaveApproval> leave;

  /// Server-side counts, which can exceed the lists: each is capped at 25
  /// items, so "3 of 40 bills" must not be reported as 3.
  final int billCount;
  final int payRunCount;
  final int leaveCount;

  static const empty = Approvals(
    bills: [],
    payRuns: [],
    leave: [],
    billCount: 0,
    payRunCount: 0,
    leaveCount: 0,
  );

  int get totalCount => billCount + payRunCount + leaveCount;

  bool get isEmpty => totalCount == 0;

  factory Approvals.fromJson(Map<String, dynamic> json) {
    final counts = asMap(json['counts']);
    return Approvals(
      bills: asMapList(json['bills']).map(BillApproval.fromJson).toList(growable: false),
      payRuns: asMapList(json['payRuns']).map(PayRunApproval.fromJson).toList(growable: false),
      leave: asMapList(json['leave']).map(LeaveApproval.fromJson).toList(growable: false),
      billCount: asInt(counts?['bills']) ?? 0,
      payRunCount: asInt(counts?['payRuns']) ?? 0,
      leaveCount: asInt(counts?['leave']) ?? 0,
    );
  }
}
