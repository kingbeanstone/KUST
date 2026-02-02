class ExecutiveItem {
  String id;
  String gender; // 'male' 또는 'female'
  String name;
  String generation; // 기수
  String position; // 직책
  String phone;
  String intro; // 한 줄 소개

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