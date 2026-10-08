import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/states.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/prayer_times_cubit.dart';
import '../../domain/prayer_day.dart';
import '../../domain/prayer_fix.dart';
import '../../domain/prayer_text.dart';

// The names and the clock formats used to live at the foot of this file. They
// were moved out when the notification and the home-screen widget started
// saying the same words, and are re-exported so that everything already
// reaching for `slotName` through the card keeps working.
export '../../domain/prayer_text.dart';

/// What one cell costs a row besides the name in it: a pixel of margin each
/// side, and a pixel of rounding either way.
const _cellChrome = 4.0;

/// Below this a cell is single-row but tight, and the type steps down a point
/// rather than the names eliding.
const _comfortableCellWidth = 60.0;

/// مواقيت الصلاة for wherever this device is standing.
///
/// Two things are being said at once and the card is built around keeping them
/// apart, because a reader glancing at it for half a second has to come away
/// with both:
///
///   * WHAT IS OPEN NOW — the prayer whose time is running. It wears the app's
///     green, filled, in the strip along the bottom.
///   * WHAT IS COMING — the mark being counted down to. It wears gold, outlined,
///     and it owns the whole top half: the disc, the name, the clock and the
///     countdown.
///
/// And the third thing, which is the one most prayer cards get wrong: between
/// الشروق and الظهر nothing is open. That stretch is six hours long, it is the
/// longest window of the day, and a card that fills its "الصلاة الحالية" slot
/// with الشروق is telling a reader there is a prayer to be made when there is
/// not. Here the green does not appear at all in that window — see [_Cell] —
/// and a note says so in words.
///
/// Expects a [PrayerTimesCubit] above it; the home screen owns one so that
/// pull-to-refresh can reach it.
class PrayerTimesCard extends StatelessWidget {
  const PrayerTimesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrayerTimesCubit, PrayerTimesState>(
      builder: (context, state) {
        final day = state.day;
        final window = state.window;
        // Only until the remembered position comes back off disk — which is one
        // or two frames, and still worth drawing the right shape for.
        if (day == null || window == null) return const _Placeholder();

        return GlassCard(
          radius: AppRadius.xl,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            // As tall as what is in it, and no taller. In the ListView a phone
            // gets, a Column's default `max` costs nothing; in the fixed-height
            // side panel a monitor gets, it stretches the glass to the foot of
            // the screen.
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: AppSpacing.lg),
              // Everything that moves is inside here, and nothing else is: the
              // pane, its hairline and its shadow are painted once and left
              // alone while the seconds run.
              _Pulse(
                until: window.end,
                onElapsed: () =>
                    context.read<PrayerTimesCubit>().refreshWindow(),
                builder: (context, now) =>
                    _Upcoming(day: day, window: window, now: now),
              ),
              ?_gapNote(context, window),
              const SizedBox(height: AppSpacing.lg),
              Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: AppSpacing.md),
              _Strip(day: day, window: window),
            ],
          ),
        );
      },
    );
  }

  /// The line that only exists between الشروق and الظهر.
  Widget? _gapNote(BuildContext context, PrayerWindow window) {
    if (!window.inSunriseGap) return null;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: GlassSurface(
        radius: AppRadius.sm,
        blur: false,
        shadow: false,
        bordered: false,
        subtle: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.prayerSunrise,
              size: 15,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.prayerSunriseGapNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The head of the card: what it is, and where it is for ──────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.14),
          ),
          child: Icon(AppIcons.prayerTimes, size: 17, color: scheme.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            l.prayerTimesTitle,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const _LocationChip(),
      ],
    );
  }
}

/// Where the times are for, and the way to fix it when that is not here.
///
/// This chip is the card's whole answer to the permission question. Nothing
/// asks the device for a position on the way into the home screen — see
/// `PrayerTimesRepository.locate` — so on a first run the card computes مكة,
/// says "موقع تقريبي" in gold, and waits to be tapped. The system dialog then
/// appears one gesture after somebody read the words explaining what it is for,
/// which is the only moment it can honestly appear.
class _LocationChip extends StatelessWidget {
  const _LocationChip();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<PrayerTimesCubit>().state;

    final tone = state.approximate ? Accent.gold.of(context) : scheme.primary;
    final label = switch (state) {
      _ when state.locating => l.prayerLocating,
      _ when state.approximate => l.prayerApproximate,
      _ when state.place != null => placeName(l, state.place!),
      _ => l.prayerYourLocation,
    };

    final badge = GlassBadge(
      label: label,
      color: tone,
      icon: state.approximate ? AppIcons.myLocation : AppIcons.location,
      dense: true,
    );

    // Nothing to offer on a platform with no location provider, or after a
    // refusal the system will not re-ask. A chip that opens no dialog and
    // changes nothing should not invite the tap.
    if (state.locating || !state.canAskForLocation) return badge;

