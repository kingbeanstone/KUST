class MemberItem {
  final String id;
  final String name;
  final String generation;
  final String phone;
  final String gender;
  final String role;
  final String emergencyContact;
  final String bloodType;
  final String height;
  final String shoeSize;
  // 💡 정렬 순서를 저장하기 위한 필드 추가
  final int order;

  /// 💡 동아리원 구분: 'YB' 또는 'OB'
  final String memberType;

  MemberItem({
    required this.id,
    required this.name,
    required this.generation,
    required this.phone,
    required this.gender,
    this.role = '대원',
    this.emergencyContact = '',
    this.bloodType = '',
    this.height = '',
    this.shoeSize = '',
    this.order = 0,
    this.memberType = 'YB',
  });

  // 💡 copyWith 메서드 추가 (순서 변경 및 업데이트 용이)
  MemberItem copyWith({
    String? id,
    String? name,
    String? generation,
    String? phone,
    String? gender,
    String? role,
    String? emergencyContact,
    String? bloodType,
    String? height,
    String? shoeSize,
    int? order,
    String? memberType,
  }) {
    return MemberItem(
      id: id ?? this.id,
      name: name ?? this.name,
      generation: generation ?? this.generation,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      bloodType: bloodType ?? this.bloodType,
      height: height ?? this.height,
      shoeSize: shoeSize ?? this.shoeSize,
      order: order ?? this.order,
      memberType: memberType ?? this.memberType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'generation': generation,
      'phone': phone,
      'gender': gender,
      'role': role,
      'emergencyContact': emergencyContact,
      'bloodType': bloodType,
      'height': height,
      'shoeSize': shoeSize,
      'order': order, // 저장 시 order 포함
      'memberType': memberType,
    };
  }

  factory MemberItem.fromMap(String id, Map<String, dynamic> map) {
    return MemberItem(
      id: id,
      // 💡 입력 실수로 붙은 앞뒤 공백 제거 — 공백이 남으면 정렬이 뒤집히고
      //    (스페이스 < 한글) 버디의 이름 매칭도 어긋난다
      name: (map['name'] ?? '').toString().trim(),
      generation: (map['generation'] ?? '').toString().trim(),
      phone: map['phone'] ?? '',
      gender: map['gender'] ?? 'male',
      role: map['role'] ?? '대원',
      emergencyContact: map['emergencyContact'] ?? '',
      bloodType: map['bloodType'] ?? '',
      height: map['height'] ?? '',
      shoeSize: map['shoeSize'] ?? '',
      order: map['order'] ?? 0, // 불러올 때 order 읽기
      memberType: map['memberType'] ?? 'YB',
    );
  }
}