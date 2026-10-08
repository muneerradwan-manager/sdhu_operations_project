class Permission {
  const Permission({
    required this.id,
    required this.code,
    this.description,
    this.parentId,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String? description;
  final String? parentId;
  final int sortOrder;

  bool get isParent => parentId == null;

  factory Permission.fromMap(Map<String, dynamic> map) => Permission(
    id: map['id'] as String,
    code: map['code'] as String,
    description: map['description'] as String?,
    parentId: map['parent_id'] as String?,
    sortOrder: (map['sort_order'] as int?) ?? 0,
  );
}
