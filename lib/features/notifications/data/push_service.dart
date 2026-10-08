import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/notifications/local_notifications.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../incidents/application/incident_alarm.dart';
import 'notifications_repository.dart';

/// What a tapped notification carried, as keys this app can act on.
///
/// FCM hands `data` back as strings on one platform and as whatever it was
/// given on the other, and a payload written by anything other than this app —
/// a test send from the Firebase console, say — can hold nulls or nested maps.
/// All of it becomes strings here, and an absent payload becomes an empty map
/// rather than null: a notification with no target is still a notification that
/// was tapped, and the inbox is where it should land.
Map<String, String> tapPayload(Map<String, dynamic>? data) => {
  for (final e in (data ?? const <String, dynamic>{}).entries)
    if (e.value != null && e.value is! Map && e.value is! List)
      e.key: e.value.toString(),
};

/// Registers this device's FCM token for the signed-in user and surfaces
/// foreground push messages as local notifications.
class PushService {
  PushService._();
  static final instance = PushService._();

  /// Shared with the prayer alarms. See [LocalNotifications] for why this is
  /// not a plugin instance of its own — there is no such thing.
  final _local = LocalNotifications.instance;

  bool _started = false;
  Future<void>? _starting;

  /// Firebase's own initialization, handed over by [bootstrap]. It was taken
  /// off the startup critical path — push is not worth holding the first frame
  /// for — so anything here that talks to Firebase awaits this first, and
  /// nothing races the app coming up.
  static Future<void>? firebaseInit;

  /// A notification tapped in the phone's own tray, waiting to be acted on.
  ///
  /// It is held rather than acted on here because there may be nowhere to go
  /// yet. A tap on a notification for an app that is not running launches it
  /// cold: at the moment this is set there is no session, no router, and the
  /// only screen is the splash. Navigating then is navigating into a redirect
  /// that sends you straight back to the home page — which looked exactly like
  /// the deep link being ignored, because it was.
  ///
  /// So the tap waits here until somebody is signed in and can be shown it. See
  /// `_AppViewState._deliverTap`, which watches both this and the session.
  final pendingTap = ValueNotifier<Map<String, String>?>(null);

  /// Takes the waiting tap, leaving nothing behind. Called by the inbox once it
  /// is on screen and able to open what the tap was about — a second read must
  /// not reopen it, or coming back to the inbox would fling you into the file
  /// again.
  Map<String, String>? takePendingTap() {
    final tap = pendingTap.value;
    pendingTap.value = null;
    return tap;
  }

  void _tapped(Map<String, dynamic>? data) =>
      pendingTap.value = tapPayload(data);

  static const _channel = AndroidNotificationChannel(
    'general',
    'General',
    description: 'General notifications',
    importance: Importance.high,
  );

  /// The alarm channel, and the reason it is separate from [_channel].
  ///
  /// An urgent report (0088) and a routine posting are the same object to
  /// Android unless they are told apart here, and one channel means they can
  /// only ever be silenced together. A man who mutes the app because it tells
  /// him about every circular has also muted the bus on the road to Arafat.
  ///
  /// So: its own channel, `Importance.max` — which is what makes Android put
  /// the notification on screen rather than in the shade — and
  /// [AndroidNotificationCategory.alarm], which carries it through Do Not
  /// Disturb's "alarms only". The prayer alarms reach for the same category two
  /// files away, for the same reason.
  ///
  /// Created at start-up rather than on first use. A channel is only made when
  /// the app runs, and the message this one carries is precisely the one that
  /// arrives when the app is NOT running — so the first alarm would land on a
  /// channel that does not exist yet, and Android would file it under
  /// Miscellaneous with the sound off.
  ///
  /// English name, deliberately, and the same argument as the prayer channels:
  /// a channel's name is fixed at creation, so a reader who later switches the
  /// app's language would find the old name frozen in the system settings with
  /// no way to correct it.
  static const _urgentChannel = AndroidNotificationChannel(
    'incidents',
    'Urgent reports',
    description: 'Emergencies raised from the field. Do not silence.',
    importance: Importance.max,
  );

