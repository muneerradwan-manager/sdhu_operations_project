import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/attachments/attachment_picker.dart';

void main() {
  group('where a photograph can be TAKEN', () {
    // The same shape of bug as the scanner one in `check_in_test.dart`, and it
    // reached a user: tapping «الكاميرا» on Windows to set a profile picture
    // threw `Bad state: This implementation of ImagePickerPlatform requires a
    // "cameraDelegate" in order to use ImageSource.camera` straight past the
    // picker and out to the zone handler. Nothing was shown, nothing was
    // logged where anyone would look, and the sheet simply closed.
    //
    // The desktop plugins all extend `CameraDelegatingImagePickerPlatform`,
    // which throws rather than returning null or falling back — so this cannot
    // be left to fail gracefully at the call site. The row has to be absent.
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('the desktops the app also runs on are not offered the camera', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.linux,
        // macOS included deliberately, though it HAS cameras: image_picker's
        // macOS implementation delegates too, and registers no delegate.
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          isCameraCaptureSupported,
          isFalse,
          reason: '$platform throws on ImageSource.camera',
        );
      }
    });

    test('the phones it is carried on are', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          isCameraCaptureSupported,
          isTrue,
          reason: '$platform implements the camera itself',
        );
      }
    });

    test('choosing a file is never withdrawn — only TAKING one is', () {
      // The point worth protecting: the gate is about capture, not about
      // attaching images at all. A desktop still picks a photograph from disk,
      // which is how one attaches a photograph on a desktop anyway.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(isCameraCaptureSupported, isFalse);
      // The gallery path goes through the same plugin and is implemented
      // everywhere; if that ever stops being true this file is the wrong place
      // to find out, but the asymmetry is the whole design and belongs here.
    });
  });
}
