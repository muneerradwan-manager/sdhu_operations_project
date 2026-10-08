import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/complaints_repository.dart';
import '../domain/complaint.dart';

enum FileComplaintStatus { ready, loadingTargets, sending }

class FileComplaintState extends Equatable {
  const FileComplaintState({
    this.status = FileComplaintStatus.ready,
    this.target,
    this.targetId,
    this.targetName,
    this.options = const [],
    this.body = '',
    this.attachments = const [],
    this.error,
  });

  final FileComplaintStatus status;

  /// What kind of thing this is about. Null until the reader picks, because
  /// defaulting to "an employee" would put a name in the frame before anybody
  /// decided the complaint was about a person at all.
  final ComplaintTarget? target;

  final String? targetId;
  final String? targetName;
  final List<ComplaintTargetOption> options;
  final String body;
  final List<PendingAttachment> attachments;
  final String? error;

  bool get needsTarget => target?.needsTarget ?? false;

  bool get canSubmit =>
      status != FileComplaintStatus.sending &&
      target != null &&
      body.trim().isNotEmpty &&
      (!needsTarget || targetId != null);

  FileComplaintState copyWith({
    FileComplaintStatus? status,
    ComplaintTarget? target,
    String? targetId,
    String? targetName,
    bool clearTarget = false,
    List<ComplaintTargetOption>? options,
    String? body,
    List<PendingAttachment>? attachments,
    String? error,
  }) => FileComplaintState(
    status: status ?? this.status,
    target: target ?? this.target,
    targetId: clearTarget ? null : (targetId ?? this.targetId),
    targetName: clearTarget ? null : (targetName ?? this.targetName),
    options: options ?? this.options,
    body: body ?? this.body,
    attachments: attachments ?? this.attachments,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    target,
    targetId,
    targetName,
    options,
    body,
    attachments,
    error,
  ];
}

class FileComplaintCubit extends SafeCubit<FileComplaintState> {
  FileComplaintCubit(this._repo, {ComplaintTarget? target, String? targetId,
      String? targetName})
    : super(
        FileComplaintState(
          target: target,
          targetId: targetId,
          targetName: targetName,
        ),
      ) {
    if (target != null && targetId == null) loadOptions(target);
  }

  final ComplaintsRepository _repo;

  /// Picking the kind clears whatever was picked under the old one — a hotel id
  /// left standing while the kind says "report" is exactly the mismatch the
  /// database refuses, and it should never get that far.
  Future<void> setTarget(ComplaintTarget target) async {
    emit(state.copyWith(target: target, clearTarget: true, options: const []));
    if (target.needsTarget) await loadOptions(target);
  }

  Future<void> loadOptions(ComplaintTarget target) async {
    emit(state.copyWith(status: FileComplaintStatus.loadingTargets, error: null));
    try {
      final options = await _repo.fetchTargets(target);
      emit(
        state.copyWith(status: FileComplaintStatus.ready, options: options),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FileComplaintStatus.ready,
          error: e.toString(),
        ),
      );
    }
  }

  void pick(String id, String name) =>
      emit(state.copyWith(targetId: id, targetName: name));

  void setBody(String value) => emit(state.copyWith(body: value));

  void addAttachment(PendingAttachment attachment) => emit(
    state.copyWith(attachments: [...state.attachments, attachment]),
  );

  void removeAttachment(int index) => emit(
    state.copyWith(
      attachments: [...state.attachments]..removeAt(index),
    ),
  );

  /// Returns the new complaint's id, or null with [FileComplaintState.error]
  /// set — the shape every editor in this app uses.
  Future<String?> submit() async {
    if (!state.canSubmit) return null;
    emit(state.copyWith(status: FileComplaintStatus.sending, error: null));
    try {
      final id = await _repo.file(
        target: state.target!,
        targetId: state.targetId,
        body: state.body.trim(),
        attachments: state.attachments,
      );
      emit(state.copyWith(status: FileComplaintStatus.ready));
      return id;
    } catch (e) {
      emit(
        state.copyWith(
          status: FileComplaintStatus.ready,
          error: e.toString(),
        ),
      );
      return null;
    }
  }
}