  /// The value of `data.type` that makes a push an emergency. One spelling,
  /// used by the payload `raise_incident` writes, by the Edge Function that
  /// picks the channel, and by the foreground mirror below — three places that
  /// must agree, and now cannot drift.
  static const incidentType = 'incident';

  /// Whether there is a Firebase to talk to at all.
  ///
  /// False on a platform this project was never configured for — the app runs
  /// there, it simply cannot be told anything while closed. Asked of Firebase
  /// itself rather than kept as a flag, so it cannot fall out of step with what
  /// [bootstrap] actually managed to start.
  bool get _available => Firebase.apps.isNotEmpty;

  /// Call once the user is approved. Safe to call repeatedly, and never
  /// throws: it is fired unawaited from the session cubit, and push failing is
  /// not worth an unhandled zone error.
  Future<void> start() async {
    try {
      await firebaseInit;
      if (!_available) return;
      if (_started) {
        // Topics as well as the token. A second call to `start` means the
        // session has changed under it — an account switch, which mutes this
        // device on the way out — and a device that registered its token but
        // subscribed to nothing is a device that goes quiet for the person now
        // using it.
        await _upsertToken();
        await syncTopics();
        return;
      }
      // An in-flight future rather than flipping `_started` up front: set
      // before the awaited init, one thrown exception (a permission dialog
      // gone wrong, a plugin hiccup) left every later call taking the
      // already-started fast path against a plugin that was never initialized
      // — foreground notifications silently off for the rest of the process.
      // This way concurrent callers still coalesce, but a failure clears the
      // way for the next attempt.
      await (_starting ??= _initialize().whenComplete(
        () => _starting = null,
      ));
    } catch (e) {
      AppLogger.warn('push', 'start failed: $e');
    }
  }

