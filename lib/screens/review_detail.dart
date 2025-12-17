import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:provider/provider.dart';
import '../db/database_helper.dart';
import '../widgets/average_score.dart';
import '../repositories/review_repository.dart';
import '../repositories/review_repository_impl.dart';
import 'review_add.dart';
import '../widgets/user_provider.dart'; // Providerからユーザー情報取得

/// 書籍詳細レビュー画面
/// 指定書籍のレビュー一覧・平均スコア・レビュー追加ボタンを表示
class BookReviewDetailScreen extends StatefulWidget {
  final int bookId; // 表示する書籍ID
  final String bookTitle; // 書籍タイトル

  const BookReviewDetailScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<BookReviewDetailScreen> createState() => _BookReviewDetailScreenState();
}

class _BookReviewDetailScreenState extends State<BookReviewDetailScreen> {
  static const int reviewsPerPage = 10; // 1ページあたりのレビュー件数
  int _currentPage = 0; // 現在のページ
  late final ReviewRepository _reviewRepository =
      ReviewRepositoryImpl(); // レビュー操作用リポジトリ
  late String _currentUserId; // 現在ログイン中のユーザーID

  Set<String> _likedReviewIds = {}; // ユーザーがいいねしたレビューID
  bool _showOnlyWithComments = false; // コメント有りレビューのみ表示フラグ

