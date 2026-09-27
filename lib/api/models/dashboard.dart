import 'page.dart';

/// Receivables or payables, split by whether they are overdue.
class AgedTotals {
  const AgedTotals({
    required this.total,
    required this.count,
    required this.overdueTotal,
    required this.overdueCount,
  });

  final double total;
  final int count;
  final double overdueTotal;
  final int overdueCount;

  static const zero = AgedTotals(total: 0, count: 0, overdueTotal: 0, overdueCount: 0);

  bool get hasOverdue => overdueCount > 0;

  factory AgedTotals.fromJson(Map<String, dynamic>? json) {
    if (json == null) return zero;
    return AgedTotals(
      total: asDouble(json['total']) ?? 0,
      count: asInt(json['count']) ?? 0,
      overdueTotal: asDouble(json['overdueTotal']) ?? 0,
      overdueCount: asInt(json['overdueCount']) ?? 0,
    );
  }
}

/// Financial-year-to-date headline figures, on the Australian FY
/// (1 July – 30 June). Trend percentages are null when the server had no
/// comparable prior period, which is the normal state in a workspace's first
/// year — rendering that as "0%" would claim flat performance that was never
/// measured.
class DashboardKpis {
  const DashboardKpis({
    this.cashPosition,
    this.fyRevenue,
    this.fyRevenueTrendPct,
    this.fyExpenses,
    this.fyExpensesTrendPct,
    this.fyNetProfit,
    this.fyNetProfitTrendPct,
  });

  final double? cashPosition;
  final double? fyRevenue;
  final double? fyRevenueTrendPct;
  final double? fyExpenses;
  final double? fyExpensesTrendPct;
  final double? fyNetProfit;
  final double? fyNetProfitTrendPct;

  factory DashboardKpis.fromJson(Map<String, dynamic>? json) => DashboardKpis(
    cashPosition: asDouble(json?['cashPosition']),
    fyRevenue: asDouble(json?['fyRevenue']),
    fyRevenueTrendPct: asDouble(json?['fyRevenueTrendPct']),
    fyExpenses: asDouble(json?['fyExpenses']),
    fyExpensesTrendPct: asDouble(json?['fyExpensesTrendPct']),
    fyNetProfit: asDouble(json?['fyNetProfit']),
    fyNetProfitTrendPct: asDouble(json?['fyNetProfitTrendPct']),
  );
}

class MonthlyPoint {
  const MonthlyPoint({required this.month, required this.income, required this.expenses});

  final String month;
  final double income;
  final double expenses;

  factory MonthlyPoint.fromJson(Map<String, dynamic> json) => MonthlyPoint(
    month: asStringOr(json['month'], ''),
    income: asDouble(json['income']) ?? 0,
    expenses: asDouble(json['expenses']) ?? 0,
  );
}

class ExpenseCategorySlice {
  const ExpenseCategorySlice({required this.name, required this.value, required this.pct});

  final String name;
  final double value;
  final double pct;

  factory ExpenseCategorySlice.fromJson(Map<String, dynamic> json) => ExpenseCategorySlice(
    name: asStringOr(json['name'], 'Uncategorised'),
    value: asDouble(json['value']) ?? 0,
    pct: asDouble(json['pct']) ?? 0,
  );
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    this.date,
    required this.description,
    this.merchant,
    required this.amount,
    this.category,
    required this.isIncome,
  });

  final String id;
  final DateTime? date;
  final String description;
  final String? merchant;
  final double amount;
  final String? category;
  final bool isIncome;

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
    id: asStringOr(json['id'], ''),
    date: DateTime.tryParse('${json['date']}')?.toLocal(),
    description: asStringOr(json['description'], 'Transaction'),
    merchant: asString(json['merchant']),
    amount: asDouble(json['amount']) ?? 0,
    category: asString(json['category']),
    isIncome: asString(json['type']) == 'income',
  );
}

/// `GET /dashboard`.
///
/// Reuses the same `loadDashboardInsights` the web dashboard renders from, so
/// the phone and the browser cannot disagree about cash position or
/// receivables.
class Dashboard {
  const Dashboard({
    required this.workspaceName,
    required this.kpis,
    required this.receivables,
    required this.payables,
    required this.monthlySeries,
    required this.topExpenseCategories,
    required this.recentActivity,
  });

  final String workspaceName;
  final DashboardKpis kpis;
  final AgedTotals receivables;
  final AgedTotals payables;
  final List<MonthlyPoint> monthlySeries;
  final List<ExpenseCategorySlice> topExpenseCategories;
  final List<ActivityItem> recentActivity;

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
    workspaceName: asStringOr(asMap(json['workspace'])?['name'], 'Your business'),
    kpis: DashboardKpis.fromJson(asMap(json['kpis'])),
    receivables: AgedTotals.fromJson(asMap(json['receivables'])),
    payables: AgedTotals.fromJson(asMap(json['payables'])),
    monthlySeries: asMapList(
      json['monthlySeries'],
    ).map(MonthlyPoint.fromJson).toList(growable: false),
    topExpenseCategories: asMapList(
      json['topExpenseCategories'],
    ).map(ExpenseCategorySlice.fromJson).toList(growable: false),
    recentActivity: asMapList(
      json['recentActivity'],
    ).map(ActivityItem.fromJson).toList(growable: false),
  );
}
