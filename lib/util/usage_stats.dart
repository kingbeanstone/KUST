import 'package:cloud_firestore/cloud_firestore.dart';

/// 💡 기능별 이용(접속) 횟수 누적 집계.
/// club_config/usage_stats 문서 하나에 {기능키: 횟수}로 쌓는다.
/// 실패해도 앱 동작에 영향 없도록 조용히 무시한다.
class UsageStats {
  static final DocumentReference<Map<String, dynamic>> doc =
      FirebaseFirestore.instance.collection('club_config').doc('usage_stats');

  /// 기능 키 → 표시 이름 (통계 화면용)
  static const Map<String, String> labels = {
    'tab_home': '홈 탭',
    'tab_schedule': '일정 탭',
    'tab_site': '사이트 탭',
    'tab_meal': '식단 탭',
    'tab_more': '더보기 탭',
    'equipment_check': '장비 체크',
    'buddy': '버디',
    'personal_checklist': '개인 체크리스트',
    'guide': '신입생 가이드',
    'growth': '성장 그래프',
    'member_list': '동아리원 명단',
    'participants': '참가자 관리',
    'inventory': '장비 인벤토리',
    'earth': '구글 어스 보기',
  };

  static void log(String key) {
    doc
        .set({key: FieldValue.increment(1)}, SetOptions(merge: true))
        .catchError((_) {});
  }
}
