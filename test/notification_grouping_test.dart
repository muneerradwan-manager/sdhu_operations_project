import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/notifications/domain/app_notification.dart';

/// A hundred rows of "21/08 09:14, 21/08 09:02, 20/08 22:40" is a wall of
/// numbers, and the eye cannot see where yesterday started without doing the
/// arithmetic itself. The inbox is cut into days so the headings do it once —
/// which is only true if a day is the reader's day, and if a row that lands out
/// of order joins the day it belongs to instead of opening a second copy of it.
void main() {
  AppNotification at(DateTime when, {String id = 'n'}) => AppNotification(
    id: id,
    groupId: id,
    title: id,
    createdAt: when,
  );

  test('consecutive days come out as one section each, newest first', () {
    final days = NotificationDay.byDay([
      at(DateTime(2026, 8, 21, 9, 14), id: 'a'),
      at(DateTime(2026, 8, 21, 9, 2), id: 'b'),
      at(DateTime(2026, 8, 20, 22, 40), id: 'c'),
    ]);

    expect(days.length, 2);
    expect(days.first.day, DateTime(2026, 8, 21));
    expect(days.first.items.map((n) => n.id), ['a', 'b']);
    expect(days.last.day, DateTime(2026, 8, 20));
    expect(days.last.items.map((n) => n.id), ['c']);
  });

  test('a row arriving out of order joins its own day rather than opening '
      'a second one', () {
    final days = NotificationDay.byDay([
      at(DateTime(2026, 8, 21, 9, 14), id: 'a'),
      at(DateTime(2026, 8, 20, 22, 40), id: 'b'),
      at(DateTime(2026, 8, 21, 1, 5), id: 'c'),
    ]);

    expect(days.length, 2);
    expect(days.first.items.map((n) => n.id), ['a', 'c']);
    expect(days.last.items.map((n) => n.id), ['b']);
  });

  test('midnight and a minute to it are different days', () {
    final days = NotificationDay.byDay([
      at(DateTime(2026, 8, 21, 0, 0), id: 'a'),
      at(DateTime(2026, 8, 20, 23, 59), id: 'b'),
    ]);

    expect(days.map((d) => d.day), [
      DateTime(2026, 8, 21),
      DateTime(2026, 8, 20),
    ]);
  });

  test('an empty inbox has no days', () {
    expect(NotificationDay.byDay(const []), isEmpty);
  });
}
