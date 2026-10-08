import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/modules/domain/module_type.dart';
import 'package:sdhu_operations_project/features/modules/domain/reference_item.dart';

ModuleField pointer(String key, String at) => ModuleField(
  id: key,
  key: key,
  label: LocalizedName(ar: key),
  kind: ModuleFieldKind.reference,
  referenceSetId: at,
);

ModuleField plain(String key, ModuleFieldKind kind) => ModuleField(
  id: key,
  key: key,
  label: LocalizedName(ar: key),
  kind: kind,
);

ReferenceItem entry(String name, Map<String, dynamic> data) => ReferenceItem(
  id: name,
  setId: 's',
  name: LocalizedName(ar: name),
  data: data,
);

/// Which lists show up already divided, and which do not.
///
/// Nothing declares this. It falls out of the schema: a list whose entries each
/// POINT at an entry of another list is a list that is already in groups, and
/// the group is the thing pointed at. الفنادق carry a city, المخيمات and
/// المراكز carry a مشعر. A list added next season carrying something similar is
/// divided too, with nothing written for it.
void main() {
  group('a list that is already in groups', () {
    test('the hotels fall into their cities', () {
      final hotels = ReferenceSet(
        id: 'h',
        code: 'hotels',
        name: const LocalizedName(ar: 'الفنادق'),
        fields: [pointer('city', 'cities'), plain('rooms', ModuleFieldKind.number)],
        items: [
          entry('فيلفيت ان', {'city': 'makkah', 'rooms': 120}),
          entry('زمزم بولمان', {'city': 'madinah'}),
          entry('دار الإيمان', {'city': 'makkah'}),
        ],
      );

      expect(hotels.dividingField()?.key, 'city');
    });

    test('a list with nothing to point at is undivided', () {
      final cities = ReferenceSet(
        id: 'c',
        code: 'cities',
        name: const LocalizedName(ar: 'المدن'),
        fields: [plain('note', ModuleFieldKind.text)],
        items: [entry('مكة', {}), entry('المدينة', {})],
      );

      expect(cities.dividingField(), isNull);
    });
  });

  group('the guard on how many', () {
    ReferenceSet withValues(Iterable<String> values) => ReferenceSet(
      id: 's',
      code: 'groups',
      name: const LocalizedName(ar: 'المجموعات'),
      fields: [pointer('hotel', 'hotels')],
      items: [
        for (final (i, v) in values.indexed) entry('g$i', {'hotel': v}),
      ],
    );

    test('one value is not a division', () {
      // Every camp at منى and none anywhere else. A single tab beside الكل says
      // nothing and costs a row of the screen.
      expect(withValues(['a', 'a', 'a']).dividingField(), isNull);
    });

    test('thirty is not a division either', () {
      // المجموعات point at a hotel. Thirty tabs is not a division of the list —
      // it is the list again, laid sideways and harder to read.
      final many = List.generate(30, (i) => 'hotel-$i');

      expect(withValues(many).dividingField(), isNull);
    });

    test('the boundary is where it says it is', () {
      expect(withValues(['a', 'b', 'c', 'd', 'e', 'f']).dividingField(), isNotNull);
      expect(
        withValues(['a', 'b', 'c', 'd', 'e', 'f', 'g']).dividingField(),
        isNull,
      );
    });

    test('counted over entries that exist, not over the target list', () {
      // A cities list of fourteen that only two hotels ever name is two tabs.
      // What matters is how many groups a reader would actually meet.
      expect(withValues(['a', 'b']).dividingField(), isNotNull);
    });

    test('an empty list divides into nothing', () {
      expect(withValues(const []).dividingField(), isNull);
    });
  });

  test('an unset pointer is not a group of its own', () {
    // Entries with no مشعر chosen must not invent a third tab here — the screen
    // gives them «بلا تصنيف», which is a different question from whether the
    // list is divisible at all.
    final camps = ReferenceSet(
      id: 's',
      code: 'camps',
      name: const LocalizedName(ar: 'المخيمات'),
      fields: [pointer('site', 'holy_sites')],
      items: [
        entry('11', {'site': 'mina'}),
        entry('12', {'site': 'arafat'}),
        entry('13', const {}),
        entry('14', {'site': ''}),
      ],
    );

    expect(camps.dividingField()?.key, 'site');
  });
}
