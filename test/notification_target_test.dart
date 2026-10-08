import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/notifications/data/push_service.dart';
import 'package:sdhu_operations_project/features/notifications/domain/app_notification.dart';

/// Where a notification takes you when you tap it.
///
/// The `data` payload is written by database triggers — notify_module_assignment
/// and the file broadcast — and read here. The two ends have to agree about the
/// key names, and nothing but a test says so: a trigger that started writing
/// `file_id` instead of `module_id` would silently make every notification
/// unopenable, with no error anywhere.
AppNotification _n(Map<String, dynamic> data) => AppNotification.fromMap({
  'id': 'n1',
  'group_id': 'g1',
  'title': 'تم إسنادك إلى ملف تشغيلي',
  'created_at': '2026-05-03T09:00:00Z',
  'data': data,
});

void main() {
  _pushTests();
  group('what a notification points at', () {
    test('an assignment opens its file', () {
      // Exactly the shape notify_module_assignment builds.
      final n = _n({
        'type': 'module_assigned',
        'module_id': 'm-42',
        'node_id': 'nd-7',
        'role_id': 'r-3',
      });
      expect(n.moduleId, 'm-42');
      expect(n.hasTarget, isTrue);
    });

    test('a broadcast to a file opens that file', () {
      final n = _n({'type': 'module_broadcast', 'module_id': 'm-9'});
      expect(n.moduleId, 'm-9');
      expect(n.hasTarget, isTrue);
    });

    test('an overdue-report reminder opens the file it is about', () {
      // Exactly the shape the scheduled pass in migration 0086 builds. The
      // reminder is only worth sending if it lands one tap from filing the
      // thing that is late.
      final n = _n({
        'type': 'report_overdue',
        'module_id': 'm-13',
        'period_start': '2026-08-04',
        'about_profile_id': 'p-5',
      });
      expect(n.moduleId, 'm-13');
      expect(n.hasTarget, isTrue);
    });

    test('a type nobody knows points nowhere, whatever it carries', () {
      // The allow-list is the point: `module_id` turns up on payloads that are
      // about something else in the file, and a tap that opens the wrong
      // screen is worse than a tap that does nothing.
      final n = _n({'type': 'something_new', 'module_id': 'm-1'});
      expect(n.moduleId, isNull);
      expect(n.hasTarget, isFalse);
    });

    test('a broadcast to everyone points nowhere', () {
      // It names no place, so the card must not offer to open one.
      final n = _n({'type': 'broadcast'});
      expect(n.moduleId, isNull);
      expect(n.hasTarget, isFalse);
    });

    test('no payload at all is not a crash', () {
      final n = AppNotification.fromMap({
        'id': 'n1',
        'group_id': 'g1',
        'title': 'hello',
        'created_at': '2026-05-03T09:00:00Z',
      });
      expect(n.data, isEmpty);
      expect(n.hasTarget, isFalse);
    });

    test('a known type with no id points nowhere rather than at empty', () {
      expect(_n({'type': 'module_assigned'}).hasTarget, isFalse);
      expect(
        _n({'type': 'module_assigned', 'module_id': ''}).hasTarget,
        isFalse,
      );
    });

    test('an unknown type is not followed, whatever it carries', () {
      // A future notification kind must not be opened as if it were a file.
      final n = _n({'type': 'report_filed', 'module_id': 'm-1'});
      expect(n.hasTarget, isFalse);
    });

    test('the payload survives being marked read', () {
      // The card rebuilds from markedRead(); losing the payload there would
      // make a notification openable exactly once.
      final n = _n({'type': 'module_assigned', 'module_id': 'm-42'});
      expect(n.markedRead().moduleId, 'm-42');
      expect(n.withAttachments(const []).moduleId, 'm-42');
    });
  });

  /// Where the inbox goes looking for what a notification carries.
  ///
  /// An urgent report's photographs are filed under the REPORT — another table,
  /// another bucket — and the row announcing it carries none of its own. The
  /// inbox read only `notification_attachments`, so a "بلاغ عاجل" sent with a
  /// photograph arrived as a line of text and the photograph was visible
  /// nowhere in the app.
  group('what a notification carries', () {
    test('an alarm points at its report, and that is where its files are', () {
      // Exactly the payload raise_incident writes (0088).
      final n = _n({
        'type': 'incident',
        'incident_id': 'i-7',
        'module_id': 'm-42',
      });
      expect(n.incidentId, 'i-7');
    });

    test(
      'an alarm raised from nowhere in particular still names its report',
      () {
        // `module_id` is null when the report was raised outside a file — the
        // photographs are no less attached for it.
        final n = _n({
          'type': 'incident',
          'incident_id': 'i-9',
          'module_id': null,
        });
        expect(n.incidentId, 'i-9');
      },
    );

    test('anything else keeps its files in its own group', () {
      expect(
        _n({'type': 'module_broadcast', 'module_id': 'm-1'}).incidentId,
        isNull,
      );
      expect(_n(const {}).incidentId, isNull);
    });

    test('an incident id that is not one is not followed', () {
      expect(_n({'type': 'incident', 'incident_id': ''}).incidentId, isNull);
      expect(_n({'type': 'incident'}).incidentId, isNull);
    });

    test('the pointer survives being marked read and being filled in', () {
      final n = _n({'type': 'incident', 'incident_id': 'i-7'});
      expect(n.markedRead().incidentId, 'i-7');
      expect(n.withAttachments(const []).incidentId, 'i-7');
    });
  });
}

