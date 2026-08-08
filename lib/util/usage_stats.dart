import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 💡 기능별 이용(접속) 횟수 누적 집계.
/// club_config/usage_stats 문서 하나에 {기능키: 횟수}로 쌓는다.
/// 실패해도 앱 동작에 영향 없도록 조용히 무시한다.
class UsageStats {
  static final DocumentReference<Map<String, dynamic>> doc =
      FirebaseFirestore.instance.collection('club_config').doc('usage_stats');

  /// 기능 키 → 표시 이름 (통계 화면용).
  /// 💡 여기 있는 키만 집계·표시한다 — 항목 조정 시 이 맵만 고치면 된다.
  static const Map<String, String> labels = {
    'weather': '날씨',
    'trip': '동기여행',
    'equipment_check': '장비 체크',
    'buddy': '버디표',
    'personal_checklist': '개인 체크리스트',
    'guide': '신입 가이드',
    'growth': '성장 그래프',
    'species': '생물 도감',
    'game': '미니 게임',
    'tab_schedule': '일정 탭',
    'tab_site': '사이트 탭',
    'earth': '구글 어스',
    'tab_meal': '식단',
    'tab_more': '더보기',
  };

  /// 💡 이 기기 접속 제외 여부 (개발자/관리자 기기의 통계 오염 방지)
  static bool _optOut = false;
  static bool get optOut => _optOut;

  /// 앱 시작 시 한 번 호출 — 제외 설정을 불러온다
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _optOut = prefs.getBool('usage_stats_opt_out') ?? false;
    } catch (_) {}
  }

  static Future<void> setOptOut(bool value) async {
    _optOut = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('usage_stats_opt_out', value);
  }

  /// 히트맵 열 머리용 짧은 이름
  static const Map<String, String> shortLabels = {
    'weather': '날씨',
    'trip': '여행',
    'equipment_check': '장비',
    'buddy': '버디',
    'personal_checklist': '체크',
    'guide': '가이드',
    'growth': '성장',
    'species': '도감',
    'game': '게임',
    'tab_schedule': '일정',
    'tab_site': '사이트',
    'earth': '어스',
    'tab_meal': '식단',
    'tab_more': '더보기',
  };

  /// 시간별 버킷 — usage_stats 문서 아래 hourly/{yyyy-MM-dd-HH} 서브컬렉션.
  /// 💡 저장은 시간 단위가 기본. 일 단위 보기는 화면에서 이걸 합산해 만든다.
  static CollectionReference<Map<String, dynamic>> get hourly =>
      doc.collection('hourly');

  static void log(String key) {
    if (_optOut) return; // 이 기기는 집계 제외
    if (!labels.containsKey(key)) return; // 집계 대상 아님
    doc
        .set({key: FieldValue.increment(1)}, SetOptions(merge: true))
        .catchError((_) {});

    // 시간별 누적 (문서 ID가 시간순 정렬되도록 zero-pad)
    final now = DateTime.now();
    final bucket = '${now.year}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}';
    hourly
        .doc(bucket)
        .set({key: FieldValue.increment(1)}, SetOptions(merge: true))
        .catchError((_) {});
  }
}
