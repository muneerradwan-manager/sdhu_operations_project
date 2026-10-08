import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../domain/check_in.dart';

/// The camera, pointed at the code on a gate.
///
/// It reports the FIRST code it recognises as ours and closes. Deliberately not
/// a scanner that keeps going: a man at a gate is scanning one sticker, and a
/// camera that carries on reading is a camera that files his arrival twice
/// because the phone was still pointing at the wall while he put it away.
///
/// Everything it cannot read is ignored in silence rather than refused with a
/// message. A camera held up outdoors sees product barcodes, WiFi codes and the
/// backs of other people's phones; a dialog for each would make the useful code
/// impossible to reach.
class ScanCheckInScreen extends StatefulWidget {
  const ScanCheckInScreen({super.key});

  @override
  State<ScanCheckInScreen> createState() => _ScanCheckInScreenState();
}

class _ScanCheckInScreenState extends State<ScanCheckInScreen> {
  final _controller = MobileScannerController(
    // One format. The scanner spends its time on what we print and nothing
    // else, which on a mid-range phone in daylight is the difference between
    // reading at arm's length and being held against the sticker.
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Set the moment a code is accepted. Without it the detector delivers two or
  /// three frames of the same sticker before the route finishes popping, and
  /// each would try to pop again.
  bool _done = false;

  /// The torch, asked for politely.
  ///
  /// `toggleTorch` throws when the controller never started, and a controller
  /// that never started is not a rare case — it is every refused camera
  /// permission, and every phone whose camera another app is holding. The
  /// button sits in the bar above the screen that SAYS the camera is
  /// unavailable, so the throw landed uncaught while the explanation was on
  /// screen. There is nothing to tell the reader here that the page is not
  /// already telling them.
  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      // Deliberately silent.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = PlaceCode.parse(barcode.rawValue);
      if (code == null) continue;
      _done = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.checkInScanTitle),
        actions: [
          IconButton(
            tooltip: l.checkInTorch,
            onPressed: _toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraUnavailable(error: error),
          ),
          // A window to aim through. Not decoration: a person told to "scan"
          // with no frame holds the phone at the wrong distance, and the codes
          // are stuck at head height on gates in bright sun.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
          // SafeArea rather than a fixed offset. The camera preview fills the
          // window edge to edge — which on Android 15 includes the space behind
          // the gesture bar — so a hint pinned a fixed distance from the bottom
          // sits underneath it on exactly the phones this is used on.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l.checkInScanHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// No camera, or the permission refused.
///
/// It used to offer the way out — report by position alone — and there is no
/// way out any more. Since 0098 a check-in is a code AND a position, so a
/// refused camera permission means this man cannot file an arrival at all until
/// he grants it. Saying so plainly is the only honest screen; the old button
/// would now close onto a sheet that has been deleted.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.camera, color: Colors.white54, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(
                l.checkInNoCamera,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.checkInNoCameraHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.commonBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
