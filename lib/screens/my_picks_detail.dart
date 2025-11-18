// lib/screens/my_picks_detail.dart
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../widgets/book_radar_chart.dart';
import '../widgets/purchase_deviation_line.dart';
import '../repositories/review_repository.dart';
import '../repositories/review_repository_impl.dart';
import 'package:provider/provider.dart';
import '../widgets/user_provider.dart';

class MyPicksDetailScreen extends StatefulWidget {
  final int recSetId;
  final String title;

  const MyPicksDetailScreen({
    super.key,
    required this.recSetId,
    required this.title,
  });

  @override
  State<MyPicksDetailScreen> createState() => _MyPicksDetailScreenState();
}

class _MyPicksDetailScreenState extends State<MyPicksDetailScreen> {
  final ReviewRepository _reviewRepo = ReviewRepositoryImpl();

  Map<String, dynamic>? _setInfo;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isOwner = false;
  String? _creatorUsername;
  bool _liked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    // 初回ロード：セット情報とアイテム情報を取得
    _loadSetDetails();
  }

  /// セット情報・アイテム情報を DB から取得
  Future<void> _loadSetDetails() async {
    setState(() => _isLoading = true);

    final db = await DatabaseHelper.instance.database;

    // UserBookSets から recSetId に紐づくアイテム一覧を取得
    final itemResults = await db.query(
      'UserBookSets',
      columns: [
        'set_id',
        'book_id',
        'item_order',
        'cover_book_id',
        'title',
        'description',
        'user_id',
        'book_hash',
      ],
      where: 'rec_set_id = ?',
      whereArgs: [widget.recSetId],
      orderBy: 'item_order ASC',
    );

    // アイテムがない場合は初期状態にリセット
    if (itemResults.isEmpty) {
      if (!mounted) return;
      setState(() {
        _setInfo = null;
        _items = [];
        _isLoading = false;
        _isOwner = false;
        _creatorUsername = null;
        _likeCount = 0;
        _liked = false;
      });
      return;
    }

    final firstItem = itemResults.first;
    final creatorId = firstItem['user_id'] as String?;

    // currentUserId は async 前に取得
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.currentUserId;
    // 作成者ユーザー名取得
    if (creatorId != null) {
      final userRows = await db.query(
        'Users',
        columns: ['username'],
        where: 'user_id = ?',
        whereArgs: [creatorId],
      );
      if (!mounted) return;
      _creatorUsername = userRows.isNotEmpty
          ? userRows.first['username'] as String?
          : null;
    }

    // セット情報と所有者判定を設定
    if (!mounted) return;
    _setInfo = {'description': firstItem['description'] ?? ''};
    _isOwner = creatorId != null && creatorId == currentUserId;

    // いいね状態を取得
    final likedRows = await db.query(
      'BookSetLikes',
      where: 'rec_set_id = ? AND user_id = ?',
      whereArgs: [widget.recSetId, currentUserId],
    );
    if (!mounted) return;
    _liked = likedRows.isNotEmpty;

    // いいね数を取得
    final countRows = await db.query(
      'BookSetLikes',
      columns: ['user_id'],
      where: 'rec_set_id = ?',
      whereArgs: [widget.recSetId],
    );
    if (!mounted) return;
    _likeCount = countRows.length;

    // アイテムに書籍情報とレビュー平均値を付与
    final itemsWithBooks = await Future.wait(
      itemResults.map((item) async {
        final bookId = item['book_id'] as int;
        final bookRow = (await db.query(
          'Books',
          columns: ['display_title', 'thumbnail_url'],
          where: 'book_id = ?',
          whereArgs: [bookId],
        )).first;

        final averages = await _reviewRepo.fetchBookAverages(bookId);

        return {
          ...item,
          'book_title': bookRow['display_title'],
          'thumbnail_url': bookRow['thumbnail_url'],
          'avg_terminology_clarity':
              (averages['avg_terminology_clarity'] ?? 0.0).toDouble(),
          'avg_variety_of_problems':
              (averages['avg_variety_of_problems'] ?? 0.0).toDouble(),
          'avg_richness_of_exercises':
              (averages['avg_richness_of_exercises'] ?? 0.0).toDouble(),
          'avg_richness_of_practice':
              (averages['avg_richness_of_practice'] ?? 0.0).toDouble(),
          'avg_lower_deviation': (averages['avg_lower_deviation'] ?? 30.0)
              .toDouble(),
          'avg_upper_deviation': (averages['avg_upper_deviation'] ?? 70.0)
              .toDouble(),
        };
      }),
    );

    if (!mounted) return;
    setState(() {
      _items = itemsWithBooks;
      _isLoading = false;
    });
  }

  /// いいねの切り替え処理
  Future<void> _toggleLike() async {
    final db = await DatabaseHelper.instance.database;
    final currentUserId = context.read<UserProvider>().currentUserId;

    await db.transaction((txn) async {
      if (_liked) {
        // 既存のいいねを削除
        await txn.delete(
          'BookSetLikes',
          where: 'rec_set_id = ? AND user_id = ?',
          whereArgs: [widget.recSetId, currentUserId],
        );
        if (!mounted) return;
        setState(() {
          _liked = false;
          _likeCount--;
        });
      } else {
        // いいねを追加
        await txn.insert('BookSetLikes', {
          'rec_set_id': widget.recSetId,
          'user_id': currentUserId,
        });
        if (!mounted) return;
        setState(() {
          _liked = true;
          _likeCount++;
        });
      }
    });
  }

  /// 各レビュー平均値からサンプル値を計算
  Map<String, double> _calculateSampleValues(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      // アイテムが空の場合はすべて 0 を返す
      return {'terminology': 0, 'variety': 0, 'exercises': 0, 'practice': 0};
    }

    return {
      'terminology': items
          .map((b) => (b['avg_terminology_clarity'] ?? 0.0).toDouble())
          .reduce((a, b) => a > b ? a : b),
      'variety': items
          .map((b) => (b['avg_variety_of_problems'] ?? 0.0).toDouble())
          .reduce((a, b) => a > b ? a : b),
      'exercises': items
          .map((b) => (b['avg_richness_of_exercises'] ?? 0.0).toDouble())
          .reduce((a, b) => a > b ? a : b),
      'practice': items
          .map((b) => (b['avg_richness_of_practice'] ?? 0.0).toDouble())
          .reduce((a, b) => a > b ? a : b),
    };
  }

  /// 購入範囲用のデータ構築
  List<Map<String, num>> _buildPurchaseBooks(List<Map<String, dynamic>> items) {
    return items
        .map(
          (b) => <String, num>{
            'lower': (b['avg_lower_deviation'] ?? 30.0) as num,
            'upper': (b['avg_upper_deviation'] ?? 70.0) as num,
          },
        )
        .toList();
  }

  /// アイテム順序の入れ替え処理
  Future<void> _swapItemOrder(int index, bool moveUp) async {
    if (_items.isEmpty) return;
    final swapIndex = moveUp ? index - 1 : index + 1;
    if (swapIndex < 0 || swapIndex >= _items.length) return;

    final db = await DatabaseHelper.instance.database;

    final currentItem = _items[index];
    final swapItem = _items[swapIndex];

    final currentOrder = currentItem['item_order'] as int;
    final swapOrder = swapItem['item_order'] as int;

    // DB上で一時的に -1 にして順序を入れ替え
    await db.transaction((txn) async {
      await txn.update(
        'UserBookSets',
        {'item_order': -1},
        where: 'set_id = ?',
        whereArgs: [currentItem['set_id']],
      );
      await txn.update(
        'UserBookSets',
        {'item_order': currentOrder},
        where: 'set_id = ?',
        whereArgs: [swapItem['set_id']],
      );
      await txn.update(
        'UserBookSets',
        {'item_order': swapOrder},
        where: 'set_id = ?',
        whereArgs: [currentItem['set_id']],
      );
    });

    // ローカルリストも更新
    final newItems = List<Map<String, dynamic>>.from(_items);
    newItems[index] = swapItem..['item_order'] = currentOrder;
    newItems[swapIndex] = currentItem..['item_order'] = swapOrder;

    if (!mounted) return;
    setState(() => _items = newItems);
  }

  /// セット情報（タイトル・コメント）の編集
  Future<void> _editSetField(String field, String currentValue) async {
    if (!_isOwner) return;
    final controller = TextEditingController(text: currentValue);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 編集ヘッダー
              Row(
                children: [
                  Expanded(
                    child: Text(
                      field == 'title' ? 'タイトルを編集' : 'コメントを編集',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 入力フィールド
              TextField(
                controller: controller,
                maxLines: field == 'description' ? 10 : 1,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              // キャンセル・保存ボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final result = controller.text.trim();
                      if (result.isEmpty) return;

                      final db = await DatabaseHelper.instance.database;
                      if (field == 'title') {
                        await db.update(
                          'BookSetTemplates',
                          {'title': result},
                          where: 'rec_set_id = ?',
                          whereArgs: [widget.recSetId],
                        );
                      } else {
                        await db.update(
                          'UserBookSets',
                          {'description': result},
                          where: 'set_id = ?',
                          whereArgs: [_items.first['set_id']],
                        );
                      }

                      await _loadSetDetails();

                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// セットコメントのプレビュー
  Widget _buildCommentPreview(String comment) {
    final lines = comment.split('\n');
    final displayLines = lines.length > 5 ? lines.sublist(0, 5) : lines;

    return GestureDetector(
      onTap: () => _showFullComment(comment),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'このセレクションの解説',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isOwner)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _editSetField('description', comment),
                  ),
              ],
            ),
            const Divider(),
            ...displayLines.map(
              (line) => Text(
                line.length > 20 ? line.substring(0, 20) : line,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (lines.length > 5)
              const Text('……', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  /// セットコメントの全文表示
  void _showFullComment(String comment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final lines = comment.split('\n');
        final displayLines = lines.length > 40 ? lines.sublist(0, 40) : lines;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'コメント全文',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                  if (_isOwner)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        if (!mounted) return;
                        Navigator.pop(context);
                        _editSetField('description', comment);
                      },
                    ),
                ],
              ),
              const Divider(),
              ...displayLines.map(
                (line) => Text(
                  line.length > 20 ? line.substring(0, 20) : line,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (lines.length > 40)
                const Text('……', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sampleValues = _calculateSampleValues(_items);
    final purchaseBooks = _buildPurchaseBooks(_items);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'タイトルを編集',
              onPressed: () => _editSetField('title', widget.title),
            ),
          if (!_isOwner)
            Row(
              children: [
                Text('$_likeCount', style: const TextStyle(fontSize: 16)),
                IconButton(
                  icon: Icon(
                    _liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked ? Colors.red : Colors.grey,
                  ),
                  onPressed: _toggleLike,
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 作成者表示
                if (_creatorUsername != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      '作成者: $_creatorUsername',
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // レーダーチャートと購入偏差ライン
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      BookRadarChart(
                        terminology: sampleValues['terminology']!,
                        variety: sampleValues['variety']!,
                        exercises: sampleValues['exercises']!,
                        practice: sampleValues['practice']!,
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

                // アイテム一覧
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
                            // サムネイル表示
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
                            // 本タイトル表示
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['book_title'] ?? 'タイトルなし',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              ),
                            ),
                            // 所有者向け上下移動ボタン
                            if (_isOwner)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    iconSize: 28,
                                    icon: const Icon(Icons.arrow_upward),
                                    onPressed: (item['item_order'] as int) == 1
                                        ? null
                                        : () => _swapItemOrder(index, true),
                                    tooltip: '上に移動',
                                  ),
                                  IconButton(
                                    iconSize: 28,
                                    icon: const Icon(Icons.arrow_downward),
                                    onPressed:
                                        (item['item_order'] as int) ==
                                            _items.length
                                        ? null
                                        : () => _swapItemOrder(index, false),
                                    tooltip: '下に移動',
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // コメントプレビュー
                if (_setInfo?['description'] != null &&
                    _setInfo!['description'].isNotEmpty)
                  _buildCommentPreview(_setInfo!['description']!),
              ],
            ),
    );
  }
}
