import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/model_fetcher.dart';

/// A loopback server standing in for the model host: the one way to prove
/// resume, redirect pinning, and whole-file-or-nothing against real sockets.
class _ModelServer {
  _ModelServer(this.body);

  final Uint8List body;
  late HttpServer _server;
  bool supportsRange = true;
  bool corrupt = false;
  int? truncateAfter;
  int? stallAfter;
  int? dropAfter;
  int? dropCount;
  List<int?>? dropScript;
  int? contentLength;
  final Completer<void> release = Completer<void>();
  final Completer<void> stalled = Completer<void>();
  String? redirectTo;
  final List<String?> rangeHeaders = [];
  int requests = 0;

  Uri get uri => Uri.parse('http://127.0.0.1:${_server.port}/model.bin');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    requests++;
    rangeHeaders.add(request.headers.value(HttpHeaders.rangeHeader));
    final response = request.response;
    final redirect = redirectTo;
    if (redirect != null) {
      redirectTo = null;
      response.statusCode = HttpStatus.found;
      response.headers.set(HttpHeaders.locationHeader, redirect);
      await response.close();
      return;
    }
    var from = 0;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null && supportsRange) {
      from = int.parse(range.substring('bytes='.length, range.length - 1));
      if (from >= body.length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await response.close();
        return;
      }
      response.statusCode = HttpStatus.partialContent;
    }
    var bytes = body.sublist(from);
    if (corrupt) bytes = Uint8List.fromList([...bytes.sublist(0, bytes.length - 1), 0]);
    if (truncateAfter case final n?) bytes = bytes.sublist(0, min(n, bytes.length));
    response.contentLength = contentLength ?? bytes.length;
    final scripted = dropScript?.elementAtOrNull(requests - 1);
    if (scripted != null) {
      await drop(response, bytes, after: scripted);
      return;
    }
    if (dropAfter case final n? when dropCount != 0) {
      if (dropCount case final left?) dropCount = left - 1;
      await drop(response, bytes, after: n);
      return;
    }
    if (stallAfter case final n?) {
      response.add(bytes.sublist(0, n));
      await response.flush();
      stalled.complete();
      await release.future;
      bytes = bytes.sublist(n);
    }
    response.add(bytes);
    try {
      await response.close();
    } on SocketException {
      // The client hung up mid-body, which is the point of the cancel test.
    }
  }

  Future<void> drop(HttpResponse response, Uint8List bytes, {required int after}) async {
    final socket = await response.detachSocket();
    socket.add(bytes.sublist(0, after));
    await socket.flush();
    socket.destroy();
  }
}

