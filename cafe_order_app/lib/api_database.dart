import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cart_ext.dart';
import 'category.dart';
import 'local_database.dart';
import 'member.dart';
import 'order_ticket.dart';
import 'product.dart';

class ApiException extends AppException {
  const ApiException(super.message, {this.statusCode});

  final int? statusCode;
}

class ApiDatabase extends LocalDatabase {
  ApiDatabase({
    String baseUrl = const String.fromEnvironment(
      'CAFE_API_URL',
      defaultValue: 'http://localhost:5187',
    ),
    http.Client? client,
  }) : _base = Uri.parse(baseUrl),
       _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;
  String? _token;

  String? get sessionToken => _token;

  void setSessionToken(String? token) => _token = token;

  @override
  Future<void> initialize() async {
    await _request('GET', '/api/health');
  }

  @override
  Future<void> close() async => _client.close();

  Future<Member?> restoreSession() async {
    final token = _token;
    if (token == null) return null;
    try {
      final member = _member(await _json('GET', '/api/auth/me'));
      if (!member.active && _token == token) _token = null;
      return member.active ? member : null;
    } on ApiException catch (error) {
      if (error.statusCode != 401 && error.statusCode != 403) rethrow;
      if (_token == token) _token = null;
      return null;
    }
  }

  Future<void> signOut() async {
    final token = _token;
    if (token == null) return;
    try {
      await _request('POST', '/api/auth/logout');
    } finally {
      if (_token == token) _token = null;
    }
  }

  @override
  Future<Member> signIn(String email, String password) async {
    final data = _map(
      await _json(
        'POST',
        '/api/auth/login',
        body: {'email': email, 'password': password},
        authenticated: false,
      ),
    );
    final member = _member(data['member']);
    _token = data['token'] as String;
    return member;
  }

  @override
  Future<Member> register({
    required String email,
    required String password,
    required String givenName,
    String? surname,
  }) async => _member(
    await _json(
      'POST',
      '/api/auth/register',
      body: {
        'email': email,
        'password': password,
        'givenName': givenName,
        'surname': surname,
      },
      authenticated: false,
    ),
  );

  @override
  Future<Member?> member(String id) async {
    final member = await restoreSession();
    return member?.id == id ? member : null;
  }

  @override
  Future<void> changePassword(
    String memberId,
    String oldPassword,
    String newPassword,
  ) async {
    await _request(
      'PUT',
      '/api/auth/password',
      body: {'currentPassword': oldPassword, 'newPassword': newPassword},
    );
  }

  @override
  Future<List<Member>> members(String adminId, {String search = ''}) async =>
      _list(await _json('GET', '/api/members', query: {'search': search}))
          .map(_member)
          .toList();

  @override
  Future<void> updateMember(
    String adminId,
    String memberId, {
    required String givenName,
    String? surname,
    required int role,
    required bool active,
  }) async {
    await _request(
      'PUT',
      '/api/members/${Uri.encodeComponent(memberId)}',
      body: {
        'givenName': givenName,
        'surname': surname,
        'role': role,
        'active': active,
      },
    );
  }

  @override
  Future<List<Category>> categories() async =>
      _list(await _json('GET', '/api/categories'))
          .map((item) => Category.fromMap(_map(item)))
          .toList();

  @override
  Future<PageResult<Product>> products({
    int? categoryId,
    String search = '',
    int? excludeId,
    int page = 1,
    int pageSize = 6,
  }) async {
    final result = _map(
      await _json(
        'GET',
        '/api/products',
        query: {
          if (categoryId != null) 'categoryId': '$categoryId',
          if (excludeId != null) 'excludeId': '$excludeId',
          if (search.isNotEmpty) 'search': search,
          'page': '$page',
          'pageSize': '$pageSize',
        },
      ),
    );
    return PageResult(
      items: _list(result['items'])
          .map((item) => Product.fromMap(_map(item)))
          .toList(),
      total: result['total'] as int,
    );
  }

  @override
  Future<Product?> product(int id) async {
    final data = await _json('GET', '/api/products/$id', allowNotFound: true);
    return data == null ? null : Product.fromMap(_map(data));
  }

  @override
  Future<Uint8List?> image(int id) async => (await _request(
    'GET',
    '/api/images/$id',
    allowNotFound: true,
  ))?.bodyBytes;

  @override
  Future<void> saveCategory(
    String adminId, {
    int? id,
    required String name,
    required String description,
    Uint8List? image,
    bool removeImage = false,
  }) async {
    await _request(
      id == null ? 'POST' : 'PUT',
      id == null ? '/api/categories' : '/api/categories/$id',
      body: {
        'name': name,
        'description': description,
        if (image != null) 'imageBase64': base64Encode(image),
        'removeImage': removeImage,
      },
    );
  }

  @override
  Future<void> deleteCategory(String adminId, int id) async {
    await _request('DELETE', '/api/categories/$id');
  }

