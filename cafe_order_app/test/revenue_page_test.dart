import 'dart:convert';

import 'package:cafe_order_app/api_database.dart';
import 'package:cafe_order_app/local_database.dart';
import 'package:cafe_order_app/main.dart';
import 'package:cafe_order_app/member.dart';
import 'package:cafe_order_app/session_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'Admin reconciles revenue across periods and opens a paid order',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final originalDatabase = LocalDatabase.instance;
      final originalMember = SessionHelper.current.value;
      final now = DateTime.now().toUtc();
      final cafeToday = now.add(const Duration(hours: 7));
      final previousYear = cafeToday.year - 1;
      final latest = _orderJson(id: 41, total: 60000, date: now, paidAt: now);
      final legacy = _orderJson(
        id: 27,
        total: 30000,
        date: DateTime.utc(previousYear, 6, 15, 8),
      );
      final revenueQueries = <Map<String, String>>[];
      var healthRequests = 0;
      final api = ApiDatabase(
        client: MockClient((request) async {
          final uri = request.url;
          if (uri.path == '/api/health') {
            healthRequests++;
            return healthRequests == 1
                ? _jsonResponse({'status': 'unavailable'}, status: 503)
                : _jsonResponse({'status': 'ok'});
          }
          if (uri.path == '/api/orders/revenue') {
            expect(request.method, 'GET');
            expect(
              request.headers['Authorization'],
              'Bearer revenue-test-token',
            );
            revenueQueries.add(uri.queryParameters);
            return _jsonResponse(switch (uri.queryParameters['year']) {
              null => [latest, legacy],
              final year when year == '$previousYear' => [legacy],
              _ => [latest],
            });
          }
          return _jsonResponse(switch (uri.path) {
            '/api/auth/me' => {
              'id': 'test-admin',
              'email': 'admin@example.com',
              'givenName': 'Quản trị',
              'role': 1,
              'active': true,
            },
            '/api/products' => {'items': [], 'total': 0},
            '/api/categories' || '/api/orders/27/lines' => [],
            '/api/cart/count' => 0,
            '/api/orders/27' => legacy,
            _ => throw StateError('Unexpected API request: ${uri.path}'),
          });
        }),
      );
      LocalDatabase.instance = api;
      FlutterSecureStorage.setMockInitialValues({
        'cafe_may_api_token': 'revenue-test-token',
      });
      addTearDown(() async {
        LocalDatabase.instance = originalDatabase;
        SessionHelper.current.value = originalMember;
        FlutterSecureStorage.setMockInitialValues({});
        await api.close();
      });

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Thử lại'));
      await tester.pumpAndSettle();
      expect(healthRequests, 2);
      await tester.tap(find.byTooltip('Mở chức năng quản trị'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quản lý doanh thu'));
      await tester.pumpAndSettle();

      expect(revenueQueries.single, isEmpty);
      expect(find.text('90.000 ₫'), findsOneWidget);
      expect(find.text('45.000 ₫'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      final latestRow = find.text('Đơn #41 · Bàn 1');
      final legacyRow = find.text('Đơn #27 · Bàn 1');
      expect(latestRow, findsOneWidget);
      expect(legacyRow, findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ngày'));
      await tester.pumpAndSettle();
      expect(revenueQueries.last, {
        'year': '${cafeToday.year}',
        'month': '${cafeToday.month}',
        'day': '${cafeToday.day}',
      });
      expect(latestRow, findsOneWidget);
      expect(legacyRow, findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Tháng'));
      await tester.pumpAndSettle();
      expect(revenueQueries.last, {
        'year': '${cafeToday.year}',
        'month': '${cafeToday.month}',
      });

      await tester.tap(find.widgetWithText(ChoiceChip, 'Năm'));
      await tester.pumpAndSettle();
      expect(revenueQueries.last, {'year': '${cafeToday.year}'});
      await tester.tap(
        find.widgetWithIcon(OutlinedButton, Icons.calendar_today_outlined),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chọn năm doanh thu'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$previousYear').hitTestable().last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng'));
      await tester.pumpAndSettle();
      expect(revenueQueries.last, {'year': '$previousYear'});
      expect(latestRow, findsNothing);
      expect(legacyRow, findsOneWidget);

      await tester.tap(legacyRow);
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết đơn'), findsOneWidget);
      expect(find.text('Đơn #27'), findsOneWidget);
      await tester.tap(find.byType(BackButton).hitTestable());
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(390, 800));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ChoiceChip, 'Ngày').hitTestable(),
        findsOneWidget,
      );
      expect(legacyRow.hitTestable(), findsOneWidget);

      final queryCount = revenueQueries.length;
      SessionHelper.current.value = const Member(
        id: 'test-member',
        email: 'member@example.com',
        givenName: 'Khách',
        role: 2,
        active: true,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Chỉ quản trị viên được xem doanh thu.'),
        findsOneWidget,
      );
      expect(revenueQueries, hasLength(queryCount));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

http.Response _jsonResponse(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _orderJson({
  required int id,
  required int total,
  required DateTime date,
  DateTime? paidAt,
}) => {
  'id': id,
  'statusId': 6,
  'total': total,
  'memberId': 'test-member',
  'memberName': 'Khách',
  'tableNumber': 1,
  'customerName': 'Khách',
  'note': '',
  'dated': date.toIso8601String(),
  'paidAtUtc': paidAt?.toIso8601String(),
};
