// lib/utils/subject_utils.dart

/// 科目構造の定義
const Map<String, List<String>> subjectHierarchy = {
  '英語': ['英単語・熟語', 'リスニング', '英文法', '英文解釈', '長文読解', '英語総合'],
  '国語': ['現代文', '古文', '漢文'],
  '数学': [],
  '理科': ['物理', '化学', '生物', '地学'],
  '地歴': ['歴史総合', '日本史探究', '世界史探究', '地理総合', '地理探究'],
  '公共': ['公共', '倫理', '政治・経済'],
  '情報': [],
};

/// 選択された科目リストを親子展開して返す
List<String> expandSubjects(List<String> selected) {
  final expanded = <String>{};

  for (final subject in selected) {
    expanded.add(subject);

    if (subjectHierarchy.containsKey(subject)) {
      expanded.addAll(subjectHierarchy[subject]!);
    }
  }

  return expanded.toList();
}

List<String> getExpandedSubjectsForSearch({
  required String educationLevel,
  required String subject,
  required Map<String, List<String>?> highSchoolSubjectsMap,
}) {
  if (educationLevel == '高校') {
    if (highSchoolSubjectsMap.containsKey(subject)) {
      final children = highSchoolSubjectsMap[subject];
      if (children == null || children.isEmpty) {
        return [subject];
      } else {
        return [subject, ...children];
      }
    } else {
      return [subject];
    }
  }
  // 高校以外は単一科目のまま
  return [subject];
}
