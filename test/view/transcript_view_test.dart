import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/take_forecast.dart';
import 'package:opentranscribe/view/layouts/entry/components/transcript_view.dart';

void main() {
  const first = TakeForecast(
    audio: Duration(seconds: 10),
    speech: Duration(seconds: 8),
    localeId: 'en-US',
    characters: 128,
  );
  const second = TakeForecast(
    audio: Duration(seconds: 4),
    speech: Duration(seconds: 3),
    localeId: 'en-US',
    characters: 48,
  );
  test('a take being appended takes up its forecast with the words to lay it out in', () {
    final held = heldForecast(noForecast, appending: true, incoming: first, sample: 'words');
    expect(held, (forecast: first, sample: 'words'));
  });

  test('the forecast outlives the pass\'s done while the take is still being appended', () {
    final held = heldForecast(
      (forecast: first, sample: 'words'),
      appending: true,
      incoming: null,
      sample: '',
    );
    expect(held, (forecast: first, sample: 'words'));
  });

  test('a newer forecast replaces the one held', () {
    final held = heldForecast(
      (forecast: first, sample: 'words'),
      appending: true,
      incoming: second,
      sample: 'other words',
    );
    expect(held, (forecast: second, sample: 'other words'));
  });

  test('nothing is held once the take is no longer being appended', () {
    final held = heldForecast(
      (forecast: first, sample: 'words'),
      appending: false,
      incoming: first,
      sample: 'words',
    );
    expect(held, noForecast);
  });
}
