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

/// 💡 장비 표의 섹션 구분용 그룹 (예: 교육 1팀).
/// 목록은 config/equipment_groups 문서 하나에 배열로 저장되고,
/// 대원은 groupId로 참조한다 — 그룹 이름을 바꿔도 문서 하나만 고치면 된다.
class EquipmentGroup {
  final String id;
  final String name;

  EquipmentGroup({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory EquipmentGroup.fromMap(Map<String, dynamic> map) => EquipmentGroup(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
      );
}

class MemberEquipment {
  String id;
  String name;
  int order;
  Map<String, GearStatus> gears;

  /// 💡 소속 그룹(EquipmentGroup.id). 빈 문자열이면 미지정.
  String groupId;

  /// 💡 장비 버디(2인 1조) 식별자. 빈 문자열이면 혼자 쓰는 대원.
  /// 다이빙 버디(buddy_system)와는 별개로, 짐을 줄이려고 장비를 나눠 쓰는 짝이다.
  String pairId;

  /// 💡 짝과 실제로 '함께 쓰는' 장비 이름들. 같은 짝이어도 장비마다 공유 여부가 다르다.
  /// (예: 가방·BCD는 공유하지만 마스크는 각자 챙기는 조)
  List<String> sharedGears;

  MemberEquipment({
    required this.id,
    required this.name,
    required this.order,
    required this.gears,
    this.groupId = '',
    this.pairId = '',
    this.sharedGears = const [],
  });

  bool get hasPair => pairId.isNotEmpty;
  bool sharesGear(String gear) => hasPair && sharedGears.contains(gear);

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      '이름': name,
      'order': order,
      'groupId': groupId,
      'pairId': pairId,
      'sharedGears': sharedGears,
    };
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
    return MemberEquipment(
      id: id,
      name: map['이름']?.toString() ?? '',
      order: map['order'] is int ? map['order'] : 0,
      gears: gearsMap,
      groupId: map['groupId']?.toString() ?? '',
      pairId: map['pairId']?.toString() ?? '',
      sharedGears: map['sharedGears'] is List ? List<String>.from(map['sharedGears']) : const [],
    );
  }

  MemberEquipment copy() => MemberEquipment(
        id: id,
        name: name,
        order: order,
        gears: gears.map((key, value) => MapEntry(key, value.copy())),
        groupId: groupId,
        pairId: pairId,
        sharedGears: List<String>.from(sharedGears),
      );
}

// 고유 번호 없는 공용 장비 모델 (수량 조절용)
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

// BCD 독립 모델
class BcdItem {
  String id; // BCD 번호 (Key)
  String name;
  String memo;
  BcdItem({required this.id, required this.name, required this.memo});
  Map<String, dynamic> toMap() => {'name': name, 'memo': memo};
  factory BcdItem.fromMap(String id, Map<String, dynamic> map) => BcdItem(id: id, name: map['name'] ?? '', memo: map['memo'] ?? '');
}

// 호흡기 독립 모델
class RegulatorItem {
  String id; // 호흡기 번호 (Key)
  String name;
  String memo;
  RegulatorItem({required this.id, required this.name, required this.memo});
  Map<String, dynamic> toMap() => {'name': name, 'memo': memo};
  factory RegulatorItem.fromMap(String id, Map<String, dynamic> map) => RegulatorItem(id: id, name: map['name'] ?? '', memo: map['memo'] ?? '');
}