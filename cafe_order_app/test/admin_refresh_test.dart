import 'package:cafe_order_app/category_page.dart';
import 'package:cafe_order_app/local_database.dart';
import 'package:cafe_order_app/member_page.dart';
import 'package:cafe_order_app/session_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousDatabase = LocalDatabase.instance;
  late LocalDatabase database;

  setUpAll(() async {
    sqfliteFfiInit();
    database = LocalDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    LocalDatabase.instance = database;
    SessionHelper.current.value = await database.member('admin-local');
  });

  tearDownAll(() async {
    SessionHelper.current.value = null;
    LocalDatabase.instance = previousDatabase;
    await database.close();
  });

  testWidgets('Category add, edit and delete refresh the open list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1050, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: CategoryPage()));

    final add = find.text('Thêm danh mục').hitTestable();
    await _waitFor(tester, add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    const name = 'Danh mục thử';
    const revisedName = 'Danh mục đã sửa';
    await tester.enterText(_field('Tên danh mục'), name);
    await tester.enterText(_field('Mô tả'), 'Dữ liệu kiểm thử danh mục.');
    final save = find.widgetWithText(FilledButton, 'Lưu');
    await tester.tap(save);
    final added = find.widgetWithText(ListTile, name);
    await _waitFor(tester, added);
    await tester.pumpAndSettle();
    expect(find.text('4 danh mục'), findsOneWidget);
    expect(find.text('Đã lưu danh mục.'), findsOneWidget);

    await tester.tap(added);
    await tester.pumpAndSettle();
    await tester.enterText(_field('Tên danh mục'), revisedName);
    await tester.tap(save);
    final edited = find.widgetWithText(ListTile, revisedName);
    await _waitFor(tester, edited);
    await tester.pumpAndSettle();
    expect(added, findsNothing);

    final options = find.descendant(
      of: edited,
      matching: find.byTooltip('Thao tác danh mục'),
    );
    await tester.tap(options);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await _waitFor(tester, find.text('3 danh mục'));
    expect(edited, findsNothing);
    await _waitFor(tester, find.text('Đã xóa danh mục.'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Member search and updates refresh the open list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1050, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: MemberPage()));

    final allMembers = find.text('2 thành viên');
    await _waitFor(tester, allMembers);
    final search = _field('Tìm theo tên hoặc email');
    await tester.enterText(search, 'member@cafemay.vn');
    await tester.pump(const Duration(milliseconds: 250));
    await _waitFor(tester, find.text('1 thành viên'));
    expect(find.text('admin@cafemay.vn'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'member@cafemay.vn',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Sửa thành viên'));
    await tester.pumpAndSettle();
    const updatedName = 'Khách thử làm mới';
    await tester.enterText(_field('Tên'), updatedName);
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu thay đổi'));
    await _waitFor(tester, find.text('Đã khóa'));
    await tester.pumpAndSettle();
    expect(find.text(updatedName), findsOneWidget);
    expect(find.text('Đã cập nhật thành viên.'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await _waitFor(tester, allMembers);
    expect(find.text('admin@cafemay.vn'), findsOneWidget);
    expect(find.text(updatedName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  expect(finder, findsOneWidget);
}
