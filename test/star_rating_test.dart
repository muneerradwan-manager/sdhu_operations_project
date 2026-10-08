import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/domain/operational_module.dart';
import 'package:sdhu_operations_project/features/modules/presentation/widgets/star_rating.dart';

/// Rating a colleague has one move that is not obvious and matters more than
/// the rest: tapping the star the rating already ends on WITHDRAWS it.
///
/// Without that, the mildest thing anybody can say is one star. A rating given
/// by accident would have to be turned into an insult or left standing, and in
/// a scheme that is anonymous and permanent that is not a small thing.
void main() {
  Future<void> pumpStars(
    WidgetTester tester, {
    required double value,
    required void Function(int?) onRated,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: StarRating(value: value, onRated: onRated)),
      ),
    ),
  );

  testWidgets('tapping a star says that many', (tester) async {
    int? said = -1;
    await pumpStars(tester, value: 0, onRated: (v) => said = v);

    await tester.tap(find.byType(InkResponse).at(2));
    expect(said, 3);
  });

  testWidgets('tapping the star it already ends on takes it back', (
    tester,
  ) async {
    int? said = -1;
    await pumpStars(tester, value: 3, onRated: (v) => said = v);

    await tester.tap(find.byType(InkResponse).at(2));
    expect(said, isNull, reason: 'the third star of a three withdraws it');
  });

  testWidgets('tapping a different star changes it rather than withdrawing', (
    tester,
  ) async {
    int? said = -1;
    await pumpStars(tester, value: 3, onRated: (v) => said = v);

    await tester.tap(find.byType(InkResponse).at(4));
    expect(said, 5);
  });

  testWidgets('a read-only row cannot be tapped at all', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: StarRating(value: 4.2))),
      ),
    );

    expect(find.byType(InkResponse), findsNothing);
  });

  group('RatingSummary', () {
    test('nothing given reads as nothing, not as zero stars', () {
      expect(RatingSummary.none.isRated, isFalse);
      expect(RatingSummary.none.ratings, 0);
    });

    test('reads what the database returns', () {
      final s = RatingSummary.fromMap({'average': 4.25, 'ratings': 4});
      expect(s.average, 4.25);
      expect(s.ratings, 4);
      expect(s.isRated, isTrue);
    });
  });
}
