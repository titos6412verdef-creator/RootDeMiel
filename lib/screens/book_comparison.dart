import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/review_repository.dart';
import '../repositories/review_repository_impl.dart';
import '../widgets/book_radar_chart.dart';
import '../widgets/purchase_deviation_line.dart';
import '../widgets/user_provider.dart';
import '../db/database_helper.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class BookComparisonScreen extends StatefulWidget {
  final List<int> selectedBookIds;

  const BookComparisonScreen({super.key, required this.selectedBookIds});

  @override
  State<BookComparisonScreen> createState() => _BookComparisonScreenState();
}

class _BookComparisonScreenState extends State<BookComparisonScreen> {
  // --- レビューリポジトリのインスタンス ---
  final ReviewRepository _reviewRepo = ReviewRepositoryImpl();

  // --- 選択中の書籍IDリスト ---
  late List<int> _selectedBookIds;

  // --- 購入検討リストの書籍ID ---
  final List<int> _purchaseListBookIds = [];

  // --- 書籍情報リスト ---
  List<Map<String, dynamic>> _books = [];

  // --- ローディング状態フラグ ---
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedBookIds = List.from(widget.selectedBookIds);

    // 初期データの読み込み
    _loadBooks();
  }

  /// --- 書籍情報をロードして偏差値などを計算 ---
  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);

    // DB・APIから選択書籍の集計データを取得
    final data = await _reviewRepo.fetchBooksAggregatedByIds(_selectedBookIds);

    // 各書籍に偏差値平均やサムネイルURLを追加
    final booksWithDeviation = await Future.wait(
      data.map((b) async {
        final averages = await _reviewRepo.fetchBookAverages(b['book_id']);

        final lower = (averages['avg_lower_deviation'] ?? 30).toDouble();
        final upper = (averages['avg_upper_deviation'] ?? 70).toDouble();

        final thumbnailUrl =
            b['thumbnail_url'] is String &&
                (b['thumbnail_url'] as String).startsWith(RegExp(r'https?://'))
            ? b['thumbnail_url']
            : null;

        return {
          ...b,
          'avg_lower_deviation': lower,
          'avg_upper_deviation': upper,
          'thumbnail_url': thumbnailUrl,
        };
      }),
    );

    // 購入検討リスト用のサンプル書籍を作成
    final sampleBook = _calculateSampleBook(booksWithDeviation);

    setState(() {
      _books = [sampleBook, ...booksWithDeviation];
      _isLoading = false;
    });
  }

  /// --- 購入検討リストへの追加／削除 ---
  void _togglePurchase(int bookId) {
    setState(() {
      if (_purchaseListBookIds.contains(bookId)) {
        _purchaseListBookIds.remove(bookId);
      } else {
        _purchaseListBookIds.add(bookId);
      }

      // 購入検討リストのサンプル書籍を更新
      final booksWithDeviation = _books
          .where((b) => b['book_id'] != -1)
          .toList();
      final sampleBook = _calculateSampleBook(booksWithDeviation);
      _books = [sampleBook, ...booksWithDeviation];
    });
  }

  /// --- 購入検討リストを空にする ---
  void _clearPurchaseList() {
    setState(() {
      _purchaseListBookIds.clear();

      final booksWithDeviation = _books
          .where((b) => b['book_id'] != -1)
          .toList();
      final sampleBook = _calculateSampleBook(booksWithDeviation);
      _books = [sampleBook, ...booksWithDeviation];
    });
  }

  /// --- 購入検討リストのサンプル書籍（最大値・最小値集計）を作成 ---
  Map<String, dynamic> _calculateSampleBook(
    List<Map<String, dynamic>> booksWithDeviation,
  ) {
    final selectedBooks = booksWithDeviation
        .where((b) => _purchaseListBookIds.contains(b['book_id']))
        .toList();

    // 各指標の最大値／最小値を計算
    double maxTerminology = selectedBooks.isNotEmpty
        ? selectedBooks
              .map((b) => (b['avg_terminology_clarity'] ?? 0.0).toDouble())
              .reduce((a, b) => a > b ? a : b)
        : 0.0;
    double maxVariety = selectedBooks.isNotEmpty
        ? selectedBooks
              .map((b) => (b['avg_variety_of_problems'] ?? 0.0).toDouble())
              .reduce((a, b) => a > b ? a : b)
        : 0.0;
    double maxExercises = selectedBooks.isNotEmpty
        ? selectedBooks
              .map((b) => (b['avg_richness_of_exercises'] ?? 0.0).toDouble())
              .reduce((a, b) => a > b ? a : b)
        : 0.0;
    double maxPractice = selectedBooks.isNotEmpty
        ? selectedBooks
              .map((b) => (b['avg_richness_of_practice'] ?? 0.0).toDouble())
              .reduce((a, b) => a > b ? a : b)
        : 0.0;
    double minLowerDeviation = selectedBooks.isNotEmpty
        ? selectedBooks
              .map((b) => (b['avg_lower_deviation'] ?? 30.0).toDouble())
              .reduce((a, b) => a < b ? a : b)
        : 30.0;
    double maxUpperDeviation = selectedBooks.isNotEmpty
        ? selectedBooks
              .map((b) => (b['avg_upper_deviation'] ?? 70.0).toDouble())
              .reduce((a, b) => a > b ? a : b)
        : 70.0;

    return {
      'book_id': -1,
      'display_title': '購入検討リストの合計値',
      'avg_terminology_clarity': maxTerminology,
      'avg_variety_of_problems': maxVariety,
      'avg_richness_of_exercises': maxExercises,
      'avg_richness_of_practice': maxPractice,
      'avg_lower_deviation': minLowerDeviation,
      'avg_upper_deviation': maxUpperDeviation,
      'purchase_books': selectedBooks
          .map<Map<String, num>>(
            (b) => {
              'lower': (b['avg_lower_deviation'] ?? 30.0),
              'upper': (b['avg_upper_deviation'] ?? 70.0),
            },
          )
          .toList(),
    };
  }

  /// --- エラー表示用 ---
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// --- 購入検討リストをMy Picksに保存 ---
  Future<void> _savePurchaseListToMyPicks() async {
    try {
      // 選択チェック
      if (_purchaseListBookIds.isEmpty) {
        _showError('本を選択してください');
        return;
      }
      if (_purchaseListBookIds.length > 15) {
        _showError('15冊までしか保存できません');
        return;
      }

      // 現在ユーザー取得
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.currentUserId;

      // 同じ組み合わせが既存かチェック
      final existingRecSetId = await _findExistingRecSetId(
        currentUserId,
        _purchaseListBookIds,
      );
      if (existingRecSetId != null) {
        _showError('同じ組み合わせのセットはすでに保存されています');
        return;
      }

      // 新しいレコメンドセット作成
      final recSetId = await _getOrCreateRecSetId();

      // UserBookSets に挿入
      await _insertUserBookSets(
        userId: currentUserId,
        recSetId: recSetId,
        bookIds: List.from(_purchaseListBookIds),
      );

      // 非同期後に context を使う前に mounted をチェック
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('マイリストに保存しました')));
    } catch (e) {
      _showError('保存に失敗しました: $e');
    }
  }

  /// --- 既存の同一セットがあるかチェック ---
  Future<int?> _findExistingRecSetId(String userId, List<int> bookIds) async {
    final db = await DatabaseHelper.instance.database;

    // ユーザーの全セットを取得
    final sets = await db.rawQuery(
      'SELECT rec_set_id FROM UserBookSets WHERE user_id = ? GROUP BY rec_set_id',
      [userId],
    );

    // 各セットの書籍IDを比較
    for (final set in sets) {
      final recSetId = set['rec_set_id'] as int;
      final items = await db.query(
        'UserBookSets',
        columns: ['book_id'],
        where: 'rec_set_id = ? AND user_id = ?',
        whereArgs: [recSetId, userId],
      );

      final existingIds = items.map((e) => e['book_id'] as int).toList()
        ..sort();
      final newIds = List<int>.from(bookIds)..sort();

      if (listEquals(existingIds, newIds)) return recSetId;
    }
    return null;
  }

  /// --- 新しいRecommendationSetを作成 ---
  Future<int> _getOrCreateRecSetId() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    final recSetId = await db.insert('BookSetTemplates', {
      'like_count': 0,
      'created_at': now,
      'updated_at': now,
    });
    debugPrint('Created RecommendationSet with rec_set_id: $recSetId');
    return recSetId;
  }

  /// --- UserBookSets に書籍セットを挿入 ---
  Future<void> _insertUserBookSets({
    required String userId,
    required int recSetId,
    required List<int> bookIds,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final sortedIds = List<int>.from(bookIds)..sort();
    final joined = sortedIds.join(',');
    final bookHash = sha256.convert(utf8.encode(joined)).toString();

    // 最初の書籍からsubjectを取得
    final firstBook = await db.query(
      'Books',
      columns: ['subject'],
      where: 'book_id = ?',
      whereArgs: [bookIds.first],
    );
    final subjectToParent = {
      '現代文': '国語',
      '古文': '国語',
      '漢文': '国語',
      '歴史総合': '歴史',
      '日本史探究': '歴史',
      '世界史探究': '歴史',
      '地理総合': '地理',
      '地理探究': '地理',
      '倫理': '公共',
      '政治・経済': '公共',
      '英単語・熟語': '英語',
      'リスニング': '英語',
      '英文法': '英語',
      '英文解釈': '英語',
      '長文読解': '英語',
      '英語総合': '英語',
    };

    String? subject;
    if (firstBook.isNotEmpty) {
      final rawSubject = firstBook.first['subject'] as String?;
      subject = subjectToParent[rawSubject] ?? rawSubject;
    }

    // 既存セットの最大 set_index を取得
    final maxIndexResult = await db.rawQuery(
      'SELECT MAX(set_index) as max_index FROM UserBookSets WHERE user_id = ?',
      [userId],
    );
    final lastIndex = maxIndexResult.first['max_index'] as int? ?? 0;
    final newSetIndex = lastIndex + 1;

    // 各書籍をUserBookSetsに挿入
    int itemOrder = 1;
    for (final bookId in bookIds) {
      if (itemOrder < 1 || itemOrder > 15) {
        throw Exception('item_order は 1〜15 の範囲である必要があります: $itemOrder');
      }

      final item = {
        'rec_set_id': recSetId,
        'user_id': userId,
        'set_index': newSetIndex,
        'item_order': itemOrder++,
        'book_id': bookId,
        'note': '',
        'title': '新しいMy pick ($newSetIndex)',
        'description': '',
        'is_public': 0,
        'cover_book_id': bookIds.first,
        'color_tag': '#000',
        'added_at': now.toIso8601String(),
        'last_used_at': now.toIso8601String(),
        'subject': subject,
        'book_hash': bookHash,
      };

      await db.insert('UserBookSets', item);
    }
    debugPrint('✅ UserBookSets に book_hash($bookHash) を保存しました');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final thumbnailWidth = screenWidth * 0.4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('書籍比較'),
        actions: [
          // 購入検討リストを空にするボタン
          if (_purchaseListBookIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'リストを空にする',
              onPressed: _clearPurchaseList,
            ),
          // My Picksに保存ボタン
          if (_purchaseListBookIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'My Picksに保存',
              onPressed: _savePurchaseListToMyPicks,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // -------------------------
                  // 購入検討リストのサンプルチャート
                  // -------------------------
                  if (_books.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: Colors.grey[100], // 行全体の背景色
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // タイトル
                          Text(
                            '${_books[0]['display_title'] ?? '購入検討リスト'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color.fromARGB(255, 22, 34, 100),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // レーダーチャート
                          SizedBox(
                            height: 180,
                            child: BookRadarChart(
                              terminology:
                                  (_books[0]['avg_terminology_clarity'] ?? 0)
                                      .toDouble(),
                              variety:
                                  (_books[0]['avg_variety_of_problems'] ?? 0)
                                      .toDouble(),
                              exercises:
                                  (_books[0]['avg_richness_of_exercises'] ?? 0)
                                      .toDouble(),
                              practice:
                                  (_books[0]['avg_richness_of_practice'] ?? 0)
                                      .toDouble(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 偏差値ライン
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final lineWidth = constraints.maxWidth * 0.7;
                              final samplePurchaseBooks =
                                  (_books[0]['purchase_books'] as List? ?? [])
                                      .map<Map<String, num>>(
                                        (e) => {
                                          'lower': (e['lower'] ?? 30.0),
                                          'upper': (e['upper'] ?? 70.0),
                                        },
                                      )
                                      .toList();

                              return Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  height: 60,
                                  width: lineWidth,
                                  child: PurchaseDeviationLine(
                                    purchaseBooks: samplePurchaseBooks,
                                    lineWidth: lineWidth,
                                    showOnlyMinMaxLabels: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                  // -------------------------
                  // 個別書籍リスト
                  // -------------------------
                  Expanded(
                    child: ListView.builder(
                      itemCount: _books.length - 1,
                      itemBuilder: (context, index) {
                        final item = _books[index + 1];

                        // --- サムネイルの設定 ---
                        Widget bookThumbnail;
                        final thumb = item['thumbnail_url'] as String?;
                        if (thumb != null && thumb.isNotEmpty) {
                          bookThumbnail = Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                                  'assets/images/no-image.jpg',
                                  fit: BoxFit.cover,
                                ),
                          );
                        } else {
                          bookThumbnail = Image.asset(
                            'assets/images/no-image.jpg',
                            fit: BoxFit.cover,
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // タイトル表示
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12.0,
                                  right: 12.0,
                                ),
                                child: Text(
                                  item['display_title'] ?? 'タイトルなし',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color.fromARGB(255, 22, 34, 100),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 本体：左（サムネイル＋購入ボタン）右（チャート＋偏差値ライン）
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 左側：サムネイル＋ボタン (30%)
                                  Flexible(
                                    flex: 4,
                                    child: Column(
                                      children: [
                                        Container(
                                          width: thumbnailWidth,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 70 / 100,
                                            child: bookThumbnail,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () =>
                                              _togglePurchase(item['book_id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                _purchaseListBookIds.contains(
                                                  item['book_id'],
                                                )
                                                ? Colors.orange
                                                : Colors.grey[300],
                                          ),
                                          child: Text(
                                            _purchaseListBookIds.contains(
                                                  item['book_id'],
                                                )
                                                ? '購入検討中'
                                                : '購入検討',
                                            style: TextStyle(
                                              color:
                                                  _purchaseListBookIds.contains(
                                                    item['book_id'],
                                                  )
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 右側：チャート＋偏差値ライン (70%)
                                  Flexible(
                                    flex: 7,
                                    child: Card(
                                      margin: EdgeInsets.zero,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(16),
                                          bottomRight: Radius.circular(16),
                                        ),
                                      ),
                                      elevation: 4,
                                      shadowColor: Colors.black.withAlpha(
                                        (0.1 * 255).toInt(),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // レーダーチャート
                                            SizedBox(
                                              height: 180,
                                              child: BookRadarChart(
                                                terminology:
                                                    (item['avg_terminology_clarity'] ??
                                                            0)
                                                        .toDouble(),
                                                variety:
                                                    (item['avg_variety_of_problems'] ??
                                                            0)
                                                        .toDouble(),
                                                exercises:
                                                    (item['avg_richness_of_exercises'] ??
                                                            0)
                                                        .toDouble(),
                                                practice:
                                                    (item['avg_richness_of_practice'] ??
                                                            0)
                                                        .toDouble(),
                                                showLabels: false, // ラベル表示切替
                                              ),
                                            ),
                                            // 偏差値ライン
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                final lineWidth =
                                                    constraints.maxWidth * 0.8;
                                                final purchaseBooks = [
                                                  {
                                                    'lower':
                                                        (item['avg_lower_deviation'] ??
                                                                30.0)
                                                            as num,
                                                    'upper':
                                                        (item['avg_upper_deviation'] ??
                                                                70.0)
                                                            as num,
                                                  },
                                                ];

                                                return Center(
                                                  child: SizedBox(
                                                    height: 60,
                                                    width: lineWidth,
                                                    child:
                                                        PurchaseDeviationLine(
                                                          purchaseBooks:
                                                              purchaseBooks,
                                                          lineWidth: lineWidth,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
