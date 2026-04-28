class ExerciseCatalogConstants {
  static const List<String> libraryMuscleGroups = [
    '胸部',
    '背部',
    '中背',
    '下背',
    '肩部',
    '手臂',
    '核心',
    '腿部',
    '臀部',
    '颈部',
  ];

  static const String cardioGroup = '有氧';

  static const List<String> libraryGroups = [
    ...libraryMuscleGroups,
    cardioGroup,
  ];

  static const List<String> sessionEditorGroups = [
    ...libraryGroups,
    '休息日',
  ];

  static const Map<String, List<String>> muscleTargets = {
    '胸部': ['胸部'],
    '背部': ['背阔肌', '斜方肌'],
    '中背': ['中背'],
    '下背': ['下背'],
    '肩部': ['肩部'],
    '手臂': ['肱二头肌', '肱三头肌', '前臂'],
    '核心': ['腹肌'],
    '腿部': ['股四头肌', '股二头肌', '小腿', '髋外展肌', '髋内收肌'],
    '臀部': ['臀部'],
    '颈部': ['颈部'],
  };

  static String titleForGroup(String group) {
    return group == '休息日' ? '休息日' : '$group训练日';
  }

  static String inferSessionGroupFromTitle(String? title) {
    final normalized = (title ?? '').trim();
    if (normalized.isEmpty) {
      return '胸部';
    }
    if (normalized.contains('休息')) {
      return '休息日';
    }
    if (normalized.contains('有氧')) {
      return '有氧';
    }
    if (normalized.contains('中背')) {
      return '中背';
    }
    if (normalized.contains('下背')) {
      return '下背';
    }
    if (normalized.contains('臀')) {
      return '臀部';
    }
    if (normalized.contains('颈')) {
      return '颈部';
    }
    if (normalized.contains('胸') || normalized.contains('推')) {
      return '胸部';
    }
    if (normalized.contains('背') || normalized.contains('拉')) {
      return '背部';
    }
    if (normalized.contains('腿') || normalized.contains('下肢')) {
      return '腿部';
    }
    if (normalized.contains('肩')) {
      return '肩部';
    }
    if (normalized.contains('手臂') ||
        normalized.contains('二头') ||
        normalized.contains('三头') ||
        normalized.contains('前臂')) {
      return '手臂';
    }
    if (normalized.contains('核心') || normalized.contains('腹')) {
      return '核心';
    }
    for (final group in sessionEditorGroups) {
      if (normalized.contains(group)) {
        return group;
      }
    }
    if (normalized.contains('胸')) {
      return '胸部';
    }
    if (normalized.contains('背')) {
      return '背部';
    }
    if (normalized.contains('腿')) {
      return '腿部';
    }
    if (normalized.contains('肩')) {
      return '肩部';
    }
    return '胸部';
  }

  static String? normalizeLibraryGroup(String? group) {
    if (group == null || group.trim().isEmpty) {
      return null;
    }
    final normalized = group.trim();
    if (libraryGroups.contains(normalized)) {
      return normalized;
    }
    switch (normalized) {
      case '胸':
        return '胸部';
      case '背':
        return '背部';
      case '腿':
        return '腿部';
      case '肩':
        return '肩部';
      case '有氧':
        return cardioGroup;
      default:
        return null;
    }
  }
}
