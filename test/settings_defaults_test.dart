import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/settings/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a person gets before they have chosen anything, and what happens when
/// they choose the thing that used to mean "nothing".
///
/// The second half is the delicate one. "Follow the system" used to be stored
/// by REMOVING the key, which worked only while nothing-stored and
/// follow-the-system meant the same. They no longer do — nothing stored is now
/// Arabic and dark — so choosing to follow the device has to be written down,
/// or the choice silently reverts on the next launch and the option looks
/// broken rather than absent.
Future<SettingsCubit> cubitWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsCubit(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a fresh install', () {
    test('speaks Arabic', () async {
      final settings = await cubitWith({});

      expect(
        settings.state.locale,
        const Locale('ar'),
        reason:
            'the mission works in Arabic; a phone set to English is a '
            'phone, not a decision',
      );
    });

    test('is dark', () async {
      final settings = await cubitWith({});

      expect(
        settings.state.themeMode,
        ThemeMode.dark,
        reason:
            'this app is read at three in the morning in Mina far more '
            'often than at a desk',
      );
    });

    test('opens with the rail standing open', () async {
      final settings = await cubitWith({});

      expect(
        settings.state.sidebarExpanded,
        isTrue,
        reason: 'a rail that arrives folded is a column of unlabelled glyphs',
      );
    });

  });

  group('the rail', () {
    test('folding it survives a restart', () async {
      // A habit, not a moment: re-folding it on every cold start is the sort of
      // small insult an app is never forgiven for.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await SettingsCubit(prefs).setSidebarExpanded(false);

      expect(SettingsCubit(prefs).state.sidebarExpanded, isFalse);
    });

    test('a home layout stored by an older build is simply ignored', () async {
      // The grid, and the choice between it and the rail, are gone. A device
      // that chose the grid last month must open on the rail rather than on
      // nothing — the key is dead, not authoritative.
      final settings = await cubitWith({'settings.homeLayout': 'grid'});

      expect(settings.state.sidebarExpanded, isTrue);
    });
  });

  group('a choice that was made', () {
    test('English is kept', () async {
      final settings = await cubitWith({'settings.locale': 'en'});
      expect(settings.state.locale, const Locale('en'));
    });

    test('light is kept', () async {
      final settings = await cubitWith({'settings.themeMode': 'light'});
      expect(settings.state.themeMode, ThemeMode.light);
    });
  });

  group('follow the system, which is no longer the default', () {
    test('choosing it for the language survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = SettingsCubit(prefs);

      await first.setLocale(null);
      expect(first.state.locale, isNull);

      // The app is closed and opened again.
      final second = SettingsCubit(prefs);

      expect(
        second.state.locale,
        isNull,
        reason: 'it came back as Arabic, so the option cannot be chosen at all',
      );
    });

    test('it is written down rather than erased', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await SettingsCubit(prefs).setLocale(null);

      expect(prefs.getString('settings.locale'), SettingsCubit.followSystem);
    });

    test('choosing it for the theme survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await SettingsCubit(prefs).setThemeMode(ThemeMode.system);

      expect(SettingsCubit(prefs).state.themeMode, ThemeMode.system);
    });
  });

  test('a value written by some other build does not crash the app', () {
    // Reading an unknown theme string must land somewhere sensible rather than
    // throwing on the way to the first frame.
    expect(() async {
      final settings = await cubitWith({'settings.themeMode': 'sepia'});
      expect(settings.state.themeMode, ThemeMode.dark);
    }, returnsNormally);
  });
}
