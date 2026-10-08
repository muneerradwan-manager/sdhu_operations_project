import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `.env` is not a config file. It is an app asset, and everything in it ships.
///
/// pubspec.yaml declares `.env` under `flutter/assets`, which means the file is
/// copied byte for byte into the APK and into the web build. That is the whole
/// reason it works at run time — and it is also why a key put there is not
/// private in any sense. `unzip app.apk` and read `assets/flutter_assets/.env`.
///
/// This mattered once, literally. `SUPABASE_SERVICE_ROLE_KEY` sat in `.env`
/// with a real value, bundled into every build. That key does not merely read
/// more than a user may — it bypasses row-level security altogether, which is
/// the ONLY thing standing between a client and the whole database. Every
/// private document behind §6.4, the hidden author of every complaint (§24.9),
/// who evaluated whom (§26.9), and every place secret in `place_codes` (§30.3)
/// — all of it, from one unzip. Not one line of Dart ever read the key; it was
/// pure leakage, doing nothing but sitting there being shipped.
///
/// .gitignore had already written the rule down, above `.env.seed`:
///
///   > Admin/service keys for local seeding. Deliberately NOT `.env`: that
///   > file is bundled as a Flutter asset, so anything in it ships inside
///   > the APK.
///
/// The rule was understood and the key drifted past it anyway, because nothing
/// enforced it. A `.gitignore` guards the repository; it cannot guard a build.
/// This test guards the build.
///
/// **The rule is derived, not listed.** A hand-written allowlist here would be
/// one more thing to remember, and the failure being prevented IS somebody not
/// remembering. So the permitted set is read out of the app itself: a key may
/// live in `.env` if, and only if, some Dart file asks for it by name. A key
/// nothing reads has no reason to be shipped, whatever it is — which catches
/// the next leaked secret as well as it caught this one, without anybody
/// teaching it a new name.
void main() {
  /// `_requireEnv('X')` in bootstrap, `dotenv.env['X']` anywhere else.
  ///
  /// Both spellings, because the app genuinely uses both: start-up keys go
  /// through the helper that fails with a sentence naming the key, and the
  /// optional Google client ID is read directly and allowed to be absent.
  final reads = [
    RegExp(r"_requireEnv\(\s*'([A-Z0-9_]+)'\s*\)"),
    RegExp(r"dotenv\.env\[\s*'([A-Z0-9_]+)'\s*\]"),
  ];

  /// `KEY=` at the head of a line, comments and blanks skipped.
  final declaration = RegExp(r'^\s*([A-Z0-9_]+)\s*=');

  /// The keys named in a `.env`-shaped file. Values are never returned and
  /// never compared — a test that printed one on failure would write the
  /// secret into the CI log it was meant to keep it out of.
  Set<String> keysIn(File file) => file
      .readAsLinesSync()
      .map((line) => declaration.firstMatch(line)?.group(1))
      .whereType<String>()
      .toSet();

  late Set<String> wanted;

  setUpAll(() {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'run from the project root — ${lib.absolute.path}',
    );

    wanted = {
      for (final file in lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
        for (final pattern in reads)
          for (final match in pattern.allMatches(file.readAsStringSync()))
            match.group(1)!,
    };

    // If this ever comes back empty the two patterns above have gone stale, and
    // every check below would pass by vacuum — the strictest possible rule
    // applied to nothing. Better to fail here and say why.
    expect(
      wanted,
      isNotEmpty,
      reason:
          'no `dotenv.env[...]` or `_requireEnv(...)` found in lib/ — the '
          'patterns in this test no longer match how the app reads its '
          'environment, so it is guarding nothing',
    );
  });

  test('.env carries nothing the app does not read', () {
    final env = File('.env');
    if (!env.existsSync()) {
      // A fresh clone has no `.env` yet. Not a failure — the contract is still
      // enforced against `.env.example`, which is committed and always there.
      return;
    }

    final surplus = keysIn(env).difference(wanted);
    expect(
      surplus,
      isEmpty,
      reason:
          '`.env` is bundled into the APK by pubspec.yaml, so every key in it '
          'is readable by anyone holding the app. These are read by no Dart '
          'file, so shipping them buys nothing and risks everything: '
          '${surplus.join(', ')}.\n'
          'Move them to `.env.seed` (gitignored, never bundled), or set them '
          'as server-side secrets with `supabase secrets set`.',
    );
  });

  test('.env.example lists exactly what the app reads', () {
    // bootstrap.dart tells whoever hits a missing key to "copy .env.example".
    // That sentence is a promise, and it was false for a while — the file did
    // not exist at all. An example that is missing, stale, or padded with keys
    // nobody reads is how the next unnecessary secret gets copied in by
    // somebody following instructions.
    final example = File('.env.example');
    expect(
      example.existsSync(),
      isTrue,
      reason: 'bootstrap.dart names this file when a key is missing',
    );

    expect(
      keysIn(example),
      equals(wanted),
      reason:
          '.env.example must name every key the app reads and no others — it '
          'is the list a new machine gets set up from',
    );
  });
}
