import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/app_text_field.dart';
import 'package:opentranscribe/view/widgets/app_toggle.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/empty_state.dart';
import 'package:opentranscribe/view/widgets/page_indicator.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:opentranscribe/view/widgets/github_mark.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';
import 'package:opentranscribe/view/widgets/wave_glyph.dart';

/// The widget gallery: every design-system widget in its states, for eyeballing
/// on device. Debug builds only, so labels are deliberately not localized.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final TextEditingController _text = TextEditingController();
  bool _toggle = true;
  int _page = 0;
  String? _notice;

  static const _icons = [
    AppIcons.micFill,
    AppIcons.mic,
    AppIcons.waveform,
    AppIcons.houseFill,
    AppIcons.gearshapeFill,
    AppIcons.chevronBackward,
    AppIcons.chevronForward,
    AppIcons.playFill,
    AppIcons.pauseFill,
    AppIcons.stopFill,
    AppIcons.squareFill,
    AppIcons.xmark,
    AppIcons.checkmark,
    AppIcons.arrowUpRight,
    AppIcons.arrowCounterclockwise,
    AppIcons.trash,
    AppIcons.ellipsis,
    AppIcons.docOnDoc,
    AppIcons.globe,
    AppIcons.moonFill,
    AppIcons.sunMax,
    AppIcons.icloud,
    AppIcons.calendar,
    AppIcons.textformat,
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Widget _section(String label) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.sm),
      child: Text(label.toUpperCase(), style: AppType.eyebrow.copyWith(color: theme.textSecondary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ColoredBox(
      color: theme.background,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppTopBar.heightOf(context) + AppSpacing.sm,
              AppSpacing.lg,
              120,
            ),
            children: [
              _section('Icons'),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [for (final icon in _icons) AppIcon(icon, color: theme.text)],
              ),
              _section('Buttons'),
              AppButton(label: 'Primary', onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Secondary', variant: AppButtonVariant.secondary, onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Danger', variant: AppButtonVariant.danger, onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              const AppButton(label: 'Disabled', onPressed: null),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Loading', isLoading: true, onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'With icon',
                icon: AppIcons.arrowCounterclockwise,
                expand: false,
                onPressed: () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  AppIconButton(icon: AppIcons.pauseFill, onTap: () {}),
                  const SizedBox(width: AppSpacing.sm),
                  AppIconButton(icon: AppIcons.arrowCounterclockwise, onTap: () {}),
                ],
              ),
              _section('Toggle'),
              Row(
                children: [
                  AppToggle(value: _toggle, onChanged: (v) => setState(() => _toggle = v)),
                  const SizedBox(width: AppSpacing.lg),
                  const AppToggle(value: true, onChanged: null),
                ],
              ),
              _section('Text field'),
              AppTextField(controller: _text, placeholder: 'Entry title'),
              _section('Spinner'),
              const Align(alignment: Alignment.centerLeft, child: AppSpinner()),
              _section('Page indicator'),
              Touchable(
                onTap: () => setState(() => _page = (_page + 1) % 4),
                child: PageIndicator(count: 4, index: _page),
              ),
              _section('Notice'),
              AppButton(
                label: 'Show notice',
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _notice = 'Couldn\'t save that entry.'),
              ),
              AppNotice(message: _notice, onDismiss: () => setState(() => _notice = null)),
              _section('Menu'),
              Align(
                alignment: Alignment.centerLeft,
                child: AppMenuButton(
                  icon: AppIcons.ellipsis,
                  items: const [
                    AppMenuItem(label: 'Rename', icon: AppIcons.textformat),
                    AppMenuItem(label: 'Re-transcribe', icon: AppIcons.arrowCounterclockwise),
                    AppMenuItem(label: 'Delete', icon: AppIcons.trash, destructive: true),
                  ],
                  onSelected: (_) {},
                ),
              ),
              _section('Wave glyph'),
              const Align(alignment: Alignment.centerLeft, child: WaveGlyph()),
              _section('GitHub mark'),
              Row(
                children: [
                  GithubMark(color: theme.text, size: 28),
                  const SizedBox(width: AppSpacing.lg),
                  GithubMark(color: theme.accent, size: 14),
                ],
              ),
              _section('Invisible ink'),
              const _InkDemo(),
              const SizedBox(height: AppSpacing.xl),
              const _InkLinesDemo(),
              _section('Empty state'),
              const EmptyState(
                visual: WaveGlyph(),
                title: 'Nothing here yet',
                message: 'Speak your mind.',
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, right: 0, child: _GalleryTopBar()),
        ],
      ),
    );
  }
}

