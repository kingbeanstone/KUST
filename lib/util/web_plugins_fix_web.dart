import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:firebase_storage_web/firebase_storage_web.dart';
import 'package:google_maps_flutter_web/google_maps_flutter_web.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:url_launcher_web/url_launcher_web.dart';

/// 💡 웹 플러그인 등록 복구.
/// 자동 생성되는 등록 코드는 플러그인들을 순서대로 등록하다가 하나가
/// 예외를 던지면 그 뒤 전부가 등록되지 않는다 (특정 폰에서 지도가
/// unregistered_view_type으로 죽던 원인). 여기서 핵심 플러그인을
/// 하나씩 try/catch로 다시 등록해 연쇄 실패를 차단하고,
/// 실패하는 플러그인 이름을 콘솔에 남긴다.
void ensureWebPluginsRegistered() {
  final Registrar registrar = webPluginRegistrar;

  void safely(String name, void Function() register) {
    try {
      register();
    } catch (e) {
      debugPrint('KUST 플러그인 등록 실패: $name → $e');
    }
  }

  safely('firebase_storage', () => FirebaseStorageWeb.registerWith(registrar));
  safely('google_maps', () => GoogleMapsPlugin.registerWith(registrar));
  safely('image_picker', () => ImagePickerPlugin.registerWith(registrar));
  safely('shared_preferences',
      () => SharedPreferencesPlugin.registerWith(registrar));
  safely('url_launcher', () => UrlLauncherPlugin.registerWith(registrar));
}
