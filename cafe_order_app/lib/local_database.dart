import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'product.dart';
import 'cart_ext.dart';
import 'category.dart';
import 'order_ticket.dart';
import 'member.dart';
import 'sqlite_platform_stub.dart'
    if (dart.library.io) 'sqlite_platform_native.dart';
import 'status.dart';

part 'local_seed.dart';

class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PageResult<T> {
  const PageResult({required this.items, required this.total});

  final List<T> items;
  final int total;
}

class LocalDatabase {
  LocalDatabase({this._factory, this._path});

  static LocalDatabase instance = LocalDatabase();
  static const tableCount = 12;
  static const statuses = [
    Status(id: 1, name: 'Chờ xác nhận'),
    Status(id: 2, name: 'Đang pha chế'),
    Status(id: 3, name: 'Chờ phục vụ'),
    Status(id: 4, name: 'Đã phục vụ'),
    Status(id: 5, name: 'Đã hủy'),
    Status(id: 6, name: 'Đã thanh toán'),
  ];

  static List<Status> nextStatuses(int statusId) => switch (statusId) {
    1 => [statuses[1], statuses[4]],
    2 => [statuses[2], statuses[4]],
    3 => [statuses[3]],
    4 => [statuses[5]],
    _ => const [],
  };

  static final _random = Random.secure();
  static final _passwordAlgorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _diacritics = {
    RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'): 'a',
    RegExp('[èéẹẻẽêềếệểễ]'): 'e',
    RegExp('[ìíịỉĩ]'): 'i',
    RegExp('[òóọỏõôồốộổỗơờớợởỡ]'): 'o',
    RegExp('[ùúụủũưừứựửữ]'): 'u',
    RegExp('[ỳýỵỷỹ]'): 'y',
    RegExp('đ'): 'd',
    RegExp(r'[\u0300-\u036f]'): '',
  };

  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _opening;

  Future<void> initialize() async {
    await _database;
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    if (identical(_opening, opening)) _opening = null;
  }

