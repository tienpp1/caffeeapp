import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cafe_order_app/product.dart';
import 'package:cafe_order_app/local_database.dart';

const _admin = 'admin-local';
const _member = 'member-local';
const _password = 'Coffee@12345';

Matcher _errorContaining(String message) => throwsA(
  isA<AppException>().having(
    (error) => error.message,
    'message',
    contains(message),
  ),
);

Uint8List _imageBytes(int size) =>
    Uint8List.fromList(List<int>.generate(size, (index) => index % 251));

Future<int> _createCategory(LocalDatabase db, String name) async {
  await db.saveCategory(_admin, name: name, description: 'Mô tả danh mục');
  return (await db.categories()).singleWhere((item) => item.name == name).id;
}

Future<Product> _createProduct(
  LocalDatabase db,
  int categoryId,
  String name, {
  int price = 45000,
  int stock = 2,
}) async {
  await db.saveProduct(
    _admin,
    categoryId: categoryId,
    name: name,
    description: 'Đồ uống pha tại quán',
    price: price,
    stock: stock,
    image: _imageBytes(32),
  );
  final results = await db.products(categoryId: categoryId, search: name);
  return results.items.singleWhere((item) => item.name == name);
}

DateTime _futureDay(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

Future<int> _checkout(
  LocalDatabase db,
  String memberId, {
  int tableNumber = 3,
}) => db.checkout(
  memberId,
  tableNumber: tableNumber,
  customerName: 'Nguyễn Thanh An',
  note: 'Ít đá',
);

void main() {
  setUpAll(sqfliteFfiInit);

  group('SQLite offline', () {
    late LocalDatabase db;

    setUp(() async {
      db = LocalDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      await db.initialize();
    });

    tearDown(() => db.close());

    test(
      'registers and authenticates members and enforces admin roles',
      () async {
        final admin = await db.signIn(' ADMIN@CAFEMAY.VN ', 'Admin@12345');
        expect(admin.id, _admin);
        expect(admin.isAdmin, isTrue);

        final user = await db.register(
          email: ' LINH@EXAMPLE.COM ',
          password: _password,
          givenName: 'Linh',
          surname: 'Đỗ',
        );
        expect(user.email, 'linh@example.com');
        expect(user.isAdmin, isFalse);
        expect((await db.signIn(user.email, _password)).id, user.id);
        await expectLater(
          db.register(
            email: user.email,
            password: _password,
            givenName: 'Trùng',
          ),
          _errorContaining('đã được đăng ký'),
        );
        expect(
          (await db.members(_admin, search: 'do linh')).single.id,
          user.id,
        );
        await expectLater(db.members(user.id), throwsA(isA<AppException>()));
        await expectLater(
          db.saveCategory(user.id, name: 'Tên', description: 'Mô tả'),
          throwsA(isA<AppException>()),
        );

        const newPassword = 'Espresso@98765';
        await db.changePassword(user.id, _password, newPassword);
        await expectLater(
          db.signIn(user.email, _password),
          throwsA(isA<AppException>()),
        );
        expect((await db.signIn(user.email, newPassword)).id, user.id);

        await expectLater(
          db.updateMember(
            _admin,
            _admin,
            givenName: 'Admin',
            role: 2,
            active: true,
          ),
          _errorContaining('ít nhất một quản trị viên'),
        );
        await expectLater(
          db.updateMember(
            _admin,
            _admin,
            givenName: 'Admin',
            role: 1,
            active: false,
          ),
          _errorContaining('ít nhất một quản trị viên'),
        );

        await db.updateMember(
          _admin,
          user.id,
          givenName: 'Linh',
          role: 1,
          active: true,
        );
        expect((await db.member(user.id))!.isAdmin, isTrue);
        await db.updateMember(
          user.id,
          _admin,
          givenName: 'Admin',
          role: 2,
          active: false,
        );
        expect((await db.member(_admin))!.active, isFalse);
        await expectLater(
          db.signIn(admin.email, 'Admin@12345'),
          _errorContaining('bị khóa'),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'stores, replaces, and deletes catalog images with related records',
      () async {
        const name = 'Danh mục ảnh';
        final first = _imageBytes(32);
        final replacement = _imageBytes(550000);
        await db.saveCategory(
          _admin,
          name: name,
          description: 'Ảnh ban đầu',
          image: first,
        );
        final category = (await db.categories()).singleWhere(
          (item) => item.name == name,
        );
        final originalId = category.imageId!;
        expect(await db.image(originalId), orderedEquals(first));

        await db.saveCategory(
          _admin,
          id: category.id,
          name: name,
          description: 'Ảnh thay thế',
          image: replacement,
        );
        final updated = (await db.categories()).singleWhere(
          (item) => item.id == category.id,
        );
        expect(updated.description, 'Ảnh thay thế');
        expect(updated.imageId, isNot(originalId));
        expect(await db.image(originalId), isNull);
        expect(await db.image(updated.imageId!), orderedEquals(replacement));

        await expectLater(
          db.saveProduct(
            _admin,
            categoryId: category.id,
            name: 'Món chưa có ảnh',
            description: 'Món cần có ảnh khi thêm',
            price: 45000,
            stock: 1,
          ),
          _errorContaining('ảnh'),
        );
        expect((await db.products(categoryId: category.id)).items, isEmpty);

        final product = await _createProduct(db, category.id, 'Món có ảnh');
        final productImageId = product.imageId!;
        expect(await db.image(productImageId), orderedEquals(first));
        await expectLater(
          db.deleteCategory(_admin, category.id),
          _errorContaining('món trong danh mục'),
        );

        await db.saveProduct(
          _admin,
          id: product.id,
          categoryId: product.categoryId,
          name: product.name,
          description: product.description,
          price: product.price,
          stock: product.stock,
          image: replacement,
        );
        final changed = (await db.product(product.id))!;
        expect(await db.image(productImageId), isNull);
        expect(await db.image(changed.imageId!), orderedEquals(replacement));
        await db.deleteProduct(_admin, product.id);
        expect(await db.product(product.id), isNull);
        expect(await db.image(changed.imageId!), isNull);

        await db.saveCategory(
          _admin,
          id: category.id,
          name: name,
          description: 'Đã bỏ ảnh',
          removeImage: true,
        );
        expect(await db.image(updated.imageId!), isNull);
        expect(
          (await db.categories())
              .singleWhere((item) => item.id == category.id)
              .imageId,
          isNull,
        );

        await db.saveCategory(
          _admin,
          id: category.id,
          name: name,
          description: 'Ảnh cuối',
          image: first,
        );
        final finalImageId = (await db.categories())
            .singleWhere((item) => item.id == category.id)
            .imageId!;
        await db.deleteCategory(_admin, category.id);
        expect(await db.image(finalImageId), isNull);
        expect(
          (await db.categories()).any((item) => item.id == category.id),
          isFalse,
        );
      },
    );

    test(
      'paginates newest-first and searches Vietnamese names without accents',
      () async {
        final categoryId = await _createCategory(db, 'Danh mục phân trang');
        final otherCategoryId = await _createCategory(db, 'Danh mục khác');
        final oldest = await _createProduct(db, categoryId, 'Cà phê đá Alpha');
        final middle = await _createProduct(db, categoryId, 'Cà phê đá Beta');
        final newest = await _createProduct(db, categoryId, 'Cà phê đá Gamma');
        final other = await _createProduct(
          db,
          otherCategoryId,
          'Cà phê đá Delta',
        );

        final firstPage = await db.products(
          categoryId: categoryId,
          search: ' CA PHE DA ',
          pageSize: 2,
        );
        final secondPage = await db.products(
          categoryId: categoryId,
          search: 'cà phê đá',
          page: 2,
          pageSize: 2,
        );
        expect(firstPage.total, 3);
        expect(secondPage.total, 3);
        expect(firstPage.items.map((item) => item.id), [newest.id, middle.id]);
        expect(secondPage.items.map((item) => item.id), [oldest.id]);

        final related = await db.products(
          categoryId: categoryId,
          excludeId: newest.id,
          pageSize: 1,
        );
        expect(related.total, 2);
        expect(related.items.single.id, middle.id);
        expect((await db.products(pageSize: 1)).items.single.id, other.id);
      },
    );

    test(
      'tracks quantity, rejects invalid updates, and removes a cart item',
      () async {
        final category = await _createCategory(db, 'Danh mục giỏ');
        final product = await _createProduct(
          db,
          category,
          'Món trong giỏ',
          stock: 3,
        );
        final other = await _createProduct(
          db,
          category,
          'Món còn lại',
          stock: 1,
        );
        await db.addToCart(_member, product.id);
        await db.addToCart(_member, product.id);
        await db.addToCart(_member, other.id);
        expect(await db.cartCount(_member), 3);
        expect((await db.cart(_member)).map((item) => item.quantity), [2, 1]);

        await db.setCartQuantity(_member, product.id, 3);
        expect(await db.cartCount(_member), 4);
        await expectLater(
          db.setCartQuantity(_member, product.id, 4),
          _errorContaining('vượt quá tồn kho'),
        );
        await expectLater(
          db.setCartQuantity(_member, product.id, -1),
          _errorContaining('không hợp lệ'),
        );
        expect(await db.cartCount(_member), 4);
        await db.setCartQuantity(_member, product.id, 0);
        expect((await db.cart(_member)).single.productId, other.id);
        expect(await db.cartCount(_member), 1);
      },
    );

    test(
      'decrements stock atomically and restores it once when canceled',
      () async {
        final category = await _createCategory(db, 'Danh mục tồn kho');
        final product = await _createProduct(
          db,
          category,
          'Món số lượng giới hạn',
          stock: 1,
        );
        final remaining = await _createProduct(
          db,
          category,
          'Món có thể đặt',
          stock: 3,
        );
        final other = await db.register(
          email: 'other@example.com',
          password: _password,
          givenName: 'Khách',
        );
        await db.addToCart(_member, product.id);
        await db.addToCart(other.id, remaining.id);
        await db.addToCart(other.id, product.id);
        await expectLater(
          _checkout(db, _member, tableNumber: 13),
          throwsA(isA<AppException>()),
        );
        expect(await db.cartCount(_member), 1);
        expect((await db.product(product.id))!.stock, 1);
        final id = await _checkout(db, _member);
        expect(await db.cartCount(_member), 0);
        expect((await db.product(product.id))!.stock, 0);
        await db.updateOrderStatus(_admin, id, 2);
        await expectLater(
          _checkout(db, other.id),
          throwsA(isA<AppException>()),
        );
        expect(await db.cartCount(other.id), 2);
        expect((await db.product(remaining.id))!.stock, 3);
        expect(await db.orders(other.id), isEmpty);

        await db.updateOrderStatus(_admin, id, 5);
        expect((await db.product(product.id))!.stock, 1);
        await expectLater(
          db.updateOrderStatus(_admin, id, 5),
          throwsA(isA<AppException>()),
        );
        expect((await db.product(product.id))!.stock, 1);
        expect(await _checkout(db, other.id), isNot(id));
        expect(await db.cartCount(other.id), 0);
        expect((await db.product(product.id))!.stock, 0);
        expect((await db.product(remaining.id))!.stock, 2);
        await expectLater(
          db.deleteProduct(_admin, product.id),
          _errorContaining('trong đơn'),
        );
      },
    );

    test(
      'keeps order snapshots, enforces ownership, and filters orders',
      () async {
        final category = await _createCategory(db, 'Danh mục đơn món');
        final product = await _createProduct(
          db,
          category,
          'Món tên trước',
          price: 90000,
        );
        final other = await db.register(
          email: 'privacy@example.com',
          password: _password,
          givenName: 'Khách',
        );
        await db.setCartQuantity(_member, product.id, 2);
        final id = await _checkout(db, _member, tableNumber: 8);
        final original = (await db.order(_member, id))!;
        expect(original.total, 180000);
        expect(original.statusId, 1);
        expect(original.customerName, 'Nguyễn Thanh An');
        expect(original.tableNumber, 8);
        expect(original.note, 'Ít đá');

        await db.saveProduct(
          _admin,
          id: product.id,
          categoryId: category,
          name: 'Món tên mới',
          description: product.description,
          price: 130000,
          stock: 0,
        );
        final line = (await db.orderLines(_member, id)).single;
        expect(line.name, product.name);
        expect(line.price, product.price);
        expect(line.quantity, 2);

        expect(await db.order(other.id, id), isNull);
        expect(await db.orderLines(other.id, id), isEmpty);
        expect(await db.orders(other.id, search: id.toString()), isEmpty);
        await expectLater(
          db.orders(other.id, admin: true),
          throwsA(isA<AppException>()),
        );
        await expectLater(
          db.updateOrderStatus(_member, id, 2),
          throwsA(isA<AppException>()),
        );

        expect((await db.orders(_member, search: id.toString())).single.id, id);
        expect((await db.orders(_member, search: '#$id')).single.id, id);
        expect(
          (await db.orders(_admin, admin: true, search: 'ban 8')).single.id,
          id,
        );
        expect(
          (await db.orders(
            _admin,
            admin: true,
            search: 'nguyen thanh an',
            date: original.dated.toLocal(),
          )).single.id,
          id,
        );
        expect(
          await db.orders(_admin, admin: true, date: _futureDay(7)),
          isEmpty,
        );
        await expectLater(
          db.updateOrderStatus(_admin, id, 4),
          _errorContaining('Không thể chuyển'),
        );
        await db.updateOrderStatus(_admin, id, 2);
        await db.updateOrderStatus(_admin, id, 3);
        await db.updateOrderStatus(_admin, id, 4);
        expect((await db.order(_member, id))!.statusId, 4);
        await db.updateOrderStatus(_admin, id, 6);
        expect((await db.order(_member, id))!.statusId, 6);
        expect((await db.product(product.id))!.stock, 0);
        await expectLater(
          db.updateOrderStatus(_admin, id, 5),
          throwsA(isA<AppException>()),
        );
        await expectLater(
          db.deleteProduct(_admin, product.id),
          _errorContaining('trong đơn'),
        );
      },
    );
  });

  test(
    'persists catalogs, carts and orders across opening the database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cafe_order_test_',
      );
      final path = '${directory.path}${Platform.pathSeparator}cafe.db';
      final first = LocalDatabase(factory: databaseFactoryFfi, path: path);
      final second = LocalDatabase(factory: databaseFactoryFfi, path: path);
      addTearDown(() async {
        await first.close();
        await second.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await directory.delete();
      });

      final category = await _createCategory(first, 'Danh mục lưu trữ');
      final product = await _createProduct(first, category, 'Món lưu trữ');
      await first.addToCart(_member, product.id);
      final id = await _checkout(first, _member);
      await first.addToCart(_member, product.id);
      await first.close();

      expect((await second.product(product.id))!.name, product.name);
      expect((await second.product(product.id))!.stock, 1);
      expect(
        await second.image(product.imageId!),
        orderedEquals(_imageBytes(32)),
      );
      expect(await second.cartCount(_member), 1);
      expect((await second.order(_member, id))!.total, product.price);
    },
  );
}