    return InkWell(
      onTap: () => _locate(context),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: badge,
    );
  }

  Future<void> _locate(BuildContext context) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<PrayerTimesCubit>();
    final outcome = await cubit.requestLocation();

    // Silence on success: the chip itself changes from "موقع تقريبي" to the
    // place, and the times move under it. A snack bar saying so would be a
    // second announcement of something already on screen.
    final message = switch (outcome) {
      LocationOutcome.located => null,
      LocationOutcome.serviceOff => l.locationServiceDisabled,
      LocationOutcome.needsPermission ||
      LocationOutcome.permanentlyDenied => l.locationPermissionDenied,
      LocationOutcome.failed => l.locationFailed,
    };
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // A refusal the app cannot lift on its own comes with the door to the
          // place where it can be. On Windows this is the whole of the fix —
          // there is no dialog behind the chip, only the system's switch — and
          // without this button the message names a wall and stops there.
          //
          // Not offered for a plain failure: a timeout is not a setting, and a
          // button that opens a page with nothing to change on it teaches the
          // reader that the button means nothing.
          action: outcome == LocationOutcome.failed
              ? null
              : SnackBarAction(
                  label: l.commonSettings,
                  onPressed: cubit.openLocationSettings,
                ),
        ),
      );
  }
}

// ── The top half: what is coming, and how long is left ─────────────────────

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.day, required this.window, required this.now});

  final PrayerDay day;
  final PrayerWindow window;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final gold = Accent.gold.of(context);

    // Tomorrow's فجر rather than the one in today's column, which has already
    // been and gone by the time this branch is taken.
    final at = window.nextIsTomorrow ? day.nextFajr : day.timeOf(window.next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gold.withValues(alpha: 0.26),
                    gold.withValues(alpha: 0.10),
                  ],
                ),
              ),
              child: Icon(iconFor(window.next), size: 21, color: gold),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // الشروق is not a prayer, so it is never announced as the
                    // next one. Inside الفجر the sentence is about that
                    // prayer's time running out, which is the fact worth
                    // knowing at four in the morning.
                    window.endsAtSunrise
                        ? l.prayerFajrEndsLabel
                        : l.prayerNextLabel,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _headline(l, at),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  countdownText(window.remainingAt(now)),
                  // Pinned LTR. The digits would come out in the right order
                  // under Arabic anyway — a run of numbers separated by colons
                  // is one bidi number — but this is the one string on the card
                  // that changes every second, and it is not worth depending on
                  // the algorithm to keep it from flipping.
                  textDirection: TextDirection.ltr,
                  style: text.titleLarge?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    // Otherwise the whole card twitches sideways once a second
                    // as a 1 replaces a 4.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  l.prayerRemainingLabel,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ProgressBar(value: window.progressAt(now), color: gold),
      ],
    );
  }

  /// "العصر · 3:42 م", and "غداً" appended when the mark is on the other side
  /// of midnight.
  String _headline(AppLocalizations l, DateTime at) {
    final name = slotName(l, window.next);
    final clock = clockText(l, at);
    return window.nextIsTomorrow
        ? '$name · $clock ${l.prayerTomorrow}'
        : '$name · $clock';
  }
}

/// How far through the current window the clock stands.
///
/// Fills from the reading side in both directions — [AlignmentDirectional] —
/// because a bar that empties leftward in Arabic reads as time running
/// backwards.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.onSurface.withValues(alpha: 0.09)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [color.withValues(alpha: 0.5), color],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The bottom half: the six marks of the day ──────────────────────────────

class _Strip extends StatelessWidget {
  const _Strip({required this.day, required this.window});

  final PrayerDay day;
  final PrayerWindow window;

  /// Whether every one of the six names is drawn in full in a cell this wide.
  ///
  /// Measured with the same [TextPainter] the cell will use, at the same style
  /// and the same font scale, against the longest name there actually is. The
  /// answer is therefore true in Arabic and in English, at the reader's own
  /// font scale, and on a device whose font metrics are nothing like the test
  /// machine's — none of which a constant can promise.
  static bool _fits(
    BuildContext context,
    double cellWidth, {
    required bool compact,
  }) {
    final l = context.l10n;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      // The heaviest of the three weights a cell uses: the current prayer is
      // bold, and it is the one that would overflow first.
      fontWeight: FontWeight.w700,
      fontSize: compact ? 10 : 11,
      height: 1.2,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final room = cellWidth - _cellChrome;

    for (final slot in PrayerSlot.values) {
      final painter = TextPainter(
        text: TextSpan(text: slotName(l, slot), style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > room) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final count = PrayerSlot.values.length;

        // Whether six fit on one line is ASKED, not estimated.
        //
        // It used to be a constant — 44 logical pixels per cell — and the
        // constant was simply wrong: at 44 the six stayed in one row and
        // المغرب lost its last letters at every phone width there is, 360
        // included. The rule above it was right and the number under it never
        // matched, which is the failure mode a magic number has.
        //
        // A number cannot be right here anyway. What fits depends on the
        // longest NAME — المغرب in Arabic, Sunrise in English, and neither is
        // the other's width — on the type scale the theme sets, and on the
        // font scale the reader chose in the phone's own settings. All three
        // are known at this point and none of them are known where a constant
        // is written.
        final oneRow = _fits(context, box.maxWidth / count, compact: false);
        final width = box.maxWidth / (oneRow ? count : 3);

        Widget cell(PrayerSlot slot) => _Cell(
          slot: slot,
          at: day.timeOf(slot),
          state: slot == window.current
              ? _CellState.current
              : slot == window.next
              ? _CellState.next
              : _CellState.plain,
          compact: width < _comfortableCellWidth,
        );

        Widget row(int start, int end) => Row(
          children: [
            for (var i = start; i < end; i++)
              Expanded(child: cell(PrayerSlot.values[i])),
          ],
        );

        if (oneRow) return row(0, count);
        return Column(
          children: [
            row(0, 3),
            const SizedBox(height: AppSpacing.sm),
            row(3, count),
          ],
        );
      },
    );
  }
}

