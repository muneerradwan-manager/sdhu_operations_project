class Season {
  const Season({
    required this.id,
    required this.hijriYear,
    this.gregorianLabel,
    this.isCurrent = false,
    this.startDate,
    this.endDate,
  });

  final String id;
  final int hijriYear;
  final String? gregorianLabel;
  final bool isCurrent;
  final DateTime? startDate;
  final DateTime? endDate;

  factory Season.fromMap(Map<String, dynamic> map) => Season(
    id: map['id'] as String,
    hijriYear: map['hijri_year'] as int,
    gregorianLabel: map['gregorian_label'] as String?,
    isCurrent: (map['is_current'] as bool?) ?? false,
    startDate: map['start_date'] == null
        ? null
        : DateTime.parse(map['start_date'] as String),
    endDate: map['end_date'] == null
        ? null
        : DateTime.parse(map['end_date'] as String),
  );
}