  @override
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
    await _request(
      id == null ? 'POST' : 'PUT',
      id == null ? '/api/products' : '/api/products/$id',
      body: {
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'stock': stock,
        if (image != null) 'imageBase64': base64Encode(image),
      },
    );
  }

  @override
  Future<void> deleteProduct(String adminId, int id) async {
    await _request('DELETE', '/api/products/$id');
  }

  @override
  Future<List<CartExt>> cart(String memberId) async =>
      _list(await _json('GET', '/api/cart'))
          .map((item) => CartExt.fromMap(_map(item)))
          .toList();

  @override
  Future<int> cartCount(String memberId) async =>
      await _json('GET', '/api/cart/count') as int;

  @override
  Future<void> addToCart(String memberId, int productId) async {
    await _request('POST', '/api/cart/$productId');
  }

  @override
  Future<void> setCartQuantity(
    String memberId,
    int productId,
    int quantity,
  ) async {
    await _request('PUT', '/api/cart/$productId', body: {'quantity': quantity});
  }

  @override
  Future<int> checkout(
    String memberId, {
    required int tableNumber,
    required String customerName,
    String note = '',
  }) async => await _json(
    'POST',
    '/api/orders',
    body: {
      'tableNumber': tableNumber,
      'customerName': customerName,
      'note': note,
    },
  ) as int;

  @override
  Future<List<OrderTicket>> orders(
    String actorId, {
    bool admin = false,
    String search = '',
    DateTime? date,
  }) async => _list(
    await _json(
      'GET',
      '/api/orders',
      query: {
        'admin': '$admin',
        if (search.isNotEmpty) 'search': search,
        if (date != null) 'date': _dateKey(date),
      },
    ),
  ).map((item) => OrderTicket.fromMap(_map(item))).toList();

  @override
  Future<OrderTicket?> order(
    String actorId,
    int id, {
    bool admin = false,
  }) async {
    final data = await _json(
      'GET',
      '/api/orders/$id',
      query: {'admin': '$admin'},
      allowNotFound: true,
    );
    return data == null ? null : OrderTicket.fromMap(_map(data));
  }

  @override
  Future<List<OrderTicket>> paidOrders(
    String adminId, {
    int? year,
    int? month,
    int? day,
  }) async => _list(
    await _json(
      'GET',
      '/api/orders/revenue',
      query: {
        if (year != null) 'year': '$year',
        if (month != null) 'month': '$month',
        if (day != null) 'day': '$day',
      },
    ),
  ).map((item) => OrderTicket.fromMap(_map(item))).toList();

  @override
  Future<List<OrderLine>> orderLines(
    String actorId,
    int id, {
    bool admin = false,
  }) async => _list(
    await _json('GET', '/api/orders/$id/lines', query: {'admin': '$admin'}),
  ).map((item) => OrderLine.fromMap(_map(item))).toList();

  @override
  Future<void> updateOrderStatus(String adminId, int id, int statusId) async {
    await _request(
      'PUT',
      '/api/orders/$id/status',
      body: {'statusId': statusId},
    );
  }

  Future<Object?> _json(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool allowNotFound = false,
    bool authenticated = true,
  }) async {
    final response = await _request(
      method,
      path,
      query: query,
      body: body,
      allowNotFound: allowNotFound,
      authenticated: authenticated,
    );
    if (response == null || response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('Web API trả về dữ liệu không hợp lệ.');
    }
  }

  Future<http.Response?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool allowNotFound = false,
    bool authenticated = true,
  }) async {
    final prefix = _base.path.replaceFirst(RegExp(r'/$'), '');
    final uri = _base.replace(path: '$prefix$path', queryParameters: query);
    final token = _token;
    final request = http.Request(method, uri);
    request.headers['Accept'] = '*/*';
    if (authenticated && token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }

    late http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException('Web API phản hồi quá lâu. Vui lòng thử lại.');
    } on http.ClientException {
      throw ApiException('Không thể kết nối Web API tại ${_base.origin}.');
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;
    if (status == 404 && allowNotFound) return null;
    throw ApiException(_errorMessage(response), statusCode: status);
  }

  static String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final message = data is Map ? data['message'] : null;
      if (message is String && message.isNotEmpty) return message;
    } on FormatException {
      // Use a stable user-facing message for empty or non-JSON responses.
    }
    return switch (response.statusCode) {
      401 => 'Phiên đăng nhập không còn hiệu lực. Vui lòng đăng nhập lại.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu.',
      _ => 'Web API trả về lỗi ${response.statusCode}. Vui lòng thử lại.',
    };
  }

  static Map<String, Object?> _map(Object? value) =>
      value as Map<String, Object?>;

  static List<Object?> _list(Object? value) => value as List<Object?>;

  static Member _member(Object? data) {
    final member = _map(data);
    final active = member['active'];
    return Member.fromMap(
      active is bool ? {...member, 'active': active ? 1 : 0} : member,
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
