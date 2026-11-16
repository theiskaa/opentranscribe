import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';

import '../../support/fake_display_channels.dart';

PaneLayout layout(Map<String, Object?> wire, {double width = AppDuo.closedContentWidth}) {
  final signal = DisplayWire.decode(wire);
  return paneLayoutFor(
    PaneInputs(
      size: signal.size,
      padding: signal.padding,
      signal: signal,
      bodySize: AppType.body.fontSize!,
      closedContentWidth: width,
    ),
  );
}

bool glides(
  PaneLayout from,
  PaneLayout to, {
  bool supported = true,
  bool previouslySettled = true,
  bool settled = true,
  bool cover = false,
  bool reduceMotion = false,
}) => paneGlides(
  previous: from,
  next: to,
  supported: supported,
  previouslySettled: previouslySettled,
  settled: settled,
  cover: cover,
  reduceMotion: reduceMotion,
);

void main() {
  final flat = layout(DisplayWire.flatWide);
  final wider = layout(DisplayWire.flatWide, width: 390);

  test('remembered cover widths do not disturb compact navigation while settled', () {
    expect(glides(flat, wider), isTrue);
    final middle = interpolatePanes(flat, wider, 0.5);
    expect(middle.leading.rect.right, 280);
    expect(middle.detail.rect.left, 281);
    expect(middle.mode, PaneMode.split);
    expect(middle.modal, wider.modal);
  });

  test('mode flips and recorder arrangement flips swap without travel', () {
    final cover = layout(DisplayWire.cover);
    final tall = layout(DisplayWire.flatTall);
    expect(glides(flat, cover), isFalse);
    expect(glides(cover, flat), isFalse);
    expect(glides(tall, flat), isFalse);
    expect(glides(flat, tall), isFalse);
  });

  test('a stale frame and its first settled replacement never glide', () {
    expect(glides(flat, wider, settled: false), isFalse);
    expect(glides(flat, wider, previouslySettled: false), isFalse);
  });

  test('Reduce Motion and the cover always swap frames without travel', () {
    expect(glides(flat, wider, reduceMotion: true), isFalse);
    expect(glides(flat, wider, cover: true), isFalse);
    expect(glides(flat, wider, supported: false), isFalse);
  });

  test('a regular supported iPhone never gains pane motion', () {
    final phone = layout(DisplayWire.iphone);
    expect(glides(phone, phone), isFalse);
    expect(glides(flat, phone), isFalse);
  });

  test('a settled cover never gains pane motion', () {
    final cover = layout(DisplayWire.cover);
    expect(glides(cover, cover, cover: true), isFalse);
    expect(glides(flat, cover, cover: true), isFalse);
  });

  test('a newly reserved fold snaps so no content travels across it', () {
    final book = layout(DisplayWire.bookWide);
    final laptop = layout(DisplayWire.laptop);
    expect(glides(flat, book), isFalse);
    expect(glides(book, flat), isFalse);
    expect(glides(book, laptop), isFalse);
    expect(glides(laptop, book), isFalse);
  });

  test('interpolation preserves the endpoints and the recorder blocks', () {
    expect(interpolatePanes(flat, wider, 0), same(flat));
    expect(interpolatePanes(flat, wider, 1), same(wider));
    expect(interpolatePanes(flat, wider, 0).leading, flat.leading);
    expect(interpolatePanes(flat, wider, 0).detail, flat.detail);
    expect(interpolatePanes(flat, wider, 1), wider);
    expect(interpolatePanes(flat, wider, 0.5).recorder, flat.recorder);
    expect(interpolatePanes(flat, wider, 0.5).leading.padding, const EdgeInsets.only(bottom: 34));
  });
}
