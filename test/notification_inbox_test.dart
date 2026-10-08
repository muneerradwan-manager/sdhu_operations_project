import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/notifications/application/notifications_cubit.dart';
import 'package:sdhu_operations_project/features/notifications/domain/app_notification.dart';

/// The inbox carries two things that are not read for the same reason.
///
/// An announcement is read when there is a minute. An urgent report is read
/// because somebody is standing somewhere waiting for an answer. Before this
/// they were drawn identically and stacked in one list, and the second was
/// found by scrolling past the first — at three in the morning, by whoever was
/// on the register.
///
/// What is asserted here is the machinery that stopped that: what a row IS,
/// where tapping it GOES, and that narrowing the list narrows what "الكل" means.
AppNotification _n(
  Map<String, dynamic> data, {
  String id = 'n1',
  DateTime? readAt,
}) => AppNotification(
  id: id,
  groupId: 'g1',
  title: 'x',
  createdAt: DateTime(2026, 8, 18, 9),
  readAt: readAt,
  data: data,
);

AppNotification _incident({String id = 'i', bool read = false}) => _n(
  {'type': 'incident', 'incident_id': 'inc-$id', 'module_id': 'm-1'},
  id: id,
  readAt: read ? DateTime(2026, 8, 18, 10) : null,
);

AppNotification _assignment({String id = 'a', bool read = false}) => _n(
  {'type': 'module_assigned', 'module_id': 'm-7'},
  id: id,
  readAt: read ? DateTime(2026, 8, 18, 10) : null,
);

AppNotification _broadcast({String id = 'b', bool read = false}) => _n(
  const {'type': 'broadcast'},
  id: id,
  readAt: read ? DateTime(2026, 8, 18, 10) : null,
);

void main() {
  group('what a row is', () {
    test('an alarm is an alarm, whatever else its payload names', () {
      // It carries `module_id` too. That does not make it a file notice — the
      // file is where the emergency happened, not the emergency.
      expect(_incident().kind, NotificationKind.incident);
      expect(_incident().isIncident, isTrue);
    });

    test('a file notice is one, and an announcement is neither', () {
      expect(_assignment().kind, NotificationKind.module);
      expect(_broadcast().kind, NotificationKind.broadcast);
      expect(_broadcast().isIncident, isFalse);
    });
  });

  group('where tapping goes', () {
    test('an alarm goes to the register, not to the file it names', () {
      final n = _incident();
      expect(n.destination, NotificationDestination.incident);
      expect(n.hasTarget, isTrue);
      // Somebody woken by "بلاغ عاجل" is going to telephone the man, not to
      // read the file's fields. The register is where both numbers are.
      expect(n.incidentId, 'inc-i');
      expect(n.moduleId, isNull);
    });

    test('a file notice still goes to its file', () {
      expect(_assignment().destination, NotificationDestination.module);
      expect(_assignment().moduleId, 'm-7');
    });

    test('an announcement goes nowhere and says so', () {
      expect(_broadcast().destination, NotificationDestination.none);
      expect(_broadcast().hasTarget, isFalse);
    });

    test('the tray tap reaches the same register the inbox row would', () {
      // A push carries the payload as FCM `data`. The two ends must not drift:
      // an alarm tapped in the phone's tray used to land on the inbox and stop
      // there, which is the one notification where the extra tap costs time.
      const data = {'type': 'incident', 'incident_id': 'inc-9'};
      expect(AppNotification.incidentIdIn(data), 'inc-9');
      expect(_n(data).incidentId, 'inc-9');
    });

    test('an alarm with no report named is not followed', () {
      expect(AppNotification.incidentIdIn(const {'type': 'incident'}), isNull);
      expect(
        AppNotification.incidentIdIn(const {
          'type': 'incident',
          'incident_id': '',
        }),
        isNull,
      );
      expect(_n(const {'type': 'incident'}).hasTarget, isFalse);
    });
  });

  group('narrowing the inbox', () {
    final items = [
      _incident(id: 'i1'),
      _assignment(id: 'a1'),
      _incident(id: 'i2', read: true),
      _broadcast(id: 'b1', read: true),
    ];
    const base = NotificationsState(loading: false);

    test('all means all', () {
      expect(base.copyWith(items: items).visible.length, 4);
    });

    test('the alarms alone, and everything else alone', () {
      final incidents = base
          .copyWith(items: items, filter: NotificationFilter.incidents)
          .visible;
      expect(incidents.map((n) => n.id), ['i1', 'i2']);

      final messages = base
          .copyWith(items: items, filter: NotificationFilter.messages)
          .visible;
      expect(messages.map((n) => n.id), ['a1', 'b1']);
    });

    test('the counts are counted per half, off the whole list', () {
      // The chip has to say what is waiting in the half you are NOT looking at,
      // so the numbers come off `items` and never off `visible`.
      final s = base.copyWith(
        items: items,
        filter: NotificationFilter.incidents,
      );
      expect(s.unread, 2);
      expect(s.unreadIncidents, 1);
      expect(s.unreadMessages, 1);
    });

    test('an inbox with no alarm in it has nothing to filter', () {
      expect(base.copyWith(items: [_assignment()]).hasIncidents, isFalse);
      expect(base.copyWith(items: items).hasIncidents, isTrue);
    });
  });
}
