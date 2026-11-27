/// Where the user stands with Belly Buddy Plus, from the store's `plus`
/// entitlement.
enum PlusState {
  /// Never had Plus.
  none,

  /// In the store's free trial.
  trial,

  /// Paying subscriber.
  active,

  /// Had Plus, it ran out.
  lapsed,
}

class PlusStatus {
  const PlusStatus({
    required this.state,
    this.expiresAt,
    this.willRenew = false,
    this.billingIssue = false,
    this.managementUrl,
  });

  static const none = PlusStatus(state: PlusState.none);

  final PlusState state;

  /// End of the current (or last) period, UTC; null without an end date.
  final DateTime? expiresAt;

  /// The subscription renews at [expiresAt] unless cancelled.
  final bool willRenew;

  /// The store reported a payment problem.
  final bool billingIssue;

  /// Store page where the user manages the subscription, if the SDK has one.
  final String? managementUrl;

  /// Plus features are unlocked.
  bool get granted => state == PlusState.trial || state == PlusState.active;

  @override
  bool operator ==(Object other) =>
      other is PlusStatus &&
      other.state == state &&
      other.expiresAt == expiresAt &&
      other.willRenew == willRenew &&
      other.billingIssue == billingIssue &&
      other.managementUrl == managementUrl;

  @override
  int get hashCode =>
      Object.hash(state, expiresAt, willRenew, billingIssue, managementUrl);

  @override
  String toString() => 'PlusStatus(${state.name})';
}
