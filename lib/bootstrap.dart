import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/logging/app_bloc_observer.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/logging_http_client.dart';
import 'core/logging/error_reporting.dart';
import 'core/offline/outbox.dart';
import 'core/offline/outbox_store.dart';
import 'core/offline/reconnects.dart';
import 'core/offline/snapshots.dart';
import 'core/supabase/secure_session_storage.dart';
import 'features/checkin/data/check_in_outbox.dart';
import 'features/incidents/data/incidents_outbox.dart';
import 'features/modules/data/module_outbox.dart';
import 'features/tasks/data/tasks_outbox.dart';
import 'features/notifications/data/push_service.dart';
import 'features/prayer_times/application/prayer_scheduler.dart';
import 'firebase_options.dart';

/// Result of app initialization, passed into the widget tree.
class AppDependencies {
  const AppDependencies({required this.prefs});
  final SharedPreferences prefs;
}

/// Brings Firebase up where there is a Firebase to bring up.
///
/// `firebase_options.dart` is generated per platform, and this project was
/// configured for Android — which is where the app ships and where push is
/// wanted. Every other platform's getter THROWS rather than returning null, so
/// running the same code on Chrome or Windows died at startup, before a single
/// screen: the whole app unavailable for want of notifications.
///
/// The app does not need Firebase to work. It needs it to be TOLD things while
/// closed. So a platform without options starts without it, and push is simply
/// off there — which [PushService] is told by there being no Firebase app at
/// all, rather than by a flag somebody has to remember to set.
///
/// Add a platform with `flutterfire configure`, and this starts working there
/// with nothing here to change.
Future<void> _initFirebaseIfConfigured() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on UnsupportedError {
    AppLogger.info('app', 'no Firebase for this platform — push is off');
  }
}

/// Brings the outbox up where there is somewhere to keep it.
///
/// Called after Supabase, because everything the queue sends goes through that
/// client; and before the first frame, because the badge in the app bar reads
/// it and a queue installed a moment later would show as empty for that moment.
///
/// It is allowed to FAIL, and the whole shape of this function is that
/// allowance. The queue needs a directory on a disk, and the web has neither —
/// `path_provider` has no implementation there and answers with a
/// `MissingPluginException`. Unguarded, that took the entire app down at
/// start-up on Chrome: a splash screen and nothing behind it, because a feature
/// for a phone in Mina could not find a folder in a browser.
///
/// The same reasoning as [_initFirebaseIfConfigured] one function up, and the
/// same conclusion. Where the queue cannot exist, it simply is not installed;
/// `sendOrQueue` already falls back to sending directly when there is no queue,
/// and the badge already draws nothing. Nothing else in the app has to know
/// which platform it is on.
///
/// Only `start()` is left unawaited: reading a small file and taking the first
/// run at what is in it is not something a splash screen should wait on, and
/// nothing on screen depends on the answer.
Future<void> _installOutbox() async {
  try {
    final outbox = Outbox(
      store: await OutboxStore.open(),
      reconnects: platformReconnects(),
    );
    ModuleOutbox.register(outbox);
    TasksOutbox.register(outbox);
    CheckInOutbox.register(outbox);
    IncidentsOutbox.register(outbox);
    Outbox.instance = outbox;
    unawaited(outbox.start());
  } catch (error) {
    // Info, one line, no stack — the same voice push uses two functions up,
    // and for the same reason. A platform having no disk is not a fault, and a
    // red twelve-line trace at every start-up on the web trains whoever is
    // reading the console to skip exactly the place real faults appear.
    AppLogger.info('app', 'no outbox on this platform — writes go straight out');
  }
}

/// Brings the saved-answers store up, on the same terms as the queue above.
///
/// The queue keeps what a man WROTE with no signal; this keeps what he last
/// READ, so the roster and his own list are still there when the network is
/// not. Same failure posture, same reason: the web has no directory to keep it
/// in, and a platform where saved answers cannot exist simply does not have
/// them — every read there is live, and no call site has to know which platform
/// it is on.
///
/// Before the first frame because the screens read it as they build; awaited
/// because it is one `mkdir`.
Future<void> _installSnapshots() async {
  try {
    Snapshots.instance = await Snapshots.open();
  } catch (error) {
    AppLogger.info('app', 'no saved answers on this platform — reads are live');
  }
}

/// Reads a required key out of `.env`, failing with a sentence that names the
/// key instead of the bare null-check error the `!` operator used to die with.
String _requireEnv(String key) {
  final value = dotenv.env[key];
  if (value == null || value.isEmpty) {
    throw StateError(
      '.env is missing $key — copy .env.example (or ask the team for the '
      'values) and rebuild; the file ships as a bundled asset.',
    );
  }
  return value;
}

/// Initializes env, Supabase, Firebase (messaging only) and shared prefs.
Future<AppDependencies> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Logging goes in first, so that a failure in everything below it is itself
  // logged rather than lost.
  installErrorLogging();
  Bloc.observer = const AppBlocObserver();
  AppLogger.info('app', 'starting — debug logging on');

  // Started here rather than further down, and started rather than awaited.
  //
  // Nothing below waits on it — it costs the first frame nothing wherever it
  // sits — but everything below it can now FAIL INTO it. A missing `.env`, a
  // Supabase key the server rejects, a keystore that will not open: these are
  // the start-up failures that leave a man in the field looking at a splash
  // screen, and until this line existed none of them left the device. What
  // happens before the attach lands is held by the reporter and sent when it
  // does; see [CrashReporting].
  //
  // Push is explicitly non-critical (see _initFirebaseIfConfigured) and its
  // platform-channel init was once holding the first frame hostage, which is
  // why PushService takes the future rather than the call.
  final firebaseInit = _initFirebaseIfConfigured();
  PushService.firebaseInit = firebaseInit;
  unawaited(firebaseInit.then((_) => CrashReporting.attach()));

  // Edge-to-edge with transparent system bars: the aurora backdrop runs behind
  // the status and navigation bars instead of stopping at a grey strip.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarDividerColor: Color(0x00000000),
    ),
  );

  await dotenv.load();
  final supabaseUrl = _requireEnv('SUPABASE_URL');
  final supabaseKey = _requireEnv('SUPABASE_ANON_KEY');

  // Prefs alongside Supabase: neither needs the other, and both are on the
  // path to the first frame.
  final prefsFuture = SharedPreferences.getInstance();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
    // The session — a live refresh token — goes to the platform keystore, not
    // the plaintext SharedPreferences file the library defaults to. Same key
    // name as the default so the first run migrates the existing session
    // instead of signing everyone out.
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(
        persistSessionKey:
            'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token',
      ),
    ),
    // Every query, auth call, upload and function invocation goes through this
    // one client, so the log covers them without a line at each call site. In
    // release the wrapper is not built at all.
    httpClient: kDebugMode ? LoggingHttpClient() : null,
    // Supabase's own chatter — token refreshes, realtime socket state — which
    // is not HTTP and would otherwise go unseen.
    debug: kDebugMode,
  );

  await _installOutbox();
  await _installSnapshots();

  final prefs = await prefsFuture;

  // Unawaited, and after the last thing the first frame depends on. The prayer
  // alarms sitting in Android's scheduler run out after a week and the times on
  // the home-screen widget go with them, so every start-up re-lays both —
  // which is a platform-channel round trip and a few dozen astronomy
  // calculations, and there is no reason for a splash screen to wait on it.
  unawaited(PrayerScheduler.instance.refresh());

  return AppDependencies(prefs: prefs);
}
