import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/offline/save_outcome.dart';
import '../../../core/utils/arabic_search.dart';
import '../../../core/utils/device_position.dart';
import '../../../core/utils/network_error.dart';
import '../data/check_in_outbox.dart';
import '../data/check_in_repository.dart';
import '../domain/check_in.dart';

enum PresenceStatus { loading, ready, error }

/// One place on the board, with everybody the last twelve hours put in it.
typedef PresenceGroup = ({String itemId, String placeName, String? groupName,
    List<PresenceLine> lines});

class PresenceState extends Equatable {
  const PresenceState({
    this.status = PresenceStatus.loading,
    this.lines = const [],
    this.gaps = const [],
    this.showingGaps = false,
    this.hiddenGroups = const {},
    this.window = const Duration(hours: 12),
    this.query = '',
    this.error,
  });

  final PresenceStatus status;
  final List<PresenceLine> lines;

  /// Posts that are manned on paper and unconfirmed in the world.
  ///
  /// Held beside [lines] rather than on a screen of their own, because they are
  /// the same fact read from the other side and the room switches between the
  /// two questions constantly: "who is in this hotel" and "who should be and
  /// is not" are asked one after the other, by the same person, about the same
  /// place, inside the same minute.
  final List<PresenceGap> gaps;

  /// Which of the two the board is currently showing.
  final bool showingGaps;

  /// Held as what is HIDDEN, for the reason the map holds it that way: a group
  /// that appears later — a مشعر used for the first time this morning — must
  /// arrive visible, not wait to be noticed.
  final Set<String> hiddenGroups;

  final Duration window;
  final String query;
  final String? error;

  /// Every group present, in the order they were met.
  List<String> get groups {
    final seen = <String>[];
    for (final line in lines) {
      final name = line.groupName ?? line.setName ?? '—';
      if (!seen.contains(name)) seen.add(name);
    }
    return seen;
  }

  bool _keeps(PresenceLine line) {
    final group = line.groupName ?? line.setName ?? '—';
    if (hiddenGroups.contains(group)) return false;
    if (query.trim().isEmpty) return true;
    return arabicMatchesAll([line.fullName, line.placeName], query);
  }

  /// The board as it is read: by PLACE, not by person. The room's question is
  /// "who is in this hotel", and a flat list of names sorted by time answers a
  /// question nobody asked.
  List<PresenceGroup> get byPlace {
    final order = <String>[];
    final held = <String, List<PresenceLine>>{};
    for (final line in lines) {
      if (!_keeps(line)) continue;
      if (!held.containsKey(line.itemId)) order.add(line.itemId);
      held.putIfAbsent(line.itemId, () => []).add(line);
    }
    return [
      for (final id in order)
        (
          itemId: id,
          placeName: held[id]!.first.placeName,
          groupName: held[id]!.first.groupName,
          lines: held[id]!,
        ),
    ];
  }

  int get showing => byPlace.fold(0, (n, g) => n + g.lines.length);

  /// The gaps as they are read: worst first, which the database already
  /// ordered them by — never seen, then longest quiet. The only thing done to
  /// them here is the search box, and deliberately not the group filter: a
  /// group is derived from a check-in's place on the board, and a man who has
  /// never checked in has no such row to derive one from. Hiding him by a
  /// filter he cannot be measured against is how an absence disappears twice.
  List<PresenceGap> get shownGaps {
    if (query.trim().isEmpty) return gaps;
    return [
      for (final gap in gaps)
        if (arabicMatchesAll([gap.fullName, gap.placeName], query)) gap,
    ];
  }

  /// How many posts are unconfirmed — the number the toggle carries, and the
  /// one worth seeing before deciding which half of the board to read.
  int get gapCount => gaps.length;

  PresenceState copyWith({
    PresenceStatus? status,
    List<PresenceLine>? lines,
    List<PresenceGap>? gaps,
    bool? showingGaps,
    Set<String>? hiddenGroups,
    Duration? window,
    String? query,
    String? error,
  }) => PresenceState(
    status: status ?? this.status,
    lines: lines ?? this.lines,
    gaps: gaps ?? this.gaps,
    showingGaps: showingGaps ?? this.showingGaps,
    hiddenGroups: hiddenGroups ?? this.hiddenGroups,
    window: window ?? this.window,
    query: query ?? this.query,
    error: error ?? this.error,
  );

  @override
  List<Object?> get props => [
    status,
    lines,
    gaps,
    showingGaps,
    hiddenGroups,
    window,
    query,
    error,
  ];
}

/// Reading who is where, across the whole season.
class PresenceCubit extends SafeCubit<PresenceState> {
  PresenceCubit(this._repo, {this.itemId}) : super(const PresenceState()) {
    load();
  }

  /// For tests that need a fixed board without a network behind it.
  PresenceCubit.forTest(super.initial)
    : _repo = CheckInRepository(),
      itemId = null;

  final CheckInRepository _repo;

  /// Set when the board was opened from one place rather than from the shelf.
  final String? itemId;

