import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/passphrase_fields.dart';

void main() {
  test('a sealing pair submits only when long enough and matching', () {
    expect(
      passphraseSubmittable(confirm: true, passphrase: 'longenough', repeat: 'longenough'),
      isTrue,
    );
    expect(passphraseSubmittable(confirm: true, passphrase: 'short', repeat: 'short'), isFalse);
    expect(
      passphraseSubmittable(confirm: true, passphrase: 'longenough', repeat: 'different'),
      isFalse,
    );
    expect(passphraseSubmittable(confirm: true, passphrase: 'longenough'), isFalse);
  });

  test(
    'an unlock submits any passphrase that is not empty, since only decrypting can judge it',
    () {
      expect(passphraseSubmittable(confirm: false, passphrase: 'x'), isTrue);
      expect(passphraseSubmittable(confirm: false, passphrase: ''), isFalse);
    },
  );

  test('a failed unlock is told until the user edits the text that failed', () {
    expect(unlockErrorShown(attempt: 0, editedAttempt: null), isFalse);
    expect(unlockErrorShown(attempt: 1, editedAttempt: null), isTrue);
    expect(unlockErrorShown(attempt: 1, editedAttempt: 1), isFalse);
    expect(unlockErrorShown(attempt: 2, editedAttempt: 1), isTrue);
  });
}
