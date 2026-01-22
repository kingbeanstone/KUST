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
  String id;      // 날짜 ID (예: "1.29")
  String breakfast;
  String lunch;
  String dinner;
  String snack;   // 💡 야식 항목 추가

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