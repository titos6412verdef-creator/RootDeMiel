// lib/screens/review_list.dart
import 'package:flutter/material.dart';
import '../widgets/subject_selector.dart';
import '../screens/review_detail.dart';
import '../utils/subject_utils.dart';
import '../repositories/review_repository.dart';
import '../repositories/review_repository_impl.dart';
import '../widgets/review_card.dart';

// サムネイル画像の表示サイズ
const double thumbnailWidth = 50.0;
const double thumbnailHeight = 80.0;

// レビュー追加ボタンのツールチップ
const String tooltipAddReview = 'レビューを追加';

// 並び替えオプションとラベル
const List<Map<String, dynamic>> sortMenuItems = [
  {'value': SortOption.name, 'label': '書籍名の昇順'},
  {'value': SortOption.count, 'label': 'レビュー件数順'},
  {'value': SortOption.scoreOverall, 'label': '総合評価の高い順'},
  {'value': SortOption.scoreTerminology, 'label': '用語説明の充実度順'},
  {'value': SortOption.scoreCoverage, 'label': '網羅率の高さ順'},
  {'value': SortOption.scoreExercise, 'label': '練習問題の充実度順'},
  {'value': SortOption.scorePractice, 'label': '実践問題の順'},
];

class ReviewListScreen extends StatefulWidget {
  final String? initialEducation; // 初期教育レベル
  final List<String>? initialSubjects; // 初期科目選択
  final void Function(int bookId, bool isAdded)?
  onBookSelected; // 比較リスト選択コールバック
  final List<int> selectedBookIds; // 選択済み書籍ID

  const ReviewListScreen({
    super.key,
    this.initialEducation,
    this.initialSubjects,
    this.onBookSelected,
    required this.selectedBookIds,
  });

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  late Future<List<Map<String, dynamic>>> _reviewsFuture; // 書籍レビュー取得用Future
  SortOption _sortOption = SortOption.name; // 現在の並び替えオプション
  String? _bookTitleFilter; // 書籍名検索フィルタ
  String? _selectedEducationLevel; // 選択中の教育レベル
  List<String>? _selectedSubjects; // 選択中の科目リスト

  final ReviewRepository _reviewRepo = ReviewRepositoryImpl(); // レビュー取得リポジトリ

  // 高校の親科目と子科目のマッピング
  final Map<String, List<String>?> highSchoolSubjectsMap = {
    '数学': null,
    '英語': ['英単語・熟語', 'リスニング', '英文法', '英文解釈', '長文読解', '英語総合'],
    '国語': ['現代文', '古文', '漢文'],
    '理科': ['物理', '化学', '生物', '地学'],
    '地歴': ['歴史総合', '日本史探究', '世界史探究', '地理総合', '地理探究'],
    '公共': ['公共', '倫理', '政治・経済'],
    '情報': null,
  };

  bool _isFilterVisible = false; // 検索・並び替えパネルの折りたたみ状態

  @override
  void initState() {
    super.initState();
    // 初期教育レベルと科目を設定
    _selectedEducationLevel = widget.initialEducation ?? '高校';
    _selectedSubjects =
        (widget.initialSubjects != null && widget.initialSubjects!.isNotEmpty)
        ? widget.initialSubjects
        : ['全教科'];
    _loadReviews(); // 初期レビュー読み込み
  }

  // 書籍を比較リストに追加/削除したときの処理
  void _handleCompareChanged(int bookId, bool isAdded) {
    widget.onBookSelected?.call(bookId, isAdded);
  }

  // レビューリストをロードする
  void _loadReviews() {
    List<String>? expandedSubjects;

    // 「全教科」が選択されている場合はフィルタを無効にする
    if (_selectedSubjects == null || _selectedSubjects!.contains('全教科')) {
      expandedSubjects = null;
    } else {
      // 科目ごとに展開された子科目リストを作成
      final expandedList = <String>[];
      for (final subject in _selectedSubjects!) {
        expandedList.addAll(
          getExpandedSubjectsForSearch(
            educationLevel: _selectedEducationLevel ?? '高校',
            subject: subject,
            highSchoolSubjectsMap: highSchoolSubjectsMap,
          ),
        );
      }
      // 重複を除去してセットに変換
      expandedSubjects = expandedList.toSet().toList();
    }

    // Futureをセットして非同期でレビュー取得
    setState(() {
      _reviewsFuture = _reviewRepo.fetchBooksAggregated(
        educationLevel: _selectedEducationLevel,
        subjects: expandedSubjects,
        sortOption: _sortOption,
        bookTitleFilter: _bookTitleFilter,
      );
    });
  }

