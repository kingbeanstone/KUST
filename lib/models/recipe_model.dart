/// 동아리 공용 레시피 (원정이 바뀌어도 유지되는 자산)
class Recipe {
  final String id;
  final String name; // 요리 이름 (식단 칸에 들어가는 텍스트)
  final String ingredients; // 재료 (자유 텍스트, 줄바꿈 구분)
  final String steps; // 조리법 (자유 텍스트)

  Recipe({
    required this.id,
    required this.name,
    this.ingredients = '',
    this.steps = '',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'ingredients': ingredients,
        'steps': steps,
      };

  factory Recipe.fromMap(String id, Map<String, dynamic> map) => Recipe(
        id: id,
        name: (map['name'] ?? '').toString().trim(),
        ingredients: map['ingredients'] ?? '',
        steps: map['steps'] ?? '',
      );
}
