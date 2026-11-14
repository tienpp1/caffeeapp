import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:win32/win32.dart';

typedef _EnumerateNative = Int32 Function(
  Pointer<Utf16>,
  Uint32,
  Pointer<Uint32>,
  Pointer<Pointer<Pointer<CREDENTIAL>>>,
);

typedef _EnumerateDart = int Function(
  Pointer<Utf16>,
  int,
  Pointer<Uint32>,
  Pointer<Pointer<Pointer<CREDENTIAL>>>,
);

/// Stores this app's values as user-scoped generic Windows credentials.
class FlutterSecureStorageWindows extends FlutterSecureStoragePlatform {
  static const _prefix = 'vn.cafemay.cafe_order_app/';
  static const _maxBlobSize = 5 * 512;
  static final _enumerate = DynamicLibrary.open('advapi32.dll')
      .lookupFunction<_EnumerateNative, _EnumerateDart>('CredEnumerateW');

  static void registerWith() {
    FlutterSecureStoragePlatform.instance = FlutterSecureStorageWindows();
  }

  static String _target(String key) =>
      '$_prefix${utf8.encode(key).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';

  static String _key(String target) {
    final hex = target.substring(_prefix.length);
    return utf8.decode([
      for (var offset = 0; offset < hex.length; offset += 2)
        int.parse(hex.substring(offset, offset + 2), radix: 16),
    ]);
  }

  static Never _failure(String operation, int code) => throw PlatformException(
    code: 'windows_credential_store',
    message: '$operation failed (Windows error $code).',
  );

  static String _value(CREDENTIAL credential) =>
      credential.CredentialBlobSize == 0
      ? ''
      : utf8.decode(
          credential.CredentialBlob.asTypedList(credential.CredentialBlobSize),
        );

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => using((arena) {
    final credential = arena<Pointer<CREDENTIAL>>();
    final target = PCWSTR(_target(key).toNativeUtf16(allocator: arena));
    final result = CredRead(target, CRED_TYPE_GENERIC, credential);
    if (!result.value) {
      if (result.error == ERROR_NOT_FOUND) return null;
      _failure('CredReadW', result.error);
    }

    try {
      return _value(credential.value.ref);
    } finally {
      CredFree(credential.value);
    }
  });

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final bytes = utf8.encode(value);
    if (bytes.length > _maxBlobSize) {
      throw PlatformException(
        code: 'windows_credential_size',
        message: 'Credential exceeds the Windows size limit.',
      );
    }

    using((arena) {
      final blob = arena<Uint8>(bytes.isEmpty ? 1 : bytes.length);
      blob.asTypedList(bytes.length).setAll(0, bytes);
      try {
        final credential = arena<CREDENTIAL>();
        credential.ref
          ..Type = CRED_TYPE_GENERIC
          ..TargetName = PWSTR(_target(key).toNativeUtf16(allocator: arena))
          ..CredentialBlobSize = bytes.length
          ..CredentialBlob = blob
          ..Persist = CRED_PERSIST_LOCAL_MACHINE;
        final result = CredWrite(credential, 0);
        if (!result.value) _failure('CredWriteW', result.error);
      } finally {
        blob.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
      }
    });
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => await read(key: key, options: options) != null;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => using((arena) {
    final target = PCWSTR(_target(key).toNativeUtf16(allocator: arena));
    final result = CredDelete(target, CRED_TYPE_GENERIC);
    if (!result.value && result.error != ERROR_NOT_FOUND) {
      _failure('CredDeleteW', result.error);
    }
  });

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => using((arena) {
    final filter = '$_prefix*'.toNativeUtf16(allocator: arena);
    final count = arena<Uint32>();
    final credentials = arena<Pointer<Pointer<CREDENTIAL>>>();
    if (_enumerate(filter, 0, count, credentials) == 0) {
      final error = GetLastError();
      if (error == ERROR_NOT_FOUND) return {};
      _failure('CredEnumerateW', error);
    }

    try {
      final values = <String, String>{};
      for (var index = 0; index < count.value; index++) {
        final credential = credentials.value[index].ref;
        final target = credential.TargetName.toDartString();
        if (credential.Type == CRED_TYPE_GENERIC &&
            target.toLowerCase().startsWith(_prefix)) {
          values[_key(target)] = _value(credential);
        }
      }
      return values;
    } finally {
      CredFree(credentials.value);
    }
  });

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    final values = await readAll(options: options);
    for (final key in values.keys) {
      await delete(key: key, options: options);
    }
  }
}
