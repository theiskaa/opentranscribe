import 'package:flutter/widgets.dart';

/// Motion tokens. Themed so a theme can quiet the app, but the defaults are
/// the app's voice: one gentle entrance and ease-out feedback. Every token
/// here has a consumer; new motion earns its token when it lands. All motion
/// is one-shot and interruptible.
@immutable
final class AppMotion {
  const AppMotion({
    this.entrance = const Duration(milliseconds: 700),
    this.entranceCurve = const Cubic(0.22, 0.61, 0.36, 1),
    this.entranceRise = 18.0,
    this.stagger = const Duration(milliseconds: 120),
    this.press = const Duration(milliseconds: 150),
    this.pressScale = 0.96,
    this.pressIcon = const Duration(milliseconds: 120),
    this.pressIconScale = 0.92,
    this.indicator = const Duration(milliseconds: 250),
    this.indicatorCurve = Curves.easeOutCubic,
    this.crossfade = const Duration(milliseconds: 200),
    this.pageDash = const Duration(milliseconds: 200),
    this.digitRoll = const Duration(milliseconds: 200),
    this.rollStagger = const Duration(milliseconds: 30),
    this.subtitleRoll = const Duration(milliseconds: 120),
    this.weekSlide = const Duration(milliseconds: 300),
    this.dayGlide = const Duration(milliseconds: 320),
    this.dayGlideCurve = Curves.easeOutCubic,
    this.wordIn = const Duration(milliseconds: 180),
    this.wordStagger = const Duration(milliseconds: 30),
    this.wordRise = 4.0,
    this.lineShift = const Duration(milliseconds: 250),
    this.pullWave = const Duration(milliseconds: 1100),
    this.shimmer = const Duration(milliseconds: 1200),
    this.errorBlink = const Duration(milliseconds: 1000),
    this.swipeSpring = const SpringDescription(mass: 1, stiffness: 440, damping: 42),
    this.toggleSpring = const SpringDescription(mass: 1, stiffness: 600, damping: 49),
    this.swipePopCurve = const Cubic(0.34, 1.25, 0.64, 1),
    this.swipePopMinScale = 0.85,
    this.swipePopSpring = const SpringDescription(mass: 1, stiffness: 480, damping: 22),
  });

  final Duration entrance;
  final Curve entranceCurve;
  final double entranceRise;
  final Duration stagger;
  final Duration press;
  final double pressScale;
  final Duration pressIcon;
  final double pressIconScale;
  final Duration indicator;
  final Curve indicatorCurve;
  final Duration crossfade;

  /// The onboarding dash indicator's color and position glide.
  final Duration pageDash;

  /// One rolling character's travel in a RollingText.
  final Duration digitRoll;

  /// Delay between consecutive rolling characters: the wave that makes a
  /// multi character change read as one gesture.
  final Duration rollStagger;

  /// The bar subtitle's quick unified roll: quieter and faster than the
  /// title's staggered [digitRoll].
  final Duration subtitleRoll;

  /// The calendar strip paging to the viewed day's week as the scroll (or a
  /// manual swipe's return trip) moves across weeks.
  final Duration weekSlide;

  /// The list gliding to a tapped day's section, or home.
  final Duration dayGlide;
  final Curve dayGlideCurve;

  /// One live-transcript word arriving: a fade and a small rise.
  final Duration wordIn;

  /// Delay between consecutive arriving words, so a partial that lands several
  /// at once reads as a cascade rather than a block.
  final Duration wordStagger;
  final double wordRise;

  /// The live transcript lifting when a line rolls off the top.
  final Duration lineShift;

  /// One pass of the wave travelling across the armed pull hint. Slow enough to
  /// read as breathing rather than vibration, and it only runs while a finger
  /// is holding the gesture past its threshold.
  final Duration pullWave;

  /// One pass of the skeleton shimmer's highlight band across the placeholder,
  /// looped while a transcript is being produced. The one loop that carries no
  /// live signal, so it is slow enough to read as breathing, not a spinner.
  final Duration shimmer;

  /// One breath of the inline error indicator's dot, looped to draw the eye
  /// without a spinner or a shout. Slow, so it reads as a pulse, not a flash.
  final Duration errorBlink;

  /// A row's swipe-action reveal settling open or closed after the finger lifts.
  /// A spring, not a fixed curve, so the settle continues at the finger's release
  /// velocity - no seam between dragging and animating. Critically damped
  /// (damping = 2*sqrt(stiffness*mass)): a fast, no-bounce catch to the target.
  final SpringDescription swipeSpring;

  /// The drawn toggle's knob settling after a tap or a released drag, seeded
  /// with the fling velocity. Stiffer than [swipeSpring] (a 24px throw wants to
  /// feel crisp, not weighty); critically damped, so the knob catches the end
  /// without a wobble.
  final SpringDescription toggleSpring;

  /// A gentle overshoot used by pop-in reveals: the theme card selection, and the
  /// delete disc growing in from [swipePopMinScale] to full size as it enters.
  final Curve swipePopCurve;
  final double swipePopMinScale;

  /// The delete disc's slide-in from the right settling home: an UNDERDAMPED
  /// spring, so it lands with one soft overshoot (a bounce) on show and springs
  /// back off the edge on hide - one continuous motion, no slide-then-pop seam.
  /// On its own controller because it must overshoot, unlike [swipeSpring].
  final SpringDescription swipePopSpring;
}
