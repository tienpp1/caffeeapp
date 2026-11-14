class Category {
  const Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.imageId,
  });

  final int id;
  final String name;
  final String description;
  final String icon;
  final int? imageId;

  factory Category.fromMap(Map<String, Object?> map) => Category(
    id: map['id'] as int,
    name: map['name'] as String,
    description: map['description'] as String,
    icon: map['icon'] as String,
    imageId: map['imageId'] as int?,
  );
}
