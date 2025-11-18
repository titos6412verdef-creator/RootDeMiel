// lib/repositories/review_repository_impl.dart
import 'package:sqflite/sqflite.dart';
import '../models/review.dart';
import '../db/database_helper.dart';
import 'review_repository.dart';

/// ReviewRepository の SQLite 実装（DatabaseHelper を使用）
class ReviewRepositoryImpl implements ReviewRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // -----------------------
  // Basic CRUD
  // -----------------------
  @override
  Future<List<Review>> fetchAllReviews() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT 
        r.*,
        COUNT(l.review_id) AS like_count
      FROM Reviews r
      LEFT JOIN Likes l ON r.review_id = l.review_id
      GROUP BY r.review_id
      ORDER BY r.created_at DESC
    ''');
    return maps.map((m) => Review.fromMap(m)).toList();
  }

  @override
  Future<Review?> fetchReviewById(String reviewId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT 
        r.*,
        COUNT(l.review_id) AS like_count
      FROM Reviews r
      LEFT JOIN Likes l ON r.review_id = l.review_id
      WHERE r.review_id = ?
      GROUP BY r.review_id
      LIMIT 1
    ''',
      [reviewId],
    );
    if (maps.isEmpty) return null;
    return Review.fromMap(maps.first);
  }

  @override
  Future<Review> createReview(Review review) async {
    final db = await _dbHelper.database;
    final map = review.toMapForInsert();
    final insertedId = await db.insert('Reviews', map);
    return review.reviewId != null
        ? review
        : review.copyWith(reviewId: insertedId.toString());
  }

  @override
  Future<void> updateReview(Review review) async {
    final db = await _dbHelper.database;
    await db.update(
      'Reviews',
      review.toMapForUpdate(),
      where: 'review_id = ?',
      whereArgs: [review.reviewId!],
    );
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    final db = await _dbHelper.database;
    await db.delete('Reviews', where: 'review_id = ?', whereArgs: [reviewId]);
  }

  // -----------------------
  // Likes 関連
  // -----------------------
  @override
  Future<Set<String>> getLikedReviewIds(String userId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Likes',
      columns: ['review_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((m) => m['review_id'].toString()).toSet();
  }

  @override
  Future<bool> isReviewLiked(String reviewId, String userId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Likes',
      where: 'review_id = ? AND user_id = ?',
      whereArgs: [reviewId, userId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  @override
  Future<void> toggleLike(String reviewId, String userId) async {
    final db = await _dbHelper.database;
    final liked = await isReviewLiked(reviewId, userId);
    if (liked) {
      await db.delete(
        'Likes',
        where: 'review_id = ? AND user_id = ?',
        whereArgs: [reviewId, userId],
      );
    } else {
      await db.insert('Likes', {'review_id': reviewId, 'user_id': userId});
    }
  }

  // -----------------------
  // 書籍ごとのレビュー集計
  // -----------------------
  @override
  Future<List<Map<String, dynamic>>> fetchBooksAggregatedByIds(
    List<int> bookIds,
  ) async {
    if (bookIds.isEmpty) return [];
    final db = await _dbHelper.database;
    final placeholders = List.filled(bookIds.length, '?').join(',');
    final result = await db.rawQuery('''
      SELECT
        b.book_id,
        b.display_title,
        b.thumbnail_url,
        COUNT(r.review_id) AS review_count,
        AVG(r.score) AS avg_score,
        AVG(r.terminology_clarity) AS avg_terminology_clarity,
        AVG(r.variety_of_problems) AS avg_variety_of_problems,
        AVG(r.richness_of_exercises) AS avg_richness_of_exercises,
        AVG(r.richness_of_practice) AS avg_richness_of_practice,
        AVG(r.recommended_lower_dev) AS avg_lower_deviation,
        AVG(r.recommended_upper_dev) AS avg_upper_deviation
      FROM Books b
      LEFT JOIN Reviews r ON r.book_id = b.book_id
      LEFT JOIN Likes l ON r.review_id = l.review_id
      WHERE b.book_id IN ($placeholders)
      GROUP BY b.book_id
    ''', bookIds);
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBooksByIds(List<int> bookIds) {
    return fetchBooksAggregatedByIds(bookIds);
  }

  @override
  Future<Map<String, double>> fetchOverallReviewAverages() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        AVG(terminology_clarity) AS avg_terminology_clarity,
        AVG(variety_of_problems) AS avg_variety_of_problems,
        AVG(richness_of_exercises) AS avg_richness_of_exercises,
        AVG(richness_of_practice) AS avg_richness_of_practice
      FROM Reviews
    ''');
    final row = result.first;
    return {
      'avg_terminology_clarity':
          (row['avg_terminology_clarity'] as num?)?.toDouble() ?? 0.0,
      'avg_variety_of_problems':
          (row['avg_variety_of_problems'] as num?)?.toDouble() ?? 0.0,
      'avg_richness_of_exercises':
          (row['avg_richness_of_exercises'] as num?)?.toDouble() ?? 0.0,
      'avg_richness_of_practice':
          (row['avg_richness_of_practice'] as num?)?.toDouble() ?? 0.0,
    };
  }

  @override
  Future<Map<String, dynamic>> fetchBookAverages(int bookId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT
        AVG(score) AS avg_score,
        AVG(terminology_clarity) AS avg_terminology_clarity,
        AVG(variety_of_problems) AS avg_variety_of_problems,
        AVG(richness_of_exercises) AS avg_richness_of_exercises,
        AVG(richness_of_practice) AS avg_richness_of_practice,
        AVG(recommended_lower_dev) AS avg_lower_deviation,
        AVG(recommended_upper_dev) AS avg_upper_deviation
      FROM Reviews
      WHERE book_id = ?
    ''',
      [bookId],
    );
    return result.first.isNotEmpty ? result.first : <String, dynamic>{};
  }

  @override
  Future<Map<String, double>> fetchReviewAveragesByBookId(int bookId) async {
    final data = await fetchBookAverages(bookId);
    return data.map(
      (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0.0),
    );
  }

  // -----------------------
  // Books 関連
  // -----------------------
  @override
  Future<Map<String, dynamic>?> fetchBookById(int bookId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Books',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  @override
  Future<List<Review>> fetchReviewsByBookId(
    int bookId, {
    int? limit,
    int? offset,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT 
        r.*,
        COUNT(l.review_id) AS like_count
      FROM Reviews r
      LEFT JOIN Likes l ON r.review_id = l.review_id
      WHERE r.book_id = ?
      GROUP BY r.review_id
      ORDER BY r.created_at DESC
      ${limit != null ? "LIMIT $limit" : ""}
      ${offset != null ? "OFFSET $offset" : ""}
    ''',
      [bookId],
    );
    return maps.map((m) => Review.fromMap(m)).toList();
  }

  @override
  Future<int> fetchReviewCountByBookId(int bookId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM Reviews WHERE book_id = ?',
      [bookId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // -----------------------
  // 内部: Sort 用 Comparator（降順対応）
  // -----------------------
  static final Map<SortOption, Comparator<Map<String, dynamic>>>
  _sortComparators = {
    SortOption.name: (a, b) => (a['display_title'] as String)
        .toLowerCase()
        .compareTo((b['display_title'] as String).toLowerCase()),
    SortOption.count: (a, b) =>
        (int.tryParse(b['review_count']?.toString() ?? '0') ?? 0).compareTo(
          int.tryParse(a['review_count']?.toString() ?? '0') ?? 0,
        ),
    SortOption.scoreOverall: (a, b) =>
        (double.tryParse(b['avg_score']?.toString() ?? '0.0') ?? 0.0).compareTo(
          double.tryParse(a['avg_score']?.toString() ?? '0.0') ?? 0.0,
        ),
    SortOption.scoreTerminology: (a, b) =>
        (double.tryParse(b['avg_terminology_clarity']?.toString() ?? '0.0') ??
                0.0)
            .compareTo(
              double.tryParse(
                    a['avg_terminology_clarity']?.toString() ?? '0.0',
                  ) ??
                  0.0,
            ),
    SortOption.scoreCoverage: (a, b) =>
        (double.tryParse(b['avg_variety_of_problems']?.toString() ?? '0.0') ??
                0.0)
            .compareTo(
              double.tryParse(
                    a['avg_variety_of_problems']?.toString() ?? '0.0',
                  ) ??
                  0.0,
            ),
    SortOption.scoreExercise: (a, b) =>
        (double.tryParse(b['avg_richness_of_exercises']?.toString() ?? '0.0') ??
                0.0)
            .compareTo(
              double.tryParse(
                    a['avg_richness_of_exercises']?.toString() ?? '0.0',
                  ) ??
                  0.0,
            ),
    SortOption.scorePractice: (a, b) =>
        (double.tryParse(b['avg_richness_of_practice']?.toString() ?? '0.0') ??
                0.0)
            .compareTo(
              double.tryParse(
                    a['avg_richness_of_practice']?.toString() ?? '0.0',
                  ) ??
                  0.0,
            ),
  };

  // -----------------------
  // fetchLatestReviewPerBook の SQLite 実装
  // -----------------------
  @override
  Future<List<Map<String, dynamic>>> fetchLatestReviewPerBook({
    String? educationLevel,
    List<String>? subjects,
    SortOption sortOption = SortOption.name,
    String? bookTitleFilter,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (educationLevel != null) {
      whereClause += 'b.education = ?';
      whereArgs.add(educationLevel);
    }
    if (subjects != null && subjects.isNotEmpty) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      final placeholders = List.filled(subjects.length, '?').join(',');
      whereClause += 'b.subject IN ($placeholders)';
      whereArgs.addAll(subjects);
    }
    if (bookTitleFilter != null && bookTitleFilter.isNotEmpty) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'b.display_title LIKE ?';
      whereArgs.add('%$bookTitleFilter%');
    }

    final result = await db.rawQuery('''
      SELECT
        b.book_id,
        b.display_title,
        b.thumbnail_url,
        COUNT(r.review_id) AS review_count,
        AVG(r.score) AS avg_score,
        AVG(r.terminology_clarity) AS avg_terminology_clarity,
        AVG(r.variety_of_problems) AS avg_variety_of_problems,
        AVG(r.richness_of_exercises) AS avg_richness_of_exercises,
        AVG(r.richness_of_practice) AS avg_richness_of_practice,
        AVG(r.recommended_lower_dev) AS avg_lower_deviation,
        AVG(r.recommended_upper_dev) AS avg_upper_deviation,
        COUNT(l.review_id) AS like_count
      FROM Books b
      LEFT JOIN Reviews r ON r.book_id = b.book_id
      LEFT JOIN Likes l ON r.review_id = l.review_id
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      GROUP BY b.book_id
    ''', whereArgs);

    final sortedResult = List<Map<String, dynamic>>.from(result);
    final comparator = _sortComparators[sortOption]!;
    sortedResult.sort(comparator);

    return sortedResult;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBooksAggregated({
    String? bookTitleFilter,
    String? educationLevel,
    SortOption sortOption = SortOption.name,
    List<String>? subjects,
  }) {
    return fetchLatestReviewPerBook(
      educationLevel: educationLevel,
      subjects: subjects,
      sortOption: sortOption,
      bookTitleFilter: bookTitleFilter,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBooksWithLatestReview({
    String? educationLevel,
    List<String>? subjects,
    SortOption sortOption = SortOption.name,
    String? bookTitleFilter,
  }) {
    return fetchLatestReviewPerBook(
      educationLevel: educationLevel,
      subjects: subjects,
      sortOption: sortOption,
      bookTitleFilter: bookTitleFilter,
    );
  }

  // -----------------------
  // My Picks / Recommendation Sets 関連
  // -----------------------

  /// rec_set_id を取得／作成
  @override
  Future<int> getOrCreateRecSetId(List<int> bookIds) async {
    final db = await _dbHelper.database;

    final existing = await db.query(
      'BookSetTemplates',
      where: 'book_count = ?',
      whereArgs: [bookIds.length],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['rec_set_id'] as int;

    final now = DateTime.now().toIso8601String();
    final recSetId = await db.insert('BookSetTemplates', {
      'book_count': bookIds.length,
      'created_at': now,
      'updated_at': now,
    });
    return recSetId;
  }

  /// set_id を取得／作成（ユーザー単位）
  @override
  Future<int> getOrCreateSetId(String userId, int recSetId) async {
    final db = await _dbHelper.database;

    final existing = await db.query(
      'BookSetTemplates',
      where: 'rec_set_id = ? AND user_id = ?',
      whereArgs: [recSetId, userId],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['set_id'] as int;

    final now = DateTime.now().toIso8601String();
    final setId = await db.insert('BookSetTemplates', {
      'rec_set_id': recSetId,
      'user_id': userId,
      'created_at': now,
      'updated_at': now,
    });
    return setId;
  }

  /// UserBookSets に挿入
  @override
  Future<void> insertUserBookSets({
    required String userId,
    required int recSetId,
    required int setId,
    required List<int> bookIds,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    for (int i = 0; i < bookIds.length; i++) {
      await db.insert('UserBookSets', {
        'rec_set_id': recSetId,
        'set_id': setId,
        'user_id': userId,
        'set_index': i + 1, // ★ bookIds 順に連番
        'item_order': i + 1,
        'book_id': bookIds[i],
        'note': '',
        'title': 'My Pick ${i + 1}',
        'description': '',
        'is_public': 0,
        'cover_book_id': bookIds.first, // ★ 先頭の bookId を代表に
        'color_tag': '#000000',
        'added_at': now,
        'last_used_at': now,
        'subject': null,
      });
    }
  }

  /// ユーザーの My Picks 一覧取得
  @override
  Future<List<Map<String, dynamic>>> fetchUserMyPicks(String userId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT i.*, b.display_title, b.thumbnail_url
      FROM UserBookSets i
      JOIN Books b ON i.book_id = b.book_id
      WHERE i.user_id = ?
      ORDER BY i.set_index, i.item_order
    ''',
      [userId],
    );

    return result;
  }

  /// My Picks 削除
  @override
  Future<void> deleteUserMyPickItem(int itemId) async {
    final db = await _dbHelper.database;
    await db.delete('UserBookSets', where: 'item_id = ?', whereArgs: [itemId]);
  }

  /// 追加: rec_set_id 単位でアイテム取得
  Future<List<Map<String, dynamic>>> fetchUserBookSets(int recSetId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT i.*, b.display_title, b.thumbnail_url
      FROM UserBookSets i
      JOIN Books b ON i.book_id = b.book_id
      WHERE i.rec_set_id = ?
      ORDER BY i.item_order
    ''',
      [recSetId],
    );
    return result;
  }

  /// 追加: 並び順を更新
  Future<void> updateUserBookSetsOrder({
    required int recSetId,
    required List<int> bookIdsInOrder,
  }) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (int i = 0; i < bookIdsInOrder.length; i++) {
      batch.update(
        'UserBookSets',
        {'item_order': i + 1},
        where: 'rec_set_id = ? AND book_id = ?',
        whereArgs: [recSetId, bookIdsInOrder[i]],
      );
    }

    await batch.commit(noResult: true);
  }
}
