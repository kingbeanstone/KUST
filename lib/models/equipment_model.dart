class GearStatus {
  String value;
  bool checked;
  GearStatus({this.value = '', this.checked = false});
  Map<String, dynamic> toMap() => {'value': value, 'checked': checked};
  factory GearStatus.fromMap(Map<String, dynamic> map) => GearStatus(
    value: map['value']?.toString() ?? '',
    checked: map['checked'] is bool ? map['checked'] : false,
  );
  GearStatus copy() => GearStatus(value: value, checked: checked);
}

class MemberEquipment {
  String id;
  String name;
  int order;
  Map<String, GearStatus> gears;

  MemberEquipment({required this.id, required this.name, required this.order, required this.gears});

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {'id': id, '이름': name, 'order': order};
    gears.forEach((key, gear) => map[key] = gear.toMap());
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
    return MemberEquipment(id: id, name: map['이름']?.toString() ?? '', order: map['order'] is int ? map['order'] : 0, gears: gearsMap);
  }

  MemberEquipment copy() => MemberEquipment(id: id, name: name, order: order, gears: gears.map((key, value) => MapEntry(key, value.copy())));
}

// 💡 임원단 모델 (한 줄 소개 필드 포함)
class ExecutiveItem {
  String id;
  String gender; // 'male' 또는 'female'
  String name;
  String generation; // 기수
  String position; // 직책
  String phone;
  String intro; // 💡 한 줄 소개

  ExecutiveItem({
    required this.id,
    required this.gender,
    required this.name,
    required this.generation,
    required this.position,
    required this.phone,
    this.intro = '',
  });

  Map<String, dynamic> toMap() => {
    'gender': gender,
    'name': name,
    'generation': generation,
    'position': position,
    'phone': phone,
    'intro': intro,
  };

  factory ExecutiveItem.fromMap(String id, Map<String, dynamic> map) => ExecutiveItem(
    id: id,
    gender: map['gender'] ?? 'male',
    name: map['name'] ?? '',
    generation: map['generation'] ?? '',
    position: map['position'] ?? '',
    phone: map['phone'] ?? '',
    intro: map['intro'] ?? '',
  );
}

// 💡 고유 번호 없는 공용 장비 모델 (수량 조절용)
class GeneralGearItem {
  String id; // 장비 이름 (Key: 슈트, 마스크 등)
  int count;
  List<String> memos;

  GeneralGearItem({required this.id, this.count = 0, this.memos = const []});

  Map<String, dynamic> toMap() => {
    'count': count,
    'memos': memos,
  };

  factory GeneralGearItem.fromMap(String id, Map<String, dynamic> map) => GeneralGearItem(
    id: id,
    count: map['count'] ?? 0,
    memos: List<String>.from(map['memos'] ?? []),
  );
}

// 💡 BCD 독립 모델
class BcdItem {
  String id; // BCD 번호 (Key)
  String name;
  String memo;
  BcdItem({required this.id, required this.name, required this.memo});
  Map<String, dynamic> toMap() => {'name': name, 'memo': memo};
  factory BcdItem.fromMap(String id, Map<String, dynamic> map) => BcdItem(id: id, name: map['name'] ?? '', memo: map['memo'] ?? '');
}

// 💡 호흡기 독립 모델
class RegulatorItem {
  String id; // 호흡기 번호 (Key)
  String name;
  String memo;
  RegulatorItem({required this.id, required this.name, required this.memo});
  Map<String, dynamic> toMap() => {'name': name, 'memo': memo};
  factory RegulatorItem.fromMap(String id, Map<String, dynamic> map) => RegulatorItem(id: id, name: map['name'] ?? '', memo: map['memo'] ?? '');
}

// 💡 식단 모델
class MealPlan {
  String id; String breakfast; String lunch; String dinner; String snack;
  MealPlan({required this.id, this.breakfast = '', this.lunch = '', this.dinner = '', this.snack = ''});
  Map<String, dynamic> toMap() => {'id': id, 'breakfast': breakfast, 'lunch': lunch, 'dinner': dinner, 'snack': snack};
  factory MealPlan.fromMap(String id, Map<String, dynamic> map) => MealPlan(id: id, breakfast: map['breakfast'] ?? '', lunch: map['lunch'] ?? '', dinner: map['dinner'] ?? '', snack: map['snack'] ?? '');
}

// 💡 일정 아이템 모델
class ScheduleItem {
  String time; String description;
  ScheduleItem({required this.time, required this.description});
  Map<String, dynamic> toMap() => {'time': time, 'description': description};
  factory ScheduleItem.fromMap(Map<String, dynamic> map) => ScheduleItem(time: map['time'] ?? '', description: map['description'] ?? '');
}

// 💡 일별 일정 모델
class DailySchedule {
  String id; List<ScheduleItem> items;
  DailySchedule({required this.id, required this.items});
  factory DailySchedule.fromMap(String id, Map<String, dynamic> map) {
    var list = map['items'] as List? ?? [];
    return DailySchedule(id: id, items: list.map((i) => ScheduleItem.fromMap(Map<String, dynamic>.from(i))).toList());
  }
}

// 💡 공지사항 모델
class NoticeItem {
  String id; String title; String content; DateTime timestamp;
  NoticeItem({required this.id, required this.title, required this.content, required this.timestamp});
  factory NoticeItem.fromMap(String id, Map<String, dynamic> map) => NoticeItem(
    id: id,
    title: map['title'] ?? '',
    content: map['content'] ?? '',
    timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
  );
}

// 💡 Q&A 답변 모델
class QnaReply {
  String id; String author; String content; DateTime timestamp;
  QnaReply({required this.id, required this.author, required this.content, required this.timestamp});
  factory QnaReply.fromMap(String id, Map<String, dynamic> map) => QnaReply(
    id: id,
    author: map['author'] ?? '익명',
    content: map['content'] ?? '',
    timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
  );
}

// 💡 Q&A 게시글 모델
class QnaPost {
  String id; String title; String content; String author; DateTime timestamp; List<QnaReply> replies;
  QnaPost({required this.id, required this.title, required this.content, required this.author, required this.timestamp, this.replies = const []});
  factory QnaPost.fromMap(String id, Map<String, dynamic> map, {List<QnaReply> replies = const []}) => QnaPost(
    id: id,
    title: map['title'] ?? '',
    content: map['content'] ?? '',
    author: map['author'] ?? '익명',
    timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    replies: replies,
  );
}