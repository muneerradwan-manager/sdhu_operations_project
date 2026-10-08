import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/evaluation.dart';

/// The names and glyphs the seven kinds are shown by.
///
/// Here rather than in the enum: what an evaluation is about is a fact about
/// the database, and what it is CALLED is a fact about the reader's language.
/// The domain does not import the ARB files.
String evaluationTargetLabel(AppLocalizations l, EvaluationTarget target) =>
    switch (target) {
      EvaluationTarget.employee => l.evaluationTargetEmployee,
      EvaluationTarget.module => l.evaluationTargetModule,
      EvaluationTarget.report => l.evaluationTargetReport,
      EvaluationTarget.hotel => l.evaluationTargetHotel,
      EvaluationTarget.cluster => l.evaluationTargetCluster,
      EvaluationTarget.group => l.evaluationTargetGroup,
      EvaluationTarget.other => l.evaluationTargetOther,
    };

/// Each kind wears the glyph its own section already wears, so an evaluation of
/// a hotel is recognisable from the same shape the master data uses.
IconData evaluationTargetIcon(EvaluationTarget target) => switch (target) {
  EvaluationTarget.employee => AppIcons.employees,
  EvaluationTarget.module => AppIcons.modules,
  EvaluationTarget.report => AppIcons.reports,
  EvaluationTarget.hotel => AppIcons.referenceData,
  EvaluationTarget.cluster => AppIcons.referenceData,
  EvaluationTarget.group => AppIcons.participants,
  EvaluationTarget.other => AppIcons.evaluations,
};

String evaluationKindLabel(AppLocalizations l, EvaluationQuestionKind kind) =>
    kind.isScored ? l.evaluationEditorAddChoice : l.evaluationEditorAddWritten;

IconData evaluationKindIcon(EvaluationQuestionKind kind) =>
    kind.isScored ? AppIcons.evaluationChoice : AppIcons.evaluationWritten;

/// A mark, written the way a mark is written and not the way a double prints.
///
/// Postgres `numeric(7,2)` comes back as 10.00 for what everybody calls 10, and
/// half marks are real — 7.5 is a mark somebody wrote on a form. So: no decimal
/// where there is nothing after it, one where there is.
String formatMark(double value) {
  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
  return rounded
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// "38 / 50", in the reader's digits. Always both halves: a score without the
/// total it was earned against is a number nobody can act on.
String formatScore(double score, double total) =>
    '${formatMark(score)} / ${formatMark(total)}';
