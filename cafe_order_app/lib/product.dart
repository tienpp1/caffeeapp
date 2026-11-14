class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.description,
    required this.stock,
    this.imageId,
  });

  final int id;
  final int categoryId;
  final String name;
  final String imageUrl;
  final int price;
  final String description;
  final int stock;
  final int? imageId;

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: map['id'] as int,
    categoryId: map['categoryId'] as int,
    name: map['name'] as String,
    imageUrl: map['imageUrl'] as String,
    price: map['price'] as int,
    description: map['description'] as String,
    stock: map['stock'] as int,
    imageId: map['imageId'] as int?,
  );
}
