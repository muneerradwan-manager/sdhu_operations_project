import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/prayer_alerts_store.dart';
import '../data/prayer_notifications.dart';
import '../data/prayer_times_repository.dart';
import '../domain/prayer_alerts.dart';
import '../domain/prayer_day.dart';
import 'prayer_scheduler.dart';

class PrayerAlertsState extends Equatable {
  const PrayerAlertsState({
    this.alerts = const PrayerAlerts(),
    this.readiness = PrayerAlertReadiness.ready,
    this.locatable = true,
    this.loaded = false,
  });

  final PrayerAlerts alerts;

  /// What the system will actually let through — see [PrayerAlertReadiness].
  ///
  /// The granted/blocked/inexact answers are only meaningful while
  /// [PrayerAlerts.enabled], because nothing is asked of the system until the
  /// reader has said they want this. [PrayerAlertReadiness.unsupported] is the
  /// exception and is settled on the way in: it is a property of the platform
  /// rather than an answer from it, costs nothing to determine, and has to be
  /// known before the switch is drawn.
  final PrayerAlertReadiness readiness;

  /// Whether this device has ever known where it is.
  ///
  /// Without a fix the times on screen are مكة's, and nothing is announced from
  /// them — see [PrayerScheduler]. The switch still works, and the page says
  /// plainly why nothing will arrive until the card's location chip is tapped.
  final bool locatable;

  /// False for the frame or two before disk answers.
  final bool loaded;

  PrayerAlertsState copyWith({
    PrayerAlerts? alerts,
    PrayerAlertReadiness? readiness,
    bool? locatable,
    bool? loaded,
  }) {
    return PrayerAlertsState(
      alerts: alerts ?? this.alerts,
      readiness: readiness ?? this.readiness,
      locatable: locatable ?? this.locatable,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  List<Object?> get props => [alerts, readiness, locatable, loaded];
}

/// The settings page's half of the prayer alarms.
///
/// It owns the CHOICES and nothing else. Every change is written to disk and
/// then handed to [PrayerScheduler], which is what actually lays the week down
/// — the same call the app makes at start-up and after a new fix, so there is
/// one path to the alarms and not three.
class PrayerAlertsCubit extends SafeCubit<PrayerAlertsState> {
  PrayerAlertsCubit() : super(const PrayerAlertsState()) {
    _load();
  }

  final _store = const PrayerAlertsStore();
  final _repository = PrayerTimesRepository();

  Future<void> _load() async {
    final alerts = await _store.read();
    final fix = await _repository.lastKnownFix();
    emit(state.copyWith(alerts: alerts, locatable: fix != null, loaded: true));
    // A platform that cannot announce anything at all has to be known BEFORE
    // the reader presses anything. [readiness] defaults to `ready` and was only
    // ever asked for once the switch was already on — so on Windows the switch
    // looked live, and pressing it ran the whole request only to drop straight
    // back to off with nothing said about why. This branch costs no system
    // call; see [PrayerNotifications.supported].
    if (!PrayerNotifications.supported) {
      emit(state.copyWith(readiness: PrayerAlertReadiness.unsupported));
    } else if (alerts.enabled) {
      emit(
        state.copyWith(
          readiness: await PrayerNotifications.instance.readiness(),
        ),
      );
    }
  }

  /// The master switch.
  ///
  /// Turning it ON is the one moment this feature is allowed to raise a system
  /// dialog: the reader has just pressed a switch labelled with what it does,
  /// which is the only point at which the permission request explains itself.
  /// If they refuse, the switch goes back — a switch left on beside a message
  /// saying nothing will happen is a lie the reader has to decode.
  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      await _apply(state.alerts.copyWith(enabled: false));
      return;
    }

    final readiness = await PrayerNotifications.instance.request();
    emit(state.copyWith(readiness: readiness));
    if (readiness == PrayerAlertReadiness.blocked ||
        readiness == PrayerAlertReadiness.unsupported) {
      emit(state.copyWith(alerts: state.alerts.copyWith(enabled: false)));
      return;
    }
    await _apply(state.alerts.copyWith(enabled: true));
  }

  Future<void> toggleSlot(PrayerSlot slot) =>
      _apply(state.alerts.toggling(slot));

  Future<void> setReminderMinutes(int minutes) =>
      _apply(state.alerts.copyWith(reminderMinutes: minutes));

  Future<void> setSilent(bool silent) =>
      _apply(state.alerts.copyWith(silent: silent));

  /// Sends the reader to the system page for exact alarms, and re-reads the
  /// answer when they come back.
  ///
  /// Re-laying afterwards is not housekeeping: alarms already scheduled
  /// inexactly stay inexact, so the permission only takes effect on the ones
  /// laid down after it.
  Future<void> grantExactAlarms() async {
    await PrayerNotifications.instance.requestExactAlarms();
    emit(
      state.copyWith(readiness: await PrayerNotifications.instance.readiness()),
    );
    await PrayerScheduler.instance.refresh();
  }

  Future<void> _apply(PrayerAlerts alerts) async {
    emit(state.copyWith(alerts: alerts));
    await _store.write(alerts);
    await PrayerScheduler.instance.refresh();
    if (alerts.enabled) {
      emit(
        state.copyWith(
          readiness: await PrayerNotifications.instance.readiness(),
        ),
      );
    }
  }
}
