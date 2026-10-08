import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/prayer_times_repository.dart';
import '../domain/prayer_day.dart';
import '../domain/prayer_fix.dart';
import '../domain/prayer_place.dart';
import 'prayer_scheduler.dart';

class PrayerTimesState extends Equatable {
  const PrayerTimesState({
    this.day,
    this.window,
    this.place,
    this.approximate = true,
    this.locating = false,
    this.outcome,
  });

  /// Null for the one or two frames before the cached fix comes back off disk.
  final PrayerDay? day;

  /// Which window the clock stood in when this state was emitted. It is
  /// re-derived on every phase change; the seconds in between are the card's
  /// business, not this cubit's — see `_Pulse` in the card.
  final PrayerWindow? window;

  /// The named place the times were computed for, or null out in the world.
  final PrayerPlace? place;

  /// Whether these times are for the fallback rather than for this device.
  ///
  /// It is true until a real fix lands, and it is surfaced rather than hidden:
  /// a card quietly showing Makkah's Fajr to somebody in Damascus is worse than
  /// one that says it does not know yet.
  final bool approximate;

  /// A fix is in flight.
  final bool locating;

  /// How the last attempt ended. Null before the first one.
  final LocationOutcome? outcome;

  /// Whether the reader can do something about [approximate] — as opposed to a
  /// desktop with no location provider, where offering a button would be a lie.
  ///
  /// A permanent refusal is the one outcome that closes the chip, and only on a
  /// phone: there the system really has stopped asking, and a chip that raises
  /// no dialog is a dead button. A desktop never asked in the first place — see
  /// `PrayerTimesRepository.openSettings` — so "permanently denied" there names
  /// a switch that is off rather than an answer that was given, and the moment
  /// the reader flips it the chip has to be tappable again. Closing it would
  /// mean the app had to be restarted to notice.
  bool get canAskForLocation => switch (outcome) {
    // Nothing left to ask for; the chip names the place instead.
    LocationOutcome.located => false,
    LocationOutcome.permanentlyDenied => _isDesktop,
    _ => true,
  };

  /// Where a permission is a setting rather than a dialog.
  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  PrayerTimesState copyWith({
    PrayerDay? day,
    PrayerWindow? window,
    PrayerPlace? place,
    bool clearPlace = false,
    bool? approximate,
    bool? locating,
    LocationOutcome? outcome,
  }) {
    return PrayerTimesState(
      day: day ?? this.day,
      window: window ?? this.window,
      place: clearPlace ? null : (place ?? this.place),
      approximate: approximate ?? this.approximate,
      locating: locating ?? this.locating,
      outcome: outcome ?? this.outcome,
    );
  }

  @override
  List<Object?> get props => [
    day,
    window,
    place,
    approximate,
    locating,
    outcome,
  ];
}

/// Keeps one day's prayer times, and keeps them current.
///
/// "Current" is the whole job, and it is not the same as "ticking". A card that
/// rebuilt itself every second to move a countdown would repaint a glass pane,
/// its hairline and its shadow sixty times a minute for the sake of two digits.
/// So the division is:
///
///   * this cubit emits on EVENTS — a fix arrived, the window changed, the day
///     turned over — and sleeps in between on a single timer set for the exact
///     moment of the next boundary;
///   * the seconds are counted inside the card, by a small widget that rebuilds
///     nothing but the countdown and the progress bar.
///
/// The timer is a belt, not the braces: it will fire late or not at all if the
/// phone suspends the app for the night. The card's ticker computes from the
/// wall clock rather than by decrementing, notices on the first frame after a
/// resume that the boundary has passed, and asks for [refreshWindow]. The two
/// mechanisms cover each other.
class PrayerTimesCubit extends SafeCubit<PrayerTimesState> {
  PrayerTimesCubit(this._repository) : super(const PrayerTimesState()) {
    unawaited(_boot());
  }

  final PrayerTimesRepository _repository;

  Timer? _boundary;

  /// How long a remembered position is taken at its word.
  ///
  /// Long, on purpose. A stale fix costs seconds of Fajr; a fresh one costs a
  /// platform channel round trip on every visit to the home screen. Half a day
  /// is well inside the error a person could tolerate and well outside the
  /// interval at which anyone opens this app.
  static const _trustFixFor = Duration(hours: 12);

