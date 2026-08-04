/// 셀프 평가 요소 (레이더 차트의 축). key는 저장용, value는 표시명.
const Map<String, String> kDiveSkills = {
  'buoyancy': '부력',
  'breathing': '호흡',
  'trim': '자세',
  'buddy': '소통',
  'calm': '침착',
};

/// 평가 등급: 1 나쁨 · 2 보통 · 3 좋음 · 4 아주 좋음 (0/없음 = 미평가)
const Map<int, String> kSkillGrades = {
  1: '나쁨',
  2: '보통',
  3: '좋음',
  4: '아주 좋음',
};

/// 개인 다이브 로그 한 회 (이 기기에 저장)
class DiveLog {
  final String id;
  final String date; // 'YYYY-MM-DD' (문자열 정렬 = 시간 정렬)
  final String site; // 다이빙 장소
  final String startTime; // 입수 시각 'HH:mm' (없으면 '')
  final String endTime; // 출수 시각 'HH:mm' (없으면 '')
  final double depth; // 최대 수심 (m)
  final double duration; // 다이빙 시간 (분)
  final double startBar; // 시작 잔압
  final double endBar; // 종료 잔압

  /// 셀프 평가 (kDiveSkills key → 1~4 점수, 없으면 미평가)
  final Map<String, int> scores;

  DiveLog({
    required this.id,
    required this.date,
    this.site = '',
    this.startTime = '',
    this.endTime = '',
    this.depth = 0,
    this.duration = 0,
    this.startBar = 0,
    this.endBar = 0,
    this.scores = const {},
  });

  /// 분당 공기 소모 (bar/min) — 낮을수록 호흡이 안정됐다는 뜻. 계산 불가면 null.
  double? get consumptionPerMin {
    if (duration <= 0 || startBar <= 0 || startBar <= endBar) return null;
    return (startBar - endBar) / duration;
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'site': site,
        'startTime': startTime,
        'endTime': endTime,
        'depth': depth,
        'duration': duration,
        'startBar': startBar,
        'endBar': endBar,
        'scores': scores,
      };

  factory DiveLog.fromMap(String id, Map<String, dynamic> map) => DiveLog(
        id: id,
        date: (map['date'] ?? '').toString(),
        site: (map['site'] ?? '').toString(),
        startTime: (map['startTime'] ?? '').toString(),
        endTime: (map['endTime'] ?? '').toString(),
        depth: (map['depth'] as num? ?? 0).toDouble(),
        duration: (map['duration'] as num? ?? 0).toDouble(),
        startBar: (map['startBar'] as num? ?? 0).toDouble(),
        endBar: (map['endBar'] as num? ?? 0).toDouble(),
        scores: {
          for (final e
              in (map['scores'] as Map? ?? const {}).entries)
            if (e.value is num && (e.value as num) > 0)
              e.key.toString(): (e.value as num).toInt(),
        },
      );
}
