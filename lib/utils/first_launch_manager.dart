import 'package:shared_preferences/shared_preferences.dart';

/// 初回起動判定を管理するクラス
class FirstLaunchManager {
  static const String _keyIsInitialized = 'is_initialized';

  /// 初回起動かどうかを返す
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isInitialized = prefs.getBool(_keyIsInitialized);

    // 保存されていなければ初回起動
    return isInitialized != true;
  }

  /// 初回起動処理が完了したことを保存する
  static Future<void> markInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsInitialized, true);
  }
}
