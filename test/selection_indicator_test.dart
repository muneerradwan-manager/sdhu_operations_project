import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/selection_indicator.dart';

/// The regression this guards against shipped once already: the unselected
/// state was `Iconsax.record` — a filled disc — and three of the four call
/// sites painted it in the PRIMARY colour, so an option nobody had chosen was
/// drawn exactly the way a chosen one should be.
///
/// So the rule is stated as a test rather than left to whoever edits the widget
/// next: empty is hollow, and the accent belongs to the chosen one alone.
void main() {
  late ColorScheme scheme;

  Future<BoxDecoration> pumpIndicator(
    WidgetTester tester, {
    required bool selected,
    SelectionShape shape = SelectionShape.one,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return Scaffold(
              body: SelectionIndicator(selected: selected, shape: shape),
            );
          },
        ),
      ),
    );
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('unselected is hollow, and never wears the accent', (
    tester,
  ) async {
    final decoration = await pumpIndicator(tester, selected: false);

    expect(decoration.color, isNot(scheme.primary));
    expect(decoration.border!.top.color, isNot(scheme.primary));
    // A ring, not a hairline: it has to be findable on a glass surface.
    expect(decoration.border!.top.width, greaterThan(1));
  });

  testWidgets('selected is filled in the accent', (tester) async {
    final decoration = await pumpIndicator(tester, selected: true);

    expect(decoration.color, scheme.primary);
  });

  testWidgets('the shape states what the group takes', (tester) async {
    final one = await pumpIndicator(tester, selected: false);
    expect(one.shape, BoxShape.circle);

    final many = await pumpIndicator(
      tester,
      selected: false,
      shape: SelectionShape.many,
    );
    expect(many.shape, BoxShape.rectangle);
    expect(many.borderRadius, isNotNull);
  });
}
