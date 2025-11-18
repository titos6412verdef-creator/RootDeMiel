import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// -------------------------------
/// BookRadarChart
/// -------------------------------
/// 書籍のレビューや評価に基づいた偏差値的な4項目（用語説明、網羅率、練習問題、実践問題）を
/// レーダーチャートで可視化するウィジェット。
/// - terminology: 用語説明の評価値
/// - variety: 網羅率の評価値
/// - exercises: 練習問題の評価値
/// - practice: 実践問題の評価値
/// - showLabels: 項目名と値を表示するかどうか
/// -------------------------------
class BookRadarChart extends StatelessWidget {
  final double terminology;
  final double variety;
  final double exercises;
  final double practice;
  final bool showLabels;

  const BookRadarChart({
    super.key,
    required this.terminology,
    required this.variety,
    required this.exercises,
    required this.practice,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160, // チャートの高さを固定
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.circle, // レーダーの形を円形に設定
          /// -------------------------------
          /// データセット
          /// -------------------------------
          dataSets: [
            // 背景用データセット（最大値のガイド用）
            RadarDataSet(
              dataEntries: [
                RadarEntry(value: 0),
                RadarEntry(value: 5),
                RadarEntry(value: 0),
                RadarEntry(value: 5),
              ],
              fillColor: Colors.transparent, // 塗りつぶしなし
              borderColor: Colors.transparent, // 線なし
              entryRadius: 0, // 点を表示しない
            ),
            // 実際の評価データ
            RadarDataSet(
              dataEntries: [
                RadarEntry(value: terminology),
                RadarEntry(value: variety),
                RadarEntry(value: exercises),
                RadarEntry(value: practice),
              ],
              fillColor: Colors.indigo.withAlpha(
                (0.4 * 255).round(),
              ), // 半透明塗りつぶし
              borderColor: Colors.indigo, // 枠線色
              borderWidth: 1.5, // 枠線太さ
              entryRadius: 2, // 各点の半径
            ),
          ],

          radarBackgroundColor: Colors.transparent, // チャート背景
          borderData: FlBorderData(show: false), // 外枠非表示
          radarBorderData: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ), // レーダー線
          titleTextStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 11,
          ), // タイトル文字
          titlePositionPercentageOffset: 0.10, // タイトル位置のオフセット
          /// -------------------------------
          /// 項目タイトル（ラベル）の取得
          /// -------------------------------
          getTitle: (index, angle) {
            if (!showLabels) {
              // ラベル非表示の場合は数値のみ表示
              switch (index) {
                case 0:
                  return RadarChartTitle(text: terminology.toStringAsFixed(1));
                case 1:
                  return RadarChartTitle(text: variety.toStringAsFixed(1));
                case 2:
                  return RadarChartTitle(text: exercises.toStringAsFixed(1));
                case 3:
                  return RadarChartTitle(text: practice.toStringAsFixed(1));
                default:
                  return const RadarChartTitle(text: '');
              }
            }

            // ラベルありの場合は項目名＋数値を表示
            switch (index) {
              case 0:
                return RadarChartTitle(
                  text: '用語説明\n${terminology.toStringAsFixed(1)}',
                );
              case 1:
                return RadarChartTitle(
                  text: '網羅率\n${variety.toStringAsFixed(1)}',
                );
              case 2:
                return RadarChartTitle(
                  text: '練習問題\n${exercises.toStringAsFixed(1)}',
                );
              case 3:
                return RadarChartTitle(
                  text: '実践問題\n${practice.toStringAsFixed(1)}',
                );
              default:
                return const RadarChartTitle(text: '');
            }
          },

          /// -------------------------------
          /// レーダーの目盛り
          /// -------------------------------
          tickCount: 5, // 目盛りの数
          ticksTextStyle: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ), // 目盛り文字
          tickBorderData: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ), // 目盛り線

          radarTouchData: RadarTouchData(enabled: false), // タッチ操作無効
        ),
      ),
    );
  }
}
