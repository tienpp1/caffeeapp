import 'dart:io';

import 'package:cafe_order_app/local_database.dart';
import 'package:cafe_order_app/product_admin_page.dart';
import 'package:cafe_order_app/session_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  final previousDatabase = LocalDatabase.instance;
  late LocalDatabase database;

  setUp(() async {
    database = LocalDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    LocalDatabase.instance = database;
    SessionHelper.current.value = await database.member('admin-local');
  });

  tearDown(() async {
    SessionHelper.current.value = null;
    LocalDatabase.instance = previousDatabase;
    await database.close();
  });

  testWidgets(
    'Admin pages contain five products and reset on category change',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: ProductAdminPage()));

      final rows = find.byType(ListTile);
      final nextPage = find.byTooltip('Trang sau').hitTestable();
      for (var page = 1; page <= 4; page++) {
        await _waitFor(tester, find.text('Trang $page / 4').hitTestable());
        expect(rows, findsNWidgets(page == 4 ? 1 : 5));
        if (page < 4) await tester.tap(nextPage);
      }

      final filter = find.byType(DropdownButtonFormField<int>);
      await _selectCategory(tester, filter, 'Cà phê');
      await _waitFor(tester, find.text('Trang 1 / 2'));
      expect(find.text('8 món'), findsOneWidget);
      final coffeeRows = find.descendant(
        of: rows,
        matching: find.text('Cà phê'),
      );
      expect(rows, findsNWidgets(5));
      expect(coffeeRows, findsNWidgets(5));

      await tester.tap(nextPage);
      await _waitFor(tester, find.text('Trang 2 / 2'));
      expect(rows, findsNWidgets(3));
      expect(coffeeRows, findsNWidgets(3));

      await _selectCategory(tester, filter, 'Tất cả danh mục');
      await _waitFor(tester, find.text('Trang 1 / 4'));
      expect(find.text('16 món'), findsOneWidget);
      expect(rows, findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Adding with a photo, editing and deleting refresh the product list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1050, 620));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final messenger = tester.binding.defaultBinaryMessenger;
      final photo = File('assets/products/espresso.jpg').absolute;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pickImage');
        return photo.path;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await tester.pumpWidget(const MaterialApp(home: ProductAdminPage()));
      final add = find.text('Thêm món').hitTestable();
      await _waitFor(tester, add);
      await _selectCategory(
        tester,
        find.byType(DropdownButtonFormField<int>),
        'Bánh và đồ ăn nhẹ',
      );
      await _waitFor(tester, find.text('4 món'));
      await tester.tap(add);
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      final dialogCategory = find.descendant(
        of: dialog,
        matching: find.byType(DropdownButtonFormField<int>),
      );
      const productName = 'Espresso thử lưu';
      await _enterField(tester, 'Tên món', productName);
      await _selectCategory(tester, dialogCategory, 'Cà phê');
      await _enterField(tester, 'Đơn giá (₫)', '32000');
      await _enterField(tester, 'Số lượng còn', '58');
      await _enterField(tester, 'Mô tả', 'Cà phê pha tại quầy.');

      final save = find.widgetWithText(FilledButton, 'Lưu').hitTestable();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.text('Vui lòng chọn ảnh món trước khi lưu.').hitTestable(),
        findsOneWidget,
      );

      final pick = find.text('Chọn ảnh');
      await tester.ensureVisible(pick);
      await tester.tap(pick);
      await _waitFor(tester, find.text('Hoàn tác'));
      await tester.tap(save);
      await _waitFor(tester, find.widgetWithText(ListTile, productName));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.text('9 món'), findsOneWidget);
      expect(find.text('Trang 1 / 2'), findsOneWidget);

      await tester.runAsync(() async {
        final products = await database.products(search: productName);
        final saved = products.items.single;
        expect(saved.categoryId, 1);
        expect(saved.price, 32000);
        expect(saved.stock, 58);
        expect(saved.imageId, isNotNull);
        expect(
          (await database.image(saved.imageId!))?.length,
          await photo.length(),
        );
      });

      await tester.tap(find.widgetWithText(ListTile, productName));
      await tester.pumpAndSettle();
      const revisedName = 'Espresso thử cập nhật';
      await _enterField(tester, 'Tên món', revisedName);
      await tester.tap(save);
      final edited = find.widgetWithText(ListTile, revisedName);
      await _waitFor(tester, edited);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, productName), findsNothing);

      await tester.tap(
        find.descendant(of: edited, matching: find.byTooltip('Thao tác món')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await _waitFor(tester, find.text('8 món'));
      expect(edited, findsNothing);
      await _waitFor(tester, find.text('Đã xóa món.'));
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _selectCategory(
  WidgetTester tester,
  Finder dropdown,
  String label,
) async {
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).hitTestable().last);
  await tester.pump();
}

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String input,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, input);
  await tester.pump();
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 250; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  expect(finder, findsOneWidget);
}
