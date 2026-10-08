import 'package:bloc/bloc.dart';

import 'app_logger.dart';
import 'error_reporting.dart';

/// Prints what every cubit in the app is doing.
///
/// [onError] is the one that earns its keep: a cubit that catches its own
/// failure and emits an error state swallows the stack trace with it, and this
/// is where the trace still comes out — and, in the field, where it leaves the
/// device.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  static const _tag = 'bloc';

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    if (!AppLogger.enabled) return;
    // The type only. A whole state object is a screenful — the states of this
    // app carry entire employee lists — and what is wanted here is the shape of
    // the sequence, not its contents.
    AppLogger.debug(
      _tag,
      '${bloc.runtimeType}: '
      '${change.currentState.runtimeType} → ${change.nextState.runtimeType}',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    AppLogger.error(_tag, '${bloc.runtimeType} threw', error, stackTrace);
    // Not fatal: the screen showed a message and the person carried on. But a
    // save that failed on a hundred phones in one hour is the single most
    // useful thing the season can be told, and it is invisible from a desk.
    CrashReporting.record(
      error,
      stackTrace,
      reason: '${bloc.runtimeType} threw',
    );
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    AppLogger.debug(_tag, '${bloc.runtimeType} created');
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    AppLogger.debug(_tag, '${bloc.runtimeType} closed');
    super.onClose(bloc);
  }
}
