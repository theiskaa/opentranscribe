import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/selectable_prose.dart';

void main() {
  group('copyDismissesSelection', () {
    test('copy runs the original action then clears the selection', () {
      final calls = <String>[];
      final items = [
        ContextMenuButtonItem(type: ContextMenuButtonType.copy, onPressed: () => calls.add('copy')),
      ];

      copyDismissesSelection(items, () => calls.add('clear')).single.onPressed!();

      expect(calls, ['copy', 'clear']);
    });

    test('a non-copy action passes through unchanged', () {
      final selectAll = ContextMenuButtonItem(
        type: ContextMenuButtonType.selectAll,
        onPressed: () {},
      );

      expect(copyDismissesSelection([selectAll], () {}).single, same(selectAll));
    });

    test('a copy item with no action passes through unchanged', () {
      const disabled = ContextMenuButtonItem(type: ContextMenuButtonType.copy, onPressed: null);

      expect(copyDismissesSelection([disabled], () {}).single, same(disabled));
    });
  });
}