  Future<void> _boot() async {
    final cached = await _repository.lastKnownFix();
    if (isClosed) return;

    _recompute(
      latitude: cached?.latitude ?? PrayerTimesRepository.fallbackLatitude,
      longitude: cached?.longitude ?? PrayerTimesRepository.fallbackLongitude,
      approximate: cached == null,
    );

    final stale =
        cached == null ||
        DateTime.now().difference(cached.capturedAt) > _trustFixFor;
    if (stale) await _locate(prompt: false);
  }

  /// Pull-to-refresh, and the season reload beside it.
  ///
  /// Never prompts: a person dragging a list down is asking for newer numbers,
  /// not for a permission dialog they did not press anything to summon.
  Future<void> refresh() async {
    await _locate(prompt: false);
    refreshWindow();
  }

  /// The location chip was tapped. This is the one call allowed to raise the
  /// system dialog, because this is the one call a person made on purpose.
  Future<LocationOutcome> requestLocation() => _locate(prompt: true);

  /// The other way out, offered beside the refusal: the system's own location
  /// page. On a desktop it is the only one there is.
  Future<void> openLocationSettings() => _repository.openSettings();

  Future<LocationOutcome> _locate({required bool prompt}) async {
    if (state.locating) return state.outcome ?? LocationOutcome.failed;
    emit(state.copyWith(locating: true));

    final result = await _repository.locate(prompt: prompt);
    if (isClosed) return result.outcome;

    final fix = result.fix;
    if (fix == null) {
      emit(state.copyWith(locating: false, outcome: result.outcome));
      return result.outcome;
    }

    _recompute(
      latitude: fix.latitude,
      longitude: fix.longitude,
      approximate: false,
      locating: false,
      outcome: result.outcome,
    );

    // The times just moved, which means every alarm laid down for the next week
    // is for the wrong place — by minutes after a walk across Makkah, by half
    // an hour after a flight. The scheduler reads the new fix back off disk
    // (the repository has already written it there) and re-lays both the alarms
    // and the home-screen widget. Unawaited: nothing on this screen waits for
    // it, and it is guarded against its own failures.
    unawaited(PrayerScheduler.instance.refresh());
    return result.outcome;
  }

  /// Re-reads the clock against the times already held, recomputing the day
  /// first if the calendar has turned over since they were worked out.
  ///
  /// Called by the boundary timer and by the card's ticker when its countdown
  /// reaches zero — including the one that reaches zero because the phone was
  /// asleep for six hours rather than because six hours passed on screen.
  void refreshWindow() {
    final day = state.day;
    if (day == null) return;

    final now = DateTime.now();
    if (!day.covers(now)) {
      // Past midnight. Recomputing needs the position, and the position is not
      // on the state — but it is on disk, and the fallback is a constant, so
      // this goes back through the same path the first paint took.
      unawaited(_recomputeFromStoredFix());
      return;
    }

    final window = day.windowAt(now);
    if (window == state.window) return;
    emit(state.copyWith(window: window));
    _scheduleBoundary(window, now);
  }

  Future<void> _recomputeFromStoredFix() async {
    final cached = await _repository.lastKnownFix();
    if (isClosed) return;
    _recompute(
      latitude: cached?.latitude ?? PrayerTimesRepository.fallbackLatitude,
      longitude: cached?.longitude ?? PrayerTimesRepository.fallbackLongitude,
      approximate: cached == null,
    );
  }

  void _recompute({
    required double latitude,
    required double longitude,
    required bool approximate,
    bool? locating,
    LocationOutcome? outcome,
  }) {
    final now = DateTime.now();
    final day = _repository.dayFor(latitude: latitude, longitude: longitude);
    final window = day.windowAt(now);
    final place = PrayerPlace.nearestTo(latitude, longitude);

    emit(
      PrayerTimesState(
        day: day,
        window: window,
        place: approximate ? null : place,
        approximate: approximate,
        locating: locating ?? state.locating,
        outcome: outcome ?? state.outcome,
      ),
    );
    _scheduleBoundary(window, now);
  }

  void _scheduleBoundary(PrayerWindow window, DateTime now) {
    _boundary?.cancel();
    // A second past the boundary rather than on it, so the recomputed window is
    // unambiguously the next one and not this one again by a rounding of the
    // clock.
    final wait = window.end.difference(now) + const Duration(seconds: 1);
    _boundary = Timer(wait.isNegative ? Duration.zero : wait, refreshWindow);
  }

  @override
  Future<void> close() {
    _boundary?.cancel();
    return super.close();
  }
}