void main() {
  final body = Uint8List.fromList(List.generate(200000, (i) => (i * 7 + 3) & 0xff));
  final bodySha = sha256.convert(body).toString();
  late _ModelServer server;
  late Directory dir;
  late File into;

  setUp(() async {
    server = _ModelServer(body);
    await server.start();
    dir = await Directory.systemTemp.createTemp('otr-fetch-');
    into = File('${dir.path}/models/model.bin');
  });
  tearDown(() async {
    await server.stop();
    await dir.delete(recursive: true);
  });

  PinnedHostFetcher fetcher({List<Duration> retryBackoff = const []}) =>
      PinnedHostFetcher(allowedHostSuffixes: const ['127.0.0.1'], retryBackoff: retryBackoff);

  const quickRetries = [Duration(milliseconds: 5), Duration(milliseconds: 5)];

  Stream<double> fetch(PinnedHostFetcher f, {Uri? source, String? sha}) => f.fetch(
    source ?? server.uri,
    into: into,
    expectedBytes: body.length,
    expectedSha256: sha ?? bodySha,
  );

  test('a whole download lands the verified file and ends at one', () async {
    final fractions = await fetch(fetcher()).toList();

    expect(fractions.last, 1);
    expect(fractions, orderedEquals([...fractions]..sort()));
    expect(await into.readAsBytes(), body);
    expect(File('${into.path}.part').existsSync(), isFalse);
  });

  test('a part left behind resumes with a range request and hashes the whole', () async {
    await into.parent.create(recursive: true);
    await File('${into.path}.part').writeAsBytes(body.sublist(0, 50000));

    await fetch(fetcher()).drain<void>();

    expect(server.rangeHeaders, ['bytes=50000-']);
    expect(await into.readAsBytes(), body);
  });

  test('a server ignoring the range restarts the part from zero', () async {
    server.supportsRange = false;
    await into.parent.create(recursive: true);
    await File('${into.path}.part').writeAsBytes([1, 2, 3]);

    await fetch(fetcher()).drain<void>();

    expect(await into.readAsBytes(), body);
  });

  test('a part longer than the file is thrown away before asking', () async {
    await into.parent.create(recursive: true);
    await File('${into.path}.part').writeAsBytes(Uint8List(body.length + 5));

    await fetch(fetcher()).drain<void>();

    expect(server.rangeHeaders, [null]);
    expect(await into.readAsBytes(), body);
  });

  test('a redirect onto a pinned host is followed', () async {
    server.redirectTo = server.uri.replace(path: '/elsewhere/model.bin').toString();

    await fetch(fetcher()).drain<void>();

    expect(server.requests, 2);
    expect(await into.readAsBytes(), body);
  });

  test('a redirect off the pinned hosts is refused before connecting', () async {
    server.redirectTo = 'https://example.com/model.bin';

    await expectLater(
      fetch(fetcher()).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.rejected),
      ),
    );
    expect(server.requests, 1);
    expect(into.existsSync(), isFalse);
  });

  test('a source off the pinned hosts is refused', () async {
    await expectLater(
      fetch(fetcher(), source: Uri.parse('https://example.com/model.bin')).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.rejected),
      ),
    );
    expect(server.requests, 0);
  });

  test('a plain http source that is not loopback is refused', () async {
    final f = PinnedHostFetcher(allowedHostSuffixes: const ['example.com']);

    await expectLater(
      fetch(f, source: Uri.parse('http://example.com/model.bin')).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.rejected),
      ),
    );
  });

  test('a corrupt body is rejected and leaves no file and no part', () async {
    server.corrupt = true;

    await expectLater(
      fetch(fetcher()).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.rejected),
      ),
    );
    expect(into.existsSync(), isFalse);
    expect(File('${into.path}.part').existsSync(), isFalse);
  });

  test('a socket dropped mid-body reads as offline and keeps the part', () async {
    server.dropAfter = 65536;

    await expectLater(
      fetch(fetcher()).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.offline),
      ),
    );
    expect(into.existsSync(), isFalse);
    expect(server.requests, 1);
    expect(File('${into.path}.part').lengthSync(), inInclusiveRange(1, 65536));
  });

  test('a drop mid-body is retried from the part and lands one verified file', () async {
    server.dropAfter = 65536;
    server.dropCount = 1;

    final fractions = await fetch(fetcher(retryBackoff: quickRetries)).toList();

    expect(fractions.last, 1);
    expect(fractions, orderedEquals([...fractions]..sort()));
    expect(server.requests, 2);
    expect(server.rangeHeaders.last, startsWith('bytes='));
    expect(await into.readAsBytes(), body);
    expect(File('${into.path}.part').existsSync(), isFalse);
  });

  test('a break after bytes costs nothing, so a file that keeps dropping still lands', () async {
    server.dropAfter = 32768;
    server.dropCount = 5;

    final fractions = await fetch(fetcher(retryBackoff: quickRetries)).toList();

    expect(fractions.last, 1);
    expect(server.requests, 6);
    expect(await into.readAsBytes(), body);
    expect(File('${into.path}.part').existsSync(), isFalse);
  });

  test('a break that delivers bytes starts the count of empty breaks over', () async {
    server.dropScript = [65536, 0, 30000, 0, 0, 0];
    const three = [Duration(milliseconds: 5), Duration(milliseconds: 5), Duration(milliseconds: 5)];

    await expectLater(
      fetch(fetcher(retryBackoff: three)).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.offline),
      ),
    );
    expect(server.requests, 6);
    expect(File('${into.path}.part').lengthSync(), inInclusiveRange(65537, 95536));
  });

  test('each empty break in a row waits the next backoff before its retry', () async {
    server.dropScript = [65536, 0, 0, 0];
    const waits = [
      Duration(milliseconds: 1),
      Duration(milliseconds: 1),
      Duration(milliseconds: 250),
    ];
    final clock = Stopwatch()..start();

    await expectLater(
      fetch(fetcher(retryBackoff: waits)).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.offline),
      ),
    );
    expect(server.requests, 4);
    expect(clock.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 250)));
  });

  test('a host answering a resume whole counts only bytes past the part as progress', () async {
    server.supportsRange = false;
    server.dropScript = [65536, 30000, 30000, 30000];

    await expectLater(
      fetch(fetcher(retryBackoff: quickRetries)).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.offline),
      ),
    );
    expect(server.requests, 3);
  });

  test('a drop before the first byte is not retried', () async {
    server.dropAfter = 0;

    await expectLater(
      fetch(fetcher(retryBackoff: quickRetries)).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.offline),
      ),
    );
    expect(server.requests, 1);
  });

  test('a retry the host answers whole still lands the verified file', () async {
    server.dropAfter = 65536;
    server.dropCount = 1;
    server.supportsRange = false;

    await fetch(fetcher(retryBackoff: quickRetries)).drain<void>();

    expect(server.requests, 2);
    expect(server.rangeHeaders.last, startsWith('bytes='));
    expect(await into.readAsBytes(), body);
    expect(File('${into.path}.part').existsSync(), isFalse);
  });

  test('a resumed part whose host cannot be reached fails at once', () async {
    await into.parent.create(recursive: true);
    await File('${into.path}.part').writeAsBytes(body.sublist(0, 50000));
    final gone = server.uri.replace(port: 1);

    await expectLater(
      fetch(fetcher(retryBackoff: quickRetries), source: gone).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.offline),
      ),
    );
    expect(server.requests, 0);
    expect(File('${into.path}.part').lengthSync(), 50000);
  });

  test('a cancel during the backoff ends the download without another request', () async {
    server.dropAfter = 65536;
    server.dropCount = 1;
    final sub = fetch(
      fetcher(retryBackoff: const [Duration(milliseconds: 200)]),
    ).listen(null, onError: (Object _) {});
    while (server.requests < 1) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(server.requests, 1);
    expect(File('${into.path}.part').existsSync(), isTrue);
  });

  test('a host declaring a length other than the catalog is rejected', () async {
    server.truncateAfter = 80000;

    await expectLater(
      fetch(fetcher()).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.rejected),
      ),
    );
    expect(into.existsSync(), isFalse);
    expect(File('${into.path}.part').existsSync(), isFalse);
  });

  test('a host that refuses the connection reads as offline', () async {
    await expectLater(
      fetch(fetcher(), source: server.uri.replace(port: 1)).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.offline),
      ),
    );
  });

  test('a cancel before the connection opened downloads nothing', () async {
    final sub = fetch(fetcher()).listen(null);
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(server.requests, 0);
    expect(into.existsSync(), isFalse);
  });

  test('a whole part left behind is verified and moved without a request', () async {
    await into.parent.create(recursive: true);
    await File('${into.path}.part').writeAsBytes(body);

    final fractions = await fetch(fetcher()).toList();

    expect(fractions, [1]);
    expect(server.requests, 0);
    expect(await into.readAsBytes(), body);
  });

  test('a cancel mid-download keeps the part for the next attempt', () async {
    server.stallAfter = 65536;
    final firstBytes = Completer<void>();
    final sub = fetch(fetcher()).listen((_) {
      if (!firstBytes.isCompleted) firstBytes.complete();
    });
    await firstBytes.future;
    await sub.cancel();
    server.release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(into.existsSync(), isFalse);
    final part = File('${into.path}.part');
    expect(part.lengthSync(), inInclusiveRange(1, 65536));
  });

  test('a wrong expected hash rejects a good body', () async {
    await expectLater(
      fetch(fetcher(), sha: 'f' * 64).drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.rejected),
      ),
    );
    expect(into.existsSync(), isFalse);
  });

  test('a non-positive expected size is refused before anything runs', () {
    expect(
      () => fetcher().fetch(server.uri, into: into, expectedBytes: 0, expectedSha256: bodySha),
      throwsArgumentError,
    );
  });
}
