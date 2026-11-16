import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models/approvals.dart';
import '../api/models/dashboard.dart';
import '../api/models/invoice.dart';
import '../api/models/page.dart';
import '../api/models/session_models.dart';
import '../api/session_manager.dart';
import '../api/token_store.dart';
import '../data/account_repository.dart';
import '../data/approvals_repository.dart';
import '../data/auth_repository.dart';
import '../data/dashboard_repository.dart';
import '../data/invoices_repository.dart';
import '../data/receipts_repository.dart';
import '../data/transactions_repository.dart';

/// One [ApiClient] per app, holding the session. Overridden in tests with a
/// client wired to a fake adapter.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(() => client.session.dispose());
  return client;
});

final sessionManagerProvider = Provider<SessionManager>(
  (ref) => ref.watch(apiClientProvider).session,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepository(ref.watch(apiClientProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);

final receiptsRepositoryProvider = Provider<ReceiptsRepository>(
  (ref) => ReceiptsRepository(ref.watch(apiClientProvider)),
);

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(apiClientProvider)),
);

final invoicesRepositoryProvider = Provider<InvoicesRepository>(
  (ref) => InvoicesRepository(ref.watch(apiClientProvider)),
);

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepository(ref.watch(apiClientProvider)),
);

final approvalsRepositoryProvider = Provider<ApprovalsRepository>(
  (ref) => ApprovalsRepository(ref.watch(apiClientProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(apiClientProvider)),
);

/// Where the app is in its own lifecycle. The router reads only this.
enum AuthStage {
  /// Reading the keychain. Shows the splash.
  restoring,

  /// No credentials, or they were rejected.
  signedOut,

  /// Signed in and `/me` has been read.
  signedIn,
}

class AuthState {
  const AuthState({required this.stage, this.me, this.signedOutReason, this.bootstrapError});

  final AuthStage stage;

  /// Null until `/me` returns. Everything workspace-scoped waits for it.
  final Me? me;

  /// Why the last session ended, for the message on the sign-in screen.
  final SignedOutReason? signedOutReason;

  /// A `/me` failure after a successful token restore — a network problem on a
  /// cold start, typically. Held rather than thrown so the splash can offer a
  /// retry instead of dumping the user back to sign-in with valid credentials.
  final String? bootstrapError;

  const AuthState.restoring() : this(stage: AuthStage.restoring);

  bool get isSignedIn => stage == AuthStage.signedIn;

  String? get activeWorkspaceId => me?.workspace.id;

  AuthState copyWith({
    AuthStage? stage,
    Me? me,
    SignedOutReason? signedOutReason,
    String? bootstrapError,
    bool clearError = false,
  }) => AuthState(
    stage: stage ?? this.stage,
    me: me ?? this.me,
    signedOutReason: signedOutReason ?? this.signedOutReason,
    bootstrapError: clearError ? null : (bootstrapError ?? this.bootstrapError),
  );
}

/// Read-only views of the current session, so screens do not each reach for
/// `authControllerProvider.select(...)`.
final meProvider = Provider<Me?>((ref) => ref.watch(authControllerProvider).me);

final canWriteProvider = Provider<bool>((ref) => ref.watch(meProvider)?.canWrite ?? false);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

/// Owns sign-in, sign-out, `/me` and workspace selection.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState.restoring()) {
    // A 401 that the interceptor could not recover from arrives here, from
    // wherever in the app it happened, so no screen has to handle it.
    _subscription = _session.onSignedOut.listen((reason) {
      if (!mounted) return;
      state = AuthState(stage: AuthStage.signedOut, signedOutReason: reason);
    });
  }

  final Ref _ref;
  late final StreamSubscription<SignedOutReason> _subscription;

  SessionManager get _session => _ref.read(sessionManagerProvider);

  AuthRepository get _auth => _ref.read(authRepositoryProvider);

  /// Called once at startup: restore credentials, then read `/me`.
  Future<void> bootstrap() async {
    state = const AuthState.restoring();
    final AuthTokens? tokens;
    try {
      tokens = await _session.restore();
    } on Object {
      // Uncaught, this left the splash spinning with no way forward.
      state = const AuthState(
        stage: AuthStage.restoring,
        bootstrapError: 'Could not read your saved sign-in on this device. Try again.',
      );
      return;
    }
    if (tokens == null) {
      state = const AuthState(stage: AuthStage.signedOut);
      return;
    }
    await _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await _auth.me();
      // Keep the selection and the server's view of the active workspace in
      // step: without this, a workspace the user has since left stays pinned in
      // the keychain and every call 403s.
      await _session.selectWorkspace(me.workspace.id);
      state = AuthState(stage: AuthStage.signedIn, me: me);
    } on Object catch (error) {
      if (!_session.hasSession) {
        // The credentials were rejected during /me; onSignedOut has already
        // moved the state.
        return;
      }
      state = AuthState(stage: AuthStage.restoring, bootstrapError: _describe(error));
    }
  }

  Future<void> retryBootstrap() => bootstrap();

  /// Sign in, then read `/me`. Throws on failure so the form can show the
  /// message inline rather than the app silently staying on the sign-in screen.
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signIn(email: email, password: password);
    await _loadMe();
    if (state.stage != AuthStage.signedIn) {
      throw StateError('Signed in but could not load your workspace. Try again.');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // signOutLocally emits on the stream, which moves the state.
  }

  /// Switch workspace. `/me` is re-read because permissions and the membership
  /// role differ per workspace, and every workspace-scoped provider is
  /// invalidated so nothing keeps showing the previous business's figures.
  Future<void> switchWorkspace(String workspaceId) async {
    if (workspaceId == state.activeWorkspaceId) return;
    await _session.selectWorkspace(workspaceId);
    await _loadMe();
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(approvalsProvider);
    _ref.invalidate(invoiceListProvider);
  }

  /// After account deletion: the server has revoked everything, and the local
  /// teardown already happened in the repository.
  void markAccountDeleted() {
    state = const AuthState(
      stage: AuthStage.signedOut,
      signedOutReason: SignedOutReason.accountDeleted,
    );
  }

  static String _describe(Object error) =>
      error is Exception ? error.toString().replaceFirst(RegExp(r'^\w+Exception: '), '') : '$error';

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Dashboard KPIs. `autoDispose` so leaving the tab drops the cached figures
/// rather than showing a stale cash position on return.
final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  ref.watch(authControllerProvider.select((state) => state.activeWorkspaceId));
  return ref.watch(dashboardRepositoryProvider).load();
});

final approvalsProvider = FutureProvider.autoDispose<Approvals>((ref) {
  ref.watch(authControllerProvider.select((state) => state.activeWorkspaceId));
  return ref.watch(approvalsRepositoryProvider).load();
});

/// Which invoice status the list is filtered to.
final invoiceFilterProvider = StateProvider<InvoiceStatus?>((ref) => null);

final invoiceListProvider = FutureProvider.autoDispose<Paged<InvoiceSummary>>((ref) {
  ref.watch(authControllerProvider.select((state) => state.activeWorkspaceId));
  final status = ref.watch(invoiceFilterProvider);
  return ref.watch(invoicesRepositoryProvider).list(status: status);
});

final invoiceDetailProvider = FutureProvider.autoDispose.family<InvoiceDetail, String>((
  ref,
  invoiceId,
) {
  return ref.watch(invoicesRepositoryProvider).detail(invoiceId);
});

/// Devices for Settings → Devices.
final devicesProvider = FutureProvider.autoDispose<List<Device>>(
  (ref) => ref.watch(devicesRepositoryProvider).list(),
);
