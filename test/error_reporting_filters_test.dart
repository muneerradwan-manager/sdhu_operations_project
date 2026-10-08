import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/logging/error_reporting.dart';

/// Two kinds of noise that must never reach the crash reporter, and everything
/// else that must still get there.
///
/// The reporter is only worth having if its dashboard is readable during the
/// five days it was built for. Both of these can produce a hundred entries in a
/// second, and neither is a fault:
///
///   * A map screen asks for a hundred tiles at once. On a blocked or slow
///     network every one fails, and the loudest signal of the season becomes
///     "somebody opened the map on bad wifi".
///   * `connectivity_plus` on Windows refuses to start its listener at all, and
///     reports it at every launch of the desktop build.
///
/// The filters are narrow on purpose. A handler that quietly eats errors is
/// worth less than the traces it saves, so what is asserted here is as much
/// what still travels as what does not.
void main() {
  setUp(CrashReporting.resetForTest);
  tearDown(CrashReporting.resetForTest);

  /// Runs [details] through the installed handler and says whether the reporter
  /// took an interest.
  bool isReported(FlutterErrorDetails details) {
    final before = CrashReporting.pendingCount;
    installErrorLogging();
    FlutterError.onError!(details);
    return CrashReporting.pendingCount > before;
  }

  group('a tile that would not download', () {
    FlutterErrorDetails tileFailure(Object error) => FlutterErrorDetails(
      exception: error,
      library: 'image resource service',
    );

    test('a socket timeout is not a crash', () {
      // Verbatim shape of what Windows produced against tile.openstreetmap.org.
      expect(
        isReported(tileFailure(
          const SocketException(
            'The semaphore timeout period has expired',
            osError: OSError('The semaphore timeout period has expired', 121),
          ),
        )),
        isFalse,
      );
    });

    test('nor is a client exception from the http package', () {
      expect(
        isReported(tileFailure(
          Exception('ClientException with SocketException: Failed host lookup'),
        )),
        isFalse,
      );
    });

    test('but a real decoding fault still travels', () {
      // An image that arrived and could not be read is a bug in what was
      // served or in how it is read, and somebody should hear about it.
      expect(
        isReported(tileFailure(StateError('Invalid image data'))),
        isTrue,
        reason: 'only NETWORK failures are weather; a corrupt image is not',
      );
    });
  });

  group('a platform stream that would not start', () {
    test('the connectivity channel on Windows is not a crash', () {
      expect(
        isReported(
          FlutterErrorDetails(
            exception: PlatformException(
              code: '-2147024809',
              message: 'NetworkManager::StartListen',
            ),
            context: ErrorDescription(
              'while activating platform stream on channel '
              'dev.fluttercommunity.plus/connectivity_status',
            ),
          ),
        ),
        isFalse,
      );
    });

    test('another channel failing the same way still travels', () {
      // The filter names one channel. A different plugin refusing to start is
      // news, and swallowing it would be how a real fault goes unnoticed.
      expect(
        isReported(
          FlutterErrorDetails(
            exception: PlatformException(code: 'x', message: 'boom'),
            context: ErrorDescription(
              'while activating platform stream on channel '
              'com.example.something_else',
            ),
          ),
        ),
        isTrue,
      );
    });
  });

  test('an ordinary framework error is reported', () {
    // The case the whole thing exists for: a bad build, an overflow, a failed
    // layout. None of the filters may touch it.
    expect(
      isReported(
        FlutterErrorDetails(
          exception: StateError('bad build'),
          library: 'widgets library',
        ),
      ),
      isTrue,
    );
  });
}
