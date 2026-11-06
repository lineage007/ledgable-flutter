import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/dashboard.dart';
import '../../app.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../shell.dart';
import '../widgets/common.dart';

/// Home. Cash, receivables, payables and FY profit, from the same
/// `loadDashboardInsights` the web dashboard renders from — so the phone and the
/// browser cannot disagree about the numbers.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: const WorkspaceAppBar(title: 'Home'),
      body: RefreshIndicator(
        onRefresh: () => refreshQuietly(() => ref.refresh(dashboardProvider.future)),
        child: switch (snapshot) {
          AsyncData(:final value) => _DashboardBody(dashboard: value),
          AsyncError(:final error) => ListView(
            // Inside a ListView so pull-to-refresh still works on the error
            // state — an offline dashboard is the most likely place someone
            // needs to retry.
            padding: const EdgeInsets.only(top: 80),
            children: [ErrorView(error: error, onRetry: () => ref.invalidate(dashboardProvider))],
          ),
          _ => const _DashboardSkeleton(),
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final kpis = dashboard.kpis;
    final fyLabel = Dates.financialYearLabel(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _CashCard(cashPosition: kpis.cashPosition),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MoneyTile(
                label: 'Owed to you',
                amount: dashboard.receivables.total,
                count: dashboard.receivables.count,
                overdueAmount: dashboard.receivables.overdueTotal,
                overdueCount: dashboard.receivables.overdueCount,
                icon: Icons.south_west_rounded,
                positive: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MoneyTile(
                label: 'You owe',
                amount: dashboard.payables.total,
                count: dashboard.payables.count,
                overdueAmount: dashboard.payables.overdueTotal,
                overdueCount: dashboard.payables.overdueCount,
                icon: Icons.north_east_rounded,
                positive: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionHeader(title: 'This financial year', subtitle: '$fyLabel, 1 July to 30 June'),
        _FyCard(kpis: kpis),
        if (dashboard.monthlySeries.length > 1) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Last 12 months'),
          _MonthlyChart(points: dashboard.monthlySeries),
        ],
        if (dashboard.topExpenseCategories.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Where the money went'),
          _ExpenseBreakdown(slices: dashboard.topExpenseCategories),
        ],
        if (dashboard.recentActivity.isNotEmpty) ...[
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Recent activity',
            action: TextButton(
              onPressed: () => context.go(Routes.review),
              child: const Text('Review'),
            ),
          ),
          LedgerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < dashboard.recentActivity.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.c.border),
                  _ActivityRow(item: dashboard.recentActivity[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The one figure someone opens the app to check.
class _CashCard extends StatelessWidget {
  const _CashCard({required this.cashPosition});

  final double? cashPosition;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return LedgerCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, size: 18, color: colors.accent),
              const SizedBox(width: 8),
              Text('Cash position', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.formatDouble(cashPosition),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 38,
                color: (cashPosition ?? 0) < 0 ? colors.negative : colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (cashPosition == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Connect a bank feed on the web to see your cash position.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Receivables or payables, with the overdue portion called out.
class _MoneyTile extends StatelessWidget {
  const _MoneyTile({
    required this.label,
    required this.amount,
    required this.count,
    required this.overdueAmount,
    required this.overdueCount,
    required this.icon,
    required this.positive,
  });

  final String label;
  final double amount;
  final int count;
  final double overdueAmount;
  final int overdueCount;
  final IconData icon;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: positive ? colors.positive : colors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.formatDouble(amount, whole: true),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (overdueCount > 0)
            StatusPill(
              label: '${Money.formatDouble(overdueAmount, whole: true)} overdue',
              tone: PillTone.negative,
            )
          else
            Text(
              count == 0 ? 'Nothing outstanding' : '$count ${count == 1 ? 'invoice' : 'invoices'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _FyCard extends StatelessWidget {
  const _FyCard({required this.kpis});

  final DashboardKpis kpis;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return LedgerCard(
      child: Column(
        children: [
          _FyRow(
            label: 'Income',
            amount: kpis.fyRevenue,
            trendPct: kpis.fyRevenueTrendPct,
            // More income is better, so a rise is good news.
            riseIsGood: true,
          ),
          Divider(height: 20, color: colors.border),
          _FyRow(
            label: 'Expenses',
            amount: kpis.fyExpenses,
            trendPct: kpis.fyExpensesTrendPct,
            // More expense is not, so the same arrow gets the opposite colour.
            riseIsGood: false,
          ),
          Divider(height: 20, color: colors.border),
          _FyRow(
            label: 'Net profit',
            amount: kpis.fyNetProfit,
            trendPct: kpis.fyNetProfitTrendPct,
            riseIsGood: true,
            emphasise: true,
          ),
        ],
      ),
    );
  }
}

class _FyRow extends StatelessWidget {
  const _FyRow({
    required this.label,
    required this.amount,
    required this.trendPct,
    required this.riseIsGood,
    this.emphasise = false,
  });

  final String label;
  final double? amount;
  final double? trendPct;
  final bool riseIsGood;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final theme = Theme.of(context);
    final trend = trendPct;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasise
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Money.formatDouble(amount, whole: true),
              style: (emphasise ? theme.textTheme.headlineSmall : theme.textTheme.bodyLarge)
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: emphasise && (amount ?? 0) < 0 ? colors.negative : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            // Null trend means the server had no comparable prior period, which
            // is the normal state in a workspace's first year. Showing nothing
            // is honest; showing 0% would claim flat performance.
            if (trend != null)
              Row(
                children: [
                  Icon(
                    trend >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 13,
                    color: (trend >= 0) == riseIsGood ? colors.positive : colors.negative,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${Money.formatTrendPct(trend)} on last year',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: (trend >= 0) == riseIsGood ? colors.positive : colors.negative,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.points});

  final List<MonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final maxValue = points
        .expand((point) => [point.income, point.expenses])
        .fold<double>(0, (a, b) => b > a ? b : a);

    return LedgerCard(
      child: Column(
        children: [
          Row(
            children: [
              _Legend(colour: colors.accent, label: 'Income'),
              const SizedBox(width: 16),
              _Legend(colour: colors.warning, label: 'Expenses'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue == 0 ? 1 : maxValue * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.cardRaised,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${Dates.monthLabel(points[group.x].month)}\n'
                      '${Money.formatDouble(rod.toY, whole: true)}',
                      TextStyle(color: colors.textPrimary, fontSize: 12),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: colors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) return const SizedBox.shrink();
                        // Twelve labels do not fit on a phone; show every other.
                        if (points.length > 6 && index.isOdd) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            Dates.monthLabel(points[index].month),
                            style: TextStyle(fontSize: 10, color: colors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 2,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].income,
                          color: colors.accent,
                          width: 6,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                        BarChartRodData(
                          toY: points[i].expenses,
                          color: colors.warning,
                          width: 6,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Top expense categories as labelled bars rather than a pie: a pie of six
/// similar slices on a phone is unreadable, and the question being asked is
/// "which is biggest", which a ranked bar answers directly.
class _ExpenseBreakdown extends StatelessWidget {
  const _ExpenseBreakdown({required this.slices});

  final List<ExpenseCategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return LedgerCard(
      child: Column(
        children: [
          for (var i = 0; i < slices.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slices[i].name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      Money.formatDouble(slices[i].value, whole: true),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (slices[i].pct / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation(colors.accent),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (item.isIncome ? colors.positive : colors.warning).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 16,
              color: item.isIncome ? colors.positive : colors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.merchant ?? item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  [
                    Dates.relative(item.date),
                    humanise(item.category),
                  ].where((part) => part.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // A "+" and a spoken label, so money in is not told apart by colour
          // alone.
          Semantics(
            label: '${item.isIncome ? 'Money in' : 'Money out'} '
                '${Money.formatDouble(item.amount.abs())}',
            excludeSemantics: true,
            child: Text(
              '${item.isIncome ? '+' : ''}${Money.formatDouble(item.amount.abs())}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: item.isIncome ? colors.positive : colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: const [
        LedgerCard(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(width: 110, height: 12),
              SizedBox(height: 14),
              SkeletonBlock(width: 190, height: 32),
            ],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: LedgerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBlock(width: 70, height: 10),
                    SizedBox(height: 12),
                    SkeletonBlock(width: 90, height: 20),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: LedgerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBlock(width: 70, height: 10),
                    SizedBox(height: 12),
                    SkeletonBlock(width: 90, height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
