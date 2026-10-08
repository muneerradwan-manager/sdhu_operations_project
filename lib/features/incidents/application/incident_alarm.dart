import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/data/push_service.dart';
import '../../notifications/domain/app_notification.dart';

/// One urgent report, as the thing that has to be put in front of somebody.
@immutable
class IncidentAlert {
  const IncidentAlert({required this.key, required this.title, this.body});

  /// The incident's id where the payload carried one, else the notification's.
  /// What makes the same emergency arriving twice — once down the Realtime
  /// socket, once as a foreground push — one alarm rather than two.
  final String key;

  final String title;
  final String? body;

  @override
  bool operator ==(Object other) => other is IncidentAlert && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// The thing that makes the room LOOK UP.
///
/// 0088 delivered urgent reports as notifications: a row in the inbox, a line
/// in the phone's tray, and on Android an alarm-category channel so the tray
/// entry at least makes a noise. That is right for a phone in a pocket and
/// completely wrong for the case this is actually for — the operations room,
/// where the app is OPEN on a screen somebody is not looking at. A banner
/// sliding in over the top of a list and sliding out again is, in that room, an
/// emergency nobody saw.
///
/// So an urgent report now also stops the app: a dialog nothing gets past, and
/// a looping alarm tone on the alarm stream (see [AlarmSoundBridge]) until
/// somebody presses the button. It is deliberately the most intrusive thing in
/// this application, and there is exactly one kind of message allowed to do it.
///
/// **Two sources, because neither one covers the whole case.**
///
///   * The Realtime stream of the reader's own inbox. This is the one that
///     works everywhere — on Windows, where there is no Firebase at all, and on
///     an Android build whose push registration failed quietly.
///   * The foreground push, handed over by [PushService]. This is the one that
///     is fast, and the one that still arrives when the Realtime socket has
///     dropped and not yet noticed.
///
/// Both feed [pending], and [IncidentAlert] is keyed on the incident, so an
/// emergency that arrives down both paths — the normal case on a working
/// Android phone — rings once.
class IncidentAlarm {
  IncidentAlarm._();
  static final instance = IncidentAlarm._();

  final _repo = NotificationsRepository();

  /// The alarms waiting to be acknowledged, oldest first.
  ///
  /// A LIST rather than a single value because emergencies arrive in threes:
  /// one bus breaks down and four people report it inside a minute. Replacing
  /// the value would have swapped the dialog's text under the reader's thumb
  /// mid-press. They queue instead, and the dialog says how many are behind it.
  final pending = ValueNotifier<List<IncidentAlert>>(const []);

  StreamSubscription<List<AppNotification>>? _sub;

  /// Every key already raised, dismissed or deliberately ignored. Nothing in
  /// here rings again.
  final _seen = <String>{};

  /// How recent an unread report has to be to still be worth an alarm when the
  /// app is opened or the socket reconnects.
  ///
  /// It exists because the Realtime stream's FIRST emission is a snapshot of
  /// the whole inbox, not a change: without a window, signing in on Thursday
  /// would set off an alarm for every emergency of the week at once. Without
  /// ANY replay, though, a man whose app was killed and who reopens it four
  /// minutes into a live emergency would find the register silent — and that is
  /// the exact moment this feature is for.
  ///
  /// Quarter of an hour is the compromise: comfortably longer than a phone
  /// takes to come back, comfortably shorter than the life of an incident
  /// somebody has already dealt with.
  static const _freshFor = Duration(minutes: 15);

  /// Starts watching. Safe to call repeatedly — a second call while already
  /// watching does nothing, which matters because the session cubit emits more
  /// often than it changes.
  void watch() {
    if (_sub != null) return;
    _sub = _repo.streamMine().listen(
      _onInbox,
      onError: (Object e) => AppLogger.warn('alarm', 'inbox stream: $e'),
    );
  }

  /// Stops, and forgets what it has seen.
  ///
  /// Called on sign-out. The `_seen` set has to go with it: the next person to
  /// use this device is a different inbox, and an id this one had already
  /// dismissed must not silence theirs.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _seen.clear();
    pending.value = const [];
  }

  void _onInbox(List<AppNotification> inbox) {
    final now = DateTime.now();
    final fresh = <IncidentAlert>[];

    for (final n in inbox) {
      if (n.data['type'] != PushService.incidentType) continue;
      final key = switch (n.data['incident_id']) {
        final String id when id.isNotEmpty => id,
        _ => n.id,
      };
      if (!_seen.add(key)) continue;
      // Marked seen above whatever happens next, so an old report is passed
      // over exactly once rather than re-examined on every emission.
      if (n.isRead) continue;
      if (now.difference(n.createdAt) > _freshFor) continue;
      fresh.add(IncidentAlert(key: key, title: n.title, body: n.body));
    }

    if (fresh.isEmpty) return;
    // Reversed, because [streamMine] hands the inbox back newest first and the
    // register's order is the opposite on purpose: the emergency that has been
    // waiting longest is the one the reader should be shown first.
    pending.value = [...pending.value, ...fresh.reversed];
  }

  /// A foreground push, offered by [PushService].
  ///
  /// Nothing is checked about freshness here and nothing needs to be: a push
  /// that has just been delivered IS new, by definition.
  void raiseFromPush({
    required String key,
    required String title,
    String? body,
  }) {
    if (_sub == null) return;
    if (!_seen.add(key)) return;
    pending.value = [...pending.value, IncidentAlert(key: key, title: title, body: body)];
  }

  /// Acknowledged. Everything waiting goes at once — the reader has been shown
  /// the count and is being sent to the register, where all of them are.
  void clear() => pending.value = const [];
}
