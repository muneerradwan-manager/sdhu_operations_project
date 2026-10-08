import 'package:equatable/equatable.dart';

import 'audit_event.dart';

/// How wide one point of a summary's series is.
///
/// Chosen by the database from the span asked for, not by the app — and sent
/// back with the answer so the axis is labelled with what was actually counted.
/// A chart whose points are weeks and whose labels say days is worse than no
/// chart.
enum AuditBucket {
  day,
  week,
  month;

  static AuditBucket fromName(String? name) => AuditBucket.values.firstWhere(
    (b) => b.name == name,
    orElse: () => AuditBucket.day,
  );
}

/// One bucket of the log's activity: when it starts, and how much happened in
/// it. A bucket nothing happened in is present with a zero — the series is
/// gap-filled server-side, because a line drawn straight across the days a
/// mission was quiet invents the traffic it skipped.
class AuditPoint extends Equatable {
  const AuditPoint({required this.at, required this.count});

  final DateTime at;
  final int count;

  @override
  List<Object?> get props => [at, count];
}

/// How many of each kind of act, over the same window.
class AuditActionCount extends Equatable {
  const AuditActionCount({required this.action, required this.count});

  final AuditAction action;
  final int count;

  @override
  List<Object?> get props => [action, count];
}

/// The log describing itself: what happened over a window, counted where the
/// rows are.
///
/// Counted by `audit_summary` (0111) and NOT derived from the pages the screen
/// happens to be holding. The list is keyset-paged fifty at a time, so the
/// events in memory are the log's most recent end rather than a sample of it; a
/// chart drawn from them would report activity falling every time somebody
/// scrolled far enough back, and would report it in the confident voice of a
/// picture.
///
/// [from]–[to] is the reader's own date filter when they set one and the last
/// thirty days when they did not, which is why it is carried here and said in
/// words above the chart. Every other filter on the screen — actor, action,
/// section, search — narrows this identically to the way it narrows the list.
class AuditSummary extends Equatable {
  const AuditSummary({
    required this.from,
    required this.to,
    required this.bucket,
    required this.total,
    required this.actors,
    required this.series,
    required this.byAction,
  });

  final DateTime from;
  final DateTime to;
  final AuditBucket bucket;

  /// Events in the window, after every filter.
  final int total;

  /// Distinct people. The system's own rows have no actor and are not one.
  final int actors;

  final List<AuditPoint> series;
  final List<AuditActionCount> byAction;

  bool get isEmpty => total == 0;

  /// The busiest bucket, for the one sentence a shape cannot say on its own.
  /// Null when nothing happened at all.
  AuditPoint? get busiest {
    if (series.isEmpty) return null;
    final peak = series.reduce((a, b) => b.count > a.count ? b : a);
    return peak.count == 0 ? null : peak;
  }

  static AuditSummary fromMap(Map<String, dynamic> map) => AuditSummary(
    from: DateTime.parse(map['from'] as String).toLocal(),
    to: DateTime.parse(map['to'] as String).toLocal(),
    bucket: AuditBucket.fromName(map['bucket'] as String?),
    total: (map['total'] as num?)?.toInt() ?? 0,
    actors: (map['actors'] as num?)?.toInt() ?? 0,
    series: [
      for (final row in (map['series'] as List? ?? const []))
        AuditPoint(
          at: DateTime.parse((row as Map)['day'] as String).toLocal(),
          count: (row['n'] as num?)?.toInt() ?? 0,
        ),
    ],
    byAction: [
      for (final row in (map['by_action'] as List? ?? const []))
        AuditActionCount(
          action: AuditAction.fromName((row as Map)['key'] as String?),
          count: (row['n'] as num?)?.toInt() ?? 0,
        ),
    ],
  );

  @override
  List<Object?> get props => [
    from,
    to,
    bucket,
    total,
    actors,
    series,
    byAction,
  ];
}
