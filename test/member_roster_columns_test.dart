import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/glass_tokens.dart';
import 'package:sdhu_operations_project/core/widgets/responsive.dart';

/// Every roster of people on the module screen has to column alike.
///
/// There are three of them, laid out by three different widgets: the members
/// held on a قطاع or مركز, the members held on a برج or مخيم, and the members
/// held on the FILE — فريق الكوسترات and every flat roster file. When their
/// thresholds drift apart the same screen shows two columns in one section and
/// one in the next, and files differ from each other for no reason a reader can
/// see: مخيمات عرفات is the only one of the three tree files with no file-level
/// team, so it alone looked right.
///
/// They now agree by CONSTRUCTION rather than by arithmetic. Every roster sits
/// inside a card — the card is the group, the people are tiles in it — so all
/// three ask the same grid for the same width inside the same padding. The two
/// constants that used to differ have become one.
///
/// Which leaves this file two jobs rather than the one it was written for: that
/// the surviving numbers still column sensibly at the widths people work at,
/// and that a roster put back OUTSIDE a card would be caught. The numbers are
/// restated rather than imported because they are private to that screen, and
/// because restating them is what makes a silent edit fail here.
const _member = 340.0; // the width a member tile actually wants
const _nested = _member - AppSpacing.lg; // _kNestedMemberWidth — inside a card
const _cardPadding =
    AppSpacing.md * 2; // the group card eats this before the grid
const _panelWidth = 380.0; // TwoPaneLayout on this screen

double _gutter(double w) => switch (WindowSize.fromWidth(w)) {
  WindowSize.compact => AppSpacing.lg,
  WindowSize.medium || WindowSize.expanded => AppSpacing.xl,
  WindowSize.large || WindowSize.extraLarge => AppSpacing.xxl,
};

/// The width the page hands to a section, panel taken out when there is one.
double _content(double window) {
  final g = _gutter(window);
  return WindowSize.fromWidth(window).hasSidePanel
      ? window - 3 * g - _panelWidth
      : window - 2 * g;
}

/// What all three rosters now do: a grid inside a group card.
int _roster(double window) => columnsFor(
  _content(window) - _cardPadding,
  minTileWidth: _nested,
  maxColumns: 4,
  spacing: AppSpacing.lg,
);

/// What a roster laid out loose on the page WOULD do — no card to sit in, and
/// so the full tile width against the full content width.
///
/// Not a layout this screen has any more. It is kept as the counter-example the
/// agreement is measured against: put a roster back outside a card and this is
/// the number it would column to, and the first test below says that number has
/// to be the same one everything else reaches.
int _looseOnPage(double window) =>
    columnsFor(_content(window), minTileWidth: _member, maxColumns: 4);

void main() {
  // The widths people actually work at: phones, tablets, the laptop lids this
  // mission carries, a half-screen window, and a desk monitor.
  const widths = <double>[
    360,
    390,
    412,
    768,
    800,
    1024,
    1200,
    1280,
    1366,
    1440,
    1536,
    1600,
    1920,
    2560,
  ];

  group('member rosters column alike', () {
    for (final w in widths) {
      test('at ${w.toInt()} a roster in a card columns like one out of it', () {
        // The three rosters are one layout now and cannot disagree with each
        // other. What can still drift is the pair of numbers that layout is
        // built from: shrink the tile allowance or fatten the card's padding
        // and the people inside a card start columning one behind everything
        // else on the page — which is the bug this file was opened for, in the
        // only form it can still take.
        final inCard = _roster(w);
        final loose = _looseOnPage(w);
        expect(
          inCard,
          loose,
          reason:
              'at $w: inside a card=$inCard, loose on the page=$loose — the '
              'card is eating a column that the width alone would have given',
        );
      });
    }

    test('a desk monitor gets more than one column', () {
      expect(_roster(1440), greaterThan(1));
    });

    test('1200 is not a hole: the panel arrives without costing a column', () {
      // The width the tree grid used to drop to one at, while the roster
      // beside it kept two.
      expect(_roster(1200), 2);
    });

    test('a phone is one column, and honestly so', () {
      expect(_roster(390), 1);
    });
  });
}
