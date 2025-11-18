// lib/screens/user_profile.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/user_provider.dart';
import '../widgets/review_card.dart';
import '../db/database_helper.dart';
import 'my_picks_detail.dart';
import 'account.dart';
import 'debug_add_test_user.dart';

// ユーザープロフィール画面
class UserProfileScreen extends StatefulWidget {
  final VoidCallback? onShowUserGuide;

  const UserProfileScreen({super.key, this.onShowUserGuide});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // --- 自分のレビューリスト ---
  List<Map<String, dynamic>> _myReviews = [];
  bool _isLoading = true; // ロード中フラグ

  // --- プロフィール情報 ---
  String? _thumbnailUrl;
  String? _userType;
  int? _points;
  String? _profile;
  String? _snsId;
  int _isPublic = 0;

  // --- おすすめセット ---
  List<Map<String, dynamic>> _recommendationSets = [];
  bool _setsLoading = true; // セットロード中フラグ

  @override
  void initState() {
    super.initState();
    // 初期データ読み込み
    _loadMyReviews(); // 投稿レビュー取得
    _loadUserProfile(); // ユーザー情報取得
    _loadBookSetTemplates(); // おすすめセット取得
  }

  // ------------------------
  // 投稿レビュー取得
  // ------------------------
  Future<void> _loadMyReviews() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final db = await DatabaseHelper.instance.database;

    // ユーザーIDでReviewsテーブルを検索
    final reviews = await db.query(
      'Reviews',
      where: 'user_id = ?',
      whereArgs: [userProvider.userId],
      orderBy: 'created_at DESC',
    );

    // デバッグ用出力
    debugPrint('--- _loadMyReviews result ---');
    for (var r in reviews) {
      debugPrint(r.toString());
    }

    if (!mounted) return; // <- 非同期処理後にBuildContextを使う前にチェック

