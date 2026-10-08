import '../../../core/l10n/localized_name.dart';
import 'module_type.dart';

/// How full a place is: the mission's own people housed or posted there, the
/// pilgrims its dependent entries add up to, and the ceiling the entry states.
///
/// The two counts were each true and never added together — the pilgrims were
/// worked out on this screen and the staff nowhere at all, so a فندق of 130 beds
/// holding 128 حاجّ and 8 of the mission read as comfortably inside its
/// capacity. A bed is a bed (0139).
class PlaceOccupancy {
  const PlaceOccupancy({
    required this.staff,
    required this.pilgrims,
    this.capacity,
  });

  final int staff;
  final int pilgrims;

  /// Null where the entry states none — 3142 states no capacity for some
  /// hotels, and a ceiling nobody set is not a ceiling of zero.
  final int? capacity;

  int get total => staff + pilgrims;

  bool get isOver => capacity != null && total > capacity!;

  int get excess => capacity == null ? 0 : total - capacity!;

  factory PlaceOccupancy.fromRow(Map<String, dynamic> row) => PlaceOccupancy(
    staff: (row['staff'] as int?) ?? 0,
    pilgrims: (row['pilgrims'] as int?) ?? 0,
    capacity: row['capacity'] as int?,
  );
}

/// One admin-managed master-data list (hotels, clusters, cities, …).
///
/// A set carries its own item schema in [fields], the same way a module type
/// carries a field schema — which is what lets "manage hotels" and "manage
/// clusters" be one screen reading two different shapes.
class ReferenceSet {
  const ReferenceSet({
    required this.id,
    required this.code,
    required this.name,
    this.fields = const [],
    this.items = const [],
    this.isSeasonScoped = false,
    this.isPlace = false,
    this.section,
  });

  /// The one list this app names by code. Accommodation is hotels and not
  /// places-in-general: a مخيم is a place a man works at for five days of the
  /// rites, not the bed he keeps for a month, and `housing_for` says the same
  /// thing in SQL (0136, 0139).
  static const hotelsCode = 'hotels';

  final String id;
  final String code;
  final LocalizedName name;
  final List<ModuleField> fields;
  final List<ReferenceItem> items;

  /// Whether an entry of this set belongs to one season. The hotels and the
  /// clusters are contracted per year; the cities simply exist.
  final bool isSeasonScoped;

  /// Whether an entry of this set is somewhere a person STANDS — a فندق, a
  /// مخيم. Those carry a check-in code; a قطاع, a مركز and a تكتل are
  /// arrangements on paper and carry nothing (0098).
  ///
  /// Not the same question as `ModuleLevel.isPlace`, which decides what the map
  /// draws. A level may be a pin while drawing from a list nobody checks in at.
  final bool isPlace;

  /// Which shelf this list is shown under (0101), or null for the trailing
  /// "other" one.
  ///
  /// A KEY, not a label: the wording is in the app because a shelf title is
  /// content in two languages. The grouping itself is editorial — nothing in
  /// the schema says a فندق and a مخيم belong together while a مركز belongs
  /// elsewhere — so it lives in the database rather than in Dart, and a list
  /// added by a future migration names its own shelf instead of waiting for
  /// somebody to edit this app.
  final String? section;

  /// The entries to CHOOSE from in [seasonId] — this season's for a scoped set,
  /// all of them otherwise.
  ///
  /// Never use this to resolve an id to a name: a tower in last season's file
  /// points at last season's hotel, and it still has to render.
  List<ReferenceItem> itemsForSeason(String? seasonId) {
    if (!isSeasonScoped || seasonId == null) return items;
    return items.where((i) => i.seasonId == seasonId).toList();
  }

