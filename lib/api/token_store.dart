import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// The credentials held on a device, as one immutable value.
///
/// Access and refresh token are kept together deliberately. The refresh token
/// is single-use and presenting a spent one revokes the whole device, so the
/// two must never be written independently — a crash between two writes
/// leaving a new access token beside an already-spent refresh token is exactly
/// the state that locks a user out. [TokenStore.save] persists this object as
/// a single value for that reason.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.deviceId,
  });

  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final String deviceId;

  /// Treat the access token as expired slightly early. A token that the server
  /// will reject by the time the request lands is worse than one refresh too
  /// many, and 30s covers ordinary clock skew and a slow radio.
  static const _expiryGuard = Duration(seconds: 30);

  bool isAccessExpired({DateTime? now}) =>
      (now ?? DateTime.now()).isAfter(accessExpiresAt.subtract(_expiryGuard));

  bool isRefreshExpired({DateTime? now}) => (now ?? DateTime.now()).isAfter(refreshExpiresAt);

  /// Built from a `TokenPair` or `LoginResponse` body. `expiresIn` is seconds
  /// until the access token dies (900); it is converted to an absolute instant
  /// here so nothing downstream has to remember when it was received.
  factory AuthTokens.fromJson(Map<String, dynamic> json, {DateTime? receivedAt}) {
    final issued = receivedAt ?? DateTime.now();
    final expiresIn = json['expiresIn'];
    final seconds = expiresIn is int ? expiresIn : int.tryParse('$expiresIn') ?? 900;
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      accessExpiresAt: issued.add(Duration(seconds: seconds)),
      refreshToken: json['refreshToken'] as String,
      refreshExpiresAt:
          DateTime.tryParse('${json['refreshExpiresAt']}')?.toLocal() ??
          issued.add(const Duration(days: 60)),
      deviceId: json['deviceId'] as String,
    );
  }

  Map<String, dynamic> toStorageJson() => {
    'accessToken': accessToken,
    'accessExpiresAt': accessExpiresAt.toIso8601String(),
    'refreshToken': refreshToken,
    'refreshExpiresAt': refreshExpiresAt.toIso8601String(),
    'deviceId': deviceId,
  };

  static AuthTokens? fromStorageJson(Map<String, dynamic> json) {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final device = json['deviceId'];
    if (access is! String || refresh is! String || device is! String) return null;
    final accessExpiry = DateTime.tryParse('${json['accessExpiresAt']}');
    final refreshExpiry = DateTime.tryParse('${json['refreshExpiresAt']}');
    if (accessExpiry == null || refreshExpiry == null) return null;
    return AuthTokens(
      accessToken: access,
      accessExpiresAt: accessExpiry.toLocal(),
      refreshToken: refresh,
      refreshExpiresAt: refreshExpiry.toLocal(),
      deviceId: device,
    );
  }

  /// Never interpolate a token into a log line. `toString` is overridden so an
  /// accidental `print($tokens)` or a Sentry breadcrumb cannot leak one.
  @override
  String toString() => 'AuthTokens(deviceId: $deviceId, accessExpiresAt: $accessExpiresAt)';
}

/// Persistence for credentials and the install id.
///
/// An interface rather than a concrete class so tests can substitute
/// [InMemoryTokenStore] — the refresh-rotation tests are the most important in
/// the suite and they must not depend on a platform keychain.
abstract class TokenStore {
  Future<AuthTokens?> read();

  /// Atomic from the app's point of view: one write, both tokens, or neither.
  Future<void> save(AuthTokens tokens);

  Future<void> clear();

  /// A UUID generated on first launch and kept for the life of the install.
  /// Not a hardware identifier — iOS offers no stable one, and App Store
  /// policy would not permit using it this way if it did. Reinstalling
  /// produces a new id and therefore a new device row.
  Future<String> installId();

  /// Workspace the user last had selected, so a cold start lands where they
  /// left off instead of on the default workspace.
  Future<String?> readWorkspaceId();

  Future<void> saveWorkspaceId(String? workspaceId);
}

/// Keychain (iOS) / Keystore-backed EncryptedSharedPreferences (Android).
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage, Uuid? uuid})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // `first_unlock` rather than the default `unlocked`: a refresh on
            // a background fetch must be able to read the token while the
            // handset is locked. `this_device_only` keeps it out of iCloud
            // Keychain, so signing in on one phone does not hand a
            // single-use refresh token to another device that would then
            // spend it and revoke both.
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          ),
      _uuid = uuid ?? const Uuid();

  static const _tokensKey = 'ledgable.auth.tokens.v1';
  static const _installIdKey = 'ledgable.install_id.v1';
  static const _workspaceKey = 'ledgable.workspace_id.v1';

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  @override
  Future<AuthTokens?> read() async {
    final raw = await _storage.read(key: _tokensKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthTokens.fromStorageJson(decoded);
    } on FormatException {
      // Corrupt blob: drop it rather than wedging every launch on a parse
      // error. The cost is one sign-in.
      await _storage.delete(key: _tokensKey);
      return null;
    }
  }

  @override
  Future<void> save(AuthTokens tokens) =>
      _storage.write(key: _tokensKey, value: jsonEncode(tokens.toStorageJson()));

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokensKey);
    await _storage.delete(key: _workspaceKey);
    // installId deliberately survives: it identifies this install to the
    // server across sign-outs, so signing back in reuses the same device row
    // rather than accumulating a new one on every logout.
  }

  @override
  Future<String> installId() async {
    final existing = await _storage.read(key: _installIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _uuid.v4();
    await _storage.write(key: _installIdKey, value: generated);
    return generated;
  }

  @override
  Future<String?> readWorkspaceId() => _storage.read(key: _workspaceKey);

  @override
  Future<void> saveWorkspaceId(String? workspaceId) => workspaceId == null
      ? _storage.delete(key: _workspaceKey)
      : _storage.write(key: _workspaceKey, value: workspaceId);
}

/// Test double. Also used by `flutter run -d macos` style local runs where no
/// keychain entitlement is configured.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore({AuthTokens? tokens, String? installId, String? workspaceId})
    : _tokens = tokens,
      _installId = installId,
      _workspaceId = workspaceId;

  AuthTokens? _tokens;
  String? _installId;
  String? _workspaceId;

  /// How many times [save] has been called — the rotation tests assert on this
  /// to prove a new refresh token was persisted before being used.
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> save(AuthTokens tokens) async {
    _tokens = tokens;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
    _workspaceId = null;
    clearCount++;
  }

  @override
  Future<String> installId() async => _installId ??= const Uuid().v4();

  @override
  Future<String?> readWorkspaceId() async => _workspaceId;

  @override
  Future<void> saveWorkspaceId(String? workspaceId) async => _workspaceId = workspaceId;
}