/// The same journey, begun from the phone's own notification tray.
///
/// A push carries the target as FCM `data`, which is strings and only strings.
/// The inbox row and the push are two copies of one fact, and the whole point of
/// [AppNotification.moduleIdIn] is that they cannot disagree — so it is asked
/// here in the shape a push actually arrives in.
void _pushTests() {
  group('a notification tapped in the phone tray', () {
    test('an assignment reaches the same file as the inbox row would', () {
      const data = {'type': 'module_assigned', 'module_id': 'm-7'};
      expect(AppNotification.moduleIdIn(data), 'm-7');
      // And the identical row read from the inbox agrees.
      expect(_n(data).moduleId, 'm-7');
    });

    test('a broadcast to a file reaches that file', () {
      expect(
        AppNotification.moduleIdIn(const {
          'type': 'module_broadcast',
          'module_id': 'm-9',
        }),
        'm-9',
      );
    });

    test('a push with no data at all opens the inbox and nothing more', () {
      expect(AppNotification.moduleIdIn(const {}), isNull);
    });

    test('a push from somewhere else is not followed', () {
      // A test send from the Firebase console, or a future message this build
      // does not understand. It must not be guessed at.
      expect(
        AppNotification.moduleIdIn(const {'type': 'promo', 'module_id': 'm-1'}),
        isNull,
      );
    });
  });

  group('what a tap carries', () {
    test('every value becomes a string, whatever it arrived as', () {
      // iOS hands these back as they were sent; Android as strings. The app
      // must not care which platform it woke up on.
      expect(tapPayload({'type': 'module_broadcast', 'count': 3}), {
        'type': 'module_broadcast',
        'count': '3',
      });
    });

    test('nulls and nested values are dropped rather than stringified', () {
      // '{a: b}' as a module id would be followed as if it were one.
      expect(
        tapPayload({
          'type': 'module_assigned',
          'module_id': 'm-2',
          'empty': null,
          'nested': {'a': 'b'},
          'list': ['a'],
        }),
        {'type': 'module_assigned', 'module_id': 'm-2'},
      );
    });

    test('no payload is an empty map, not null', () {
      // A tap with nothing attached still means "take me to my notifications".
      expect(tapPayload(null), isEmpty);
    });
  });

  group('the tap waits until there is somewhere to put it', () {
    setUp(() => PushService.instance.pendingTap.value = null);

    test('it is taken once and once only', () {
      PushService.instance.pendingTap.value = const {
        'type': 'module_assigned',
        'module_id': 'm-3',
      };
      expect(PushService.instance.takePendingTap(), {
        'type': 'module_assigned',
        'module_id': 'm-3',
      });
      // Coming back to the inbox later must not fling the reader into the file
      // a second time.
      expect(PushService.instance.takePendingTap(), isNull);
    });

    test('nothing waiting is nothing taken', () {
      expect(PushService.instance.takePendingTap(), isNull);
    });
  });
}
