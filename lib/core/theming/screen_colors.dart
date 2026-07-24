import 'package:flutter/widgets.dart';

/// Per-screen background colors. Every screen reads its own token, never the
/// base `background` directly, so a user theme can tint a single screen.
/// All derive to the base background unless a theme overrides them.
@immutable
final class ScreenColors {
  const ScreenColors({
    required this.onboarding,
    required this.home,
    required this.recorder,
    required this.entryDetail,
    required this.settings,
  });

  final Color onboarding;
  final Color home;
  final Color recorder;
  final Color entryDetail;
  final Color settings;
}
