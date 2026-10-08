import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
// XFile comes through share_plus rather than a direct cross_file dependency,
// the way every other caller in this app gets it.
import 'package:share_plus/share_plus.dart';

/// Bytes made into something the platform's share sheet will take.
///
/// The web has no temporary directory — `path_provider` has no implementation
/// there — so the bytes are handed over as they are and the browser's own share
/// or download takes them from memory. Written as a fallback on the FAILURE
/// rather than as a check on `kIsWeb`, because what matters is whether a
/// directory can be had, not which platform is asking.
///
/// Lifted out of the export cubit when the place-code card needed the same
/// thing. One copy, so the web fallback is not re-derived by somebody who does
/// not know it exists — which is exactly how a feature ends up working
/// everywhere but in a browser.
Future<XFile> asShareable(
  Uint8List bytes, {
  required String name,
  required String mimeType,
}) async {
  try {
    final directory = await getTemporaryDirectory();
    final path = _join(directory.path, name);
    await File(path).writeAsBytes(bytes, flush: true);
    return XFile(path, mimeType: mimeType);
  } catch (_) {
    return XFile.fromData(bytes, name: name, mimeType: mimeType);
  }
}

/// [directory] and [name] joined with the separator THIS platform uses.
///
/// A forward slash reads as a separator to Dart everywhere, so a path built
/// with one is written and read back without complaint on Windows too — which
/// is what made this look correct for as long as nobody handed the path to
/// anything else.
///
/// The Windows share sheet is something else. `share_plus` passes the path
/// straight to WinRT's `StorageFile.GetFileFromPathAsync`, and that refuses any
/// path with a forward slash in it — `C:\…\Temp/place-code.pdf` comes back
/// 0x80070002, FILE NOT FOUND, for a file that is sitting right there. The
/// plugin then simply leaves the file out of the share package, so the sheet
/// opens with nothing in it and nothing anywhere says why.
///
/// [Platform.pathSeparator] rather than the `path` package: this is the one
/// join in the app, and it is not worth promoting a transitive dependency to a
/// direct one for it.
String _join(String directory, String name) {
  final separator = Platform.pathSeparator;
  final base = directory.endsWith(separator) || directory.endsWith('/')
      ? directory.substring(0, directory.length - 1)
      : directory;
  return '$base$separator$name';
}
