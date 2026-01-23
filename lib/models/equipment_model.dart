class GearStatus {
  String value;
  bool checked;

  GearStatus({this.value = '', this.checked = false});

  Map<String, dynamic> toMap() => {
    'value': value,
    'checked': checked,
  };

  factory GearStatus.fromMap(Map<String, dynamic> map) {
    return GearStatus(
      value: map['value']?.toString() ?? '',
      checked: map['checked'] is bool ? map['checked'] : false,
    );
  }

  GearStatus copy() => GearStatus(value: value, checked: checked);
}

class MemberEquipment {
  String id;
  String name;
  int order;
  Map<String, GearStatus> gears;

  MemberEquipment({
    required this.id,
    required this.name,
    required this.order,
    required this.gears,
  });

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      '이름': name,
      'order': order,
    };
    gears.forEach((key, gear) {
      map[key] = gear.toMap();
    });
    return map;
  }

  factory MemberEquipment.fromMap(String id, Map<String, dynamic> map) {
    const gearNames = ['가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타'];
    Map<String, GearStatus> gearsMap = {};

    for (var name in gearNames) {
      if (map[name] != null && map[name] is Map) {
        gearsMap[name] = GearStatus.fromMap(Map<String, dynamic>.from(map[name]));
      } else {
        gearsMap[name] = GearStatus();
      }
    }

    return MemberEquipment(
      id: id,
      name: map['이름']?.toString() ?? '',
      order: map['order'] is int ? map['order'] : 0,
      gears: gearsMap,
    );
  }

  MemberEquipment copy() {
    return MemberEquipment(
      id: id,
      name: name,
      order: order,
      gears: gears.map((key, value) => MapEntry(key, value.copy())),
    );
  }
}

class MealPlan {
  String id;
  String breakfast;
  String lunch;
  String dinner;
  String snack;

  MealPlan({
    required this.id,
    this.breakfast = '',
    this.lunch = '',
    this.dinner = '',
    this.snack = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'breakfast': breakfast,
    'lunch': lunch,
    'dinner': dinner,
    'snack': snack,
  };

  factory MealPlan.fromMap(String id, Map<String, dynamic> map) {
    return MealPlan(
      id: id,
      breakfast: map['breakfast']?.toString() ?? '',
      lunch: map['lunch']?.toString() ?? '',
      dinner: map['dinner']?.toString() ?? '',
      snack: map['snack']?.toString() ?? '',
    );
  }

  MealPlan copy() => MealPlan(
    id: id,
    breakfast: breakfast,
    lunch: lunch,
    dinner: dinner,
    snack: snack,
  );
}

class ScheduleItem {
  String time;
  String description;

  ScheduleItem({required this.time, required this.description});

  Map<String, dynamic> toMap() => {'time': time, 'description': description};

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      time: map['time']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }
}

class DailySchedule {
  String id;
  List<ScheduleItem> items;

  DailySchedule({required this.id, required this.items});

  Map<String, dynamic> toMap() => {
    'id': id,
    'items': items.map((i) => i.toMap()).toList(),
  };

  factory DailySchedule.fromMap(String id, Map<String, dynamic> map) {
    var list = map['items'] as List? ?? [];
    return DailySchedule(
      id: id,
      items: list.map((i) => ScheduleItem.fromMap(Map<String, dynamic>.from(i))).toList(),
    );
  }
}

// 💡 공지사항 모델 추가
class NoticeItem {
  String id;
  String title;
  String content;
  DateTime timestamp;

  NoticeItem({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory NoticeItem.fromMap(String id, Map<String, dynamic> map) {
    return NoticeItem(
      id: id,
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}