import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/complaints_repository.dart';
import '../domain/complaint.dart';

enum ThreadStatus { loading, ready, missing, error }

class ComplaintThreadState extends Equatable {
  const ComplaintThreadState({
    this.status = ThreadStatus.loading,
    this.messages = const [],
    this.isLocked = false,
    this.isDismissed = false,
    this.myRole = ComplaintRole.complainant,
    this.sending = false,
    this.busy = false,
    this.error,
  });

  final ThreadStatus status;
  final List<ComplaintMessage> messages;
  final bool isLocked;
  final bool isDismissed;
  final ComplaintRole myRole;

  /// A reply is going out. Separate from [busy] so the composer can show a
  /// spinner without the lock and dismiss actions greying out at the same time.
  final bool sending;

  /// Locking, dismissing or deleting is in flight.
  final bool busy;
  final String? error;

  /// The complaint's own words — always the first bubble, and the only one
  /// without a reply id.
  ComplaintMessage? get head =>
      messages.where((m) => m.isHead).firstOrNull;

  List<ComplaintMessage> get replies =>
      messages.where((m) => !m.isHead).toList();

  ComplaintThreadState copyWith({
    ThreadStatus? status,
    List<ComplaintMessage>? messages,
    bool? isLocked,
    bool? isDismissed,
    ComplaintRole? myRole,
    bool? sending,
    bool? busy,
    String? error,
  }) => ComplaintThreadState(
    status: status ?? this.status,
    messages: messages ?? this.messages,
    isLocked: isLocked ?? this.isLocked,
    isDismissed: isDismissed ?? this.isDismissed,
    myRole: myRole ?? this.myRole,
    sending: sending ?? this.sending,
    busy: busy ?? this.busy,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    messages,
    isLocked,
    isDismissed,
    myRole,
    sending,
    busy,
    error,
  ];
}

class ComplaintThreadCubit extends SafeCubit<ComplaintThreadState> {
  ComplaintThreadCubit(this._repo, this.complaintId, {Complaint? known})
    : _known = known,
      super(
        ComplaintThreadState(
          isLocked: known?.isLocked ?? false,
          isDismissed: known?.isDismissed ?? false,
          myRole: known?.myRole ?? ComplaintRole.complainant,
        ),
      ) {
    load();
  }

  final ComplaintsRepository _repo;
  final String complaintId;

  /// What the list already knew, so the header can be right before the thread
  /// arrives. The server's answer replaces it either way.
  final Complaint? _known;

  Future<void> load() async {
    emit(state.copyWith(status: ThreadStatus.loading, error: null));
    try {
      final messages = await _repo.fetchThread(complaintId);
      emit(
        state.copyWith(
          status: ThreadStatus.ready,
          messages: messages,
          myRole: _roleFrom(messages) ?? _known?.myRole,
        ),
      );
    } catch (e) {
      final raw = e.toString().toLowerCase();
      emit(
        state.copyWith(
          status: raw.contains('complaint_not_found')
              ? ThreadStatus.missing
              : ThreadStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  /// Which side of this the reader is on, read off their own bubbles rather
  /// than guessed: the server stamped every message with its author's role and
  /// with whether it is the reader's, so the two together say it outright.
  ComplaintRole? _roleFrom(List<ComplaintMessage> messages) {
    for (final m in messages) {
      if (m.isMine) return m.role;
    }
    return null;
  }

  Future<bool> reply(
    String body, {
    List<PendingAttachment> attachments = const [],
  }) async {
    if (body.trim().isEmpty) return false;
    emit(state.copyWith(sending: true, error: null));
    try {
      await _repo.reply(
        complaintId: complaintId,
        body: body.trim(),
        attachments: attachments,
      );
      final messages = await _repo.fetchThread(complaintId);
      emit(state.copyWith(sending: false, messages: messages));
      return true;
    } catch (e) {
      emit(state.copyWith(sending: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> setLocked(bool locked) async {
    emit(state.copyWith(busy: true, error: null));
    try {
      await _repo.setLocked(complaintId, locked);
      emit(state.copyWith(busy: false, isLocked: locked));
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> setDismissed(bool dismissed, {String? reason}) async {
    emit(state.copyWith(busy: true, error: null));
    try {
      await _repo.setDismissed(complaintId, dismissed, reason: reason);
      emit(state.copyWith(busy: false, isDismissed: dismissed));
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> delete() async {
    emit(state.copyWith(busy: true, error: null));
    try {
      await _repo.delete(complaintId);
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  Future<String> signedUrl(
    String path, {
    bool download = false,
    String? downloadName,
  }) => _repo.signedUrl(path, download: download, downloadName: downloadName);
}
