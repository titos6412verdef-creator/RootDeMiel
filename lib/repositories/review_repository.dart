// lib/repositories/review_repository.dart
import '../models/review.dart';

/// ソートオプション用 enum
enum SortOption {
  name,
  count,
  scoreOverall,
  scoreTerminology,
  scoreCoverage,
  scoreExercise,
  scorePractice,
}

extension SortOptionExt on SortOption {
  /// SQLite でのソート時に使用する列名を返す
  String toDatabaseColumn() {
    switch (this) {
      case SortOption.name:
        return 'display_title';
      case SortOption.count:
        return 'review_count';
      case SortOption.scoreOverall:
        return 'avg_score';
      case SortOption.scoreTerminology:
        return 'avg_terminology_clarity';
      case SortOption.scoreCoverage:
        return 'avg_variety_of_problems';
      case SortOption.scoreExercise:
        return 'avg_richness_of_exercises';
      case SortOption.scorePractice:
        return 'avg_richness_of_practice';
    }
  }
}

/// レビューリポジトリのインターフェース
/// データ取得・保存の共通メソッドを定義します。
/// 実装クラス（ReviewRepositoryImpl）で実装してください。
abstract class ReviewRepository {
  // ----------------------
  // Basic CRUD
  // ----------------------
  Future<List<Review>> fetchAllReviews();
  Future<Review?> fetchReviewById(String reviewId);
  Future<Review> createReview(Review review);
  Future<void> updateReview(Review review);
  Future<void> deleteReview(String reviewId);

  // ----------------------
  // Books / Aggregates
  // ----------------------
  Future<List<Map<String, dynamic>>> fetchBooksByIds(List<int> bookIds);

  Future<List<Map<String, dynamic>>> fetchBooksAggregatedByIds(
    List<int> bookIds,
  );

  Future<Map<String, double>> fetchOverallReviewAverages();
  Future<Map<String, dynamic>> fetchBookAverages(int bookId);

  // ----------------------
  // List / Summary
  // ----------------------
  Future<List<Map<String, dynamic>>> fetchLatestReviewPerBook({
    String? educationLevel,
    List<String>? subjects,
    SortOption sortOption,
    String? bookTitleFilter,
  });

  Future<List<Review>> fetchReviewsByBookId(
    int bookId, {
    int? limit,
    int? offset,
  });

  Future<Map<String, dynamic>?> fetchBookById(int bookId);
  Future<int> fetchReviewCountByBookId(int bookId);
  Future<Map<String, double>> fetchReviewAveragesByBookId(int bookId);

  // ----------------------
  // Likes
  // ----------------------
  Future<bool> isReviewLiked(String reviewId, String userId);
  Future<void> toggleLike(String reviewId, String userId);
  Future<Set<String>> getLikedReviewIds(String userId);

  // ----------------------
  // fetchBooksAggregated alias
  // ----------------------
  Future<List<Map<String, dynamic>>> fetchBooksAggregated({
    String? bookTitleFilter,
    String? educationLevel,
    SortOption sortOption,
    List<String>? subjects,
  });

  Future<List<Map<String, dynamic>>> fetchBooksWithLatestReview({
    String? educationLevel,
    List<String>? subjects,
    SortOption sortOption,
    String? bookTitleFilter,
  });

  // ----------------------
  // Recommendation Sets / My Picks
  // ----------------------
  Future<int> getOrCreateRecSetId(List<int> bookIds);
  Future<int> getOrCreateSetId(String userId, int recSetId);
  Future<void> insertUserBookSets({
    required String userId,
    required int recSetId,
    required int setId,
    required List<int> bookIds,
  });

  Future<List<Map<String, dynamic>>> fetchUserMyPicks(String userId);
  Future<void> deleteUserMyPickItem(int itemId);
}
