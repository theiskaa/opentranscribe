import 'package:flutter/widgets.dart' show Locale;

import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:reflections/reflections.dart';

// The collaborators are private and named parameters cannot be, so initializing
// formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// The one reflection-aware piece of the notification stack: it decides WHEN
/// each period's reflection nudge should exist and keeps the OS's pending
/// notifications in step with the settings. The [NotificationScheduler] it
/// drives stays generic; the policy lives here.
///
/// A period's nudge is scheduled only when everything lines up - the on-device
/// model can run, that period's reflections are enabled, the reminders master
/// and the period's own selection are on, and permission is granted - and
/// cancelled the instant any of those stops holding. [sync] is the single
/// entry point: call it after any of those inputs could have changed (a
/// settings toggle, a catch-up, a resume).
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

  /// A period's nudge identity: the scheduler's notification identifier (a
  /// reschedule under it replaces rather than stacks) and the key its enabled
  /// flag persists under. Public so the settings surface reads and writes the
  /// same slots this notifier schedules from.
  static String keyFor(ReflectionPeriod period) => 'reflect.${period.wire}';

  /// The one fire time shared by every period's nudge. A single slot on
  /// purpose: the nudges differ in WHICH day they fire, not when in the day,
  /// and one Time row is a calmer surface than three.
  static const timeKey = 'reflect';

  /// The reminders master switch, persisted under [timeKey] beside the shared
  /// time. Unset (an install predating the switch) falls back to whether any
  /// period's nudge was stored on, so old intents keep firing untouched.
  static bool masterEnabled(NotificationSettings settings) =>
      settings.enabledOrNull(timeKey) ??
      ReflectionPeriod.values.any((p) => settings.enabled(keyFor(p)));

  /// Whether [period]'s nudge is selected under the master. A lone enabled
  /// period needs no selection of its own - the settings surface hides the
  /// picker and the master alone governs it - so it counts as selected
  /// whatever an earlier multi-period mix stored. Derived, not migrated:
  /// disabling the other periods elsewhere can never strand the master on
  /// top of an invisibly deselected survivor.
  static bool selectedFor(
    ReflectionPeriod period,
    NotificationSettings notifySettings,
    ReflectionSettings reflectionSettings,
  ) {
    if (notifySettings.enabled(keyFor(period))) return true;
    final shown = ReflectionPeriod.values.where(reflectionSettings.enabledFor);
    return shown.length == 1 && shown.single == period;
  }

  bool _running = false;
  bool _pending = false;

  /// Reconciles the OS's pending nudges with the current settings. Cheap and
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
    // The cheap local gate first: it rules out most cancels without an async
    // hop, and leaves only the genuinely-schedule case to probe for.
    if (!ReflectionPeriod.values.any(_shouldSchedule)) {
      await _cancelAll();
      return;
    }
    if (await _scheduler.permissionStatus() != NotificationPermission.authorized) {
      await _cancelAll();
      return;
    }
    // Availability last: never nudge a device that produces nothing. Probed
    // live, so enabling the model mid-life is picked up on the next sync.
    if (!(await _availability()).isAvailable) {
      await _cancelAll();
      return;
    }
    final strings = _strings;
    for (final period in ReflectionPeriod.values) {
      // Re-read the cheap gate after the awaits: a toggle that landed while
      // they were in flight must win, not schedule a nudge the user just
      // turned off.
      if (_shouldSchedule(period)) {
        await _schedule(period, strings);
      } else {
        await _scheduler.cancel(keyFor(period));
      }
    }
  }

  bool _shouldSchedule(ReflectionPeriod period) =>
      masterEnabled(_notifySettings) &&
      _reflectionSettings.enabledFor(period) &&
      selectedFor(period, _notifySettings, _reflectionSettings);

  /// Cancelling an id with nothing pending is a native no-op, so a blanket
  /// cancel is the simplest way to hold the "cancelled the instant any gate
  /// stops holding" guarantee for every period at once.
  Future<void> _cancelAll() async {
    for (final period in ReflectionPeriod.values) {
      await _scheduler.cancel(keyFor(period));
    }
  }

  /// A period's trigger mirrors when its reflection becomes readable: daily
  /// fires every day (yesterday closed at midnight), weekly on the locale's
  /// week boundary, monthly on the 1st (the only day every month has).
  Future<void> _schedule(ReflectionPeriod period, AppLocalizations strings) {
    final key = keyFor(period);
    final hour = _notifySettings.hour(timeKey);
    final minute = _notifySettings.minute(timeKey);
    return switch (period) {
      ReflectionPeriod.daily => _scheduler.scheduleDaily(
        id: key,
        hour: hour,
        minute: minute,
        title: strings.notifyDailyTitle,
        body: strings.notifyDailyBody,
      ),
      ReflectionPeriod.weekly => _scheduler.scheduleWeekly(
        id: key,
        weekday: _boundaryWeekday(),
        hour: hour,
        minute: minute,
        title: strings.notifyWeeklyTitle,
        body: strings.notifyWeeklyBody,
      ),
      ReflectionPeriod.monthly => _scheduler.scheduleMonthly(
        id: key,
        day: 1,
        hour: hour,
        minute: minute,
        title: strings.notifyMonthlyTitle,
        body: strings.notifyMonthlyBody,
      ),
    };
  }

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
