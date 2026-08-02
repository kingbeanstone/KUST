import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 💡 구글맵 JS 라이브러리(MapTypeId 상수까지)가 준비될 때까지 대기.
/// index.html이 어떤 로딩 방식(동기/동적 로더)이든, 준비 전에 지도 위젯을
/// 만들다 터지는 타이밍 크래시를 원천 차단한다. (최대 15초, 실패 시 false)
Future<bool> waitForGoogleMaps() async {
  var importRequested = false;

  for (var i = 0; i < 150; i++) {
    final google = globalContext.getProperty('google'.toJS);
    if (google.isA<JSObject>()) {
      final maps = (google as JSObject).getProperty('maps'.toJS);
      if (maps.isA<JSObject>()) {
        final mapsObj = maps as JSObject;

        // MapTypeId 상수가 있으면 라이브러리가 완전히 로드된 것
        if (mapsObj.getProperty('MapTypeId'.toJS).isA<JSObject>()) {
          return true;
        }

        // 동적 로더만 있는 경우: 직접 라이브러리 로드를 요청한다
        if (!importRequested &&
            mapsObj.getProperty('importLibrary'.toJS).isA<JSFunction>()) {
          mapsObj.callMethod('importLibrary'.toJS, 'maps'.toJS);
          mapsObj.callMethod('importLibrary'.toJS, 'marker'.toJS);
          importRequested = true;
        }
      }
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }
  return false;
}
