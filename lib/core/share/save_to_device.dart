import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether this device can be asked where to put a file.
///
/// Everywhere but the browser. This used to be the desktops alone, on
/// `file_selector.getSaveLocation`, which has no implementation on a phone —
/// and the argument written here was that a phone keeps a file through the
/// share sheet's own «حفظ في الملفات», which the share action beside this one
/// already reaches.
///
/// That was true and it was still the wrong shape. Keeping a file and sending
/// one are two different intentions, and putting the first inside the second
/// makes a person open a sheet full of contacts and applications in order to do
/// the one thing that involves nobody. `file_picker.saveFile` opens the
/// system's own document picker on Android and iOS and the save dialog on the
/// desktops, so both intentions can now have their own button.
///
/// The web is left out, and not for want of a mechanism: there, `saveFile`
/// starts a browser download and returns null — the same null it returns when
/// somebody closes the dialog. A success indistinguishable from a cancellation
/// is exactly the report [SaveOutcome] exists to keep this app from making.
bool get isSaveToDeviceSupported => !kIsWeb;

/// What came of asking. [SaveOutcome.cancelled] is not a failure and must not
/// be reported as one — closing the dialog is an answer.
enum SaveOutcome { saved, cancelled, failed }

class SaveResult {
  const SaveResult(this.outcome, {this.path});

  const SaveResult.cancelled() : outcome = SaveOutcome.cancelled, path = null;

  final SaveOutcome outcome;

  /// Where it landed, for the message that says so. Null unless [saved] — and
  /// possibly null even then: Android answers with a document URI rather than a
  /// path a person would recognise, so the message that reads this has to cope
  /// with having nothing to print.
  final String? path;
}

/// Asks where to put [bytes] and writes them there.
///
/// The suggested name is what the dialog opens with; whatever the person types
/// instead is what is used, extension and all — this does not correct anybody's
/// filename.
///
/// The bytes are handed to the picker rather than written afterwards, because
/// on Android and iOS there is no path to write to: the plugin passes them
/// through the platform's own document writer and hands back where they went.
/// On the desktops it writes them at the chosen path itself.
Future<SaveResult> saveToDevice(
  Uint8List bytes, {
  required String suggestedName,
  required String label,
  required String extension,
  required String mimeType,
}) async {
  if (!isSaveToDeviceSupported) return const SaveResult(SaveOutcome.failed);
  try {
    final uri = await FilePicker.saveFile(
      fileName: suggestedName,
      bytes: bytes,
      // Named so the phone's picker suggests somewhere sensible to put it.
      // file_picker 13 still accepts `type`/`allowedExtensions` here but no
      // longer forwards them; the MIME type is what reaches the platform.
      mimeType: mimeType,
      dialogTitle: label,
    );
    // Null is the dialog being closed, which is a decision rather than a fault.
    if (uri == null) return const SaveResult.cancelled();

    return SaveResult(
      SaveOutcome.saved,
      path: uri.scheme == 'file' ? uri.toFilePath() : null,
    );
  } catch (_) {
    return const SaveResult(SaveOutcome.failed);
  }
}
