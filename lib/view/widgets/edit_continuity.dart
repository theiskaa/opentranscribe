import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';

enum EditRestore { wait, discard, restore }

EditRestore editRestoreFor({
  required bool supported,
  required bool settled,
  required bool stable,
  required bool currentRoute,
  required bool canFocus,
  required bool anotherFieldFocused,
  required bool interrupted,
  required String savedText,
  required String currentText,
}) {
  if (!supported ||
      !currentRoute ||
      !canFocus ||
      anotherFieldFocused ||
      interrupted ||
      savedText != currentText) {
    return EditRestore.discard;
  }
  if (!settled || !stable) return EditRestore.wait;
  return EditRestore.restore;
}

bool editDisplayKnown({
  required bool previouslyKnown,
  required bool supported,
  required bool cover,
  required bool regular,
}) => previouslyKnown || (supported && (cover || regular));

class EditContinuityController extends ChangeNotifier {
  void cancel() => notifyListeners();
}

TextSelection? editSelectionFor(TextSelection selection, int textLength) =>
    selection.isValid && selection.end <= textLength ? selection : null;

class EditContinuity extends StatefulWidget {
  const EditContinuity({
    required this.controller,
    required this.focusNode,
    required this.requestKeyboard,
    required this.child,
    this.onBlur,
    this.continuity,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback requestKeyboard;
  final VoidCallback? onBlur;
  final EditContinuityController? continuity;
  final Widget child;

  @override
  State<EditContinuity> createState() => _EditContinuityState();
}

class _EditContinuityState extends State<EditContinuity> with WidgetsBindingObserver {
  PaneTouchTracker? _panes;
  ModalRoute<dynamic>? _route;
  ({Size size, PaneMode mode})? _geometry;
  TextEditingValue? _focused;
  TextEditingValue? _pending;
  TextEditingValue? _metricsCandidate;
  bool _blurred = false;
  bool _scheduled = false;
  bool _interrupted = false;
  int _revision = 0;
  int _stableRevision = -1;
  bool _duoSeen = false;

  bool get _recoverable => _panes?.supported == true && _duoSeen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointer);
    widget.focusNode.addListener(_focusChanged);
    widget.controller.addListener(_valueChanged);
    widget.continuity?.addListener(_cancel);
    _valueChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _panes = PaneLayoutScope.maybeOf(context);
    _route = ModalRoute.of(context);
    final panes = _panes;
    if (panes == null) return;
    _duoSeen = editDisplayKnown(
      previouslyKnown: _duoSeen,
      supported: panes.supported,
      cover: panes.cover,
      regular: panes.regular,
    );
    final geometry = (size: panes.media.size, mode: panes.layout.mode);
    if (_geometry != null && _geometry != geometry && _recoverable) {
      _pending ??= _metricsCandidate ?? _focused;
      _metricsCandidate = null;
      _revision++;
    }
    _geometry = geometry;
    if (_pending != null || _blurred) _schedule();
  }

  @override
  void didUpdateWidget(EditContinuity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.continuity != widget.continuity) {
      oldWidget.continuity?.removeListener(_cancel);
      widget.continuity?.addListener(_cancel);
    }
    if (oldWidget.focusNode == widget.focusNode && oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.focusNode.removeListener(_focusChanged);
    oldWidget.controller.removeListener(_valueChanged);
    widget.focusNode.addListener(_focusChanged);
    widget.controller.addListener(_valueChanged);
    _focused = _pending = _metricsCandidate = null;
    _blurred = false;
    _valueChanged();
  }

  @override
  void didChangeMetrics() {
    // A responder can disappear before the resized MediaQuery reaches this field.
    if (_recoverable && _focused != null) {
      _metricsCandidate ??= _focused;
      _schedule();
    }
  }

  void _valueChanged() {
    if (widget.focusNode.hasFocus && _pending == null && widget.controller.selection.isValid) {
      _focused = widget.controller.value;
      if (_metricsCandidate != null && _metricsCandidate!.text != _focused!.text) {
        _metricsCandidate = _focused;
      }
    }
  }

  void _focusChanged() {
    if (widget.focusNode.hasFocus) {
      _blurred = false;
      _interrupted = false;
      _valueChanged();
      if (PaneScope.maybeOf(context)?.detailRoot == true || _panes?.detailKeys.isNotEmpty == true) {
        _panes?.touch(PaneTouch.detail);
      }
      return;
    }
    if (!_recoverable) {
      _focused = null;
      widget.onBlur?.call();
      return;
    }
    _blurred = true;
    _schedule();
  }

  void _cancel() {
    _interrupted = true;
    _pending = null;
    _focused = _metricsCandidate = null;
    if (_recoverable) _schedule();
  }

  void _pointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    if (_pending != null || _metricsCandidate != null || _blurred) _interrupted = true;
    _pending = _metricsCandidate = null;
    if (!widget.focusNode.hasFocus) _focused = null;
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      if (revision != _revision || _stableRevision != _revision) {
        _stableRevision = _revision;
        _schedule();
        return;
      }
      final saved = _pending;
      if (saved == null) {
        _metricsCandidate = null;
        if (_blurred) _finishBlur();
        _resumeSnapshot();
        return;
      }
      final primary = FocusManager.instance.primaryFocus;
      final decision = editRestoreFor(
        supported: _recoverable,
        settled: _panes?.settled == true,
        stable: revision == _revision,
        currentRoute: _route?.isCurrent ?? true,
        canFocus: widget.focusNode.canRequestFocus,
        anotherFieldFocused:
            primary != null && primary != widget.focusNode && primary is! FocusScopeNode,
        interrupted: _interrupted,
        savedText: saved.text,
        currentText: widget.controller.text,
      );
      if (decision == EditRestore.wait) return;
      _pending = null;
      if (decision == EditRestore.restore) {
        _blurred = false;
        final selection = editSelectionFor(saved.selection, widget.controller.text.length);
        if (selection != null) widget.controller.selection = selection;
        widget.focusNode.requestFocus();
        widget.requestKeyboard();
      } else if (_blurred) {
        _finishBlur();
      }
      _metricsCandidate = null;
      _resumeSnapshot();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _resumeSnapshot() {
    if (!widget.focusNode.hasFocus) return;
    _interrupted = false;
    _valueChanged();
  }

  void _finishBlur() {
    _blurred = false;
    _focused = null;
    widget.onBlur?.call();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
    widget.focusNode.removeListener(_focusChanged);
    widget.controller.removeListener(_valueChanged);
    widget.continuity?.removeListener(_cancel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
