import 'dart:async';

import 'package:sqflite/sqflite.dart';

DatabaseFactory defaultDatabaseFactory() =>
    throw UnsupportedError('Ứng dụng trên trình duyệt dùng Web API.');

Future<T> runDatabaseComputation<T>(FutureOr<T> Function() compute) async =>
    compute();
