import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../widgets/subject_selector.dart';
import 'manage_books.dart';
import 'dart:math';
import 'package:sqflite/sqflite.dart';

const int defaultScore = 3;
const String errorMsgBookSelectRequired = '書籍を選択してください';
const String errorMsgUserIdNotFound = 'ユーザーIDが取得できませんでした';
const String msgReviewSaveSuccess = 'レビューを保存しました';

class AddReviewScreen extends StatefulWidget {
  final int? bookId; // 初期選択用の書籍ID（任意）
  final String? bookTitle; // 必要なら書籍タイトルも受け取る（任意）

  const AddReviewScreen({super.key, this.bookId, this.bookTitle});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _books = [];
  String? _selectedBookId;

  final _userIdController = TextEditingController(text: '');
  final _commentController = TextEditingController();

  int _score = defaultScore;

  // 評価項目
  int _terminologyClarity = 3;
  int _visualDensity = 3;
  int _varietyOfProblems = 3;
  int _richnessOfExercises = 3;
  int _richnessOfPractice = 3;
  int _recommendedLowerDev = 45;
  int _recommendedUpperDev = 65;

  // --- 以下、教育区分・教科・書籍絞り込み用 ---
  String? _selectedEducation;
  List<String>? _selectedSubjects;
  String _bookSearchText = '';

  List<Map<String, dynamic>> _filteredBooks = [];

  @override
  void initState() {
    super.initState();

    _setRandomTestUserId();

    _loadBooks();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _setRandomTestUserId() {
    final random = Random();
    final randomUserId = 'test_user_${random.nextInt(100000)}';
    setState(() {
      _userIdController.text = randomUserId;
    });
  }

  Future<void> _loadBooks() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('Books');

    setState(() {
      _books = result;

      // 初期は教育区分・教科は未選択
      _selectedEducation = null;
      _selectedSubjects = null;
      _bookSearchText = '';
    });

    // ここで初期選択の書籍IDがDBに存在するかチェック
    final initialBookIdStr = widget.bookId?.toString();
    final bookExists =
        initialBookIdStr != null &&
        _books.any((book) => book['book_id'].toString() == initialBookIdStr);

    setState(() {
      if (bookExists) {
        _selectedBookId = initialBookIdStr;
      } else if (_books.isNotEmpty) {
        _selectedBookId = _books.first['book_id'].toString();
      } else {
        _selectedBookId = null;
      }
    });

    // フィルタリング実施（初期は絞り込みなし）
    _filterBooks();
  }

