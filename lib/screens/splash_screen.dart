// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/user_provider.dart';
import 'home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration minimumDisplayTime = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await Future.wait([
      userProvider.init(),
      Future.delayed(minimumDisplayTime),
    ]);

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ★ 余白対策
      body: Stack(
        children: [
          // 背景画像（全面）
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash.png',
              fit: BoxFit.cover, // ★ 画面いっぱい
            ),
          ),

          // ローディング（下部中央などに置く例）
          const Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
