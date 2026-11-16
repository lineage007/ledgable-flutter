import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/models/session_models.dart';
import '../api/session_manager.dart';
import '../api/token_store.dart';

/// Sign in, sign out, and `/me`.
class AuthRepository {
  AuthRepository(this._client, {DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final ApiClient _client;
  final DeviceInfoPlugin _deviceInfo;

  SessionManager get session => _client.session;

  /// Exchange email and password for a device-bound token pair.
  ///
  /// The pair is persisted before this returns, so a crash immediately after
  /// sign-in comes back signed in.
  Future<User> signIn({required String email, required String password}) async {
    final descriptor = await describeDevice();
    final body = await _client.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password, 'device': descriptor.toJson()},
      skipAuth: true,
      using: _client.authlessDio,
    );

    await session.adopt(AuthTokens.fromJson(body));
    final user = body['user'];
    return User.fromJson(user is Map<String, dynamic> ? user : const {});
  }

  /// Bootstrap context: user, device, active workspace, memberships and
  /// permissions. Called after sign-in and on every cold start.
  Future<Me> me() async => Me.fromJson(await _client.get('/me'));

  /// Sign this device out.
  ///
  /// The refresh token goes in the body as well as the bearer header, because
  /// an app backgrounded past the 15-minute access TTL must still be able to
  /// sign out. The local teardown happens whatever the server says: leaving
  /// credentials on the handset because the network was down would be the
  /// wrong failure mode for a sign-out button.
  Future<void> signOut() async {
    final refreshToken = session.tokens?.refreshToken;
    try {
      await _client.post(
        '/auth/logout',
        body: refreshToken == null ? const <String, dynamic>{} : {'refreshToken': refreshToken},
        skipAuth: true,
        using: _client.authlessDio,
      );
    } on ApiException {
      // Idempotent endpoint; a failure here only means the server was not
      // reached. The device is signed out either way.
    } on SessionExpiredException {
      // Nothing to revoke.
    }
    await session.signOutLocally(SignedOutReason.userInitiated);
  }

  /// The descriptor sent with `/auth/login`.
  ///
  /// `installId` is a UUID this app generated on first launch and keeps in the
  /// keychain. It is deliberately not a hardware identifier: iOS offers no
  /// stable one, and App Store policy would not permit using it this way if it
  /// did. The name is the handset's own, which is what makes the Devices list
  /// readable — "Gary's iPhone" rather than a UUID.
  Future<DeviceDescriptor> describeDevice({String? pushToken}) async {
    final installId = await session.installId();
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    String platform;
    String? deviceName;
    String? osVersion;

    if (Platform.isIOS) {
      platform = 'IOS';
      final info = await _deviceInfo.iosInfo;
      deviceName = info.name;
      osVersion = 'iOS ${info.systemVersion}';
    } else if (Platform.isAndroid) {
      platform = 'ANDROID';
      final info = await _deviceInfo.androidInfo;
      deviceName = '${info.manufacturer} ${info.model}'.trim();
      osVersion = 'Android ${info.version.release}';
    } else {
      // Desktop and web runs exist only for development. The API enum accepts
      // IOS or ANDROID, so a macOS debug run reports as iOS rather than being
      // rejected at validation.
      platform = 'IOS';
      deviceName = 'Ledgable dev (${Platform.operatingSystem})';
      osVersion = Platform.operatingSystemVersion;
    }

    return DeviceDescriptor(
      installId: installId,
      platform: platform,
      deviceName: deviceName,
      appVersion: appVersion,
      osVersion: osVersion,
      pushToken: pushToken,
    );
  }
}

/// Settings → Devices.
class DevicesRepository {
  DevicesRepository(this._client);

  final ApiClient _client;

  Future<List<Device>> list() async {
    final body = await _client.get('/devices');
    final devices = body['devices'];
    if (devices is! List) return const [];
    return devices
        .whereType<Map>()
        .map((entry) => Device.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Sign a device out remotely. Revoking the current device is allowed and
  /// behaves as a logout, so the caller must check [Device.current] and clear
  /// the keychain when it was this handset.
  Future<void> revoke(String deviceId) => _client.delete('/devices/$deviceId');
}
