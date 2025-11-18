import 'package:flutter/material.dart';

/// HomeScreen から呼び出せるターミナル用Widget版
class UserGuideWidget extends StatelessWidget {
  const UserGuideWidget({
    super.key,
    this.onBack,
    this.onShowEvaluationItems, // 追加
  });

  /// 戻るボタン押下時のコールバック
  final VoidCallback? onBack;

  /// 「評価項目について」を Home 内で表示する場合のコールバック
  final VoidCallback? onShowEvaluationItems;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アプリの使い方・用語解説')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          UserCard(
            title: '評価項目について',
            icon: Icons.analytics,
            description: '「用語説明の丁寧さ」や「実践問題の多さ」などの評価項目が何を示しているかを確認できます。',
            onTap:
                onShowEvaluationItems ??
                () {
                  Navigator.pushNamed(context, '/evaluationItems');
                },
          ),

          UserCard(
            title: '参考書の選び方',
            icon: Icons.menu_book,
            description: '補強ポイントがわかったら、どの参考書を選ぶと効率的かの指針を示します。',
            onTap: () {
              Navigator.pushNamed(context, '/bookSelection');
            },
          ),
          UserCard(
            title: 'アプリの使い方',
            icon: Icons.compare,
            description: 'アプリの使い方についてざっくり説明しています。。',
            onTap: () {
              Navigator.pushNamed(context, '/APPGuide');
            },
          ),
        ],
      ),
    );
  }
}

/// ターミナル用カードコンポーネント
class UserCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;

  const UserCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.grey.shade300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  // deprecated 回避: withAlpha
                  color: Theme.of(
                    context,
                  ).primaryColor.withAlpha((0.1 * 255).round()),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
