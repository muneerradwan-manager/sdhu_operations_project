import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/utils/device_position.dart';
import '../../../core/utils/network_error.dart';
import '../data/incidents_outbox.dart';
import '../data/incidents_repository.dart';
import '../domain/incident.dart';

enum IncidentsStatus { loading, ready, error }

/// Whose reports the screen is showing.
///
/// The same split [ComplaintsScope] draws, and for the same reason: `mine` is
/// عام ← بلاغاتي and is everybody's — what this account raised, whatever else
/// it may hold — and `all` is the operations room's register, gated by
/// `incidents.receive`. One screen answers both; what differs is which
/// question it asks the server (see `IncidentsRepository.fetchList`'s
/// `mineOnly`), not two lists kept in sync by hand.
enum IncidentsScope { mine, all }

class IncidentsState extends Equatable {
  const IncidentsState({
    this.scope = IncidentsScope.all,
    this.status = IncidentsStatus.loading,
    this.incidents = const [],
    this.includeClosed = false,
    this.focusId,
    this.error,
  });

  final IncidentsScope scope;
  final IncidentsStatus status;
  final List<Incident> incidents;
  final bool includeClosed;

  /// The one report the register was opened FOR, when it was opened from an
  /// alarm in the inbox rather than from the menu.
  ///
  /// The register is a screen somebody watches; arriving at it from a tap on
  /// "بلاغ عاجل" is a different errand — the reader has one report in mind and
  /// wants it, not a list to find it in. So the list narrows to it and offers
  /// the way back out to the whole register.
  final String? focusId;

  final String? error;

  int get openCount =>
      incidents.where((incident) => incident.state.isOpen).length;

  /// What the screen draws: everything, or the one report it was opened for.
  List<Incident> get visible => switch (focusId) {
    final id? => incidents.where((incident) => incident.id == id).toList(),
    _ => incidents,
  };

  /// Opened for a report the register no longer holds — struck off since, or
  /// past the end of what the list fetches. Said in so many words rather than
  /// drawn as an empty register, which would read as "there are no emergencies"
  /// to somebody who was just told there was one.
  bool get focusMissing =>
      focusId != null && status == IncidentsStatus.ready && visible.isEmpty;

  IncidentsState copyWith({
    IncidentsStatus? status,
    List<Incident>? incidents,
    bool? includeClosed,
    String? error,
    bool clearFocus = false,
  }) => IncidentsState(
    scope: scope,
    status: status ?? this.status,
    incidents: incidents ?? this.incidents,
    includeClosed: includeClosed ?? this.includeClosed,
    focusId: clearFocus ? null : focusId,
    error: error,
  );

  @override
  List<Object?> get props => [
    scope,
    status,
    incidents,
    includeClosed,
    focusId,
    error,
  ];
}

/// The register, for whoever receives urgent reports — or one person's own.
class IncidentsCubit extends SafeCubit<IncidentsState> {
  IncidentsCubit(
    this._repo, {
    IncidentsScope scope = IncidentsScope.all,
    String? focusId,
  }) : super(
         IncidentsState(
           scope: scope,
           focusId: focusId,
           // A report tapped in the inbox may well have been dealt with while
           // the reader was walking to the phone. Opening the register on it
           // and finding nothing, because closed ones are hidden by default,
           // would be the app losing something it had just announced.
           //
           // بلاغاتي carries the same true default for a plainer reason: it
           // is a short personal history, not a live board to keep tidy, and
           // "was this ever dealt with" is exactly what somebody checking on
           // their own report wants answered without a switch to find first.
           includeClosed: focusId != null || scope == IncidentsScope.mine,
         ),
       ) {
    load();
  }

  final IncidentsRepository _repo;

  /// How deep to read when the register was opened for one report.
  ///
  /// The list comes back oldest-open-first, so a report raised this minute sits
  /// at the far end of it. The ordinary hundred is the right size for a screen
  /// somebody is watching and the wrong size for finding one row in a season's
  /// worth — and this read happens once, on arrival from a tap.
  static const _focusedLimit = 500;

