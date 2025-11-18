// lib/models/review.dart

/// レビューデータモデル（DB: Reviews テーブルに対応）
///
/// DBスキーマに基づく主なカラム（抜粋）:
/// - review_id TEXT PRIMARY KEY
/// - user_id TEXT
/// - book_id INTEGER
/// - score INTEGER (1..5)
/// - comment TEXT
/// - terminology_clarity INTEGER
/// - visual_density INTEGER
/// - variety_of_problems INTEGER
/// - richness_of_exercises INTEGER
/// - richness_of_practice INTEGER
/// - recommended_lower_dev INTEGER
/// - recommended_upper_dev INTEGER
/// - created_at DATETIME
/// - updated_at DATETIME
///
/// 備考:
/// - reviewId は文字列（UUID等）を想定。既存コードで数値を使っている場合にも対応できるよう柔軟に扱います。
/// - userName は JOIN 結果（Users.username）を格納する補助フィールドで、DB のカラムには存在しません。
class Review {
  /// DB上の主キー（TEXT）。生成時は null にしてサーバ/アプリ側で生成する運用も可能。
  final String? reviewId;

  /// 投稿者ユーザーID（Users.user_id を参照）
  final String userId;

  /// 対象の書籍ID（Books.book_id）
  final int bookId;

  /// 総合評価スコア（1..5）
  final int score;

  /// コメント・感想文（任意）
  final String? comment;

  /// 用語説明の丁寧さ（評価: 整数）等、各種評価項目は nullable
  final int? terminologyClarity;
  final int? visualDensity;
  final int? varietyOfProblems;
  final int? richnessOfExercises;
  final int? richnessOfPractice;

  /// 投稿者が推奨する偏差値レンジ（任意）
  final int? recommendedLowerDev;
  final int? recommendedUpperDev;

  /// 作成／更新日時（ISO8601文字列）
  final String? createdAt;
  final String? updatedAt;

  /// JOIN時に取得される表示名（Users.username）を格納する補助フィールド
  final String? userName;

  /// 「役に立った」件数（JOIN/集計で取得）
  final int likeCount;

  /// 互換用：既存コードから `toMap()` を呼ばれている場合に備えたメソッド
  /// - INSERT/UPDATE どちらにも使える汎用マップを返します。
  Map<String, dynamic> toMap() {
    final m = toMapForInsert();
    // reviewId がある場合は明示的に含める（既存コードが主キーを渡す想定なら）
    if (reviewId != null) {
      m['review_id'] = reviewId;
    }
    return m;
  }

  Review({
    this.reviewId,
    required this.userId,
    required this.bookId,
    required this.score,
    this.comment,
    this.terminologyClarity,
    this.visualDensity,
    this.varietyOfProblems,
    this.richnessOfExercises,
    this.richnessOfPractice,
    this.recommendedLowerDev,
    this.recommendedUpperDev,
    this.createdAt,
    this.updatedAt,
    this.userName,
    this.likeCount = 0,
  });

  // ------- ヘルパー: 柔軟な数値パース -------
  static int? _toNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final s = v.toString();
    return int.tryParse(s);
  }

  static String? _toNullableString(dynamic v) {
    if (v == null) return null;
    return v.toString();
  }

  /// DBの Map から Review インスタンスを生成するファクトリ
  /// - DBから返る値が String や int のどちらでも対応します
  factory Review.fromMap(Map<String, dynamic> m) {
    // review_id は TEXT だが、既存コードで数値が入っているケースに対応
    final rid = m['review_id'] ?? m['id'] ?? m['ID'];
    final reviewIdStr = rid?.toString();

    return Review(
      reviewId: reviewIdStr,
      userId: (m['user_id'] ?? '').toString(),
      bookId: _toNullableInt(m['book_id']) ?? 0,
      score: _toNullableInt(m['score']) ?? 0,
      comment: _toNullableString(m['comment']),
      terminologyClarity: _toNullableInt(m['terminology_clarity']),
      visualDensity: _toNullableInt(m['visual_density']),
      varietyOfProblems: _toNullableInt(m['variety_of_problems']),
      richnessOfExercises: _toNullableInt(m['richness_of_exercises']),
      richnessOfPractice: _toNullableInt(m['richness_of_practice']),
      recommendedLowerDev: _toNullableInt(m['recommended_lower_dev']),
      recommendedUpperDev: _toNullableInt(m['recommended_upper_dev']),
      createdAt: _toNullableString(m['created_at']),
      updatedAt: _toNullableString(m['updated_at']),
      userName: _toNullableString(m['user_name']),
      likeCount: _toNullableInt(m['like_count']) ?? 0,
    );
  }

  /// INSERT 用の Map を生成（review_id が null の場合は呼び出し側で生成可能）
  /// - created_at は指定がなければ現在時刻をセット
  Map<String, dynamic> toMapForInsert() {
    return {
      if (reviewId != null) 'review_id': reviewId,
      'user_id': userId,
      'book_id': bookId,
      'score': score,
      'comment': comment,
      'terminology_clarity': terminologyClarity,
      'visual_density': visualDensity,
      'variety_of_problems': varietyOfProblems,
      'richness_of_exercises': richnessOfExercises,
      'richness_of_practice': richnessOfPractice,
      'recommended_lower_dev': recommendedLowerDev,
      'recommended_upper_dev': recommendedUpperDev,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt,
    };
  }

  /// UPDATE 用の Map を生成（updated_at に現在時刻をセット）
  Map<String, dynamic> toMapForUpdate() {
    final m = toMapForInsert();
    m.remove('created_at');
    m['updated_at'] = DateTime.now().toIso8601String();
    return m;
  }

  /// copyWith: 一部だけ変更して新しい Review を作るユーティリティ
  Review copyWith({
    String? reviewId,
    String? userId,
    int? bookId,
    int? score,
    String? comment,
    int? terminologyClarity,
    int? visualDensity,
    int? varietyOfProblems,
    int? richnessOfExercises,
    int? richnessOfPractice,
    int? recommendedLowerDev,
    int? recommendedUpperDev,
    String? createdAt,
    String? updatedAt,
    String? userName,
    int? likeCount,
  }) {
    return Review(
      reviewId: reviewId ?? this.reviewId,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      score: score ?? this.score,
      comment: comment ?? this.comment,
      terminologyClarity: terminologyClarity ?? this.terminologyClarity,
      visualDensity: visualDensity ?? this.visualDensity,
      varietyOfProblems: varietyOfProblems ?? this.varietyOfProblems,
      richnessOfExercises: richnessOfExercises ?? this.richnessOfExercises,
      richnessOfPractice: richnessOfPractice ?? this.richnessOfPractice,
      recommendedLowerDev: recommendedLowerDev ?? this.recommendedLowerDev,
      recommendedUpperDev: recommendedUpperDev ?? this.recommendedUpperDev,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      likeCount: likeCount ?? this.likeCount,
    );
  }

  @override
  String toString() {
    return 'Review(reviewId: $reviewId, bookId: $bookId, score: $score, userId: $userId, likeCount: $likeCount)';
  }
}
