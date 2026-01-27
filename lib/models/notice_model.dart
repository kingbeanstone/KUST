class NoticeItem {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final bool isPinned;
  final List<String> imageUrls;

  NoticeItem({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.isPinned = false,
    this.imageUrls = const [],
  });

  // 💡 데이터를 Map으로 변환 (저장용)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isPinned': isPinned,
      'imageUrls': imageUrls,
    };
  }

  // 💡 Map 데이터를 객체로 변환 (불러오기용)
  factory NoticeItem.fromMap(String id, Map<String, dynamic> map) {
    return NoticeItem(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      isPinned: map['isPinned'] ?? false,
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
    );
  }
}