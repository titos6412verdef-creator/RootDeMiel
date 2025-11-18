// lib/models/book.dart

/// 書籍データを表現するモデルクラス
///
/// DBスキーマ（Booksテーブル）のカラム名に合わせてフィールド名を定義しています。
/// - book_id (INTEGER PRIMARY KEY AUTOINCREMENT)
/// - display_title, official_title, author, publisher, edition, thumbnail_url, education, subject
/// - page_count, created_at, updated_at
class Book {
  /// DB上の主キー（自動採番に対応するため nullable にしています）。
  /// - 既存レコードを扱う場合は値が入ります（例: SELECTしたとき）。
  /// - 新規作成（INSERT）時は null にしておき、DB側で自動採番させるのを推奨します。
  final int? bookId;

  /// ユーザーに表示するタイトル（必須）
  final String displayTitle;

  /// 正式なタイトル（任意）
  final String? officialTitle;

  /// 著者（任意）
  final String? author;

  /// 出版社（任意）
  final String? publisher;

  /// 版（例: 第1版）（任意）
  final String? edition;

  /// サムネイル画像のURL（任意）
  /// - http(s) URL や file:// パス、または空（null）を許容します
  final String? thumbnailUrl;

  /// 教育区分（小学校・中学校・高校 など
  final String? education;

  /// 科目（数学、英語、など）
  final String? subject;

  /// ページ数
  final int? pageCount;

  final String? isbn; // ISBN

  /// レコード作成日時（ISO8601 文字列、nullable）
  final String? createdAt;

  /// レコード更新日時（ISO8601 文字列、nullable）
  final String? updatedAt;

  Book({
    this.bookId,
    required this.displayTitle,
    this.officialTitle,
    this.author,
    this.publisher,
    this.edition,
    this.thumbnailUrl,
    this.education,
    this.subject,
    this.pageCount,
    this.isbn,
    this.createdAt,
    this.updatedAt,
  });

  /// DBのMap (`Map<String, dynamic>`) から Book オブジェクトを生成するファクトリ
  /// - DBから返る値が String 型になっているケースも想定して柔軟に変換します
  factory Book.fromMap(Map<String, dynamic> m) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    // 柔軟にキー名の違いにも対応できるようにする（例：book_id / id）
    final dynamicBookId = m['book_id'] ?? m['id'];
    final dynamicDisplayTitle = m['display_title'] ?? m['title'];

    return Book(
      bookId: parseInt(dynamicBookId),
      displayTitle: dynamicDisplayTitle?.toString() ?? '',
      officialTitle: m['official_title']?.toString(),
      author: m['author']?.toString(),
      publisher: m['publisher']?.toString(),
      edition: m['edition']?.toString(),
      thumbnailUrl: m['thumbnail_url']?.toString(),
      education: m['education']?.toString(),
      subject: m['subject']?.toString(),
      pageCount: parseInt(m['page_count']),
      createdAt: m['created_at']?.toString(),
      updatedAt: m['updated_at']?.toString(),
    );
  }

  /// INSERT 用の Map を返す（book_id は含めない）
  /// - created_at が null の場合は現在時刻を自動セット
  /// - SQLite の自動採番を利用するため book_id は含めません
  Map<String, dynamic> toMapForInsert() {
    return {
      'display_title': displayTitle,
      'official_title': officialTitle,
      'author': author,
      'publisher': publisher,
      'edition': edition,
      'thumbnail_url': thumbnailUrl,
      'education': education,
      'subject': subject,
      'page_count': pageCount,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt,
    };
  }

  /// UPDATE 用の Map を返す（更新時に使う）
  /// - updated_at に現在時刻をセットして返します
  /// - book_id は where 句で指定するためここには含めません
  Map<String, dynamic> toMapForUpdate() {
    final map = toMapForInsert(); // 基本は同じフィールド
    map.remove('created_at'); // 更新時は created_at を変更しない
    map['updated_at'] = DateTime.now().toIso8601String();
    return map;
  }

  /// 完全版の Map（必要に応じて使う。insert では通常 book_id を渡さない）
  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'display_title': displayTitle,
      'official_title': officialTitle,
      'author': author,
      'publisher': publisher,
      'edition': edition,
      'thumbnail_url': thumbnailUrl,
      'education': education,
      'subject': subject,
      'page_count': pageCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 一部フィールドだけ変更して新しい Book を作るユーティリティ（copy-on-write）
  Book copyWith({
    int? bookId,
    String? displayTitle,
    String? officialTitle,
    String? author,
    String? publisher,
    String? edition,
    String? thumbnailUrl,
    String? education,
    String? subject,
    int? pageCount,
    String? createdAt,
    String? updatedAt,
  }) {
    return Book(
      bookId: bookId ?? this.bookId,
      displayTitle: displayTitle ?? this.displayTitle,
      officialTitle: officialTitle ?? this.officialTitle,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      edition: edition ?? this.edition,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      education: education ?? this.education,
      subject: subject ?? this.subject,
      pageCount: pageCount ?? this.pageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Book(bookId: $bookId, displayTitle: $displayTitle)';
  }
}
