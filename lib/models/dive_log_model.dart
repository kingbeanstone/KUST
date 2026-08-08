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

/// 💡 실수/특이사항 태그 — 나중에 "어떤 상황에서 실수가 잦은지"
/// 인사이트를 뽑기 위한 원료. key는 저장용, value는 표시명.
const Map<String, String> kDiveTags = {
  'gear_miss': '장비 누락',
  'mask_flood': '마스크 물참',
  'weight': '웨이트 안맞음',
  'ear': '압평형 고생',
  'current': '조류 셌음',
  'entry': '입출수 허둥',
  'cold': '추웠음',
  'buddy_lost': '버디 놓침',
};

/// 개인 다이브 로그 한 회 (이 기기에 저장)
class DiveLog {
  final String id;
  final String date; // 'YYYY-MM-DD' (문자열 정렬 = 시간 정렬)
  final String site; // 다이빙 장소
  final String startTime; // 입수 시각 'HH:mm' (없으면 '')
  final String endTime; // 출수 시각 'HH:mm' (없으면 '')
  final double depth; // 최대 수심 (m)
  final double avgDepth; // 평균 수심 (m, 0=미입력 — 다이빙 컴퓨터 있을 때)
  final double? waterTemp; // 수온 (℃, null=미입력)
  final double duration; // 다이빙 시간 (분)
  final double startBar; // 시작 잔압
  final double endBar; // 종료 잔압

  /// 셀프 평가 (kDiveSkills key → 1~4 점수, 없으면 미평가)
  final Map<String, int> scores;

  /// 실수/특이사항 태그 (kDiveTags key 목록)
  final List<String> tags;

  DiveLog({
    required this.id,
    required this.date,
    this.site = '',
    this.startTime = '',
    this.endTime = '',
    this.depth = 0,
    this.avgDepth = 0,
    this.waterTemp,
    this.duration = 0,
    this.startBar = 0,
    this.endBar = 0,
    this.scores = const {},
    this.tags = const [],
  });

  /// 분당 공기 소모 (bar/min) — 낮을수록 호흡이 안정됐다는 뜻. 계산 불가면 null.
  double? get consumptionPerMin {
    if (duration <= 0 || startBar <= 0 || startBar <= endBar) return null;
    return (startBar - endBar) / duration;
  }

  /// 💡 수심 보정 분당 소모 (수면 환산 bar/min) — 깊을수록 같은 호흡에도
  /// 공기가 빨리 닳으므로, 평균 수심의 수압(1+수심/10기압)으로 나눠
  /// 수심이 달라도 공정하게 비교한다. 평균 수심이 없으면 보정 없이 원값.
  double? get correctedPerMin {
    final sac = consumptionPerMin;
    if (sac == null) return null;
    if (avgDepth <= 0) return sac;
    return sac / (1 + avgDepth / 10);
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'site': site,
        'startTime': startTime,
        'endTime': endTime,
        'depth': depth,
        'avgDepth': avgDepth,
        'waterTemp': waterTemp,
        'duration': duration,
        'startBar': startBar,
        'endBar': endBar,
        'scores': scores,
        'tags': tags,
      };

  factory DiveLog.fromMap(String id, Map<String, dynamic> map) => DiveLog(
        id: id,
        date: (map['date'] ?? '').toString(),
        site: (map['site'] ?? '').toString(),
        startTime: (map['startTime'] ?? '').toString(),
        endTime: (map['endTime'] ?? '').toString(),
        depth: (map['depth'] as num? ?? 0).toDouble(),
        avgDepth: (map['avgDepth'] as num? ?? 0).toDouble(),
        waterTemp: (map['waterTemp'] as num?)?.toDouble(),
        duration: (map['duration'] as num? ?? 0).toDouble(),
        startBar: (map['startBar'] as num? ?? 0).toDouble(),
        endBar: (map['endBar'] as num? ?? 0).toDouble(),
        scores: {
          for (final e
              in (map['scores'] as Map? ?? const {}).entries)
            if (e.value is num && (e.value as num) > 0)
              e.key.toString(): (e.value as num).toInt(),
        },
        tags: [
          for (final t in (map['tags'] as List? ?? const []))
            if (kDiveTags.containsKey(t.toString())) t.toString(),
        ],
      );
}
