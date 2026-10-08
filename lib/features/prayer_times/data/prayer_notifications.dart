import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/logging/app_logger.dart';
import '../../../core/notifications/local_notifications.dart';
import '../domain/prayer_schedule.dart';

/// The text one alarm carries. Built by the caller, which is the only layer
/// that knows what language this device is being read in.
class PrayerAlarmText {
  const PrayerAlarmText({required this.title, required this.body});

  final String title;
  final String body;
}

/// What stands between the reader and a prayer alert that actually arrives.
enum PrayerAlertReadiness {
  /// Everything is granted; alarms will land on the minute.
  ready,

  /// Notifications are allowed, but exact alarms are not — so Android is free
  /// to batch them, and الفجر may arrive several minutes late. Recoverable:
  /// see [PrayerNotifications.requestExactAlarms].
  inexact,

  /// The reader said no to notifications, or the system has them switched off
  /// for this app. Nothing will be shown at all.
  blocked,

  /// Not Android — nothing to schedule and nothing to fix.
  unsupported,
}

/// Lays the day's calls down as scheduled Android notifications.
///
/// The whole difficulty of this is that the app is NOT RUNNING when a prayer
/// comes in. There is no timer to rely on and no Dart to execute: every
/// occurrence has to be handed to the system's alarm service ahead of time,
/// individually, because a prayer is at a different clock time every day and
/// there is no "daily at 04:32" to repeat. So [apply] lays down a week at once
/// — see [PrayerSchedule.horizonDays] — and the week is re-laid every time the
/// app comes up.
class PrayerNotifications {
  PrayerNotifications._();
  static final instance = PrayerNotifications._();

  /// The call itself, with the phone's notification sound.
  static const channelCall = 'prayer_call';

  /// The same, muted. A separate CHANNEL and not a flag on the notification:
  /// Android freezes a channel's sound at the moment it is created and ignores
  /// every later change, so "silent" can only be a second channel — and this
  /// way the reader can also find both in the system settings and tune them
  /// there, which is where a person goes looking.
  static const channelQuiet = 'prayer_call_quiet';

  /// Marks a tap as belonging to this feature. Prayer notifications have
  /// nowhere in particular to go — opening the app is the whole of it — and
  /// this is what stops the inbox from claiming the tap and flinging the
  /// reader into a notification list that has nothing to do with الفجر.
  static const tapPayload = 'prayer-alert';

  /// Whether this platform can show a local notification at all.
  ///
  /// Pure: it touches neither the plugin nor the system, which is what makes it
  /// safe to ask on the way in, before the reader has opted into anything.
  /// [readiness] cannot answer this — it initializes the plugin first, and
  /// nothing may be asked of the system until the switch has been pressed.
  static bool get supported => LocalNotifications.supported;

  /// The alarms currently laid down, so that [apply] can tell what has to be
  /// cancelled without cancelling and re-adding the whole week each time.
  ///
  /// Not persisted: on a cold start it is empty, and [apply] falls back to
  /// asking the platform what is pending, which is the authority anyway.
  final _laid = <int>{};

  Future<void>? _ready;

  Future<void> _ensureReady() => _ready ??= _init();

  Future<void> _init() async {
    // Registered BEFORE the plugin comes up, so that a cold start from a tap on
    // الفجر finds this handler already in the chain. It claims the tap and does
    // nothing with it: opening the app IS the whole of what that tap meant, and
    // the point of claiming is to stop the inbox from taking it and throwing
    // the reader into a list of mission notifications instead.
    LocalNotifications.instance.onTap((payload) => payload == tapPayload);
    await LocalNotifications.instance.ensureReady();

    // Ten years of rules rather than the full database: a third of the size,
    // and this schedules a week ahead.
    tz_data.initializeTimeZones();
    // UTC deliberately, and it is not a shortcut. The platform is handed a wall
    // time plus a zone NAME, and resolves one against the other — so a zone of
    // UTC with the instant expressed in UTC names exactly the same moment as
    // the local zone with the local wall time, without this app having to ask
    // a plugin which IANA zone the phone is in and without being wrong when it
    // guesses. Every alarm here is an absolute instant on a fixed date, never
    // a repeating wall-clock rule, which is the one case where the distinction
    // would have mattered.
    tz.setLocalLocation(tz.UTC);
  }

  /// Asks for what is needed, in the order a person expects to be asked.
  ///
  /// Called from the settings switch and nowhere else: a permission dialog
  /// belongs one gesture after the sentence explaining what it is for.
  Future<PrayerAlertReadiness> request() async {
    if (!LocalNotifications.supported) return PrayerAlertReadiness.unsupported;
    await _ensureReady();

    final android = _android;
    if (android == null) return PrayerAlertReadiness.unsupported;

    final allowed =
        await android.requestNotificationsPermission() ??
        // Below Android 13 there is no dialog and nothing to grant; the
        // system-level switch is the only answer there is.
        await android.areNotificationsEnabled() ??
        false;
    if (!allowed) return PrayerAlertReadiness.blocked;

    return readiness();
  }

