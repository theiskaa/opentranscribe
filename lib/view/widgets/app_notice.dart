import 'dart:async';

import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

/// How long a notice stays: its own [duration], or three times that when a
/// screen reader is driving, so the words are reached before they go.
Duration noticeHold(Duration duration, {required bool assisted}) =>
    assisted ? duration * 3 : duration;

/// A quiet inline notice: one line that appears when a screen has something to
/// say (a failure it could not prevent), sits in the layout rather than over it,
/// and clears ITSELF after a few seconds via [onDismiss]. No button, no colour -
/// an error reads by its words and by fading away, the way a dialog never would.
/// A screen reader hears it announced and gets longer before it clears.
class AppNotice extends StatefulWidget {
  const AppNotice({
    required this.message,
    required this.onDismiss,
    this.duration = const Duration(seconds: 4),
    this.oneLine = false,
    super.key,
  });

  final String? message;
  final VoidCallback onDismiss;
  final Duration duration;

  /// Shrinks a long message to one line instead of wrapping it, for a seat of
  /// fixed height such as a bar's row.
  final bool oneLine;

  @override
  State<AppNotice> createState() => _AppNoticeState();
}

class _AppNoticeState extends State<AppNotice> {
  Timer? _timer;
  bool _armed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: the hold and the announcement both read the tree.
    if (_armed) return;
    _armed = true;
    _arm();
  }

  @override
  void didUpdateWidget(AppNotice old) {
    super.didUpdateWidget(old);
    // A fresh message restarts the clock; the same message leaves it running so
    // a rebuild does not keep a stale line alive forever.
    if (widget.message != old.message) _arm();
  }

  void _arm() {
    _timer?.cancel();
    final message = widget.message;
    if (message == null) return;
    final assisted = MediaQuery.accessibleNavigationOf(context);
    if (assisted) {
      unawaited(
        SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context)),
      );
    }
    _timer = Timer(noticeHold(widget.duration, assisted: assisted), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final message = widget.message;
    final text = message == null
        ? null
        : Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.note.copyWith(color: theme.textSecondary),
          );
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: ValueKey(message),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: widget.oneLine ? FittedBox(fit: BoxFit.scaleDown, child: text) : text,
            ),
    );
  }
}
