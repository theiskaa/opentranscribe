import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/services/retranscribe_runner.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/components/retranscribe_sheet.dart';

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

  test('the active engine name is the marked row, and empty before rows exist', () {
    EngineRowState row(String id, {required bool active}) => EngineRowState(
      descriptor: EngineDescriptor(
        engineId: id,
        displayName: id.toUpperCase(),
        blurb: (_) => id,
        logo: const IconData(0x21),
      ),
      available: true,
      isActive: active,
    );

    expect(activeEngineName([row('a', active: false), row('b', active: true)]), 'B');
    expect(activeEngineName(const []), '');
  });

  test('the fraction clamps when the total shrank under the settled count', () {
    expect(retranscribeFraction(const RetranscribeProgress(total: 1, landed: 1, failed: 1)), 1);
  });
}
