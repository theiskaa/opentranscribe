import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';

import '../../support/display_fixtures.dart';
import '../../support/fake_display_channels.dart';

PaneLayout layoutOf(
  Map<String, Object?> wire, {
  double? bodySize,
  double closedContentWidth = AppDuo.closedContentWidth,
  Size? size,
  EdgeInsets? padding,
}) {
  final signal = DisplayWire.decode(wire);
  return paneLayoutFor(
    PaneInputs(
      size: size ?? signal.size,
      padding: padding ?? signal.padding,
      signal: signal,
      bodySize: bodySize ?? AppType.body.fontSize!,
      closedContentWidth: closedContentWidth,
    ),
  );
}

void main() {
  group('modal rects', () {
    test('flat and book modal rects follow the detail safe band', () {
      for (final wire in [DisplayWire.flatWide, DisplayWire.bookWide]) {
        final layout = layoutOf(wire);
        expect(layout.modal.left, layout.detail.rect.left + layout.detail.padding.left);
        expect(layout.modal.right, layout.detail.rect.right - layout.detail.padding.right);
        expect(layout.modal.width, greaterThan(0));
      }
    });

    test('a stale signal cannot supply a fold or a modal half to the new window', () {
      final signal = DisplayWire.decode(DisplayWire.bookWide);
      expect(displaySignalDescribes(signal, coverSize), isFalse);
      expect(displaySignalDescribes(signal, wideSize), isTrue);
      final layout = layoutOf(DisplayWire.bookWide, size: coverSize, padding: coverPadding);
      expect(layout.modal, const Rect.fromLTRB(0, 0, 382, 678));
      expect(layout.fold, isNull);
    });
  });

  group('the cover', () {
    final layout = layoutOf(DisplayWire.cover);

    test('is one pane over the whole window that keeps every inset', () {
      const pane = Pane(
        rect: Rect.fromLTWH(0, 0, 466, 678),
        padding: EdgeInsets.fromLTRB(0, 0, 84, 34),
        barToSideColumn: true,
      );
      expect(layout.mode, PaneMode.single);
      expect(layout.leading, pane);
      expect(layout.detail, pane);
      expect(layout.divider, isNull);
      expect(layout.fold, isNull);
    });

    test('sends the bar to the side column, its controls under the status cluster', () {
      expect(
        layout.sideColumn,
        const SideColumn(
          rect: Rect.fromLTWH(382, 0, 84, 678),
          side: BarSide.right,
          upperSlot: Rect.fromLTRB(382, 174, 466, 409),
          lowerSlot: Rect.fromLTRB(382, 409, 466, 644),
          occlusions: [Rect.fromLTWH(400, 29, 37, 37), Rect.fromLTWH(382, 0, 84, 174)],
        ),
      );
    });

    test('keeps the recorder a column and sheets clear of the side column', () {
      expect(
        layout.recorder,
        const RecorderLayout(
          arrangement: RecorderArrangement.column,
          first: Rect.fromLTRB(0, 0, 382, 644),
        ),
      );
      expect(layout.modal, const Rect.fromLTRB(0, 0, 382, 678));
    });

    test('uses the measured top inset when no occlusion is reported', () {
      final bare = layoutOf({...DisplayWire.cover, 'regions': const <Object?>[]});

      expect(bare.sideColumn!.upperSlot.top, bare.leading.padding.top);
    });
  });

  group('the inner display, book wide', () {
    final layout = layoutOf(DisplayWire.bookWide);

    test('splits so both panes meet the fold, with no divider', () {
      expect(layout.mode, PaneMode.split);
      expect(
        layout.fold,
        const Fold(rect: Rect.fromLTWH(456, 0, 40, 669), axis: FoldAxis.vertical),
      );
      expect(
        layout.leading,
        const Pane(rect: Rect.fromLTRB(0, 0, 456, 669), padding: EdgeInsets.only(bottom: 34)),
      );
      expect(
        layout.detail,
        const Pane(
          rect: Rect.fromLTRB(496, 0, 951, 669),
          padding: EdgeInsets.fromLTRB(0, 0, 84, 34),
          barToSideColumn: true,
        ),
      );
      expect(layout.divider, isNull);
    });

    test('takes the side column slot from the live status cluster', () {
      expect(layout.sideColumn!.rect, const Rect.fromLTWH(867, 0, 84, 669));
      expect(layout.sideColumn!.upperSlot, const Rect.fromLTRB(867, 124, 951, 379.5));
      expect(layout.sideColumn!.lowerSlot, const Rect.fromLTRB(867, 379.5, 951, 635));
    });

    test('sets the recorder side by side, the instrument standing off the fold', () {
      expect(
        layout.recorder,
        const RecorderLayout(
          arrangement: RecorderArrangement.sideBySide,
          first: Rect.fromLTRB(0, 0, foldStart - AppDuo.recorderFoldOffset, 635),
          second: Rect.fromLTRB(496, 0, 867, 635),
        ),
      );
    });

    test('centres sheets in the detail pane, clear of the side column', () {
      expect(layout.modal, const Rect.fromLTRB(496, 0, 867, 669));
      expect(layout.modal.overlaps(layout.sideColumn!.rect), isFalse);
    });
  });

  group('the inner display, flat wide', () {
    final layout = layoutOf(DisplayWire.flatWide);

    test('keeps navigation compact with a hairline before the main content', () {
      expect(layout.mode, PaneMode.split);
      expect(layout.fold, isNull);
      expect(layout.leading.rect, const Rect.fromLTRB(0, 0, 280, 669));
      expect(layout.divider, const Rect.fromLTWH(280, 0, 1, 669));
      expect(layout.detail.rect, const Rect.fromLTRB(281, 0, 951, 669));
      expect(layout.detail.barToSideColumn, isTrue);
      expect(layout.leading.barToSideColumn, isFalse);
      expect(layout.modal, const Rect.fromLTRB(281, 0, 867, 669));
    });

    test('a wider remembered cover does not inflate the navigation sidebar', () {
      final remembered = layoutOf(DisplayWire.flatWide, closedContentWidth: 390);

      expect(remembered.leading.rect.right, 280);
      expect(remembered.detail.rect.left, 281);
    });

    test('splits the recorder at the content centre while the division is inactive', () {
      expect(
        layout.recorder,
        const RecorderLayout(
          arrangement: RecorderArrangement.sideBySide,
          first: Rect.fromLTRB(0, 0, 433.5, 635),
          second: Rect.fromLTRB(433.5, 0, 867, 635),
        ),
      );
    });
  });

  group('the inner display, flat tall', () {
    final layout = layoutOf(DisplayWire.flatTall);

    test('is one pane with horizontal bars, as the phone has always been', () {
      expect(layout.mode, PaneMode.single);
      expect(
        layout.leading,
        const Pane(rect: Rect.fromLTWH(0, 0, 669, 951), padding: EdgeInsets.fromLTRB(0, 82, 0, 34)),
      );
      expect(layout.sideColumn, isNull);
      expect(layout.fold, isNull);
      expect(layout.modal, const Rect.fromLTWH(0, 0, 669, 951));
    });

    test('stacks the recorder across the inactive division', () {
      expect(
        layout.recorder,
        const RecorderLayout(
          arrangement: RecorderArrangement.stacked,
          first: Rect.fromLTRB(0, 82, 669, 456),
          second: Rect.fromLTRB(0, 496, 669, 917),
        ),
      );
    });

    test('stacks across a centred token band when no division is reported', () {
      final bare = layoutOf({...DisplayWire.flatTall, 'regions': const <Object?>[]});

      expect(bare.recorder.first.bottom, tallSize.height / 2 - AppDuo.foldBand / 2);
      expect(bare.recorder.second!.top, tallSize.height / 2 + AppDuo.foldBand / 2);
    });
  });

  group('the laptop pose', () {
    final layout = layoutOf(DisplayWire.laptop);

    test('folding into it moves nothing in the recorder', () {
      expect(layout.recorder, layoutOf(DisplayWire.flatTall).recorder);
    });

    test('is one pane that reports the fold and keeps sheets on the lower splitHalfWidth', () {
      expect(layout.mode, PaneMode.single);
      expect(
        layout.fold,
        const Fold(rect: Rect.fromLTWH(0, 456, 669, 40), axis: FoldAxis.horizontal),
      );
      expect(layout.modal, const Rect.fromLTRB(0, 496, 669, 951));
    });
  });

  group('a regular iPhone', () {
    final layout = layoutOf(DisplayWire.iphone);

    test('is today: one pane, every inset, no side column, a column recorder', () {
      const pane = Pane(
        rect: Rect.fromLTWH(0, 0, 402, 874),
        padding: EdgeInsets.fromLTRB(0, 62, 0, 34),
      );
      expect(layout.mode, PaneMode.single);
      expect(layout.leading, pane);
      expect(layout.detail, pane);
      expect(layout.sideColumn, isNull);
      expect(layout.fold, isNull);
      expect(layout.recorder.arrangement, RecorderArrangement.column);
      expect(layout.modal, const Rect.fromLTWH(0, 0, 402, 874));
    });

    test('lays out the same whether or not its OS reports regions', () {
      expect(layoutOf(DisplayWire.unsupported), layout);
    });
  });

  group('an unsupported signal', () {
    test('is one pane with the window insets even on a wide regular window', () {
      final layout = paneLayoutFor(
        PaneInputs(
          size: wideSize,
          padding: widePadding,
          signal: DisplaySignal.unsupported,
          bodySize: AppType.body.fontSize!,
          closedContentWidth: AppDuo.closedContentWidth,
        ),
      );

      expect(layout.mode, PaneMode.single);
      expect(layout.detail.padding, const EdgeInsets.fromLTRB(0, 0, 84, 34));
      expect(layout.detail.barToSideColumn, isFalse);
      expect(layout.sideColumn, isNull);
      expect(layout.fold, isNull);
      expect(layout.recorder.arrangement, RecorderArrangement.column);
      expect(layout.modal, const Rect.fromLTRB(0, 0, 867, 669));
    });
  });

  group('large text', () {
    test('starts at the first accessibility size, not before', () {
      expect(
        layoutOf(DisplayWire.flatWide, bodySize: AppType.largeTextBody - 0.1).mode,
        PaneMode.split,
      );
      expect(layoutOf(DisplayWire.flatWide, bodySize: AppType.largeTextBody).mode, PaneMode.single);
    });

    test('collapses the inner display to one pane and the recorder to a column', () {
      final layout = layoutOf(DisplayWire.flatWide, bodySize: AppType.largeTextBody);

      expect(layout.mode, PaneMode.single);
      expect(layout.detail.rect, const Rect.fromLTWH(0, 0, 951, 669));
      expect(layout.detail.barToSideColumn, isTrue);
      expect(layout.recorder.arrangement, RecorderArrangement.column);
    });

    test('keeps sheets on the trailing side of an active book fold', () {
      final layout = layoutOf(DisplayWire.bookWide, bodySize: AppType.largeTextBody);

      expect(layout.mode, PaneMode.single);
      expect(layout.modal, const Rect.fromLTRB(496, 0, 867, 669));
    });

    test('every inner pose stays a column above the accessibility threshold', () {
      for (final wire in [
        DisplayWire.flatWide,
        DisplayWire.bookWide,
        DisplayWire.flatTall,
        DisplayWire.laptop,
      ]) {
        for (final bodySize in [AppType.largeTextBody, AppType.largeTextBody + 10]) {
          final layout = layoutOf(wire, bodySize: bodySize);
          expect(layout.mode, PaneMode.single);
          expect(layout.recorder.arrangement, RecorderArrangement.column);
        }
      }
    });

    test('keeps the cover a column', () {
      final layout = layoutOf(DisplayWire.cover, bodySize: AppType.largeTextBody);

      expect(layout.mode, PaneMode.single);
      expect(layout.recorder.arrangement, RecorderArrangement.column);
    });
  });

  group('a signal still describing another window', () {
    void expectPlain(PaneLayout layout, Size size, EdgeInsets padding) {
      expect(layout.mode, PaneMode.single);
      expect(layout.fold, isNull);
      expect(layout.sideColumn, isNull);
      expect(layout.recorder.arrangement, RecorderArrangement.column);
      expect(layout.modal, Rect.fromLTRB(padding.left, 0, size.width - padding.right, size.height));
    }

    test('closing from the book pose lays the cover out plainly, sheets inside it', () {
      expectPlain(
        layoutOf(DisplayWire.bookWide, size: coverSize, padding: coverPadding),
        coverSize,
        coverPadding,
      );
    });

    test('rotating from the book pose to tall lays out plainly until the signal lands', () {
      expectPlain(
        layoutOf(DisplayWire.bookWide, size: tallSize, padding: tallPadding),
        tallSize,
        tallPadding,
      );
    });

    test('rotating from tall to wide lays out plainly until the signal lands', () {
      expectPlain(
        layoutOf(DisplayWire.flatTall, size: wideSize, padding: widePadding),
        wideSize,
        widePadding,
      );
    });

    test('a splitHalfWidth point of rounding still counts as the same window', () {
      final layout = layoutOf(
        DisplayWire.bookWide,
        size: Size(wideSize.width + 0.4, wideSize.height),
      );

      expect(layout.mode, PaneMode.split);
    });
  });

  group('Split View halves', () {
    final trailingHalfLeft = wideSize.width - splitHalfWidth;
    final lowerHalfTop = tallSize.height - splitHalfWidth;

    void expectNoFold(PaneLayout layout) {
      expect(layout.fold, isNull);
      expect(layout.mode, PaneMode.single);
      expect(layout.modal.width, greaterThan(0));
      expect(layout.modal.height, greaterThan(0));
    }

    test(
      'in the book pose, the left splitHalfWidth holds the fold at its edge and parts nothing',
      () {
        final layout = layoutOf(
          DisplayWire.splitHalf(
            width: splitHalfWidth,
            height: wideSize.height,
            insets: DisplayWire.insets(0, 0, widePadding.bottom, 0),
            division: DisplayWire.region(
              'division',
              foldStart,
              0,
              splitHalfWidth - foldStart,
              wideSize.height,
            ),
          ),
        );

        expectNoFold(layout);
        expect(layout.modal, Rect.fromLTRB(0, 0, splitHalfWidth, wideSize.height));
      },
    );

    test(
      'in the book pose, the right splitHalfWidth holds the fold at its edge and parts nothing',
      () {
        final layout = layoutOf(
          DisplayWire.splitHalf(
            width: splitHalfWidth,
            height: wideSize.height,
            insets: DisplayWire.insetsOf(widePadding),
            barSide: 'right',
            division: DisplayWire.region(
              'division',
              0,
              0,
              foldStart + foldDepth - trailingHalfLeft,
              wideSize.height,
            ),
          ),
        );

        expectNoFold(layout);
        expect(
          layout.modal,
          Rect.fromLTRB(0, 0, splitHalfWidth - widePadding.right, wideSize.height),
        );
      },
    );

    test(
      'in the laptop pose, the upper splitHalfWidth holds the fold at its edge and parts nothing',
      () {
        final layout = layoutOf(
          DisplayWire.splitHalf(
            width: tallSize.width,
            height: splitHalfWidth,
            insets: DisplayWire.insets(tallPadding.top, 0, 0, 0),
            division: DisplayWire.region(
              'division',
              0,
              foldStart,
              tallSize.width,
              splitHalfWidth - foldStart,
            ),
          ),
        );

        expectNoFold(layout);
      },
    );

    test(
      'in the laptop pose, the lower splitHalfWidth holds the fold at its edge and parts nothing',
      () {
        final layout = layoutOf(
          DisplayWire.splitHalf(
            width: tallSize.width,
            height: splitHalfWidth,
            insets: DisplayWire.insets(0, 0, tallPadding.bottom, 0),
            division: DisplayWire.region(
              'division',
              0,
              0,
              tallSize.width,
              foldStart + foldDepth - lowerHalfTop,
            ),
          ),
        );

        expectNoFold(layout);
      },
    );

    test('in the laptop pose, a side splitHalfWidth still has the fold across it', () {
      final layout = layoutOf(
        DisplayWire.splitHalf(
          width: sideHalfWidth,
          height: tallSize.height,
          insets: DisplayWire.insetsOf(tallPadding),
          division: DisplayWire.region('division', 0, foldStart, sideHalfWidth, foldDepth),
        ),
      );

      expect(
        layout.fold,
        const Fold(
          rect: Rect.fromLTWH(0, foldStart, sideHalfWidth, foldDepth),
          axis: FoldAxis.horizontal,
        ),
      );
      expect(layout.modal, Rect.fromLTRB(0, foldStart + foldDepth, sideHalfWidth, tallSize.height));
    });
  });

  group('narrower windows on the inner display', () {
    test('a compact Split View splitHalfWidth is one pane', () {
      final layout = layoutOf({
        ...DisplayWire.flatWide,
        'width': splitHalfWidth,
        'horizontal': 'compact',
        'regions': const <Object?>[],
      });

      expect(layout.mode, PaneMode.single);
      expect(layout.recorder.arrangement, RecorderArrangement.column);
    });

    test('a regular window too narrow for two closed columns is one pane', () {
      final layout = layoutOf({
        ...DisplayWire.flatWide,
        'width': 700.0,
        'regions': const <Object?>[],
      });

      expect(layout.mode, PaneMode.single);
      expect(layout.recorder.arrangement, RecorderArrangement.sideBySide);
    });
  });

  group('a bar on the left', () {
    final layout = layoutOf({
      ...DisplayWire.flatWide,
      'insets': DisplayWire.insets(0, widePadding.right, widePadding.bottom, 0),
      'barSide': 'left',
      'regions': [DisplayWire.region('occlusion', 0, 0, widePadding.right, 124)],
    });

    test('insets compact navigation past the status column', () {
      expect(
        layout.leading,
        const Pane(rect: Rect.fromLTRB(0, 0, 364, 669), padding: EdgeInsets.fromLTRB(84, 0, 0, 34)),
      );
      expect(layout.divider, const Rect.fromLTWH(364, 0, 1, 669));
    });

    test('leaves the detail its horizontal bar', () {
      expect(
        layout.detail,
        const Pane(rect: Rect.fromLTRB(365, 0, 951, 669), padding: EdgeInsets.only(bottom: 34)),
      );
    });

    test('draws the side column on the left', () {
      expect(layout.sideColumn!.side, BarSide.left);
      expect(layout.sideColumn!.rect, const Rect.fromLTWH(0, 0, 84, 669));
      expect(layout.sideColumn!.upperSlot.top, 124);
    });
  });
}
