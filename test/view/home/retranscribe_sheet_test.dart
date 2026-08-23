import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/services/retranscribe_runner.dart';
import 'package:opentranscribe/view/layouts/home/components/retranscribe_sheet.dart';

void main() {
  test('a running phase always shows the running face', () {
    expect(
      retranscribeFace(RetranscribePhase.running, sawRunning: false),
      RetranscribeFace.running,
    );
    expect(retranscribeFace(RetranscribePhase.running, sawRunning: true), RetranscribeFace.running);
  });

  test('a terminal phase is a summary only to the opening that watched the run', () {
    expect(retranscribeFace(RetranscribePhase.done, sawRunning: true), RetranscribeFace.finished);
    expect(
      retranscribeFace(RetranscribePhase.cancelled, sawRunning: true),
      RetranscribeFace.finished,
    );
    expect(retranscribeFace(RetranscribePhase.done, sawRunning: false), RetranscribeFace.idle);
    expect(retranscribeFace(RetranscribePhase.cancelled, sawRunning: false), RetranscribeFace.idle);
  });

  test('idle always shows the preview face', () {
    expect(retranscribeFace(RetranscribePhase.idle, sawRunning: false), RetranscribeFace.idle);
  });

  test('the fraction walks the queue and survives an empty one', () {
    expect(retranscribeFraction(const RetranscribeProgress()), 0);
    expect(retranscribeFraction(const RetranscribeProgress(total: 4, landed: 1, failed: 1)), 0.5);
    expect(retranscribeFraction(const RetranscribeProgress(total: 2, landed: 2)), 1);
  });

  test('the fraction clamps when the total shrank under the settled count', () {
    expect(retranscribeFraction(const RetranscribeProgress(total: 1, landed: 1, failed: 1)), 1);
  });
}
