import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/share/shareable.dart';

/// The place code and the export sheets both leave this app the same way: bytes
/// written into the temporary directory, then that path handed to the
/// platform's share sheet.
///
/// The path was built with a forward slash, which every part of Dart accepts on
/// every platform — the file is written, and read back, and nothing complains.
/// The Windows share sheet is not part of Dart. `share_plus` passes the path
/// through to WinRT's `StorageFile.GetFileFromPathAsync`, and that refuses a
/// path with a forward slash anywhere in it: `C:\…\Temp/place-code.pdf` comes
/// back 0x80070002, FILE NOT FOUND, for a file that is sitting right there. The
/// plugin then drops the file from the share package and opens an empty sheet,
/// and nothing anywhere says why.
///
/// So the separator has to be the one the platform actually uses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory temp;

  /// What path_provider will answer with. A test sets this to a real directory
  /// so the bytes have somewhere to land.
  late String temporaryPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('shareable_test');
    temporaryPath = temp.path;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getTemporaryDirectory') return temporaryPath;
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  final bytes = Uint8List.fromList([1, 2, 3]);

  Future<String> pathOf() async => (await asShareable(
    bytes,
    name: 'place-code.pdf',
    mimeType: 'application/pdf',
  )).path;

  test('the path is joined with the separator this platform uses', () async {
    expect(
      await pathOf(),
      '${temp.path}${Platform.pathSeparator}place-code.pdf',
    );
  });

  test('nothing introduces a slash the platform does not use', () async {
    // The whole of the Windows failure in one line — and on a platform whose
    // separator IS the forward slash there is nothing here to get wrong.
    if (Platform.pathSeparator == r'\') {
      expect(await pathOf(), isNot(contains('/')));
    }
  });

  test('a directory that already ends in a separator is not doubled', () async {
    // path_provider is not the only thing that answers this, and an
    // implementation handing back "C:\Temp\" would otherwise produce a path
    // with two separators in a row — the same refusal by another route.
    temporaryPath = temp.path + Platform.pathSeparator;

    expect(
      await pathOf(),
      '${temp.path}${Platform.pathSeparator}place-code.pdf',
    );
  });

  test('the bytes are actually there, under that name', () async {
    expect(File(await pathOf()).readAsBytesSync(), bytes);
  });

  test('nowhere to write is bytes carried in memory, not a crash', () async {
    // A platform with no temporary directory — the browser — hands the bytes
    // to the share sheet as they are. Written as a fallback on the failure
    // rather than a check on which platform is asking.
    temporaryPath = '';
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    final file = await asShareable(
      bytes,
      name: 'place-code.pdf',
      mimeType: 'application/pdf',
    );

    expect(await file.readAsBytes(), bytes);
  });
}
