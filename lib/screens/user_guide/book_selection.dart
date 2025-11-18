import 'package:flutter/material.dart';

/// 参考書の選び方
class BookSelectionScreen extends StatelessWidget {
  final VoidCallback onBack;

  const BookSelectionScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final selectionTips = [
      {
        'problem': '何から手を付けたらいいかわからない。勉強の仕方がわからない',
        'tip': '「用語の充実度」が高い本から始めましょう。基礎の理解が固まると応用もしやすくなります。',
        'image': null,
      },
      {
        'problem': '言い換えや説明が苦手',
        'tip': '「図表や補助線の多さ」をチェック。視覚的に理解できイメージが持てると説明力があがります。',
        'image': null,
      },
      {
        'problem': '教科書の章末問題や定期試験だといい点が取れない',
        'tip': '「網羅率」と「練習問題の多さ」の良い教材をそろえましょう。それぞれ別な参考書でも問題ありません。',
        'image': null,
      },
      {
        'problem': '過去問や模擬試験で点が伸びない',
        'tip': '「実践問題（過去問等）」が豊富な教材で実践演習を積みましょう。',
        'image': null,
      },
      {
        'problem': '目標校や目標偏差値に合う教材を知りたい',
        'tip': '「対象偏差値」を確認。自分のレベルと目標に合った教材を選ぶことが大切です。',
        'image': null,
      },
      {
        'problem': '複数の課題を抱えているとき',
        'tip': 'できるだけ最初のステップ（このページの上にあるもの）から検討しましょう。',
        'image': null,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('参考書の選び方'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const Text(
            'あなたに合う参考書の選び方',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '参考書は、抱えている悩みや現在地によって選ぶべきものが変わります。'
            'ここでは、典型的な悩みに対して適した教材の方向性をわかりやすくまとめています。',
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 24),

          ...selectionTips.map((tip) {
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
                  Text(
                    tip['problem']!,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tip['tip']!,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: Colors.black87,
                    ),
                  ),
                  if (tip['image'] != null) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(tip['image']!, fit: BoxFit.cover),
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
