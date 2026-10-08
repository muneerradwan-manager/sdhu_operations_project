import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/l10n/localized_name.dart';
import '../../profile/domain/profile.dart';
import '../data/modules_repository.dart';
import '../domain/module_type.dart';
import '../domain/operational_module.dart';
import '../domain/reference_item.dart';

enum EditorStatus { loading, ready, saving, error }

/// What one step of the wizard is FOR.
///
/// The steps used to be counted rather than named — two for a roster, three for
/// a tree — which held for as long as a file was one thing or the other. تشكيل
/// فرق المشاعر is both: it is divided into قطاعات like the towers file, it stops
/// there rather than going on to hotels, and it carries two teams on the file
/// itself besides. Counting cannot express that; naming can, and each step now
/// appears exactly when the type has something to put in it.
enum EditorStep { info, sectors, towers, teams }

/// Why a save attempt did not go through. Returned from the save methods rather
/// than held in state: the same complaint repeated twice must still produce a
/// second message.
enum SaveOutcome { ok, missingDate, missingField, missingEntry, missingRole, failed }

class SaveResult {
  const SaveResult(this.outcome, {this.name, this.message});

  final SaveOutcome outcome;

  /// The field, entry or role that was left empty.
  final LocalizedName? name;
  final String? message;

  bool get ok => outcome == SaveOutcome.ok;
}

/// A sector or tower as the sheet hands it back: what it is, and who holds each
/// of its roles. Not yet persisted.
class NodeDraft {
  const NodeDraft({
    this.id,
    this.referenceItemId,
    this.secondaryReferenceItemId,
    this.label,
    this.data = const {},
    this.roleMembers = const {},
    this.housing = const {},
  });

  /// Null when adding; set when editing an existing node.
  final String? id;

  /// The master-data entry this node stands for (a hotel), for levels that have
  /// a list.
  final String? referenceItemId;

  /// The entry from the level's second list — the تكتل a برج belongs to. Null
  /// for a level that names no such list.
  final String? secondaryReferenceItemId;

  /// Its name, for levels that have none (a sector).
  final String? label;

  /// The values of the level's own fields — a مخيم's الطاقة الاستيعابية and its
  /// موقع.
  final Map<String, dynamic> data;

  final Map<String, Set<String>> roleMembers;

  /// The hotel each man on this node sleeps in — role id, then profile id, then
  /// the hotel entry. Filled only by levels that are not themselves a place: a
  /// tower member's مسكن is his tower and nobody is asked for it (0139).
  final Map<String, Map<String, String?>> housing;

  Set<String> membersOf(String roleId) => roleMembers[roleId] ?? const {};

  Map<String, String?> housingOf(String roleId) => housing[roleId] ?? const {};
}

class ModuleEditorState extends Equatable {
  const ModuleEditorState({
    this.status = EditorStatus.loading,
    this.step = 0,
    this.type,
    this.moduleId,
    this.startsOn,
    this.endsOn,
    this.startNote,
    this.endNote,
    this.decisionNumber,
    this.values = const {},
    this.pendingFiles = const {},
    this.reportCadence = ReportCadence.none,
    this.nodes = const [],
    this.members = const [],
    this.employees = const [],
    this.referenceSets = const [],
    this.sectorSourceTypeIds = const {},
    this.error,
  });

  final EditorStatus status;

  /// For a file built as a tree: 0 — the file itself, 1 — its sectors, 2 — the
  /// towers inside them. For a file that is only a roster, the tree steps
  /// collapse into one: 0 — the file, 1 — its people.
  final int step;

  final ModuleType? type;

  /// Null until the file has been created; the tree cannot be built before the
  /// row it hangs off exists.
  final String? moduleId;

  final DateTime? startsOn;

  /// When it stops being live, if an end was set. Optional — most files run
  /// until their type's condition is met and nobody writes a date for it.
  final DateTime? endsOn;

  /// ملاحظة بداية العمل — this file's own word about its start, where the
  /// type's standing condition used to be printed. Optional.
  final String? startNote;

  /// ملاحظة نهاية العمل. Optional in the same way.
  final String? endNote;

  /// رقم القرار, if it has been issued yet.
  final String? decisionNumber;

  /// Field values keyed by [ModuleField.key], as they will be persisted.
  final Map<String, dynamic> values;

  /// PDFs chosen on this device but not uploaded yet — a file id is needed for
  /// the storage path, so uploads wait until the row exists.
  final Map<String, File> pendingFiles;

  /// How often this file will ask its members for a report.
  final ReportCadence reportCadence;

  final List<ModuleNode> nodes;

