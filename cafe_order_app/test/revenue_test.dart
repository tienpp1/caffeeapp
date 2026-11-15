import 'dart:io';

import 'package:cafe_order_app/local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _admin = 'admin-local';
const _member = 'member-local';

void main() {
  setUpAll(sqfliteFfiInit);

  late String path;
  late LocalDatabase db;

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('cafemay_revenue_');
    path = p.join(directory.path, 'revenue.db');
    db = LocalDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(() async {
      await db.close();
      await databaseFactoryFfi.deleteDatabase(path);
      await directory.delete();
    });
  });

  test(
    'reports paid orders by the Vietnamese payment day, month and year',
    () async {
      await db.initialize();
      final product = (await db.products(pageSize: 1)).items.single;
      await db.addToCart(_member, product.id);
      final paidId = await db.checkout(
        _member,
        tableNumber: 1,
        customerName: 'An',
      );
      for (final status in [2, 3, 4]) {
        await db.updateOrderStatus(_admin, paidId, status);
      }
      expect(await db.paidOrders(_admin), isEmpty);

      final beforePayment = DateTime.now().toUtc();
      await db.updateOrderStatus(_admin, paidId, 6);
      final paid = (await db.paidOrders(_admin)).single;
      expect(paid.id, paidId);
      expect(paid.paidAtUtc, isNotNull);
      expect(paid.paidAtUtc!.isUtc, isTrue);
      expect(paid.paidAtUtc!.isBefore(beforePayment), isFalse);
      expect(paid.paidAtUtc!.isAfter(DateTime.now().toUtc()), isFalse);

      final raw = await databaseFactoryFfi.openDatabase(path);
      await raw.update(
        'orders',
        {
          'dated': '2024-12-31T16:30:00.000Z',
          'paidAtUtc': '2024-12-31T17:00:00.000Z',
        },
        where: 'id = ?',
        whereArgs: [paidId],
      );
      const beforeNewYear = '2024-12-31T16:59:59.999Z';
      final previousId = await raw.insert(
        'orders',
        _orderRow(status: 6, dated: beforeNewYear, paidAt: beforeNewYear),
      );
      final nextDayId = await raw.insert(
        'orders',
        _orderRow(status: 6, paidAt: '2025-01-01T17:00:00.000Z'),
      );
      final nextMonthId = await raw.insert(
        'orders',
        _orderRow(status: 6, paidAt: '2025-01-31T17:00:00.000Z'),
      );
      await raw.insert('orders', _orderRow(status: 1));
      await raw.insert('orders', _orderRow(status: 5));

      Future<List<int>> ids({int? year, int? month, int? day}) async =>
          (await db.paidOrders(
            _admin,
            year: year,
            month: month,
            day: day,
          )).map((order) => order.id).toList();

      expect(await ids(), [nextMonthId, nextDayId, paidId, previousId]);
      expect(await ids(year: 2025), [nextMonthId, nextDayId, paidId]);
      expect(await ids(year: 2025, month: 1), [nextDayId, paidId]);
      expect(await ids(year: 2025, month: 1, day: 1), [paidId]);
      expect(await ids(year: 2024, month: 12, day: 31), [previousId]);
      expect(await ids(year: 2025, month: 3), isEmpty);
      await expectLater(db.paidOrders(_member), throwsA(isA<AppException>()));
      await expectLater(
        db.paidOrders(_admin, month: 1),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        db.paidOrders(_admin, year: 2025, day: 1),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        db.paidOrders(_admin, year: 2025, month: 2, day: 29),
        throwsA(isA<AppException>()),
      );
    },
  );

  test('upgrades v1 orders and uses date placed for old paid orders', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE members (
              id TEXT PRIMARY KEY, email TEXT NOT NULL, givenName TEXT NOT NULL,
              role INTEGER NOT NULL, active INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE orders (
              id INTEGER PRIMARY KEY, statusId INTEGER NOT NULL,
              memberId TEXT NOT NULL REFERENCES members(id), memberName TEXT NOT NULL,
              tableNumber INTEGER NOT NULL, customerName TEXT NOT NULL, note TEXT NOT NULL,
              dated TEXT NOT NULL, total INTEGER NOT NULL, searchText TEXT NOT NULL
            )
          ''');
          await db.insert('members', {
            'id': _admin,
            'email': 'admin@example.com',
            'givenName': 'Quản trị',
            'role': 1,
            'active': 1,
          });
          await db.insert('members', {
            'id': _member,
            'email': 'member@example.com',
            'givenName': 'Khách mẫu',
            'role': 2,
            'active': 1,
          });
          final legacyOrder = _orderRow(
            status: 6,
            dated: '2024-12-31T17:00:00.000Z',
          )..remove('paidAtUtc');
          await db.insert('orders', {'id': 27, ...legacyOrder});
        },
      ),
    );
    await old.close();

    await db.initialize();
    final row = (await db.paidOrders(
      _admin,
      year: 2025,
      month: 1,
      day: 1,
    )).single;
    expect(row.id, 27);
    expect(row.total, 30000);
    expect(row.paidAtUtc, isNull);
    expect(await db.paidOrders(_admin, year: 2024), isEmpty);
  });
}

Map<String, Object?> _orderRow({
  required int status,
  String dated = '2024-12-31T16:30:00.000Z',
  String? paidAt,
}) => {
  'statusId': status,
  'memberId': _member,
  'memberName': 'Khách mẫu',
  'tableNumber': 1,
  'customerName': 'An',
  'note': '',
  'dated': dated,
  'paidAtUtc': paidAt,
  'total': 30000,
  'searchText': 'khach mau an ban 1',
};
