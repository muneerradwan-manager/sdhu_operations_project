import 'package:equatable/equatable.dart';

import 'prayer_day.dart';

/// Which calls this phone makes a noise for, how loudly, and how far ahead.
///
/// Off by default, and deliberately: an app that starts announcing الفجر at
/// half past four because somebody installed it is an app that gets its
/// notifications turned off wholesale in the system settings — which takes the
/// mission's own messages down with it. The switch is in the settings page and
/// it is the reader who throws it.
class PrayerAlerts extends Equatable {
  const PrayerAlerts({
    this.enabled = false,
    this.slots = everyPrayer,
    this.reminderMinutes = 0,
    this.silent = false,
  });

  /// The five. الشروق is not among them and cannot be added: it is not a
  /// prayer, and a phone that pinged at sunrise saying "حان وقت الشروق" would
  /// be announcing a prayer that does not exist.
  static const everyPrayer = <PrayerSlot>{
    PrayerSlot.fajr,
    PrayerSlot.dhuhr,
    PrayerSlot.asr,
    PrayerSlot.maghrib,
    PrayerSlot.isha,
  };

  /// What the "before the call" setting may be set to, in minutes. The first
  /// is off.
  static const reminderChoices = <int>[0, 5, 10, 15, 20, 30];

  final bool enabled;

  /// The subset of [everyPrayer] that announces itself.
  final Set<PrayerSlot> slots;

  /// Minutes of warning before the call, or 0 for none.
  final int reminderMinutes;

  /// Arrives without a sound — it still lands in the tray and still vibrates
  /// if the phone is set to. For the days a person is in a meeting rather than
  /// in a hotel corridor.
  final bool silent;

  /// Whether anything at all is to be scheduled.
  bool get announces => enabled && slots.isNotEmpty;

  /// Whether the early warning is on as well as the call itself.
  bool get reminds => announces && reminderMinutes > 0;

  bool announcing(PrayerSlot slot) => slots.contains(slot);

  PrayerAlerts copyWith({
    bool? enabled,
    Set<PrayerSlot>? slots,
    int? reminderMinutes,
    bool? silent,
  }) {
    return PrayerAlerts(
      enabled: enabled ?? this.enabled,
      slots: slots ?? this.slots,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      silent: silent ?? this.silent,
    );
  }

  /// Adds or removes one prayer, never letting الشروق in.
  PrayerAlerts toggling(PrayerSlot slot) {
    if (!slot.isPrayer) return this;
    final next = {...slots};
    if (!next.remove(slot)) next.add(slot);
    return copyWith(slots: next);
  }

  @override
  List<Object?> get props => [enabled, slots, reminderMinutes, silent];
}
