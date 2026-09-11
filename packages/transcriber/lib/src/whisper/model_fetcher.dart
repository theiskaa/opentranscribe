import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:transcriber/src/transcribe/transcription_exception.dart';

/// Where a fetcher keeps an unfinished download, beside its destination.
const modelPartSuffix = '.part';

/// The errno a write answers with when the disk is full.
const enospc = 28;

/// Downloads one model file. The only contract in the package that reaches
/// the network; [PinnedHostFetcher] is the only code that does.
///
/// Guarantees a caller may rely on: [into] exists only once the whole file
/// arrived and its sha256 matched [expectedSha256], so a file that exists is
/// always a whole, verified one; progress arrives as fractions of
/// [expectedBytes] and the stream completes when the file is in place; a
/// failure is a [ModelInstallFailed] carrying its [ModelInstallReason]; a
/// cancel (unsubscribing) closes the connection and keeps what arrived, so
/// the next fetch of the same file resumes.
abstract interface class ModelFetcher {
  Stream<double> fetch(
    Uri source, {
    required File into,
    required int expectedBytes,
    required String expectedSha256,
  });
}

/// The [ModelFetcher] over dart:io, pinned to a host list: the source and
/// every redirect must be https on a host in [allowedHostSuffixes] (a loopback
/// address may be plain http, for tests). Resumes a `.part` with a Range
/// request, hashes while writing, and moves the verified part into place last.
/// A transfer that breaks after bytes arrived (a reset, a stall, the socket
/// iOS closed while the app was away) is reopened from the part; only breaks
/// in a row that delivered nothing count towards offline, so a long file on a
/// link that keeps dropping still lands. One that never delivered a byte
/// fails at once.
class PinnedHostFetcher implements ModelFetcher {
  PinnedHostFetcher({
    required List<String> allowedHostSuffixes,
    HttpClient Function()? newClient,
    List<Duration> retryBackoff = _defaultBackoff,
  }) : _suffixes = List.unmodifiable(allowedHostSuffixes),
       _newClient = newClient ?? HttpClient.new,
       _backoff = List.unmodifiable(retryBackoff);

  final List<String> _suffixes;
  final HttpClient Function() _newClient;

  /// The wait before retrying a transfer that broke after bytes arrived,
  /// indexed by how many breaks in a row delivered nothing; as many empty
  /// breaks in a row as there are waits count as offline.
  final List<Duration> _backoff;

