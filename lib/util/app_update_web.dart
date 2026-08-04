import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 💡 서비스워커·캐시를 비우고 새로고침해 최신 배포판을 받는다.
/// index.html의 kustForceUpdate를 부르고, 함수가 없거나 실패하면
/// 일반 새로고침으로라도 갱신을 시도한다 (구버전 페이지 폴백).
void forceAppUpdate() {
  try {
    if (globalContext.getProperty('kustForceUpdate'.toJS).isA<JSFunction>()) {
      globalContext.callMethod('kustForceUpdate'.toJS);
      return;
    }
  } catch (_) {}

  // 폴백: 일반 새로고침
  try {
    final location = globalContext.getProperty('location'.toJS);
    if (location.isA<JSObject>()) {
      (location as JSObject).callMethod('reload'.toJS);
    }
  } catch (_) {}
}