  Future<void> load() async {
    try {
      final incidents = await _repo.fetchList(
        includeClosed: state.includeClosed,
        limit: state.focusId == null ? 100 : _focusedLimit,
        mineOnly: state.scope == IncidentsScope.mine,
      );
      emit(state.copyWith(status: IncidentsStatus.ready, incidents: incidents));
    } catch (e) {
      emit(state.copyWith(status: IncidentsStatus.error, error: e.toString()));
    }
  }

  /// Out of the one report and into the whole register — the way back from
  /// having arrived here through an alarm.
  void showAll() => emit(state.copyWith(clearFocus: true));

  Future<void> setIncludeClosed(bool value) async {
    emit(state.copyWith(includeClosed: value));
    await load();
  }

  /// Moves one along. Returns null on success, else what went wrong.
  ///
  /// Deliberately NOT queued when there is no network. Everything else in this
  /// app that a person writes is worth keeping for later; "I have taken this
  /// on" is worth nothing later. It is a claim about right now, made so that
  /// nobody else duplicates the trip, and one that arrives an hour after the
  /// fact has told the room something that stopped being true.
  Future<String?> setState(
    Incident incident,
    IncidentState next, {
    String? resolution,
  }) async {
    try {
      await _repo.setState(
        incidentId: incident.id,
        state: next,
        resolution: resolution,
      );
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Strikes one off. Returns null on success, else what went wrong.
  ///
  /// Not queued when the network is down, for the same reason [setState] is not:
  /// the register is what several people are reading at once, and a deletion
  /// that lands an hour later removes a row somebody has since acted on.
  Future<String?> delete(Incident incident) async {
    try {
      await _repo.delete(incident.id);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Empties it. Returns how many went, or the error.
  Future<({int deleted, String? error})> deleteAll({
    bool onlyClosed = true,
  }) async {
    try {
      final deleted = await _repo.deleteAll(onlyClosed: onlyClosed);
      await load();
      return (deleted: deleted, error: null);
    } catch (e) {
      return (deleted: 0, error: e.toString());
    }
  }
}

/// Raising one. A plain function, because it is called from a button that may
/// be anywhere in the app.
abstract final class RaiseIncident {
  static Future<IncidentOutcome> send(
    PendingIncident pending, {
    IncidentsRepository? repository,
  }) async {
    final repo = repository ?? IncidentsRepository();

    // Taken first, and never allowed to hold anything up: a position that has
    // not arrived in a few seconds is not worth the delay when somebody is
    // waiting for help. `currentPositionOrNull` gives up quietly.
    final position = await currentPositionOrNull(
      timeout: const Duration(seconds: 8),
    );

    try {
      await repo.raise(
        body: pending.body,
        moduleId: pending.moduleId,
        nodeId: pending.nodeId,
        subjectProfileId: pending.subjectProfileId,
        appRoute: pending.appRoute,
        appLabel: pending.appLabel,
        latitude: position?.latitude,
        longitude: position?.longitude,
        accuracy: position?.accuracy,
        attachments: pending.attachments,
      );
      return IncidentOutcome.sent;
    } catch (error) {
      if (!looksLikeNetworkFailure(error)) return IncidentOutcome.failed;

      // Kept, so it is not lost — but the caller MUST tell the person that
      // nobody has been alerted. See [IncidentOutcome.waitingForNetwork].
      if (!Outbox.isInstalled) return IncidentOutcome.failed;
      try {
        await Outbox.instance.add(
          kind: IncidentsOutbox.kind,
          payload: IncidentsOutbox.payload(
            body: pending.body,
            moduleId: pending.moduleId,
            nodeId: pending.nodeId,
            subjectProfileId: pending.subjectProfileId,
            appRoute: pending.appRoute,
            appLabel: pending.appLabel,
            latitude: position?.latitude,
            longitude: position?.longitude,
            accuracy: position?.accuracy,
          ),
          label: pending.body,
          attachments: pending.attachments,
        );
        return IncidentOutcome.waitingForNetwork;
      } catch (_) {
        return IncidentOutcome.failed;
      }
    }
  }
}