  Map<String, dynamic>? _bookData; // 書籍情報
  List<Map<String, dynamic>> _reviews = []; // 現在ページのレビューリスト
  Map<String, dynamic> _averages = {}; // 平均スコア
  int _totalReviews = 0; // 総レビュー数
  bool _isLoading = true; // データ読み込み中フラグ
  String? _errorMessage; // エラーメッセージ

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ProviderからユーザーIDを取得
    _currentUserId = context.read<UserProvider>().userId;
    // 初期データ読み込み
    _initData();
    // いいね済みレビューIDを取得
    _initLikedReviewIds();
  }

  /// 現在ユーザーがいいねしたレビューIDを取得
  Future<void> _initLikedReviewIds() async {
    final likedIds = await _reviewRepository.getLikedReviewIds(_currentUserId);
    setState(() {
      _likedReviewIds = likedIds;
    });
  }

  /// 書籍情報とレビューを取得
  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _fetchBookDetailAndReviews();
      setState(() {
        _bookData = data['book'];
        _reviews = data['reviews'];
        _totalReviews = data['totalReviews'];
        _averages = data['averages'];
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// DBから書籍情報・レビュー・平均スコアを取得
  Future<Map<String, dynamic>> _fetchBookDetailAndReviews() async {
    final db = await DatabaseHelper.instance.database;

    // 書籍情報取得
    final bookList = await db.query(
      'Books',
      columns: ['book_id', 'display_title', 'thumbnail_url'],
      where: 'book_id = ?',
      whereArgs: [widget.bookId],
    );
    if (bookList.isEmpty) throw Exception('書籍が見つかりません');
    final book = bookList.first;

    // 総レビュー件数取得
    final reviewCountResult = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM Reviews WHERE book_id = ?',
      [widget.bookId],
    );
    final totalReviews = Sqflite.firstIntValue(reviewCountResult) ?? 0;

    // レビュー一覧取得（1ページ分）
    final reviewsRaw = await db.rawQuery(
      '''
      SELECT r.*, u.username AS user_name,
        (SELECT COUNT(*) FROM Likes l WHERE l.review_id = r.review_id) AS like_count
      FROM Reviews r
      LEFT JOIN Users u ON r.user_id = u.user_id
      WHERE r.book_id = ?
      ORDER BY r.created_at DESC
      LIMIT ? OFFSET ?
      ''',
      [widget.bookId, reviewsPerPage, _currentPage * reviewsPerPage],
    );

    final reviews = reviewsRaw
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    // 各項目の平均値計算
    final avgResult = await db.rawQuery(
      '''
      SELECT 
        AVG(score) AS avg_score,
        AVG(terminology_clarity) AS avg_terminology_clarity,
        AVG(visual_density) AS avg_visual_density,
        AVG(variety_of_problems) AS avg_variety_of_problems,
        AVG(richness_of_exercises) AS avg_richness_of_exercises,
        AVG(richness_of_practice) AS avg_richness_of_practice,
        AVG(recommended_lower_dev) AS avg_lower_deviation,
        AVG(recommended_upper_dev) AS avg_upper_deviation
      FROM Reviews
      WHERE book_id = ?
      ''',
      [widget.bookId],
    );

    final averages = (avgResult.isNotEmpty && avgResult.first.isNotEmpty)
        ? avgResult.first
        : <String, dynamic>{};

    return {
      'book': book,
      'reviews': reviews,
      'totalReviews': totalReviews,
      'averages': averages,
    };
  }

  /// 次ページ表示
  void _nextPage() async {
    _currentPage++;
    await _initData();
  }

  /// 前ページ表示
  void _previousPage() async {
    if (_currentPage > 0) {
      _currentPage--;
      await _initData();
    }
  }

  /// レビュー追加後に最初のページを再読み込み
  void _refreshAfterReview() async {
    _currentPage = 0;
    await _initData();
  }

  /// 日付文字列を yyyy/MM/dd に整形
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // 背景色
          Container(color: const Color(0xFF34170B)),
          // 背景画像
          FractionalTranslation(
            translation: const Offset(0, 0.015),
            child: Image.asset(
              'assets/images/lib.jpg',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
          // 戻るボタン
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('一覧に戻る'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  backgroundColor: Colors.brown[800]?.withAlpha(
                    (0.8 * 255).toInt(),
                  ),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator()) // 読み込み中
                : _errorMessage != null
                ? Center(child: Text('エラー: $_errorMessage')) // エラー表示
                : _bookData == null
                ? const Center(child: Text('データがありません')) // データ無し
                : Padding(
                    padding: EdgeInsets.only(
                      top: screenHeight * 0.084,
                      left: 12,
                      right: 12,
                      bottom: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 書籍情報＋平均スコア
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBookImageArea(
                              (_bookData!['thumbnail_url'] as String?)
                                          ?.isNotEmpty ==
                                      true
                                  ? _bookData!['thumbnail_url']
                                  : null,
                            ),
                            SizedBox(width: screenWidth * 0.09),
                            Container(
                              width: screenWidth * 0.4,
                              margin: const EdgeInsets.only(top: 0, left: 1),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Card(
                                    color: Colors.white.withAlpha(
                                      (0.6 * 255).toInt(),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Review Score',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 0),
                                          AverageReviewCard(
                                            averages: _averages, // 平均スコア表示
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white70),
                        // フィルター＆レビュー件数
                        Padding(
                          padding: EdgeInsets.only(top: 0.0, left: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🕒 レビュー (${_currentPage * reviewsPerPage + 1}～${(_currentPage * reviewsPerPage) + _reviews.length} / $_totalReviews 件)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 15),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _showOnlyWithComments,
                                    onChanged: (bool? val) {
                                      setState(() {
                                        _showOnlyWithComments = val ?? false;
                                        _currentPage = 0;
                                      });
                                      _initData(); // フィルター更新
                                    },
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'コメントがあるものだけ表示',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // レビューリスト
                        Expanded(
                          child: _reviews.isEmpty
                              ? const Center(
                                  child: Text(
                                    'レビューがまだありません',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _reviews.length,
                                  itemBuilder: (context, index) {
                                    final review = _reviews[index];
                                    final userName =
                                        (review['user_name'] as String?)
                                                ?.isNotEmpty ==
                                            true
                                        ? review['user_name']
                                        : '匿名ラッコ';
                                    final reviewNumber =
                                        _totalReviews -
                                        (_currentPage * reviewsPerPage + index);
                                    final reviewId = review['review_id']
                                        .toString();

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(
                                            (0.1 * 255).toInt(),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // レビュー番号
                                            Text(
                                              'レビュー $reviewNumber',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white70,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // コメント表示
                                            if ((review['comment'] as String?)
                                                    ?.isNotEmpty ==
                                                true)
                                              Text(
                                                '${review['comment']}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            // スコアやいいね
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (review['score'] != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 12,
                                                          ),
                                                      child: Text(
                                                        '★: ${review['score']}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    ),
                                                  if (review['terminology_clarity'] !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 12,
                                                          ),
                                                      child: Text(
                                                        '🧠: ${review['terminology_clarity']}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    ),
                                                  if (review['visual_density'] !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 12,
                                                          ),
                                                      child: Text(
                                                        '📊: ${review['visual_density']}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    ),
                                                  if (review['variety_of_problems'] !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 12,
                                                          ),
                                                      child: Text(
                                                        '📚: ${review['variety_of_problems']}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    ),
                                                  if (review['richness_of_exercises'] !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 12,
                                                          ),
                                                      child: Text(
                                                        '📄: ${review['richness_of_exercises']}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    ),
                                                  if (review['richness_of_practice'] !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 12,
                                                          ),
                                                      child: Text(
                                                        '📝: ${review['richness_of_practice']}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    ),
                                                  // いいねボタン
                                                  IconButton(
                                                    icon: Icon(
                                                      _likedReviewIds.contains(
                                                            reviewId,
                                                          )
                                                          ? Icons.thumb_up
                                                          : Icons
                                                                .thumb_up_outlined,
                                                      color: Colors.white70,
                                                    ),
                                                    onPressed: () async {
                                                      // いいねON/OFF切替
                                                      await _reviewRepository
                                                          .toggleLike(
                                                            reviewId,
                                                            _currentUserId,
                                                          );
                                                      final db =
                                                          await DatabaseHelper
                                                              .instance
                                                              .database;
                                                      final likeCountResult =
                                                          await db.rawQuery(
                                                            'SELECT COUNT(*) AS like_count FROM Likes WHERE review_id = ?',
                                                            [reviewId],
                                                          );
                                                      final likeCount =
                                                          Sqflite.firstIntValue(
                                                            likeCountResult,
                                                          ) ??
                                                          0;

                                                      setState(() {
                                                        if (_likedReviewIds
                                                            .contains(
                                                              reviewId,
                                                            )) {
                                                          _likedReviewIds
                                                              .remove(reviewId);
                                                        } else {
                                                          _likedReviewIds.add(
                                                            reviewId,
                                                          );
                                                        }
                                                        review['like_count'] =
                                                            likeCount;
                                                      });
                                                    },
                                                  ),
                                                  Text(
                                                    '${review['like_count'] ?? 0}',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            // 作成者と投稿日
                                            Text(
                                              'by $userName (${_formatDate(review['created_at'])})',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        // ページ切替ボタン
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: _currentPage > 0
                                  ? _previousPage
                                  : null,
                              child: const Text('前へ'),
                            ),
                            ElevatedButton(
                              onPressed:
                                  ((_currentPage + 1) * reviewsPerPage <
                                      _totalReviews)
                                  ? _nextPage
                                  : null,
                              child: const Text('次へ'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // レビュー追加ボタン
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.rate_review),
                            label: const Text('この書籍をレビューする'),
                            onPressed: () async {
                              final reviewAdded = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddReviewScreen(
                                    bookId: widget.bookId,
                                    bookTitle: widget.bookTitle,
                                  ),
                                ),
                              );
                              if (reviewAdded == true) {
                                _refreshAfterReview(); // 追加後再読み込み
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 書籍サムネイル表示
  Widget _buildBookImageArea(
    String? thumbnail, {
    BoxFit imageFit = BoxFit.fill,
  }) {
    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final leftPercent = 0.011;
        final rightPercent = 0.435;
        final imageWidth = (rightPercent - leftPercent) * screenWidth;
        final marginLeft = leftPercent * screenWidth;
        final imageHeight = imageWidth * 1.45;

        return Container(
          margin: EdgeInsets.only(left: marginLeft),
          width: imageWidth,
          height: imageHeight,
          child: thumbnail != null
              ? Image.network(
                  thumbnail,
                  fit: imageFit,
                  errorBuilder: (_, __, ___) =>
                      Image.asset('assets/images/no-image.jpg', fit: imageFit),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                )
              : Image.asset('assets/images/no-image.jpg', fit: imageFit),
        );
      },
    );
  }
}