  // 親科目と子科目をインデント表示用に整理する
  List<Map<String, dynamic>> _buildIndentedReviewList(
    List<Map<String, dynamic>> reviews,
  ) {
    List<Map<String, dynamic>> result = [];
    List<String> parentOrder = highSchoolSubjectsMap.keys.toList();

    Map<String, List<Map<String, dynamic>>> childrenMap = {};
    List<Map<String, dynamic>> parentsWithoutChildren = [];

    // 指定科目の親科目を取得
    String? findParentOfSubject(String subject) {
      for (var entry in highSchoolSubjectsMap.entries) {
        if (entry.value != null && entry.value!.contains(subject)) {
          return entry.key;
        }
      }
      return null;
    }

    // レビューを親科目/子科目に振り分け
    for (var review in reviews) {
      final education = review['education'] as String?;
      final subject = review['subject'] as String?;

      if (education == '高校' && subject != null) {
        final parent = findParentOfSubject(subject);
        if (parent != null) {
          childrenMap.putIfAbsent(parent, () => []).add({
            ...review,
            'isChild': true, // 子科目フラグ
          });
          continue;
        }
      }
      parentsWithoutChildren.add({...review, 'isChild': false}); // 親なし科目
    }

    // 親科目順にリストを構築
    for (var parent in parentOrder) {
      final parentReview = parentsWithoutChildren.firstWhere(
        (r) => r['subject'] == parent && (r['education'] == '高校'),
        orElse: () => {},
      );

      if (parentReview.isNotEmpty) {
        result.add(parentReview);
        parentsWithoutChildren.remove(parentReview);
      }

      // 子科目を追加
      if (childrenMap.containsKey(parent)) {
        result.addAll(childrenMap[parent]!);
        childrenMap.remove(parent);
      }
    }

    // 残りの親なしレビューを追加
    result.addAll(parentsWithoutChildren);
    return result;
  }

  // 教育レベル・科目選択が変更されたときの処理
  void _onSubjectSelectionChanged(
    String? educationLevel,
    List<String>? subjects,
  ) {
    setState(() {
      _selectedEducationLevel = educationLevel;
      _selectedSubjects = (subjects != null && subjects.isNotEmpty)
          ? subjects
          : ['全教科'];
      _loadReviews(); // 再読み込み
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 教育レベル・科目セレクタ
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: EducationSubjectSelector(
                onSelectionChanged: _onSubjectSelectionChanged,
                initialEducationLevel: _selectedEducationLevel,
                initialSubject:
                    (_selectedSubjects != null &&
                        _selectedSubjects!.length == 1)
                    ? _selectedSubjects!.first
                    : null,
              ),
            ),

            // --- 折りたたみ式検索・並び替えパネル ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: Column(
                children: [
                  // パネルの開閉トグル
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isFilterVisible = !_isFilterVisible;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          _isFilterVisible
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        const SizedBox(width: 4),
                        const Text('検索 / 並び替え'),
                      ],
                    ),
                  ),

                  // アニメーション付きパネル
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _isFilterVisible ? 120 : 0,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 5),
                          // 書籍名検索テキストフィールド
                          TextField(
                            decoration: const InputDecoration(
                              labelText: '書籍名で検索',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _bookTitleFilter = value.trim().isEmpty
                                  ? null
                                  : value.trim();
                              _loadReviews();
                            },
                          ),
                          const SizedBox(height: 1),
                          // 並び替えドロップダウン
                          Row(
                            children: [
                              const Text('並び替え: '),
                              const SizedBox(width: 8),
                              DropdownButton<SortOption>(
                                value: _sortOption,
                                items: sortMenuItems
                                    .map(
                                      (item) => DropdownMenuItem<SortOption>(
                                        value: item['value'] as SortOption,
                                        child: Text(item['label'] ?? ''),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (SortOption? selected) {
                                  if (selected != null) {
                                    setState(() {
                                      _sortOption = selected;
                                      _loadReviews(); // 並び替え変更時に再読み込み
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // レビューリスト
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _reviewsFuture,
                  builder: (context, snapshot) {
                    // データ取得中はインジケータ表示
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // エラー時の表示
                    else if (snapshot.hasError) {
                      return const Center(child: Text('エラーが発生しました'));
                    }
                    // データなしの場合
                    else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('レビューはまだありません'));
                    }
                    // データあり
                    else {
                      final displayedReviews = _buildIndentedReviewList(
                        snapshot.data!,
                      );

                      return ListView.builder(
                        itemCount: displayedReviews.length,
                        itemBuilder: (context, index) {
                          final item = displayedReviews[index];
                          return Container(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ReviewCard(
                              item: {
                                'book_id': item['book_id'],
                                'display_title': item['display_title'] ?? '',
                                'thumbnail_url':
                                    (item['thumbnail_url'] != null &&
                                        (item['thumbnail_url'] as String)
                                            .isNotEmpty)
                                    ? item['thumbnail_url']
                                    : 'assets/images/no-image.jpg',
                                'avg_score': item['avg_score'],
                                'review_count': item['review_count'],
                                'avg_terminology_clarity':
                                    item['avg_terminology_clarity'],
                                'avg_variety_of_problems':
                                    item['avg_variety_of_problems'],
                                'avg_richness_of_exercises':
                                    item['avg_richness_of_exercises'],
                                'avg_richness_of_practice':
                                    item['avg_richness_of_practice'],
                              },
                              thumbnailWidth: thumbnailWidth,
                              thumbnailHeight: thumbnailHeight,
                              isChild: item['isChild'] ?? false,
                              selectedBookIds: widget.selectedBookIds,
                              onCompareChanged: _handleCompareChanged,
                              // タップでレビュー詳細画面へ遷移
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        BookReviewDetailScreen(
                                          bookId: item['book_id'],
                                          bookTitle:
                                              item['display_title'] ?? '',
                                        ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      // 書籍追加用のFloatingActionButton
      floatingActionButton: FloatingActionButton(
        heroTag: 'addReviewBtn',
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/add-book');
          if (result == true) {
            _loadReviews(); // 書籍追加後にリスト再読み込み
          }
        },
        tooltip: '書籍を追加',
        child: const Icon(Icons.library_add),
      ),
    );
  }
}
