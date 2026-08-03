import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/home/components/reflection_home_card.dart';
import 'package:opentranscribe/view/layouts/reflections/components/disabled_card.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_labels.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_scrubber.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_states.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/app_text_field.dart';
import 'package:opentranscribe/view/widgets/app_toggle.dart';
import 'package:opentranscribe/view/widgets/segmented_control.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/empty_state.dart';
import 'package:opentranscribe/view/widgets/glass_capsule.dart';
import 'package:opentranscribe/view/widgets/page_indicator.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:opentranscribe/view/widgets/circle_tile.dart';
import 'package:opentranscribe/view/widgets/dither.dart';
import 'package:opentranscribe/view/widgets/dither_card.dart';
import 'package:opentranscribe/view/widgets/dither_field.dart';
import 'package:opentranscribe/view/widgets/github_mark.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/animated_reveal.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/time_field.dart';
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
  bool _reveal = true;
  int _segment = 1;
  int _page = 0;
  String? _notice;
  int _hour = 9;
  int _minute = 0;

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
    AppIcons.oneCalendar,
    AppIcons.sevenCalendar,
    AppIcons.bell,
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
              _section('Segmented control'),
              AppSegmentedControl<int>(
                segments: const [(0, 'Day'), (1, 'Week'), (2, 'Month')],
                selected: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
              _section('Time field'),
              SettingsCard(
                children: [
                  TimeField(
                    label: 'Time',
                    hour: _hour,
                    minute: _minute,
                    onChanged: (h, m) => setState(() {
                      _hour = h;
                      _minute = m;
                    }),
                  ),
                ],
              ),
              _section('Animated reveal'),
              SettingsCard(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsToggleRow(
                        icon: AppIcons.bellFill,
                        label: 'Reveal a row',
                        value: _reveal,
                        onChanged: (v) => setState(() => _reveal = v),
                      ),
                      AnimatedReveal(
                        visible: _reveal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SettingsDivider(),
                            TimeField(
                              label: 'Time',
                              hour: _hour,
                              minute: _minute,
                              onChanged: (h, m) => setState(() {
                                _hour = h;
                                _minute = m;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
              _section('Glass capsule'),
              const _GlassCapsuleDemo(),
              _section('Dither reveal'),
              const _DitherRevealDemo(),
              _section('Dither field'),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 150,
                  height: 96,
                  child: DitherField(color: theme.reflectionCard.dither),
                ),
              ),
              _section('Dither card'),
              DitherCard(
                patch: const Size(120, 72),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'The reflection family\'s card surface, with the corner '
                    'breath of dither sized by its patch.',
                    style: AppType.footnote.copyWith(color: theme.textSecondary, height: 1.4),
                  ),
                ),
              ),
              _section('Notice'),
              AppButton(
                label: 'Show notice',
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _notice = 'Couldn\'t save that entry.'),
              ),
              AppNotice(message: _notice, onDismiss: () => setState(() => _notice = null)),
              _section('Menu'),
              const Align(
                alignment: Alignment.centerLeft,
                child: AppMenuButton(
                  icon: AppIcons.ellipsis,
                  items: [
                    AppMenuItem(label: 'Rename', icon: AppIcons.textformat),
                    AppMenuItem(label: 'Re-transcribe', icon: AppIcons.arrowCounterclockwise),
                    AppMenuItem(label: 'Delete', icon: AppIcons.trash, destructive: true),
                  ],
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
              _section('Locale flag'),
              Row(
                children: [
                  for (final tag in ['en-US', 'de', 'ja', 'fr-FR', 'ko'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.surfaceBorder),
                        ),
                        child: LocaleFlag(localeFlag(tag), size: 18),
                      ),
                    ),
                  CircleTile(child: LocaleFlag(localeFlag('it'), size: 20)),
                ],
              ),
              _section('Invisible ink'),
              const _InkDemo(),
              const SizedBox(height: AppSpacing.xl),
              const _InkLinesDemo(),
              _section('Ink reveal'),
              const _InkRevealDemo(),
              const SizedBox(height: AppSpacing.xl),
              const _InkRevealPendingDemo(),
              _section('Reflections'),
              ReflectionHomeCard(
                reflection: Reflection(
                  weekStart: DateTime(2026, 7, 20),
                  generatedAt: DateTime.utc(2026, 7, 27),
                  text:
                      'The week kept circling back to the launch, and the launch held. '
                      'Between the late nights there was a gym visit that finally stuck '
                      'and a dinner that turned into a walk.',
                ),
                onTap: () {},
              ),
              const SizedBox(height: AppSpacing.lg),
              ReflectionHomeCard(
                reflection: Reflection(
                  weekStart: DateTime(2026, 7, 13),
                  generatedAt: DateTime.utc(2026, 7, 20),
                ),
                onTap: () {},
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                reflectionMetaLine(voiceLabel: 'Literary', writtenLabel: 'Written Jul 27'),
                style: AppType.footnote.copyWith(color: theme.textSecondary),
              ),
              _section('Reflection states'),
              const _ReflectionStatesDemo(),
              _section('Sheets'),
              AppButton(
                label: 'Message',
                variant: AppButtonVariant.secondary,
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (context) => const SheetMessage(
                    icon: AppIcons.globe,
                    title: 'Not available yet',
                    body:
                        'A body long enough to wrap onto a second line, the way a real '
                        'failure story reads.',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Message with retry',
                variant: AppButtonVariant.secondary,
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (context) => SheetMessage(
                    icon: AppIcons.icloud,
                    title: 'Couldn\'t download',
                    body: 'Check your connection and free space, then try again.',
                    action: AppButton(label: 'Retry', onPressed: () => Navigator.of(context).pop()),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Message with rows',
                variant: AppButtonVariant.secondary,
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (context) => SheetMessage(
                    icon: AppIcons.globe,
                    title: 'Language limit reached',
                    body: 'Remove one of these to make room.',
                    rows: [
                      for (final name in const ['English (US)', 'Deutsch (DE)'])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppType.subhead.copyWith(color: theme.text),
                                ),
                              ),
                              AppIcon(AppIcons.trash, size: 18, color: theme.danger),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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

/// The write-on the reflections pager runs: the text arrives as its own ink
/// and settles. Tap to replay (a fresh element restarts the reveal).
class _InkRevealDemo extends StatefulWidget {
  const _InkRevealDemo();

  @override
  State<_InkRevealDemo> createState() => _InkRevealDemoState();
}

class _InkRevealDemoState extends State<_InkRevealDemo> {
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Touchable(
      onTap: () => setState(() => _generation++),
      child: InkReveal(
        key: ValueKey(_generation),
        phase: InkPhase.write,
        color: theme.text,
        background: theme.background,
        child: Text(
          'Tap to replay. This paragraph writes itself the way a weekly '
          'reflection arrives: its own ink shimmers, holds a beat, then '
          'resolves into the words.',
          style: AppType.body.copyWith(color: theme.text, height: 1.45),
        ),
      ),
    );
  }
}

/// The pending state: the placeholder cloud a regenerate shimmers while the
/// model writes. It never resolves here; the pager's does when words land.
class _InkRevealPendingDemo extends StatelessWidget {
  const _InkRevealPendingDemo();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return InkReveal(
      phase: InkPhase.pending,
      color: theme.text,
      background: theme.background,
      placeholderLines: 3,
      child: const SizedBox.shrink(),
    );
  }
}

/// Tap to decompose the panel into dither dots and back: the disabled
/// notice's arrival, posed over the gallery's own background as the cover.
class _DitherRevealDemo extends StatefulWidget {
  const _DitherRevealDemo();

  @override
  State<_DitherRevealDemo> createState() => _DitherRevealDemoState();
}

class _DitherRevealDemoState extends State<_DitherRevealDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(vsync: this, value: 1);
  late final CurvedAnimation _wave = CurvedAnimation(parent: _reveal, curve: Curves.easeInOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reveal.duration = context.motionNow.ditherReveal;
  }

  void _toggle() {
    final show = _reveal.value <= 0.5;
    if (context.reduceMotion) {
      _reveal.value = show ? 1 : 0;
      return;
    }
    if (show) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Touchable(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, child) =>
            DitherReveal(progress: _wave.value, cover: theme.background, child: child!),
        child: Container(
          width: double.infinity,
          decoration: SuperellipseDecoration(
            color: theme.settings.cardBackground,
            borderRadius: AppRadius.card,
            border: BorderSide(color: theme.settings.cardBorder),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Tap to dissolve this panel into dither dots and summon it back, '
            'cell by cell up the Bayer ladder.',
            style: AppType.footnote.copyWith(color: theme.textSecondary, height: 1.4),
          ),
        ),
      ),
    );
  }
}

