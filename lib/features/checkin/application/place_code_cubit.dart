import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/check_in_repository.dart';
import '../domain/check_in.dart';

enum PlaceCodeStatus { loading, ready, denied, error }

class PlaceCodeState extends Equatable {
  const PlaceCodeState({
    this.status = PlaceCodeStatus.loading,
    this.code,
    this.placeName = '',
    this.rotatedAt,
    this.dueAt,
    this.error,
  });

  final PlaceCodeStatus status;
  final PlaceCode? code;
  final String placeName;
  final DateTime? rotatedAt;

  /// When the schedule of 0114 will rotate this code by itself, killing every
  /// printed copy. Null when the schedule is off — and then the only thing that
  /// ever changes a code is somebody pressing تجديد الرمز.
  final DateTime? dueAt;

  final String? error;

  /// A place with no pin accepts NOTHING since 0098 — the server refuses with
  /// `check_in_place_has_no_location` rather than letting anybody in unchecked.
  /// So the card says it here, where somebody who can fix it is looking, rather
  /// than leaving it to be discovered by a man standing at the gate.
  bool get isUnpinned =>
      status == PlaceCodeStatus.ready &&
      (code?.latitude == null || code?.longitude == null);

  /// Whether the automatic rotation is near enough that the reprint should be
  /// happening now rather than being noted.
  ///
  /// Seven days, and it is the CARD's threshold rather than the policy's: the
  /// server warns at `warn_before_days` by notification, and this is what the
  /// person who happened to open the page sees without one. Wider on purpose —
  /// a line that appears the same morning the paper dies is a line that arrives
  /// too late to act on.
  bool get isRotatingSoon {
    final due = dueAt;
    if (due == null) return false;
    return due.difference(DateTime.now()).inDays <= 7;
  }

  @override
  List<Object?> get props => [
    status,
    code,
    placeName,
    rotatedAt,
    dueAt,
    error,
  ];
}

/// One place's code, fetched on its own.
///
/// Deliberately NOT folded into `ReferenceDataCubit`. That cubit holds every
/// set with every entry, and is loaded on a screen most people open to read a
/// phone number — pulling every secret in the season into it, for everyone who
/// happens to hold the permission, to show one card, is the kind of convenience
/// that turns a printable secret into a downloadable one.
class PlaceCodeCubit extends SafeCubit<PlaceCodeState> {
  PlaceCodeCubit(this._repo, this.itemId) : super(const PlaceCodeState()) {
    load();
  }

  final CheckInRepository _repo;
  final String itemId;

  Future<void> load() async {
    try {
      final found = await _repo.fetchCode(itemId);
      if (found == null) {
        emit(const PlaceCodeState(status: PlaceCodeStatus.error));
        return;
      }
      emit(
        PlaceCodeState(
          status: PlaceCodeStatus.ready,
          code: found.code,
          placeName: found.placeName,
          rotatedAt: found.rotatedAt,
          dueAt: found.dueAt,
        ),
      );
    } catch (e) {
      // The RPC refuses outright without `checkin.codes`, and that refusal is
      // not an error to apologise for — it is the answer. Kept apart so the
      // card can simply not draw rather than showing a red box to somebody who
      // was never meant to see the code.
      final denied = e.toString().contains('check_in_codes_denied');
      emit(
        PlaceCodeState(
          status: denied ? PlaceCodeStatus.denied : PlaceCodeStatus.error,
          error: denied ? null : e.toString(),
        ),
      );
    }
  }

  /// Makes every printed copy dead. Returns null on success, the error
  /// otherwise — the screen has something to say either way.
  Future<String?> rotate() async {
    try {
      await _repo.rotateCode(itemId);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
