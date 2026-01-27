class MealPlan {
  final String id;
  final String breakfast;
  final String lunch;
  final String dinner;
  final String snack;

  MealPlan({
    required this.id,
    this.breakfast = '',
    this.lunch = '',
    this.dinner = '',
    this.snack = '',
  });

  // 💡 데이터를 Map으로 변환 (저장용)
  Map<String, dynamic> toMap() {
    return {
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'snack': snack,
    };
  }

  // 💡 Map 데이터를 객체로 변환 (불러오기용)
  factory MealPlan.fromMap(String id, Map<String, dynamic> map) {
    return MealPlan(
      id: id,
      breakfast: map['breakfast'] ?? '',
      lunch: map['lunch'] ?? '',
      dinner: map['dinner'] ?? '',
      snack: map['snack'] ?? '',
    );
  }

  // 💡 파이어베이스 문서로부터 객체 생성
  factory MealPlan.fromFirestore(String id, Map<String, dynamic> data) {
    return MealPlan.fromMap(id, data);
  }
}