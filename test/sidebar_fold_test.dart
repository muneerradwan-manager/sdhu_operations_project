import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/router/app_router.dart';
import 'package:sdhu_operations_project/features/auth/application/session_cubit.dart';
import 'package:sdhu_operations_project/features/home/presentation/widgets/app_sidebar.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile_enums.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// The rail folds from 288 pixels down to 76 and back, and everything in it has
/// to survive both widths and every width between.
///
/// The first build of it did not. A tile draws its outline whether or not it is
/// the current one — transparent when it is not, so that becoming current does
/// not shift the label sideways — and `Border.all` is a real pixel on each
/// side. Left out of the arithmetic, the folded rail handed its 24-pixel glyph
/// a 22-pixel box and painted a yellow-and-black stripe down the entire column,
/// on every tile, on every frame. It reached a running app before anybody saw
/// it, because nothing here measured the closed state.
///
/// So: the rail is built at both widths, in both directions, and asked whether
/// it threw. `takeException` returns the overflow assertion when it did.
void main() {
  /// The labels as the rail draws them, not a copy of them typed here — the
  /// Arabic is vocalised, and a literal would be a second spelling of the
  /// same word for the first edit to leave behind.
  late AppLocalizations ar;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  final admin = SessionState(
    status: SessionStatus.approved,
    profile: const Profile(
      id: 'admin',
      firstName: 'محمد',
      accountStatus: AccountStatus.approved,
      isAdmin: true,
    ),
  );

  /// The rail at the width the shell would give it, and nothing else.
  Widget rail({
    required bool expanded,
    required SessionState session,
    String location = Routes.home,
    TextDirection direction = TextDirection.rtl,
    double? width,
  }) => MaterialApp(
    locale: direction == TextDirection.rtl
        ? const Locale('ar')
        : const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width:
            width ?? (expanded ? kRailExpandedWidth : kRailCollapsedWidth),
        height: 900,
        child: AppSidebar(
          session: session,
          location: location,
          expanded: expanded,
          onToggle: () {},
        ),
      ),
    ),
  );

  for (final rtl in [true, false]) {
    final way = rtl ? 'right to left' : 'left to right';

    testWidgets('the rail standing open fits its column, $way', (tester) async {
      await tester.pumpWidget(
        rail(
          expanded: true,
          session: admin,
          direction: rtl ? TextDirection.rtl : TextDirection.ltr,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the rail folded to its icons fits its column, $way', (
      tester,
    ) async {
      await tester.pumpWidget(
        rail(
          expanded: false,
          session: admin,
          direction: rtl ? TextDirection.rtl : TextDirection.ltr,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('and at every width between the two', (tester) async {
    // The fold is an animation, so the column spends 220ms at widths that are
    // neither. A tile that fits at both ends and overflows in the middle is
    // still a stripe across the screen — just a brief one, on the gesture the
    // reader performs most.
    for (var w = kRailCollapsedWidth; w <= kRailExpandedWidth; w += 8) {
      await tester.pumpWidget(
        rail(expanded: true, session: admin, width: w),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'overflowed at $w');
    }
  });

  testWidgets('an account holding nothing gets a rail of its own work', (
    tester,
  ) async {
    // The rail reads the same catalogue the tiles do, so a member sees العام
    // and no administered shelf at all — and the column still has to draw
    // itself without the shelves that are missing.
    await tester.pumpWidget(
      rail(
        expanded: true,
        session: SessionState(status: SessionStatus.approved),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(ar.navEmployees), findsNothing);
    expect(find.text(ar.navModules), findsOneWidget);
  });

  testWidgets('exactly one entry is drawn as current', (tester) async {
    // What makes a rail a rail rather than a menu. `/modules/manage` starts
    // with `/modules`, so a prefix match here would light the office's entry
    // and the member's at once — the two are matched exactly, like the route
    // guards they are drawn by.
    await tester.pumpWidget(
      rail(
        expanded: true,
        session: admin,
        location: Routes.modulesManage,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final lit = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color != null &&
              (c.decoration! as BoxDecoration).color!.a > 0.10 &&
              (c.decoration! as BoxDecoration).borderRadius != null,
        );

    expect(
      lit.length,
      1,
      reason: 'the rail lit ${lit.length} entries for one location',
    );
  });
}
