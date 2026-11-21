import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

/// The app's strings plus the Widgets, Material and Cupertino strings from
/// `material_ui`.
///
/// Use this instead of the generated `AppLocalizations.localizationsDelegates`:
/// as of Flutter 3.50, `flutter gen-l10n` still lists the legacy delegates from
/// `flutter_localizations`, which `material_ui` widgets do not read, so date
/// pickers, tooltips, back buttons and the like would find no localizations.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
