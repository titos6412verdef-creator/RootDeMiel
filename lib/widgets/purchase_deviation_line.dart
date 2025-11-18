// lib/widgets/purchase_deviation_line.dart
import 'package:flutter/material.dart';

class PurchaseDeviationLine extends StatelessWidget {
  final List<Map<String, num>> purchaseBooks; // {'lower': num, 'upper': num}
  final double lineWidth;
  final bool showOnlyMinMaxLabels; // 新規追加: 最小/最大ラベルのみにするか

  const PurchaseDeviationLine({
    super.key,
    required this.purchaseBooks,
    this.lineWidth = 240,
    this.showOnlyMinMaxLabels = false,
  });

  // 新: 透明度付きColor作成
  Color greenWithOpacity(double opacity) {
    int alpha = (opacity * 255).round().clamp(0, 255);
    return Color.fromARGB(alpha, 0, 128, 0); // 緑のRGB固定
  }

  @override
  Widget build(BuildContext context) {
    if (purchaseBooks.isEmpty) {
      return const Text('購入検討中の書籍がありません');
    }

    const double min = 30;
    const double max = 70;

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = lineWidth < constraints.maxWidth
            ? lineWidth
            : constraints.maxWidth;

        double getX(double value) {
          double ratio = ((value - min) / (max - min)).clamp(0, 1);
          return ratio * effectiveWidth;
        }

        final lines = purchaseBooks
            .map(
              (book) => {
                'lower': (book['lower'] ?? min).toDouble(),
                'upper': (book['upper'] ?? max).toDouble(),
              },
            )
            .toList();

        // ラベル描画用
        List<Widget> labelWidgets;
        if (showOnlyMinMaxLabels && lines.isNotEmpty) {
          final minVal = lines
              .map((e) => e['lower']!)
              .reduce((a, b) => a < b ? a : b);
          final maxVal = lines
              .map((e) => e['upper']!)
              .reduce((a, b) => a > b ? a : b);
          labelWidgets = [
            Positioned(
              left: getX(minVal).clamp(0, effectiveWidth - 20),
              child: Text(
                minVal.round().toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Positioned(
              left: getX(maxVal).clamp(0, effectiveWidth - 20),
              child: Text(
                maxVal.round().toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ];
        } else {
          labelWidgets = lines.map((line) {
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
          }).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // ラベル部分
            SizedBox(
              width: effectiveWidth,
              height: 20,
              child: Stack(children: labelWidgets),
            ),
            const SizedBox(height: 4),
            // 線と帯
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: effectiveWidth,
                  height: 6,
                  color: Colors.grey[300],
                ),
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
                // 青丸（中央値）
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
            const SizedBox(height: 4),
            // 目盛り
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
}
