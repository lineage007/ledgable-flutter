/// Build-time configuration.
///
/// Everything here arrives via `--dart-define`, so a build can be pointed at
/// a local Next.js dev server without editing code, and so the repository
/// never contains an environment value. There are no secrets in this file by
/// construction: the mobile client holds no API key, only the per-device
/// tokens it earns at sign-in, and those live in the keychain.
///
/// ```
/// flutter run --dart-define=LEDGABLE_API_BASE_URL=http://localhost:7331
/// ```
class Env {
  const Env._();

  /// Origin of the Ledgable deployment. The `/api/mobile/v1` prefix is added
  /// by the client, so this is a bare origin with no trailing slash.
  static const String apiBaseUrl = String.fromEnvironment(
    'LEDGABLE_API_BASE_URL',
    defaultValue: 'https://ledgable.co',
  );

  /// Where approvals and other web-only surfaces deep-link to. Same origin as
  /// the API in every deployment shipped so far, but kept separate because a
  /// local API run against production data would want the production web URL.
  static const String webBaseUrl = String.fromEnvironment(
    'LEDGABLE_WEB_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static String get apiRoot => '${_stripTrailingSlash(apiBaseUrl)}/api/mobile/v1';

  static String webUrl(String path) =>
      '${_stripTrailingSlash(webBaseUrl)}${path.startsWith('/') ? path : '/$path'}';

  /// Publicly reachable account-deletion documentation, which Google Play
  /// requires in addition to the in-app path (PLAN.md §8).
  static String get accountDeletionUrl => webUrl('/legal/privacy#deleting-your-account');

  static String get privacyPolicyUrl => webUrl('/legal/privacy');

  static String get termsUrl => webUrl('/legal/terms');

  static String get supportUrl => webUrl('/contact');

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
