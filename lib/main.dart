// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/add_review.dart';
import 'screens/add_book.dart';
import 'screens/manage_books.dart';
import 'screens/account.dart';
import 'db/database_helper.dart';
import 'utils/user_manager.dart';
import 'package:provider/provider.dart';
import 'widgets/user_provider.dart';
import 'screens/user_guide/evaluation_items.dart';
import 'screens/user_guide/book_selection.dart';
import 'screens/user_guide/app_guide.dart';
//import 'screens/user_guide/efficiency_tips.dart';
import 'screens/debug_add_test_user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await UserManager.init();

  final db = await DatabaseHelper.instance.database;

  final userProvider = UserProvider();
  await userProvider.init(); // UserManager init() 内部で呼ばれる

  // デバッグ用：作成されたテーブルの一覧を出力
  List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table';",
  );
  debugPrint("作成されたテーブル一覧:");
  for (var table in tables) {
    debugPrint("- ${table['name']}");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
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
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(), // ← ここを HomeScreen に変更
        '/add': (context) => const AddReviewScreen(),
        '/add-book': (context) => const AddBookScreen(),
        '/manage-books': (context) => const ManageBooksScreen(),
        '/account': (context) => const AccountScreen(),
        '/evaluationItems': (context) =>
            EvaluationItemsScreen(onBack: () => Navigator.pop(context)),
        '/bookSelection': (context) =>
            BookSelectionScreen(onBack: () => Navigator.pop(context)),
        //'/efficiencyTips': (context) =>  EfficiencyTipsScreen(onBack: () => Navigator.pop(context)),
        '/debug_test_user': (context) => const DebugAddTestUserScreen(),
        '/APPGuide': (context) => const APPGuide(),
      },
    );
  }
}
