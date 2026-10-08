import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

/// How a value becomes a cell.
///
/// One place for it, because the alternative is nine datasets each deciding
/// what an empty date looks like, and a sheet where a blank means "none" in one
/// column and "1970-01-01" in the next is a sheet somebody will add up wrongly.
abstract final class ExportValues {
  /// A date, as a date and not as a timestamp.
  ///
  /// ISO on purpose. A spreadsheet reads `2026-08-04` as a date in every
  /// locale; `04/08/2026` is the fourth of August in Damascus and the eighth of
  /// April in New York, and an export that has to be told which is which is an
  /// export that will be read wrongly at least once.
  static String date(DateTime? value) =>
      value == null ? '' : DateFormat('yyyy-MM-dd').format(value.toLocal());

  /// A date with the time on it, for things where the hour is the point — when
  /// a complaint was filed, when a duty was last moved.
  static String moment(DateTime? value) => value == null
      ? ''
      : DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());

  /// Yes or no in the reader's language.
  ///
  /// Never `true`/`false`: this is a sheet a person reads, and half of them are
  /// reading it in Arabic.
  static String yesNo(AppLocalizations l, bool? value) =>
      value == null ? '' : (value ? l.auditYes : l.auditNo);

  /// A number, with nothing added to it.
  static String number(num? value) => value?.toString() ?? '';

  /// A number rounded for reading — a score out of a hundred does not want six
  /// decimal places.
  static String decimal(double? value, {int places = 1}) =>
      value == null ? '' : value.toStringAsFixed(places);

  /// Plain text, with the line breaks kept.
  ///
  /// The CSV writer quotes them, so a duty note stays one cell however many
  /// lines the man typed. Nothing is truncated: an export exists to carry what
  /// is there.
  static String text(String? value) => value ?? '';
}