/// Every reflection state a page or the empty screen can land in, posed for
/// review with the real copy: the four empty-timeline editorials (tap to
/// cycle), the three week-page placeholders, the disabled notice card (toggle
/// to watch it dither in and out), and the transient regenerate failure.
class _ReflectionStatesDemo extends StatefulWidget {
  const _ReflectionStatesDemo();

  @override
  State<_ReflectionStatesDemo> createState() => _ReflectionStatesDemoState();
}

class _ReflectionStatesDemoState extends State<_ReflectionStatesDemo> {
  static const _editorials = <(String, bool, ReflectionAvailabilityStatus)>[
    ('First run', true, ReflectionAvailabilityStatus.available),
    ('Apple Intelligence off', false, ReflectionAvailabilityStatus.notEnabled),
    ('Model preparing', false, ReflectionAvailabilityStatus.modelNotReady),
    ('Unsupported device', false, ReflectionAvailabilityStatus.unsupported),
  ];

  static const _weeks = <(String, ReflectionWeekStatus)>[
    ('Quiet week', ReflectionWeekStatus.silent),
    ('Erased', ReflectionWeekStatus.erased),
    ('Waiting', ReflectionWeekStatus.unreflected),
  ];

  int _editorial = 0;
  bool _disabled = true;
  String? _notice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (editorialLabel, available, status) = _editorials[_editorial];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caption('Editorial: $editorialLabel (tap to cycle)'),
        Touchable(
          onTap: () => setState(() => _editorial = (_editorial + 1) % _editorials.length),
          child: ReflectionEditorialBody(
            copy: reflectionEditorialCopy(l10n, available: available, status: status),
          ),
        ),
        for (final (label, week) in _weeks) ...[
          const SizedBox(height: AppSpacing.xl),
          _Caption(label),
          _ReflectionWeekExample(status: week),
        ],
        const SizedBox(height: AppSpacing.xl),
        const _Caption('Disabled notice (toggle to dither in and out)'),
        AppButton(
          label: _disabled ? 'Enable reflections' : 'Disable reflections',
          variant: AppButtonVariant.secondary,
          onPressed: () => setState(() => _disabled = !_disabled),
        ),
        const SizedBox(height: AppSpacing.sm),
        ReflectionsDisabledSlot(
          disabled: _disabled,
          onEnable: () => setState(() => _disabled = false),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _Caption('Regenerate failure'),
        AppButton(
          label: 'Show failure notice',
          variant: AppButtonVariant.secondary,
          onPressed: () => setState(() => _notice = l10n.reflectionRegenerateFailed),
        ),
        AppNotice(message: _notice, onDismiss: () => setState(() => _notice = null)),
      ],
    );
  }
}

