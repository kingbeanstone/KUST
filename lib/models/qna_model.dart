class QnaReply {
  String id;
  String author;
  String content;
  DateTime timestamp;

  QnaReply({
    required this.id,
    required this.author,
    required this.content,
    required this.timestamp
  });

  factory QnaReply.fromMap(String id, Map<String, dynamic> map) => QnaReply(
    id: id,
    author: map['author'] ?? '익명',
    content: map['content'] ?? '',
    timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
  );
}

class QnaPost {
  String id;
  String title;
  String content;
  String author;
  DateTime timestamp;
  List<QnaReply> replies;

  QnaPost({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.timestamp,
    this.replies = const []
  });

  factory QnaPost.fromMap(String id, Map<String, dynamic> map, {List<QnaReply> replies = const []}) => QnaPost(
    id: id,
    title: map['title'] ?? '',
    content: map['content'] ?? '',
    author: map['author'] ?? '익명',
    timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    replies: replies,
  );
}