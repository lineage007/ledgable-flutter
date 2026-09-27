import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/models/account_deletion.dart';
import '../../config/env.dart';
import '../../core/formatters.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../widgets/common.dart';

final _deletionPreviewProvider = FutureProvider.autoDispose<AccountDeletionPreview>(
  (ref) => ref.watch(accountRepositoryProvider).deletionPreview(),
);

/// Delete this account. Required by App Store guideline 5.1.1(v) and by Google
/// Play, and built to be honest rather than merely present.
///
/// The thing this screen has to get across is that **deleting the login is not
/// deleting the books**. A Ledgable account is attached to financial records
/// under a seven-year retention commitment — five years is the ATO's floor — so
/// "delete my account" cannot mean "destroy the ledger". The server decides one
/// of four outcomes per workspace and explains each in plain language; this
/// screen shows all of them, plus any subscription still billing, before it asks
/// for the password.
///
/// The export is offered before the confirmation, not after.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _passwordController = TextEditingController();

  bool _exportAcknowledged = false;
  bool _understood = false;
  bool _deleting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete(AccountDeletionPreview preview) async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This cannot be undone. Your login, your password and every signed-in '
              'device are destroyed immediately.',
              style: Theme.of(dialogContext).textTheme.bodyLarge,
            ),
            if (preview.retained > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${preview.retained} '
                '${preview.retained == 1 ? 'workspace' : 'workspaces'} will be frozen '
                'and kept for ${preview.retentionYears} years. You will get a '
                'reference to quote if the business ever needs them back — write it '
                'down.',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep my account'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: dialogContext.c.negative),
            child: const Text('Delete it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .deleteAccount(
            password: _passwordController.text,
            exportAcknowledged: _exportAcknowledged,
          );
      if (!mounted) return;
      // The repository already cleared the keychain. Show the reference before
      // the router moves to sign-in, because after this response there is no
      // account left to look it up from.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _DeletionReceiptDialog(result: result),
      );
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).markAccountDeleted();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst(RegExp(r'^\w+Exception: '), '');
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(_deletionPreviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Delete my account')),
      body: SafeArea(
        child: switch (snapshot) {
          AsyncError(:final error) => ListView(
            padding: const EdgeInsets.only(top: 60),
            children: [
              ErrorView(error: error, onRetry: () => ref.invalidate(_deletionPreviewProvider)),
            ],
          ),
          AsyncData(:final value) => _buildForm(value),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _buildForm(AccountDeletionPreview preview) {
    final colors = context.c;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.negative.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.negative.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.delete_forever_rounded, size: 20, color: colors.negative),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This deletes your login, not your books',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: colors.negative),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Your password, your sessions, your signed-in devices and your '
                'two-factor setup are destroyed straight away, and your name and '
                'email are overwritten.\n\n'
                'Financial records are different. Australian law requires them to be '
                'kept, and Ledgable commits to ${preview.retentionYears} years — so a '
                'workspace with a ledger and nobody left in it is frozen rather than '
                'erased.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'What happens to your workspaces',
          subtitle: preview.workspaces.isEmpty
              ? null
              : '${preview.workspaces.length} '
                    '${preview.workspaces.length == 1 ? 'workspace' : 'workspaces'}',
        ),
        if (preview.workspaces.isEmpty)
          LedgerCard(
            child: Text(
              'You are not a member of any workspace, so there is nothing to keep.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          for (final workspace in preview.workspaces) ...[
            _OutcomeCard(workspace: workspace, retentionYears: preview.retentionYears),
            const SizedBox(height: 10),
          ],
        if (preview.liveSubscriptions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card_rounded, size: 18, color: colors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You are still paying for '
                        '${preview.liveSubscriptions.length == 1 ? 'a workspace' : '${preview.liveSubscriptions.length} workspaces'}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: colors.warning, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Deleting your account stops these from renewing. There is no refund '
                  'for the rest of the period you have already paid for. If you want '
                  'billing stopped sooner, cancel in Settings → Billing on the web '
                  'first.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 8),
                for (final subscription in preview.liveSubscriptions)
                  Text(
                    '• ${subscription.name} (${humanise(subscription.status)})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const SectionHeader(title: 'Take a copy first'),
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ledgable can put together an archive of your invoices, receipts and '
                'transactions. The download is on the web — the phone cannot build it.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final url = Env.webUrl(preview.exportAvailableAt);
                  final opened = await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!mounted) return;
                  if (opened) {
                    setState(() => _exportAcknowledged = true);
                  } else {
                    showErrorToast(context, StateError('Could not open $url'));
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open backups on the web'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _exportAcknowledged,
                onChanged: (value) => setState(() => _exportAcknowledged = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(
                  "I have what I need, or I don't want a copy",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Confirm'),
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (preview.activeDeviceCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${preview.activeDeviceCount} '
                    '${preview.activeDeviceCount == 1 ? 'device' : 'devices'} will be '
                    'signed out, including this one.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              CheckboxListTile(
                value: _understood,
                onChanged: _deleting
                    ? null
                    : (value) => setState(() => _understood = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'I understand this is permanent and cannot be undone',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                enabled: !_deleting,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Your password',
                  // The bearer token proves the handset is trusted, not that the
                  // person holding it owns the account.
                  helperText: 'Required so an unlocked phone cannot do this on its own',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: colors.negative),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: colors.negative),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _deleting || !_understood ? null : () => _delete(preview),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.negative,
                  foregroundColor: kWhite,
                ),
                child: _deleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kWhite),
                      )
                    : const Text('Delete my account'),
              ),
              const SizedBox(height: 10),
              Text(
                'You can also do this on the web. Deleting an account is explained in '
                'full in our privacy policy.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.workspace, required this.retentionYears});

  final WorkspaceDeletionOutcome workspace;
  final int retentionYears;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final (tone, icon) = switch (workspace.outcome) {
      DeletionOutcome.untouched => (PillTone.positive, Icons.check_circle_outline_rounded),
      DeletionOutcome.transferred => (PillTone.accent, Icons.swap_horiz_rounded),
      DeletionOutcome.retained => (PillTone.warning, Icons.lock_clock_rounded),
      DeletionOutcome.deleted => (PillTone.negative, Icons.delete_outline_rounded),
      DeletionOutcome.unknown => (PillTone.neutral, Icons.help_outline_rounded),
    };
    final accent = switch (tone) {
      PillTone.positive => colors.positive,
      PillTone.accent => colors.accent,
      PillTone.warning => colors.warning,
      PillTone.negative => colors.negative,
      PillTone.neutral => colors.border,
    };

    return LedgerCard(
      accent: workspace.outcome.isLoss ? accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusPill(label: workspace.outcome.label, tone: tone),
            ],
          ),
          const SizedBox(height: 8),
          // The server's own wording, safe to show verbatim.
          Text(
            workspace.reason,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          if (workspace.outcome == DeletionOutcome.retained) ...[
            const SizedBox(height: 8),
            Text(
              'Frozen read-only for $retentionYears years, then purged.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// The deletion receipt.
///
/// Not dismissible by tapping outside: the reference cannot be looked up again
/// once this closes, because there is no account left to look it up from.
class _DeletionReceiptDialog extends StatelessWidget {
  const _DeletionReceiptDialog({required this.result});

  final AccountDeletionResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final failures = result.failedCancellations;

    return AlertDialog(
      title: const Text('Your account is deleted'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keep this reference. It is what support needs if the business ever '
              'wants its records back.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.cardRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: SelectableText(
                result.reference,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (result.retainedWorkspaces.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Kept until', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final workspace in result.retainedWorkspaces)
                Text(
                  '${workspace.name} — ${Dates.format(workspace.retentionUntil)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
            if (failures.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.negative.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.negative.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A subscription is still billing',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: colors.negative, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    // The one case the client MUST surface: the account is gone
                    // but money is still moving, and there is no account left to
                    // cancel it from.
                    Text(
                      'Ledgable could not stop billing for '
                      '${failures.map((failure) => failure.name).join(', ')}. '
                      'Contact support with the reference above and it will be '
                      'sorted. Ledgable has been alerted as well.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}
