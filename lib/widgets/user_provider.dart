// lib/widgets/user_provider.dart

import 'package:flutter/foundation.dart';
import '../utils/user_manager.dart';
import '../db/database_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

/// 環境に応じたベースURLを返す
String getBaseUrl() {
  const String productionUrl = ''; // TODO: 本番環境URLを追加

  if (productionUrl.isNotEmpty) return productionUrl;

  if (Platform.isAndroid) return 'http://10.0.2.2:3000'; // Androidエミュレータ用
  return 'http://localhost:3000'; // iOS / 開発環境用
}

/// ユーザー情報をアプリ全体で管理するProvider
/// 未来のサーバー対応や複数端末同期を考慮した構造
class UserProvider extends ChangeNotifier {
  String _userId = '';
  String _displayName = '';

  /// 初期化：匿名ID生成＆サーバーから情報取得
  Future<void> init({bool skipServer = false}) async {
    // UserManagerで匿名ID生成・DB登録
    await UserManager.init();
    _userId = UserManager.currentUserId;
    _displayName = UserManager.displayName;

    debugPrint(
      '[UserProvider] init: _userId=$_userId, _displayName=$_displayName',
    );

    if (!skipServer) {
      // ローカルサーバーから匿名ユーザー情報取得
      final serverUser = await _fetchAnonymousUserFromServer();
      if (serverUser != null) {
        _userId = serverUser['user_id'] ?? _userId;
        _displayName = serverUser['username'] ?? _displayName;
        await UserManager.setDisplayName(_displayName);
        debugPrint(
          '[UserProvider] Server data applied: _userId=$_userId, _displayName=$_displayName',
        );
      }
    } else {
      debugPrint('[UserProvider] Server fetch skipped');
    }

    notifyListeners();
  }

  String get userId => _userId;
  String get currentUserId => _userId;
  String get displayName => _displayName;

  /// ディスプレイ名更新
  Future<void> setDisplayName(String name) async {
    _displayName = name;
    await UserManager.setDisplayName(name);
    notifyListeners();
  }

  /// サーバーから匿名ユーザー情報を取得
  Future<Map<String, dynamic>?> _fetchAnonymousUserFromServer() async {
    try {
      final url = Uri.parse('${getBaseUrl()}/api/anonymous_user');

      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 3)); // ★ timeout を追加

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('[UserProvider] サーバーから取得できませんでした: ${response.statusCode}');
        return null;
      }
    } on SocketException {
      debugPrint('[UserProvider] ネットワーク未接続 or サーバー未起動');
      return null;
    } on TimeoutException {
      debugPrint('[UserProvider] タイムアウト: サーバー反応なし');
      return null;
    } catch (e) {
      debugPrint('[UserProvider] サーバー接続エラー: $e');
      return null;
    }
  }

  /// 匿名データを表示用に現在ユーザーIDでマッピング
  Future<List<Map<String, dynamic>>> mapAnonymousData(
    List<Map<String, dynamic>> items,
  ) async {
    return items.map((item) {
      return {...item, 'user_id': _userId};
    }).toList();
  }

  /// ログアウト
  Future<void> logout() async {
    debugPrint('[Logout] Start');

    await UserManager.logout();

    _userId = UserManager.anonUserId;
    _displayName = '匿名ラッコ';

    notifyListeners();

    debugPrint('[Logout] Done: _userId=$_userId, _displayName=$_displayName');
  }

  /// ユーザー情報更新（UI更新用）
  void setUser(String uid, String name) {
    _userId = uid;
    _displayName = name;
    notifyListeners();
  }

  // ===========================
  // ★ メール連携・ログイン機能
  // ===========================

  /// メール連携（ユーザー名・生年月日付き）
  Future<void> linkWithEmail(
    String email,
    String hashedPassword,
    String username,
    String userType,
  ) async {
    final db = await DatabaseHelper.instance.database;

    // 既存メールアドレス重複チェック
    final existingUser = await db.query(
      'Users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (existingUser.isNotEmpty) {
      throw Exception('このメールアドレスはすでに使用されています');
    }

    // 現在の匿名ユーザーを更新
    await db.update(
      'Users',
      {
        'email': email,
        'password_hash': hashedPassword,
        'username': username,
        'user_type': userType,
      },
      where: 'user_id = ?',
      whereArgs: [_userId],
    );

    _displayName = username;

    debugPrint(
      '[linkWithEmail] email=$email, username=$username, user_type=$userType',
    );

    notifyListeners();
  }

  /// メールログイン
  Future<void> loginWithEmail(String email, String hashedPassword) async {
    final db = await DatabaseHelper.instance.database;

    debugPrint('================ [Login Attempt] ================');
    debugPrint('[Login] Input email=$email, hash=$hashedPassword');
    debugPrint('[Login] Current _userId(before query)=$_userId');

    final user = await db.query(
      'Users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email, hashedPassword],
    );

    debugPrint('[Login] Query result count=${user.length}');
    debugPrint('[Login] Query result=$user');

    if (user.isEmpty) {
      debugPrint('[Login] user.isEmpty -> invalid credentials');
      throw Exception('メールアドレスまたはパスワードが間違っています');
    }

    final uid = user.first['user_id'] as String;
    final name = user.first['username'] as String? ?? 'ユーザー';

    debugPrint('[Login] DB returned uid=$uid, name=$name');

    // データベースは書き換えず、表示時に現在ログインIDにマッピング
    setUser(uid, name);

    final allUsers = await db.query('Users');
    debugPrint('[Login] Users table snapshot: $allUsers');
    debugPrint('=================================================');
  }
}
