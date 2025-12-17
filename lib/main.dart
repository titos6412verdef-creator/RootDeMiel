// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'screens/home.dart';
import 'screens/review_add.dart';
import 'screens/book_add.dart';
import 'screens/book_manage.dart';
import 'screens/account.dart';
import 'screens/user_guide/evaluation_items.dart';
import 'screens/user_guide/book_selection.dart';
import 'screens/user_guide/app_guide.dart';
import 'screens/debug_add_test_user.dart';

import 'widgets/user_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'レビューアプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),

      // ★ 起動時は必ず Splash
      home: const SplashScreen(),

      // ★ 既存ルーティングはそのまま
      routes: {
        '/home': (context) => const HomeScreen(),
        '/add': (context) => const AddReviewScreen(),
        '/add-book': (context) => const AddBookScreen(),
        '/manage-books': (context) => const ManageBooksScreen(),
        '/account': (context) => const AccountScreen(),
        '/evaluationItems': (context) =>
            EvaluationItemsScreen(onBack: () => Navigator.pop(context)),
        '/bookSelection': (context) =>
            BookSelectionScreen(onBack: () => Navigator.pop(context)),
        '/debug_test_user': (context) => const DebugAddTestUserScreen(),
        '/APPGuide': (context) => const APPGuide(),
      },
    );
  }
}
