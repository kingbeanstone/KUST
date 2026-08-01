/// 개인 다이브 로그 한 회 (club_members/{id}/dive_logs — 원정이 바뀌어도 쌓인다)
class DiveLog {
  final String id;
  final String date; // 'YYYY-MM-DD' (문자열 정렬 = 시간 정렬)
  final String site; // 다이빙 장소
  final double depth; // 최대 수심 (m)
  final double duration; // 다이빙 시간 (분)
  final double startBar; // 시작 잔압
  final double endBar; // 종료 잔압

  DiveLog({
    required this.id,
    required this.date,
    this.site = '',
    this.depth = 0,
    this.duration = 0,
    this.startBar = 0,
    this.endBar = 0,
  });

  /// 분당 공기 소모 (bar/min) — 낮을수록 호흡이 안정됐다는 뜻. 계산 불가면 null.
  double? get consumptionPerMin {
    if (duration <= 0 || startBar <= 0 || startBar <= endBar) return null;
    return (startBar - endBar) / duration;
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'site': site,
        'depth': depth,
        'duration': duration,
        'startBar': startBar,
        'endBar': endBar,
      };

  factory DiveLog.fromMap(String id, Map<String, dynamic> map) => DiveLog(
        id: id,
        date: (map['date'] ?? '').toString(),
        site: (map['site'] ?? '').toString(),
        depth: (map['depth'] as num? ?? 0).toDouble(),
        duration: (map['duration'] as num? ?? 0).toDouble(),
        startBar: (map['startBar'] as num? ?? 0).toDouble(),
        endBar: (map['endBar'] as num? ?? 0).toDouble(),
      );
}
