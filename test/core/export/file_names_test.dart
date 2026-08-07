import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/export/file_names.dart';

void main() {
  group('sanitizeFileName', () {
    test('strips path separators and reserved characters', () {
      expect(sanitizeFileName(r'a/b\c:d*e?f"g<h>i|j'), 'abcdefghij');
    });

    test('collapses runs of whitespace into single spaces', () {
      expect(sanitizeFileName('morning   walk\n\tnotes'), 'morning walk notes');
    });

    test('strips control characters', () {
      expect(sanitizeFileName('a\x00b\x1fc'), 'abc');
    });

    test('trims leading and trailing dots', () {
      expect(sanitizeFileName('...hidden name..'), 'hidden name');
    });

    test('falls back when nothing legible survives', () {
      expect(sanitizeFileName('///???'), 'untitled');
      expect(sanitizeFileName(''), 'untitled');
      expect(sanitizeFileName('...', fallback: 'entry'), 'entry');
    });

    test('caps length without splitting a surrogate pair', () {
      final long = '🙂' * 100;
      final capped = sanitizeFileName(long, maxLength: 10);
      expect(capped, '🙂' * 10);
    });

    test('capping never leaves a trailing dot or space', () {
      expect(sanitizeFileName('hello. world', maxLength: 6), 'hello');
      expect(sanitizeFileName('hello world', maxLength: 6), 'hello');
    });

    test('a reserved-character fallback still sanitizes at the call site pattern', () {
      expect(
        sanitizeFileName('', fallback: sanitizeFileName('Sans titre : note')),
        'Sans titre  note',
      );
    });

    test('defuses windows device names', () {
      expect(sanitizeFileName('nul'), 'nul-');
      expect(sanitizeFileName('CON.md'), 'CON-.md');
      expect(sanitizeFileName('com1'), 'com1-');
      expect(sanitizeFileName('console'), 'console');
      expect(sanitizeFileName('nullable.md'), 'nullable.md');
    });

    test('keeps unicode titles intact', () {
      expect(sanitizeFileName('走った日 のメモ'), '走った日 のメモ');
    });
  });

  group('uniqueFileName', () {
    test('returns the name untouched when free', () {
      expect(uniqueFileName('walk.md', {'run.md'}), 'walk.md');
    });

    test('numbers collisions before the extension', () {
      expect(uniqueFileName('walk.md', {'walk.md'}), 'walk-2.md');
      expect(uniqueFileName('walk.md', {'walk.md', 'walk-2.md'}), 'walk-3.md');
    });

    test('numbers extensionless names at the end', () {
      expect(uniqueFileName('walk', {'walk'}), 'walk-2');
    });

    test('treats a leading dot as part of the name, not an extension', () {
      expect(uniqueFileName('.config', {'.config'}), '.config-2');
    });
  });
}
