import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../api/session_manager.dart';
import '../../config/env.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../widgets/common.dart';

/// Sign in with email and password.
///
/// There is no MFA step here because the mobile API does not have one: the
/// `/auth/login` contract is email + password + device descriptor, and the
/// route verifies credentials through `authenticateUser` without a second
/// factor. Adding a screen for a challenge the server never issues would be
/// inventing a flow. Noted in STATUS-app.md as a handoff.
///
/// There is deliberately no "Sign up" or pricing link. The app ships as a free
/// companion to the paid web service under Apple's guideline 3.1.3(f), which
/// means no purchasing inside the app and no call to action pointing at
/// purchasing outside it.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(email: _emailController.text, password: _passwordController.text);
      // The router moves on the state change; nothing to do here.
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        // A wrong email and a wrong password return an identical body on
        // purpose, so this endpoint cannot be used to discover which addresses
        // are registered. Show the server's message rather than guessing which
        // field was wrong.
        _error = error.isRateLimited && error.retryAfter != null
            ? '${error.displayMessage} Try again in ${error.retryAfter} seconds.'
            : error.displayMessage;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    final reason = ref.watch(authControllerProvider).signedOutReason;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              // Tablets and the iPhone Pro Max both get a readable column rather
              // than fields stretched the full width of the screen.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Wordmark(),
                    const SizedBox(height: 32),
                    Text('Sign in', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Use the same email and password as the Ledgable web app.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (reason != null && _error == null) ...[
                      _SignedOutNotice(reason: reason),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      autocorrect: false,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@business.com.au',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter your email address';
                        if (!text.contains('@') || text.length < 5) {
                          return 'That does not look like an email address';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.go,
                      autofillHints: const [AutofillHints.password],
                      enabled: !_submitting,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty ? 'Enter your password' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _InlineError(message: _error!),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Forgot your password? Reset it on ${Uri.parse(Env.webBaseUrl).host}, '
                      'then sign in here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ledgable keeps your books for seven years, as Australian '
                      'record-keeping rules require.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.receipt_long_rounded, size: 32, color: colors.accent),
        ),
        const SizedBox(height: 16),
        Text('Ledgable', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text('Australian bookkeeping, sorted', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// Explains why the app is back at sign-in, so a session that ended overnight
/// does not look like a bug.
class _SignedOutNotice extends StatelessWidget {
  const _SignedOutNotice({required this.reason});

  final SignedOutReason reason;

  @override
  Widget build(BuildContext context) {
    final (message, tone) = switch (reason) {
      SignedOutReason.userInitiated => ('You have been signed out.', PillTone.neutral),
      SignedOutReason.sessionExpired => (
        'Your session expired. Sign in again to carry on.',
        PillTone.warning,
      ),
      SignedOutReason.deviceRevoked => (
        'This device was signed out. If that was not you, change your password '
            'on the web as well.',
        PillTone.negative,
      ),
      SignedOutReason.accountDeleted => ('Your account has been deleted.', PillTone.neutral),
    };

    final colors = context.c;
    final accent = switch (tone) {
      PillTone.negative => colors.negative,
      PillTone.warning => colors.warning,
      _ => colors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// An inline error under the fields. Not a dialog: an error the user must
/// read to fix their input belongs next to the input.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.negative.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.negative.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: colors.negative),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.negative),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while the keychain is read on a cold start, and when `/me` failed on a
/// connection the user can retry.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final error = state.bootstrapError;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _Wordmark(),
                const SizedBox(height: 40),
                if (error == null)
                  const CircularProgressIndicator()
                else ...[
                  // The credentials are valid; only the network failed. Sending
                  // the user back to sign-in here would make them re-enter a
                  // password for no reason.
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(authControllerProvider.notifier).retryBootstrap(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                    child: const Text('Sign in as someone else'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
