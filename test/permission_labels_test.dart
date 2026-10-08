import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/permission_labels.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// A grant nobody translated still works, and that is the problem.
///
/// `permissionLabel` falls back to the CODE, so an unlabelled permission does
/// not fail, does not log and does not look broken from the inside — it renders
/// as `evaluations.templates` in a column of Arabic sentences, in the one
/// screen where an administrator decides what somebody may do. He is choosing
/// between a sentence he understands and a string he does not, about authority
/// over the season's records.
///
/// It went unnoticed across three migrations that way: 0084 added four codes,
/// 0088 added two, 0098 added three, and none of them were labelled. The
/// fallback is still right — a code from a newer server should render as
/// something rather than crash — but nothing was checking, and this is the
/// check.
void main() {
  late AppLocalizations ar;
  late AppLocalizations en;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// Every code the app names, read from the constants file rather than listed
  /// here — a list written twice is a list that goes out of date once.
  List<String> declaredCodes() {
    final dart = File(
      'lib/core/constants/permission_codes.dart',
    ).readAsStringSync();
    return RegExp(r"static\s+const\s+\w+\s*=\s*'([^']+)'")
        .allMatches(dart)
        .map((m) => m.group(1)!)
        .where((code) => code.contains('.'))
        .toList();
  }

  /// The section each one hangs under. `checkin.board` implies a `checkin`
  /// heading, and the editor draws it above the grants.
  Set<String> declaredSections() =>
      declaredCodes().map((c) => c.split('.').first).toSet();

  test('every grant reads as a sentence, in both languages', () {
    final codes = declaredCodes();
    expect(codes, isNotEmpty, reason: 'the pattern has drifted');

    final untranslated = <String>[];
    for (final code in codes) {
      if (permissionLabel(ar, code) == code) untranslated.add('ar: $code');
      if (permissionLabel(en, code) == code) untranslated.add('en: $code');
    }

    expect(
      untranslated,
      isEmpty,
      reason: 'these render as raw codes in the permissions editor, where '
          'somebody is deciding what another person may do:\n  '
          '${untranslated.join('\n  ')}',
    );
  });

  test('and so does every section heading above them', () {
    final untranslated = <String>[];
    for (final section in declaredSections()) {
      if (permissionLabel(ar, section) == section) {
        untranslated.add('ar: $section');
      }
      if (permissionLabel(en, section) == section) {
        untranslated.add('en: $section');
      }
    }

    expect(
      untranslated,
      isEmpty,
      reason: 'a heading over translated rows, itself untranslated:\n  '
          '${untranslated.join('\n  ')}',
    );
  });

  test('an unknown code still renders as something', () {
    // The fallback stays. A server one migration ahead of this build will name
    // grants this app has never heard of, and a permissions editor that threw
    // on one of them would be unopenable until the app was updated — which is
    // worse than a row reading as a code.
    expect(permissionLabel(ar, 'something.new'), 'something.new');
  });
}
