import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_database.dart';
import 'local_database.dart';
import 'member.dart';

class SessionHelper {
  static const _storage = FlutterSecureStorage();
  static const _memberKey = 'cafe_order_member_id';
  static const _apiTokenKey = 'cafe_may_api_token';
  static final current = ValueNotifier<Member?>(null);

  static Future<void> restore() async {
    final db = LocalDatabase.instance;
    if (db is ApiDatabase) {
      // The browser session lives in memory until the page is closed or reloaded.
      if (!kIsWeb) db.setSessionToken(await _storage.read(key: _apiTokenKey));
      final member = await db.restoreSession();
      if (!kIsWeb && member == null) await _storage.delete(key: _apiTokenKey);
      current.value = member;
      return;
    }
    final id = await _storage.read(key: _memberKey);
    if (id == null) return;

    final member = await LocalDatabase.instance.member(id);
    if (member == null || !member.active) {
      await delete();
      return;
    }
    current.value = member;
  }

  static Future<void> save(Member member) async {
    final db = LocalDatabase.instance;
    if (db is ApiDatabase) {
      if (!kIsWeb) {
        await _storage.write(key: _apiTokenKey, value: db.sessionToken);
      }
    } else {
      await _storage.write(key: _memberKey, value: member.id);
    }
    current.value = member;
  }

  static Future<void> delete() async {
    final db = LocalDatabase.instance;
    if (db is ApiDatabase) {
      try {
        await db.signOut();
      } on AppException {
        // Local sign-out also succeeds when the server is unavailable.
      } finally {
        if (!kIsWeb) await _storage.delete(key: _apiTokenKey);
        current.value = null;
      }
    } else {
      await _storage.delete(key: _memberKey);
      current.value = null;
    }
  }

  static Future<void> refresh() async {
    final signedIn = current.value;
    if (signedIn == null) return;

    final member = await LocalDatabase.instance.member(signedIn.id);
    if (current.value?.id != signedIn.id) return;
    if (member == null || !member.active) {
      await delete();
      return;
    }
    current.value = member;
  }
}
