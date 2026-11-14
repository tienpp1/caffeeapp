import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cafe_order_app/cart_page.dart';
import 'package:cafe_order_app/helper.dart';
import 'package:cafe_order_app/local_database.dart';
import 'package:cafe_order_app/main.dart';
import 'package:cafe_order_app/session_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  final database = LocalDatabase.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('cafe_order_widget_');
    await databaseFactoryFfi.setDatabasesPath(directory.path);
    FlutterSecureStorage.setMockInitialValues({});
    await database.initialize();
  });

  tearDownAll(() async {
    await SessionHelper.delete();
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    expect(finder, findsWidgets);
  }

  testWidgets('Member adds a menu item and edits its quantity from the cart', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      final member = await database.signIn('member@cafemay.vn', 'Member@12345');
      await SessionHelper.save(member);
    });

    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.byType(ProductCard));

    final card = tester.widget<ProductCard>(find.byType(ProductCard).first);
    await tester.tap(find.byType(ProductCard).first);
    final add = find.text('Thêm vào giỏ món');
    await waitFor(tester, add);
    await tester.ensureVisible(add);
    await tester.tap(add);
    await waitFor(tester, find.text('Đã thêm món vào giỏ món.'));

    final viewCart = find.text('Xem giỏ món');
    await tester.ensureVisible(viewCart);
    await tester.tap(viewCart);
    final increase = find.byTooltip('Tăng số lượng');
    await waitFor(tester, increase);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: find.byType(CartPage),
        matching: find.text(card.product.name),
      ),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget);

    if (card.product.stock > 1) {
      await tester.tap(increase);
      await waitFor(tester, find.text('2'));
      await tester.tap(find.byTooltip('Giảm số lượng'));
      await waitFor(tester, find.text('1'));
    }

    await tester.tap(find.byTooltip('Xóa ${card.product.name} khỏi giỏ'));
    await waitFor(tester, find.text('Giỏ món đang trống.'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('A table order goes from checkout to cash payment', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      final member = await database.signIn('member@cafemay.vn', 'Member@12345');
      final menu = await database.products(pageSize: 1);
      await database.addToCart(member.id, menu.items.single.id);
      await SessionHelper.save(member);
    });

    await tester.pumpWidget(const MyApp());
    final cart = find.byTooltip('Giỏ món');
    await waitFor(tester, cart);
    await tester.tap(cart);
    final checkout = find.text('Tiếp tục đặt món');
    await waitFor(tester, checkout);
    await tester.tap(checkout);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bàn 3').last);
    await tester.pumpAndSettle();
    final submit = find.text('Xác nhận gọi món');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await waitFor(tester, find.text('Chờ xác nhận'));
    expect(find.text('Bàn 3'), findsWidgets);

    final orderId = await tester.runAsync(() async {
      final member = SessionHelper.current.value!;
      final orders = await database.orders(member.id);
      return orders.single.id;
    });
    expect(orderId, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      final admin = await database.signIn('admin@cafemay.vn', 'Admin@12345');
      await SessionHelper.save(admin);
    });
    await tester.pumpWidget(const MyApp());
    final menuButton = find.byIcon(Icons.menu);
    await waitFor(tester, menuButton);
    await tester.tap(menuButton);
    final orderMenu = find.text('Quản lý đơn').hitTestable();
    await waitFor(tester, orderMenu);
    await tester.tap(orderMenu);
    final order = find.text('Đơn #$orderId · Bàn 3');
    await waitFor(tester, order);
    await tester.tap(order);
    for (final action in [
      'Đang pha chế',
      'Chờ phục vụ',
      'Đã phục vụ',
      'Ghi nhận thu tiền mặt',
    ]) {
      final button = find.widgetWithText(OutlinedButton, action);
      await waitFor(tester, button);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    }
    await waitFor(tester, find.text('Đã thu tiền mặt'));
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
