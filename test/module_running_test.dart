import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/domain/operational_module.dart';

/// A file can stop being live two ways: an administrator switches it off, or
/// the end date somebody wrote on it goes by. The app asks [isRunning] almost
/// everywhere and the database asks the same question of the same two facts —
/// a member sees the files he is in that are switched on AND not out of time.
///
/// The boundary is the whole of it. `ends_on` is the last day the file runs,
/// not the first day it does not: a file ending today is working today, and
/// getting that backwards would close every file a day early, at exactly the
/// hour the work it was opened for is finishing.
void main() {
  final today = DateTime.now();
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  OperationalModule file({bool active = true, DateTime? endsOn}) =>
      OperationalModule(
        id: 'm',
        moduleTypeId: 't',
        seasonId: 's',
        isActive: active,
        endsOn: endsOn,
      );

  test('no end date means it runs until somebody says otherwise', () {
    expect(file().hasEnded, isFalse);
    expect(file().isRunning, isTrue);
  });

  test('the last day is inclusive — it is running today', () {
    final ending = file(endsOn: day(0));
    expect(ending.hasEnded, isFalse);
    expect(ending.isRunning, isTrue);
  });

  test('yesterday is over', () {
    final ended = file(endsOn: day(-1));
    expect(ended.hasEnded, isTrue);
    expect(ended.isRunning, isFalse);
  });

  test('tomorrow is not', () {
    expect(file(endsOn: day(1)).isRunning, isTrue);
  });

  test('a file never switched on is not running, date or no date', () {
    expect(file(active: false).isRunning, isFalse);
    expect(file(active: false, endsOn: day(30)).isRunning, isFalse);
  });

  test('having ended is about the date alone, not the switch', () {
    // Which is what lets a card say WHICH of the two silences it is in.
    expect(file(active: false, endsOn: day(-1)).hasEnded, isTrue);
    expect(file(active: false).hasEnded, isFalse);
  });

  test('a time of day on the end date does not end it early', () {
    // Dates arrive from the database as midnight, but a value built in the app
    // can carry a clock; the comparison is by day.
    final ending = file(
      endsOn: DateTime(today.year, today.month, today.day, 23, 59),
    );
    expect(ending.isRunning, isTrue);
  });
}
