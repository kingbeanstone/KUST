/// 원정 재료 (기획부장이 잔량을 갱신하며 소비 페이스를 판단한다)
class IngredientItem {
  final String id;
  final String name; // 품목 (쌀, 돼지고기…)
  final String unit; // 단위 (kg, 개, 팩…)
  final double total; // 준비해 간 총량
  final double remaining; // 현재 남은 양

  IngredientItem({
    required this.id,
    required this.name,
    this.unit = '',
    this.total = 0,
    this.remaining = 0,
  });

  double get remainRatio => total <= 0 ? 0 : (remaining / total).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => {
        'name': name,
        'unit': unit,
        'total': total,
        'remaining': remaining,
      };

  factory IngredientItem.fromMap(String id, Map<String, dynamic> map) =>
      IngredientItem(
        id: id,
        name: (map['name'] ?? '').toString().trim(),
        unit: (map['unit'] ?? '').toString().trim(),
        total: (map['total'] as num? ?? 0).toDouble(),
        remaining: (map['remaining'] as num? ?? 0).toDouble(),
      );
}