  static const _maxRedirects = 5;
  static const _progressStep = 0.005;
  static const _stall = Duration(seconds: 60);
  static const _defaultBackoff = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];

  bool _allowed(Uri uri) {
    final loopback = InternetAddress.tryParse(uri.host)?.isLoopback ?? false;
    if (uri.scheme != 'https' && !loopback) return false;
    return _suffixes.any((s) => uri.host == s || uri.host.endsWith('.$s'));
  }

  @override
  Stream<double> fetch(
    Uri source, {
    required File into,
    required int expectedBytes,
    required String expectedSha256,
  }) {
    if (expectedBytes <= 0) throw ArgumentError.value(expectedBytes, 'expectedBytes');
    late final StreamController<double> controller;
    HttpClient? client;
    controller = StreamController<double>(
      onListen: () {
        final opened = client = _newClient();
        unawaited(
          _run(
            source,
            into: into,
            expectedBytes: expectedBytes,
            expectedSha256: expectedSha256.toLowerCase(),
            client: opened,
            progress: controller,
          ).then(
            (_) {
              if (controller.hasListener) unawaited(controller.close());
            },
            onError: (Object error, StackTrace stack) {
              if (!controller.hasListener) return;
              controller.addError(_failure(error), stack);
              unawaited(controller.close());
            },
          ),
        );
      },
      onCancel: () => client?.close(force: true),
    );
    return controller.stream;
  }

  Future<void> _run(
    Uri source, {
    required File into,
    required int expectedBytes,
    required String expectedSha256,
    required HttpClient client,
    required StreamController<double> progress,
  }) async {
    if (!_allowed(source)) throw _rejected('host not pinned: ${source.host}');
    final part = File('${into.path}$modelPartSuffix');
    var received = 0;
    try {
      await into.parent.create(recursive: true);
      var offset = await part.exists() ? await part.length() : 0;
      if (offset > expectedBytes) {
        await part.delete();
        offset = 0;
      }
      late Digest digest;
      ByteConversionSink hashing() => sha256.startChunkedConversion(
        ChunkedConversionSink<Digest>.withCallback((d) => digest = d.single),
      );
      Future<void> hashPrefix(ByteConversionSink sink) async {
        await for (final chunk in part.openRead()) {
          sink.add(chunk);
        }
      }

      // A cancel landed after the last byte: only the hash is left to check.
      if (offset == expectedBytes) {
        final whole = hashing();
        await hashPrefix(whole);
        whole.close();
        if (digest.toString() == expectedSha256) {
          await part.rename(into.path);
          if (progress.hasListener) progress.add(1);
          return;
        }
        await part.delete();
        offset = 0;
      }
      if (!progress.hasListener) return;

      // One running hash across attempts: over the part's prefix once resumed,
      // then every chunk as it lands.
      ByteConversionSink? digesting;
      var lastEmitted = -1.0;
      var gotBytes = false;

      Future<void> attempt() async {
        final response = await _open(client, source, offset);
        final resumed = response.statusCode == HttpStatus.partialContent && offset > 0;
        if (response.statusCode != HttpStatus.ok && !resumed) {
          await response.drain<void>();
          throw _rejected('http ${response.statusCode}');
        }
        if (!resumed) {
          offset = 0;
          digesting = null;
          lastEmitted = -1.0;
        }
        final length = response.contentLength;
        if (length != -1 && length != expectedBytes - offset) {
          await response.drain<void>();
          if (await part.exists()) await part.delete();
          throw _rejected('the host serves $length bytes, not the catalog\'s');
        }
        if (!progress.hasListener) {
          await response.drain<void>();
          return;
        }
        final fresh = digesting == null;
        final sink = digesting ??= hashing();
        if (resumed && fresh) await hashPrefix(sink);
        received = offset;
        final raf = await part.open(mode: resumed ? FileMode.append : FileMode.write);
        try {
          await for (final chunk in response.timeout(_stall)) {
            if (!progress.hasListener) return;
            received += chunk.length;
            if (received > expectedBytes) throw _rejected('longer than expected');
            sink.add(chunk);
            await raf.writeFrom(chunk);
            gotBytes = true;
            final fraction = received / expectedBytes;
            if (fraction - lastEmitted >= _progressStep) {
              lastEmitted = fraction;
              progress.add(fraction);
            }
          }
        } finally {
          await raf.close();
        }
        if (progress.hasListener && received < expectedBytes) {
          throw _offline('connection closed early');
        }
      }

      // The part's high-water mark: a host answering a resume whole starts
      // received over, and only new bytes count as progress.
      var furthest = offset;
      var emptyBreaks = 0;
      while (true) {
        try {
          await attempt();
          break;
        } catch (e) {
          final failure = _failure(e);
          // A break after the last byte leaves the hash to decide.
          if (failure.reason != ModelInstallReason.offline) throw failure;
          if (received == expectedBytes) break;
          if (!gotBytes) throw failure;
          final grew = received > furthest;
          if (grew) furthest = received;
          emptyBreaks = grew ? 0 : emptyBreaks + 1;
          if (emptyBreaks >= _backoff.length) throw failure;
          if (!progress.hasListener) return;
          offset = received;
          await Future<void>.delayed(_backoff[emptyBreaks]);
          if (!progress.hasListener) return;
        }
      }
      if (!progress.hasListener) return;
      digesting!.close();
      if (digest.toString() != expectedSha256) {
        await part.delete();
        throw _rejected('sha256 mismatch');
      }
      await part.rename(into.path);
      if (progress.hasListener) progress.add(1);
    } on ModelInstallFailed {
      // An over-long part can never resume.
      if (received > expectedBytes && await part.exists()) await part.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClientResponse> _open(HttpClient client, Uri source, int offset) async {
    var current = source;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      if (!_allowed(current)) throw _rejected('redirect outside the pinned hosts');
      final request = await client.getUrl(current);
      request.followRedirects = false;
      if (offset > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      final response = await request.close();
      if (!response.isRedirect) return response;
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null) throw _rejected('redirect without a location');
      current = current.resolve(location);
    }
    throw _rejected('too many redirects');
  }

  static ModelInstallFailed _failure(Object error) => switch (error) {
    ModelInstallFailed() => error,
    SocketException() ||
    HandshakeException() ||
    TlsException() ||
    HttpException() ||
    TimeoutException() => _offline('$error'),
    FileSystemException(osError: final os) when os?.errorCode == enospc => ModelInstallFailed(
      '$error',
      null,
      ModelInstallReason.noSpace,
    ),
    _ => _rejected('$error'),
  };

  static ModelInstallFailed _offline(String message) =>
      ModelInstallFailed(message, null, ModelInstallReason.offline);

  static ModelInstallFailed _rejected(String message) =>
      ModelInstallFailed(message, null, ModelInstallReason.rejected);
}
