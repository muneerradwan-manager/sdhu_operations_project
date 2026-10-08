import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../seasons/data/seasons_repository.dart';
import '../../seasons/domain/season.dart';
import '../data/permissions_repository.dart';
import '../domain/permission.dart';

enum PermissionAssignStatus { loading, ready, error }

/// What one press of "أسنِد" actually did — how many people, and whether the
/// selected grants were news to any of them. [grants] can be zero with the
/// call still a success: handing a permission to somebody who already holds
/// it is not an error, it is nothing to do.
typedef PermissionAssignResult = ({int users, int grants, String? error});

class PermissionAssignState extends Equatable {
  const PermissionAssignState({
    this.status = PermissionAssignStatus.loading,
    this.catalog = const [],
    this.prerequisites = const {},
    this.seasonId,
    this.selected = const {},
    this.assigning = false,
    this.error,
  });

  final PermissionAssignStatus status;
  final List<Permission> catalog;

  /// permission id → the ids it requires — the same rows the DB enforces
  /// with, so what this screen promises is exactly what the server will hold
  /// to.
  final Map<String, Set<String>> prerequisites;

  /// The season the employee picker lists — the one page every assignment in
  /// this app chooses people through, and it deals in a season's
  /// participants. Null when no season is under way, in which case there is
  /// nobody to offer and the screen says so instead of opening an empty page.
  final String? seasonId;

  /// The permissions picked so far. Always CLOSED under prerequisites:
  /// selecting an action pulls its ground in with it, deselecting a ground
  /// drops whatever stood on it — the same rule the per-person editor and the
  /// database both keep, applied to the basket instead of the sheet.
  final Set<String> selected;

  /// True while the grants are being written. One flag for the whole screen:
  /// the basket must not change under a write that is iterating it.
  final bool assigning;

  final String? error;

  PermissionAssignState copyWith({
    PermissionAssignStatus? status,
    List<Permission>? catalog,
    Map<String, Set<String>>? prerequisites,
    String? seasonId,
    Set<String>? selected,
    bool? assigning,
    String? error,
  }) {
    return PermissionAssignState(
      status: status ?? this.status,
      catalog: catalog ?? this.catalog,
      prerequisites: prerequisites ?? this.prerequisites,
      seasonId: seasonId ?? this.seasonId,
      selected: selected ?? this.selected,
      assigning: assigning ?? this.assigning,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    catalog,
    prerequisites,
    seasonId,
    selected,
    assigning,
    error,
  ];
}

/// The permissions-first half of the grant story.
///
/// The per-person editor answers "what may THIS person do" and lives on the
/// employee's own page. This one answers the office's other question — "these
/// five things, who does them" — by holding a basket of permissions and
/// writing it onto several people at once. Three data-entry clerks are one
/// selection and one press, not three visits to three sheets.
class PermissionAssignCubit extends SafeCubit<PermissionAssignState> {
  PermissionAssignCubit(this._repo) : super(const PermissionAssignState()) {
    load();
  }

  final PermissionsRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: PermissionAssignStatus.loading));
    try {
      final results = await Future.wait([
        _repo.fetchCatalog(),
        _repo.fetchPrerequisites(),
        // The season, because the people are not loaded here at all: choosing
        // them happens on the one employee-picker page every assignment in
        // this app goes through, and that page lists a season's participants.
        SeasonsRepository().fetchCurrentSeason(),
      ]);
      emit(
        state.copyWith(
          status: PermissionAssignStatus.ready,
          catalog: results[0] as List<Permission>,
          prerequisites: results[1] as Map<String, Set<String>>,
          seasonId: (results[2] as Season?)?.id,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PermissionAssignStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  List<Permission> childrenOf(String parentId) =>
      state.catalog.where((p) => p.parentId == parentId).toList();

  /// Everything [id] transitively requires, whether or not it is selected.
  Set<String> _requirementsOf(String id) {
    final out = <String>{};
    void visit(String p) {
      for (final req in state.prerequisites[p] ?? const <String>{}) {
        if (out.add(req)) visit(req);
      }
    }

    visit(id);
    return out;
  }

  /// The selected permissions that stand on [id], transitively — what
  /// dropping [id] from the basket takes with it.
  Set<String> _selectedDependentsOf(String id) => {
    for (final s in state.selected)
      if (s != id && _requirementsOf(s).contains(id)) s,
  };

  /// Puts one action in or out of the basket, keeping the basket closed under
  /// prerequisites both ways. Sections are headings, not grants.
  void toggle(String permissionId) {
    if (state.assigning) return;
    final perm = state.catalog.firstWhere((p) => p.id == permissionId);
    if (perm.isParent) return;

    if (state.selected.contains(permissionId)) {
      emit(
        state.copyWith(
          selected: state.selected.difference({
            permissionId,
            ..._selectedDependentsOf(permissionId),
          }),
        ),
      );
    } else {
      emit(
        state.copyWith(
          selected: {
            ...state.selected,
            ..._requirementsOf(permissionId),
            permissionId,
          },
        ),
      );
    }
  }

  /// The whole section in one act — a basket screen exists for bulk, and
  /// "everything under الملفات" is the commonest bulk there is.
  void setSection(String parentId, bool select) {
    if (state.assigning) return;
    final children = childrenOf(parentId);
    if (select) {
      emit(
        state.copyWith(
          selected: {
            ...state.selected,
            for (final c in children) ...[..._requirementsOf(c.id), c.id],
          },
        ),
      );
    } else {
      final dropped = <String>{
        for (final c in children) ...{c.id, ..._selectedDependentsOf(c.id)},
      };
      emit(state.copyWith(selected: state.selected.difference(dropped)));
    }
  }

  void clearSelection() {
    if (state.assigning) return;
    emit(state.copyWith(selected: const {}));
  }

  /// The basket, ordered so every requirement precedes what requires it — the
  /// order the rows must be written in, because the DB refuses a grant whose
  /// ground is absent.
  List<String> _ordered() {
    final out = <String>[];
    void visit(String id) {
      if (out.contains(id)) return;
      for (final req in state.prerequisites[id] ?? const <String>{}) {
        if (state.selected.contains(req)) visit(req);
      }
      out.add(id);
    }

    for (final id in state.selected) {
      visit(id);
    }
    return out;
  }

  /// Writes the basket onto every chosen person, skipping what each already
  /// holds. All-or-nothing per person, best-effort across people: a failure
  /// stops the run and reports, and whoever was already written stays
  /// written — a grant is idempotent to repeat, so pressing again finishes
  /// the job rather than doubling it.
  Future<PermissionAssignResult> assign(Set<String> userIds) async {
    if (state.selected.isEmpty || userIds.isEmpty) {
      return (users: 0, grants: 0, error: null);
    }
    emit(state.copyWith(assigning: true));
    final ordered = _ordered();
    var users = 0;
    var grants = 0;
    try {
      for (final userId in userIds) {
        // Re-read rather than assumed: the point of skipping is that granting
        // twice is a unique-key violation, and what somebody holds may have
        // changed since this screen loaded.
        final held = await _repo.fetchGranted(userId);
        final missing = [
          for (final id in ordered)
            if (!held.contains(id)) id,
        ];
        await _repo.grantMany(userId, missing);
        users += 1;
        grants += missing.length;
      }
      // The errand is done; an emptied basket is what says so.
      emit(state.copyWith(assigning: false, selected: const {}));
      return (users: users, grants: grants, error: null);
    } catch (e) {
      emit(state.copyWith(assigning: false));
      return (users: users, grants: grants, error: e.toString());
    }
  }
}
