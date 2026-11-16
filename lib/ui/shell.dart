import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../state/providers.dart';
import '../theme.dart';

/// The signed-in frame: four tabs, a central capture action, and settings.
///
/// Capture sits in the middle and is the only elevated control, because
/// photographing a receipt is the reason the app gets installed. Everything else
/// is the reason it gets kept.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_Tab>[
    _Tab(Routes.dashboard, Icons.home_rounded, 'Home'),
    _Tab(Routes.review, Icons.rule_rounded, 'Review'),
    _Tab(Routes.invoices, Icons.description_rounded, 'Invoices'),
    _Tab(Routes.settings, Icons.person_outline_rounded, 'You'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.c;
    final location = GoRouterState.of(context).matchedLocation;
    final canWrite = ref.watch(canWriteProvider);

    return Scaffold(
      body: child,
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => context.push(Routes.receiptCapture),
              backgroundColor: colors.accent,
              foregroundColor: Theme.of(context).brightness == Brightness.dark ? kTealDark : kWhite,
              tooltip: 'Snap a receipt',
              child: const Icon(Icons.photo_camera_rounded),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final tab in _tabs)
                  Expanded(
                    child: _NavItem(
                      tab: tab,
                      // `startsWith` so a pushed detail route keeps its parent
                      // tab highlighted rather than clearing every tab.
                      active:
                          location == tab.path ||
                          (tab.path != Routes.dashboard && location.startsWith(tab.path)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active});

  final _Tab tab;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final tint = active ? colors.accent : colors.textTertiary;

    return Semantics(
      selected: active,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: active ? null : () => context.go(tab.path),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 22, color: tint),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: tint,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app bar every tab uses: workspace name, a switcher when there is more
/// than one workspace, and the user's initials.
class WorkspaceAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const WorkspaceAppBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final colors = context.c;

    return AppBar(
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (me != null)
            Text(
              me.workspace.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      actions: [
        ...actions,
        if (me != null && me.hasMultipleWorkspaces)
          IconButton(
            onPressed: () => showWorkspaceSwitcher(context, ref),
            icon: Icon(Icons.swap_horiz_rounded, color: colors.textSecondary),
            tooltip: 'Switch workspace',
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Workspace picker.
///
/// A bottom sheet rather than a menu because the list can be long and the names
/// are business names, which do not truncate well.
Future<void> showWorkspaceSwitcher(BuildContext context, WidgetRef ref) async {
  final me = ref.read(meProvider);
  if (me == null) return;

  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final colors = sheetContext.c;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Switch workspace', style: Theme.of(sheetContext).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: me.workspaces.length,
                itemBuilder: (_, index) {
                  final workspace = me.workspaces[index];
                  final active = workspace.id == me.workspace.id;
                  return ListTile(
                    leading: Icon(
                      active ? Icons.check_circle_rounded : Icons.business_rounded,
                      color: active ? colors.accent : colors.textTertiary,
                    ),
                    title: Text(workspace.name),
                    subtitle: Text(
                      workspace.isDefault
                          ? '${_roleLabel(workspace.role)} · default'
                          : _roleLabel(workspace.role),
                    ),
                    onTap: active ? null : () => Navigator.of(sheetContext).pop(workspace.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (selected == null) return;
  await ref.read(authControllerProvider.notifier).switchWorkspace(selected);
}

String _roleLabel(String role) {
  if (role.isEmpty) return 'Member';
  final lower = role.toLowerCase().replaceAll('_', ' ');
  return lower[0].toUpperCase() + lower.substring(1);
}
