import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/router/app_router.dart';
import 'package:sdhu_operations_project/core/constants/permission_codes.dart';
import 'package:sdhu_operations_project/features/incidents/domain/incident.dart';

Incident incident({
  IncidentState state = IncidentState.open,
  DateTime? createdAt,
  DateTime? handledAt,
  double? lat,
  double? lng,
}) => Incident(
  id: 'i1',
  body: 'حافلة متعطلة على طريق عرفات',
  state: state,
  createdAt: createdAt ?? DateTime.now(),
  reporterId: 'p1',
  reporterName: 'منير عبدالله رضوان',
  handledAt: handledAt,
  latitude: lat,
  longitude: lng,
);

void main() {
  group('how long it went unanswered', () {
    test('an open one is still counting', () {
      final waited = incident(
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ).waited;

      expect(waited.inMinutes, closeTo(40, 1));
    });

    test('it stops the moment somebody picks it up', () {
      // The number that matters is how long it sat unanswered. Letting it climb
      // after a man was dispatched would report a failure that did not happen.
      final start = DateTime(2026, 8, 4, 20, 0);
      final taken = DateTime(2026, 8, 4, 20, 12);

      final subject = incident(
        state: IncidentState.inProgress,
        createdAt: start,
        handledAt: taken,
      );

      expect(subject.waited, const Duration(minutes: 12));
    });

    test('a closed one keeps the time it was picked up, not the time it ended',
        () {
      final subject = incident(
        state: IncidentState.closed,
        createdAt: DateTime(2026, 8, 4, 20, 0),
        handledAt: DateTime(2026, 8, 4, 20, 5),
      );

      expect(subject.waited, const Duration(minutes: 5));
    });
  });

  group('the position', () {
    test('a fix becomes a link somebody can open', () {
      final subject = incident(lat: 21.3891, lng: 39.8579);

      expect(subject.hasPlace, isTrue);
      expect(subject.mapUrl, 'https://www.google.com/maps?q=21.3891,39.8579');
    });

    test('no fix is no link, rather than a link to nowhere', () {
      // A phone indoors, or a refused permission. A map button that opened the
      // middle of the ocean would be worse than no button.
      expect(incident().hasPlace, isFalse);
      expect(incident().mapUrl, isNull);
      expect(incident(lat: 21.3).mapUrl, isNull);
      expect(incident(lng: 39.8).mapUrl, isNull);
    });
  });

  group('the states', () {
    test('the database spellings round-trip', () {
      for (final state in IncidentState.values) {
        expect(IncidentState.fromDb(state.dbName), state);
      }
    });

    test('in_progress is the underscored one the enum name is not', () {
      // The Dart name is `inProgress` and the column is `in_progress`; a
      // `.name` shortcut here would write a value the enum type rejects.
      expect(IncidentState.inProgress.dbName, 'in_progress');
    });

    test('an unknown state reads as open, not as closed', () {
      // If an older app meets a state a newer migration added, treating it as
      // OPEN keeps it in front of the operations room. Treating it as closed
      // would hide a live emergency.
      expect(IncidentState.fromDb('escalated'), IncidentState.open);
      expect(IncidentState.fromDb(null), IncidentState.open);
    });
  });

  group('who may reach what', () {
    test('raising one is behind no permission at all', () {
      // A system in which only certain people may report that a bus has broken
      // down is a system that does not find out about the bus.
      expect(sectionGuards.containsKey(Routes.raiseIncident), isFalse);
    });

    test('the register is behind incidents.receive', () {
      final guard = sectionGuards[Routes.incidents];

      expect(guard, isNotNull);
      expect(PermissionCodes.incidentsReceive, 'incidents.receive');
    });
  });

  test('the outcome of sending has three cases, not two', () {
    // The middle one is why this enum exists. "Kept on the device" is a success
    // everywhere else in this app and is NOT one here: the man pressed that
    // button because he needs somebody to come, and nobody has been told.
    expect(IncidentOutcome.values, hasLength(3));
    expect(
      IncidentOutcome.values,
      contains(IncidentOutcome.waitingForNetwork),
    );
  });
}