    setState(() {
      _myReviews = reviews;
      _isLoading = false;
    });
  }

  // ------------------------
  // ユーザー情報取得
  // ------------------------
  Future<void> _loadUserProfile() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final db = await DatabaseHelper.instance.database;

    final results = await db.query(
      'Users',
      where: 'user_id = ?',
      whereArgs: [userProvider.userId],
      limit: 1,
    );

    if (!mounted) return; // <- 非同期処理後にBuildContextを使う前にチェック

    if (results.isNotEmpty) {
      final data = results.first;
      setState(() {
        _thumbnailUrl = data['thumbnail_url'] as String?;
        _userType = data['user_type'] as String?;
        _points = data['points'] as int? ?? 0;
        _profile = data['profile'] as String? ?? '';
        _snsId = data['sns_id'] as String? ?? '';
        _isPublic = data['is_public'] as int? ?? 0;
      });
    }
  }

  // ------------------------
  // プロフィールの個別フィールド更新
  // ------------------------
  Future<void> _updateUserField(String column, dynamic value) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final db = await DatabaseHelper.instance.database;

    // Usersテーブルを更新
    await db.update(
      'Users',
      {column: value},
      where: 'user_id = ?',
      whereArgs: [userProvider.userId],
    );

    if (!mounted) return; // <- 非同期処理後にBuildContextを使う前にチェック

    // ローカルステートも更新
    setState(() {
      switch (column) {
        case 'thumbnail_url':
          _thumbnailUrl = value;
          break;
        case 'user_type':
          _userType = value;
          break;
        case 'profile':
          _profile = value;
          break;
        case 'sns_id':
          _snsId = value;
          break;
        case 'username':
          _displayNameUpdate(value); // Providerにも反映
          break;
        case 'is_public':
          _isPublic = value;
          break;
      }
    });
  }

  // Provider上の表示名更新
  Future<void> _displayNameUpdate(String newName) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.setDisplayName(newName);
  }

  // ------------------------
  // おすすめセット取得（カバー画像URL付）
  // ------------------------
  Future<void> _loadBookSetTemplates() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final db = await DatabaseHelper.instance.database;

    // SQLでUserBookSetsとBooksを結合しカバー画像取得
    final result = await db.rawQuery(
      '''
    SELECT r.rec_set_id,
           MAX(r.set_index)    AS set_index,
           MAX(r.title)        AS title,
           MAX(r.description)  AS description,
           MAX(r.color_tag)    AS color_tag,
           MAX(r.is_public)    AS is_public,
           MAX(r.cover_book_id) AS cover_book_id,
           COALESCE(b.thumbnail_url, 'assets/images/no-image.jpg') AS cover_url
    FROM UserBookSets r
    LEFT JOIN Books b
      ON r.cover_book_id = b.book_id
    WHERE r.user_id = ?
    GROUP BY r.rec_set_id
    ORDER BY set_index ASC
    ''',
      [userProvider.userId],
    );

    if (!mounted) return; // <- 非同期処理後にBuildContextを使う前にチェック

    setState(() {
      _recommendationSets = result;
      _setsLoading = false;
    });
  }

  // ------------------------
  // セット削除
  // ------------------------
  Future<void> _deleteSet(int recSetId) async {
    // 削除確認ダイアログ
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('このセットを削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'UserBookSets',
      where: 'rec_set_id = ?',
      whereArgs: [recSetId],
    );
    await db.delete(
      'BookSetTemplates',
      where: 'rec_set_id = ?',
      whereArgs: [recSetId],
    );
    await _loadBookSetTemplates();
  }

  // ------------------------
  // セット編集ダイアログ（タイトル・説明・色タグ）
  // ------------------------
  void _editSetDialog(Map<String, dynamic> set) {
    final titleController = TextEditingController(text: set['title']);
    final descController = TextEditingController(text: set['description']);
    final colorController = TextEditingController(text: set['color_tag']);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('セットを編集'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'セット名'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '説明'),
                  maxLines: 2,
                ),
                TextField(
                  controller: colorController,
                  decoration: const InputDecoration(labelText: '色タグ'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                final newDesc = descController.text.trim();
                final newColor = colorController.text.trim();
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                final db = await DatabaseHelper.instance.database;

                // 更新処理
                await db.update(
                  'UserBookSets',
                  {
                    'title': newTitle,
                    'description': newDesc,
                    'color_tag': newColor,
                  },
                  where: 'rec_set_id = ? AND user_id = ?',
                  whereArgs: [set['rec_set_id'], userProvider.userId],
                );

                Navigator.pop(context);
                await _loadBookSetTemplates();
              },
              child: const Text('更新'),
            ),
          ],
        );
      },
    );
  }

  // ------------------------
  // セットの並び替え（上／下移動）
  // ------------------------
  Future<void> _moveSet(int recSetId, int direction) async {
    final db = await DatabaseHelper.instance.database;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final current = _recommendationSets.firstWhere(
      (s) => s['rec_set_id'] == recSetId,
    );
    final currentIndex = current['set_index'] as int;
    final newIndex = currentIndex + direction;
    if (newIndex < 1 || newIndex > _recommendationSets.length) return;

    final swapTarget = _recommendationSets.firstWhere(
      (s) => s['set_index'] == newIndex,
    );

    // トランザクションで順序入れ替え
    await db.transaction((txn) async {
      await txn.update(
        'UserBookSets',
        {'set_index': currentIndex},
        where: 'rec_set_id = ? AND user_id = ?',
        whereArgs: [swapTarget['rec_set_id'], userProvider.userId],
      );

      await txn.update(
        'UserBookSets',
        {'set_index': newIndex},
        where: 'rec_set_id = ? AND user_id = ?',
        whereArgs: [recSetId, userProvider.userId],
      );
    });

    await _loadBookSetTemplates();
  }

  // ------------------------
  // セットの公開／非公開切替
  // ------------------------
  Future<void> _toggleSetVisibility(int recSetId, int current) async {
    final db = await DatabaseHelper.instance.database;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final newValue = current == 1 ? 0 : 1;

    await db.update(
      'UserBookSets',
      {'is_public': newValue},
      where: 'rec_set_id = ? AND user_id = ?',
      whereArgs: [recSetId, userProvider.userId],
    );

    await _loadBookSetTemplates();
  }

  // ------------------------
  // メインビルド
  // ------------------------
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(), // プロフィール画像
            const SizedBox(height: 16),
            _buildProfileInfo(), // ユーザー情報
            const SizedBox(height: 16),

            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'あなたの投稿レビュー',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 投稿レビュー表示
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_myReviews.isEmpty)
              const Text('まだ投稿したレビューはありません。')
            else
              Column(
                children: _myReviews.map((review) {
                  debugPrint(
                    'Rendering ReviewCard: ${review['review_id']} / ${review['book_id']}',
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ReviewCard(
                      item: review,
                      selectedBookIds: [],
                      onCompareChanged: (bookId, isAdded) {},
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'あなたのおすすめセット',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // おすすめセット表示
            _setsLoading
                ? const Center(child: CircularProgressIndicator())
                : _recommendationSets.isEmpty
                ? const Text('まだ作成したセットはありません。')
                : Column(
                    children: _recommendationSets.map((set) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          onTap: () {
                            // セット詳細画面に遷移
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MyPicksDetailScreen(
                                  recSetId: set['rec_set_id'],
                                  title: set['title'],
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              // カバー画像
                              Container(
                                width: MediaQuery.of(context).size.width * 0.3,
                                height: 120,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: set['cover_url'].startsWith('http')
                                        ? NetworkImage(set['cover_url'])
                                        : AssetImage(set['cover_url'])
                                              as ImageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // セット情報
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // タイトル＋編集ボタン
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              set['title'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 18,
                                            ),
                                            onPressed: () =>
                                                _editSetDialog(set),
                                          ),
                                        ],
                                      ),
                                      // 公開状況＋公開スイッチ
                                      Row(
                                        children: [
                                          Text(
                                            set['is_public'] == 1 &&
                                                    _isPublic == 1
                                                ? '公開中'
                                                : '非公開',
                                          ),
                                          const SizedBox(width: 8),
                                          Switch(
                                            value:
                                                set['is_public'] == 1 &&
                                                _isPublic == 1,
                                            onChanged: _isPublic == 1
                                                ? (_) => _toggleSetVisibility(
                                                    set['rec_set_id'],
                                                    set['is_public'],
                                                  )
                                                : null,
                                          ),
                                          if (_isPublic != 1)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                left: 4.0,
                                              ),
                                              child: Icon(
                                                Icons.lock,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                      // 並び替え・削除ボタン
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.arrow_upward,
                                            ),
                                            onPressed: () =>
                                                _moveSet(set['rec_set_id'], -1),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.arrow_downward,
                                            ),
                                            onPressed: () =>
                                                _moveSet(set['rec_set_id'], 1),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () =>
                                                _deleteSet(set['rec_set_id']),
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
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // ------------------------
  // プロフィール画像表示
  // ------------------------
  Widget _buildProfileHeader() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: _thumbnailUrl != null && _thumbnailUrl!.isNotEmpty
                ? NetworkImage(_thumbnailUrl!)
                : null,
            child: _thumbnailUrl == null || _thumbnailUrl!.isEmpty
                ? const Icon(Icons.person, size: 40)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () =>
                  _editFieldDialog('サムネイルURL', 'thumbnail_url', _thumbnailUrl),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------
  // プロフィール情報表示
  // ------------------------
  Widget _buildProfileInfo() {
    final userProvider = Provider.of<UserProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ユーザーネーム＋編集
        Row(
          children: [
            Expanded(
              child: Text(
                'ユーザーネーム: ${userProvider.displayName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editFieldDialog(
                'ユーザーネーム',
                'username',
                userProvider.displayName,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // ユーザーID表示
        Text(
          'ユーザーID: ${userProvider.userId}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),

        // SNS連携ID＋編集
        Row(
          children: [
            Expanded(
              child: Text(
                'SNS連携ID: ${_snsId ?? ''}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editFieldDialog('SNS連携ID', 'sns_id', _snsId),
            ),
          ],
        ),

        // ユーザー種別＋編集
        Row(
          children: [
            Expanded(
              child: Text(
                'ユーザー種別: ${_userType ?? '未選択'}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editFieldDialog(
                'ユーザー種別',
                'user_type',
                _userType,
                isDropdown: true,
              ),
            ),
          ],
        ),

        // ポイント表示
        Row(
          children: [
            Expanded(
              child: Text(
                'ポイント: ${_points ?? 0}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),

        // 自己紹介＋編集
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '自己紹介: ${_profile ?? ''}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editFieldDialog(
                '自己紹介',
                'profile',
                _profile,
                multiline: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // プロフィール公開設定スイッチ
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            title: const Text(
              'プロフィール公開設定',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            subtitle: Text(
              _isPublic == 1 ? '公開中' : '非公開',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            value: _isPublic == 1,
            onChanged: (val) async {
              final newValue = val ? 1 : 0;
              await _updateUserField('is_public', newValue);
            },
            activeColor: Colors.indigo,
            activeTrackColor: Colors.indigo[100],
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[300],
            contentPadding: EdgeInsets.zero,
          ),
        ),

        // アカウント連携 / ログインボタン
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.account_circle),
            label: const Text('アカウント連携 / ログイン'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ).then((_) async {
                // 戻ったときに再読み込み
                await _loadBookSetTemplates();
                await _loadMyReviews();
                await _loadUserProfile();
              });
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // デバッグ用: テストユーザー追加
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bug_report),
            label: const Text('デバッグ: テストユーザー追加'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DebugAddTestUserScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // 管理者用: 書籍管理画面ボタン
        if (_userType == 'admin')
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.library_books),
              label: const Text('書籍データ管理'),
              onPressed: () {
                Navigator.pushNamed(context, '/manage-books');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------
  // フィールド編集ダイアログ
  // ------------------------
  void _editFieldDialog(
    String label,
    String column,
    String? initialValue, {
    bool multiline = false,
    bool isDropdown = false,
  }) {
    String? selectedValue = initialValue;
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('$label を編集'),
          content: isDropdown
              ? StatefulBuilder(
                  builder: (context, setState) {
                    final options = ['中高生', '大学生', '学校関係者', '塾関係者', 'その他'];
                    return DropdownButton<String>(
                      isExpanded: true,
                      value: selectedValue,
                      hint: const Text('選択してください'),
                      items: options
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedValue = val;
                        });
                      },
                    );
                  },
                )
              : TextField(
                  controller: controller,
                  decoration: InputDecoration(labelText: label),
                  maxLines: multiline ? 6 : 1,
                  maxLength: multiline ? 400 : null,
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = isDropdown ? selectedValue : controller.text;
                if (value != null) {
                  await _updateUserField(column, value);
                }
                Navigator.pop(context);
              },
              child: const Text('更新'),
            ),
          ],
        );
      },
    );
  }
}
