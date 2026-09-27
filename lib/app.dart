import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/providers.dart';
import 'theme.dart';
import 'ui/screens/approvals_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/delete_account_screen.dart';
import 'ui/screens/devices_screen.dart';
import 'ui/screens/invoice_detail_screen.dart';
import 'ui/screens/invoices_screen.dart';
import 'ui/screens/new_invoice_screen.dart';
import 'ui/screens/receipt_capture_screen.dart';
import 'ui/screens/receipt_review_screen.dart';
import 'ui/screens/receipts_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/sign_in_screen.dart';
import 'ui/screens/transaction_review_screen.dart';
import 'ui/shell.dart';

/// Route paths, in one place so a deep link and a push payload cannot disagree
/// with what the router actually registered.
class Routes {
  const Routes._();

  static const splash = '/';
  static const signIn = '/sign-in';
  static const dashboard = '/home';
  static const review = '/review';
  static const receipts = '/receipts';
  static const receiptCapture = '/receipts/capture';
  static const invoices = '/invoices';
  static const newInvoice = '/invoices/new';
  static const approvals = '/approvals';
  static const settings = '/settings';
  static const devices = '/settings/devices';
  static const deleteAccount = '/settings/delete-account';

  static String receiptReview(String receiptId) => '/receipts/$receiptId';

  static String invoiceDetail(String invoiceId) => '/invoices/$invoiceId';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// The router.
///
/// Redirect logic lives in exactly one place: [AuthStage] decides whether the
/// app is showing the splash, the sign-in screen, or the signed-in shell. No
/// screen pushes to sign-in itself, so a 401 from any corner of the app lands
/// the same way.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthStage>(ref.read(authControllerProvider).stage);
  ref.listen<AuthStage>(
    authControllerProvider.select((state) => state.stage),
    (_, stage) => auth.value = stage,
  );
  ref.onDispose(auth.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      final stage = ref.read(authControllerProvider).stage;
      final location = state.matchedLocation;

      return switch (stage) {
        AuthStage.restoring => location == Routes.splash ? null : Routes.splash,
        AuthStage.signedOut => location == Routes.signIn ? null : Routes.signIn,
        AuthStage.signedIn =>
          location == Routes.splash || location == Routes.signIn ? Routes.dashboard : null,
      };
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),

      // The four tabs plus settings share a shell so the bottom bar does not
      // rebuild on navigation and the tab state survives switching.
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: Routes.dashboard, builder: (_, _) => const DashboardScreen()),
          GoRoute(path: Routes.review, builder: (_, _) => const TransactionReviewScreen()),
          GoRoute(path: Routes.receipts, builder: (_, _) => const ReceiptsScreen()),
          GoRoute(path: Routes.invoices, builder: (_, _) => const InvoicesScreen()),
          GoRoute(path: Routes.approvals, builder: (_, _) => const ApprovalsScreen()),
          GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
        ],
      ),

      // Pushed over the shell: full-screen tasks that should hide the tab bar.
      GoRoute(
        path: Routes.receiptCapture,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const ReceiptCaptureScreen(),
      ),
      GoRoute(
        path: Routes.newInvoice,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NewInvoiceScreen(),
      ),
      GoRoute(
        path: Routes.devices,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const DevicesScreen(),
      ),
      GoRoute(
        path: Routes.deleteAccount,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/receipts/:receiptId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => ReceiptReviewScreen(receiptId: state.pathParameters['receiptId']!),
      ),
      GoRoute(
        path: '/invoices/:invoiceId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['invoiceId']!),
      ),
    ],
  );
});

class LedgableApp extends ConsumerWidget {
  const LedgableApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Ledgable',
      debugShowCheckedModeBanner: false,
      theme: ledgableTheme(),
      darkTheme: ledgableDarkTheme(),
      // Follow the handset. Both themes are built and checked for contrast, so
      // there is no reason to force one.
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
