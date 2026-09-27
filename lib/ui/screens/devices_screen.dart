import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models/session_models.dart';
import '../../core/formatters.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../widgets/common.dart';

/// Settings → Devices. Every handset signed in to this account, and a way to
/// sign one out remotely.
///
/// Push tokens are never shown, only whether one is registered: a push token is
/// a sending capability, not an attribute of the device.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final _revoking = <String>{};

  Future<void> _revoke(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(device.current ? 'Sign out this phone?' : 'Sign out ${device.displayName}?'),
        content: Text(
          device.current
              // Revoking the current device is allowed and behaves as a logout,
              // so say that plainly rather than letting it surprise anyone.
              ? 'This is the phone you are using. You will be signed out straight away '
                    'and will need your password to get back in.'
              : 'That device will be signed out immediately and will need the account '
                    'password to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: context.c.negative),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _revoking.add(device.id));
    try {
      await ref.read(devicesRepositoryProvider).revoke(device.id);
      if (!mounted) return;
      if (device.current) {
        // The server has revoked this device's refresh chain, so the local
        // credentials are now dead. Clear them rather than waiting for the next
        // call to 401.
        await ref.read(authControllerProvider.notifier).signOut();
        return;
      }
      ref.invalidate(devicesProvider);
      showSuccessToast(context, '${device.displayName} signed out.');
    } on Object catch (error) {
      if (!mounted) return;
      showErrorToast(context, error);
    } finally {
      if (mounted) setState(() => _revoking.remove(device.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Signed-in devices')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(devicesProvider.future),
          child: switch (snapshot) {
            AsyncError(:final error) => ListView(
              padding: const EdgeInsets.only(top: 60),
              children: [ErrorView(error: error, onRetry: () => ref.invalidate(devicesProvider))],
            ),
            AsyncData(:final value) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Each install of the Ledgable app is its own device. Reinstalling '
                  'creates a new one, so an old entry here is normal.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                for (final device in value) ...[
                  _DeviceCard(
                    device: device,
                    busy: _revoking.contains(device.id),
                    onRevoke: device.isRevoked ? null : () => _revoke(device),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.busy, this.onRevoke});

  final Device device;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return LedgerCard(
      accent: device.current ? colors.accent : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.cardRaised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              device.platform == 'IOS' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
              size: 20,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (device.current)
                      const StatusPill(label: 'This phone', tone: PillTone.accent)
                    else if (device.isRevoked)
                      const StatusPill(label: 'Signed out', tone: PillTone.neutral),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (device.osVersion != null) device.osVersion!,
                    if (device.appVersion != null) 'Ledgable ${device.appVersion}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Last used ${Dates.sinceShort(device.lastSeenAt)} · '
                  'added ${Dates.relativeInline(device.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (device.pushEnabled) ...[
                  const SizedBox(height: 6),
                  const StatusPill(
                    label: 'Notifications on',
                    tone: PillTone.neutral,
                    icon: Icons.notifications_active_outlined,
                  ),
                ],
                if (onRevoke != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: busy ? null : onRevoke,
                      style: TextButton.styleFrom(foregroundColor: colors.negative),
                      child: busy
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(device.current ? 'Sign out this phone' : 'Sign out'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
