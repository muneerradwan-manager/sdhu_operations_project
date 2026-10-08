import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/offline/reconnects.dart';
import 'core/settings/settings_cubit.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/aurora_background.dart';
import 'core/widgets/responsive.dart';
import 'features/auth/application/auth_cubit.dart';
import 'features/auth/application/session_cubit.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/saved_accounts_store.dart';
import 'features/incidents/application/incident_alarm.dart';
import 'features/incidents/presentation/widgets/incident_alarm_host.dart';
import 'features/notifications/data/push_service.dart';
import 'features/profile/data/profile_repository.dart';
import 'l10n/app_localizations.dart';

class HajjOperationsApp extends StatelessWidget {
  const HajjOperationsApp({super.key, required this.deps});

  final AppDependencies deps;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // The saved-accounts store is built here and reached through the
        // repository that owns it, rather than provided in its own right: it is
        // a Listenable, and `RepositoryProvider` refuses those outright — it
        // cannot rebuild on a change, so handing one out invites a screen that
        // reads the list once and never notices it grow. Whoever wants it takes
        // `auth.accounts` and listens to it deliberately.
        //
        // Read off the keystore as the app builds rather than in `bootstrap`:
        // the list only decides whether the login screen offers shortcuts, and
        // nothing should wait on a keystore to reach the first frame. It
        // notifies when it arrives, and the picker appears then.
        RepositoryProvider(
          create: (_) {
            final accounts = SavedAccountsStore();
            unawaited(accounts.load());
            return AuthRepository(accounts);
          },
        ),
        RepositoryProvider(create: (_) => ProfileRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit(deps.prefs)),
          BlocProvider(
            create: (context) => SessionCubit(
              context.read<AuthRepository>(),
              context.read<ProfileRepository>(),
              // The same hint the outbox drains on. A session restored from
              // disk goes and checks itself the second a radio associates,
              // rather than waiting for somebody to close the app.
              reconnects: platformReconnects(),
            ),
          ),
          BlocProvider(
            create: (context) => AuthCubit(context.read<AuthRepository>()),
          ),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final _router = buildRouter(context.read<SessionCubit>());

  @override
  void initState() {
    super.initState();
    PushService.instance.pendingTap.addListener(_deliverTap);
    _deliverTap();
    // The listener below only fires on a CHANGE, and a session restored from
    // disk can already be approved by the time this widget is built — in which
    // case nothing would ever have started the alarm.
    _syncAlarm(context.read<SessionCubit>().state);
  }

  @override
  void dispose() {
    PushService.instance.pendingTap.removeListener(_deliverTap);
    IncidentAlarm.instance.stop();
    super.dispose();
  }

  /// Turns the urgent-report alarm on for whoever is signed in, and off when
  /// nobody is.
  ///
  /// Tied to the SESSION rather than started once at boot, because what it
  /// listens to is one person's inbox: left running across an account switch it
  /// would be watching the previous user's stream, and the ids it had already
  /// dismissed would silence the new reader's emergencies. [IncidentAlarm.stop]
  /// clears both.
  void _syncAlarm(SessionState session) {
    if (session.status == SessionStatus.approved) {
      IncidentAlarm.instance.watch();
    } else {
      IncidentAlarm.instance.stop();
    }
  }

  /// Takes a notification tapped in the phone's tray to the inbox.
  ///
  /// Two things have to be true at once, and they do not arrive together. The
  /// tap can land before there is anybody signed in — a cold start from a tap
  /// begins at the splash with the session still resolving — and navigating
  /// then means navigating into a redirect that sends you back to the home
  /// page. So this runs on both: whenever a tap arrives, and whenever the
  /// session changes. Whichever is second is the one that does the work.
  ///
  /// The tap is deliberately NOT consumed here. The inbox takes it when it is
  /// on screen, and only then, because it is the inbox that knows how to open
  /// what the notification was about — and how to say so honestly when the file
  /// has since been deleted.
  ///
  /// It arrives via the HOME PAGE, and that is not a detour.
  ///
  /// `go` REPLACES the stack. Sent straight to the inbox, a cold start from a
  /// tap produced a single page with nothing underneath it — so the back
  /// gesture, the one every reader tries first, left the app entirely. Whoever
  /// was woken at 3am by an urgent report read it, pressed back, and was on
  /// their launcher: to get anywhere in the app they had to open it again.
  ///
  /// So the stack is built rather than jumped to: home, then the inbox on top
  /// of it. Back now means back, and the app the notification opened is the app
  /// they are left standing in.
  void _deliverTap() {
    if (!mounted) return;
    if (PushService.instance.pendingTap.value == null) return;
    if (context.read<SessionCubit>().state.status != SessionStatus.approved) {
      return;
    }
    _router.go(Routes.home);
    _router.push(Routes.notifications);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;

    return BlocListener<SessionCubit, SessionState>(
      listener: (_, session) {
        _deliverTap();
        _syncAlarm(session);
      },
      child: _app(settings),
    );
  }

  Widget _app(SettingsState settings) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(solid: settings.solidSurfaces),
      darkTheme: AppTheme.dark(solid: settings.solidSurfaces),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      // The animated backdrop lives above the navigator's own background and
      // below every route, so it survives page transitions without restarting.
      // The snack bar cap wraps it because it works by overriding the theme,
      // and everything that shows a snack bar is inside.
      //
      // The alarm host is outermost and draws nothing. It has to be above every
      // route for the same reason the backdrop is — an urgent report is not
      // something you have to be on the right screen to be told about — and it
      // is handed the router because a dialog opened from here has no Navigator
      // above it to open on.
      builder: (context, child) => IncidentAlarmHost(
        router: _router,
        child: SnackBarWidthCap(
          child: AuroraBackground(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
