import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/settings/settings_cubit.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/selection_indicator.dart';

/// AppBar action exposing quick theme + language switching.
class SettingsMenuButton extends StatelessWidget {
  const SettingsMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = context.watch<SettingsCubit>();
    final mode = settings.state.themeMode;

    return PopupMenuButton<void>(
      icon: const Icon(AppIcons.settings),
      tooltip: l.commonSettings,
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            l.settingsTheme,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        _themeItem(context, ThemeMode.system, l.themeSystem, mode),
        _themeItem(context, ThemeMode.light, l.themeLight, mode),
        _themeItem(context, ThemeMode.dark, l.themeDark, mode),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: Text(
            l.settingsLanguage,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        _localeItem(context, const Locale('ar'), l.languageArabic, settings),
        _localeItem(context, const Locale('en'), l.languageEnglish, settings),
      ],
    );
  }

  PopupMenuItem<void> _themeItem(
    BuildContext context,
    ThemeMode value,
    String label,
    ThemeMode current,
  ) {
    return PopupMenuItem(
      onTap: () => context.read<SettingsCubit>().setThemeMode(value),
      child: _row(context, label, selected: value == current),
    );
  }

  PopupMenuItem<void> _localeItem(
    BuildContext context,
    Locale value,
    String label,
    SettingsCubit settings,
  ) {
    final selected = settings.state.locale?.languageCode == value.languageCode;
    return PopupMenuItem(
      onTap: () => context.read<SettingsCubit>().setLocale(value),
      child: _row(context, label, selected: selected),
    );
  }

  Widget _row(BuildContext context, String label, {required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SelectionIndicator(selected: selected, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: selected ? scheme.primary : null,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}
