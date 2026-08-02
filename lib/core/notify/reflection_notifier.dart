import 'package:flutter/widgets.dart' show Locale;

import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

// The collaborators are private and named parameters cannot be, so initializing
// formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// The one reflection-aware piece of the notification stack: it decides WHEN
/// the weekly reflection nudge should exist and keeps the OS's pending
/// notification in step with the settings. The [NotificationScheduler] it
/// drives stays generic; the policy lives here.
///
/// The nudge is scheduled only when everything lines up - the on-device model
/// can run, reflections are enabled, the user turned the weekly notification
/// on, and permission is granted - and cancelled the instant any of those stops
/// holding. [sync] is the single entry point: call it after any of those inputs
/// could have changed (a settings toggle, a catch-up, a resume).
class ReflectionNotifier {
  ReflectionNotifier({
    required NotificationScheduler scheduler,
    required NotificationSettings notifySettings,
    required ReflectionSettings reflectionSettings,
    required Future<ReflectionAvailability> Function() availability,
    required String Function() language,
    DateTime Function()? clock,
  }) : _scheduler = scheduler,
       _notifySettings = notifySettings,
       _reflectionSettings = reflectionSettings,
       _availability = availability,
       _language = language,
       _clock = clock ?? DateTime.now;

  final NotificationScheduler _scheduler;
  final NotificationSettings _notifySettings;
  final ReflectionSettings _reflectionSettings;
  final Future<ReflectionAvailability> Function() _availability;
  final String Function() _language;
  final DateTime Function() _clock;

  /// The weekly reflection nudge's identity: the scheduler's fixed notification
  /// identifier (a reschedule under it replaces rather than stacks) and the key
  /// its enabled flag and fire time persist under. Public so the settings
  /// surface reads and writes the same slot this notifier schedules from.
  static const key = 'reflect.weekly';

  bool _running = false;
  bool _pending = false;

  /// Reconciles the OS's pending nudge with the current settings. Cheap and
  /// safe to call often; never throws (the scheduler swallows its own errors,
  /// and the strings fall back to English).
  ///
  /// Serialized: it is fired unawaited from several triggers (launch, resume, a
  /// settings toggle), and two interleaving runs could otherwise leave a stale
  /// pending nudge. A run requested while one is in flight is coalesced into one
  /// trailing pass, so the last-written settings always win.
  Future<void> sync() async {
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      do {
        _pending = false;
        await _reconcile();
      } while (_pending);
    } finally {
      _running = false;
    }
  }

  Future<void> _reconcile() async {
    // The cheap local gates first: they rule out most cancels without an async
    // hop, and leave only the genuinely-schedule case to probe for.
    if (!_shouldSchedule) {
      await _scheduler.cancel(key);
      return;
    }
    if (await _scheduler.permissionStatus() != NotificationPermission.authorized) {
      await _scheduler.cancel(key);
      return;
    }
    // Availability last: never nudge a device that produces nothing. Probed
    // live, so enabling the model mid-life is picked up on the next sync.
    if (!(await _availability()).isAvailable) {
      await _scheduler.cancel(key);
      return;
    }
    // Re-read the cheap gates after the awaits: a toggle that landed while they
    // were in flight must win, not schedule a nudge the user just turned off.
    if (!_shouldSchedule) {
      await _scheduler.cancel(key);
      return;
    }
    final strings = _strings;
    await _scheduler.scheduleWeekly(
      id: key,
      weekday: _boundaryWeekday(),
      hour: _notifySettings.hour(key),
      minute: _notifySettings.minute(key),
      title: strings.notifyWeeklyTitle,
      body: strings.notifyWeeklyBody,
    );
  }

  bool get _shouldSchedule => _notifySettings.enabled(key) && _reflectionSettings.enabled;

  /// The week's first day as a DateTime weekday (1=Mon..7=Sun), resolved from
  /// the app language so the nudge lands on the same boundary the week strip and
  /// the reflection bucketing use. A language change that shifts the first-day
  /// moves the nudge on the next [sync].
  int _boundaryWeekday() => startOfWeek(dateOnly(_clock()), localeId: _language()).weekday;

  /// The generic notification strings in the app language. Resolved off the UI
  /// tree (this runs on launch and resume, with no BuildContext) via the
  /// generated lookup. The strings are generic by contract and never carry
  /// reflection text. An unsupported or corrupt language code falls back to
  /// English rather than throwing, so [sync] keeps its never-throws guarantee.
  AppLocalizations get _strings {
    try {
      return lookupAppLocalizations(Locale(_language()));
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }
}
