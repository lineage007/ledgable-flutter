import '../api/api_client.dart';
import '../api/models/account_deletion.dart';
import '../api/session_manager.dart';

class AccountRepository {
  AccountRepository(this._client);

  final ApiClient _client;

  /// What deleting this account would do, per workspace. Shown before asking
  /// for confirmation — the outcome is decided server-side and the reasons are
  /// safe to show verbatim.
  ///
  /// No workspace header: deletion is an account operation, and a caller who
  /// never finished setup has no workspace to send.
  Future<AccountDeletionPreview> deletionPreview() async =>
      AccountDeletionPreview.fromJson(await _client.get('/account', noWorkspace: true));

  /// Delete the account.
  ///
  /// Deletes the login — password, sessions, every mobile device and refresh
  /// token, MFA enrolment — and anonymises the profile. It does **not** destroy
  /// financial records: a workspace whose last member this was, and which holds
  /// a ledger, is frozen read-only for seven years and then purged.
  ///
  /// [password] is mandatory on top of the bearer token, so an unlocked phone
  /// left on a table cannot be used to delete its owner's account.
  ///
  /// The keychain is cleared as soon as the server confirms, because every
  /// credential this device holds has just been revoked server-side and keeping
  /// them would only produce a confusing 401 on the next tap.
  Future<AccountDeletionResult> deleteAccount({
    required String password,
    required bool exportAcknowledged,
  }) async {
    final body = await _client.delete(
      '/account',
      noWorkspace: true,
      body: {
        'password': password,
        // The literal string the API requires, as a guard against a replayed
        // request body.
        'confirm': 'DELETE',
        'exportAcknowledged': exportAcknowledged,
      },
    );
    final result = AccountDeletionResult.fromJson(body);
    await _client.session.signOutLocally(SignedOutReason.accountDeleted);
    return result;
  }
}