  /// The people on the file itself, for a type with no tree. Each carries the
  /// duties handed to them.
  final List<ModuleMember> members;

  final List<Profile> employees;
  final List<ReferenceSet> referenceSets;

  /// The types whose outermost level means the SAME THING as this file's — the
  /// only files worth importing from. Empty when nothing else divides the way
  /// this file does, and then the offer is not made at all.
  final Set<String> sectorSourceTypeIds;

  final String? error;

  bool get isCreated => moduleId != null;

  /// Whether this file is divided into places at all.
  bool get hasTree => type?.hasTree ?? true;

  /// Whether it carries roles held once for the whole file, beside whatever
  /// tree it may have.
  bool get hasFileRoles => (type?.roles ?? const <ModuleRole>[]).isNotEmpty;

  /// The steps this particular file takes, in order. Each one is here because
  /// the type has something for it: sectors when there is an outermost level,
  /// towers only when a level sits inside that one, teams when roles are held
  /// on the file itself. A roster gets two steps and the towers file three,
  /// exactly as before.
  List<EditorStep> get stepKinds => [
    EditorStep.info,
    if (parentLevel != null) EditorStep.sectors,
    if (childLevel != null) EditorStep.towers,
    if (hasFileRoles) EditorStep.teams,
  ];

  int get lastStep => stepKinds.length - 1;

  /// What the step in force is for. Clamped, because the type arrives after the
  /// first frame and a step index outlives a reload.
  EditorStep get currentStep => stepKinds[step.clamp(0, lastStep)];

  List<ModuleMember> membersOf(String roleId) =>
      members.where((m) => m.roleId == roleId).toList();

  Set<String> memberProfileIdsOf(String roleId) =>
      members.where((m) => m.roleId == roleId).map((m) => m.profileId).toSet();

  /// The sector level, and the tower level inside it.
  ModuleLevel? get parentLevel => type?.outermostLevel;
  ModuleLevel? get childLevel {
    final parent = parentLevel;
    return parent == null ? null : type?.levelBelow(parent);
  }

