import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/check_in_repository.dart';
import '../domain/check_in.dart';

enum MyCheckInsStatus { loading, ready, error }

/// How far back the record is read.
///
/// Named periods rather than a date picker, because the question a person asks
/// their own record is never "between the 3rd and the 9th" — it is "was I
/// marked at the camp last night", "how many times this week", "everything, so
/// I can show somebody". Three answers, one press each.
enum CheckInWindow {
  day(Duration(days: 1)),
  week(Duration(days: 7)),
  all(null);

  const CheckInWindow(this.span);

  final Duration? span;

  DateTime? since() => span == null ? null : DateTime.now().subtract(span!);
}

class MyCheckInsState extends Equatable {
  const MyCheckInsState({
    this.status = MyCheckInsStatus.loading,
    this.lines = const [],
    this.window = CheckInWindow.week,
    this.place,
    this.savedAt,
    this.error,
  });

  final MyCheckInsStatus status;
  final List<PresenceLine> lines;
  final CheckInWindow window;

  /// One place's id, when the reader has narrowed to it.
  final String? place;

  /// When this was last true, if it is being shown from disk.
  final DateTime? savedAt;

  final String? error;

  /// Every place in the record, newest first, for the filter to offer.
  ///
  /// Derived from what came back rather than from the master list of places:
  /// the filter should offer the four hotels this person has actually stood in,
  /// not the sixty the mission contracted.
  List<({String id, String name})> get places {
    final seen = <String>{};
    return [
      for (final line in lines)
        if (seen.add(line.itemId)) (id: line.itemId, name: line.placeName),
    ];
  }

  List<PresenceLine> get shown => place == null
      ? lines
      : [
          for (final line in lines)
            if (line.itemId == place) line,
        ];

  MyCheckInsState copyWith({
    MyCheckInsStatus? status,
    List<PresenceLine>? lines,
    CheckInWindow? window,
    String? place,
    bool clearPlace = false,
    DateTime? savedAt,
    String? error,
  }) => MyCheckInsState(
    status: status ?? this.status,
    lines: lines ?? this.lines,
    window: window ?? this.window,
    place: clearPlace ? null : (place ?? this.place),
    savedAt: savedAt,
    error: error,
  );

  @override
  List<Object?> get props => [status, lines, window, place, savedAt, error];
}

/// A person's own arrivals — the one reading of this table that needs no grant.
///
/// §30.3 of 0098 gave everybody the right to read their own check-ins, and the
/// app never had a screen for it: the only thing that read `place_check_ins`
/// was the operations room's board, behind `checkin.board`. So the man who
/// scanned the code could file his arrival and could not afterwards see that he
/// had — which is the one thing he might reasonably want to check, and the
/// exact thing he is asked about when somebody disputes it.
class MyCheckInsCubit extends SafeCubit<MyCheckInsState> {
  MyCheckInsCubit(this._repo) : super(const MyCheckInsState()) {
    load();
  }

  /// For tests that need a fixed record without a network behind it.
  MyCheckInsCubit.forTest(super.initial) : _repo = CheckInRepository();

  final CheckInRepository _repo;

  Future<void> load() async {
    try {
      // The PLACE filter is applied in memory and the WINDOW at the server, and
      // the split is not arbitrary: narrowing by place must not change what the
      // filter itself can offer. Asked of the server, choosing "فندق الأنصار"
      // would return only those rows — and the list of places to choose from,
      // being derived from the rows, would collapse to the one already chosen,
      // with no way back to the others.
      final read = await _repo.fetchMyCheckIns(since: state.window.since());
      emit(
        state.copyWith(
          status: MyCheckInsStatus.ready,
          lines: read.data,
          savedAt: read.savedAt,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: MyCheckInsStatus.error, error: e.toString()),
      );
    }
  }

  Future<void> setWindow(CheckInWindow value) async {
    emit(state.copyWith(window: value));
    await load();
  }

  /// Null clears it — "every place" is a state, not the absence of one.
  void setPlace(String? value) => emit(
    value == null
        ? state.copyWith(clearPlace: true)
        : state.copyWith(place: value),
  );
}
