// lib/screens/account_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/user_provider.dart';
import '../utils/user_manager.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // ログイン用
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 新規作成用
  final _emailControllerNew = TextEditingController();
  final _passwordControllerNew = TextEditingController();
  final _usernameController = TextEditingController();
  DateTime? _birthDate;
  bool _isTeacher = false;
  bool _isRegisterSectionExpanded = false;

  bool _loading = false;
  String? _linkedEmail;

  @override
  void initState() {
    super.initState();
    _loadLinkedEmail();
  }

  Future<void> _loadLinkedEmail() async {
    final credentials = await UserManager.getCredentials();
    if (!mounted) return;
    setState(() => _linkedEmail = credentials['email']);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  String _calcUserType() {
    if (_isTeacher) return '0';
    if (_birthDate == null) return 'other';

    final now = DateTime.now();
    final age =
        now.year -
        _birthDate!.year -
        ((now.month < _birthDate!.month ||
                (now.month == _birthDate!.month && now.day < _birthDate!.day))
            ? 1
            : 0);

    if (age >= 12 && age <= 15) return '1'; // 中学生
    if (age >= 16 && age <= 18) return '2'; // 高校生
    return '3'; // 社会人・浪人生
  }

  Future<void> _linkWithEmail(UserProvider userProvider) async {
    final email = _emailControllerNew.text.trim();
    final password = _passwordControllerNew.text.trim();
    final username = _usernameController.text.trim();
    final userType = _calcUserType();

    if (email.isEmpty ||
        password.isEmpty ||
        username.isEmpty ||
        _birthDate == null) {
      _showError('すべての項目を入力してください');
      return;
    }

    setState(() => _loading = true);
    try {
      final hashed = _hashPassword(password);
      await userProvider.linkWithEmail(email, hashed, username, userType);
      await UserManager.saveCredentials(email, password);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('アカウントを作成しました')));
      setState(() => _linkedEmail = email);
    } catch (e) {
      _showError('登録に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithEmail(UserProvider userProvider) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('メールアドレスとパスワードを入力してください');
      return;
    }

    setState(() => _loading = true);
    try {
      final hashed = _hashPassword(password);
      await userProvider.loginWithEmail(email, hashed);
      await UserManager.saveCredentials(email, password);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログインしました')));
      setState(() => _linkedEmail = email);
    } catch (e) {
      _showError('ログインに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('アカウント連携 / ログイン')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ユーザーネーム: ${userProvider.displayName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _linkedEmail != null ? '連携済み: $_linkedEmail' : 'アカウント未連携',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Divider(height: 32),
                  ..._buildUnlinkedSection(userProvider),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    '連携するとできること',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('- メールアドレスで同じアカウントにログイン可能'),
                  const Text('- 複数端末からデータを引き継ぎ可能'),
                  const Text('- 投稿したレビューや「いいね」を保持'),
                  const SizedBox(height: 16),
                  const Text(
                    'セキュリティについて',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('- メールアドレスやパスワードは暗号化され安全に保存されます'),
                  const Text('- 匿名ユーザーとしての利用も継続可能'),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildUnlinkedSection(UserProvider userProvider) => [
    // ▼ 既存ログイン
    const Text(
      "■ すでにアカウントをお持ちの方",
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    TextField(
      controller: _emailController,
      decoration: const InputDecoration(labelText: 'メールアドレス'),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _passwordController,
      decoration: const InputDecoration(labelText: 'パスワード'),
      obscureText: true,
    ),
    const SizedBox(height: 12),
    ElevatedButton.icon(
      icon: const Icon(Icons.login),
      label: const Text('ログイン'),
      onPressed: () => _loginWithEmail(userProvider),
    ),
    const SizedBox(height: 28),
    const Divider(),
    const SizedBox(height: 16),

    // ▼ 新規作成折りたたみボタン
    Center(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orangeAccent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          _isRegisterSectionExpanded
              ? Icons.keyboard_arrow_up
              : Icons.person_add_alt,
          size: 24,
        ),
        label: Text(
          _isRegisterSectionExpanded ? '新規アカウント作成を閉じる' : '新規アカウントを作成',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          setState(
            () => _isRegisterSectionExpanded = !_isRegisterSectionExpanded,
          );
        },
      ),
    ),
    const SizedBox(height: 16),

    // ▼ 展開セクション
    AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState: _isRegisterSectionExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: const SizedBox.shrink(),
      secondChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 新規メール
          TextField(
            controller: _emailControllerNew,
            decoration: const InputDecoration(labelText: 'メールアドレス'),
          ),
          const SizedBox(height: 12),
          // 新規パスワード
          TextField(
            controller: _passwordControllerNew,
            decoration: const InputDecoration(labelText: 'パスワード'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          // ユーザーネーム
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'ユーザーネーム'),
          ),
          const SizedBox(height: 12),
          // 生年月日
          Row(
            children: [
              Expanded(
                child: Text(
                  _birthDate == null
                      ? '生年月日を選択'
                      : '生年月日: ${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}',
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2005),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _birthDate = date);
                },
                child: const Text('選択'),
              ),
            ],
          ),
          CheckboxListTile(
            title: const Text('教職員 / 塾関係者です'),
            value: _isTeacher,
            onChanged: (val) {
              setState(() => _isTeacher = val ?? false);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('新規アカウントを作成'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 64, 255, 163),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () => _linkWithEmail(userProvider),
          ),
        ],
      ),
    ),
  ];
}
