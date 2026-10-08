import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/bloc/safe_cubit.dart';

/// Every cubit in this app awaits the database and then emits what came back,
/// and a person can leave the screen while that is in flight. The provider is
/// disposed, the cubit closed, and the reply arrives at a door that is no
/// longer there — which plain `emit` answers with a thrown StateError.
///
/// It is a real event and a non-event: the state was for a screen nobody is
/// looking at. Dropping it is the whole correct response, and doing it in one
/// place is why this class exists rather than `if (!isClosed)` written at
/// thirty awaits and forgotten at the thirty-first.
class _Counter extends SafeCubit<int> {
  _Counter() : super(0);

  void increment() => emit(state + 1);

  /// The shape the real cubits have: await something, then emit.
  Future<void> incrementLater(Future<void> work) async {
    await work;
    emit(state + 1);
  }
}

void main() {
  test('it emits normally while it is open', () {
    final cubit = _Counter()..increment()..increment();
    expect(cubit.state, 2);
  });

  test('emitting after close is dropped, not thrown', () async {
    final cubit = _Counter();
    await cubit.close();

    expect(cubit.increment, returnsNormally);
    expect(cubit.state, 0, reason: 'the state stands as it was at close');
  });

  test('a reply that lands after the screen is gone changes nothing', () async {
    final cubit = _Counter();
    final work = Future<void>.delayed(const Duration(milliseconds: 20));

    final inFlight = cubit.incrementLater(work);
    await cubit.close();

    // The await completes AFTER close — the case that throws without this.
    await expectLater(inFlight, completes);
    expect(cubit.state, 0);
  });

  test('closing twice is still fine', () async {
    final cubit = _Counter();
    await cubit.close();
    await cubit.close();
    expect(cubit.increment, returnsNormally);
  });
}
