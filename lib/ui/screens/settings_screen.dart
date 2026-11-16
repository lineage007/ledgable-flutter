import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/models/session_models.dart';
import '../../app.dart';
import '../../config/env.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../shell.dart';
import '../widgets/common.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Account, workspace, devices, legal, sign out, and account deletion.
///
/// There is deliberately no "Upgrade", "Subscribe" or "See pricing" anywhere on
/// this screen. The app ships as a free companion to the paid web service under
/// Apple's guideline 3.1.3(f), which permits no purchasing inside the app and no
/// call to action pointing at purchasing outside it.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final version = ref.watch(_appVersionProvider);

    return Scaffold(
      appBar: const WorkspaceAppBar(title: 'You'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (me != null) _IdentityCard(me: me),
          const SizedBox(height: 24),
          if (me != null && me.hasMultipleWorkspaces) ...[
            const SectionHeader(title: 'Workspace'),
            LedgerCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.business_rounded),
                title: Text(me.workspace.name),
                subtitle: Text(
                  '${_roleLabel(me.membership.role)} · '
                  '${me.workspaces.length} workspaces',
                ),
                trailing: const Icon(Icons.swap_horiz_rounded),
                onTap: () => showWorkspaceSwitcher(context, ref),
              ),
            ),
            const SizedBox(height: 24),
          ],
          const SectionHeader(title: 'Security'),
          LedgerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_iphone_rounded),
                  title: const Text('Signed-in devices'),
                  subtitle: const Text('See and sign out other phones'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.devices),
                ),
                Divider(height: 1, color: context.c.border),
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('Change your password'),
                  subtitle: const Text('Opens Ledgable on the web'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                  onTap: () => _open(context, Env.webUrl('/settings/security')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Your data'),
          LedgerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  // The archive is web-only, so the app links out rather than
                  // offering an in-app export that cannot work.
                  title: const Text('Download a copy of your data'),
                  subtitle: const Text('Opens Ledgable on the web'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                  onTap: () => _open(context, Env.webUrl('/settings/backups')),
                ),
                Divider(height: 1, color: context.c.border),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                  onTap: () => _open(context, Env.privacyPolicyUrl),
                ),
                Divider(height: 1, color: context.c.border),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: const Text('Terms of service'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                  onTap: () => _open(context, Env.termsUrl),
                ),
                Divider(height: 1, color: context.c.border),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: const Text('Get help'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                  onTap: () => _open(context, Env.supportUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Account'),
          LedgerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: context.c.textSecondary),
                  title: const Text('Sign out'),
                  subtitle: const Text('Only this device'),
                  onTap: () => _confirmSignOut(context, ref),
                ),
                Divider(height: 1, color: context.c.border),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: context.c.negative),
                  title: Text('Delete my account', style: TextStyle(color: context.c.negative)),
                  subtitle: const Text('Permanent. See what happens first.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.deleteAccount),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Text(
                  'Ledgable for ${Theme.of(context).platform == TargetPlatform.iOS ? 'iOS' : 'Android'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                switch (version) {
                  AsyncData(:final value) => Text(
                    'Version $value',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  _ => const SizedBox.shrink(),
                },
                const SizedBox(height: 4),
                Text(
                  Uri.parse(Env.apiBaseUrl).host,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.c.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need your email and password to sign back in on this device. '
          'Your books are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
  }

  static Future<void> _open(BuildContext context, String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showErrorMessage(context, 'Could not open $url');
    }
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return LedgerCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: colors.accentSoft, shape: BoxShape.circle),
            child: Center(
              child: Text(
                me.user.initials,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colors.accent),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me.user.name.isEmpty ? me.user.email : me.user.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  me.user.email,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                StatusPill(
                  label: '${_roleLabel(me.membership.role)} of ${me.workspace.name}',
                  tone: PillTone.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(String role) {
  if (role.isEmpty) return 'Member';
  final lower = role.toLowerCase().replaceAll('_', ' ');
  return lower[0].toUpperCase() + lower.substring(1);
}