  List<ModuleNode> get parentNodes {
    final level = parentLevel;
    if (level == null) return const [];
    return nodes.where((n) => n.levelId == level.id).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<ModuleNode> childrenOf(String parentId) =>
      nodes.where((n) => n.parentId == parentId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  ReferenceSet? referenceSetById(String? id) =>
      referenceSets.where((s) => s.id == id).firstOrNull;

  /// The hotels, for the one question a level that is not a place has to ask
  /// out loud: where does this man sleep (0139).
  ReferenceSet? get hotelsSet => referenceSets
      .where((s) => s.code == ReferenceSet.hotelsCode)
      .firstOrNull;

  ReferenceItem? referenceItem(String? setId, String? itemId) {
    if (itemId == null) return null;
    return referenceSetById(setId)?.items.where((i) => i.id == itemId).firstOrNull;
  }

  Profile? profileById(String id) =>
      employees.where((e) => e.id == id).firstOrNull;

  /// Entries already standing at [levelId] in this file. A hotel is entered
  /// once — the database enforces it, and the picker leaves it out rather than
  /// letting someone hit the error.
  Set<String> takenEntries(String levelId, {String? except}) => {
    for (final n in nodes)
      if (n.levelId == levelId && n.id != except && n.referenceItemId != null)
        n.referenceItemId!,
  };

  /// The same for the level's second list: a تكتل is tied to one برج, and the
  /// database has its own unique index saying so.
  Set<String> takenSecondaryEntries(String levelId, {String? except}) => {
    for (final n in nodes)
      if (n.levelId == levelId &&
          n.id != except &&
          n.secondaryReferenceItemId != null)
        n.secondaryReferenceItemId!,
  };

  ModuleEditorState copyWith({
    EditorStatus? status,
    int? step,
    ModuleType? type,
    String? moduleId,
    DateTime? startsOn,
    DateTime? endsOn,
    String? startNote,
    String? endNote,
    String? decisionNumber,
    bool clearEndsOn = false,
    Map<String, dynamic>? values,
    Map<String, File>? pendingFiles,
    ReportCadence? reportCadence,
    List<ModuleNode>? nodes,
    List<ModuleMember>? members,
    List<Profile>? employees,
    List<ReferenceSet>? referenceSets,
    Set<String>? sectorSourceTypeIds,
    String? error,
  }) {
    return ModuleEditorState(
      status: status ?? this.status,
      step: step ?? this.step,
      type: type ?? this.type,
      moduleId: moduleId ?? this.moduleId,
      startsOn: startsOn ?? this.startsOn,
      // Explicitly, because null is a value here: taking an end date off is as
      // real an edit as putting one on, and `??` cannot tell the two apart.
      endsOn: clearEndsOn ? null : (endsOn ?? this.endsOn),
      startNote: startNote ?? this.startNote,
      endNote: endNote ?? this.endNote,
      decisionNumber: decisionNumber ?? this.decisionNumber,
      values: values ?? this.values,
      pendingFiles: pendingFiles ?? this.pendingFiles,
      reportCadence: reportCadence ?? this.reportCadence,
      nodes: nodes ?? this.nodes,
      members: members ?? this.members,
      employees: employees ?? this.employees,
      referenceSets: referenceSets ?? this.referenceSets,
      sectorSourceTypeIds: sectorSourceTypeIds ?? this.sectorSourceTypeIds,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    step,
    type?.id,
    moduleId,
    startsOn,
    endsOn,
    startNote,
    endNote,
    decisionNumber,
    values,
    pendingFiles,
    reportCadence,
    nodes,
    members,
    employees,
    referenceSets,
    sectorSourceTypeIds,
    error,
  ];
}

/// Builds one operational file, in the order it is actually built: the file
/// itself, then its sectors, then the hotels inside each sector.
///
/// Each step is persisted as it is completed rather than held until the end. A
/// file is assembled over days — towers are added as they are confirmed — so
/// there is no moment at which "the whole thing" is ready to be saved at once.
class ModuleEditorCubit extends SafeCubit<ModuleEditorState> {
  ModuleEditorCubit(
    this._repo, {
    required this.moduleTypeId,
    required this.seasonId,
    this.existing,
  }) : super(const ModuleEditorState()) {
    _load();
  }

  final ModulesRepository _repo;
  final String moduleTypeId;
  final String seasonId;
  final OperationalModule? existing;

  bool get isEditing => existing != null;

  Future<void> _load() async {
    try {
      final type = await _repo.fetchModuleType(moduleTypeId);
      if (type == null) {
        emit(
          state.copyWith(
            status: EditorStatus.error,
            error: 'module type not found',
          ),
        );
        return;
      }
      final employees = await _repo.fetchAssignableEmployees(seasonId);
      // Inactive entries stay loaded: a tower may already point at one.
      final sets = await _repo.fetchReferenceSets(activeOnly: false);
      // Not either/or any more: تشكيل فرق المشاعر has both a tree and a roster,
      // so each side is fetched when the TYPE has one rather than when it does
      // not have the other.
      final nodes = existing == null || !type.hasTree
          ? const <ModuleNode>[]
          : await _repo.fetchNodes(existing!.id);
      final members = existing == null || type.roles.isEmpty
          ? const <ModuleMember>[]
          : await _repo.fetchMembers(existing!.id);

      // Which other types divide the way this one does. Worked out once, here,
      // so the sectors step knows whether to offer the import at all rather
      // than offering it and then admitting there is nothing to take.
      final myLevel = type.outermostLevel;
      final sourceTypeIds = myLevel == null
          ? const <String>{}
          : {
              for (final t in await _repo.fetchModuleTypes(activeOnly: false))
                if (t.id != type.id && t.outermostLevel?.code == myLevel.code)
                  t.id,
            };

      emit(
        state.copyWith(
          status: EditorStatus.ready,
          type: type,
          moduleId: existing?.id,
          startsOn: existing?.startsOn,
          endsOn: existing?.endsOn,
          startNote: existing?.startNote,
          endNote: existing?.endNote,
          decisionNumber: existing?.decisionNumber,
          reportCadence: existing?.reportCadence ?? ReportCadence.none,
          values: Map<String, dynamic>.from(existing?.data ?? const {}),
          nodes: nodes,
          members: members,
          employees: employees,
          referenceSets: sets,
          sectorSourceTypeIds: sourceTypeIds,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, error: e.toString()));
    }
  }

  Future<void> _reloadNodes() async {
    final id = state.moduleId;
    if (id == null) return;
    emit(state.copyWith(nodes: await _repo.fetchNodes(id)));
  }

  Future<void> _reloadMembers() async {
    final id = state.moduleId;
    if (id == null) return;
    emit(state.copyWith(members: await _repo.fetchMembers(id)));
  }

  void goTo(int step) => emit(state.copyWith(step: step));

  void setReportCadence(ReportCadence value) =>
      emit(state.copyWith(reportCadence: value));

  void setStartsOn(DateTime value) => emit(state.copyWith(startsOn: value));

  /// Null clears it — a file whose end was set and then thought better of.
  void setEndsOn(DateTime? value) => emit(
    value == null
        ? state.copyWith(clearEndsOn: true)
        : state.copyWith(endsOn: value),
  );

  void setDecisionNumber(String value) =>
      emit(state.copyWith(decisionNumber: value.trim()));

  /// Kept whole while it is being typed — a note is prose, and trimming it on
  /// every keystroke takes the space away before the next word arrives.
  void setStartNote(String value) => emit(state.copyWith(startNote: value));

  void setEndNote(String value) => emit(state.copyWith(endNote: value));

  void setValue(String key, Object? value) {
    final values = Map<String, dynamic>.from(state.values);
    if (value == null || (value is String && value.isEmpty)) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    emit(state.copyWith(values: values));
  }

  void attachFile(String key, File file, String fileName) {
    final pending = Map<String, File>.from(state.pendingFiles)..[key] = file;
    // Shown immediately; the path is filled in once the upload runs on save.
    final values = Map<String, dynamic>.from(state.values)
      ..[key] = {'path': '', 'name': fileName};
    emit(state.copyWith(pendingFiles: pending, values: values));
  }

  /// Blank is nothing, not an empty string standing in for it — what a cleared
  /// box means is that the column should hold no value at all.
  static String? _orNull(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  /// Step 1: the file itself. Creates it on the first pass and updates it
  /// afterwards, then moves on to the sectors.
  Future<SaveResult> saveInfo() async {
    final type = state.type;
    if (type == null) return const SaveResult(SaveOutcome.failed);

    final startsOn = state.startsOn;
    if (startsOn == null) return const SaveResult(SaveOutcome.missingDate);
    // An empty number is no number, not an empty string standing in for one.
    // The same for the two notes: whoever cleared one meant to say nothing.
    final number = _orNull(state.decisionNumber);
    final startNote = _orNull(state.startNote);
    final endNote = _orNull(state.endNote);

    for (final f in type.fields.where((f) => f.isRequired)) {
      final v = state.values[f.key];
      final missing =
          v == null ||
          (v is String && v.trim().isEmpty) ||
          (f.kind == ModuleFieldKind.pdf &&
              ModuleFile.fromJson(v) == null &&
              !state.pendingFiles.containsKey(f.key));
      if (missing) return SaveResult(SaveOutcome.missingField, name: f.label);
    }

    emit(state.copyWith(status: EditorStatus.saving));
    try {
      final values = Map<String, dynamic>.from(state.values);

      // The row has to exist before files can be filed under its id.
      final id =
          state.moduleId ??
          await _repo.createModule(
            moduleTypeId: type.id,
            seasonId: seasonId,
            startsOn: startsOn,
            endsOn: state.endsOn,
            startNote: startNote,
            endNote: endNote,
            decisionNumber: number,
            reportCadence: state.reportCadence,
            data: {
              for (final e in values.entries)
                if (!state.pendingFiles.containsKey(e.key)) e.key: e.value,
            },
          );

      for (final entry in state.pendingFiles.entries) {
        final name =
            (values[entry.key] as Map?)?['name'] as String? ?? 'file.pdf';
        final path = await _repo.uploadModuleFile(
          moduleId: id,
          fileName: name,
          file: entry.value,
          fieldKey: entry.key,
        );
        values[entry.key] = ModuleFile(path: path, name: name).toJson();
      }

      await _repo.updateModule(
        id,
        startsOn: startsOn,
        endsOn: state.endsOn,
        startNote: startNote,
        endNote: endNote,
        decisionNumber: number,
        data: values,
        reportCadence: state.reportCadence,
      );

      emit(
        state.copyWith(
          status: EditorStatus.ready,
          moduleId: id,
          values: values,
          pendingFiles: const {},
          step: 1,
        ),
      );
      return const SaveResult(SaveOutcome.ok);
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.ready));
      return SaveResult(SaveOutcome.failed, message: e.toString());
    }
  }

  /// Steps 2 and 3: adds or updates one sector or tower together with everyone
  /// holding a role in it.
  Future<SaveResult> saveNode({
    required ModuleLevel level,
    required NodeDraft draft,
    String? parentId,
  }) async {
    final moduleId = state.moduleId;
    if (moduleId == null) return const SaveResult(SaveOutcome.failed);

    if (level.isNamedByHand) {
      if ((draft.label ?? '').trim().isEmpty) {
        return SaveResult(SaveOutcome.missingEntry, name: level.name);
      }
    } else if (draft.referenceItemId == null) {
      return SaveResult(SaveOutcome.missingEntry, name: level.name);
    }
    // A level that names a second list asks for it too: the تكتل is half of
    // what entering a برج means, and a tower without one is the gap this was
    // added to close.
    if (level.secondaryReferenceSetId != null &&
        draft.secondaryReferenceItemId == null) {
      return SaveResult(SaveOutcome.missingEntry, name: level.name);
    }
    for (final f in level.fields.where((f) => f.isRequired)) {
      final v = draft.data[f.key];
      if (v == null || (v is String && v.trim().isEmpty)) {
        return SaveResult(SaveOutcome.missingField, name: f.label);
      }
    }
    for (final r in level.roles.where((r) => r.isRequired)) {
      if (draft.membersOf(r.id).isEmpty) {
        return SaveResult(SaveOutcome.missingRole, name: r.name);
      }
    }

    emit(state.copyWith(status: EditorStatus.saving));
    try {
      var id = draft.id;
      if (id == null) {
        final siblings = parentId == null
            ? state.parentNodes
            : state.childrenOf(parentId);
        id = await _repo.createNode(
          moduleId: moduleId,
          levelId: level.id,
          parentId: parentId,
          referenceItemId: draft.referenceItemId,
          secondaryReferenceItemId: draft.secondaryReferenceItemId,
          label: draft.label?.trim(),
          data: draft.data,
          sortOrder: siblings.length + 1,
        );
      } else {
        await _repo.updateNode(
          id,
          referenceItemId: draft.referenceItemId,
          secondaryReferenceItemId: draft.secondaryReferenceItemId,
          label: draft.label?.trim(),
          data: draft.data,
        );
      }

      for (final role in level.roles) {
        final members = draft.membersOf(role.id);
        await _repo.setNodeRoleMembers(
          nodeId: id,
          roleId: role.id,
          profileIds: members,
          // A key for every man on the role, so that clearing his hotel is told
          // apart from the level never having asked — and nothing at all for a
          // level whose node IS the place.
          housing: level.isPlace
              ? const {}
              : {for (final p in members) p: draft.housingOf(role.id)[p]},
        );
      }

      await _reloadNodes();
      emit(state.copyWith(status: EditorStatus.ready));
      return const SaveResult(SaveOutcome.ok);
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.ready));
      return SaveResult(SaveOutcome.failed, message: e.toString());
    }
  }

