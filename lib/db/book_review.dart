class Review {
  final String reviewId;
  final int bookId;
  final String userName;
  final double totalRating;
  final int? explanation;
  final int? diagrams;
  final int? coverage;
  final int? variation;
  final int? practice;
  final String? comment;
  final String createdAt;
  final int? recommendedLowerDev;
  final int? recommendedUpperDev;

  Review({
    required this.reviewId,
    required this.bookId,
    required this.userName,
    required this.totalRating,
    this.explanation,
    this.diagrams,
    this.coverage,
    this.variation,
    this.practice,
    this.comment,
    required this.createdAt,
    this.recommendedLowerDev,
    this.recommendedUpperDev,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      reviewId: map['review_id'] as String,
      bookId: map['book_id'] as int,
      userName: map['user_name'] as String? ?? '匿名ラッコ',
      totalRating: (map['score'] as num).toDouble(),
      explanation: map['terminology_clarity'] as int?,
      diagrams: map['visual_density'] as int?,
      coverage: map['variety_of_problems'] as int?,
      variation: map['richness_of_exercises'] as int?,
      practice: map['richness_of_practice'] as int?,
      comment: map['comment'] as String?,
      createdAt: map['created_at'] as String,
      recommendedLowerDev: map['recommended_lower_dev'] as int?,
      recommendedUpperDev: map['recommended_upper_dev'] as int?,
    );
  }
}