  void _filterBooks() {
    setState(() {
      _filteredBooks = _books.where((book) {
        final educationMatch =
            _selectedEducation == null ||
            _selectedEducation!.isEmpty ||
            book['education'] == _selectedEducation;

        // 複数科目対応判定。書籍のsubjectは単一文字列（例："数学"）なので、
        // 選択科目のどれかに書籍のsubjectが含まれるかを判定
        final subjectMatch =
            (_selectedSubjects == null || _selectedSubjects!.isEmpty)
            ? true
            : _selectedSubjects!.contains(book['subject'] as String? ?? '');

        final searchMatch =
            _bookSearchText.isEmpty ||
            (book['display_title'] as String).toLowerCase().contains(
              _bookSearchText.toLowerCase(),
            );

        return educationMatch && subjectMatch && searchMatch;
      }).toList();

      // ここでは _selectedBookId を変えない（初期選択は_loadBooksで行う）
      if (_filteredBooks.isEmpty) {
        _selectedBookId = null;
      } else if (_selectedBookId != null &&
          !_filteredBooks.any(
            (book) => book['book_id'].toString() == _selectedBookId,
          )) {
        // フィルターに引っかからず初期選択の書籍がリストにない場合は先頭に変更
        _selectedBookId = _filteredBooks.first['book_id'].toString();
      }
    });
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(errorMsgUserIdNotFound)));
      return;
    }

    if (_selectedBookId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(errorMsgBookSelectRequired)));
      return;
    }

    final db = await DatabaseHelper.instance.database;

    await db.insert('Users', {
      'user_id': userId,
      'username': '匿名ラッコ',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final now = DateTime.now().toIso8601String();

    final reviewData = {
      'user_id': userId,
      'book_id': int.parse(_selectedBookId!),
      'score': _score,
      'comment': _commentController.text,
      'terminology_clarity': _terminologyClarity,
      'visual_density': _visualDensity,
      'variety_of_problems': _varietyOfProblems,
      'richness_of_exercises': _richnessOfExercises,
      'richness_of_practice': _richnessOfPractice,
      'recommended_lower_dev': _recommendedLowerDev,
      'recommended_upper_dev': _recommendedUpperDev,
      'created_at': now,
    };

    try {
      await db.insert('Reviews', reviewData);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(msgReviewSaveSuccess)));
      Navigator.pop(context, true);
    } catch (e, stack) {
      // ここでエラー詳細をログに出す-----------------------------------------
      debugPrint('レビュー保存時のエラー: $e');
      debugPrintStack(stackTrace: stack);
      //debug----------------------------------------------------------

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    }
  }

  Widget _buildSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 1,
    int max = 5,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: value.toString(),
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('レビュー追加')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 教育区分・教科選択セレクター（複数科目対応）
              EducationSubjectSelector(
                initialEducationLevel: _selectedEducation,
                initialSubject:
                    (_selectedSubjects != null &&
                        _selectedSubjects!.length == 1)
                    ? _selectedSubjects!.first
                    : null,
                onSelectionChanged: (education, subjects) {
                  setState(() {
                    _selectedEducation = education;
                    _selectedSubjects = subjects;
                  });
                },
              ),
              const SizedBox(height: 12),

              // 書籍名検索テキストボックス
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '書籍名で検索',
                  hintText: '一部を入力すると候補を絞り込みます',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    _bookSearchText = val;
                  });
                  _filterBooks();
                },
              ),

              const SizedBox(height: 12),

              // 書籍選択ドロップダウン（絞り込み済み）
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: '書籍を選択'),
                items: _filteredBooks.map((book) {
                  return DropdownMenuItem(
                    value: book['book_id'].toString(),
                    child: Text(book['display_title'] ?? '(無題)'),
                  );
                }).toList(),
                value: _selectedBookId,
                onChanged: (val) {
                  setState(() {
                    _selectedBookId = val;
                  });
                },
                validator: (val) => (val == null || val.isEmpty)
                    ? errorMsgBookSelectRequired
                    : null,
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageBooksScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.library_books),
                label: const Text('書籍を管理/追加する'),
              ),

              const SizedBox(height: 24),

              _buildSlider(
                label: '総合評価',
                value: _score,
                onChanged: (v) => setState(() => _score = v),
              ),
              _buildSlider(
                label: '用語説明の充実度',
                value: _terminologyClarity,
                onChanged: (v) => setState(() => _terminologyClarity = v),
              ),
              _buildSlider(
                label: '図表や補助線の多さ',
                value: _visualDensity,
                onChanged: (v) => setState(() => _visualDensity = v),
              ),
              _buildSlider(
                label: '網羅率（学習内容の多様性）',
                value: _varietyOfProblems,
                onChanged: (v) => setState(() => _varietyOfProblems = v),
              ),
              _buildSlider(
                label: '練習問題（類題）の充実度',
                value: _richnessOfExercises,
                onChanged: (v) => setState(() => _richnessOfExercises = v),
              ),
              _buildSlider(
                label: '実践問題（過去問等）の充実度',
                value: _richnessOfPractice,
                onChanged: (v) => setState(() => _richnessOfPractice = v),
              ),

              const SizedBox(height: 24),

              _buildSlider(
                label: '対象偏差値（下限）',
                value: _recommendedLowerDev,
                onChanged: (v) => setState(() => _recommendedLowerDev = v),
                min: 30,
                max: 70,
              ),
              _buildSlider(
                label: '対象偏差値（上限）',
                value: _recommendedUpperDev,
                onChanged: (v) => setState(() => _recommendedUpperDev = v),
                min: 30,
                max: 70,
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'コメント',
                  hintText: 'レビューコメント（最大300文字）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 300,
                validator: (value) {
                  if (value != null && value.length > 300) {
                    return 'コメントは300文字以内で入力してください';
                  }
                  return null; // コメントが空でもOKにする
                },
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _submitReview,
                child: const Text('レビューを保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
