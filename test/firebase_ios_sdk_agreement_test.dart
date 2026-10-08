/// The Firebase plugins must all want the SAME firebase-ios-sdk.
///
/// Each one's `ios/<name>/Package.swift` pins that SDK with SwiftPM's `exact:`
/// — not a range — so Swift Package Manager has no room to reconcile two
/// different answers. It does not pick the newer. It refuses:
///
///   xcodebuild: error: Could not resolve package dependencies:
///     'firebase_messaging-16.4.3' depends on 'firebase-ios-sdk' 12.15.0 and
///     'firebase_crashlytics-5.2.7' depends on 'firebase-ios-sdk' 12.17.0
///
/// pubspec.lock drifted into exactly that state on its own: the three are
/// constrained with `^`, they were resolved at different times, and `pub get`
/// upgrades nothing it does not have to. Nothing said a word about it. Android
/// builds, web builds, `flutter analyze` and 946 tests were all clean, because
/// this is a fact about Package.swift files that only an iOS build reads — and
/// an iOS build needs a Mac, so on this project it is the slowest and most
/// distant place a mistake can surface.
///
/// Upgrading ONE of the three is all it takes to break it again.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The plugins that carry a `Package.swift` pinning firebase-ios-sdk.
const _plugins = <String>[
  'firebase_core',
  'firebase_messaging',
  'firebase_crashlytics',
];

/// Where pub put each package for THIS checkout. Read from the project rather
/// than from a PUB_CACHE path, which differs on every machine and on CI.
Map<String, Directory> _packageRoots() {
  final file = File('.dart_tool/package_config.json');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'run `flutter pub get` before this test',
  );

  final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final roots = <String, Directory>{};

  for (final entry in (config['packages'] as List).cast<Map<String, dynamic>>()) {
    final name = entry['name'] as String;
    if (!_plugins.contains(name)) continue;
    // rootUri is absolute for a hosted package and relative to .dart_tool for
    // a path dependency; resolve against the file's own directory either way.
    final uri = Uri.parse(entry['rootUri'] as String);
    roots[name] = Directory.fromUri(
      uri.hasScheme ? uri : File('.dart_tool/').absolute.uri.resolveUri(uri),
    );
  }
  return roots;
}

/// The version out of `let firebaseSdkVersion: Version = "12.18.0"`.
///
/// Loose about three things the plugins have each spelled differently: the
/// name (`firebase_sdk_version` in the older ones, `firebaseSdkVersion` now),
/// whether there is a type annotation at all, and what that type is — it is
/// `Version` today and was `String` before, which is what this missed on the
/// first attempt.
String? _pinnedSdk(Directory root, String plugin) {
  final manifest = File('${root.path}/ios/$plugin/Package.swift');
  if (!manifest.existsSync()) return null;
  final match = RegExp(
    r'''let\s+firebase[_]?[Ss]dk[_]?[Vv]ersion\s*(?::\s*\w+\s*)?=\s*"([0-9]+\.[0-9]+\.[0-9]+)"''',
  ).firstMatch(manifest.readAsStringSync());
  return match?.group(1);
}

void main() {
  test('every Firebase plugin pins the same firebase-ios-sdk', () {
    final roots = _packageRoots();
    final pinned = <String, String>{};

    for (final plugin in _plugins) {
      final root = roots[plugin];
      expect(root, isNotNull, reason: '$plugin is not in package_config.json');

      final version = _pinnedSdk(root!, plugin);
      // A plugin that has stopped shipping a Package.swift, or that pins with
      // a range instead, is not a failure — it is simply out of this argument.
      if (version != null) pinned[plugin] = version;
    }

    expect(
      pinned,
      isNotEmpty,
      reason: 'no Package.swift found — has the plugin layout changed?',
    );

    final agreed = pinned.values.toSet();
    expect(
      agreed,
      hasLength(1),
      reason:
          'SwiftPM pins these with `exact:` and will refuse to resolve:\n'
          '${pinned.entries.map((e) => '  ${e.key} -> firebase-ios-sdk ${e.value}').join('\n')}\n'
          'Fix with: flutter pub upgrade ${_plugins.join(' ')}',
    );
  });
}
