import 'package:flutter/material.dart';

class AverageReviewCard extends StatelessWidget {
  final Map<String, dynamic> averages;
  final double lineWidth;

  /// 追加: 複数線対応用のサブ偏差値リスト
  /// 各 Map は {'lower': double, 'upper': double} の形式
  final List<Map<String, double>>? subScores;

  const AverageReviewCard({
    super.key,
    required this.averages,
    this.lineWidth = 240,
    this.subScores,
  });

  // 透明度付きColor作成
  Color greenWithOpacity(double opacity) {
    int alpha = (opacity * 255).round().clamp(0, 255);
    return Color.fromARGB(alpha, 0, 128, 0); // 緑のRGB固定
  }

  Widget buildDeviationLine(double? lower, double? upper) {
    const double min = 30;
    const double max = 70;

    List<Map<String, double>> lines =
        subScores ??
        (lower != null && upper != null
            ? [
                {'lower': lower, 'upper': upper},
              ]
            : []);

    if (lines.isEmpty) {
      return const Text('偏差値データなし');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = constraints.maxWidth;

        double getX(double value) {
          double ratio = ((value - min) / (max - min)).clamp(0, 1);
          return ratio * effectiveWidth;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 1),

            // ラベル部分
            SizedBox(
              width: effectiveWidth,
              height: 20,
              child: Stack(
                children: lines.map((line) {
                  double lowerPos = getX(line['lower']!);
                  double upperPos = getX(line['upper']!);
                  return Stack(
                    children: [
                      Positioned(
                        left: (lowerPos - 10).clamp(0, effectiveWidth - 20),
                        child: Text(
                          line['lower']!.round().toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Positioned(
                        left: (upperPos - 10).clamp(0, effectiveWidth - 20),
                        child: Text(
                          line['upper']!.round().toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 0),

            // 線と帯
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 背景線
                Container(
                  width: effectiveWidth,
                  height: 6,
                  color: Colors.grey[300],
                ),
                // 複数線（緑）の重ね描画
                ...lines.asMap().entries.map((entry) {
                  Map<String, double> line = entry.value;
                  double lowerPos = getX(line['lower']!);
                  double upperPos = getX(line['upper']!);

                  return Positioned(
                    left: lowerPos.clamp(0, effectiveWidth),
                    child: Container(
                      width: (upperPos - lowerPos).clamp(
                        0,
                        effectiveWidth - lowerPos,
                      ),
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            greenWithOpacity(0.1),
                            greenWithOpacity(0.9),
                            greenWithOpacity(0.1),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  );
                }),

                // 青丸を最前面に表示（中央値） - 全書籍分描画
                ...lines.map((line) {
                  double mid = (line['lower']! + line['upper']!) / 2;
                  double left = (getX(mid) - 4).clamp(0, effectiveWidth - 8);
                  return Positioned(
                    left: left,
                    top: (6 / 2) - 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 1),

            // 目盛りラベル
            SizedBox(
              width: effectiveWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('30', style: TextStyle(fontSize: 12)),
                  Text('50', style: TextStyle(fontSize: 12)),
                  Text('70', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double? avgScore = averages['avg_score'] as double?;
    double? terminology = averages['avg_terminology_clarity'] as double?;
    double? visual = averages['avg_visual_density'] as double?;
    double? variety = averages['avg_variety_of_problems'] as double?;
    double? exercises = averages['avg_richness_of_exercises'] as double?;
    double? practice = averages['avg_richness_of_practice'] as double?;
    double? lower = averages['avg_lower_deviation'] as double?;
    double? upper = averages['avg_upper_deviation'] as double?;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 1),
        if (avgScore != null) buildScoreRow('★', '総合評価', avgScore),
        if (terminology != null) buildScoreRow('🧠', '用語説明', terminology),
        if (visual != null) buildScoreRow('📊', '図表の量', visual),
        if (variety != null) buildScoreRow('📚', '網羅性', variety),
        if (exercises != null) buildScoreRow('📄', '練習問題量', exercises),
        if (practice != null) buildScoreRow('📝', '実践問題量', practice),
        const SizedBox(height: 1),
        buildDeviationLine(lower, upper),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: SizedBox(width: lineWidth, child: content),
    );
  }

  Widget buildScoreRow(String icon, String label, double value) {
    String paddedLabel = label.padRight(5, '　'); // 全角スペース
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$icon '),
          TextSpan(
            text: paddedLabel,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(text: ': ${value.toStringAsFixed(1)}'),
        ],
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}
