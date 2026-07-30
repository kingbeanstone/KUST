/// 💡 v2: 원정(시즌) 단위. 연 4회(춘계/하계/추계/동계) × 연도.
/// 원정별 데이터(장비/버디/일정/식단)는 expeditions/{id}/ 서브컬렉션에 담긴다.
class Expedition {
  final String id; // 예: 2025_winter
  final int year;
  final String season; // spring | summer | autumn | winter

  Expedition({required this.id, required this.year, required this.season});

  static const Map<String, String> seasonLabels = {
    'spring': '춘계',
    'summer': '하계',
    'autumn': '추계',
    'winter': '동계',
  };

  /// 정렬용: 같은 해 안에서 춘계 → 동계 순
  static const Map<String, int> seasonOrder = {
    'spring': 1,
    'summer': 2,
    'autumn': 3,
    'winter': 4,
  };

  String get seasonLabel => seasonLabels[season] ?? season;
  String get label => '${year % 100}년 $seasonLabel 원정';

  int get sortKey => year * 10 + (seasonOrder[season] ?? 0);

  Map<String, dynamic> toMap() => {'year': year, 'season': season};

  factory Expedition.fromMap(String id, Map<String, dynamic> map) => Expedition(
        id: id,
        year: map['year'] is int ? map['year'] : 0,
        season: map['season']?.toString() ?? '',
      );
}