  Future<void> _initialize() async {
    await FirebaseMessaging.instance.requestPermission();

    // The notification raised while the app is in front is a LOCAL one, shown
    // by this service rather than by the system, so Firebase never hears it
    // being tapped. Without this it was the one notification in the app that
    // did nothing at all when pressed.
    //
    // Registered BEFORE `ensureReady` so that a cold start from a tap finds
    // this handler already in the chain — see [LocalNotifications.onTap].
    _local.onTap(_claimTap);
    await _local.ensureReady();

    final android = _local.plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_channel);
    await android?.createNotificationChannel(_urgentChannel);

    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _upsertToken());

    // The other ways a notification gets tapped, and all of them were missing
    // at one point: without these, tapping one raised the app onto whatever
    // screen it had been left on, which is indistinguishable from the tap
    // having done nothing.
    //
    //   * the app was in the background and is being brought forward;
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _tapped(m.data));
    //   * the app was not running at all and a FIREBASE-shown notification's
    //     tap started it. The message is delivered once, to whoever asks
    //     first, so it is asked for here and parked until there is a session;
    final launch = await FirebaseMessaging.instance.getInitialMessage();
    if (launch != null) _tapped(launch.data);
    //   * the app was not running at all and a LOCAL notification's tap
    //     started it — one this service showed while foregrounded, tapped
    //     after the app was later killed. Firebase never heard of it, and it is
    //     [LocalNotifications] that holds that payload until the handler
    //     registered above claims it, which happens inside `ensureReady`.

    // Only now, with everything above it done: a failure anywhere before this
    // line leaves the service unstarted, so the next `start()` tries again.
    _started = true;

    await _upsertToken();
    await syncTopics();
  }

  /// A tap on a local notification, offered to this service first.
  ///
  /// Only the ones this service wrote are claimed, and it knows them by their
  /// shape: a push payload is `jsonEncode(message.data)`, always a JSON object.
  /// Anything else belongs to somebody else — the prayer alarms write a bare
  /// marker string — and declining it is what lets that tap reach its owner
  /// instead of dumping the reader in an inbox that has nothing to do with it.
  bool _claimTap(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic>) return false;
      _tapped(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  static const _prefsKey = 'fcm_topics';

  /// Brings this device's subscriptions in line with what the user is actually
  /// part of: the whole mission, plus every file they hold a role in.
  ///
  /// The previous set is remembered on the device because FCM will not tell us
  /// what it is subscribed to — without that record, a member removed from a
  /// file would go on receiving that file's messages forever.
  Future<void> syncTopics() async {
    await firebaseInit;
    if (!_available) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getStringList(_prefsKey)?.toSet() ?? <String>{};

      final wanted = <String>{PushTopics.all};
      for (final id in await _myModuleIds(uid)) {
        wanted.add(PushTopics.module(id));
      }

      for (final topic in wanted.difference(previous)) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      }
      for (final topic in previous.difference(wanted)) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }

      await prefs.setStringList(_prefsKey, wanted.toList());
      AppLogger.info('push', 'topics: ${wanted.join(', ')}');
    } catch (e) {
      AppLogger.warn('push', 'topic sync failed: $e');
    }
  }

  /// Every file this person holds a role in — on the file itself or anywhere in
  /// its tree. RLS already limits both tables to what they may see.
  Future<Set<String>> _myModuleIds(String uid) async {
    final direct = await supabase
        .from('module_members')
        .select('module_id')
        .eq('profile_id', uid);
    final viaNodes = await supabase
        .from('module_node_members')
        .select('module_nodes(module_id)')
        .eq('profile_id', uid);

    return {
      for (final r in (direct as List).cast<Map<String, dynamic>>())
        r['module_id'] as String,
      for (final r in (viaNodes as List).cast<Map<String, dynamic>>())
        if (r['module_nodes'] case final Map node) node['module_id'] as String,
    };
  }

  /// Stops delivery to this device: no topics, and no token to send to. The
  /// inbox is untouched — the messages still arrive, the phone just stays quiet.
  Future<void> mute() async {
    await firebaseInit;
    if (!_available) return;
    await forgetTopics();
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await supabase
          .from('device_tokens')
          .delete()
          .eq('user_id', uid)
          .eq('token', token);
    } catch (_) {
      // Best effort; the topics are already gone, which is most of it.
    }
  }

  /// Drops every subscription. Called on sign-out, so the next person to use
  /// this device does not receive the last one's files.
  Future<void> forgetTopics() async {
    await firebaseInit;
    if (!_available) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final topic in prefs.getStringList(_prefsKey) ?? const <String>[]) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }
      await prefs.remove(_prefsKey);
    } catch (_) {
      // Best effort: a stale subscription is not worth blocking sign-out.
    }
  }

  Future<void> _upsertToken() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await supabase.from('device_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (_) {
      // Non-fatal — the in-app inbox still works without push.
    }
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    // The foreground mirror has to make the same choice the server made for the
    // background case, off the same key — otherwise an emergency that arrives
    // while the app happens to be open is the one that comes in quietly.
    final urgent = message.data['type'] == incidentType;
    final channel = urgent ? _urgentChannel : _channel;

    // And a tray entry is not enough for this one. The app being in FRONT is
    // exactly the case the notification handles worst — a banner slides in over
    // a list and slides out again, and in an operations room, where the app is
    // open on a screen nobody is looking at, that is an emergency nobody saw.
    // So it also goes to [IncidentAlarm], which stops the app with a dialog and
    // an alarm tone. It is keyed on the incident, so this and the Realtime
    // stream delivering the same report ring once between them.
    if (urgent) {
      IncidentAlarm.instance.raiseFromPush(
        key: switch (message.data['incident_id']) {
          final String id when id.isNotEmpty => id,
          _ => message.messageId ?? '${n.title}${n.body}',
        },
        title: n.title ?? '',
        body: n.body,
      );
    }
    _local.plugin.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: urgent ? Importance.max : Importance.high,
          priority: urgent ? Priority.max : Priority.high,
          category: urgent ? AndroidNotificationCategory.alarm : null,
        ),
      ),
      // What the push was about, carried across so that this notification can
      // be tapped for the same effect as the one the system would have shown.
      payload: jsonEncode(message.data),
    );
  }
}
