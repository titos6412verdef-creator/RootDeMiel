import 'package:flutter/material.dart';

class ReviewCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final double thumbnailWidth;
  final double thumbnailHeight;
  final bool isChild;
  final VoidCallback? onTap;

  /// 追加部分：親Widgetで管理している比較リスト
  final List<int> selectedBookIds;
  final void Function(int bookId, bool isAdded)? onCompareChanged;

  const ReviewCard({
    super.key,
    required this.item,
    this.thumbnailWidth = 100.0,
    this.thumbnailHeight = 100.0,
    this.isChild = false,
    this.onTap,
    required this.selectedBookIds,
    this.onCompareChanged,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  void _toggleCompare() {
    final bookId = widget.item['book_id'] as int?;
    if (bookId == null) return;

    final isAdded = !widget.selectedBookIds.contains(bookId);
    widget.onCompareChanged?.call(bookId, isAdded);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final thumbnailWidth = screenWidth * 0.25;
    final thumbnailHeight = thumbnailWidth * (100 / 70);

    final bookId = widget.item['book_id'] as int?;
    final isSaved = bookId != null && widget.selectedBookIds.contains(bookId);
    final isSelected = isSaved;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左：サムネイル＋比較ボタン
          InkWell(
            onTap: _toggleCompare,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: thumbnailWidth * 0.8,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // サムネイル
                  SizedBox(
                    width: thumbnailWidth * 0.8,
                    height: thumbnailHeight * 0.8,
                    child:
                        (widget.item['thumbnail_url'] != null &&
                            (widget.item['thumbnail_url'] as String).isNotEmpty)
                        ? ((widget.item['thumbnail_url'] as String).startsWith(
                                'http',
                              )
                              ? Image.network(
                                  widget.item['thumbnail_url'],
                                  width: thumbnailWidth,
                                  height: thumbnailHeight,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.book,
                                        size: thumbnailHeight,
                                        color: Colors.grey[400],
                                      ),
                                )
                              : Image.asset(
                                  widget.item['thumbnail_url'],
                                  width: thumbnailWidth,
                                  height: thumbnailHeight,
                                  fit: BoxFit.cover,
                                ))
                        : Icon(
                            Icons.book,
                            size: thumbnailHeight,
                            color: Colors.grey[400],
                          ),
                  ),
                  const SizedBox(height: 6),
                  // ブックマーク＋比較する
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        size: 18,
                        color: isSaved ? Colors.green : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '比較する',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSaved ? Colors.green : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 右：カード本体
          Expanded(
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Card(
                color: isSelected ? Colors.green[50] : Colors.white,
                margin: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    topLeft: Radius.zero,
                    bottomLeft: Radius.zero,
                  ),
                ),
                elevation: 4,
                shadowColor: Colors.black.withAlpha((0.1 * 255).round()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // タイトル
                      Text(
                        '${widget.item['display_title'] ?? 'タイトルなし'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 平均スコア
                      if (widget.item['avg_score'] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${double.tryParse(widget.item['avg_score'].toString())?.toStringAsFixed(1) ?? '-'} / 5.0',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      // レビュー件数
                      if (widget.item['review_count'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'レビュー件数: ${widget.item['review_count']}件',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      // サブスコア
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (widget.item['avg_terminology_clarity'] !=
                                  null)
                                Expanded(
                                  child: _buildSubScore(
                                    '用語充実度',
                                    widget.item['avg_terminology_clarity'],
                                  ),
                                ),
                              if (widget.item['avg_variety_of_problems'] !=
                                  null)
                                Expanded(
                                  child: _buildSubScore(
                                    '網羅率',
                                    widget.item['avg_variety_of_problems'],
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              if (widget.item['avg_richness_of_exercises'] !=
                                  null)
                                Expanded(
                                  child: _buildSubScore(
                                    '練習問題',
                                    widget.item['avg_richness_of_exercises'],
                                  ),
                                ),
                              if (widget.item['avg_richness_of_practice'] !=
                                  null)
                                Expanded(
                                  child: _buildSubScore(
                                    '実践問題',
                                    widget.item['avg_richness_of_practice'],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubScore(String label, dynamic score) {
    final display =
        double.tryParse(score.toString())?.toStringAsFixed(1) ?? '-';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
        Text(
          display,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
