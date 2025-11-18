import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'edit_book.dart';
import '../widgets/subject_selector.dart';

/// 書籍管理画面
/// 書籍の一覧表示、検索、フィルタリング、編集、削除を行う
class ManageBooksScreen extends StatefulWidget {
  const ManageBooksScreen({super.key});

  @override
  State<ManageBooksScreen> createState() => _ManageBooksScreenState();
}

class _ManageBooksScreenState extends State<ManageBooksScreen> {
  List<Map<String, dynamic>> _books = []; // 表示中の書籍データ
  String _searchQuery = ''; // 検索キーワード
  String _selectedEducationLevel = '高校'; // 選択中の学年
  List<String> _selectedSubjects = ['全教科']; // 選択中の科目

  @override
  void initState() {
    super.initState();
    _fetchBooks(); // 初期表示用に書籍データを取得
  }

  /// データベースから書籍を取得（検索・フィルター適用）
  Future<void> _fetchBooks() async {
    final db = await DatabaseHelper.instance.database;
    String where = '';
    List<dynamic> whereArgs = [];

    // 検索キーワードがある場合、display_title または official_title にマッチするものを取得
    if (_searchQuery.isNotEmpty) {
      where += '(display_title LIKE ? OR official_title LIKE ?)';
      whereArgs.addAll(['%$_searchQuery%', '%$_searchQuery%']);
    }

    // 選択中の教育レベルでフィルタ
    if (_selectedEducationLevel.isNotEmpty) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'education = ?';
      whereArgs.add(_selectedEducationLevel);
    }

    // 科目フィルタ（「全教科」でない場合のみ適用）
    if (!_selectedSubjects.contains('全教科')) {
      if (where.isNotEmpty) where += ' AND ';
      final placeholders = List.filled(
        _selectedSubjects.length,
        '?',
      ).join(', ');
      where += 'subject IN ($placeholders)';
      whereArgs.addAll(_selectedSubjects);
    }

    // データベースから取得
    final books = await db.query(
      'Books',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'display_title ASC',
    );

    // 画面表示中なら State を更新
    if (mounted) {
      setState(() {
        _books = books;
      });
    }
  }

  /// 検索・フィルターUIの構築
  Widget _buildFilters() {
    return Column(
      children: [
        // 検索TextField
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'タイトルで検索',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _fetchBooks();
            },
          ),
        ),
        // 教育レベル・科目フィルター
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: EducationSubjectSelector(
            initialEducationLevel: _selectedEducationLevel,
            initialSubject: _selectedSubjects.length == 1
                ? _selectedSubjects.first
                : null,
            onSelectionChanged: (educationLevel, subjects) {
              setState(() {
                _selectedEducationLevel =
                    educationLevel ?? _selectedEducationLevel;
                _selectedSubjects = (subjects != null && subjects.isNotEmpty)
                    ? subjects
                    : ['全教科'];
              });
              _fetchBooks();
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('書籍管理'),
        actions: [
          // 書籍追加ボタン
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '書籍追加',
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/add-book');
              if (result == true) _fetchBooks();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(), // 検索・フィルターUI
          Expanded(
            child: _books.isEmpty
                ? const Center(child: Text('登録されている書籍がありません'))
                : ListView.builder(
                    itemCount: _books.length,
                    itemBuilder: (context, index) {
                      final book = _books[index];
                      final bookIdInt = book['book_id'] as int;

                      return GestureDetector(
                        onTap: () async {
                          // 書籍編集画面へ遷移
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditBookScreen(bookId: bookIdInt),
                            ),
                          );
                          if (updated == true) _fetchBooks();
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 書籍情報
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 書籍ID表示
                                      Text(
                                        'ID: $bookIdInt',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // 表示タイトル
                                      Text(
                                        book['display_title'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // 正式タイトル（あれば表示）
                                      if ((book['official_title'] ?? '')
                                          .isNotEmpty)
                                        Text(
                                          book['official_title'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      // 削除ボタン（管理者のみ）
                                      Row(
                                        children: [
                                          if (DatabaseHelper.currentUserType ==
                                              'admin')
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _deleteBook(bookIdInt),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              child: const Text('削除'),
                                            ),
                                          if (DatabaseHelper.currentUserType ==
                                              'admin')
                                            const SizedBox(width: 8),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // サムネイル表示
                                Container(
                                  width: 120,
                                  height: 140,
                                  color: Colors.grey.shade200,
                                  child:
                                      (book['thumbnail_url'] != null &&
                                          (book['thumbnail_url'] as String)
                                              .isNotEmpty)
                                      ? Image.network(
                                          book['thumbnail_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Image.asset(
                                                  'assets/images/no-image.jpg',
                                                  fit: BoxFit.cover,
                                                );
                                              },
                                        )
                                      : Image.asset(
                                          'assets/images/no-image.jpg',
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 書籍削除処理（確認ダイアログ付き）
  Future<void> _deleteBook(int bookId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: const Text('この書籍を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('Books', where: 'book_id = ?', whereArgs: [bookId]);
      if (mounted) {
        // 削除成功メッセージ
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('書籍を削除しました')));
        _fetchBooks(); // 削除後に一覧を更新
      }
    }
  }
}