  /// Step 2 of a file with no tree: puts people on one of its teams. Returns
  /// null on success, else the failure.
  ///
  /// Someone dropped from a team loses the duties he was handed there with him;
  /// someone who stays keeps his, which is why membership is diffed rather than
  /// rewritten.
  Future<String?> setRoleMembers(String roleId, Set<String> profileIds) async {
    final moduleId = state.moduleId;
    if (moduleId == null) return null;

    emit(state.copyWith(status: EditorStatus.saving));
    try {
      await _repo.setModuleRoleMembers(
        moduleId: moduleId,
        roleId: roleId,
        profileIds: profileIds,
      );
      await _reloadMembers();
      emit(state.copyWith(status: EditorStatus.ready));
      return null;
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.ready));
      return e.toString();
    }
  }

  /// Returns null on success, else the failure. Removing a sector removes the
  /// towers under it.
  Future<String?> deleteNode(String id) async {
    try {
      await _repo.deleteNode(id);
      await _reloadNodes();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// The other files of this season worth importing from.
  ///
  /// Only files whose outermost level is the SAME level, by code. A قطاع and a
  /// مركز are both a division of a file, and there the likeness ends: one is a
  /// stretch of towers in Makkah, the other a station at عرفات, and offering to
  /// copy between them would be offering nonsense.
  Future<List<OperationalModule>> sectorSources() async {
    final allowed = state.sectorSourceTypeIds;
    if (allowed.isEmpty) return const [];
    try {
      final modules = await _repo.fetchModules(seasonId: seasonId);
      return modules
          .where((m) => m.id != state.moduleId && allowed.contains(m.moduleTypeId))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Takes the sectors of [fromModuleId] into this file, as copies. Returns how
  /// many were added, or null if it could not be done at all.
  Future<int?> importSectorsFrom(String fromModuleId) async {
    final id = state.moduleId;
    if (id == null) return null;
    emit(state.copyWith(status: EditorStatus.saving));
    try {
      final copied = await _repo.copyModuleSectors(
        fromModuleId: fromModuleId,
        toModuleId: id,
      );
      await _reloadNodes();
      emit(state.copyWith(status: EditorStatus.ready));
      return copied;
    } catch (_) {
      emit(state.copyWith(status: EditorStatus.ready));
      return null;
    }
  }
}
