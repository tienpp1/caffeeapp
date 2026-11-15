import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cafe_order_app/cart_page.dart';
import 'package:cafe_order_app/helper.dart';
import 'package:cafe_order_app/local_database.dart';
import 'package:cafe_order_app/login_page.dart';
import 'package:cafe_order_app/main.dart';
import 'package:cafe_order_app/register_page.dart';
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

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int attempts = 100,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    expect(finder, findsWidgets);
  }

  testWidgets('Create account from login and return with the email filled in', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(SessionHelper.delete);

    await tester.pumpWidget(const MyApp());
    final signIn = find.widgetWithText(FilledButton, 'Đăng nhập');
    await waitFor(tester, signIn);
    await tester.tap(signIn);
    await tester.pumpAndSettle();

    final openRegister = find.widgetWithText(TextButton, 'Tạo tài khoản');
    await tester.ensureVisible(openRegister);
    await tester.tap(openRegister);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(RegisterPage), findsOneWidget);

    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );

    const email = 'lien.dangky@example.com';
    const password = 'CafeMay@1234';
    await tester.enterText(field('Tên'), 'Liên');
    await tester.enterText(field('Email'), email);
    await tester.enterText(field('Mật khẩu'), password);
    await tester.enterText(field('Nhập lại mật khẩu'), password);
    final submit = find.widgetWithText(FilledButton, 'Tạo tài khoản');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Đang tạo tài khoản…'), findsOneWidget);

    await waitFor(
      tester,
      find.text('Đã tạo tài khoản. Bạn có thể đăng nhập.'),
      attempts: 500,
    );
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.widget<TextField>(field('Email')).controller?.text, email);
    expect(
      tester.widget<TextField>(field('Mật khẩu')).controller?.text,
      isEmpty,
    );

    final member = await tester.runAsync(
      () => database.signIn(email, password),
    );
    expect(member?.givenName, 'Liên');
    expect(tester.takeException(), isNull);
  });

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
    final productCards = find.byType(ProductCard);
    await waitFor(tester, productCards);
    final firstProduct = productCards.first;
    final stock = tester.widget<ProductCard>(firstProduct).product.stock;
    await tester.tap(firstProduct);
    final cart = find.text('Xem giỏ món');
    await waitFor(tester, cart);
    await tester.ensureVisible(cart);
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

    await tester.pumpAndSettle();
    final back = find.byType(BackButton).hitTestable();
    await tester.tap(back);
    await waitFor(tester, find.text('Giỏ món đang trống.'));
    await tester.pumpAndSettle();
    await tester.tap(back);
    await waitFor(tester, find.text('Còn ${stock - 1} phần'));
    expect(tester.takeException(), isNull);

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
    final success = find.text('Đã cập nhật trạng thái đơn.');
    final error = find.text('Đã có lỗi. Vui lòng thử lại.');
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
      await waitFor(tester, success);
      expect(success, findsOneWidget);
      expect(error, findsNothing);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pump();
      expect(success, findsNothing);
    }
    await waitFor(tester, find.text('Đã thu tiền mặt'));
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Members only see their own orders after switching accounts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const firstEmail = 'first.orders@example.com';
    const secondEmail = 'second.orders@example.com';
    const password = 'CafeMay@1234';
    final orders = (await tester.runAsync(() async {
      final product = (await database.products(pageSize: 1)).items.single;
      Future<int> createOrder(String email, int table) async {
        final member = await database.register(
          email: email,
          password: password,
          givenName: 'Linh',
        );
        await database.addToCart(member.id, product.id);
        return database.checkout(
          member.id,
          tableNumber: table,
          customerName: 'Linh',
        );
      }

      final first = await createOrder(firstEmail, 7);
      final second = await createOrder(secondEmail, 8);
      await SessionHelper.save(await database.signIn(firstEmail, password));
      return (first: first, second: second);
    }))!;

    await tester.pumpWidget(const MyApp());
    final menu = find.byIcon(Icons.menu);
    await waitFor(tester, menu);
    await tester.tap(menu);
    final myOrders = find.text('Đơn của tôi').hitTestable();
    await waitFor(tester, myOrders);
    await tester.tap(myOrders);

    final firstOrder = find.text('Đơn #${orders.first} · Bàn 7');
    final secondOrder = find.text('Đơn #${orders.second} · Bàn 8');
    await waitFor(tester, firstOrder);
    expect(secondOrder, findsNothing);
    await tester.tap(firstOrder);
    final firstDetail = find.text('Đơn #${orders.first}');
    await waitFor(tester, firstDetail);

    await tester.runAsync(() async {
      await SessionHelper.delete();
      await SessionHelper.save(await database.signIn(secondEmail, password));
    });
    final denied = find.text('Không tìm thấy đơn hoặc bạn chưa có quyền xem.');
    await waitFor(tester, denied);
    expect(firstDetail, findsNothing);
    await tester.tap(find.byType(BackButton).hitTestable());
    await waitFor(tester, secondOrder);
    expect(firstOrder, findsNothing);

    final search = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Tìm mã đơn, số bàn hoặc tên',
    );
    await tester.enterText(search, '#${orders.first}');
    await tester.pump(const Duration(milliseconds: 300));
    await waitFor(tester, find.text('Không có đơn phù hợp.'));
    expect(firstOrder, findsNothing);
    await tester.enterText(search, '#${orders.second}');
    await tester.pump(const Duration(milliseconds: 300));
    await waitFor(tester, secondOrder);
    expect(tester.takeException(), isNull);
  });
}
