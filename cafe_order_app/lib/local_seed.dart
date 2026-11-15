part of 'local_database.dart';

const _schema = [
  '''
  CREATE TABLE members (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    givenName TEXT NOT NULL,
    surname TEXT,
    role INTEGER NOT NULL CHECK (role IN (1, 2)),
    active INTEGER NOT NULL CHECK (active IN (0, 1)),
    passwordSalt TEXT NOT NULL,
    passwordHash TEXT NOT NULL,
    searchText TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    length INTEGER NOT NULL CHECK (length > 0)
  )
  ''',
  '''
  CREATE TABLE image_chunks (
    imageId INTEGER NOT NULL REFERENCES images(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    bytes BLOB NOT NULL,
    PRIMARY KEY (imageId, position)
  )
  ''',
  '''
  CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    nameKey TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    icon TEXT NOT NULL DEFAULT '',
    imageId INTEGER REFERENCES images(id)
  )
  ''',
  '''
  CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    categoryId INTEGER NOT NULL REFERENCES categories(id),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    price INTEGER NOT NULL CHECK (price > 0),
    stock INTEGER NOT NULL CHECK (stock >= 0),
    imageUrl TEXT NOT NULL DEFAULT '',
    imageId INTEGER REFERENCES images(id),
    searchText TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE cart (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    memberId TEXT NOT NULL REFERENCES members(id),
    productId INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    UNIQUE (memberId, productId)
  )
  ''',
  '''
  CREATE TABLE orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    statusId INTEGER NOT NULL CHECK (statusId IN (1, 2, 3, 4, 5, 6)),
    memberId TEXT NOT NULL REFERENCES members(id),
    memberName TEXT NOT NULL,
    tableNumber INTEGER NOT NULL CHECK (tableNumber BETWEEN 1 AND 12),
    customerName TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    dated TEXT NOT NULL,
    paidAtUtc TEXT,
    total INTEGER NOT NULL CHECK (total > 0),
    searchText TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE order_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    orderId INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    productId INTEGER NOT NULL REFERENCES products(id),
    name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price INTEGER NOT NULL CHECK (price > 0),
    UNIQUE (orderId, productId)
  )
  ''',
  'CREATE INDEX products_category ON products(categoryId)',
  'CREATE INDEX cart_product ON cart(productId)',
  'CREATE INDEX orders_member_date ON orders(memberId, dated DESC)',
  'CREATE INDEX order_lines_product ON order_lines(productId)',
];

const _seedCategories = [
  {
    'id': 1,
    'name': 'Cà phê',
    'nameKey': 'ca phe',
    'description': 'Cà phê phin và espresso pha tại quầy.',
    'icon': 'assets/categories/coffee.jpg',
  },
  {
    'id': 2,
    'name': 'Trà và trái cây',
    'nameKey': 'tra va trai cay',
    'description': 'Trà, matcha và đồ uống kết hợp trái cây.',
    'icon': 'assets/categories/tea.jpg',
  },
  {
    'id': 3,
    'name': 'Bánh và đồ ăn nhẹ',
    'nameKey': 'banh va do an nhe',
    'description': 'Bánh nướng và món ăn nhẹ dùng tại bàn.',
    'icon': 'assets/categories/food.jpg',
  },
];

typedef _SeedProduct = ({
  int categoryId,
  String name,
  String image,
  int price,
  String description,
  int stock,
});

const _seedProducts = <_SeedProduct>[
  (
    categoryId: 1,
    name: 'Espresso',
    image: 'espresso',
    price: 30000,
    description: 'Cà phê chiết xuất đậm, dùng nóng trong tách nhỏ.',
    stock: 18,
  ),
  (
    categoryId: 1,
    name: 'Americano',
    image: 'americano',
    price: 35000,
    description: 'Espresso pha nước, có thể dùng nóng hoặc với đá.',
    stock: 20,
  ),
  (
    categoryId: 1,
    name: 'Cappuccino',
    image: 'cappuccino',
    price: 45000,
    description: 'Espresso với sữa nóng và lớp bọt sữa mịn.',
    stock: 16,
  ),
  (
    categoryId: 1,
    name: 'Latte',
    image: 'latte',
    price: 49000,
    description: 'Espresso pha nhiều sữa cho vị dịu, có thể chọn nóng hoặc đá.',
    stock: 22,
  ),
  (
    categoryId: 1,
    name: 'Cà phê sữa đá',
    image: 'ca-phe-sua-da',
    price: 39000,
    description: 'Cà phê phin đậm với sữa đặc và đá.',
    stock: 24,
  ),
  (
    categoryId: 1,
    name: 'Cà phê đen đá',
    image: 'ca-phe-den-da',
    price: 32000,
    description: 'Cà phê phin dùng với đá, có thể yêu cầu thêm đường.',
    stock: 20,
  ),
  (
    categoryId: 1,
    name: 'Bạc xỉu',
    image: 'bac-xiu',
    price: 42000,
    description: 'Sữa đặc, sữa tươi và một lớp cà phê phin nhẹ.',
    stock: 18,
  ),
  (
    categoryId: 1,
    name: 'Cà phê muối',
    image: 'ca-phe-muoi',
    price: 45000,
    description: 'Cà phê phin với kem muối béo nhẹ.',
    stock: 17,
  ),
  (
    categoryId: 2,
    name: 'Trà đào cam sả',
    image: 'tra-dao-cam-sa',
    price: 49000,
    description: 'Trà đen với đào, cam tươi và sả thơm.',
    stock: 21,
  ),
  (
    categoryId: 2,
    name: 'Trà vải',
    image: 'tra-vai',
    price: 45000,
    description: 'Trà lài, vải và đá, vị ngọt thanh.',
    stock: 18,
  ),
  (
    categoryId: 2,
    name: 'Trà tắc',
    image: 'tra-tac',
    price: 35000,
    description: 'Trà đen pha tắc tươi, dùng lạnh.',
    stock: 22,
  ),
  (
    categoryId: 2,
    name: 'Matcha latte',
    image: 'matcha-latte',
    price: 55000,
    description: 'Bột trà xanh đánh mịn với sữa tươi.',
    stock: 18,
  ),
  (
    categoryId: 3,
    name: 'Croissant bơ',
    image: 'croissant',
    price: 36000,
    description: 'Bánh sừng bò nhiều lớp, nướng giòn và thơm bơ.',
    stock: 10,
  ),
  (
    categoryId: 3,
    name: 'Bánh mì gà',
    image: 'banh-mi-ga',
    price: 52000,
    description: 'Bánh mì giòn kẹp gà xé, dưa leo và rau.',
    stock: 10,
  ),
  (
    categoryId: 3,
    name: 'Bánh chuối',
    image: 'banh-chuoi',
    price: 39000,
    description: 'Bánh chuối nướng mềm, dùng theo lát.',
    stock: 8,
  ),
  (
    categoryId: 3,
    name: 'Bánh phô mai',
    image: 'banh-pho-mai',
    price: 56000,
    description: 'Bánh phô mai nướng, giữ lạnh và phục vụ theo lát.',
    stock: 8,
  ),
];