  /// What state things are in right now, without asking the reader anything.
  Future<PrayerAlertReadiness> readiness() async {
    if (!LocalNotifications.supported) return PrayerAlertReadiness.unsupported;
    await _ensureReady();

    final android = _android;
    if (android == null) return PrayerAlertReadiness.unsupported;

    if (!(await android.areNotificationsEnabled() ?? false)) {
      return PrayerAlertReadiness.blocked;
    }
    if (!(await android.canScheduleExactNotifications() ?? false)) {
      return PrayerAlertReadiness.inexact;
    }
    return PrayerAlertReadiness.ready;
  }

  /// Opens the system page where exact alarms are granted.
  ///
  /// Since Android 14 this is off by default for an app that is not a clock,
  /// and there is no in-app dialog for it — the reader is sent to a settings
  /// screen and comes back. Without it the alarms still fire, but batched:
  /// Android may hold them for several minutes, which is the difference
  /// between a call to prayer and a reminder that one has passed.
  Future<void> requestExactAlarms() async {
    await _ensureReady();
    await _android?.requestExactAlarmsPermission();
  }

  /// Replaces every prayer alarm with the given set.
  ///
  /// [text] is asked for one alarm at a time rather than handed over as a list,
  /// so that the caller's formatting runs only for the alarms that survive.
  Future<void> apply(
    List<PrayerAlarm> alarms, {
    required PrayerAlarmText Function(PrayerAlarm) text,
    required bool silent,
  }) async {
    if (!LocalNotifications.supported) return;
    await _ensureReady();

    try {
      await _cancelOurs();

      final exact = await _android?.canScheduleExactNotifications() ?? false;
      final details = NotificationDetails(android: _details(silent: silent));

      for (final alarm in alarms) {
        final words = text(alarm);
        await LocalNotifications.instance.plugin.zonedSchedule(
          id: alarm.id,
          title: words.title,
          body: words.body,
          scheduledDate: tz.TZDateTime.from(alarm.at, tz.UTC),
          notificationDetails: details,
          payload: tapPayload,
          // Exact where the reader has allowed it, and a best effort where they
          // have not — rather than refusing to schedule at all. A call that
          // arrives four minutes late is worth having; one that never arrives
          // because a permission was missing is a silent failure nobody can
          // see.
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
        _laid.add(alarm.id);
      }

      AppLogger.info('prayer', 'laid ${alarms.length} alarms, exact: $exact');
    } catch (e, s) {
      // A phone that has hit the system's alarm ceiling, a channel that would
      // not create, a platform channel that threw. None of it is worth taking
      // the app down for — the card still shows the times.
      AppLogger.error('prayer', 'could not schedule alarms', e, s);
    }
  }

  /// Drops every prayer alarm, leaving the rest of the tray alone.
  Future<void> cancelAll() async {
    if (!LocalNotifications.supported) return;
    await _ensureReady();
    await _cancelOurs();
  }

  /// Cancels only the ids in this feature's reserved block.
  ///
  /// `cancelAll()` on the plugin would take the mission's own notifications
  /// down with it — the inbox's messages sit in the same tray under ids this
  /// feature knows nothing about.
  Future<void> _cancelOurs() async {
    final plugin = LocalNotifications.instance.plugin;
    final ids = {..._laid};
    try {
      for (final pending in await plugin.pendingNotificationRequests()) {
        if (PrayerSchedule.owns(pending.id)) ids.add(pending.id);
      }
    } catch (_) {
      // Older or unusual implementations may refuse to list. The set we laid
      // down ourselves is then all we have, and it is right in every case
      // except a cold start — where the ids about to be re-laid overwrite the
      // old ones anyway, because they are computed the same way.
    }
    for (final id in ids) {
      await plugin.cancel(id: id);
    }
    _laid.clear();
  }

  AndroidNotificationDetails _details({required bool silent}) =>
      AndroidNotificationDetails(
        silent ? channelQuiet : channelCall,
        // The channel's name and description are what the reader sees in the
        // system's own settings, so they are the app's words, not an id.
        silent ? _quietName : _callName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        // Tells Android this is time-critical: it survives Do Not Disturb's
        // "alarms only" mode and is ordered above chatter in the shade.
        category: AndroidNotificationCategory.alarm,
        // A dedicated silhouette. The launcher icon put here comes out as a
        // white blob — Android takes the alpha channel of a small icon and
        // throws the colours away.
        icon: '@drawable/ic_stat_prayer',
        color: const Color(0xFF016D5D),
        playSound: !silent,
        autoCancel: true,
        // The sound is the channel's business, not the notification's — see
        // [channelQuiet]. `playSound` above is carried anyway for the platforms
        // and versions that still read it.
        channelAction: AndroidNotificationChannelAction.createIfNotExists,
      );

  // The channel labels. English here and not localized, on purpose: a
  // channel's name is fixed at creation and the system settings page keeps
  // showing whichever language it was first created in, so a reader who
  // switches the app to Arabic would find an Arabic name beside an English one
  // and no way to correct either. Neutral words, once.
  static const _callName = 'Prayer times';
  static const _quietName = 'Prayer times (silent)';
  static const _channelDescription =
      'The call to each prayer, and the '
      'reminder before it.';

  AndroidFlutterLocalNotificationsPlugin? get _android => LocalNotifications
      .instance
      .plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
}
