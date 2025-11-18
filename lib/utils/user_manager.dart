// lib/utils/user_manager.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import 'package:flutter/foundation.dart';

/// --- デフォルト値・メッセージなど変更や拡張が想定される定数 ---
const String defaultUserName = "匿名ラッコ"; // 匿名ユーザーの表示名
//--------------------------------------------------------------------

/// ユーザー管理クラス
/// アプリ全体でのユーザーIDや表示名の取得・設定を一元管理
class UserManager {
  // 内部キャッシュ用の変数
  static String? _anonUserId; // 初期匿名ユーザーID
  static String? _currentUserId; // 現在ログイン中のユーザーID
  static String? _displayName;

  // Secure Storage インスタンス
  static final _secureStorage = FlutterSecureStorage();

  /// 初期化（アプリ起動時に呼び出す）
  /// - Secure Storage に保存済みIDがあれば使用
  /// - なければ新規UUIDを生成して保存
  /// - Usersテーブルに存在しない場合は匿名ユーザーとしてDB登録
  static Future<void> init() async {
    _anonUserId = await _secureStorage.read(key: 'anon_user_id');
    _currentUserId = await _secureStorage.read(key: 'current_user_id');
    _displayName = await _secureStorage.read(key: 'display_name');

    if (_anonUserId == null) {
      // UUIDを新規生成して保存
      _anonUserId = const Uuid().v4();
      _displayName ??= defaultUserName;

      await _secureStorage.write(key: 'anon_user_id', value: _anonUserId);
      await _secureStorage.write(key: 'current_user_id', value: _anonUserId);
      await _secureStorage.write(key: 'display_name', value: _displayName);

      debugPrint('[UserManager] 新しい匿名ユーザーIDを生成: $_anonUserId');
    } else {
      debugPrint('[UserManager] 既存匿名ユーザーIDを使用: $_anonUserId');
      _displayName ??= defaultUserName;

      // current_user_id が未設定の場合は匿名IDで初期化
      if (_currentUserId == null) {
        _currentUserId = _anonUserId;
        await _secureStorage.write(
          key: 'current_user_id',
          value: _currentUserId,
        );
      }
    }

    // DB上にユーザーが存在するか確認
    final db = await DatabaseHelper.instance.database;
    final existing = await db.query(
      'Users',
      where: 'user_id = ?',
      whereArgs: [_anonUserId],
    );

    if (existing.isEmpty) {
      // Usersテーブルに匿名ユーザーを登録
      await db.insert('Users', {
        'user_id': _anonUserId,
        'username': _displayName,
      });
      debugPrint('[UserManager] Usersテーブルに $_displayName を登録しました');
    }
  }

  /// 現在のユーザーIDを取得（ログイン中／匿名とも currentUserId）
  static String get currentUserId {
    debugPrint('[UserManager.currentUserId] returning $_currentUserId');
    if (_currentUserId == null) {
      throw Exception('[UserManager] init() を先に呼び出してください');
    }
    return _currentUserId!;
  }

  /// 初期匿名ユーザーIDを取得
  static String get anonUserId {
    if (_anonUserId == null) {
      throw Exception('[UserManager] init() を先に呼び出してください');
    }
    return _anonUserId!;
  }

  /// 現在の表示名を取得
  static String get displayName {
    if (_displayName == null) {
      throw Exception('[UserManager] init() を先に呼び出してください');
    }
    return _displayName!;
  }

  /// 表示名を変更（Secure Storageとキャッシュを更新）
  static Future<void> setDisplayName(String name) async {
    _displayName = name;
    await _secureStorage.write(key: 'display_name', value: name);
    debugPrint('[UserManager] 表示名を $name に変更しました');

    // DBも更新（存在チェック済みの前提）
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'Users',
      {'username': name},
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
    );
  }

  /// ログイン中のユーザーを切り替え（メールアカウントなど）
  static Future<void> setCurrentUserId(String newUserId) async {
    debugPrint(
      '[UserManager.setCurrentUserId] called with newUserId=$newUserId',
    );
    _currentUserId = newUserId;
    await _secureStorage.write(key: 'current_user_id', value: _currentUserId);
    debugPrint(
      '[UserManager.setCurrentUserId] updated currentUserId=$_currentUserId',
    );
  }

  /// ログアウト（current_user_id を匿名IDに戻す）
  static Future<void> logout() async {
    debugPrint('[UserManager] logout() start');
    await clearCredentials();
    debugPrint('[UserManager] credentials cleared');

    debugPrint(
      '[UserManager] anonUserId=$anonUserId, currentUserId before set=$currentUserId',
    );
    await setCurrentUserId(anonUserId);
    debugPrint('[UserManager] currentUserId after set=$currentUserId');
  }

  /// メール・パスワード保存（Secure Storage）
  static Future<void> saveCredentials(String email, String password) async {
    await _secureStorage.write(key: 'email', value: email);
    await _secureStorage.write(key: 'password', value: password);
  }

  /// メール・パスワード取得
  static Future<Map<String, String?>> getCredentials() async {
    final email = await _secureStorage.read(key: 'email');
    final password = await _secureStorage.read(key: 'password');
    return {'email': email, 'password': password};
  }

  /// メール・パスワード削除
  static Future<void> clearCredentials() async {
    await _secureStorage.delete(key: 'email');
    await _secureStorage.delete(key: 'password');
  }
}
