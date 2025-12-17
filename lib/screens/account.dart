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
      setState(() => _linkedEmail = email);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログインしました')));
    } catch (e) {
      _showError('ログインに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      setState(() => _linkedEmail = email);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('アカウントを作成しました')));
    } catch (e) {
      _showError('登録に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout(UserProvider userProvider) async {
    setState(() => _loading = true);
    try {
      await userProvider.logout();
      await UserManager.clearCredentials();

      if (!mounted) return;
      setState(() => _linkedEmail = null);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログアウトしました')));
    } catch (e) {
      _showError('ログアウトに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('アカウント')),
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

                  /// ★ ここで分岐
                  _linkedEmail == null
                      ? _buildUnlinkedSection(userProvider)
                      : _buildLinkedSection(userProvider),
                ],
              ),
            ),
    );
  }

  // -----------------------------
  // 未ログイン時 UI
  // -----------------------------
  Widget _buildUnlinkedSection(UserProvider userProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),

        Center(
          child: ElevatedButton.icon(
            icon: Icon(
              _isRegisterSectionExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.person_add_alt,
            ),
            label: Text(
              _isRegisterSectionExpanded ? '新規アカウント作成を閉じる' : '新規アカウントを作成',
            ),
            onPressed: () {
              setState(() {
                _isRegisterSectionExpanded = !_isRegisterSectionExpanded;
              });
            },
          ),
        ),
        const SizedBox(height: 16),

        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isRegisterSectionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _emailControllerNew,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordControllerNew,
                decoration: const InputDecoration(labelText: 'パスワード'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'ユーザーネーム'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _birthDate == null
                          ? '生年月日を選択'
                          : '生年月日: '
                                '${_birthDate!.year}/'
                                '${_birthDate!.month}/'
                                '${_birthDate!.day}',
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
                      if (date != null) {
                        setState(() => _birthDate = date);
                      }
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
                onPressed: () => _linkWithEmail(userProvider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------------
  // ログイン済み UI
  // -----------------------------
  Widget _buildLinkedSection(UserProvider userProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('■ ログイン中', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('ログアウト'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: () => _logout(userProvider),
        ),
      ],
    );
  }
}
