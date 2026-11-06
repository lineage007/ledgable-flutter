import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/models/approvals.dart';
import '../../config/env.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../shell.dart';
import '../widgets/common.dart';

/// Everything waiting on the signed-in user: bills, pay runs, leave.
///
/// **Read-only, and the screen says so.** Approving a pay run commits PAYG
/// withholding and super guarantee liabilities; approving leave deducts an
/// accrued balance. Those state machines live inside the payroll routes on the
/// web, and putting an Approve button here before they are shared services would
/// mean a second copy of the transition rules that could drift from the first.
/// So each item opens the web page that can act on it, and the app is honest
/// about why rather than showing a button that does not work.
class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(approvalsProvider);

    return Scaffold(
      appBar: const WorkspaceAppBar(title: 'Approvals'),
      body: RefreshIndicator(
        onRefresh: () => refreshQuietly(() => ref.refresh(approvalsProvider.future)),
        child: switch (snapshot) {
          AsyncError(:final error) => ListView(
            padding: const EdgeInsets.only(top: 80),
            children: [ErrorView(error: error, onRetry: () => ref.invalidate(approvalsProvider))],
          ),
          AsyncData(:final value) when value.isEmpty => ListView(
            padding: const EdgeInsets.only(top: 60),
            children: const [
              SizedBox(
                height: 380,
                child: EmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'Nothing waiting on you',
                  message:
                      'Bills to approve, pay runs to sign off and leave requests '
                      'show up here.',
                ),
              ),
            ],
          ),
          AsyncData(:final value) => _ApprovalsBody(approvals: value),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ApprovalsBody extends StatelessWidget {
  const _ApprovalsBody({required this.approvals});

  final Approvals approvals;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _ReadOnlyNotice(),
        const SizedBox(height: 16),
        if (approvals.bills.isNotEmpty) ...[
          SectionHeader(
            title: 'Bills to approve',
            subtitle: _cappedSubtitle(approvals.bills.length, approvals.billCount),
          ),
          for (final bill in approvals.bills) ...[
            _BillCard(bill: bill),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
        ],
        if (approvals.payRuns.isNotEmpty) ...[
          SectionHeader(
            title: 'Pay runs to sign off',
            subtitle: _cappedSubtitle(approvals.payRuns.length, approvals.payRunCount),
          ),
          for (final payRun in approvals.payRuns) ...[
            _PayRunCard(payRun: payRun),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
        ],
        if (approvals.leave.isNotEmpty) ...[
          SectionHeader(
            title: 'Leave requests',
            subtitle: _cappedSubtitle(approvals.leave.length, approvals.leaveCount),
          ),
          for (final leave in approvals.leave) ...[
            _LeaveCard(leave: leave),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  /// The API caps each list at 25. Showing "25" when 40 are waiting would
  /// understate the queue.
  static String? _cappedSubtitle(int shown, int total) =>
      total > shown ? 'Showing $shown of $total' : null;
}

class _ReadOnlyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: colors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Approving happens on the web for now. Signing off a pay run commits '
              'PAYG and super, so Ledgable keeps that in one place rather than two.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the web page that can act on an item.
Future<void> _openOnWeb(BuildContext context, String deepLink) async {
  final url = Uri.parse(Env.webUrl(deepLink));
  final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    showErrorToast(context, StateError('Could not open $url'));
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountLabel,
    required this.deepLink,
    this.tone = PillTone.warning,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final String amountLabel;
  final String deepLink;
  final PillTone tone;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final accent = switch (tone) {
      PillTone.negative => colors.negative,
      PillTone.positive => colors.positive,
      PillTone.accent => colors.accent,
      PillTone.neutral => colors.border,
      PillTone.warning => colors.warning,
    };

    return LedgerCard(
      accent: accent,
      onTap: () => _openOnWeb(context, deepLink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(amountLabel, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.open_in_new_rounded, size: 13, color: colors.textTertiary),
              const SizedBox(width: 6),
              Text('Open on the web to approve', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill});

  final BillApproval bill;

  @override
  Widget build(BuildContext context) {
    return _ApprovalCard(
      icon: Icons.request_quote_outlined,
      title: bill.supplierName,
      subtitle: [
        bill.billNumber,
        if (bill.dueDate != null) 'due ${Dates.relativeInline(bill.dueDate)}',
      ].join(' · '),
      amount: Money.format(bill.amountDue ?? bill.total),
      amountLabel: 'to pay',
      deepLink: bill.deepLink,
    );
  }
}

class _PayRunCard extends StatelessWidget {
  const _PayRunCard({required this.payRun});

  final PayRunApproval payRun;

  @override
  Widget build(BuildContext context) {
    final period = payRun.periodStart == null || payRun.periodEnd == null
        ? 'Pay run'
        : '${Dates.formatDayMonth(payRun.periodStart)} – '
              '${Dates.format(payRun.periodEnd)}';

    return _ApprovalCard(
      icon: Icons.payments_outlined,
      title: period,
      subtitle: payRun.payDate == null
          ? 'Calculated, not signed off'
          : 'Pay date ${Dates.format(payRun.payDate)}',
      amount: Money.format(payRun.netTotal),
      amountLabel: 'net pay',
      deepLink: payRun.deepLink,
      footer: Column(
        children: [
          DetailRow(label: 'Gross', value: Money.format(payRun.grossTotal)),
          // Named in full: "tax" alone is ambiguous on a pay run, and the
          // liability this commits is PAYG withholding specifically.
          DetailRow(label: 'PAYG withholding', value: Money.format(payRun.taxTotal)),
          DetailRow(label: 'Super guarantee', value: Money.format(payRun.superTotal)),
        ],
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave});

  final LeaveApproval leave;

  @override
  Widget build(BuildContext context) {
    final sameDay =
        leave.startDate != null &&
        leave.endDate != null &&
        // Calendar days, not elapsed hours: 4 to 5 Oct is 23 hours in Sydney.
        DateUtils.isSameDay(leave.startDate, leave.endDate);

    return _ApprovalCard(
      icon: Icons.event_busy_outlined,
      title: leave.employeeName,
      subtitle: sameDay
          ? Dates.format(leave.startDate)
          : '${Dates.formatDayMonth(leave.startDate)} – ${Dates.format(leave.endDate)}',
      amount: leave.hoursLabel.split(' ').first,
      amountLabel: 'hours',
      deepLink: leave.deepLink,
      tone: PillTone.accent,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(label: leave.leaveType.label, tone: PillTone.accent),
          if (leave.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              leave.notes!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
