import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Whether a tap has been dealt with. A handler that returns false is saying
/// "not mine", and the next one is asked.
typedef NotificationTap = bool Function(String? payload);

/// The app's single [FlutterLocalNotificationsPlugin], and the one place it is
/// initialized.
///
/// `FlutterLocalNotificationsPlugin()` is a FACTORY over a static instance —
/// every `new` in this codebase hands back the same object, and `initialize`
/// keeps only the last `onDidReceiveNotificationResponse` it was given. So two
/// features each calling `initialize` with their own tap handler is not two
/// handlers: it is a race, and whichever ran second silently owns every tap in
/// the app. That is what this class exists to prevent.
///
/// Everything that shows a local notification — the foreground mirror of a push
/// message, and the prayer alarms — goes through here: one `initialize`, one
/// read of the launch details, and a chain of handlers asked in registration
/// order until one claims the payload.
class LocalNotifications {
  LocalNotifications._();
  static final instance = LocalNotifications._();

  /// The shared plugin. Callers use it for `show`, `zonedSchedule`, `cancel`
  /// and the platform-specific resolutions; they must NOT call `initialize`.
  final plugin = FlutterLocalNotificationsPlugin();

  final _handlers = <NotificationTap>[];

  Future<void>? _ready;

  /// The payload of the notification whose tap STARTED the app, held until
  /// somebody claims it.
  ///
  /// It cannot simply be dispatched at the end of [_init]: a cold start from a
  /// tap runs through here before the feature that owns that payload has
  /// necessarily registered, and a launch tap arriving at an empty chain is a
  /// deep link silently dropped. So it waits, and [onTap] offers it to each
  /// handler as it joins.
  String? _launch;
  bool _launchPending = false;

  /// Registers a tap handler, and offers it the launch payload if one is still
  /// unclaimed.
  void onTap(NotificationTap handler) {
    _handlers.add(handler);
    if (_launchPending && handler(_launch)) _clearLaunch();
  }

  /// Initializes the plugin once. Safe to call from anywhere, any number of
  /// times; concurrent callers await the same future.
  Future<void> ensureReady() => _ready ??= _init();

  Future<void> _init() async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Every request flag off: `FirebaseMessaging.requestPermission` in
        // PushService already raises the one iOS permission prompt there is,
        // and leaving these at their `true` default would race it — two calls
        // for the same authorization, at two different moments in startup.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _dispatch(response.payload),
    );

    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _launch = launch!.notificationResponse?.payload;
      _launchPending = true;
      if (_dispatch(_launch)) _clearLaunch();
    }
  }

  bool _dispatch(String? payload) {
    for (final handler in _handlers) {
      if (handler(payload)) return true;
    }
    return false;
  }

  void _clearLaunch() {
    _launch = null;
    _launchPending = false;
  }

  /// Where [ensureReady] may be called at all.
  ///
  /// Not a statement about the plugin, which covers more than this: it is that
  /// `initialize` THROWS on a platform whose settings are absent from the const
  /// above. So this list and that object are the same list, written twice, and
  /// a platform is added to both or to neither. Linux and Windows have neither.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
