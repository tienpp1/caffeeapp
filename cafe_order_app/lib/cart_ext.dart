class CartExt {
  const CartExt({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.stock,
    this.imageId,
  });

  final int id;
  final int productId;
  final int quantity;
  final String name;
  final String imageUrl;
  final int price;
  final int stock;
  final int? imageId;

  factory CartExt.fromMap(Map<String, Object?> map) => CartExt(
    id: map['id'] as int,
    productId: map['productId'] as int,
    quantity: map['quantity'] as int,
    name: map['name'] as String,
    imageUrl: map['imageUrl'] as String,
    price: map['price'] as int,
    stock: map['stock'] as int,
    imageId: map['imageId'] as int?,
  );
}