  /// The entries to CHOOSE from when the asker may only have part of the list.
  ///
  /// Two narrowings, asking different questions, and both apply: which season's
  /// camps, and then which مشعر's. Since 0095 one مخيمات list serves both
  /// مشاعر — a camp is a camp — but المخيم رقم 11 at منى and المخيم رقم 11 at
  /// عرفات are a kilometre apart, and offering the منى file both is offering it
  /// a mistake nothing downstream can catch: the row would be perfectly
  /// well-formed and simply false.
  ///
  /// [filter] comes from `module_type_levels.reference_filter` and is matched
  /// by containment, exactly as the server's `@>` would read it: every key
  /// present and equal. An unknown key therefore narrows to nothing rather than
  /// being ignored — a level asking for a slice that does not exist should show
  /// an empty picker, not the whole list.
  List<ReferenceItem> itemsToOffer(
    String? seasonId, {
    Map<String, dynamic>? filter,
  }) {
    final scoped = itemsForSeason(seasonId);
    if (filter == null || filter.isEmpty) return scoped;

    return scoped
        .where(
          (item) =>
              filter.entries.every((want) => item.data[want.key] == want.value),
        )
        .toList();
  }

  /// The field this list already falls into groups by, or null if it has none
  /// worth showing.
  ///
  /// Not declared anywhere. It falls out of the schema: a list whose entries
  /// each POINT at an entry of another list is a list that is already divided,
  /// and the division is the thing pointed at. الفنادق carry a city, المخيمات
  /// and المراكز carry a مشعر. A list added next season that carries something
  /// similar is divided too, with nothing written for it.
  ///
  /// [atMost] is what keeps this from being silly. المجموعات point at a hotel,
  /// and thirty tabs is not a division of anything — it is the list again, laid
  /// sideways and harder to read. Two or three is a division; thirty is a
  /// coincidence of shape.
  ///
  /// Counted over entries that EXIST rather than over the target list, because
  /// what matters is how many groups a reader would actually meet: a cities
  /// list of fourteen that only two hotels ever name is still two tabs.
  ModuleField? dividingField({int atMost = 6}) {
    for (final field in fields) {
      if (field.kind != ModuleFieldKind.reference) continue;
      if (field.referenceSetId == null) continue;
      final values = items
          .map((i) => i.data[field.key])
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .toSet();
      if (values.length >= 2 && values.length <= atMost) return field;
    }
    return null;
  }

  ReferenceSet copyWith({List<ReferenceItem>? items}) => ReferenceSet(
    id: id,
    code: code,
    name: name,
    fields: fields,
    items: items ?? this.items,
    isSeasonScoped: isSeasonScoped,
    // Every level goes through here while a set is narrowed, so anything left
    // out is not "defaulted" — it is ERASED, silently, on the way through.
    isPlace: isPlace,
    section: section,
  );

  factory ReferenceSet.fromMap(Map<String, dynamic> map) {
    final fields = ((map['reference_set_fields'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
    fields.sort(
      (a, b) => ((a['sort_order'] as int?) ?? 0).compareTo(
        (b['sort_order'] as int?) ?? 0,
      ),
    );
    final items = ((map['reference_items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ReferenceItem.fromMap)
        .toList();
    items.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.ar.compareTo(b.name.ar);
    });
    return ReferenceSet(
      id: map['id'] as String,
      code: map['code'] as String,
      name: LocalizedName.fromMap(map),
      fields: fields.map(ModuleField.fromMap).toList(),
      items: items,
      isSeasonScoped: (map['is_season_scoped'] as bool?) ?? false,
      isPlace: (map['is_place'] as bool?) ?? false,
      section: map['section'] as String?,
    );
  }
}

/// One entry in a set: its name, plus the values of whatever fields its set
/// defines, keyed by field key.
class ReferenceItem {
  const ReferenceItem({
    required this.id,
    required this.setId,
    required this.name,
    this.data = const {},
    this.isActive = true,
    this.sortOrder = 0,
    this.seasonId,
  });

  final String id;
  final String setId;
  final LocalizedName name;
  final Map<String, dynamic> data;
  final bool isActive;
  final int sortOrder;

  /// The season this entry was contracted for, for a set that is scoped to one.
  /// Null on the sets that are not, and on entries that predate the scoping.
  final String? seasonId;

  factory ReferenceItem.fromMap(Map<String, dynamic> map) => ReferenceItem(
    id: map['id'] as String,
    setId: map['set_id'] as String,
    name: LocalizedName.fromMap(map),
    data: Map<String, dynamic>.from(
      (map['data'] as Map?) ?? const <String, dynamic>{},
    ),
    isActive: (map['is_active'] as bool?) ?? true,
    sortOrder: (map['sort_order'] as int?) ?? 0,
    seasonId: map['season_id'] as String?,
  );
}
