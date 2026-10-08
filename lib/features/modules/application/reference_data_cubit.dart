import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../seasons/data/seasons_repository.dart';
import '../../seasons/domain/season.dart';
import '../data/modules_repository.dart';
import '../domain/reference_item.dart';

enum ReferenceDataStatus { loading, ready, error }

/// Why a write did not go through. `inUse` and `duplicate` are the two an admin
/// will actually hit — deleting a hotel a module was built around, and typing a
/// name that is already on the list.
enum ReferenceOutcome { ok, inUse, duplicate, failed }

class ReferenceResult {
  const ReferenceResult(this.outcome, {this.message});

  final ReferenceOutcome outcome;
  final String? message;

  bool get isOk => outcome == ReferenceOutcome.ok;
}

/// What emptying a list actually managed to do. The two numbers are reported
/// rather than reduced to success or failure, because the interesting case is
/// neither: most of the list goes and a handful stay because a module was built
/// on them.
class BulkDeleteResult {
  const BulkDeleteResult({
    required this.deleted,
    required this.kept,
    this.message,
  });

  final int deleted;
  final int kept;

  /// Set only when something other than the in-use guard refused — a dropped
  /// connection deserves its own words, not "these entries are in use".
  final String? message;
}

class ReferenceDataState extends Equatable {
  const ReferenceDataState({
    this.status = ReferenceDataStatus.loading,
    this.sets = const [],
    this.season,
    this.error,
  });

  final ReferenceDataStatus status;

  /// Every set with every entry it has, in every season. The screen shows only
  /// [season]'s for a scoped set — but the whole list stays here, because
  /// resolving an id to a name must work for last season's entries too.
  final List<ReferenceSet> sets;

  final Season? season;
  final String? error;

  ReferenceSet? setById(String id) =>
      sets.where((s) => s.id == id).firstOrNull;

  /// The entries to SHOW for [setId]: this season's, for a set that is scoped.
  List<ReferenceItem> visibleItems(String setId) {
    final set = setById(setId);
    if (set == null) return const [];
    return set.itemsForSeason(season?.id);
  }

  ReferenceItem? itemById(String setId, String itemId) =>
      setById(setId)?.items.where((i) => i.id == itemId).firstOrNull;

  @override
  List<Object?> get props => [status, sets, season, error];
}

/// Master data the admin owns: the lists that back every dropdown, kept out of
/// free text so the same hotel is one hotel everywhere.
class ReferenceDataCubit extends SafeCubit<ReferenceDataState> {
  ReferenceDataCubit(this._repo, this._seasons)
    : super(const ReferenceDataState()) {
    load();
  }

  final ModulesRepository _repo;
  final SeasonsRepository _seasons;

  /// The season an entry is created into, for a set that is scoped to one.
  String? get seasonId => state.season?.id;

  Future<void> load() async {
    try {
      final season = await _seasons.fetchCurrentSeason();
      final sets = await _repo.fetchReferenceSets(activeOnly: false);
      emit(
        ReferenceDataState(
          status: ReferenceDataStatus.ready,
          sets: sets,
          season: season,
        ),
      );
    } catch (e) {
      emit(
        ReferenceDataState(
          status: ReferenceDataStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  /// Brings another season's entries into the current one. Returns how many
  /// were added, or null when it failed.
  Future<int?> importFromSeason({
    required String setId,
    required String fromSeasonId,
  }) async {
    final to = state.season?.id;
    if (to == null) return null;
    try {
      final copied = await _repo.copyReferenceItems(
        setId: setId,
        fromSeasonId: fromSeasonId,
        toSeasonId: to,
      );
      await load();
      return copied;
    } catch (_) {
      return null;
    }
  }

  /// How full one place is in the season in force. Not held in state: it is one
  /// entry's figure on one page, and putting it in the list's state would mean
  /// counting every hotel in the season to draw a page about one of them.
  Future<PlaceOccupancy?> occupancyOf(String itemId) async {
    try {
      return await _repo.fetchPlaceOccupancy(
        itemId: itemId,
        seasonId: state.season?.id,
      );
    } catch (_) {
      return null;
    }
  }

  /// The seasons an import could draw from: every one but the one in force.
  Future<List<Season>> otherSeasons() async {
    final seasons = await _seasons.fetchSeasons();
    return seasons.where((s) => s.id != state.season?.id).toList();
  }

  Future<ReferenceResult> addItem({
    required String setId,
    required String nameAr,
    String? nameEn,
    Map<String, dynamic> data = const {},
  }) async {
    return _write(
      () => _repo.addReferenceItem(
        setId: setId,
        nameAr: nameAr,
        nameEn: nameEn,
        data: data,
        // Stamped only for a scoped set: a new hotel is a hotel of THIS season,
        // a new city is a city.
        seasonId: (state.setById(setId)?.isSeasonScoped ?? false)
            ? seasonId
            : null,
      ),
    );
  }

  Future<ReferenceResult> updateItem({
    required String id,
    required String nameAr,
    String? nameEn,
    Map<String, dynamic> data = const {},
  }) async {
    return _write(
      () => _repo.updateReferenceItem(
        id: id,
        nameAr: nameAr,
        nameEn: nameEn,
        data: data,
      ),
    );
  }

  Future<ReferenceResult> deleteItem(String id) =>
      _write(() => _repo.deleteReferenceItem(id));

  /// Removes every entry in [ids], one row at a time.
  ///
  /// One statement would be a single trip, but the guard is a BEFORE DELETE
  /// trigger that raises: one entry a module was built on would abort the whole
  /// delete and the list would come back untouched. Row by row, what can go
  /// goes and the rest are counted.
  ///
  /// Entries also point at each other — a مجموعة at its تكتل — so a row refused
  /// on the first pass can be free once whatever pointed at it is gone. Passes
  /// repeat while one of them still makes progress, and stop the moment a whole
  /// pass changes nothing: what is left then is genuinely in use.
  Future<BulkDeleteResult> deleteItems(Iterable<String> ids) async {
    var deleted = 0;
    String? failure;
    var remaining = ids.toList();

    while (remaining.isNotEmpty) {
      final refused = <String>[];
      for (final id in remaining) {
        try {
          await _repo.deleteReferenceItem(id);
          deleted++;
        } catch (e) {
          final text = e.toString();
          if (!text.contains('reference_item_in_use')) failure ??= text;
          refused.add(id);
        }
      }
      if (refused.length == remaining.length) break;
      remaining = refused;
    }

    await load();
    return BulkDeleteResult(
      deleted: deleted,
      kept: remaining.length,
      message: failure,
    );
  }

  Future<ReferenceResult> _write(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return const ReferenceResult(ReferenceOutcome.ok);
    } catch (e) {
      // The delete guard raises this sentinel; it deserves its own message
      // rather than a raw Postgres error.
      final text = e.toString();
      if (text.contains('reference_item_in_use')) {
        return const ReferenceResult(ReferenceOutcome.inUse);
      }
      // The (set_id, name_ar) unique index — the whole point of master data.
      if (text.contains('duplicate key') || text.contains('23505')) {
        return const ReferenceResult(ReferenceOutcome.duplicate);
      }
      return ReferenceResult(ReferenceOutcome.failed, message: text);
    }
  }
}
