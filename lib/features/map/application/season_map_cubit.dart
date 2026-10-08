import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../incidents/data/incidents_repository.dart';
import '../../incidents/domain/incident.dart';
import '../data/season_map_repository.dart';
import '../domain/map_place.dart';

enum SeasonMapStatus { loading, ready, error }

class SeasonMapState extends Equatable {
  const SeasonMapState({
    this.status = SeasonMapStatus.loading,
    this.places = const [],
    this.incidents = const [],
    this.showPlaces = true,
    this.showIncidents = true,
    this.hiddenGroups = const {},
    this.error,
  });

  final SeasonMapStatus status;
  final List<MapPlace> places;

  /// Only the ones still open, and only the ones that said where they were.
  final List<Incident> incidents;

  final bool showPlaces;
  final bool showIncidents;

  /// The groups switched OFF, by key.
  ///
  /// Stored as what is hidden rather than what is shown, so that a group which
  /// appears for the first time — a file created mid-season, a hotel given a
  /// city — arrives visible. Storing the visible set would make every new group
  /// invisible until somebody noticed it was missing, which is the one state a
  /// map must never be in.
  final Set<String> hiddenGroups;

  final String? error;

  /// The groups present, in the order the server sent them, each with its
  /// label and how many places it holds.
  List<MapGroup> get groups {
    final seen = <String, MapGroup>{};
    for (final place in places) {
      final existing = seen[place.groupKey];
      seen[place.groupKey] = MapGroup(
        key: place.groupKey,
        name: place.groupName,
        count: (existing?.count ?? 0) + 1,
      );
    }
    return seen.values.toList();
  }

  Iterable<MapPlace> get drawnPlaces => showPlaces
      ? places.where((p) => !hiddenGroups.contains(p.groupKey))
      : const [];
  Iterable<Incident> get drawnIncidents => showIncidents ? incidents : const [];

  int get needingAttention =>
      places.where((p) => p.condition.wantsAttention).length;

  SeasonMapState copyWith({
    SeasonMapStatus? status,
    List<MapPlace>? places,
    List<Incident>? incidents,
    bool? showPlaces,
    bool? showIncidents,
    Set<String>? hiddenGroups,
    String? error,
  }) => SeasonMapState(
    status: status ?? this.status,
    places: places ?? this.places,
    incidents: incidents ?? this.incidents,
    showPlaces: showPlaces ?? this.showPlaces,
    showIncidents: showIncidents ?? this.showIncidents,
    hiddenGroups: hiddenGroups ?? this.hiddenGroups,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    places,
    incidents,
    showPlaces,
    showIncidents,
    hiddenGroups,
    error,
  ];
}

/// The season, drawn.
///
/// Two sources on one map, and they are fetched separately on purpose. The
/// places come from `season_map`; the incidents come from the register they
/// already live in, at the coordinates the reporter's phone gave — which is
/// frequently nowhere near a place this app knows about. A bus broken down on
/// the road to Arafat is the case that matters, and attaching it to the nearest
/// camp would draw the marker somewhere nobody has to go.
class SeasonMapCubit extends SafeCubit<SeasonMapState> {
  SeasonMapCubit(this._places, this._incidents) : super(const SeasonMapState()) {
    load();
  }

  /// A cubit standing on a state that is already loaded.
  ///
  /// For exercising the filter without a repository or a network behind it —
  /// which is most of what there is to get wrong here, and none of it needs a
  /// server to be wrong in.
  @visibleForTesting
  SeasonMapCubit.forTest(super.initial)
    : _places = SeasonMapRepository(),
      _incidents = IncidentsRepository();

  final SeasonMapRepository _places;
  final IncidentsRepository _incidents;

  Future<void> load() async {
    try {
      final places = await _places.fetchPlaces();

      // The incidents are a SECOND question and are allowed to fail on their
      // own. Whoever may see the map need not hold `incidents.receive`, and a
      // map that refused to draw because he does not would be a map that
      // punishes him for what he is not.
      var incidents = const <Incident>[];
      try {
        incidents = [
          for (final incident in await _incidents.fetchList())
            if (incident.hasPlace && !incident.state.isClosed) incident,
        ];
      } catch (_) {
        // Left empty, and the layer simply has nothing in it.
      }

      emit(
        state.copyWith(
          status: SeasonMapStatus.ready,
          places: places,
          incidents: incidents,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: SeasonMapStatus.error, error: e.toString()));
    }
  }

  void setShowPlaces(bool value) => emit(state.copyWith(showPlaces: value));
  void setShowIncidents(bool value) =>
      emit(state.copyWith(showIncidents: value));

  void toggleGroup(String key) {
    final hidden = {...state.hiddenGroups};
    if (!hidden.remove(key)) hidden.add(key);
    emit(state.copyWith(hiddenGroups: hidden));
  }

  /// Shows one group and nothing else — "just the camps of Mina".
  ///
  /// The gesture the filter is actually for. Switching four groups off one at
  /// a time to look at the fifth is the same work the map was meant to save.
  void showOnly(String key) => emit(
    state.copyWith(
      hiddenGroups: {
        for (final group in state.groups)
          if (group.key != key) group.key,
      },
    ),
  );

  void showAllGroups() => emit(state.copyWith(hiddenGroups: const {}));
}
