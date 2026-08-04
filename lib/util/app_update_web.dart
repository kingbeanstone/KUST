import 'dart:js_interop';

@JS('kustForceUpdate')
external void _kustForceUpdate();

/// 💡 서비스워커 등록 해제 + 캐시 삭제 + 새로고침 (index.html에 정의됨).
/// PWA가 캐시된 구버전을 버리고 최신 배포판을 즉시 받게 한다.
void forceAppUpdate() => _kustForceUpdate();
