import 'package:flutter_bloc/flutter_bloc.dart';

/// A [Cubit] that does not throw when its screen has already gone.
///
/// Nearly every cubit in this app does the same thing: await the database, then
/// emit what came back. And a person can leave the screen while that is in
/// flight — press back, pop a sheet, let the router redirect them at sign-out —
/// which disposes the provider, closes the cubit, and leaves the reply arriving
/// at a door that is no longer there. `emit` answers that with
/// `StateError: Cannot emit new states after calling close`.
///
/// It is a real error in the sense that something did happen, and no error at
/// all in the sense that matters: the state was for a screen nobody is looking
/// at. Dropping it is the whole correct response. The alternative — writing
/// `if (!isClosed)` at every await in eighteen cubits — is the same behaviour
/// written thirty times, and forgotten on the thirty-first.
///
/// What this deliberately does NOT do is cancel the work. The request still
/// runs and still reaches the database, which is usually what was wanted: a
/// save that was already sent should land whether or not its screen survived
/// long enough to hear about it.
abstract class SafeCubit<State> extends Cubit<State> {
  SafeCubit(super.initialState);

  @override
  void emit(State state) {
    if (isClosed) return;
    super.emit(state);
  }
}
