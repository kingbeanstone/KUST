import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 💡 index.html의 kustAudio* 함수 호출 (검증된 globalContext 패턴).
/// 함수가 없거나 실패하면 false — 호출부가 audioplayers로 폴백한다.
bool audioPlay(String url, bool loop, double volume) {
  try {
    if (!globalContext.getProperty('kustAudioPlay'.toJS).isA<JSFunction>()) {
      return false;
    }
    globalContext.callMethod(
        'kustAudioPlay'.toJS, url.toJS, loop.toJS, volume.toJS);
    return true;
  } catch (_) {
    return false;
  }
}

bool audioPause(String url) {
  try {
    if (!globalContext.getProperty('kustAudioPause'.toJS).isA<JSFunction>()) {
      return false;
    }
    globalContext.callMethod('kustAudioPause'.toJS, url.toJS);
    return true;
  } catch (_) {
    return false;
  }
}

void audioLoad(String url) {
  try {
    if (globalContext.getProperty('kustAudioLoad'.toJS).isA<JSFunction>()) {
      globalContext.callMethod('kustAudioLoad'.toJS, url.toJS);
    }
  } catch (_) {}
}
