import 'first_launch_manager.dart';

/// アプリ起動時の初期化処理をまとめるクラス
class AppInitializer {
  /// 起動時に必ず呼ぶ初期化処理
  static Future<void> initialize() async {
    // 1. DB初期化（後で実装）
    await _initializeDatabase();

    // 2. ユーザーID初期化（後で実装）
    await _initializeUser();

    // 3. 初回起動チェック
    final isFirstLaunch = await FirstLaunchManager.isFirstLaunch();

    if (isFirstLaunch) {
      // 4. 初回起動時のみの処理
      await _runFirstLaunchSetup();
      await FirstLaunchManager.markInitialized();
    }
  }

  // ---- 以下は内部専用メソッド ----

  static Future<void> _initializeDatabase() async {
    // TODO: DB接続・確認
  }

  static Future<void> _initializeUser() async {
    // TODO: 匿名ユーザーID取得
  }

  static Future<void> _runFirstLaunchSetup() async {
    // TODO: 初期データ投入など
  }
}
