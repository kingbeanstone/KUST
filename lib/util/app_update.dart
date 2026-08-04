import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_version.dart';
import 'app_update_stub.dart'
    if (dart.library.js_interop) 'app_update_web.dart';

/// 💡 인앱 업데이트.
/// 배포할 때마다 club_config/app_config 문서의 latest 필드를 새 버전으로 갱신하고,
/// 앱은 이를 실시간 구독해 내 버전(kAppVersion)과 비교한다.
/// 업데이트 실행 = 서비스워커·캐시를 비우고 새로고침 (PWA 강제 최신화).
class AppUpdate {
  static final DocumentReference<Map<String, dynamic>> doc =
      FirebaseFirestore.instance.collection('club_config').doc('app_config');

  /// 'v2.20.1 (8/5)' → [2, 20, 1]
  static List<int> _nums(String v) {
    final m = RegExp(r'v?(\d+)\.(\d+)\.(\d+)').firstMatch(v);
    if (m == null) return const [0, 0, 0];
    return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  }

  /// 표시용 현재 버전 (날짜 꼬리표 제외, 예: 'v2.20.1')
  static String get current => kAppVersion.split(' ').first;

  /// latest가 지금 실행 중인 버전보다 새것인가
  static bool isNewer(String? latest) {
    if (latest == null || latest.trim().isEmpty) return false;
    final a = _nums(latest);
    final b = _nums(kAppVersion);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static void apply() => forceAppUpdate();
}
