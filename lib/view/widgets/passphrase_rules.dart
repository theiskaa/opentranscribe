/// What is wrong with a passphrase pair, or null when it is acceptable.
enum PassphraseIssue { tooShort, mismatch }

/// The floor for a NEW archive's passphrase. Unlocking never re-checks it:
/// the only honest gate for an existing archive is whether it decrypts.
const passphraseMinLength = 8;

/// Whether [passphrase] (and, when [repeat] is given, its confirmation) may
/// seal an archive. Order matters: length first, so a short pair never reads
/// as merely mismatched.
PassphraseIssue? passphraseIssue(String passphrase, [String? repeat]) {
  if (passphrase.length < passphraseMinLength) return PassphraseIssue.tooShort;
  if (repeat != null && repeat != passphrase) return PassphraseIssue.mismatch;
  return null;
}

/// The issue worth SHOWING while the user is still typing: nothing until the
/// first field has content, no mismatch until the second field has content.
/// The gate above stays strict; this only decides the footnote.
PassphraseIssue? passphraseNotice(String passphrase, String repeat) {
  if (passphrase.isEmpty) return null;
  if (passphrase.length < passphraseMinLength) return PassphraseIssue.tooShort;
  if (repeat.isNotEmpty && repeat != passphrase) return PassphraseIssue.mismatch;
  return null;
}
