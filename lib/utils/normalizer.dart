// lib/utils/normalizer.dart

import 'package:diacritic/diacritic.dart';
import 'package:characters/characters.dart'; // アクセント記号の除去（今後拡張する場合に便利）

/// 文字列の正規化（簡易版）
/// - 前後の空白削除
/// - 全角スペース・半角スペースの除去
/// - 小文字化
/// - アクセントの除去（例：é → e）
/// ※全角→半角やカタカナ変換は未対応（必要なら追加可能）
String normalizeText(String input) {
  return removeDiacritics(
    input
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '') // 全角/半角スペース除去
        .trim(),
  );
}

/// タイトル・著者・出版社が一致するかどうかを判定する
bool isExactMatch(String a, String b) {
  return normalizeText(a) == normalizeText(b);
}

/// fuzzyな（ゆるやかな）一致度を算出する（0.0〜1.0）
double similarityScore(String a, String b) {
  final normA = normalizeText(a);
  final normB = normalizeText(b);

  if (normA.isEmpty || normB.isEmpty) return 0.0;
  if (normA == normB) return 1.0;

  return _jaccardSimilarity(normA, normB);
}

/// 類似スコアが閾値以上（例：0.75）であれば「類似」とみなす
bool isSimilar(String a, String b, {double threshold = 0.75}) {
  return similarityScore(a, b) >= threshold;
}

/// --- 内部関数：Jaccard係数を使って類似度を測る ---------------------

double _jaccardSimilarity(String a, String b) {
  final setA = a.characters.toSet();
  final setB = b.characters.toSet();

  final intersection = setA.intersection(setB).length;
  final union = setA.union(setB).length;

  return union == 0 ? 0.0 : intersection / union;
}
