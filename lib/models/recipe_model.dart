/// 동아리 공용 레시피 (원정이 바뀌어도 유지되는 자산)
class Recipe {
  final String id;
  final String name; // 요리 이름 (식단 칸에 들어가는 텍스트)
  final String category; // 메뉴 카테고리 (밥, 국/찌개, 메인, 간식…)
  final String ingredients; // 재료 (자유 텍스트, 줄바꿈 구분)
  final String steps; // 조리법 (자유 텍스트)
  final int order; // 카테고리 안 표시 순서 (없으면 맨 뒤)

  /// 식단표 끼니 자리: breakfast | lunch | dinner | snack | ''(보관함/미배치)
  final String slot;

  static const int kNoOrder = 1 << 40;

  Recipe({
    required this.id,
    required this.name,
    this.category = '',
    this.ingredients = '',
    this.steps = '',
    this.order = kNoOrder,
    this.slot = '',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'ingredients': ingredients,
        'steps': steps,
        'order': order,
        'slot': slot,
      };

  factory Recipe.fromMap(String id, Map<String, dynamic> map) => Recipe(
        id: id,
        name: (map['name'] ?? '').toString().trim(),
        category: (map['category'] ?? '').toString().trim(),
        ingredients: map['ingredients'] ?? '',
        steps: map['steps'] ?? '',
        order: (map['order'] as num?)?.toInt() ?? kNoOrder,
        slot: (map['slot'] ?? '').toString(),
      );
}
