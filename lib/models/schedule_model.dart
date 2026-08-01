class ScheduleItem {
  final String time;
  final String description;

  /// 블록 색상 키 (schedule_screen의 kItemColors, '' = 기본 파랑)
  final String color;

  ScheduleItem({required this.time, required this.description, this.color = ''});

  // 💡 데이터를 Map으로 변환 (저장용)
  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'description': description,
      'color': color,
    };
  }

  // 💡 Map에서 객체로 변환 (불러오기용)
  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      time: map['time'] ?? '',
      description: map['description'] ?? '',
      color: map['color'] ?? '',
    );
  }
}

class DailySchedule {
  final String id; // 날짜 (예: 1.29)
  final List<ScheduleItem> items;

  DailySchedule({required this.id, required this.items});

  // 💡 DailySchedule 전체를 Map으로 변환 (저장용)
  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  // 💡 파이어베이스에서 읽어온 데이터를 객체로 변환
  factory DailySchedule.fromMap(String id, Map<String, dynamic> map) {
    final List<dynamic> itemsData = map['items'] ?? [];
    return DailySchedule(
      id: id,
      items: itemsData.map((item) => ScheduleItem.fromMap(Map<String, dynamic>.from(item))).toList(),
    );
  }

  // 💡 호환성을 위한 Firestore 팩토리 메서드
  factory DailySchedule.fromFirestore(String id, Map<String, dynamic> data) {
    return DailySchedule.fromMap(id, data);
  }
}