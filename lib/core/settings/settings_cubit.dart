import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bloc/safe_cubit.dart';
import '../../features/notifications/data/push_service.dart';
import '../../features/prayer_times/application/prayer_scheduler.dart';

class SettingsState extends Equatable {
  const SettingsState({
    required this.themeMode,
    required this.locale,
    this.notificationsEnabled = true,
    this.solidSurfaces = false,
    this.sidebarExpanded = true,
  });

  final ThemeMode themeMode;

  /// null => follow the device locale.
  final Locale? locale;

  /// Whether this device wants push at all. The in-app inbox is unaffected —
  /// turning it off stops the phone buzzing, it does not stop being told.
  final bool notificationsEnabled;

  /// Take the glass out: opaque panes, no blur, heavier hairlines.
  ///
  /// One switch answering two complaints that share a fix. Outdoors in ذو
  /// الحجة a translucent pane spends contrast the eye has already lost to
  /// glare; and every blur is a save-layer the compositor re-reads each frame,
  /// which on the handsets field staff actually carry is where the frame
  /// budget goes.
  ///
  /// Per DEVICE rather than per account, like the theme and the language beside
  /// it: it is about the screen in this man's hand and the sun on it, not about
  /// who he is. The same person on a desk indoors wants it off.
  final bool solidSurfaces;

  /// Whether the rail stands open with its labels showing, or folded to a
  /// column of icons. Kept across sessions: somebody who folds it, switches
  /// away for a week and comes back should find it folded, not reset.
  final bool sidebarExpanded;

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    bool? notificationsEnabled,
    bool? solidSurfaces,
    bool? sidebarExpanded,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : (locale ?? this.locale),
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      solidSurfaces: solidSurfaces ?? this.solidSurfaces,
      sidebarExpanded: sidebarExpanded ?? this.sidebarExpanded,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    locale,
    notificationsEnabled,
    solidSurfaces,
    sidebarExpanded,
  ];
}

/// Persists appearance + language choices.
class SettingsCubit extends SafeCubit<SettingsState> {
  SettingsCubit(this._prefs)
    : super(
        SettingsState(
          themeMode: _readThemeMode(_prefs),
          locale: _readLocale(_prefs),
          notificationsEnabled: _prefs.getBool(_kNotifications) ?? true,
          solidSurfaces: _prefs.getBool(_kSolidSurfaces) ?? false,
          sidebarExpanded: _prefs.getBool(_kSidebarExpanded) ?? true,
        ),
      );

  final SharedPreferences _prefs;

  static const _kTheme = 'settings.themeMode';
  static const _kSolidSurfaces = 'settings.solidSurfaces';
  static const _kSidebarExpanded = 'settings.sidebarExpanded';

  /// Public because the prayer scheduler reads it too: a notification raised
  /// while the app is closed has no cubit to ask what language to speak, and
  /// the choice made here is the one it must honour.
  static const localeKey = 'settings.locale';

  static const _kNotifications = 'settings.notifications';

  /// Written when somebody chooses "follow the system", so that choosing it is
  /// distinguishable from never having chosen at all.
  ///
  /// It used to be stored by REMOVING the key, which was fine while "nothing
  /// stored" and "follow the system" meant the same thing. They no longer do:
  /// nothing stored is now Arabic, and without this sentinel a person who
  /// deliberately asked for the device's language would get Arabic back on the
  /// next launch, with no way to make the choice stick.
  static const followSystem = 'system';

  /// Dark unless somebody said otherwise.
  ///
  /// This app is read at three in the morning in Mina and on a coach before
  /// Fajr, far more often than it is read at a desk. Following the device
  /// would hand a white screen to whoever never opened the settings, which is
  /// most people.
  static ThemeMode _readThemeMode(SharedPreferences p) =>
      switch (p.getString(_kTheme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        followSystem => ThemeMode.system,
        // Unset, or a value written by a build that spelled it differently.
        _ => ThemeMode.dark,
      };

  /// Arabic unless somebody said otherwise.
  ///
  /// Arabic is not a fallback here, it is the language the mission works in:
  /// the master data is Arabic, half the English column in the catalog was
  /// never filled in, and every notification the database composes is written
  /// in it. A phone set to English is a phone, not a decision.
  ///
  /// Null still means "follow the device", and is still reachable — it is
  /// simply no longer what you get by saying nothing.
  static Locale? _readLocale(SharedPreferences p) {
    final code = p.getString(localeKey);
    if (code == followSystem) return null;
    return code == null ? const Locale('ar') : Locale(code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> setSolidSurfaces(bool solid) async {
    emit(state.copyWith(solidSurfaces: solid));
    await _prefs.setBool(_kSolidSurfaces, solid);
  }

  /// Folding and unfolding the rail. Persisted rather than held in the screen's
  /// own state: it is a habit, not a moment — a man who works folded wants it
  /// folded tomorrow, and re-folding it on every cold start is the sort of
  /// small insult an app is never forgiven for.
  Future<void> setSidebarExpanded(bool expanded) async {
    emit(state.copyWith(sidebarExpanded: expanded));
    await _prefs.setBool(_kSidebarExpanded, expanded);
  }

  /// Turning push off unsubscribes this device from every topic and forgets its
  /// token, so nothing is delivered to it; turning it back on resubscribes.
  Future<void> setNotificationsEnabled(bool enabled) async {
    emit(state.copyWith(notificationsEnabled: enabled));
    await _prefs.setBool(_kNotifications, enabled);
    if (enabled) {
      await PushService.instance.start();
    } else {
      await PushService.instance.mute();
    }
  }

  Future<void> setLocale(Locale? locale) async {
    emit(state.copyWith(locale: locale, clearLocale: locale == null));
    // The sentinel rather than removing the key — see [followSystem].
    await _prefs.setString(localeKey, locale?.languageCode ?? followSystem);
    // The screen re-renders itself; the two things OUTSIDE it do not. A week of
    // prayer alarms and the home-screen widget both carry finished sentences,
    // written in whichever language was chosen when they were laid down, and
    // they would go on saying "Fajr is now due" in an app that had been Arabic
    // for a month. So they are written again, in the new language.
    await PrayerScheduler.instance.refresh();
  }
}