enum _CellState { current, next, plain }

class _Cell extends StatelessWidget {
  const _Cell({
    required this.slot,
    required this.at,
    required this.state,
    required this.compact,
  });

  final PrayerSlot slot;
  final DateTime at;
  final _CellState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // The one rule this card exists to get right: الشروق never wears the colour
    // that means "a prayer is open". When the clock is inside the sunrise gap
    // it is still the `current` cell — that is where the reader is — but it is
    // marked in the surface's own grey, so the strip shows no green at all and
    // says, without a word, that nothing is due.
    final tone = switch (state) {
      _CellState.current =>
        slot.isPrayer ? scheme.primary : scheme.onSurfaceVariant,
      _CellState.next => Accent.gold.of(context),
      _CellState.plain => scheme.onSurfaceVariant,
    };

    final emphasised = state != _CellState.plain;

    return Semantics(
      label: switch (state) {
        _CellState.current when slot.isPrayer =>
          '${l.prayerNowLabel} · ${slotName(l, slot)}',
        _CellState.next => '${l.prayerNextLabel} · ${slotName(l, slot)}',
        _ => slotName(l, slot),
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: state == _CellState.current
              ? tone.withValues(alpha: 0.14)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          // Transparent rather than absent on a plain cell, so all six keep the
          // same inner height and their times sit on one line across the strip.
          border: Border.all(
            color: switch (state) {
              _CellState.current => tone.withValues(alpha: 0.34),
              _CellState.next => tone.withValues(alpha: 0.45),
              _CellState.plain => Colors.transparent,
            },
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slotName(l, slot),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                color: slot.isPrayer ? tone : tone.withValues(alpha: 0.72),
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
                fontSize: compact ? 10 : 11,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              // No ص/م down here. Six rows in their own order carry that on
              // their own — nobody reads الفجر at 4:32 as an afternoon — and
              // the two letters are the difference between a name that fits in
              // a 46-pixel column and one that does not.
              shortClockText(at),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: emphasised ? tone : scheme.onSurface,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
                fontSize: compact ? 11 : 12.5,
                height: 1.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The ticker ─────────────────────────────────────────────────────────────

/// Rebuilds its subtree once a second, and says when the moment it was watching
/// has gone by.
///
/// It reports the wall clock rather than counting down from a stored duration,
/// which is what makes it survive the phone being asleep: the first tick after
/// a resume already knows six hours have passed, redraws the right numbers, and
/// tells the cubit to move the window on. There is no separate resume handler
/// anywhere in this feature, and there does not need to be.
class _Pulse extends StatefulWidget {
  const _Pulse({
    required this.until,
    required this.onElapsed,
    required this.builder,
  });

  /// The moment [onElapsed] fires at — the end of the current window.
  final DateTime until;

  /// Fired once per [until]. Re-armed when a new one is handed down.
  final VoidCallback onElapsed;

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) _announced = false;
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    // A periodic timer drifts, and two ticks can land inside one second. The
    // card shows nothing finer than a second, so a repeat is a free rebuild.
    if (now.second == _now.second && now.minute == _now.minute) return;
    setState(() => _now = now);

    if (!_announced && !now.isBefore(widget.until)) {
      _announced = true;
      widget.onElapsed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

// ── The shape the card takes before its position is known ──────────────────

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    Widget bar(double height, {double? width}) => GlassSurface(
      radius: AppRadius.xs,
      blur: false,
      shadow: false,
      bordered: false,
      subtle: true,
      height: height,
      width: width,
      child: const SizedBox.shrink(),
    );

    return Shimmer(
      child: GlassCard(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(20, width: 130),
            const SizedBox(height: AppSpacing.lg),
            bar(44),
            const SizedBox(height: AppSpacing.md),
            bar(6),
            const SizedBox(height: AppSpacing.xl),
            bar(38),
          ],
        ),
      ),
    );
  }
}

// ── Naming and formatting ──────────────────────────────────────────────────

IconData iconFor(PrayerSlot slot) => switch (slot) {
  PrayerSlot.fajr || PrayerSlot.maghrib => AppIcons.prayerDawn,
  PrayerSlot.sunrise => AppIcons.prayerSunrise,
  PrayerSlot.dhuhr || PrayerSlot.asr => AppIcons.prayerNoon,
  PrayerSlot.isha => AppIcons.prayerNight,
};
