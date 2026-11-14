import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

DatabaseFactory defaultDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return databaseFactory;
}

Future<T> runDatabaseComputation<T>(FutureOr<T> Function() compute) =>
    Isolate.run(compute);
