import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/app_theme.dart';
import 'package:sdhu_operations_project/features/prayer_times/application/prayer_times_cubit.dart';
import 'package:sdhu_operations_project/features/prayer_times/data/prayer_times_repository.dart';
import 'package:sdhu_operations_project/features/prayer_times/domain/prayer_day.dart';
import 'package:sdhu_operations_project/features/prayer_times/domain/prayer_fix.dart';
import 'package:sdhu_operations_project/features/prayer_times/presentation/widgets/prayer_times_card.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// What the card SAYS, in the three states a reader can actually catch it in.
///
/// The arithmetic behind them is walked minute by minute in
/// `prayer_times_test.dart`; this file is about whether the right sentence
/// reaches the screen, and whether six names and six clocks fit across a phone
/// and across a 320-wide side panel without a letter going missing.
///
/// The repository is stubbed rather than mocked at the channel: under
/// `flutter test` the location plugin never answers at all — the future simply
/// does not complete — so a card built on the real one is frozen on "جارٍ
/// تحديد موقعك…" forever and there is nothing to assert about it.
void main() {
  /// The Arabic the card actually speaks, read out of the same table it draws
  /// from rather than typed again here.
  ///
  /// It used to be typed again here, and the strings are now vocalised —
  /// الْفَجْرُ, not الفجر — so every literal in this file stopped matching at
  /// once. A copy of a sentence in a test is a second place that sentence is
  /// written, and the second place is never the one that gets corrected.
  late AppLocalizations ar;

  /// The six marks, in the order the strip lays them out.
  late List<String> arabicNames;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
    arabicNames = [
      ar.prayerFajr,
      ar.prayerSunrise,
      ar.prayerDhuhr,
      ar.prayerAsr,
      ar.prayerMaghrib,
      ar.prayerIsha,
    ];
  });

  /// Answers where the platform would, and hands back whichever day the test
  /// needs to put the clock inside a particular window.
  ///
  /// [dayBuilder] is given the real `now`, so a day it builds is arranged
  /// around whatever hour the suite happens to run at. Nothing here depends on
  /// the wall clock; everything is placed relative to it.
  PrayerTimesCubit stubbed({
    PrayerFix? fix,
    LocationOutcome outcome = LocationOutcome.needsPermission,
    PrayerDay Function(DateTime now)? dayBuilder,
  }) {
    return PrayerTimesCubit(
      _StubRepository(fix: fix, outcome: outcome, dayBuilder: dayBuilder),
    );
  }

  Widget harness(
    PrayerTimesCubit cubit, {
    required double width,
    required Locale locale,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark(),
      home: Scaffold(
        // Unbounded height, which is what the card gets in the app: a ListView
        // on a phone, a scrolling panel on a monitor. A bounded box would let a
        // stretching Column hide behind the test's own 600 pixels.
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: width,
              child: BlocProvider.value(
                value: cubit,
                child: const PrayerTimesCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the card and lets the boot chain settle.
  ///
  /// Not `pumpAndSettle`: the card holds a one-second ticker that schedules a
  /// frame forever, and settling would wait for an end that never comes.
  Future<void> show(
    WidgetTester tester,
    PrayerTimesCubit cubit, {
    required double width,
    Locale locale = const Locale('ar'),
  }) async {
    await tester.pumpWidget(harness(cubit, width: width, locale: locale));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  /// Takes the tree down before the test ends, so the ticker and the cubit's
  /// boundary timer are cancelled rather than reported as still pending.
  Future<void> dismiss(WidgetTester tester, PrayerTimesCubit cubit) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  }

  /// Whether [name] reached the screen WHOLE, rather than trimmed to an
  /// ellipsis.
  ///
  /// `find.text` cannot answer this and never could: it matches the semantic
  /// string, so a cell painting "المغ…" still answers to `find.text('المغرب')`.
  /// For a long time the test above asserted "none of them elide" with exactly
  /// that finder, and المغرب was in fact losing its last letters at every phone
  /// width there is — the assertion was true and the sentence it was written to
  /// defend was false.
  ///
  /// So it is measured: the painted box against what the same string wants at
  /// the same style. Anything wider than its box has been cut.
  void expectDrawnInFull(
    WidgetTester tester,
    String name, {
    TextDirection direction = TextDirection.rtl,
  }) {
    final finder = find.text(name);
    final box = tester.getRect(finder);
    final painter = TextPainter(
      text: TextSpan(text: name, style: tester.widget<Text>(finder).style),
      textDirection: direction,
      maxLines: 1,
    )..layout();

    expect(
      painter.width,
      lessThanOrEqualTo(box.width + 0.5),
      reason: '"$name" was cut: it wants ${painter.width.toStringAsFixed(1)} '
          'and was given ${box.width.toStringAsFixed(1)}',
    );
  }

  group('the strip', () {
    testWidgets('a phone gets all six marks, and none of them elide', (
      tester,
    ) async {
      final cubit = stubbed(fix: _mina);
      await show(tester, cubit, width: 360);

      expect(tester.takeException(), isNull);
      for (final name in arabicNames) {
        // Once each: the strip. The headline names the coming mark too, but as
        // "العصر · 3:42 م" — one Text, and never an exact match for this.
        expect(find.text(name), findsOneWidget, reason: name);
        // And whole. This is the half the finder cannot see, and the half the
        // strip's whole layout exists to protect.
        expectDrawnInFull(tester, name);
      }

      await dismiss(tester, cubit);
    });

    testWidgets('nor at the narrowest panel the app puts it in', (
      tester,
    ) async {
      final cubit = stubbed(fix: _mina);
      await show(tester, cubit, width: 320);

      for (final name in arabicNames) {
        expectDrawnInFull(tester, name);
      }

      await dismiss(tester, cubit);
    });

    testWidgets('a narrow panel folds the six into two rows of three', (
      tester,
    ) async {
      // The two widths are not arbitrary and are not a phone and a tablet.
      // They are one on each side of the only line that matters: whether six
      // names fit across without one being cut.
      //
      // Where that line falls is no longer a number in the source — the strip
      // measures the actual names, at the actual style and font scale, so it
      // moves with the language and with whatever the reader set in the
      // phone's own settings. It sits above every phone width, which is the
      // finding that put this test right: six Arabic names have never fitted
      // across a phone, and the card was quietly clipping المغرب on all of
      // them while a constant of 44 said they fitted.
      final narrow = stubbed(fix: _mina);
      await show(tester, narrow, width: 320);
      expect(tester.takeException(), isNull);
      for (final name in arabicNames) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      final rowsWhenNarrow = _rowCount(tester, arabicNames);
      final folded = tester.getSize(find.byType(PrayerTimesCard)).height;
      await dismiss(tester, narrow);

      final wide = stubbed(fix: _mina);
      await show(tester, wide, width: 700);
      final rowsWhenWide = _rowCount(tester, arabicNames);
      final flat = tester.getSize(find.byType(PrayerTimesCard)).height;
      await dismiss(tester, wide);

      expect(rowsWhenNarrow, 2, reason: 'the narrow panel should fold');
      expect(rowsWhenWide, 1, reason: 'a wide one has no reason to');

      // And the fold is what costs the height. Asserted as well as the row
      // count because the height is what a reader actually notices, and a
      // layout that folded without growing would mean the second row had
      // landed on top of the first.
      expect(folded, greaterThan(flat));
    });

    testWidgets('English fits the same columns', (tester) async {
      final cubit = stubbed(fix: _mina);
      await show(tester, cubit, width: 360, locale: const Locale('en'));

      expect(tester.takeException(), isNull);
      for (final name in [
        'Fajr',
        'Sunrise',
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
        // English asks for less room than Arabic, so it may well fit across
        // where المغرب does not — the strip decides per language rather than
        // per width, and this is the half of that which is worth pinning.
        expectDrawnInFull(tester, name, direction: TextDirection.ltr);
      }
      expect(find.text('Prayer times'), findsOneWidget);

      await dismiss(tester, cubit);
    });
  });

  group('what it says about where it is', () {
    testWidgets('with no position of its own it says so rather than pretending', (
      tester,
    ) async {
      // The times on screen are مكة's. Saying "موقعك" over them would be a lie,
      // and saying nothing would leave a reader in Damascus with a Fajr an hour
      // out and no way to tell.
      final cubit = stubbed();
      await show(tester, cubit, width: 360);

      expect(find.text(ar.prayerApproximate), findsOneWidget);
      expect(cubit.state.approximate, isTrue);
      // And there is something to be done about it, so the chip takes a tap.
      expect(cubit.state.canAskForLocation, isTrue);

      await dismiss(tester, cubit);
    });

    testWidgets('a fix inside the مشاعر is named, not spelled in degrees', (
      tester,
    ) async {
      final cubit = stubbed(fix: _mina, outcome: LocationOutcome.located);
      await show(tester, cubit, width: 360);

      expect(find.text(ar.prayerPlaceMina), findsOneWidget);
      expect(find.text(ar.prayerApproximate), findsNothing);

      await dismiss(tester, cubit);
    });

    testWidgets('a fix outside every named place falls back to "موقعك"', (
      tester,
    ) async {
      // Damascus, where the mission comes from.
      final cubit = stubbed(
        fix: PrayerFix(
          latitude: 33.5138,
          longitude: 36.2765,
          capturedAt: DateTime.now(),
        ),
        outcome: LocationOutcome.located,
      );
      await show(tester, cubit, width: 360);

      expect(find.text(ar.prayerYourLocation), findsOneWidget);

      await dismiss(tester, cubit);
    });
  });

  group('the window it is standing in', () {
    testWidgets('between الشروق and الظهر it says no prayer is due', (
      tester,
    ) async {
      // The whole reason this card exists in the shape it does. Six hours of
      // every day have no prayer in them, and a card that fills its "الصلاة
      // الحالية" slot with الشروق tells a reader there is one.
      final cubit = stubbed(fix: _mina, dayBuilder: _dayInSunriseGap);
      await show(tester, cubit, width: 360);

      expect(find.text(ar.prayerSunriseGapNote), findsOneWidget);
      // And what it counts down to is الظهر, which IS a prayer.
      expect(find.textContaining('${ar.prayerDhuhr} ·'), findsOneWidget);
      expect(cubit.state.window!.inSunriseGap, isTrue);

      await dismiss(tester, cubit);
    });

    testWidgets('inside الفجر it counts to the end of the prayer, not to one', (
      tester,
    ) async {
      final cubit = stubbed(fix: _mina, dayBuilder: _dayInFajr);
      await show(tester, cubit, width: 360);

      // Not "الصلاة القادمة: الشروق" — الشروق is not a prayer and is never
      // announced as the next one.
      expect(find.text(ar.prayerFajrEndsLabel), findsOneWidget);
      expect(find.text(ar.prayerNextLabel), findsNothing);
      expect(find.textContaining('${ar.prayerSunrise} ·'), findsOneWidget);
      // No gap note here: الفجر is open, and something IS due.
      expect(find.text(ar.prayerSunriseGapNote), findsNothing);

      await dismiss(tester, cubit);
    });

    testWidgets('in an ordinary window it announces the next prayer', (
      tester,
    ) async {
      final cubit = stubbed(fix: _mina, dayBuilder: _dayInAsr);
      await show(tester, cubit, width: 360);

      expect(find.text(ar.prayerNextLabel), findsOneWidget);
      expect(find.textContaining('${ar.prayerMaghrib} ·'), findsOneWidget);
      expect(find.text(ar.prayerFajrEndsLabel), findsNothing);

      await dismiss(tester, cubit);
    });
  });
}

final _mina = PrayerFix(
  latitude: 21.4133,
  longitude: 39.8933,
  capturedAt: DateTime.now(),
);

/// Days built around the real `now`, so that whichever hour the suite runs at,
/// the clock lands in the window under test.
///
/// The marks outside that window are placed only far enough away to keep the
/// order; nothing reads them.
PrayerDay _dayAround(
  DateTime now, {
  required Duration fajr,
  required Duration sunrise,
  required Duration dhuhr,
  required Duration asr,
  required Duration maghrib,
  required Duration isha,
}) {
  return PrayerDay(
    day: DateTime(now.year, now.month, now.day),
    fajr: now.add(fajr),
    sunrise: now.add(sunrise),
    dhuhr: now.add(dhuhr),
    asr: now.add(asr),
    maghrib: now.add(maghrib),
    isha: now.add(isha),
    previousIsha: now.add(fajr - const Duration(hours: 8)),
    nextFajr: now.add(isha + const Duration(hours: 8)),
  );
}

PrayerDay _dayInSunriseGap(DateTime now) => _dayAround(
  now,
  fajr: const Duration(hours: -4),
  sunrise: const Duration(hours: -3),
  dhuhr: const Duration(hours: 1),
  asr: const Duration(hours: 4),
  maghrib: const Duration(hours: 7),
  isha: const Duration(hours: 8),
);

PrayerDay _dayInFajr(DateTime now) => _dayAround(
  now,
  fajr: const Duration(minutes: -30),
  sunrise: const Duration(minutes: 55),
  dhuhr: const Duration(hours: 7),
  asr: const Duration(hours: 10),
  maghrib: const Duration(hours: 13),
  isha: const Duration(hours: 14),
);

PrayerDay _dayInAsr(DateTime now) => _dayAround(
  now,
  fajr: const Duration(hours: -11),
  sunrise: const Duration(hours: -10),
  dhuhr: const Duration(hours: -3),
  asr: const Duration(minutes: -40),
  maghrib: const Duration(hours: 2),
  isha: const Duration(hours: 3),
);

/// Everything the platform would answer, answered.
///
/// Only the two calls that cross a boundary are overridden. [dayFor] is left
/// alone unless a test needs the clock in a particular window — the astronomy
/// is the same code the app runs.
class _StubRepository extends PrayerTimesRepository {
  _StubRepository({
    required this.fix,
    required this.outcome,
    required this.dayBuilder,
  });

  final PrayerFix? fix;
  final LocationOutcome outcome;
  final PrayerDay Function(DateTime now)? dayBuilder;

  @override
  Future<PrayerFix?> lastKnownFix() async => fix;

  @override
  Future<LocationResult> locate({required bool prompt}) async =>
      LocationResult(outcome, outcome == LocationOutcome.located ? fix : null);

  @override
  PrayerDay dayFor({
    required double latitude,
    required double longitude,
    DateTime? at,
  }) {
    final builder = dayBuilder;
    if (builder == null) {
      return super.dayFor(latitude: latitude, longitude: longitude, at: at);
    }
    return builder(at ?? DateTime.now());
  }
}

/// How many rows the six marks landed on.
///
/// Counted from where each name was PAINTED rather than from the widget tree:
/// the strip builds either one Row of six or a Column of two Rows of three, and
/// the tops of the boxes say which happened without this test having to know
/// the shape of either.
int _rowCount(WidgetTester tester, List<String> names) => {
  for (final name in names) tester.getRect(find.text(name)).top.roundToDouble(),
}.length;