  Future<Database> get _database async {
    final opening = _opening ??= _open();
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final factory = _factory ?? defaultDatabaseFactory();
    final path =
        _path ?? p.join(await factory.getDatabasesPath(), 'cafe_may.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE orders ADD COLUMN paidAtUtc TEXT');
          }
        },
      ),
    );
  }

  Future<void> _create(Database db, int version) async {
    final schema = db.batch();
    for (final statement in _schema) {
      schema.execute(statement);
    }
    await schema.commit(noResult: true);

    final seed = db.batch();
    seed.insert(
      'members',
      await _newMemberRow(
        id: 'admin-local',
        email: 'admin@cafemay.vn',
        password: 'Admin@12345',
        givenName: 'Quản trị',
        role: 1,
      ),
    );
    seed.insert(
      'members',
      await _newMemberRow(
        id: 'member-local',
        email: 'member@cafemay.vn',
        password: 'Member@12345',
        givenName: 'Khách mẫu',
      ),
    );
    for (final category in _seedCategories) {
      seed.insert('categories', category);
    }
    for (final product in _seedProducts) {
      seed.insert('products', {
        'categoryId': product.categoryId,
        'name': product.name,
        'imageUrl': 'assets/products/${product.image}.jpg',
        'price': product.price,
        'description': product.description,
        'stock': product.stock,
        'searchText': _normalize('${product.name} ${product.description}'),
      });
    }
    await seed.commit(noResult: true);
  }

  Future<List<Category>> categories() async {
    final db = await _database;
    return (await db.query(
      'categories',
      orderBy: 'id',
    )).map(Category.fromMap).toList();
  }

  Future<PageResult<Product>> products({
    int? categoryId,
    String search = '',
    int? excludeId,
    int page = 1,
    int pageSize = 6,
  }) async {
    if (page < 1 || pageSize < 1) {
      throw const AppException('Trang hoặc kích thước trang không hợp lệ.');
    }
    final db = await _database;
    final keyword = _normalize(search);
    final filters = [
      if (categoryId != null) 'categoryId = ?',
      if (excludeId != null) 'id != ?',
      if (keyword.isNotEmpty) 'instr(searchText, ?) > 0',
    ];
    final args = [?categoryId, ?excludeId, if (keyword.isNotEmpty) keyword];
    final where = filters.isEmpty ? null : filters.join(' AND ');
    return db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        where: where,
        whereArgs: args,
        orderBy: 'id DESC',
        limit: pageSize,
        offset: (page - 1) * pageSize,
      );
      final count = await txn.query(
        'products',
        columns: ['COUNT(*) AS total'],
        where: where,
        whereArgs: args,
      );
      return PageResult(
        items: rows.map(Product.fromMap).toList(),
        total: count.single['total'] as int,
      );
    });
  }

  Future<Product?> product(int id) async {
    final row = await _find(await _database, 'products', id);
    return row == null ? null : Product.fromMap(row);
  }

  Future<Uint8List?> image(int id) async {
    final db = await _database;
    return db.transaction((txn) async {
      final image = await _find(txn, 'images', id);
      if (image == null) return null;
      final chunks = await txn.query(
        'image_chunks',
        columns: ['bytes'],
        where: 'imageId = ?',
        whereArgs: [id],
        orderBy: 'position',
      );
      final bytes = BytesBuilder(copy: false);
      for (final chunk in chunks) {
        bytes.add(chunk['bytes'] as Uint8List);
      }
      final result = bytes.takeBytes();
      return result.length == image['length'] ? result : null;
    });
  }

  Future<Member> signIn(String email, String password) async {
    final db = await _database;
    final rows = await db.query(
      'members',
      where: 'email = ?',
      whereArgs: [_normalizeEmail(email)],
      limit: 1,
    );
    final row = rows.firstOrNull;
    if (row == null || !await _passwordMatches(row, password)) {
      throw const AppException('Email hoặc mật khẩu không đúng.');
    }
    final user = Member.fromMap(row);
    if (!user.active) {
      throw const AppException('Tài khoản đã bị khóa.');
    }
    return user;
  }

  Future<Member> register({
    required String email,
    required String password,
    required String givenName,
    String? surname,
  }) async {
    email = _normalizeEmail(email);
    if (email.length > 254 || !_emailPattern.hasMatch(email)) {
      throw const AppException('Email không hợp lệ.');
    }
    _validatePassword(password);
    final row = await _newMemberRow(
      email: email,
      password: password,
      givenName: _requiredText(givenName, 'Tên', maxLength: 80),
      surname: _optionalText(surname, 'Họ', maxLength: 80),
    );
    final db = await _database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'members',
        columns: ['id'],
        where: 'email = ?',
        whereArgs: [email],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw const AppException('Email này đã được đăng ký.');
      }
      await txn.insert('members', row);
      return Member.fromMap(row);
    });
  }

  Future<Member?> member(String id) async {
    final row = await _find(await _database, 'members', id);
    return row == null ? null : Member.fromMap(row);
  }

  Future<void> changePassword(
    String memberId,
    String oldPassword,
    String newPassword,
  ) async {
    _validatePassword(newPassword);
    if (oldPassword == newPassword) {
      throw const AppException('Mật khẩu mới phải khác mật khẩu hiện tại.');
    }
    final db = await _database;
    final row = await _find(db, 'members', memberId);
    if (row == null || row['active'] != 1) {
      throw const AppException('Tài khoản hiện không hoạt động.');
    }
    if (!await _passwordMatches(row, oldPassword)) {
      throw const AppException('Mật khẩu hiện tại không đúng.');
    }
    final salt = _randomBytes(16);
    final changed = await db.update(
      'members',
      {
        'passwordSalt': base64Encode(salt),
        'passwordHash': base64Encode(await _passwordHash(newPassword, salt)),
      },
      where: 'id = ? AND active = 1 AND passwordHash = ?',
      whereArgs: [memberId, row['passwordHash']],
    );
    if (changed == 0) {
      throw const AppException('Tài khoản đã thay đổi. Vui lòng thử lại.');
    }
  }

  Future<List<Member>> members(String adminId, {String search = ''}) async {
    final db = await _database;
    final keyword = _normalize(search);
    return db.transaction((txn) async {
      await _requireActor(txn, adminId, role: 1);
      final rows = await txn.query(
        'members',
        where: keyword.isEmpty ? null : 'instr(searchText, ?) > 0',
        whereArgs: keyword.isEmpty ? null : [keyword],
        orderBy: 'role, email',
      );
      return rows.map(Member.fromMap).toList();
    });
  }

  Future<void> updateMember(
    String adminId,
    String memberId, {
    required String givenName,
    String? surname,
    required int role,
    required bool active,
  }) async {
    if (role != 1 && role != 2) {
      throw const AppException('Vai trò không hợp lệ.');
    }
    givenName = _requiredText(givenName, 'Tên', maxLength: 80);
    surname = _optionalText(surname, 'Họ', maxLength: 80);
    final db = await _database;
    await db.transaction((txn) async {
      await _requireActor(txn, adminId, role: 1);
      final row = await _find(txn, 'members', memberId);
      if (row == null) throw const AppException('Tài khoản không tồn tại.');
      final user = Member.fromMap(row);
      if (user.isAdmin && user.active && (!active || role != 1)) {
        final remaining = await txn.query(
          'members',
          columns: ['id'],
          where: 'active = 1 AND role = 1 AND id != ?',
          whereArgs: [memberId],
          limit: 1,
        );
        if (remaining.isEmpty) {
          throw const AppException(
            'Cần giữ ít nhất một quản trị viên hoạt động.',
          );
        }
      }
      await txn.update(
        'members',
        {
          'givenName': givenName,
          'surname': surname,
          'role': role,
          'active': active ? 1 : 0,
          'searchText': _normalize('${surname ?? ''} $givenName ${user.email}'),
        },
        where: 'id = ?',
        whereArgs: [memberId],
      );
    });
  }

  Future<void> saveCategory(
    String adminId, {
    int? id,
    required String name,
    required String description,
    Uint8List? image,
    bool removeImage = false,
  }) async {
    name = _requiredText(name, 'Tên danh mục', maxLength: 100);
    description = _requiredText(description, 'Mô tả', maxLength: 1000);
    _validateImage(image);
    final db = await _database;
    await db.transaction((txn) async {
      await _requireActor(txn, adminId, role: 1);
      final existing = id == null ? null : await _find(txn, 'categories', id);
      if (id != null && existing == null) {
        throw const AppException('Danh mục không tồn tại.');
      }
      final nameKey = _normalize(name);
      final duplicates = await txn.query(
        'categories',
        columns: ['id'],
        where: 'nameKey = ? AND id != ?',
        whereArgs: [nameKey, id ?? -1],
        limit: 1,
      );
      if (duplicates.isNotEmpty) {
        throw const AppException('Tên danh mục đã tồn tại.');
      }
      final oldImageId = existing?['imageId'] as int?;
      final imageId = image != null
          ? await _insertImage(txn, image)
          : (removeImage ? null : oldImageId);
      final row = {
        'name': name,
        'nameKey': nameKey,
        'description': description,
        'icon': removeImage ? '' : (existing?['icon'] ?? ''),
        'imageId': imageId,
      };
      if (id == null) {
        await txn.insert('categories', row);
      } else {
        await txn.update('categories', row, where: 'id = ?', whereArgs: [id]);
      }
      if (oldImageId != null && oldImageId != imageId) {
        await _deleteImage(txn, oldImageId);
      }
    });
  }

  Future<void> deleteCategory(String adminId, int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await _requireActor(txn, adminId, role: 1);
      final existing = await _find(txn, 'categories', id);
      if (existing == null) throw const AppException('Danh mục không tồn tại.');
      final products = await txn.query(
        'products',
        columns: ['id'],
        where: 'categoryId = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (products.isNotEmpty) {
        throw const AppException(
          'Hãy chuyển hoặc xóa món trong danh mục trước.',
        );
      }
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
      await _deleteImage(txn, existing['imageId'] as int?);
    });
  }

  Future<void> saveProduct(
    String adminId, {
    int? id,
    required int categoryId,
    required String name,
    required String description,
    required int price,
    required int stock,
    Uint8List? image,
  }) async {
    name = _requiredText(name, 'Tên món', maxLength: 120);
    description = _requiredText(description, 'Mô tả', maxLength: 3000);
    if (price <= 0 || price > 1000000000 || stock < 0 || stock > 10000) {
      throw const AppException('Giá bán hoặc số lượng tồn không hợp lệ.');
    }
    if (id == null && image == null) {
      throw const AppException('Vui lòng chọn ảnh cho món mới.');
    }
    _validateImage(image);
    final db = await _database;
    await db.transaction((txn) async {
      await _requireActor(txn, adminId, role: 1);
      if (await _find(txn, 'categories', categoryId) == null) {
        throw const AppException('Danh mục không tồn tại.');
      }
      final existing = id == null ? null : await _find(txn, 'products', id);
      if (id != null && existing == null) {
        throw const AppException('Món không tồn tại.');
      }
      final oldImageId = existing?['imageId'] as int?;
      final imageId = image == null
          ? oldImageId
          : await _insertImage(txn, image);
      final row = {
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'stock': stock,
        'imageUrl': existing?['imageUrl'] ?? '',
        'imageId': imageId,
        'searchText': _normalize('$name $description'),
      };
      if (id == null) {
        await txn.insert('products', row);
      } else {
        await txn.update('products', row, where: 'id = ?', whereArgs: [id]);
      }
      if (oldImageId != null && oldImageId != imageId) {
        await _deleteImage(txn, oldImageId);
      }
    });
  }

  Future<void> deleteProduct(String adminId, int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await _requireActor(txn, adminId, role: 1);
      final existing = await _find(txn, 'products', id);
      if (existing == null) throw const AppException('Món không tồn tại.');
      final orders = await txn.query(
        'order_lines',
        columns: ['id'],
        where: 'productId = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (orders.isNotEmpty) {
        throw const AppException('Món đã có trong đơn hàng và không thể xóa.');
      }
      await txn.delete('products', where: 'id = ?', whereArgs: [id]);
      await _deleteImage(txn, existing['imageId'] as int?);
    });
  }

  Future<List<CartExt>> cart(String memberId) async {
    final db = await _database;
    return db.transaction((txn) async {
      await _requireActor(txn, memberId, role: 2);
      return _cart(txn, memberId);
    });
  }

  Future<int> cartCount(String memberId) async {
    final db = await _database;
    return db.transaction((txn) async {
      await _requireActor(txn, memberId, role: 2);
      final rows = await txn.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS total FROM cart WHERE memberId = ?',
        [memberId],
      );
      return rows.single['total'] as int;
    });
  }

  Future<void> addToCart(String memberId, int productId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await _requireActor(txn, memberId, role: 2);
      final rows = await txn.query(
        'cart',
        columns: ['quantity'],
        where: 'memberId = ? AND productId = ?',
        whereArgs: [memberId, productId],
        limit: 1,
      );
      final current = rows.isEmpty ? 0 : rows.single['quantity'] as int;
      await _setCartQuantity(txn, memberId, productId, current + 1);
    });
  }

  Future<void> setCartQuantity(
    String memberId,
    int productId,
    int quantity,
  ) async {
    if (quantity < 0) {
      throw const AppException('Số lượng không hợp lệ.');
    }
    final db = await _database;
    await db.transaction((txn) async {
      await _requireActor(txn, memberId, role: 2);
      await _setCartQuantity(txn, memberId, productId, quantity);
    });
  }

  Future<void> _setCartQuantity(
    Transaction txn,
    String memberId,
    int productId,
    int quantity,
  ) async {
    final args = [memberId, productId];
    if (quantity == 0) {
      await txn.delete(
        'cart',
        where: 'memberId = ? AND productId = ?',
        whereArgs: args,
      );
      return;
    }
    final row = await _find(txn, 'products', productId);
    if (row == null) throw const AppException('Món không tồn tại.');
    if (quantity > (row['stock'] as int)) {
      throw const AppException('Số lượng vượt quá tồn kho của món.');
    }
    final updated = await txn.update(
      'cart',
      {'quantity': quantity},
      where: 'memberId = ? AND productId = ?',
      whereArgs: args,
    );
    if (updated == 0) {
      await txn.insert('cart', {
        'memberId': memberId,
        'productId': productId,
        'quantity': quantity,
      });
    }
  }

  Future<int> checkout(
    String memberId, {
    required int tableNumber,
    required String customerName,
    String note = '',
  }) async {
    if (tableNumber < 1 || tableNumber > tableCount) {
      throw const AppException('Số bàn không hợp lệ.');
    }
    customerName = _requiredText(customerName, 'Tên khách', maxLength: 100);
    note = _optionalText(note, 'Ghi chú', maxLength: 500) ?? '';
    final db = await _database;
    return db.transaction((txn) async {
      final user = await _requireActor(txn, memberId, role: 2);
      final items = await _cart(txn, memberId);
      if (items.isEmpty) throw const AppException('Giỏ món đang trống.');
      for (final item in items) {
        final updated = await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?',
          [item.quantity, item.productId, item.quantity],
        );
        if (updated == 0) {
          throw AppException(
            'Không đủ phần ${item.name}. Vui lòng sửa giỏ món.',
          );
        }
      }
      final total = items.fold(
        0,
        (sum, item) => sum + item.price * item.quantity,
      );
      final memberName = '${user.surname ?? ''} ${user.givenName}'.trim();
      final id = await txn.insert('orders', {
        'statusId': 1,
        'memberId': memberId,
        'memberName': memberName,
        'tableNumber': tableNumber,
        'customerName': customerName,
        'note': note,
        'dated': DateTime.now().toUtc().toIso8601String(),
        'total': total,
        'searchText': _normalize('$memberName $customerName Bàn $tableNumber'),
      });
      final lines = txn.batch();
      for (final item in items) {
        lines.insert('order_lines', {
          'orderId': id,
          'productId': item.productId,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
        });
      }
      await lines.commit(noResult: true);
      await txn.delete('cart', where: 'memberId = ?', whereArgs: [memberId]);
      return id;
    });
  }

  Future<List<OrderTicket>> orders(
    String actorId, {
    bool admin = false,
    String search = '',
    DateTime? date,
  }) async {
    final db = await _database;
    final keyword = _normalize(search);
    final orderNumber = RegExp(r'^#\s*([0-9]+)$').firstMatch(keyword)?.group(1);
    final filters = [
      if (!admin) 'memberId = ?',
      if (orderNumber != null)
        'id = ?'
      else if (keyword.isNotEmpty)
        "(instr(searchText, ?) > 0 OR instr(CAST(id AS TEXT), ?) > 0)",
      if (date != null) "date(dated, 'localtime') = ?",
    ];
    final args = [
      if (!admin) actorId,
      if (orderNumber != null)
        orderNumber
      else if (keyword.isNotEmpty) ...[
        keyword,
        keyword,
      ],
      if (date != null) _dateKey(date),
    ];
    return db.transaction((txn) async {
      await _requireActor(txn, actorId, role: admin ? 1 : 2);
      final rows = await txn.query(
        'orders',
        where: filters.isEmpty ? null : filters.join(' AND '),
        whereArgs: args,
        orderBy: 'dated DESC, id DESC',
      );
      return rows.map(OrderTicket.fromMap).toList();
    });
  }

  Future<OrderTicket?> order(
    String actorId,
    int id, {
    bool admin = false,
  }) async {
    final db = await _database;
    return db.transaction((txn) async {
      final row = await _orderFor(txn, actorId, id, admin: admin);
      return row == null ? null : OrderTicket.fromMap(row);
    });
  }

  Future<List<OrderTicket>> paidOrders(
    String adminId, {
    int? year,
    int? month,
    int? day,
  }) async {
    final period = _revenuePeriod(year, month, day);
    // Both columns use UTC ISO-8601. Dropping Z before sorting preserves
    // chronological order when one value has additional fractional digits.
    const paidTime = "rtrim(coalesce(paidAtUtc, dated), 'Z')";
    final db = await _database;
    return db.transaction((txn) async {
      await _requireActor(txn, adminId, role: 1);
      final rows = await txn.query(
        'orders',
        where: period == null
            ? 'statusId = 6'
            : 'statusId = 6 AND $paidTime >= ? AND $paidTime < ?',
        whereArgs: period == null ? null : [period.start, period.end],
        orderBy: '$paidTime DESC, id DESC',
      );
      return rows.map(OrderTicket.fromMap).toList();
    });
  }

  Future<List<OrderLine>> orderLines(
    String actorId,
    int id, {
    bool admin = false,
  }) async {
    final db = await _database;
    return db.transaction((txn) async {
      if (await _orderFor(txn, actorId, id, admin: admin) == null) return [];
      final rows = await txn.query(
        'order_lines',
        where: 'orderId = ?',
        whereArgs: [id],
        orderBy: 'id',
      );
      return rows.map(OrderLine.fromMap).toList();
    });
  }

  Future<void> updateOrderStatus(String adminId, int id, int statusId) async {
    final db = await _database;
    await db.transaction((txn) async {
      final row = await _orderFor(txn, adminId, id, admin: true);
      if (row == null) throw const AppException('Đơn hàng không tồn tại.');
      final allowed = nextStatuses(row['statusId'] as int);
      if (!allowed.any((status) => status.id == statusId)) {
        throw const AppException('Không thể chuyển sang trạng thái này.');
      }
      if (statusId == 5) {
        await txn.rawUpdate(
          '''
          UPDATE products SET stock = stock + (
            SELECT l.quantity FROM order_lines l
            WHERE l.orderId = ? AND l.productId = products.id
          )
          WHERE id IN (SELECT productId FROM order_lines WHERE orderId = ?)
          ''',
          [id, id],
        );
      }
      await txn.update(
        'orders',
        {
          'statusId': statusId,
          if (statusId == 6)
            'paidAtUtc': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<Map<String, Object?>?> _orderFor(
    Transaction txn,
    String actorId,
    int id, {
    required bool admin,
  }) async {
    await _requireActor(txn, actorId, role: admin ? 1 : 2);
    final rows = await txn.query(
      'orders',
      where: admin ? 'id = ?' : 'id = ? AND memberId = ?',
      whereArgs: [id, if (!admin) actorId],
      limit: 1,
    );
    return rows.firstOrNull;
  }

  Future<List<CartExt>> _cart(DatabaseExecutor db, String memberId) async {
    final rows = await db.rawQuery(
      '''
      SELECT c.id, c.productId, c.quantity, p.name, p.price, p.stock,
             p.imageUrl, p.imageId
      FROM cart c JOIN products p ON p.id = c.productId
      WHERE c.memberId = ?
      ORDER BY c.id
      ''',
      [memberId],
    );
    return rows.map(CartExt.fromMap).toList();
  }

  static Future<Map<String, Object?>?> _find(
    DatabaseExecutor db,
    String table,
    Object id,
  ) async {
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.firstOrNull;
  }

  static Future<Member> _requireActor(
    DatabaseExecutor db,
    String id, {
    required int role,
  }) async {
    final row = await _find(db, 'members', id);
    if (row == null || row['active'] != 1) {
      throw const AppException(
        'Vui lòng đăng nhập bằng tài khoản đang hoạt động.',
      );
    }
    final member = Member.fromMap(row);
    if (member.role != role) {
      throw const AppException(
        'Tài khoản không có quyền thực hiện thao tác này.',
      );
    }
    return member;
  }

  static Future<void> _deleteImage(Transaction txn, int? id) async {
    if (id != null) {
      await txn.delete('images', where: 'id = ?', whereArgs: [id]);
    }
  }

  static Future<int> _insertImage(Transaction txn, Uint8List image) async {
    final id = await txn.insert('images', {'length': image.length});
    const chunkSize = 256 * 1024;
    final chunks = txn.batch();
    for (var offset = 0; offset < image.length; offset += chunkSize) {
      chunks.insert('image_chunks', {
        'imageId': id,
        'position': offset,
        'bytes': Uint8List.sublistView(
          image,
          offset,
          min(offset + chunkSize, image.length),
        ),
      });
    }
    await chunks.commit(noResult: true);
    return id;
  }

  static Future<Map<String, Object?>> _newMemberRow({
    String? id,
    required String email,
    required String password,
    required String givenName,
    String? surname,
    int role = 2,
  }) async {
    final salt = _randomBytes(16);
    return {
      'id': id ?? base64UrlEncode(_randomBytes(18)),
      'email': email,
      'givenName': givenName,
      'surname': surname,
      'role': role,
      'active': 1,
      'passwordSalt': base64Encode(salt),
      'passwordHash': base64Encode(await _passwordHash(password, salt)),
      'searchText': _normalize('${surname ?? ''} $givenName $email'),
    };
  }

  static Uint8List _randomBytes(int count) =>
      Uint8List.fromList(List.generate(count, (_) => _random.nextInt(256)));

  static Future<List<int>> _passwordHash(String password, List<int> salt) =>
      runDatabaseComputation(() async {
        final key = await _passwordAlgorithm.deriveKey(
          secretKey: SecretKey(utf8.encode(password)),
          nonce: salt,
        );
        return key.extractBytes();
      });

  static Future<bool> _passwordMatches(
    Map<String, Object?> row,
    String password,
  ) async {
    if (password.length > 128) return false;
    final salt = base64Decode(row['passwordSalt'] as String);
    final expected = base64Decode(row['passwordHash'] as String);
    final actual = await _passwordHash(password, salt);
    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= expected[index] ^ actual[index];
    }
    return difference == 0;
  }

  static void _validatePassword(String password) {
    if (password.trim().length < 8 || password.length > 128) {
      throw const AppException('Mật khẩu phải có từ 8 đến 128 ký tự.');
    }
  }

  static void _validateImage(Uint8List? image) {
    if (image != null && (image.isEmpty || image.length > 5 * 1024 * 1024)) {
      throw const AppException('Ảnh phải có dung lượng từ 1 byte đến 5 MB.');
    }
  }

  static String _requiredText(
    String value,
    String label, {
    required int maxLength,
  }) {
    final text = _optionalText(value, label, maxLength: maxLength);
    if (text == null) throw AppException('$label không được để trống.');
    return text;
  }

  static String? _optionalText(
    String? value,
    String label, {
    required int maxLength,
  }) {
    final text = value?.trim() ?? '';
    if (text.length > maxLength) {
      throw AppException('$label tối đa $maxLength ký tự.');
    }
    return text.isEmpty ? null : text;
  }

  static String _normalizeEmail(String value) => value.trim().toLowerCase();

  static String _normalize(String value) {
    var text = value.trim().toLowerCase();
    for (final entry in _diacritics.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text;
  }

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static ({String start, String end})? _revenuePeriod(
    int? year,
    int? month,
    int? day,
  ) {
    const invalidPeriod = AppException('Kỳ doanh thu không hợp lệ.');
    if (year == null) {
      if (month != null || day != null) throw invalidPeriod;
      return null;
    }
    if (year < 2 ||
        year > 9998 ||
        (month != null && (month < 1 || month > 12)) ||
        (day != null && (month == null || day < 1 || day > 31))) {
      throw invalidPeriod;
    }

    final first = DateTime.utc(year, month ?? 1, day ?? 1);
    if (day != null && (first.month != month || first.day != day)) {
      throw invalidPeriod;
    }
    final next = switch ((month, day)) {
      (final int month, final int day) => DateTime.utc(year, month, day + 1),
      (final int month, null) => DateTime.utc(year, month + 1),
      _ => DateTime.utc(year + 1),
    };
    const cafeOffset = Duration(hours: 7);
    String utcBoundary(DateTime boundary) =>
        boundary.subtract(cafeOffset).toIso8601String().substring(0, 19);
    return (start: utcBoundary(first), end: utcBoundary(next));
  }
}
