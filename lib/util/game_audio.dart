import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 💡 게임 오디오 소스 헬퍼.
/// PWA(웹)에서는 서비스워커가 캐시한 오디오 파일을 <audio> 태그로 재생할 때
/// Range 요청이 처리되지 않아 소리 없이 실패하는 문제가 있다 (특히 안드로이드
/// 크롬). 그래서 웹에서는 에셋을 바이트로 읽어 data URI로 재생하고,
/// 네이티브에서는 기존 AssetSource를 그대로 쓴다.
final Map<String, BytesSource> _bytesCache = {};

Future<Source> gameAudioSource(String file) async {
  if (!kIsWeb) return AssetSource('audio/$file');
  final cached = _bytesCache[file];
  if (cached != null) return cached;
  final data = await rootBundle.load('assets/audio/$file');
  final src = BytesSource(data.buffer.asUint8List(), mimeType: 'audio/wav');
  _bytesCache[file] = src;
  return src;
}
