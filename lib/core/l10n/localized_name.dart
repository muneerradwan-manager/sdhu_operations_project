import 'package:flutter/widgets.dart';

/// A name the database stores in both languages. Module types, fields, roles
/// and master data are content — they live in rows, not in the ARB files — so
/// they carry their own translations and resolve against the active locale.
class LocalizedName {
  const LocalizedName({required this.ar, this.en});

  final String ar;
  final String? en;

  /// Arabic is the source language: an English column that was never filled in
  /// falls back to it rather than showing a blank.
  String of(BuildContext context) =>
      inLanguage(Localizations.localeOf(context).languageCode);

  /// The same choice, made from a language code instead of from a context.
  ///
  /// Wanted where there is no element to read a locale from: an export builds
  /// its file after the screen that asked for it may already be gone, and the
  /// heading of a column has to be resolved once, at that moment, rather than
  /// re-resolved per cell.
  String inLanguage(String languageCode) {
    if (languageCode == 'ar') return ar;
    final english = en;
    return (english == null || english.isEmpty) ? ar : english;
  }

  static LocalizedName fromMap(
    Map<String, dynamic> map, {
    String prefix = 'name',
  }) {
    return LocalizedName(
      ar: (map['${prefix}_ar'] as String?) ?? '',
      en: map['${prefix}_en'] as String?,
    );
  }
}
