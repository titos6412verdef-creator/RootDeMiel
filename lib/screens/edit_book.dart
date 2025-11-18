import 'package:flutter/material.dart';
import '../models/book.dart';
import '../db/database_helper.dart';
import '../widgets/subject_selector.dart';
import '../services/google_books_service.dart';

class EditBookScreen extends StatefulWidget {
  final int bookId; // 編集対象の書籍ID

  const EditBookScreen({super.key, required this.bookId});

  @override
  State<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends State<EditBookScreen> {
  // フォーム全体の状態を管理
  final _formKey = GlobalKey<FormState>();

  // 編集対象の書籍情報
  Book? _book;

  // フォーム入力用コントローラー
  final TextEditingController _displayTitleController = TextEditingController();
  final TextEditingController _officialTitleController =
      TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _publisherController = TextEditingController();
  final TextEditingController _pageCountController = TextEditingController();

  // 教育レベルと科目選択
  String? _selectedEducation;
  List<String>? _selectedSubjects;

  // APIから取得したサムネイルURL
  String? _apiThumbnailUrl;

  // 読み込み中フラグ
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 初期表示時にDBから書籍情報を取得
    _loadBook();
  }

  /// 書籍情報をDBから読み込み、フォームに反映する
  Future<void> _loadBook() async {
    final book = await DatabaseHelper.instance.getBookById(widget.bookId);

    if (!mounted) return; // ウィジェット破棄済みの場合は終了

    if (book == null) {
      // 書籍が存在しない場合はメッセージ表示して前画面に戻る
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('書籍が見つかりませんでした')));
      Navigator.pop(context);
      return;
    }

    // フォームコントローラーに値をセット
    _displayTitleController.text = book.displayTitle;
    _officialTitleController.text = book.officialTitle ?? '';
    _authorController.text = book.author ?? '';
    _publisherController.text = book.publisher ?? '';
    _pageCountController.text = book.pageCount?.toString() ?? '';

    // Stateに反映
    setState(() {
      _book = book;
      _selectedEducation = (book.education?.isNotEmpty ?? false)
          ? book.education
          : null;
      _selectedSubjects = (book.subject != null && book.subject!.isNotEmpty)
          ? book.subject!.split(',').map((s) => s.trim()).toList()
          : null;
      _apiThumbnailUrl = book.thumbnailUrl;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    // コントローラー破棄
    _displayTitleController.dispose();
    _officialTitleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _pageCountController.dispose();
    super.dispose();
  }

  /// 全角数字を半角数字に変換
  String _zenkakuToHankakuNumber(String input) {
    const zenkakuNums = '０１２３４５６７８９';
    const hankakuNums = '0123456789';
    var output = '';
    for (final c in input.characters) {
      final index = zenkakuNums.indexOf(c);
      output += (index >= 0) ? hankakuNums[index] : c;
    }
    return output;
  }

  /// 書籍情報をDBに保存（更新）
  Future<void> _updateBook() async {
    if (!_formKey.currentState!.validate() || _book == null) return;

    // ページ数を半角に変換して整数に
    final pageCountStr = _zenkakuToHankakuNumber(
      _pageCountController.text.trim(),
    );
    final int? pageCount = pageCountStr.isEmpty
        ? null
        : int.tryParse(pageCountStr);

    // ページ数が不正な場合はエラー表示
    if (pageCountStr.isNotEmpty && pageCount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ページ数は数字で入力してください')));
      return;
    }

    // 科目をカンマ区切り文字列に変換
    final subjectString =
        (_selectedSubjects == null || _selectedSubjects!.isEmpty)
        ? ''
        : _selectedSubjects!.join(',');

    // DBに書籍情報を更新
    await DatabaseHelper.instance.updateBook(
      bookId: _book!.bookId!,
      displayTitle: _displayTitleController.text.trim(),
      officialTitle: _officialTitleController.text.trim(),
      author: _authorController.text.trim(),
      publisher: _publisherController.text.trim(),
      pageCount: pageCount,
      education: _selectedEducation ?? '',
      subject: subjectString,
      thumbnailUrl: _apiThumbnailUrl ?? _book!.thumbnailUrl,
    );

    if (!mounted) return;
    // 更新完了メッセージ表示
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('書籍情報を更新しました')));
    // 前画面に戻る（trueを返すと更新完了を通知）
    Navigator.pop(context, true);
  }

  /// 指定フィールドをGoogle Books APIから取得してフォームを更新
  Future<void> _fetchAndUpdateField(String field) async {
    if (_book == null) return;

    final isbn = _book!.isbn ?? '';
    if (isbn.isEmpty) {
      if (!mounted) return;
      // ISBN未登録の場合は取得不可
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ISBNが未登録のため取得できません')));
      return;
    }

    // 現在の値を取得
    dynamic currentValue;
    switch (field) {
      case 'author':
        currentValue = _authorController.text;
        break;
      case 'publisher':
        currentValue = _publisherController.text;
        break;
      case 'pageCount':
        currentValue = _pageCountController.text;
        break;
      case 'thumbnailUrl':
        currentValue = _apiThumbnailUrl;
        break;
      default:
        currentValue = null;
    }

    // 既存値がある場合は上書き確認
    if (currentValue != null && currentValue.toString().isNotEmpty) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('上書き確認'),
          content: Text('$field は既に値があります。上書きしますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('上書き'),
            ),
          ],
        ),
      );
      if (overwrite != true) return;
    }

    // APIからデータ取得
    final fetched = await GoogleBooksApiService.fetchBookInfoByIsbn(isbn);
    if (fetched == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('APIからデータを取得できませんでした')));
      return;
    }

    // デバッグ出力
    debugPrint('=== Google Books API fetched data ===');
    debugPrint(fetched.toString());
    debugPrint('page_count: ${fetched['page_count']}');

    // 取得データをフォームに反映
    if (!mounted) return;
    setState(() {
      switch (field) {
        case 'author':
          _authorController.text = fetched['author'] ?? '';
          break;
        case 'publisher':
          _publisherController.text = fetched['publisher'] ?? '';
          break;
        case 'pageCount':
          final pc = fetched['page_count'];
          _pageCountController.text = (pc != null && pc > 0)
              ? pc.toString()
              : '';
          break;
        case 'thumbnailUrl':
          _apiThumbnailUrl = fetched['thumbnail_url'] ?? '';
          break;
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$field を更新しました')));
  }

  /// 入力フィールドとAPI取得ボタンを横並びで表示する
  Widget _buildDetailRowWithButton(
    String label,
    Widget inputWidget,
    String field,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 入力欄
        Expanded(child: inputWidget),
        // API取得ボタン
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '$label をAPIから取得',
          onPressed: () => _fetchAndUpdateField(field),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // 読み込み中はプログレス表示
      return Scaffold(
        appBar: AppBar(title: const Text('書籍の詳細')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // メイン画面
    return Scaffold(
      appBar: AppBar(title: const Text('書籍の詳細')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 書籍ID表示
              Text(
                '書籍ID: ${_book!.bookId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // サムネイル画像とAPI取得ボタン
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(
                      (_apiThumbnailUrl != null && _apiThumbnailUrl!.isNotEmpty)
                          ? _apiThumbnailUrl!
                          : 'assets/images/no-image.jpg',
                      height: 120,
                      width: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/no-image.jpg',
                        height: 120,
                        width: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          '自動取得',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'サムネイルをAPIから取得',
                          onPressed: () => _fetchAndUpdateField('thumbnailUrl'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 表示タイトル入力
              TextFormField(
                controller: _displayTitleController,
                decoration: const InputDecoration(labelText: '表示タイトル'),
                validator: (value) =>
                    value == null || value.isEmpty ? '入力してください' : null,
              ),
              const SizedBox(height: 8),
              // 正式タイトル入力
              TextFormField(
                controller: _officialTitleController,
                decoration: const InputDecoration(labelText: '正式タイトル'),
              ),
              const SizedBox(height: 20),
              // API取得ラベル
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '自動取得',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
              // 著者入力＋API取得ボタン
              _buildDetailRowWithButton(
                '著者',
                TextFormField(
                  controller: _authorController,
                  decoration: const InputDecoration(labelText: '著者'),
                  validator: (value) => null,
                ),
                'author',
              ),
              const SizedBox(height: 12),
              // 出版社入力＋API取得ボタン
              _buildDetailRowWithButton(
                '出版社',
                TextFormField(
                  controller: _publisherController,
                  decoration: const InputDecoration(labelText: '出版社'),
                  validator: (value) => null,
                ),
                'publisher',
              ),
              const SizedBox(height: 12),
              // ページ数入力＋API取得ボタン
              _buildDetailRowWithButton(
                'ページ数',
                TextFormField(
                  controller: _pageCountController,
                  decoration: const InputDecoration(labelText: 'ページ数'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final converted = _zenkakuToHankakuNumber(value.trim());
                    if (!RegExp(r'^\d+$').hasMatch(converted)) {
                      return '数字のみで入力してください';
                    }
                    return null;
                  },
                ),
                'pageCount',
              ),
              const SizedBox(height: 20),
              // 教科・科目選択
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
              const SizedBox(height: 30),
              // 修正ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _updateBook,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('修正', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
