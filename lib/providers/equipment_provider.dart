import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/equipment_model.dart';

class EquipmentProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 💡 앱 내 디버그 콘솔용 로그 리스트
  final List<String> _debugLogs = [];
  List<String> get debugLogs => _debugLogs;

  void addLog(String message) {
    final time = DateTime.now().toString().substring(11, 19);
    _debugLogs.insert(0, "[$time] $message");
    notifyListeners();
  }

  // 💡 관리자 권한 상태 관리
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  // 💡 비밀번호 기억하기 상태 (영구 저장됨)
  bool _isPasswordSaved = false;
  bool get isPasswordSaved => _isPasswordSaved;

  void setAdminStatus(bool status) {
    _isAdmin = status;
    notifyListeners();
  }

  // 💡 데이터 리스트
  List<MemberEquipment> _data = [];
  List<BcdItem> _bcds = [];
  List<RegulatorItem> _regulators = [];
  List<GeneralGearItem> _generalGears = [];

  List<MemberEquipment> get data => _data;
  List<BcdItem> get bcds => _bcds;
  List<RegulatorItem> get regulators => _regulators;
  List<GeneralGearItem> get generalGears => _generalGears;

  EquipmentProvider() {
    _initProvider();
  }

  Future<void> _initProvider() async {
    addLog("장비 시스템 초기화...");
    await _loadPreferences(); // 💡 시작 시 저장된 관리자 설정 불러오기
    _listenToMembers();
    _listenToInventory();
    _listenToGeneralGears();
  }

  // --- 설정 및 관리자 인증 로직 (영구 저장 기능 포함) ---

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPasswordSaved = prefs.getBool('isPasswordSaved') ?? false;

      // 💡 만약 비밀번호 기억하기가 켜져 있었다면, 앱 시작 시 자동으로 관리자 권한 부여
      if (_isPasswordSaved) {
        _isAdmin = true;
        addLog("기억된 설정으로 관리자 자동 인증됨");
      }
      notifyListeners();
    } catch (e) {
      addLog("설정 로드 실패: $e");
    }
  }

  Future<bool> authenticate(String password, {bool remember = false}) async {
    if (password == "779") {
      _isAdmin = true;
      _isPasswordSaved = remember;

      // 💡 '기억하기' 여부를 기기에 영구 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPasswordSaved', remember);

      addLog("관리자 인증 성공 (기억하기: $remember)");
      notifyListeners();
      return true;
    }
    return false;
  }

  void logoutAdmin() {
    _isAdmin = false;
    // 💡 로그아웃(해제)을 하더라도 '기억하기' 설정 자체는 유지합니다.
    // 그래야 다음에 다시 '인증' 버튼을 눌렀을 때 비밀번호 없이 들어갈 수 있습니다.
    addLog("관리자 모드 해제 (설정은 유지됨)");
    notifyListeners();
  }

  // 💡 만약 '기억하기' 설정 자체를 완전히 지우고 싶을 때 사용 (선택 사항)
  Future<void> forgetAdmin() async {
    _isAdmin = false;
    _isPasswordSaved = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isPasswordSaved');
    addLog("관리자 설정 완전 초기화");
    notifyListeners();
  }

  // --- 실시간 데이터 리스너 (Firestore) ---
  void _listenToMembers() {
    _db.collection('members').orderBy('order').snapshots().listen((snapshot) {
      _data = snapshot.docs.map((doc) => MemberEquipment.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  void _listenToInventory() {
    _db.collection('bcds').snapshots().listen((snapshot) {
      _bcds = snapshot.docs.map((doc) => BcdItem.fromMap(doc.id, doc.data())).toList();
      _bcds.sort((a, b) => int.tryParse(a.id)?.compareTo(int.tryParse(b.id) ?? 0) ?? a.id.compareTo(b.id));
      notifyListeners();
    });
    _db.collection('regulators').snapshots().listen((snapshot) {
      _regulators = snapshot.docs.map((doc) => RegulatorItem.fromMap(doc.id, doc.data())).toList();
      _regulators.sort((a, b) => int.tryParse(a.id)?.compareTo(int.tryParse(b.id) ?? 0) ?? a.id.compareTo(b.id));
      notifyListeners();
    });
  }

  void _listenToGeneralGears() {
    _db.collection('general_gears').snapshots().listen((snapshot) {
      _generalGears = snapshot.docs.map((doc) => GeneralGearItem.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  // --- SearchScreen 필수 메서드 (인벤토리 관리) ---
  Future<void> addBcd(String id, String name, String memo) async => await _db.collection('bcds').doc(id).set({'name': name, 'memo': memo});
  Future<void> updateBcd(String id, String name, String memo) async {
    if (!_isAdmin) return;
    await _db.collection('bcds').doc(id).update({'name': name, 'memo': memo});
  }
  Future<void> deleteBcd(String id) async { if (_isAdmin) await _db.collection('bcds').doc(id).delete(); }

  Future<void> addRegulator(String id, String name, String memo) async => await _db.collection('regulators').doc(id).set({'name': name, 'memo': memo});
  Future<void> updateRegulator(String id, String name, String memo) async {
    if (!_isAdmin) return;
    await _db.collection('regulators').doc(id).update({'name': name, 'memo': memo});
  }
  Future<void> deleteRegulator(String id) async { if (_isAdmin) await _db.collection('regulators').doc(id).delete(); }

  // 공용 장비 관리
  Future<void> updateGeneralGearCount(String gearId, int delta) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('general_gears').doc(gearId);
    final doc = await docRef.get();
    if (doc.exists) {
      int current = doc.data()?['count'] ?? 0;
      await docRef.update({'count': (current + delta) < 0 ? 0 : (current + delta)});
    }
  }

  Future<void> addGeneralGearMemo(String gearId, String memo) async {
    if (!_isAdmin) return;
    await _db.collection('general_gears').doc(gearId).update({'memos': FieldValue.arrayUnion([memo])});
  }

  Future<void> deleteGeneralGearMemo(String gearId, int index) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('general_gears').doc(gearId);
    final doc = await docRef.get();
    if (doc.exists) {
      List<String> memos = List<String>.from(doc.data()?['memos'] ?? []);
      if (index >= 0 && index < memos.length) {
        memos.removeAt(index);
        await docRef.update({'memos': memos});
      }
    }
  }

  // --- 장비 체크리스트 CRUD ---
  Future<void> saveBulkChanges(List<MemberEquipment> updatedList) async {
    if (!_isAdmin) return;
    final batch = _db.batch();
    for (var member in updatedList) {
      batch.set(_db.collection('members').doc(member.id), member.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
    addLog("장비 데이터 일괄 저장 완료");
  }

  Future<void> addRow() async {
    if (!_isAdmin) return;
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    int nextOrder = _data.isEmpty ? 0 : _data.last.order + 1;
    final newRow = MemberEquipment(
        id: id, name: '', order: nextOrder,
        gears: {for (var k in ['가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타']) k: GearStatus()}
    );
    await _db.collection('members').doc(id).set(newRow.toMap());
  }

  Future<void> deleteMember(String id) async {
    if (!_isAdmin) {
      addLog("삭제 실패: 권한 없음");
      return;
    }
    try {
      await _db.collection('members').doc(id).delete();
      addLog("행 삭제 성공: $id");
    } catch (e) {
      addLog("삭제 중 에러 발생: $e");
    }
  }

  Future<void> toggleCheck(String id, String field) async {
    if (!_isAdmin) return;
    final member = _data.firstWhere((m) => m.id == id);
    final bool currentStatus = member.gears[field]?.checked ?? false;
    await _db.collection('members').doc(id).set({field: {'checked': !currentStatus}}, SetOptions(merge: true));
  }

  Future<void> resetAllChecks() async {
    if (!_isAdmin) return;
    final batch = _db.batch();
    for (var member in _data) {
      Map<String, dynamic> resetGears = {};
      member.gears.forEach((key, gear) {
        resetGears[key] = {'value': gear.value, 'checked': false};
      });
      batch.set(_db.collection('members').doc(member.id), resetGears, SetOptions(merge: true));
    }
    await batch.commit();
    addLog("체크리스트 전체 리셋 완료");
  }
}