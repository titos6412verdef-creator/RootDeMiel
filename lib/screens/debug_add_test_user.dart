// lib/screens/debug_add_test_user.dart
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../db/database_helper.dart';

/// デバッグ用画面: 複数テストユーザーをSQLiteに追加/更新
/// - 既存匿名ユーザーにもメール・パスワードを設定
/// - UUID風の固定 user_id を使用
/// - 管理者アカウントも追加
class DebugAddTestUserScreen extends StatefulWidget {
  const DebugAddTestUserScreen({super.key});

  @override
  State<DebugAddTestUserScreen> createState() => _DebugAddTestUserScreenState();
}

class _DebugAddTestUserScreenState extends State<DebugAddTestUserScreen> {
  bool _added = false;
  String _message = '';

  Future<void> _addTestUsers() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 追加/更新対象ユーザー（UUID風 user_id を固定）
      final users = [
        // 管理者アカウント
        {
          'email': 't.ito.s6412.verfe@gmail.com',
          'password': 'tokihaima0102',
          'username': '管理者',
          'user_id': '00000000-0000-0000-0000-000000000000',
          'user_type': 'admin', // 特別権限
        },
        {
          'email': 'test_user1_new@example.com',
          'password': 'password123',
          'username': 'テストユーザー1',
          'user_id': '11111111-1111-1111-1111-111111111111',
        },
        {
          'email': 'test_user2_new@example.com',
          'password': 'password123',
          'username': 'テストユーザー2',
          'user_id': '22222222-2222-2222-2222-222222222222',
        },
        {
          'email': 'test_user3_new@example.com',
          'password': 'password123',
          'username': 'テストユーザー3',
          'user_id': '33333333-3333-3333-3333-333333333333',
        },
        {
          'email': 'anon1_new@example.com',
          'password': 'password123',
          'username': '匿名ラッコ',
          'user_id': '44444444-4444-4444-4444-444444444444',
        },
        {
          'email': 'anon2_new@example.com',
          'password': 'password123',
          'username': '匿名ラッコ',
          'user_id': '55555555-5555-5555-5555-555555555555',
        },
        {
          'email': 'anon3_new@example.com',
          'password': 'password123',
          'username': '匿名ラッコ',
          'user_id': '66666666-6666-6666-6666-666666666666',
        },
      ];

      final List<String> addedUsers = [];

      for (final u in users) {
        final hashedPassword = sha256
            .convert(utf8.encode(u['password']!))
            .toString();

        final userId = u['user_id']!;
        final existing = await db.query(
          'Users',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        final userType = u['user_type'] ?? 'other';

        if (existing.isNotEmpty) {
          // 更新
          await db.update(
            'Users',
            {
              'username': u['username'],
              'email': u['email'],
              'password_hash': hashedPassword,
              'user_type': userType,
              'account_status': 1,
              'is_public': 1,
            },
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          debugPrint(
            '[DebugAddTestUser] Updated $userId / email=${u['email']}',
          );
        } else {
          // 新規追加
          await db.insert('Users', {
            'user_id': userId,
            'username': u['username'],
            'user_type': userType,
            'email': u['email'],
            'password_hash': hashedPassword,
            'created_at': DateTime.now().toIso8601String(),
            'account_status': 1,
            'is_public': 1,
          });
          debugPrint('[DebugAddTestUser] Added ${u['email']} / userId=$userId');
        }

        addedUsers.add('${u['username']} / ${u['email']} / ${u['password']}');
      }

      // 全ユーザー確認
      final allUsers = await db.query('Users');
      debugPrint('Users table after insert/update: $allUsers');

      setState(() {
        _added = true;
        _message = 'テストユーザーを追加/更新しました:\n${addedUsers.join('\n')}';
      });
    } catch (e, st) {
      debugPrint('Error in _addTestUsers: $e\n$st');
      setState(() {
        _added = false;
        _message = '追加に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('デバッグ: テストユーザー追加')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _added ? null : _addTestUsers,
              child: const Text('テストユーザーを追加する'),
            ),
            const SizedBox(height: 24),
            Text(_message),
          ],
        ),
      ),
    );
  }
}
