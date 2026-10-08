import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/audit/domain/audit_event.dart';
import 'package:sdhu_operations_project/features/audit/domain/audit_summary.dart';
import 'package:sdhu_operations_project/features/audit/presentation/widgets/audit_pulse.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// The log describing itself.
///
/// The whole reason this arrived as a server-counted summary rather than
/// something the screen works out for itself is in [AuditSummary]'s own doc:
/// the list is keyset-paged fifty at a time, so what the screen holds is the
/// log's most recent END, not a sample of it. These tests guard the reading of
/// that answer — and, at the bottom, that it can be drawn.
void main() {
  group('reading the summary', () {
    Map<String, dynamic> payload({
      List<Map<String, dynamic>>? series,
      List<Map<String, dynamic>>? byAction,
      int total = 5,
      int actors = 2,
      String bucket = 'day',
    }) => {
      'from': '2026-07-11T00:00:00Z',
      'to': '2026-07-14T00:00:00Z',
      'bucket': bucket,
      'total': total,
      'actors': actors,
      'series':
          series ??
          [
            {'day': '2026-07-11T00:00:00Z', 'n': 3},
            {'day': '2026-07-12T00:00:00Z', 'n': 0},
            {'day': '2026-07-13T00:00:00Z', 'n': 2},
          ],
      'by_action':
          byAction ??
          [
            {'key': 'update', 'n': 3},
            {'key': 'insert', 'n': 2},
          ],
    };

    test('a day nothing happened on is a zero, not a missing day', () {
      final s = AuditSummary.fromMap(payload());

      // Gap-filled server-side. A line drawn straight from the 11th to the 13th
      // over an absent 12th invents traffic on the day the mission was quiet.
      expect(s.series, hasLength(3));
      expect(s.series[1].count, 0);
      expect(s.total, 5);
      expect(s.actors, 2);
    });

    test('the bucket comes from the answer, not from the app', () {
      // A chart whose points are weeks and whose labels say days is worse than
      // no chart, so the width of a point is the database's to state.
      expect(AuditSummary.fromMap(payload()).bucket, AuditBucket.day);
      expect(
        AuditSummary.fromMap(payload(bucket: 'week')).bucket,
        AuditBucket.week,
      );
      expect(
        AuditSummary.fromMap(payload(bucket: 'month')).bucket,
        AuditBucket.month,
      );
      // An unknown width is read as a day rather than thrown over: the chart
      // is worth drawing even if a later migration invents a fourth.
      expect(
        AuditSummary.fromMap(payload(bucket: 'fortnight')).bucket,
        AuditBucket.day,
      );
    });

    test('the kinds of act arrive as the enum the filter uses', () {
      final s = AuditSummary.fromMap(payload());
      expect(s.byAction.first.action, AuditAction.update);
      expect(s.byAction.first.count, 3);
      expect(s.byAction.last.action, AuditAction.insert);
    });

    test('the busiest bucket is a real one, or none at all', () {
      expect(AuditSummary.fromMap(payload()).busiest!.count, 3);

      // A window of nothing has no busiest day — and saying "the busiest day
      // was Tuesday, with zero" is worse than saying nothing.
      final quiet = AuditSummary.fromMap(
        payload(
          total: 0,
          actors: 0,
          series: [
            {'day': '2026-07-11T00:00:00Z', 'n': 0},
            {'day': '2026-07-12T00:00:00Z', 'n': 0},
          ],
          byAction: [],
        ),
      );
      expect(quiet.busiest, isNull);
      expect(quiet.isEmpty, isTrue);
    });

    test('an empty window still parses into a drawable answer', () {
      final s = AuditSummary.fromMap({
        'from': '2026-07-11T00:00:00Z',
        'to': '2026-07-14T00:00:00Z',
        'bucket': 'day',
        'total': 0,
        'actors': 0,
        'series': <dynamic>[],
        'by_action': <dynamic>[],
      });
      expect(s.series, isEmpty);
      expect(s.byAction, isEmpty);
      expect(s.isEmpty, isTrue);
    });
  });

  group('the pulse', () {
    Widget wrap(AuditSummary summary) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 900,
          height: 600,
          child: AuditPulse(summary: summary),
        ),
      ),
    );

    AuditSummary summary({
      required List<AuditPoint> series,
      List<AuditActionCount> byAction = const [],
      int total = 0,
      int actors = 0,
      AuditBucket bucket = AuditBucket.day,
    }) => AuditSummary(
      from: DateTime(2026, 7, 11),
      to: DateTime(2026, 7, 14),
      bucket: bucket,
      total: total,
      actors: actors,
      series: series,
      byAction: byAction,
    );

    testWidgets('draws the window it was counted over, in words', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          summary(
            total: 5,
            actors: 2,
            series: [
              for (var i = 0; i < 3; i++)
                AuditPoint(at: DateTime(2026, 7, 11 + i), count: i),
            ],
            byAction: const [
              AuditActionCount(action: AuditAction.update, count: 3),
              AuditActionCount(action: AuditAction.insert, count: 2),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      // The window is never left to be guessed: it is the reader's own date
      // filter when they set one and the last thirty days when they did not,
      // and the chart means a different thing in each case.
      expect(find.text('11 Jul – 14 Jul'), findsNWidgets(2));
      expect(find.text('5 events'), findsOneWidget);
      expect(find.text('2 people'), findsOneWidget);
    });

    testWidgets('a window with nothing in it says so rather than drawing zero', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(summary(series: const [])));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('Nothing happened in this window'), findsOneWidget);
      expect(find.text('no events'), findsOneWidget);
    });
  });
}