  Future<void> load() async {
    try {
      // Both halves, together. The window means the same thing to each — "seen
      // within this" and "not seen within this" — so reading them apart would
      // let one be a few seconds older than the other and let a name appear on
      // both at once, which is the one thing a board like this must never do.
      final both = await Future.wait([
        _repo.fetchPresence(
          since: DateTime.now().subtract(state.window),
          itemId: itemId,
        ),
        _repo.fetchGaps(within: state.window, itemId: itemId),
      ]);
      emit(
        state.copyWith(
          status: PresenceStatus.ready,
          lines: both[0] as List<PresenceLine>,
          gaps: both[1] as List<PresenceGap>,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: PresenceStatus.error, error: e.toString()));
    }
  }

  void setQuery(String value) => emit(state.copyWith(query: value));

  /// Turns the board over. No re-read: both halves are already in hand, and a
  /// spinner between two answers to the same question reads as two screens.
  void showGaps(bool value) => emit(state.copyWith(showingGaps: value));

  Future<void> setWindow(Duration value) async {
    emit(state.copyWith(window: value));
    await load();
  }

  void toggleGroup(String group) {
    final hidden = {...state.hiddenGroups};
    if (!hidden.remove(group)) hidden.add(group);
    emit(state.copyWith(hiddenGroups: hidden));
  }

  void showAllGroups() => emit(state.copyWith(hiddenGroups: const {}));
}

/// Reporting an arrival.
///
/// Not a screen's cubit — one act, with one method, so that the ordering rules
/// below live in exactly one place.
abstract final class CheckIn {
  /// Records that the caller arrived at the place the scanned code names.
  ///
  /// Three rules, and each is here rather than at a call site because getting
  /// any of them wrong is silent:
  ///
  /// 1. **The position is taken first**, before anything is sent, so what is
  ///    recorded is where the man was when he pressed — not where the phone was
  ///    when the queue finally drained, hours later and possibly in another
  ///    city.
  /// 2. **No position is refused immediately and never queued.** Since 0098 the
  ///    server will not accept a positionless check-in at all, so queueing one
  ///    would tell him it was kept and throw it away later. There is nothing to
  ///    wait for.
  /// 3. **The poster's own coordinates are consulted only when the network is
  ///    gone.** They are on the poster so an offline phone can refuse honestly
  ///    rather than queue a lie — but they are a COPY, and a copy goes stale.
  ///    If they were checked before every send, an administrator correcting a
  ///    pin in the master data would make every sticker already on a wall start
  ///    refusing men standing in exactly the right place, the poster's old
  ///    numbers outvoting the server's new ones. Online the server is
  ///    authoritative and fresh; the copy is consulted only when there is
  ///    nothing better, which is the one case it was printed for.
  /// The receipt rides beside the outcome rather than inside it: [SaveOutcome]
  /// is shared by five features and none of the others has anything to say on
  /// success. Null when the arrival was queued or refused — there is no place
  /// name to report until the server has named one.
  /// [fix] is injectable for the same reason [repository] is: the three rules
  /// above are all about what happens for a particular position and a
  /// particular failure, and a rule that can only be exercised by standing in
  /// Mina with the network off is a rule nothing guards.
  static Future<({SaveOutcome outcome, CheckInReceipt? receipt})> arrive({
    required PlaceCode code,
    String? note,
    CheckInRepository? repository,
    Future<Fix?> Function()? fix,
  }) async {
    final repo = repository ?? CheckInRepository();
    final position = await (fix ?? currentFix)();

    // Rule 2.
    if (position == null) {
      return (
        outcome: const SaveOutcome.failed('check_in_needs_a_position'),
        receipt: null,
      );
    }

    try {
      final receipt = await repo.checkIn(
        itemId: code.itemId,
        secret: code.secret,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        note: note,
      );
      return (outcome: const SaveOutcome.sent(), receipt: receipt);
    } catch (error) {
      // A refusal is the server's answer and must be shown, not swallowed —
      // the same rule `Outbox.sendOrQueue` states for every other write.
      if (!looksLikeNetworkFailure(error)) {
        return (outcome: SaveOutcome.failed(error.toString()), receipt: null);
      }

      // Rule 3: only now.
      if (code.canCheckLocally) {
        final distance = CheckInRules.metresBetween(
          position.latitude,
          position.longitude,
          code.latitude!,
          code.longitude!,
        );
        if (CheckInRules.tooFar(
          distance: distance,
          accuracy: position.accuracy,
          radius: code.radiusM!,
        )) {
          return (
            outcome: const SaveOutcome.failed('check_in_too_far'),
            receipt: null,
          );
        }
      }

      if (!Outbox.isInstalled) {
        return (outcome: SaveOutcome.failed(error.toString()), receipt: null);
      }
      await Outbox.instance.add(
        kind: CheckInOutbox.kind,
        payload: CheckInOutbox.payload(
          itemId: code.itemId,
          secret: code.secret,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          note: note,
        ),
      );
      return (outcome: const SaveOutcome.queued(), receipt: null);
    }
  }
}
