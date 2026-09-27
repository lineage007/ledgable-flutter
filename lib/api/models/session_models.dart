import 'page.dart';

/// What a role may do, from the same map the server enforces with. UI that the
/// API would refuse is hidden rather than shown and then 403'd after the tap.
enum Permission {
  read,
  write,
  destructive;

  static Permission? parse(Object? raw) => switch (asString(raw)?.toUpperCase()) {
    'READ' => Permission.read,
    'WRITE' => Permission.write,
    'DESTRUCTIVE' => Permission.destructive,
    _ => null,
  };
}

class User {
  const User({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: asStringOr(json['id'], ''),
    email: asStringOr(json['email'], ''),
    name: asStringOr(json['name'], ''),
  );

  /// Initials for the avatar. "Gary Cakir" → "GC", a single name → its first
  /// letter, an empty name → the first letter of the email.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class WorkspaceRef {
  const WorkspaceRef({
    required this.id,
    required this.name,
    required this.role,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String role;
  final bool isDefault;

  factory WorkspaceRef.fromJson(Map<String, dynamic> json) => WorkspaceRef(
    id: asStringOr(json['id'], ''),
    name: asStringOr(json['name'], 'Workspace'),
    role: asStringOr(json['role'], ''),
    isDefault: asBool(json['isDefault']),
  );
}

class ActiveWorkspace {
  const ActiveWorkspace({
    required this.id,
    required this.name,
    this.slug,
    required this.kind,
    required this.status,
    required this.ownerUserId,
  });

  final String id;
  final String name;
  final String? slug;
  final String kind;
  final String status;
  final String ownerUserId;

  factory ActiveWorkspace.fromJson(Map<String, dynamic> json) => ActiveWorkspace(
    id: asStringOr(json['id'], ''),
    name: asStringOr(json['name'], 'Workspace'),
    slug: asString(json['slug']),
    kind: asStringOr(json['kind'], ''),
    status: asStringOr(json['status'], ''),
    ownerUserId: asStringOr(json['ownerUserId'], ''),
  );
}

class Membership {
  const Membership({required this.id, required this.role, required this.isDefault});

  final String id;
  final String role;
  final bool isDefault;

  factory Membership.fromJson(Map<String, dynamic>? json) => Membership(
    id: asStringOr(json?['id'], ''),
    role: asStringOr(json?['role'], ''),
    isDefault: asBool(json?['isDefault']),
  );
}

class DeviceContext {
  const DeviceContext({this.id, this.installId, this.platform});

  final String? id;
  final String? installId;
  final String? platform;

  factory DeviceContext.fromJson(Map<String, dynamic>? json) => DeviceContext(
    id: asString(json?['id']),
    installId: asString(json?['installId']),
    platform: asString(json?['platform']),
  );
}

/// `GET /me` — the bootstrap call after login and after a cold start.
class Me {
  const Me({
    required this.user,
    required this.device,
    required this.workspace,
    required this.membership,
    required this.workspaces,
    required this.permissions,
  });

  final User user;
  final DeviceContext device;
  final ActiveWorkspace workspace;
  final Membership membership;
  final List<WorkspaceRef> workspaces;
  final Set<Permission> permissions;

  bool get canWrite => permissions.contains(Permission.write);

  bool get canDestroy => permissions.contains(Permission.destructive);

  /// The workspace switcher is only worth showing when there is somewhere to
  /// switch to.
  bool get hasMultipleWorkspaces => workspaces.length > 1;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    user: User.fromJson(asMap(json['user']) ?? const {}),
    device: DeviceContext.fromJson(asMap(json['device'])),
    workspace: ActiveWorkspace.fromJson(asMap(json['workspace']) ?? const {}),
    membership: Membership.fromJson(asMap(json['membership'])),
    workspaces: asMapList(json['workspaces']).map(WorkspaceRef.fromJson).toList(growable: false),
    permissions: asStringList(
      json['permissions'],
    ).map(Permission.parse).whereType<Permission>().toSet(),
  );
}

/// A signed-in handset, for Settings → Devices.
class Device {
  const Device({
    required this.id,
    required this.platform,
    this.deviceName,
    this.appVersion,
    this.osVersion,
    required this.lastSeenAt,
    required this.createdAt,
    this.revokedAt,
    required this.pushEnabled,
    required this.current,
  });

  final String id;
  final String platform;
  final String? deviceName;
  final String? appVersion;
  final String? osVersion;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? revokedAt;

  /// Whether a push token is registered. The token itself is never returned —
  /// a push token is a sending capability, not an attribute.
  final bool pushEnabled;

  /// True for the handset making the request.
  final bool current;

  bool get isRevoked => revokedAt != null;

  String get displayName => deviceName ?? (platform == 'IOS' ? 'iPhone' : 'Android device');

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: asStringOr(json['id'], ''),
    platform: asStringOr(json['platform'], 'IOS'),
    deviceName: asString(json['deviceName']),
    appVersion: asString(json['appVersion']),
    osVersion: asString(json['osVersion']),
    lastSeenAt: DateTime.tryParse('${json['lastSeenAt']}')?.toLocal(),
    createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal(),
    revokedAt: DateTime.tryParse('${json['revokedAt']}')?.toLocal(),
    pushEnabled: asBool(json['pushEnabled']),
    current: asBool(json['current']),
  );
}

/// The device descriptor sent with `POST /auth/login`.
class DeviceDescriptor {
  const DeviceDescriptor({
    required this.installId,
    required this.platform,
    this.deviceName,
    this.appVersion,
    this.osVersion,
    this.pushToken,
  });

  final String installId;

  /// `IOS` or `ANDROID`.
  final String platform;
  final String? deviceName;
  final String? appVersion;
  final String? osVersion;
  final String? pushToken;

  Map<String, dynamic> toJson() => {
    'installId': installId,
    'platform': platform,
    if (deviceName != null) 'deviceName': _cap(deviceName!, 120),
    if (appVersion != null) 'appVersion': _cap(appVersion!, 40),
    if (osVersion != null) 'osVersion': _cap(osVersion!, 40),
    // Omitted rather than sent as null when the user declined
    // notifications: omitting never clears a previously registered token.
    if (pushToken != null) 'pushToken': _cap(pushToken!, 512),
  };

  static String _cap(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
