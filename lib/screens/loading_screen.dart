import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/user_provider.dart';
import 'home.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    try {
      // ① 起動時に必要な非同期処理
      await context.read<UserProvider>().init();

      // ② 初期化完了後に Home へ遷移
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      debugPrint('[LoadingScreen] 初期化エラー: $e');
      // 失敗時はここで止まる（後でエラー画面にしてもOK）
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
