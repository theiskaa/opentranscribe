/// Whether the user supports the app. One product today (the lifetime
/// unlock), so this is a two-state answer; features only ever ask
/// [isSupporter], and a new tier lands as one more value here.
enum SupporterTier {
  none,
  lifetime;

  bool get isSupporter => this != none;

  /// Reads a stored or channel value. Fail-closed: anything unknown,
  /// including null, is [none], so a bad read can lock but never grant.
  static SupporterTier parse(String? raw) => switch (raw) {
    'lifetime' => lifetime,
    _ => none,
  };
}
