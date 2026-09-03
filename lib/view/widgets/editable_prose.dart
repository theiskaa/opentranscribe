import 'package:flutter/cupertino.dart'
    show
        CupertinoAdaptiveTextSelectionToolbar,
        CupertinoTextMagnifier,
        cupertinoTextSelectionHandleControls;
import 'package:flutter/gestures.dart' show TapDragEndDetails;
import 'package:flutter/services.dart' show TextCapitalization, TextInputAction;
import 'package:flutter/widgets.dart';

/// The app's editable text, the platform way: tap places the caret, a long
/// press raises the magnifier and the edit menu, a drag selects, the iOS
/// handles show, and the keyboard capitalizes as asked. Built on
/// [EditableText] rather than the Cupertino field, which merges its own
/// font, size and tracking into the style: a field here must set exactly the
/// type its reading twin does, so entering an edit moves no text.
///
/// Adds around [EditableText] only what the Cupertino field adds around it,
/// never what it adds inside: no decoration, no placeholder, no clear button.
/// Owners draw the frame. The handles and menu take their colours from the
/// [SelectionTheme] at the app root.
///
/// Autofill is off for every field. A secret offered to autofill is a secret
/// offered to iCloud Keychain, which is off-device; and the accessory strip
/// autofill hangs over the keyboard changes the inset as focus moves between
/// fields, which walks a keyboard-sized sheet up and down the screen.
class EditableProse extends StatefulWidget {
  const EditableProse({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.cursorColor,
    required this.backgroundCursorColor,
    required this.selectionColor,
    required this.keyboardAppearance,
    this.autofocus = false,
    this.obscureText = false,
    this.secret = false,
    this.capitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.scrollPadding = const EdgeInsets.all(20),
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Color cursorColor;
  final Color backgroundCursorColor;
  final Color selectionColor;
  final Brightness keyboardAppearance;
  final bool autofocus;
  final bool obscureText;

  /// Keeps autocorrect, suggestions and the keyboard's personalized learning
  /// off, shown or hidden. A passphrase must never teach the keyboard.
  final bool secret;

  final TextCapitalization capitalization;

  /// Null grows without bound, as [EditableText.maxLines] reads it.
  final int? maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsets scrollPadding;

  @override
  State<EditableProse> createState() => EditableProseState();
}

/// Whether the iOS selection handles show after a selection change: never on
/// a collapsed selection or one the keyboard made, always for handwriting,
/// otherwise when there is text and the gesture that caused it allows them.
/// The Cupertino field's rule, kept pure so it can be tested.
bool showsSelectionHandles({
  required SelectionChangedCause? cause,
  required bool collapsed,
  required bool hasText,
  required bool gestureAllows,
}) {
  if (!gestureAllows) return false;
  if (collapsed) return false;
  if (cause == SelectionChangedCause.keyboard) return false;
  if (cause == SelectionChangedCause.stylusHandwriting) return true;
  return hasText;
}

class EditableProseState extends State<EditableProse>
    implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => true;

  @override
  bool get selectionEnabled => true;

  late final _ProseGestureBuilder _gestures = _ProseGestureBuilder(state: this);
  bool _showHandles = false;

  /// One [TextMagnifierConfiguration] for every field: the Cupertino loupe.
  static final TextMagnifierConfiguration _magnifier = TextMagnifierConfiguration(
    magnifierBuilder: (context, controller, info) =>
        CupertinoTextMagnifier(controller: controller, magnifierInfo: info),
  );

  /// The horizontal cursor nudge iOS draws, in device pixels; the Cupertino
  /// field's own constant.
  static const double _cursorOffsetPixels = -2;

  EditableTextState? get _editable => editableTextKey.currentState;

  /// Raises the keyboard on an already focused field, for a frame tap that
  /// lands outside the text.
  void requestKeyboard() => _editable?.requestKeyboard();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(EditableProse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode.removeListener(_onFocusChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  // The selection wash paints only while focused, so a rebuild must follow
  // the focus.
  void _onFocusChanged() => setState(() {});

  void _onSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    final show = showsSelectionHandles(
      cause: cause,
      collapsed: widget.controller.selection.isCollapsed,
      hasText: widget.controller.text.isNotEmpty,
      gestureAllows: _gestures.shouldShowSelectionToolbar && _gestures.shouldShowSelectionHandles,
    );
    if (show != _showHandles) setState(() => _showHandles = show);
    if (cause == SelectionChangedCause.longPress) _editable?.bringIntoView(selection.extent);
  }

  // VoiceOver's activate and focus, answered as the Cupertino field answers
  // them: the renderer ignores pointers, so nothing below would.
  void _onSemanticsTap() {
    final controller = widget.controller;
    if (!controller.selection.isValid) {
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    }
    requestKeyboard();
  }

  void _onSemanticsFocus() {
    final node = widget.focusNode;
    if (node.canRequestFocus && !node.hasFocus) {
      node.requestFocus();
    } else {
      requestKeyboard();
    }
  }

  static Widget _contextMenu(BuildContext context, EditableTextState state) {
    if (SystemContextMenu.isSupportedByField(state)) {
      return SystemContextMenu.editableText(editableTextState: state);
    }
    return CupertinoAdaptiveTextSelectionToolbar.editableText(editableTextState: state);
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    return Semantics(
      onTap: _onSemanticsTap,
      onFocus: _onSemanticsFocus,
      child: _gestures.buildGestureDetector(
        behavior: HitTestBehavior.translucent,
        child: RepaintBoundary(
          child: EditableText(
            key: editableTextKey,
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: widget.style,
            cursorColor: widget.cursorColor,
            backgroundCursorColor: widget.backgroundCursorColor,
            selectionColor: focused ? widget.selectionColor : null,
            autocorrectionTextRectColor: widget.selectionColor,
            keyboardAppearance: widget.keyboardAppearance,
            autofocus: widget.autofocus,
            obscureText: widget.obscureText,
            autocorrect: !widget.secret,
            enableSuggestions: !widget.secret,
            enableIMEPersonalizedLearning: !widget.secret,
            // Null, not the empty-list default: an empty list still opts the
            // field into autofill and lets the platform guess.
            autofillHints: null,
            textCapitalization: widget.capitalization,
            maxLines: widget.maxLines,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onSelectionChanged: _onSelectionChanged,
            scrollPadding: widget.scrollPadding,
            showSelectionHandles: _showHandles,
            selectionControls: cupertinoTextSelectionHandleControls,
            contextMenuBuilder: _contextMenu,
            magnifierConfiguration: _magnifier,
            // The gesture detector above owns every pointer; the renderer must
            // not answer them a second time.
            rendererIgnoresPointer: true,
            cursorOpacityAnimates: true,
            cursorRadius: const Radius.circular(2),
            cursorOffset: Offset(_cursorOffsetPixels / MediaQuery.devicePixelRatioOf(context), 0),
            paintCursorAboveText: true,
          ),
        ),
      ),
    );
  }
}

/// The Cupertino field's gesture builder: the base class places the caret
/// and raises the keyboard on tap; a finished drag selection raises it too.
class _ProseGestureBuilder extends TextSelectionGestureDetectorBuilder {
  _ProseGestureBuilder({required EditableProseState state})
    : _state = state,
      super(delegate: state);

  final EditableProseState _state;

  @override
  void onDragSelectionEnd(TapDragEndDetails details) {
    _state.requestKeyboard();
    super.onDragSelectionEnd(details);
  }
}
