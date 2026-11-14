class OrderTicket {
  const OrderTicket({
    required this.id,
    required this.statusId,
    required this.total,
    required this.memberId,
    required this.memberName,
    required this.tableNumber,
    required this.customerName,
    required this.note,
    required this.dated,
  });

  final int id;
  final int statusId;
  final int total;
  final String memberId;
  final String memberName;
  final int tableNumber;
  final String customerName;
  final String note;
  final DateTime dated;

  factory OrderTicket.fromMap(Map<String, Object?> map) => OrderTicket(
    id: map['id'] as int,
    statusId: map['statusId'] as int,
    total: map['total'] as int,
    memberId: map['memberId'] as String,
    memberName: map['memberName'] as String,
    tableNumber: map['tableNumber'] as int,
    customerName: map['customerName'] as String,
    note: map['note'] as String,
    dated: DateTime.parse(map['dated'] as String),
  );
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.quantity,
    required this.price,
    required this.name,
  });

  final int productId;
  final int quantity;
  final int price;
  final String name;

  factory OrderLine.fromMap(Map<String, Object?> map) => OrderLine(
    productId: map['productId'] as int,
    quantity: map['quantity'] as int,
    price: map['price'] as int,
    name: map['name'] as String,
  );
}