/// Tap the paragraph to watch it dissolve into invisible ink and resolve back,
/// the same effect a re-transcribe runs on the old words: hide, hold a beat,
/// then reveal.
class _InkDemo extends StatefulWidget {
  const _InkDemo();

  @override
  State<_InkDemo> createState() => _InkDemoState();
}

class _InkDemoState extends State<_InkDemo> with TickerProviderStateMixin {
  static const _sample =
      'Tap this to watch it dissolve into invisible ink. The words scatter into '
      'a living field of soft sparks, hold there the way they would while a run '
      'is in flight, then resolve back into the text.';

  final GlobalKey _key = GlobalKey();

  // Created in initState, never lazily: a demo disposed without ever being
  // tapped must not create its tickers during teardown.
  late final AnimationController _reveal;
  late final AnimationController _clock;
  ui.Image? _image;
  Size? _size;
  double _dpr = 1;
  bool _shimmering = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, value: 1);
    _clock = AnimationController(vsync: this);
  }

  void _play() {
    // Gated like production: the transcript view skips the shimmer too.
    if (_shimmering || context.reduceMotion) return;
    final boundary = _key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize || boundary.size.isEmpty) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    _image?.dispose();
    _image = boundary.toImageSync(pixelRatio: dpr);
    // Plain copy: a raw RenderBox.size tracks its owner and trips debugAdoptSize.
    _size = Size(boundary.size.width, boundary.size.height);
    _dpr = dpr;
    _reveal.duration = context.motionNow.inkDissolve;
    setState(() => _shimmering = true);
    _clock
      ..duration = context.motionNow.inkLoop
      ..repeat();
    _reveal.reverse(); // text -> ink
    // Hold the shimmer, then take the slower path back to the text.
    Future<void>.delayed(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      _reveal.duration = context.motionNow.inkResolve;
      await _reveal.forward();
      if (!mounted) return;
      _clock.stop();
      setState(() {
        _shimmering = false;
        _image?.dispose();
        _image = null;
        _size = null;
      });
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _clock.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final text = Touchable(
      onTap: _play,
      child: RepaintBoundary(
        key: _key,
        child: Text(_sample, style: AppType.body.copyWith(color: theme.text)),
      ),
    );
    if (!_shimmering || _image == null || _size == null) return text;
    return Stack(
      children: [
        FadeTransition(opacity: _reveal, child: text),
        IgnorePointer(
          child: FadeTransition(
            opacity: ReverseAnimation(_reveal),
            child: InvisibleInk(
              image: _image!,
              size: _size!,
              pixelRatio: _dpr,
              color: theme.text,
              clock: _clock,
            ),
          ),
        ),
      ],
    );
  }
}

/// The first-transcribe placeholder: estimated ink lines for a fake 25-second
/// recording, shimmering in place so the shape can be eyeballed without
/// recording anything.
class _InkLinesDemo extends StatefulWidget {
  const _InkLinesDemo();

  @override
  State<_InkLinesDemo> createState() => _InkLinesDemoState();
}

class _InkLinesDemoState extends State<_InkLinesDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!context.reduceMotion) {
      _clock
        ..duration = context.motionNow.inkLoop
        ..repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    const style = AppType.body;
    final fontSize = style.fontSize!;
    final lineHeight = fontSize * style.height!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final lines = estimateInkLines(
          audio: const Duration(seconds: 25),
          width: width,
          fontSize: fontSize,
        );
        return InvisibleInk.points(
          points: placeholderInkPoints(
            width: width,
            lines: lines,
            fontSize: fontSize,
            lineHeight: lineHeight,
          ),
          size: Size(width, lines * lineHeight),
          color: theme.text,
          clock: _clock,
        );
      },
    );
  }
}

class _GalleryTopBar extends StatelessWidget {
  const _GalleryTopBar();

  @override
  Widget build(BuildContext context) {
    return const AppTopBar(frosted: true, leading: AppBackButton());
  }
}
