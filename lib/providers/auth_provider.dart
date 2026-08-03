import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../util/usage_stats.dart';

class AuthProvider with ChangeNotifier {
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  bool _isPasswordSaved = false;
  bool get isPasswordSaved => _isPasswordSaved;

  final List<String> _debugLogs = [];
  List<String> get debugLogs => _debugLogs;

  AuthProvider() {
    _loadPreferences();
  }

  void addLog(String message) {
    final time = DateTime.now().toString().substring(11, 19);
    _debugLogs.insert(0, "[$time] $message");
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPasswordSaved = prefs.getBool('isPasswordSaved') ?? false;

      // 💡 앱 실행 시 이미 기억된 상태라면 즉시 관리자 권한 부여 (자동 로그인)
      if (_isPasswordSaved) {
        _isAdmin = true;
        addLog("✅ 저장된 정보로 관리자 자동 인증됨");
      }
      notifyListeners();
    } catch (e) {
      debugPrint("설정 로드 에러: $e");
    }
  }

  Future<bool> authenticate(String password, {bool remember = false}) async {
    // 💡 779=일반 관리자, 800=개발자 전용 (이 기기 접속은 이용 통계 집계 제외)
    if (password == "779" || password == "800") {
      _isAdmin = true;

      if (password == "800") {
        await UsageStats.setOptOut(true);
        addLog("🧑‍💻 개발자 인증 — 이 기기는 이용 통계 집계 제외");
      }

      // 💡 한 번이라도 기억하기를 선택했거나, 이번에 선택했다면 영구 유지
      if (remember || _isPasswordSaved) {
        _isPasswordSaved = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPasswordSaved', true);
        addLog("🔐 관리자 인증 성공 (정보 유지 중)");
      } else {
        addLog("🔐 관리자 인증 성공");
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  // 💡 명시적으로 '기억하기'를 취소하고 싶을 때만 사용하는 기능
  Future<void> forgetAdminSetting() async {
    _isPasswordSaved = false;
    _isAdmin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isPasswordSaved');
    addLog("🗑️ 저장된 관리자 정보를 삭제했습니다.");
    notifyListeners();
  }

  void logout() {
    _isAdmin = false;
    // 💡 로그아웃을 해도 _isPasswordSaved는 건드리지 않습니다.
    // 그래야 인증 버튼 클릭 시 다시 비밀번호를 묻지 않습니다.
    addLog("🔓 관리자 모드 해제 (설정은 유지됨)");
    notifyListeners();
  }
}