import 'package:flutter/widgets.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/operational_module.dart';

/// What a reporting cadence is called. Its own file because both the editor
/// (choosing one) and the file page (showing it) need the same words.
String cadenceLabel(BuildContext context, ReportCadence cadence) =>
    cadenceName(context.l10n, cadence);

/// The same words, asked for without an element to read a locale from.
///
/// An export builds its file after the screen that asked for it may already be
/// gone, so it carries [AppLocalizations] rather than a context — the same
/// split `complaint_labels.dart` and `evaluation_labels.dart` already make.
String cadenceName(AppLocalizations l, ReportCadence cadence) => switch (cadence) {
  ReportCadence.none => l.cadenceNone,
  ReportCadence.daily => l.cadenceDaily,
  ReportCadence.weekly => l.cadenceWeekly,
  ReportCadence.once => l.cadenceOnce,
};
