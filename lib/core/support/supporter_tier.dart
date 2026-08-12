/// How the user supports the app, if at all. Features only ever ask
/// [isSupporter]; which product paid matters to nothing but the support
/// screen's own copy.
enum SupporterTier {
  none,
  monthly,
  lifetime;

  bool get isSupporter => this != none;

  /// Reads a stored or channel value. Fail-closed: anything unknown,
  /// including null, is [none], so a bad read can lock but never grant.
  static SupporterTier parse(String? raw) => switch (raw) {
    'monthly' => monthly,
    'lifetime' => lifetime,
    _ => none,
  };
}
