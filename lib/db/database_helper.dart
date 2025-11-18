import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/review.dart';
import '../models/book.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = p.join(dbPath, 'review_app.db');

    return await openDatabase(
      path,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // -------------------
    // Users
    // -------------------
    await db.execute('''
      CREATE TABLE Users (
        user_id TEXT PRIMARY KEY,
        username TEXT DEFAULT '匿名ラッコ',
        user_type TEXT DEFAULT 'other',
        email TEXT UNIQUE,
        password_hash TEXT,
        last_login_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        points INTEGER DEFAULT 0,
        profile TEXT,
        sns_id TEXT,
        thumbnail_url TEXT,
        account_status INTEGER DEFAULT 1,
        is_public INTEGER DEFAULT 1
      );
    ''');

    // -------------------
    // Books
    // -------------------
    await db.execute('''
      CREATE TABLE Books (
        book_id INTEGER PRIMARY KEY AUTOINCREMENT,
        display_title TEXT NOT NULL,
        official_title TEXT,
        author TEXT,
        publisher TEXT,
        thumbnail_url TEXT,
        education TEXT,
        subject TEXT,
        page_count INTEGER,
        isbn TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT
      );
    ''');

    // -------------------
    // Reviews
    // -------------------
    await db.execute('''
      CREATE TABLE Reviews (
        review_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        book_id INTEGER NOT NULL,
        score INTEGER NOT NULL CHECK(score BETWEEN 1 AND 5),
        comment TEXT,
        terminology_clarity INTEGER,
        visual_density INTEGER,
        variety_of_problems INTEGER,
        richness_of_exercises INTEGER,
        richness_of_practice INTEGER,
        recommended_lower_dev INTEGER,
        recommended_upper_dev INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME,
        FOREIGN KEY (user_id) REFERENCES Users(user_id),
        FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE,
        UNIQUE(user_id, book_id)
      );
    ''');

    // -------------------
    // Likes (Reviews)
    // -------------------
    await db.execute('''
      CREATE TABLE Likes (
        user_id TEXT NOT NULL,
        review_id INTEGER NOT NULL,
        PRIMARY KEY (user_id, review_id),
        FOREIGN KEY (user_id) REFERENCES Users(user_id),
        FOREIGN KEY (review_id) REFERENCES Reviews(review_id)
      );
    ''');

    // -------------------
    // BookSetTemplates
    // -------------------
    await db.execute('''
      CREATE TABLE BookSetTemplates (
        rec_set_id INTEGER PRIMARY KEY AUTOINCREMENT,
        like_count INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT
      );
    ''');

    // -------------------
    // UserBookSets
    // -------------------
    await db.execute('''
      CREATE TABLE UserBookSets (
        set_id INTEGER PRIMARY KEY AUTOINCREMENT,
        rec_set_id INTEGER NOT NULL,
        set_index INTEGER NOT NULL CHECK(set_index > 0),
        user_id TEXT NOT NULL,
        book_hash TEXT,
        item_order INTEGER NOT NULL,
        book_id INTEGER NOT NULL,
        note TEXT,
        title TEXT,
        description TEXT,
        is_public INTEGER DEFAULT 0,
        cover_book_id INTEGER,
        color_tag TEXT DEFAULT '#000',
        added_at TEXT DEFAULT CURRENT_TIMESTAMP,
        last_used_at TEXT,
        subject TEXT,
        education TEXT,
        UNIQUE(rec_set_id, user_id, item_order),
        FOREIGN KEY (rec_set_id) REFERENCES BookSetTemplates(rec_set_id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES Users(user_id),
        FOREIGN KEY (book_id) REFERENCES Books(book_id),
        FOREIGN KEY (cover_book_id) REFERENCES Books(book_id)
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_rec_items_set ON UserBookSets(rec_set_id);',
    );

    // -------------------
    // BookSetLikes
    // -------------------
    await db.execute('''
  CREATE TABLE BookSetLikes (
  rec_set_id INTEGER NOT NULL,
  user_id TEXT NOT NULL,
  PRIMARY KEY(rec_set_id, user_id)
);
''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 将来のマイグレーション対応
  }

  // ------------------------------
  // Books関連
  // ------------------------------
  Future<List<Map<String, dynamic>>> getBooks() async {
    final db = await database;
    return await db.query(
      'Books',
      columns: ['book_id', 'display_title'],
      orderBy: 'display_title ASC',
    );
  }

  Future<Book?> getBookById(int bookId) async {
    final db = await database;
    final results = await db.query(
      'Books',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (results.isNotEmpty) {
      final map = results.first;
      return Book(
        bookId: map['book_id'] as int,
        displayTitle: map['display_title'] as String? ?? '',
        officialTitle: map['official_title'] as String? ?? '',
        author: map['author'] as String? ?? '',
        publisher: map['publisher'] as String? ?? '',
        thumbnailUrl: map['thumbnail_url'] as String? ?? '',
        education: map['education'] as String? ?? '',
        subject: map['subject'] as String? ?? '',
        pageCount: map['page_count'] as int?,
        isbn: map['isbn'] as String? ?? '',
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> getBookMapById(int bookId) async {
    final db = await database;
    final results = await db.query(
      'Books',
      columns: ['book_id', 'thumbnail_url'],
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<int> updateBook({
    required int bookId,
    required String displayTitle,
    String? officialTitle,
    String? author,
    String? publisher,
    String? education,
    String? subject,
    String? thumbnailUrl,
    int? pageCount,
    String? isbn,
  }) async {
    final db = await database;
    final data = <String, dynamic>{
      'display_title': displayTitle,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (officialTitle != null) data['official_title'] = officialTitle;
    if (author != null) data['author'] = author;
    if (publisher != null) data['publisher'] = publisher;
    if (education != null) data['education'] = education;
    if (subject != null) data['subject'] = subject;
    if (thumbnailUrl != null) data['thumbnail_url'] = thumbnailUrl;
    if (pageCount != null) data['page_count'] = pageCount;
    if (isbn != null) data['isbn'] = isbn;

    return await db.update(
      'Books',
      data,
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  // ------------------------------
  // Reviews / Likes関連
  // ------------------------------
  Future<List<Review>> getLatestReviewsByBookId(
    int bookId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT 
        r.*, 
        u.username AS user_name,
        COUNT(l.review_id) AS like_count
      FROM Reviews r
      LEFT JOIN Users u ON r.user_id = u.user_id
      LEFT JOIN Likes l ON l.review_id = r.review_id
      WHERE r.book_id = ?
      GROUP BY r.review_id
      ORDER BY r.created_at DESC
      LIMIT ? OFFSET ?;
    ''',
      [bookId, limit, offset],
    );
    return maps.map((m) => Review.fromMap(m)).toList();
  }

  Future<bool> isLiked(String userId, String reviewId) async {
    final db = await database;
    final result = await db.query(
      'Likes',
      where: 'user_id = ? AND review_id = ?',
      whereArgs: [userId, reviewId],
    );
    return result.isNotEmpty;
  }

  Future<void> toggleLike(String userId, String reviewId) async {
    final db = await database;
    if (await isLiked(userId, reviewId)) {
      await db.delete(
        'Likes',
        where: 'user_id = ? AND review_id = ?',
        whereArgs: [userId, reviewId],
      );
    } else {
      await db.insert('Likes', {'user_id': userId, 'review_id': reviewId});
    }
  }

  Future<Set<String>> getLikedReviewIds(String userId) async {
    final db = await database;
    final results = await db.query(
      'Likes',
      columns: ['review_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.map((row) => row['review_id'].toString()).toSet();
  }

  // ------------------------------
  // BookSetTemplates関連
  // ------------------------------
  Future<List<Map<String, dynamic>>> getBookSetTemplates({
    String? orderBy,
  }) async {
    final db = await database;
    return db.query(
      'UserBookSets',
      columns: ['rec_set_id', 'title', 'cover_book_id'],
      where: 'is_public = 1',
      orderBy: orderBy ?? 'rec_set_id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getBookSetTemplatesWithUser({
    String? orderBy,
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT rsi.rec_set_id,
             rsi.title,
             rsi.cover_book_id,
             rsi.added_at,
             u.username
      FROM UserBookSets rsi
      LEFT JOIN Users u ON rsi.user_id = u.user_id
      WHERE rsi.is_public = 1
      ORDER BY ${orderBy ?? 'rsi.added_at DESC, rsi.rec_set_id DESC'};
    ''');
  }

  Future<bool> isRecommendationSetLiked(String userId, int recSetId) async {
    final db = await database;
    final result = await db.query(
      'BookSetLikes',
      where: 'user_id = ? AND rec_set_id = ?',
      whereArgs: [userId, recSetId],
    );
    return result.isNotEmpty;
  }

  Future<void> toggleRecommendationSetLike(String userId, int recSetId) async {
    final db = await database;
    final liked = await isRecommendationSetLiked(userId, recSetId);
    await db.transaction((txn) async {
      if (liked) {
        await txn.delete(
          'BookSetLikes',
          where: 'user_id = ? AND rec_set_id = ?',
          whereArgs: [userId, recSetId],
        );
        await txn.rawUpdate(
          'UPDATE BookSetTemplates SET like_count = like_count - 1 WHERE rec_set_id = ?',
          [recSetId],
        );
      } else {
        await txn.insert('BookSetLikes', {
          'user_id': userId,
          'rec_set_id': recSetId,
        });
        await txn.rawUpdate(
          'UPDATE BookSetTemplates SET like_count = like_count + 1 WHERE rec_set_id = ?',
          [recSetId],
        );
      }
    });
  }

  Future<Set<int>> getLikedRecommendationSetIds(String userId) async {
    final db = await database;
    final results = await db.query(
      'BookSetLikes',
      columns: ['rec_set_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.map((row) => row['rec_set_id'] as int).toSet();
  }

  // ------------------------------
  // UserBookSetsにbook_hashを追加して同じ組み合わせ判定
  // ------------------------------
  Future<void> insertUserBookSetWithHash({
    required String userId,
    required int recSetId,
    required List<int> bookIds,
    required List<int> itemOrders,
    String? title,
    String? description,
    int? coverBookId,
    String? subject,
    String? education,
    bool isPublic = false,
    String colorTag = '#000',
  }) async {
    final db = await database;

    // book_hash生成

    final sortedIds = bookIds.toSet().toList()..sort();
    final joined = sortedIds.join(',');
    final bookHash = sha256.convert(utf8.encode(joined)).toString();

    await db.transaction((txn) async {
      for (int i = 0; i < bookIds.length; i++) {
        await txn.insert('UserBookSets', {
          'rec_set_id': recSetId,
          'user_id': userId,
          'book_id': bookIds[i],
          'item_order': itemOrders[i],
          'title': title,
          'description': description,
          'cover_book_id': coverBookId,
          'subject': subject,
          'education': education,
          'is_public': isPublic ? 1 : 0,
          'color_tag': colorTag,
          'book_hash': bookHash,
          'added_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<int>> findRecSetIdsByBookHash(String bookHash) async {
    final db = await database;
    final results = await db.query(
      'UserBookSets',
      columns: ['rec_set_id'],
      where: 'book_hash = ?',
      whereArgs: [bookHash],
      groupBy: 'rec_set_id',
    );
    return results.map((row) => row['rec_set_id'] as int).toList();
  }

  /// book_hash単位でのいいね数付きランキング取得
  Future<List<Map<String, dynamic>>>
  getBookSetTemplatesWithLikesAndUser() async {
    final db = await database;

    // BookSetLikesの集計確認
    final likeResult = await db.rawQuery('''
    SELECT rec_set_id, COUNT(user_id) AS like_count
    FROM BookSetLikes
    GROUP BY rec_set_id
  ''');

    debugPrint('▶️ BookSetLikes 集計結果 (${likeResult.length}件)');
    for (final row in likeResult) {
      debugPrint(
        'rec_set_id=${row['rec_set_id']} → like_count=${row['like_count']}',
      );
    }

    // book_hash単位で集約
    final result = await db.rawQuery('''
 SELECT
  ubs.book_hash,
  MAX(ubs.title) AS title,
  MAX(ubs.cover_book_id) AS cover_book_id,
  MAX(u.username) AS username,
  (
    SELECT SUM(bl.like_count)
    FROM (
      SELECT rec_set_id, COUNT(user_id) AS like_count
      FROM BookSetLikes
      GROUP BY rec_set_id
    ) bl
    WHERE bl.rec_set_id IN (
      SELECT rec_set_id
      FROM UserBookSets
      WHERE book_hash = ubs.book_hash
    )
  ) AS like_count
FROM (
  SELECT DISTINCT book_hash, rec_set_id, title, cover_book_id, user_id
  FROM UserBookSets
  WHERE is_public = 1
) ubs
LEFT JOIN Users u ON u.user_id = ubs.user_id
GROUP BY ubs.book_hash
ORDER BY like_count DESC


  ''');

    debugPrint('▶️ getBookSetTemplatesWithLikesAndUser 完了: ${result.length}行');
    for (final row in result) {
      debugPrint(
        'book_hash=${row['book_hash']} → like_count=${row['like_count']}',
      );
    }

    return result;
  }

  /// 指定した rec_set_id のいいね数を取得
  Future<int> getLikeCountByRecSetId(int recSetId) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT * FROM BookSetLikes WHERE rec_set_id = ?',
      [recSetId],
    );

    final count = result.length;

    return count;
  }

  /// 現在ログイン中のユーザータイプを保持
  /// 例: 'admin' / 'other' / 'anon'
  static String currentUserType = 'other';

  /// ログイン時にユーザータイプをセットする
  static void setCurrentUserType(String type) {
    currentUserType = type;
  }
}