/// One week page's no-text placeholder, resolved from the shared state mapping
/// so the gallery shows exactly what the pager renders.
class _ReflectionWeekExample extends StatelessWidget {
  const _ReflectionWeekExample({required this.status});

  final ReflectionWeekStatus status;

  @override
  Widget build(BuildContext context) {
    final placeholder = reflectionWeekPlaceholder(AppLocalizations.of(context)!, status)!;
    return ReflectionWeekPlaceholder(
      title: placeholder.title,
      body: placeholder.body,
      marker: placeholder.marker,
    );
  }
}

/// A small monochrome label above a gallery example, naming the state being
/// posed. Debug-only, so it is deliberately not localized.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: AppType.footnote.copyWith(color: theme.textSecondary)),
    );
  }
}

/// The floating scrubber material over busy text, so the frost itself is what
/// the gallery shows: the paragraph must read through the capsule as glass.
class _GlassCapsuleDemo extends StatelessWidget {
  const _GlassCapsuleDemo();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scrubber = theme.scrubber;
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          'The capsule floats over reading text like this line and the next, '
          'and what sits beneath it stays legible through the frost rather '
          'than being cut off by a solid band.',
          style: AppType.body.copyWith(color: theme.textSecondary, height: 1.45),
        ),
        GlassCapsule(
          height: scrubber.height,
          tint: scrubber.tint,
          border: scrubber.border,
          sigma: scrubber.blurSigma,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            // Posed mid-flow, so the stream and both rim shrinks all show.
            child: ScrubberDots(count: 20, position: 9.4),
          ),
        ),
      ],
    );
  }
}
