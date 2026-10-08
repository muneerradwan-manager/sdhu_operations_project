import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/permissions_repository.dart';
import '../domain/permission.dart';

enum PermissionEditorStatus { loading, ready, error }

class PermissionEditorState extends Equatable {
  const PermissionEditorState({
    this.status = PermissionEditorStatus.loading,
    this.catalog = const [],
    this.prerequisites = const {},
    this.granted = const {},
    this.busy = const {},
    this.error,
  });

  final PermissionEditorStatus status;
  final List<Permission> catalog;

  /// permission id → the ids it requires. The same rows the DB enforces with,
  /// so what this editor promises is exactly what the server will hold to.
  final Map<String, Set<String>> prerequisites;
  final Set<String> granted; // permission ids
  final Set<String> busy; // permission ids currently toggling
  final String? error;

  PermissionEditorState copyWith({
    PermissionEditorStatus? status,
    List<Permission>? catalog,
    Map<String, Set<String>>? prerequisites,
    Set<String>? granted,
    Set<String>? busy,
    String? error,
  }) {
    return PermissionEditorState(
      status: status ?? this.status,
      catalog: catalog ?? this.catalog,
      prerequisites: prerequisites ?? this.prerequisites,
      granted: granted ?? this.granted,
      busy: busy ?? this.busy,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    catalog,
    prerequisites,
    granted,
    busy,
    error,
  ];
}

/// Loads the catalog, the dependency rows and the employee's granted set, and
/// toggles actions — writing through to the DB immediately.
///
/// Sections are headings, not grants; only actions toggle. Granting an action
/// grants its missing prerequisites first (ground before what stands on it —
/// the DB refuses any other order), and revoking one lets the DB cascade the
/// revoke onto everything that required it, then re-reads the sheet so the
/// switches show what actually happened.
class PermissionEditorCubit extends SafeCubit<PermissionEditorState> {
  PermissionEditorCubit(this._repo, this.userId)
    : super(const PermissionEditorState()) {
    _load();
  }

  final PermissionsRepository _repo;
  final String userId;

  Future<void> _load() async {
    emit(state.copyWith(status: PermissionEditorStatus.loading));
    try {
      final results = await Future.wait([
        _repo.fetchCatalog(),
        _repo.fetchPrerequisites(),
        _repo.fetchGranted(userId),
      ]);
      emit(
        state.copyWith(
          status: PermissionEditorStatus.ready,
          catalog: results[0] as List<Permission>,
          prerequisites: results[1] as Map<String, Set<String>>,
          granted: results[2] as Set<String>,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PermissionEditorStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  List<Permission> childrenOf(String parentId) =>
      state.catalog.where((p) => p.parentId == parentId).toList();

  /// The prerequisites of [id] not yet granted, transitively, ordered so every
  /// requirement precedes what requires it.
  List<String> missingPrerequisitesOf(String id) {
    final out = <String>[];
    void visit(String p) {
      for (final req in state.prerequisites[p] ?? const <String>{}) {
        if (state.granted.contains(req) || out.contains(req)) continue;
        visit(req);
        out.add(req);
      }
    }

    visit(id);
    return out;
  }

  /// The granted permissions that stand on [id], transitively — what a revoke
  /// of [id] will take with it.
  Set<String> grantedDependentsOf(String id) {
    bool requires(String p, String target, Set<String> seen) {
      if (!seen.add(p)) return false;
      final reqs = state.prerequisites[p] ?? const <String>{};
      return reqs.contains(target) ||
          reqs.any((r) => requires(r, target, seen));
    }

    return {
      for (final g in state.granted)
        if (g != id && requires(g, id, <String>{})) g,
    };
  }

  /// Toggles an action. Sections have no switch and are refused outright.
  Future<void> toggle(String permissionId) async {
    if (state.busy.contains(permissionId)) return;
    final perm = state.catalog.firstWhere((p) => p.id == permissionId);
    if (perm.isParent) return;
    final isGranted = state.granted.contains(permissionId);

    if (isGranted) {
      // The DB cascades this revoke onto every dependent, so the sheet is
      // re-read afterwards rather than second-guessed.
      final affected = {permissionId, ...grantedDependentsOf(permissionId)};
      emit(state.copyWith(busy: {...state.busy, ...affected}));
      try {
        await _repo.revoke(userId, permissionId);
        final granted = await _repo.fetchGranted(userId);
        emit(
          state.copyWith(
            granted: granted,
            busy: state.busy.difference(affected),
          ),
        );
      } catch (e) {
        emit(
          state.copyWith(
            busy: state.busy.difference(affected),
            error: e.toString(),
          ),
        );
      }
    } else {
      // Ground first: the DB refuses a grant whose prerequisites are absent.
      final chain = [...missingPrerequisitesOf(permissionId), permissionId];
      emit(state.copyWith(busy: {...state.busy, ...chain}));
      try {
        for (final id in chain) {
          await _repo.grant(userId, id);
        }
        emit(
          state.copyWith(
            granted: {...state.granted, ...chain},
            busy: state.busy.difference(chain.toSet()),
          ),
        );
      } catch (e) {
        // A chain may have landed partway; re-read rather than guess. The
        // re-read is itself guarded: the likeliest reason the grant failed is
        // that the network is down, in which case this second call fails the
        // same way — and unguarded it escaped the catch and left every switch
        // in the chain spinning "busy" until the screen was reopened.
        Set<String>? granted;
        try {
          granted = await _repo.fetchGranted(userId);
        } catch (_) {
          // Keep what we believed before the attempt.
        }
        emit(
          state.copyWith(
            granted: granted ?? state.granted,
            busy: state.busy.difference(chain.toSet()),
            error: e.toString(),
          ),
        );
      }
    }
  }
}
