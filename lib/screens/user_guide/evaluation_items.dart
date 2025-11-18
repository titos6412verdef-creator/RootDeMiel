import 'package:flutter/material.dart';

class EvaluationItemsScreen extends StatelessWidget {
  final VoidCallback onBack;

  const EvaluationItemsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final evaluationItems = [
      {
        'title': '総合評価',
        'description':
            'この教材を全体的に見て、学びやすさや分かりやすさがどのくらい高いかを示す指標です。取り組みやすさや継続性といった、学習全体の快適さを総合的に判断します。',
        'image': null,
      },
      {
        'title': '用語説明の充実度',
        'description':
            '学習の最初のステップは「言葉を理解すること」です。この教材が必要な用語を丁寧に説明しており、学び始める際につまずきにくい構成かを評価します。',
        'image': 'assets/images/stage_0.jpg',
      },
      {
        'title': '図表や補助線の多さ',
        'description':
            '視覚的な理解を助ける図表や補助線がどれほど用意されているかを示します。多すぎても情報が散らかり、少なすぎても理解が難しくなるため、バランスがポイントとなります。',
        'image': 'assets/images/stage_1.jpg',
      },
      {
        'title': '網羅率（学習内容の多様性）',
        'description':
            '概念の理解とその応用をどれだけ多面的に学べるかを評価します。幅広く内容がカバーされているか、適切なバランスで学べるかが重要です。',
        'image': 'assets/images/stage_2.jpg',
      },
      {
        'title': '練習問題（類題）の多さ',
        'description':
            '理解を定着させるには「自分で再現すること」が不可欠です。この教材に十分な類題が揃っているか、復習・反復がしやすい設計かを確認します。',
        'image': 'assets/images/stage_3.jpg',
      },
      {
        'title': '実践問題（過去問等）',
        'description':
            '実際の入試レベルに近い問題がどれだけ用意されているかを示します。学んだ知識を組み合わせる実践力を養えるかが評価の中心です。',
        'image': 'assets/images/stage_4.jpg',
      },
      {
        'title': '対象偏差値',
        'description':
            'この教材がどの学習段階の人に適しているかを示す指標です。現在地から志望レベルへ到達するために必要なレベルを満たしているかを確認します。',
        'image': null,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('評価項目について'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          // ページタイトル
          const Text(
            '参考書レビューの評価基準',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'このページでは、レビューで使用している各評価項目が何を示しているのかを丁寧に解説します。'
            '選書の基準として活用し、あなたに合った教材選びに役立ててください。',
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 24),

          ...evaluationItems.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タイトル
                  Text(
                    item['title']!,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 説明文
                  Text(
                    item['description']!,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: Colors.black87,
                    ),
                  ),

                  // 画像があるときだけ表示
                  if (item['image'] != null) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(item['image']!, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
