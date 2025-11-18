// lib/screens/hash_book.dart

import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../widgets/book_radar_chart.dart';
import '../widgets/purchase_deviation_line.dart';
import '../repositories/review_repository.dart';
import '../repositories/review_repository_impl.dart';

// ハッシュで指定された書籍セットを表示する画面
class HashBookScreen extends StatefulWidget {
  final String bookHash; // 表示する書籍セットのハッシュ
  final String title; // AppBarに表示するタイトル

  const HashBookScreen({
    super.key,
    required this.bookHash,
    required this.title,
  });

  @override
  State<HashBookScreen> createState() => _HashBookScreenState();
}

class _HashBookScreenState extends State<HashBookScreen> {
  final ReviewRepository _reviewRepo =
      ReviewRepositoryImpl(); // レビュー関連のデータ取得用リポジトリ

  List<Map<String, dynamic>> _items = []; // 書籍セット内のアイテム情報
  bool _isLoading = true; // ローディング状態の管理

  @override
  void initState() {
    super.initState();
    _loadHashSetDetails(); // 初期表示時にデータ読み込み
  }

  // bookHashに紐づく書籍セットの詳細をDBから取得
  Future<void> _loadHashSetDetails() async {
    setState(() => _isLoading = true); // ローディング開始

    final db = await DatabaseHelper.instance.database;

    // UserBookSetsテーブルから該当ハッシュの書籍構成を取得
    final results = await db.query(
      'UserBookSets',
      columns: ['book_id', 'item_order', 'cover_book_id', 'title', 'book_hash'],
      where: 'book_hash = ?',
      whereArgs: [widget.bookHash],
      orderBy: 'item_order ASC',
    );

    if (results.isEmpty) {
      // データがなければ空リストをセットしてローディング終了
      setState(() {
        _items = [];
        _isLoading = false;
      });
      return;
    }

    final itemsWithBooks = <Map<String, dynamic>>[];
    final addedBookIds = <int>{}; // 重複排除用のSet

    for (var item in results) {
      final bookId = item['book_id'] as int;
      if (addedBookIds.contains(bookId)) continue; // 重複するbookIdはスキップ
      addedBookIds.add(bookId);

      // BooksテーブルからタイトルとサムネイルURLを取得
      final bookRow = (await db.query(
        'Books',
        columns: ['display_title', 'thumbnail_url'],
        where: 'book_id = ?',
        whereArgs: [bookId],
      )).first;

      // 書籍ごとのレビュー平均値を取得
      final averages = await _reviewRepo.fetchBookAverages(bookId);

      // アイテム情報とレビュー平均をマージしてリストに追加
      itemsWithBooks.add({
        ...item,
        'book_title': bookRow['display_title'],
        'thumbnail_url': bookRow['thumbnail_url'],
        'avg_terminology_clarity': (averages['avg_terminology_clarity'] ?? 0.0)
            .toDouble(),
        'avg_variety_of_problems': (averages['avg_variety_of_problems'] ?? 0.0)
            .toDouble(),
        'avg_richness_of_exercises':
            (averages['avg_richness_of_exercises'] ?? 0.0).toDouble(),
        'avg_richness_of_practice':
            (averages['avg_richness_of_practice'] ?? 0.0).toDouble(),
        'avg_lower_deviation': (averages['avg_lower_deviation'] ?? 30.0)
            .toDouble(),
        'avg_upper_deviation': (averages['avg_upper_deviation'] ?? 70.0)
            .toDouble(),
      });
    }

    // 取得結果を状態に反映
    setState(() {
      _items = itemsWithBooks;
      _isLoading = false;
    });
  }

  // レーダーチャートに表示する値を計算（書籍セット内で最大値を採用）
  Map<String, double> _calculateRadarValues(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return {'terminology': 0, 'variety': 0, 'exercises': 0, 'practice': 0};
    }

    return {
      'terminology': items
          .map((b) => b['avg_terminology_clarity'] as double)
          .reduce((a, b) => a > b ? a : b),
      'variety': items
          .map((b) => b['avg_variety_of_problems'] as double)
          .reduce((a, b) => a > b ? a : b),
      'exercises': items
          .map((b) => b['avg_richness_of_exercises'] as double)
          .reduce((a, b) => a > b ? a : b),
      'practice': items
          .map((b) => b['avg_richness_of_practice'] as double)
          .reduce((a, b) => a > b ? a : b),
    };
  }

  // 購入偏差値ライン用の値リストを作成
  List<Map<String, num>> _buildPurchaseRange(List<Map<String, dynamic>> items) {
    return items
        .map<Map<String, num>>(
          (b) => {
            'lower': b['avg_lower_deviation'] as num,
            'upper': b['avg_upper_deviation'] as num,
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final radarValues = _calculateRadarValues(_items); // レーダーチャート用値
    final purchaseBooks = _buildPurchaseRange(_items); // 偏差値ライン用値

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          // データ読み込み中はインジケータを表示
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // レーダーチャートと購入偏差値ライン表示
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      BookRadarChart(
                        terminology: radarValues['terminology']!,
                        variety: radarValues['variety']!,
                        exercises: radarValues['exercises']!,
                        practice: radarValues['practice']!,
                      ),
                      const SizedBox(height: 16),
                      PurchaseDeviationLine(
                        purchaseBooks: purchaseBooks,
                        lineWidth: MediaQuery.of(context).size.width * 0.8,
                        showOnlyMinMaxLabels: true,
                      ),
                    ],
                  ),
                ),

                // 書籍リスト表示
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final thumbnailUrl = item['thumbnail_url']?.toString();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 書籍サムネイル表示
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  (thumbnailUrl != null &&
                                      thumbnailUrl.isNotEmpty)
                                  ? Image.network(
                                      thumbnailUrl,
                                      width: 70,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      'assets/images/no-image.jpg',
                                      width: 70,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // 書籍タイトル表示
                            Expanded(
                              child: Text(
                                item['book_title'] ?? 'タイトルなし',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
