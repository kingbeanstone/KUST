import 'package:flutter/foundation.dart';

import 'game_audio_stub.dart'
    if (dart.library.js_interop) 'game_audio_web.dart' as bridge;

/// 💡 게임 오디오.
/// 웹(PWA)에서는 audioplayers 웹 구현이 기기에 따라 소리 없이 실패하는
/// 문제가 있어, index.html의 순정 <audio> 브리지(kustAudio*)로 재생한다.
/// 네이티브에서는 이 함수들이 전부 false를 돌려주므로 호출부가
/// 기존 audioplayers(AssetSource) 경로를 그대로 탄다.
const String _base = 'assets/assets/audio/';

/// 웹이면 순정 <audio>로 재생하고 true. 아니면 false (호출부가 폴백).
bool webAudioPlay(String file, {bool loop = false, double volume = 1.0}) {
  if (!kIsWeb) return false;
  return bridge.audioPlay('$_base$file', loop, volume);
}

/// 웹 브금 일시정지. 처리했으면 true.
bool webAudioPause(String file) {
  if (!kIsWeb) return false;
  return bridge.audioPause('$_base$file');
}

/// 💡 게임 허브 진입 시 미리 불러두기 — 첫 재생 지연·버벅임 완화.
void preloadGameAudio() {
  if (!kIsWeb) return;
  for (final f in [
    'jurumarble_bgm.wav',
    'dice.wav',
    'land.wav',
    'beep.wav',
  ]) {
    bridge.audioLoad('$_base$f');
  }
}
