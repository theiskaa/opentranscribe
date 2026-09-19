import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/cache_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/screens/cache_screen.dart';

void main() {
  const usage = AudioUsage(
    totalBytes: 800,
    totalCount: 10,
    reclaimableBytes: 600,
    reclaimableCount: 7,
  );

  group('storageFigures', () {
    test('the kept share is what the transcribed share leaves of the audio', () {
      final figures = storageFigures(usage, modelBytes: 200);
      expect(figures.clearable, 600);
      expect(figures.clearableCount, 7);
      expect(figures.kept, 200);
      expect(figures.keptCount, 3);
      expect(figures.models, 200);
    });

    test('the total counts audio and models together', () {
      expect(storageTotal(storageFigures(usage, modelBytes: 200)), 1000);
    });

    test('a measure whose reclaimable share outran its total never goes negative', () {
      const racing = AudioUsage(
        totalBytes: 100,
        totalCount: 1,
        reclaimableBytes: 150,
        reclaimableCount: 2,
      );
      final figures = storageFigures(racing, modelBytes: 0);
      expect(figures.kept, 0);
      expect(figures.keptCount, 0);
    });
  });

  group('storageShares', () {
    test('each kind takes its share of everything the phone keeps', () {
      final shares = storageShares(storageFigures(usage, modelBytes: 200));
      expect(shares.clearable, 0.6);
      expect(shares.kept, 0.2);
      expect(shares.models, 0.2);
    });

    test('an empty phone draws no share at all rather than dividing by nothing', () {
      const empty = AudioUsage(
        totalBytes: 0,
        totalCount: 0,
        reclaimableBytes: 0,
        reclaimableCount: 0,
      );
      final shares = storageShares(storageFigures(empty, modelBytes: 0));
      expect(shares, (clearable: 0.0, kept: 0.0, models: 0.0));
    });
  });

  test('a clear drawn halfway has drained half its share and counted half its entries down', () {
    final before = storageFigures(usage, modelBytes: 200);
    final after = storageFigures(
      const AudioUsage(totalBytes: 200, totalCount: 3, reclaimableBytes: 0, reclaimableCount: 0),
      modelBytes: 200,
    );
    final mid = lerpStorage(before, after, 0.5);
    expect(mid.clearable, 300);
    expect(mid.clearableCount, 3.5);
    expect(mid.kept, 200);
    expect(storageTotal(mid), 700);
  });

  group('storageBarWidths', () {
    test('the shown kinds share the bar less the gaps between them', () {
      final widths = storageBarWidths([0.5, 0.25, 0.25], width: 104, gap: 2);
      expect(widths, [50, 25, 25]);
    });

    test('a kind under a pixel draws nothing and opens no gap', () {
      final widths = storageBarWidths([0.995, 0.005, 0], width: 100, gap: 2);
      expect(widths[1], 0);
      expect(widths[2], 0);
      expect(widths[0], closeTo(99.5, 1e-9));
    });

    test('an empty bar draws no kind at all', () {
      expect(storageBarWidths([0, 0, 0], width: 100, gap: 2), [0, 0, 0]);
    });
  });

  group('clearFace', () {
    test('something to clear offers the clear', () {
      expect(clearFace(const CacheState(usage: usage)), ClearFace.clear);
    });

    test('a running clear shows it is working, whatever the numbers say', () {
      expect(clearFace(const CacheState(usage: usage, clearing: true)), ClearFace.clearing);
    });

    test('once nothing is left, the last clear says what it freed', () {
      const cleared = AudioUsage(
        totalBytes: 200,
        totalCount: 3,
        reclaimableBytes: 0,
        reclaimableCount: 0,
      );
      expect(clearFace(const CacheState(usage: cleared, freedBytes: 600)), ClearFace.freed);
    });

    test('new audio to clear after a clear offers the clear again instead of the freed note', () {
      expect(clearFace(const CacheState(usage: usage, freedBytes: 600)), ClearFace.clear);
    });

    test('with nothing kept after transcribing and no clear yet, there is nothing to clear', () {
      const none = AudioUsage(
        totalBytes: 200,
        totalCount: 3,
        reclaimableBytes: 0,
        reclaimableCount: 0,
      );
      expect(clearFace(const CacheState(usage: none)), ClearFace.nothing);
      expect(clearFace(const CacheState()), ClearFace.nothing);
    });
  });
}
