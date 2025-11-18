// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'review_list.dart';
import 'book_comparison.dart';
import 'user_profile.dart';
import 'user_guide/user_guide.dart';
import 'user_guide/evaluation_items.dart';
import 'ranking.dart';

/// プレースホルダー画面（未実装画面用）
/// 未実装画面に簡単なメッセージを表示する
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title は未実装です',
        style: const TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}

/// ホーム画面（タブ切り替え + 内部画面切替を管理）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // 現在表示中のタブインデックス
  List<int> selectedBookIds = []; // 選択中の書籍IDリスト

  /// タブに応じて Body の表示ウィジェットを返す
  Widget _getBody(int index) {
    switch (index) {
      case 0:
        // 書籍一覧画面
        return ReviewListScreen(
          onBookSelected: _handleBookSelected,
          selectedBookIds: selectedBookIds,
        );
      case 1:
        // 書籍比較画面
        return BookComparisonScreen(
          selectedBookIds: List.from(selectedBookIds),
        );
      case 2:
        // おすすめランキング画面
        return const RankingScreen();
      case 3:
        // 使い方ガイド画面
        return UserGuideWidget(
          onBack: () {
            setState(() {
              _currentIndex = 0; // 書籍一覧に戻す
            });
          },
          onShowEvaluationItems: () {
            setState(() {
              _currentIndex = 6; // 評価項目画面へ遷移
            });
          },
        );
      case 4:
        // 設定画面
        return UserProfileScreen(
          onShowUserGuide: () {
            setState(() {
              _currentIndex = 5; // Home 内で使い方ガイド表示
            });
          },
        );
      case 5:
        // Home 内の使い方ガイド画面（設定から遷移）
        return UserGuideWidget(
          onBack: () {
            setState(() {
              _currentIndex = 4; // 設定タブに戻す
            });
          },
          onShowEvaluationItems: () {
            setState(() {
              _currentIndex = 6; // 評価項目画面表示
            });
          },
        );
      case 6:
        // Home 内の評価項目画面
        return EvaluationItemsScreen(
          onBack: () {
            setState(() {
              _currentIndex = 5; // 使い方ガイドへ戻す
            });
          },
        );
      default:
        // 不正なインデックスの場合は空ウィジェット
        return const SizedBox.shrink();
    }
  }

  /// 書籍選択・解除時に selectedBookIds を更新
  void _handleBookSelected(int bookId, bool isAdded) {
    setState(() {
      if (isAdded) {
        if (!selectedBookIds.contains(bookId)) selectedBookIds.add(bookId);
      } else {
        selectedBookIds.remove(bookId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body は現在のタブ/画面に応じて切替
      body: _getBody(_currentIndex),
      // 画面下部ナビゲーションバー
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex > 4 ? 4 : _currentIndex, // 5,6 は Home 内遷移用
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '書籍一覧'),
          BottomNavigationBarItem(icon: Icon(Icons.compare), label: '比較検討'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'おすすめ'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '使い方'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
