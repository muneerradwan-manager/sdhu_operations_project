import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/modules/domain/reference_item.dart';

ReferenceItem camp(String name, {String? site, String? season}) => ReferenceItem(
  id: '$name/$site',
  setId: 'camps',
  name: LocalizedName(ar: name),
  data: {'site': ?site},
  seasonId: season,
);

/// One list per kind of thing, and a level draws its own slice of it.
///
/// The مخيمات are ONE list — a camp is a camp — but المخيم رقم 11 at منى and
/// المخيم رقم 11 at عرفات are a kilometre apart. So the مشعر is part of what
/// identifies a camp rather than a note on it, and the منى file is offered
/// منى's camps only. A camp entered in the wrong مشعر is a mistake nothing
/// downstream can catch: the row is perfectly well-formed and simply false.
void main() {
  const mina = 'site-mina';
  const arafat = 'site-arafat';

  final camps = ReferenceSet(
    id: 'camps',
    code: 'camps',
    name: const LocalizedName(ar: 'المخيمات'),
    isSeasonScoped: true,
    items: [
      camp('المخيم رقم 11', site: mina, season: '1447'),
      camp('المخيم رقم 14', site: mina, season: '1447'),
      camp('المخيم رقم 11', site: arafat, season: '1447'),
      camp('المخيم رقم 16', site: arafat, season: '1447'),
      camp('المخيم رقم 11', site: mina, season: '1448'),
    ],
  );

  group('a level draws its own slice', () {
    test('the مشعر narrows the list', () {
      final offered = camps.itemsToOffer(
        '1447',
        filter: const {'site': mina},
      );

      expect(offered.map((i) => i.name.ar), ['المخيم رقم 11', 'المخيم رقم 14']);
    });

    test('the same NAME in the other مشعر is a different camp', () {
      // The reason the مشعر is part of the identity and not a label. Both lists
      // hold a "المخيم رقم 11" and they are different ground.
      final atMina = camps.itemsToOffer('1447', filter: const {'site': mina});
      final atArafat = camps.itemsToOffer(
        '1447',
        filter: const {'site': arafat},
      );

      expect(atMina.first.name.ar, atArafat.first.name.ar);
      expect(
        atMina.first.id,
        isNot(atArafat.first.id),
        reason: 'one name, two places',
      );
    });

    test('the season narrows it too, and both apply', () {
      // Two different questions — which season\'s camps, and then which
      // مشعر\'s — and answering only one of them was the bug this guards.
      final offered = camps.itemsToOffer(
        '1447',
        filter: const {'site': mina},
      );

      expect(offered.every((i) => i.seasonId == '1447'), isTrue);
      expect(offered, hasLength(2));
    });

    test('no filter is the whole season, not nothing', () {
      // Every level but the camps and the centres. A سطر that forgot to set a
      // filter must keep working exactly as it did before 0095.
      expect(camps.itemsToOffer('1447'), hasLength(4));
      expect(camps.itemsToOffer('1447', filter: const {}), hasLength(4));
    });

    test('a slice that does not exist is empty, not everything', () {
      // The failure mode worth choosing deliberately. A filter naming a مشعر
      // nobody is stationed in should show an empty picker — falling back to
      // the whole list would quietly offer عرفات's camps to منى, which is the
      // one thing the filter exists to prevent.
      expect(
        camps.itemsToOffer('1447', filter: const {'site': 'site-muzdalifah'}),
        isEmpty,
      );
      expect(
        camps.itemsToOffer('1447', filter: const {'nonsense': 'x'}),
        isEmpty,
      );
    });
  });

  test('an unscoped list ignores the season and still slices', () {
    // المراكز: the same مركز number is run at both مشاعر and neither is
    // contracted afresh each year, so the season narrowing does nothing here
    // and the مشعر narrowing does all the work.
    final centers = ReferenceSet(
      id: 'centers',
      code: 'centers',
      name: const LocalizedName(ar: 'المراكز'),
      items: [
        camp('المركز رقم 11', site: mina),
        camp('المركز رقم 15', site: mina),
        camp('المركز رقم 11', site: arafat),
      ],
    );

    expect(
      centers.itemsToOffer('1447', filter: const {'site': arafat}).single.name.ar,
      'المركز رقم 11',
    );
  });
}
