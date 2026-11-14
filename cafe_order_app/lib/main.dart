import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api_database.dart';
import 'cafe_theme.dart';
import 'product_admin_page.dart';
import 'cart_page.dart';
import 'category_page.dart';
import 'details_page.dart';
import 'home_page.dart';
import 'order_details_page.dart';
import 'order_page.dart';
import 'local_database.dart';
import 'login_page.dart';
import 'member_page.dart';
import 'profile_page.dart';
import 'register_page.dart';
import 'session_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const offline = bool.fromEnvironment('CAFE_OFFLINE');
  if (kIsWeb || (defaultTargetPlatform == TargetPlatform.windows && !offline)) {
    LocalDatabase.instance = ApiDatabase();
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<void> _startup = _initialize();

  Future<void> _initialize() async {
    await LocalDatabase.instance.initialize();
    await SessionHelper.restore();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cà Phê Mây',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('vi')],
      theme: buildCafeTheme(),
      home: FutureBuilder<void>(
        future: _startup,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        LocalDatabase.instance is ApiDatabase
                            ? 'Không thể kết nối Web API. Hãy kiểm tra terminal đang chạy dotnet watch run.'
                            : 'Không thể mở dữ liệu trên thiết bị.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _startup = _initialize()),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const HomePage(title: 'Cà Phê Mây');
        },
      ),
      routes: {
        '/login': (_) => const LoginPage(title: 'Đăng nhập'),
        '/register': (_) => const RegisterPage(title: 'Đăng ký'),
        '/profile': (_) => const ProfilePage(title: 'Tài khoản'),
        '/details': (_) => const DetailsPage(title: 'Chi tiết món'),
        '/cart': (_) => const CartPage(title: 'Giỏ món'),
        '/orders': (_) => const OrderPage(title: 'Đơn của tôi'),
        '/orders/details': (_) => const OrderDetailsPage(title: 'Chi tiết đơn'),
        '/admin/members': (_) =>
            const MemberPage(title: 'Thành viên và vai trò'),
        '/admin/categories': (_) =>
            const CategoryPage(title: 'Quản lý danh mục'),
        '/admin/products': (_) => const ProductAdminPage(title: 'Quản lý món'),
        '/admin/orders': (_) =>
            const OrderPage(title: 'Quản lý đơn', admin: true),
      },
    );
  }
}
