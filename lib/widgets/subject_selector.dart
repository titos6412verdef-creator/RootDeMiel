import 'package:flutter/material.dart';

class EducationSubjectSelector extends StatefulWidget {
  final void Function(String? educationLevel, List<String>? subjects)?
  onSelectionChanged;
  final String? initialEducationLevel;
  final String? initialSubject;

  const EducationSubjectSelector({
    super.key,
    this.onSelectionChanged,
    this.initialEducationLevel,
    this.initialSubject,
  });

  @override
  State<EducationSubjectSelector> createState() =>
      _EducationSubjectSelectorState();
}

class _EducationSubjectSelectorState extends State<EducationSubjectSelector> {
  final List<String> educationLevels = ['小学校', '中学校', '高校'];

  final Map<String, List<String>> highSchoolSubjectsMap = {
    '国語': ['現代文', '古文', '漢文'],
    '数学': [],
    '理科': ['物理', '化学', '生物', '地学'],
    '地歴': ['歴史総合', '日本史探究', '世界史探究', '地理総合', '地理探究'],
    '公共': ['公共', '倫理', '政治・経済'],
    '情報': [],
    '英語': ['英単語・熟語', 'リスニング', '英文法', '英文解釈', '長文読解', '英語総合'],
  };

  final Map<String, List<String>> subjectsByEducation = {
    '小学校': ['国語', '算数', '理科', '社会', '英語'],
    '中学校': ['国語', '数学', '理科', '社会', '英語'],
    '高校': [], // 高校は highSchoolSubjectsMap を使うため空リスト
  };

  late String selectedEducationLevel;
  String? selectedSubject;

  @override
  void initState() {
    super.initState();

    // 初期値を高校に設定
    selectedEducationLevel = widget.initialEducationLevel ?? '高校';

    final subjects = _getAvailableSubjectsValues();

    // 初期科目が有効か判定
    bool isValidInitialSubject(String? subject) {
      if (subject == null) return false;
      if (subjects.contains(subject)) return true;

      // 高校の親科目の子科目が指定された場合も有効とする判定
      if (selectedEducationLevel == '高校') {
        for (var parent in highSchoolSubjectsMap.keys) {
          var children = highSchoolSubjectsMap[parent]!;
          if (children.contains(subject)) {
            return true;
          }
        }
      }
      return false;
    }

    if (isValidInitialSubject(widget.initialSubject)) {
      selectedSubject = widget.initialSubject;
    } else {
      selectedSubject = '全教科';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifySelectionChanged();
    });
  }

  // 高校科目の順番をカスタマイズ
  List<Map<String, String>> _expandHighSchoolSubjects() {
    List<Map<String, String>> expanded = [];
    final orderedKeys = ['数学', '英語', '国語', '理科', '地歴', '公共', '情報'];

    for (var parent in orderedKeys) {
      if (!highSchoolSubjectsMap.containsKey(parent)) continue;

      final children = highSchoolSubjectsMap[parent]!;
      expanded.add({'label': parent, 'value': parent});
      for (var child in children) {
        expanded.add({'label': '  $child', 'value': child});
      }
    }
    return expanded;
  }

  // 使用可能な科目一覧
  List<Map<String, String>> getAvailableSubjects() {
    List<Map<String, String>> result;

    if (selectedEducationLevel == '高校') {
      result = [
        {'label': '全教科', 'value': '全教科'},
        ..._expandHighSchoolSubjects(),
      ];
    } else {
      final subjects = subjectsByEducation[selectedEducationLevel] ?? [];
      final subjectMaps = subjects
          .map((s) => {'label': s, 'value': s})
          .toList();
      result = [
        {'label': '全教科', 'value': '全教科'},
        ...subjectMaps,
      ];
    }

    return result;
  }

  List<String> _getAvailableSubjectsValues() {
    return getAvailableSubjects().map((e) => e['value']!).toList();
  }

  void _notifySelectionChanged() {
    if (widget.onSelectionChanged == null) return;

    final edu = selectedEducationLevel;

    if (selectedSubject == null || selectedSubject == '全教科') {
      widget.onSelectionChanged!(edu, null);
      return;
    }

    if (selectedEducationLevel == '高校' &&
        highSchoolSubjectsMap.containsKey(selectedSubject)) {
      final children = highSchoolSubjectsMap[selectedSubject]!;
      final List<String> subjectsList = [selectedSubject!];
      if (children.isNotEmpty) subjectsList.addAll(children);
      widget.onSelectionChanged!(edu, subjectsList);
      return;
    }

    widget.onSelectionChanged!(edu, [selectedSubject!]);
  }

  @override
  Widget build(BuildContext context) {
    final availableSubjects = getAvailableSubjects();

    // 初期選択が items 内にない場合は null にして一意性エラーを防ぐ
    if (!availableSubjects.any((e) => e['value'] == selectedSubject)) {
      selectedSubject = '全教科';
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '教育区分'),
            value: selectedEducationLevel,
            items: educationLevels
                .map(
                  (level) => DropdownMenuItem(value: level, child: Text(level)),
                )
                .toList(),
            onChanged: (val) {
              setState(() {
                selectedEducationLevel = val!;
                selectedSubject = '全教科'; // 選択科目をリセット
                _notifySelectionChanged();
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '科目'),
            value: selectedSubject,
            items: availableSubjects.map((item) {
              final isChild = item['label']!.startsWith('  ');
              return DropdownMenuItem<String>(
                value: item['value'],
                child: Padding(
                  padding: EdgeInsets.only(left: isChild ? 16.0 : 0),
                  child: Text(item['label']!.trimLeft()),
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                selectedSubject = val;
                _notifySelectionChanged();
              });
            },
          ),
        ),
      ],
    );
  }
}
