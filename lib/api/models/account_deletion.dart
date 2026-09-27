import 'page.dart';

/// What deleting the account does to one workspace.
enum DeletionOutcome {
  /// Another owner remains; nothing changes.
  untouched,

  /// Ownership passes to the longest-standing remaining member.
  transferred,

  /// Nobody is left and there are financial records, so the books are frozen
  /// read-only for the retention period and then purged.
  retained,

  /// Nobody is left and there is nothing to keep.
  deleted,

  unknown;

  static DeletionOutcome parse(Object? raw) => switch (asString(raw)?.toLowerCase()) {
    'untouched' => DeletionOutcome.untouched,
    'transferred' => DeletionOutcome.transferred,
    'retained' => DeletionOutcome.retained,
    'deleted' => DeletionOutcome.deleted,
    _ => DeletionOutcome.unknown,
  };

  String get label => switch (this) {
    DeletionOutcome.untouched => 'Carries on',
    DeletionOutcome.transferred => 'Handed over',
    DeletionOutcome.retained => 'Frozen, records kept',
    DeletionOutcome.deleted => 'Deleted',
    DeletionOutcome.unknown => 'Unknown',
  };

  /// Whether this outcome loses the person access to a workspace. Drives
  /// emphasis on the consequences screen: the two that do are the ones worth
  /// reading twice.
  bool get isLoss => this == DeletionOutcome.retained || this == DeletionOutcome.deleted;
}

class WorkspaceDeletionOutcome {
  const WorkspaceDeletionOutcome({
    required this.workspaceId,
    required this.name,
    required this.outcome,
    required this.reason,
  });

  final String workspaceId;
  final String name;
  final DeletionOutcome outcome;

  /// Plain-language explanation from the server, safe to show verbatim.
  final String reason;

  factory WorkspaceDeletionOutcome.fromJson(Map<String, dynamic> json) => WorkspaceDeletionOutcome(
    workspaceId: asStringOr(json['workspaceId'], ''),
    name: asStringOr(json['name'], 'Workspace'),
    outcome: DeletionOutcome.parse(json['outcome']),
    reason: asStringOr(json['reason'], ''),
  );
}

class LiveSubscriptionWarning {
  const LiveSubscriptionWarning({
    required this.workspaceId,
    required this.name,
    required this.status,
  });

  final String workspaceId;
  final String name;
  final String status;

  factory LiveSubscriptionWarning.fromJson(Map<String, dynamic> json) => LiveSubscriptionWarning(
    workspaceId: asStringOr(json['workspaceId'], ''),
    name: asStringOr(json['name'], 'Workspace'),
    status: asStringOr(json['status'], ''),
  );
}

/// `GET /account` — the consequences screen, shown before asking to confirm.
class AccountDeletionPreview {
  const AccountDeletionPreview({
    required this.retentionYears,
    required this.activeDeviceCount,
    required this.workspaces,
    required this.liveSubscriptions,
    required this.exportAvailableAt,
    required this.untouched,
    required this.transferred,
    required this.retained,
    required this.deleted,
  });

  /// How long frozen books are kept. Seven years — five is the ATO's floor,
  /// and Ledgable commits to seven.
  final int retentionYears;

  /// Mobile installs that will be signed out.
  final int activeDeviceCount;
  final List<WorkspaceDeletionOutcome> workspaces;

  /// Workspaces still billing that this deletion would freeze or destroy.
  /// Deletion sets each to cancel at period end: nothing renews, and there is
  /// no refund for the remainder of the current period. Must be said before
  /// the person confirms.
  final List<LiveSubscriptionWarning> liveSubscriptions;

  /// Where the data archive can be downloaded. Web-only today, so the app links
  /// out rather than offering an in-app export that cannot work.
  final String exportAvailableAt;

  final int untouched;
  final int transferred;
  final int retained;
  final int deleted;

  bool get hasLosses => retained > 0 || deleted > 0;

  factory AccountDeletionPreview.fromJson(Map<String, dynamic> json) {
    final totals = asMap(json['totals']);
    return AccountDeletionPreview(
      retentionYears: asInt(json['retentionYears']) ?? 7,
      activeDeviceCount: asInt(json['activeDeviceCount']) ?? 0,
      workspaces: asMapList(
        json['workspaces'],
      ).map(WorkspaceDeletionOutcome.fromJson).toList(growable: false),
      liveSubscriptions: asMapList(
        json['workspacesWithLiveSubscription'],
      ).map(LiveSubscriptionWarning.fromJson).toList(growable: false),
      exportAvailableAt: asStringOr(json['exportAvailableAt'], '/settings/backups'),
      untouched: asInt(totals?['untouched']) ?? 0,
      transferred: asInt(totals?['transferred']) ?? 0,
      retained: asInt(totals?['retained']) ?? 0,
      deleted: asInt(totals?['deleted']) ?? 0,
    );
  }
}

class RetainedWorkspace {
  const RetainedWorkspace({required this.id, required this.name, this.retentionUntil});

  final String id;
  final String name;
  final DateTime? retentionUntil;

  factory RetainedWorkspace.fromJson(Map<String, dynamic> json) => RetainedWorkspace(
    id: asStringOr(json['id'], ''),
    name: asStringOr(json['name'], 'Workspace'),
    retentionUntil: DateTime.tryParse('${json['retentionUntil']}')?.toLocal(),
  );
}

/// One subscription that was still billing a workspace this deletion froze.
class BillingCancellation {
  const BillingCancellation({required this.name, required this.result, required this.message});

  final String name;

  /// `cancel_at_period_end`, `not_configured`, `no_stripe_subscription`, or
  /// `failed`.
  final String result;
  final String message;

  /// The one the client MUST surface: the account is gone but a subscription is
  /// still live, and there is no account left for the person to cancel it from.
  bool get isFailure => result == 'failed';

  factory BillingCancellation.fromJson(Map<String, dynamic> json) => BillingCancellation(
    name: asStringOr(json['name'], 'Workspace'),
    result: asStringOr(json['result'], ''),
    message: asStringOr(json['message'], ''),
  );
}

/// `DELETE /account`.
class AccountDeletionResult {
  const AccountDeletionResult({
    required this.reference,
    required this.retainedWorkspaces,
    required this.billingCancellations,
    required this.devicesRevoked,
  });

  /// Support reference, e.g. `LGD-7Q2F4K8M`. Must be shown: after this response
  /// there is no account left to look it up from, and it is what a business
  /// quotes to reclaim frozen books.
  final String reference;
  final List<RetainedWorkspace> retainedWorkspaces;
  final List<BillingCancellation> billingCancellations;
  final int devicesRevoked;

  List<BillingCancellation> get failedCancellations =>
      billingCancellations.where((entry) => entry.isFailure).toList(growable: false);

  factory AccountDeletionResult.fromJson(Map<String, dynamic> json) => AccountDeletionResult(
    reference: asStringOr(json['reference'], ''),
    retainedWorkspaces: asMapList(
      json['retainedWorkspaces'],
    ).map(RetainedWorkspace.fromJson).toList(growable: false),
    billingCancellations: asMapList(
      json['billingCancellations'],
    ).map(BillingCancellation.fromJson).toList(growable: false),
    devicesRevoked: asInt(json['devicesRevoked']) ?? 0,
  );
}
