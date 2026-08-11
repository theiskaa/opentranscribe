import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/widgets/passphrase_rules.dart';

void main() {
  group('passphraseIssue', () {
    test('accepts a matching pair at the minimum length', () {
      expect(passphraseIssue('12345678', '12345678'), isNull);
    });

    test('refuses a short passphrase before judging the match', () {
      expect(passphraseIssue('1234567', 'different'), PassphraseIssue.tooShort);
    });

    test('refuses a mismatched confirmation', () {
      expect(passphraseIssue('12345678', '12345679'), PassphraseIssue.mismatch);
    });

    test('an empty confirmation reads as mismatch, keeping the gate shut', () {
      expect(passphraseIssue('12345678', ''), PassphraseIssue.mismatch);
    });

    test('judges a lone passphrase without a confirmation', () {
      expect(passphraseIssue('12345678'), isNull);
      expect(passphraseIssue('short'), PassphraseIssue.tooShort);
    });
  });

  group('passphraseNotice', () {
    test('stays silent before anything is typed', () {
      expect(passphraseNotice('', ''), isNull);
      expect(passphraseNotice('', 'x'), isNull);
    });

    test('shows too short while the first field is under the floor', () {
      expect(passphraseNotice('123', ''), PassphraseIssue.tooShort);
    });

    test('too short outranks mismatch while both fields hold text', () {
      expect(passphraseNotice('1234', 'xyz'), PassphraseIssue.tooShort);
    });

    test('shows mismatch only once the second field has content', () {
      expect(passphraseNotice('12345678', ''), isNull);
      expect(passphraseNotice('12345678', '1234'), PassphraseIssue.mismatch);
      expect(passphraseNotice('12345678', '12345678'), isNull);
    });
  });
}
