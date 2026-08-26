import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/export/share_export.dart';

/// Pins the channel contract with ShareExport.swift: payload shapes, cancel
/// answers, error-code mapping.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('opentranscribe/share_export');

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
  });

  test('shareFiles sends the paths and answers completion', () async {
    late MethodCall seen;
    messenger.setMockMethodCallHandler(methods, (call) async {
      seen = call;
      return {'completed': true};
    });
    expect(await ShareExport().shareFiles(['/tmp/a.md', '/tmp/b.zip']), isTrue);
    expect(seen.method, 'shareFiles');
    expect(seen.arguments, {
      'paths': ['/tmp/a.md', '/tmp/b.zip'],
    });
  });

  test('a dismissed share sheet answers false, not an error', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => {'completed': false});
    expect(await ShareExport().shareFiles(['/tmp/a.md']), isFalse);
  });

  test('pickArchive answers the picked path', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'pickArchive');
      return {'path': '/tmp/inbox/journal.otarchive'};
    });
    expect(await ShareExport().pickArchive(), '/tmp/inbox/journal.otarchive');
  });

  test('a cancelled picker answers null, not an error', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => {'path': null});
    expect(await ShareExport().pickArchive(), isNull);
  });

  test('a platform error surfaces with its code preserved', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'busy', message: 'a picker is already open');
    });
    await expectLater(
      ShareExport().pickArchive(),
      throwsA(isA<ShareExportException>().having((e) => e.code, 'code', ShareExportException.busy)),
    );
  });

  test('a null reply resolves to the conservative answers', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => null);
    expect(await ShareExport().shareFiles(['/tmp/a.md']), isFalse);
    expect(await ShareExport().pickArchive(), isNull);
  });

  test('a busy share sheet surfaces with its code preserved', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'busy', message: 'a share or pick is already presenting');
    });
    await expectLater(
      ShareExport().shareFiles(['/tmp/a.md']),
      throwsA(isA<ShareExportException>().having((e) => e.code, 'code', ShareExportException.busy)),
    );
  });

  test('an empty path list is refused before the channel', () async {
    var called = false;
    messenger.setMockMethodCallHandler(methods, (call) async {
      called = true;
      return {'completed': true};
    });
    expect(() => ShareExport().shareFiles([]), throwsArgumentError);
    expect(called, isFalse);
  });

  test('a missing plugin surfaces as the domain exception', () async {
    await expectLater(
      ShareExport().shareFiles(['/tmp/a.md']),
      throwsA(isA<ShareExportException>()),
    );
  });
}
