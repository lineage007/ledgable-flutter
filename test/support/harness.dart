import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgable_app/api/api_client.dart';
import 'package:ledgable_app/api/models/session_models.dart';
import 'package:ledgable_app/api/token_store.dart';
import 'package:ledgable_app/core/formatters.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ledgable_app/state/providers.dart';
import 'package:ledgable_app/theme.dart';

import 'fake_http.dart';

/// A signed-in session wired to a fake HTTP adapter.
class TestHarness {
  TestHarness._(this.http, this.client, this.overrides);

  final FakeHttpAdapter http;
  final ApiClient client;
  final List<Override> overrides;

  /// Builds a harness whose [ApiClient] is already holding a live token pair, so
  /// widget tests exercise the screens rather than the sign-in flow.
  static Future<TestHarness> signedIn({FakeHttpAdapter? adapter}) async {
    final http = adapter ?? FakeHttpAdapter();
    final client = ApiClient(
      store: InMemoryTokenStore(),
      baseUrl: 'https://example.test/api/mobile/v1',
    );
    client.useAdapter(http);
    await client.session.adopt(
      AuthTokens(
        accessToken: 'access-1',
        accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
        refreshToken: 'refresh-1',
        refreshExpiresAt: DateTime.now().add(const Duration(days: 60)),
        deviceId: 'device-1',
      ),
    );
    await client.session.selectWorkspace('ws-1');

    return TestHarness._(http, client, [apiClientProvider.overrideWithValue(client)]);
  }

  /// Wraps [child] in the providers, theme and localisations a screen needs.
  ///
  /// [brightness] drives which theme is applied, so the same widget test can
  /// assert a screen renders in both light and dark.
  Widget wrap(
    Widget child, {
    Brightness brightness = Brightness.light,
    Me? me,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        ...overrides,
        ...extraOverrides,
        if (me != null) authControllerProvider.overrideWith((ref) => _StubAuthController(ref, me)),
      ],
      child: MaterialApp(
        // The real app turns this off too; in a golden it paints a red diagonal
        // across the top-right corner and hides whatever sits under it.
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark ? ledgableDarkTheme() : ledgableTheme(),
        home: child,
      ),
    );
  }
}

/// An [AuthController] that starts already signed in, bypassing the keychain and
/// the `/me` round trip for widget tests that only care about one screen.
class _StubAuthController extends AuthController {
  _StubAuthController(super.ref, Me me) {
    state = AuthState(stage: AuthStage.signedIn, me: me);
  }

  @override
  Future<void> bootstrap() async {}
}

/// A `/me` payload with everything a screen reads.
Me testMe({
  String workspaceName = 'Salt & Stone Pty Ltd',
  List<String> permissions = const ['READ', 'WRITE'],
  int workspaceCount = 1,
}) {
  return Me.fromJson({
    'user': {'id': 'u-1', 'email': 'gary@saltandstone.test', 'name': 'Gary Cakir'},
    'device': {'id': 'device-1', 'installId': 'install-1', 'platform': 'IOS'},
    'workspace': {
      'id': 'ws-1',
      'name': workspaceName,
      'kind': 'BUSINESS',
      'status': 'ACTIVE',
      'ownerUserId': 'u-1',
    },
    'membership': {'id': 'm-1', 'role': 'OWNER', 'isDefault': true},
    'workspaces': [
      for (var i = 0; i < workspaceCount; i++)
        {
          'id': i == 0 ? 'ws-1' : 'ws-${i + 1}',
          'name': i == 0 ? workspaceName : 'Workspace ${i + 1}',
          'role': 'OWNER',
          'isDefault': i == 0,
        },
    ],
    'permissions': permissions,
  });
}

/// Loads the app's bundled fonts into the test binding.
///
/// `flutter test` renders every glyph as a filled box by default, which makes a
/// golden useless for spotting a label that no longer fits. Registering the real
/// Inter and Plus Jakarta Sans files means the goldens show actual text and a
/// truncation regression is visible in the diff.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;

  const families = <String, List<String>>{
    'Inter': [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ],
    'Plus Jakarta Sans': [
      'assets/fonts/PlusJakartaSans-SemiBold.ttf',
      'assets/fonts/PlusJakartaSans-Bold.ttf',
      'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
    ],
  };

  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final bytes = await File(path).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await _loadMaterialIcons();
}

/// Registers the Material icon font from the Flutter SDK cache.
///
/// Icons otherwise render as empty boxes in a golden, which hides an icon that
/// has gone missing or changed. Resolved from the SDK rather than vendored,
/// because copying Google's icon font into the repository to make tests prettier
/// is not worth the licence question. Skipped silently when the path does not
/// resolve — a machine without it still gets every other assertion.
Future<void> _loadMaterialIcons() async {
  final flutterRoot = _flutterRoot();
  if (flutterRoot == null) return;
  final file = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(await file.readAsBytes())));
  await loader.load();
}

/// The SDK root, derived from the Dart executable that is running this test.
String? _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  // …/flutter/bin/cache/dart-sdk/bin/dart
  var directory = File(Platform.resolvedExecutable).parent;
  for (var depth = 0; depth < 6; depth++) {
    if (Directory('${directory.path}/bin/cache/artifacts/material_fonts').existsSync()) {
      return directory.path;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  return null;
}

bool _fontsLoaded = false;

/// Loads en_AU date symbols, and stubs the app-version channel.
///
/// `PackageInfo.fromPlatform()` has no platform channel in a widget test, and
/// the sign-in path reads it to build the device descriptor, so without this the
/// first `pumpAndSettle` after a sign-in tap never returns.
Future<void> setUpFormatting() async {
  await initialiseFormatting();
  PackageInfo.setMockInitialValues(
    appName: 'Ledgable',
    packageName: 'co.ledgable.app',
    version: '1.0.0',
    buildNumber: '4',
    buildSignature: '',
  );
}

/// Settle the tree *and* let an in-flight HTTP call complete.
///
/// `pumpAndSettle` stops as soon as no frame is scheduled, and Dio schedules a
/// zero-duration timer inside `fetch`. Under the test binding's fake clock that
/// timer needs one more pump with a duration to fire, so a request started by a
/// tap or a swipe has not reached the adapter when `pumpAndSettle` returns. This
/// pumps, advances the clock, and settles again.
Future<void> settleWithNetwork(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
  // A second round covers a call that only starts once the first has resolved —
  // the undo path, and the refresh-then-retry path.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// Advances the clock in fixed steps without waiting for the tree to go quiet.
///
/// `pumpAndSettle` never returns while anything is animating, and a progress
/// spinner animates forever. Use this when a screen is expected to still be
/// showing one — or a dialog over one — after the call under test resolves.
Future<void> pumpNetwork(WidgetTester tester, {int steps = 6}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pins the surface to a consistent phone size so goldens do not depend on the
/// host's default 800×600 test window.
void useIPhoneSurface(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
