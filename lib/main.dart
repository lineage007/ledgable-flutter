import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/formatters.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // en_AU date symbols are not compiled into intl by default. Without this every
  // Australian date format in the app throws at runtime.
  await initialiseFormatting();

  // Edge-to-edge with a transparent status bar. Icon brightness is left to the
  // system so it follows the light/dark theme rather than being pinned dark and
  // disappearing against the dark canvas.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const ProviderScope(child: _Bootstrap()));
}

/// Starts the session restore and then hands over to [LedgableApp].
///
/// Kept separate from `main()` so the restore runs inside the widget tree, where
/// a failure can be shown on the splash instead of crashing before there is
/// anything to show it on.
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap();

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) => const LedgableApp();
}
