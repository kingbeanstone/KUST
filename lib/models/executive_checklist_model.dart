class ExecutiveChecklistItem {
  final String id;
  final String title;
  final String description;
  final bool isChecked;
  final String category; // 예: 행정, 예약, 장비, 기타

  ExecutiveChecklistItem({
    required this.id,
    required this.title,
    this.description = '',
    this.isChecked = false,
    this.category = '일반',
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isChecked': isChecked,
      'category': category,
    };
  }

  factory ExecutiveChecklistItem.fromMap(String id, Map<String, dynamic> map) {
    return ExecutiveChecklistItem(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isChecked: map['isChecked'] ?? false,
      category: map['category'] ?? '일반',
    );
  }
}