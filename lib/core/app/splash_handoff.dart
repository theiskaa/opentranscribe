import 'package:flutter/services.dart';

// Channel identifier. Must match SplashHandoffPlugin in WaveSplash.swift.
const _name = 'opentranscribe/splash';

/// Tells the native launch splash that home has painted, so its collapse
/// reveals a journal that is already there rather than the frames building it.
///
/// Preflight-safe: with no plugin behind it (a non-iOS host, a test harness, a
/// hot restart whose splash is long gone) [finish] is silent. The splash is
/// cosmetic and a failed hand-off must never break a launch; native carries its
/// own backstop for a Dart that never calls.
class SplashHandoff {
  SplashHandoff({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(_name);

  final MethodChannel _channel;

  Future<void> finish() async {
    try {
      await _channel.invokeMethod<void>('finish');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
