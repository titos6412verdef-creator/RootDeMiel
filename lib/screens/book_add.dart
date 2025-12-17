import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../services/google_books_service.dart'; // Google Books APIサービス

// --- 科目アイテム ---
// name: 科目名
// indentLevel: 0=親科目、1=子科目（高校用）
class SubjectItem {
  final String name;
  final int indentLevel;
  SubjectItem(this.name, {this.indentLevel = 0});
}

// --- 書籍追加画面 ---
class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  // --- フォームキー ---
  final _formKey = GlobalKey<FormState>();

  // --- テキストコントローラー ---
  final _titleController = TextEditingController(); // 書籍名検索
  final _isbnController = TextEditingController(); // ISBN入力

  // --- ドロップダウン選択 ---
  String? _selectedEducationLevel; // 小・中・高
  String? _selectedSubject; // 単一の科目

  // --- 教育段階リスト ---
  final List<String> educationLevels = ['小学校', '中学校', '高校'];

  // --- 高校用科目と子科目のマップ ---
  final Map<String, List<String>?> highSchoolSubjectsMap = {
    '国語': ['現代文', '古文', '漢文'],
    '数学': null,
    '理科': ['物理', '化学', '生物', '地学'],
    '地歴': ['歴史総合', '日本史探究', '世界史探究', '地理総合', '地理探究'],
    '公共': ['公共', '倫理', '政治・経済'],
    '情報': null,
    '英語': ['英単語・熟語', 'リスニング', '英文法', '英文解釈', '長文読解', '英語総合'],
  };

  // --- 小中学校用科目マップ ---
  final Map<String, List<String>> subjectsByEducation = {
    '小学校': ['国語', '算数', '理科', '社会', '英語'],
    '中学校': ['国語', '数学', '理科', '社会', '英語'],
    '高校': [], // 高校は上のマップで処理
  };

  // --- 高校も含めた科目リストを取得 ---
  List<SubjectItem> getAvailableSubjects() {
    if (_selectedEducationLevel == '高校') {
      List<SubjectItem> subjects = [];
      for (final entry in highSchoolSubjectsMap.entries) {
        subjects.add(SubjectItem(entry.key, indentLevel: 0));
        for (final child in entry.value ?? []) {
          subjects.add(SubjectItem(child, indentLevel: 1));
        }
      }
      subjects.removeWhere((s) => s.name == '全教科');
      return subjects;
    } else if (_selectedEducationLevel != null) {
      final list = subjectsByEducation[_selectedEducationLevel] ?? [];
      return list
          .where((s) => s != '全教科')
          .map((s) => SubjectItem(s, indentLevel: 0))
          .toList();
    }
    return [];
  }

  // --- 検索結果管理 ---
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // --- 書籍検索（タイトル） ---
  Future<void> _searchBooksByTitle(String query) async {
    if (query.trim().length < 2) {
      // 2文字未満は検索しない
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await GoogleBooksApiService.searchBooksByTitle(
        query.trim(),
      );
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  // --- 書籍選択時の処理 ---
  void _selectBook(Map<String, dynamic> book) {
    setState(() {
      _titleController.text = book['display_title'] ?? book['title'] ?? '';
      _isbnController.text = book['isbn'] ?? '';
      _searchResults = [];
    });
  }

  bool _isLoading = false; // 保存中表示

  // --- 書籍追加処理 ---
  Future<void> _addBook() async {
    if (!_formKey.currentState!.validate()) return; // バリデーションチェック

    setState(() => _isLoading = true);

    final db = await DatabaseHelper.instance.database;

    final newIsbn = _isbnController.text.replaceAll('-', '').trim();

    if (newIsbn.isEmpty) {
      // ISBN必須チェック
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ISBNは必須です')));
      return;
    }

    // --- APIから書籍情報取得 ---
    Map<String, dynamic>? apiBookInfo;
    try {
      apiBookInfo = await GoogleBooksApiService.fetchBookInfoByIsbn(newIsbn);
    } catch (e) {
      apiBookInfo = null;
    }

    if (apiBookInfo == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ISBNから書籍情報を取得できませんでした。ISBNが正しいか確認してください。'),
        ),
      );
      return;
    }

    // --- ISBN重複チェック ---
    final existingIsbnBooks = await db.query(
      'Books',
      where: 'isbn = ?',
      whereArgs: [newIsbn],
    );
    if (existingIsbnBooks.isNotEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('このISBNはすでに登録されています')));
      return;
    }

    // --- 表示名重複チェック ---
    final titleFromApi = apiBookInfo['display_title'] as String? ?? '';
    final titleToUse = titleFromApi.isNotEmpty
        ? titleFromApi
        : _titleController.text.trim();

    final existingTitleBooks = await db.query(
      'Books',
      where: 'display_title = ?',
      whereArgs: [titleToUse],
    );
    if (existingTitleBooks.isNotEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('この表示名はすでに登録されています')));
      return;
    }

    // --- 保存用データ ---
    final educationToUse = _selectedEducationLevel;
    final subjectToUse = _selectedSubject ?? '';
    final pageCountFromApi = apiBookInfo['page_count'] as int?;
    final thumbnailUrlFromApi = apiBookInfo['thumbnail_url'] as String?;
    final now = DateTime.now().toIso8601String();

    try {
      final insertedId = await db.insert('Books', {
        'display_title': titleToUse,
        'official_title': apiBookInfo['official_title'] ?? '',
        'author': apiBookInfo['author'] ?? '',
        'education': educationToUse,
        'subject': subjectToUse,
        'page_count': pageCountFromApi,
        'isbn': newIsbn,
        'thumbnail_url': thumbnailUrlFromApi,
        'created_at': now,
        'updated_at': null,
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('書籍を追加しました (ID: $insertedId)')));
      Navigator.pop(context, insertedId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('書籍の保存に失敗しました: $e')));
    }
  }

  // --- デバッグ用：ポラリスシリーズ5冊追加 ---
  Future<void> _insertDebugBooks() async {
    final db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> debugBooks = [
      {
        'display_title': 'ポラリス1 英文法レベル1',
        'official_title': 'Polaris 英文法レベル1',
        'author': '関正生',
        'education': '高校',
        'subject': '英語',
        'page_count': 200,
        'isbn': '9784010347211',
        'thumbnail_url': null,
      },
      // 他4冊略（既存コード同様）
    ];

    for (final book in debugBooks) {
      final exists = await db.query(
        'Books',
        where: 'isbn = ?',
        whereArgs: [book['isbn']],
      );
      if (exists.isEmpty) {
        await db.insert('Books', {
          ...book,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': null,
        });
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('デバッグ用のポラリス5冊を追加しました')));
  }

  @override
  void initState() {
    super.initState();
    // タイトル入力変更時にAPI検索
    _titleController.addListener(() {
      _searchBooksByTitle(_titleController.text);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  // --- ビルドメソッド ---
  @override
  Widget build(BuildContext context) {
    final availableSubjects = getAvailableSubjects(); // 表示用科目リスト

    return Scaffold(
      appBar: AppBar(title: const Text('書籍の追加')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 書籍名入力（検索用）
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: '書籍名（検索用）'),
                    validator: (value) => null,
                  ),
                  if (_isSearching) const LinearProgressIndicator(),
                  // 検索結果表示
                  if (_searchResults.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final book = _searchResults[index];
                          return ListTile(
                            title: Text(
                              book['display_title'] ?? book['title'] ?? '',
                            ),
                            subtitle: Text(() {
                              final authors = book['authors'];
                              if (authors is List) return authors.join(', ');
                              if (authors is String) return authors;
                              return '';
                            }()),
                            onTap: () => _selectBook(book),
                          );
                        },
                      ),
                    ),
                  // ISBN入力
                  TextFormField(
                    controller: _isbnController,
                    decoration: const InputDecoration(labelText: 'ISBN'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'ISBNを入力してください';
                      }

                      final isbn = value.replaceAll('-', '').trim();

                      if (!RegExp(r'^\d{10}(\d{3})?$').hasMatch(isbn)) {
                        return '正しいISBNを入力してください（10桁または13桁）';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // 教育段階・科目選択
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: '教育段階'),
                          value: _selectedEducationLevel,
                          items: educationLevels
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedEducationLevel = val;
                              _selectedSubject = null;
                            });
                          },
                          validator: (value) =>
                              value == null ? '教育段階を選択してください' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: '科目'),
                          value:
                              availableSubjects
                                  .map((e) => e.name)
                                  .contains(_selectedSubject)
                              ? _selectedSubject
                              : null,
                          items: availableSubjects
                              .map(
                                (subjectItem) => DropdownMenuItem<String>(
                                  value: subjectItem.name,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: 16.0 * subjectItem.indentLevel,
                                    ),
                                    child: Text(subjectItem.name),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedSubject = val);
                          },
                          validator: (value) =>
                              value == null ? '科目を選択してください' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _addBook,
                    child: const Text('保存'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _insertDebugBooks,
                    child: const Text('デバッグ用：ポラリス5冊追加'),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
