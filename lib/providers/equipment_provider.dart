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
  List<EquipmentGroup> _groups = [];

  List<MemberEquipment> get data => _data;
  List<BcdItem> get bcds => _bcds;
  List<RegulatorItem> get regulators => _regulators;
  List<GeneralGearItem> get generalGears => _generalGears;
  List<EquipmentGroup> get groups => _groups;

  EquipmentProvider() {
    _initProvider();
  }

  Future<void> _initProvider() async {
    addLog("장비 시스템 초기화...");
    await _loadPreferences(); // 💡 시작 시 저장된 관리자 설정 불러오기
    _listenToMembers();
    _listenToInventory();
    _listenToGeneralGears();
    _listenToGroups();
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

  void _listenToGroups() {
    _db.collection('config').doc('equipment_groups').snapshots().listen((doc) {
      final list = (doc.data()?['groups'] as List?) ?? [];
      _groups = list
          .map((g) => EquipmentGroup.fromMap(Map<String, dynamic>.from(g)))
          .toList();
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
    final bool next = !(member.gears[field]?.checked ?? false);

    // 💡 짝과 함께 쓰는 장비는 한 개뿐이므로 두 사람의 체크가 따로 놀면 안 된다.
    final targets = member.sharesGear(field) ? _pairMemberIds(member) : [id];

    final batch = _db.batch();
    for (final target in targets) {
      batch.set(_db.collection('members').doc(target), {
        field: {'checked': next}
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // --- 장비 그룹(교육 1팀 등 자유 라벨) 관리 ---

  Future<void> _saveGroups(List<EquipmentGroup> groups) async {
    await _db.collection('config').doc('equipment_groups').set({
      'groups': groups.map((g) => g.toMap()).toList(),
    });
  }

  Future<void> addGroup(String name) async {
    if (!_isAdmin || name.trim().isEmpty) return;
    final group = EquipmentGroup(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
    );
    await _saveGroups([..._groups, group]);
    addLog('그룹 추가: ${group.name}');
  }

  Future<void> deleteGroup(String groupId) async {
    if (!_isAdmin) return;
    // 소속 대원을 먼저 미지정으로 되돌린 뒤 그룹을 지운다.
    final batch = _db.batch();
    for (final m in _data.where((m) => m.groupId == groupId)) {
      batch.set(_db.collection('members').doc(m.id), {'groupId': ''}, SetOptions(merge: true));
    }
    await batch.commit();
    await _saveGroups(_groups.where((g) => g.id != groupId).toList());
  }

  /// 대원을 그룹에 배정한다. 장비 버디가 있으면 표가 깨지지 않도록 짝도 함께 옮긴다.
  /// groupId가 빈 값이면 미지정 처리.
  Future<void> assignToGroup(String memberId, String groupId) async {
    if (!_isAdmin) return;
    final member = _data.firstWhere((m) => m.id == memberId);
    final targets = member.hasPair ? _pairMemberIds(member) : [memberId];

    final batch = _db.batch();
    for (final id in targets) {
      batch.set(_db.collection('members').doc(id), {'groupId': groupId}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // --- 장비 버디(2인 1조) 관리 ---

  List<String> _pairMemberIds(MemberEquipment member) {
    if (!member.hasPair) return [member.id];
    return _data.where((m) => m.pairId == member.pairId).map((m) => m.id).toList();
  }

  /// 두 대원을 장비 버디로 묶는다. 이미 다른 짝이 있으면 먼저 풀린다.
  Future<void> pairMembers(String idA, String idB) async {
    if (!_isAdmin || idA == idB) return;
    final pairId = 'pair_${DateTime.now().millisecondsSinceEpoch}';

    final batch = _db.batch();
    for (final id in [idA, idB]) {
      final existing = _data.firstWhere((m) => m.id == id);
      // 기존 짝의 상대방을 먼저 홀로 되돌린다.
      if (existing.hasPair) {
        for (final other in _data.where((m) => m.pairId == existing.pairId && m.id != id)) {
          batch.set(_db.collection('members').doc(other.id),
              {'pairId': '', 'sharedGears': <String>[]}, SetOptions(merge: true));
        }
      }
      batch.set(_db.collection('members').doc(id),
          {'pairId': pairId, 'sharedGears': <String>[]}, SetOptions(merge: true));
    }
    await batch.commit();
    addLog('장비 버디 편성: $idA + $idB');
  }

  /// 짝을 해제하고 공유 설정도 함께 지운다.
  Future<void> unpairMembers(String pairId) async {
    if (!_isAdmin || pairId.isEmpty) return;
    final batch = _db.batch();
    for (final m in _data.where((m) => m.pairId == pairId)) {
      batch.set(_db.collection('members').doc(m.id),
          {'pairId': '', 'sharedGears': <String>[]}, SetOptions(merge: true));
    }
    await batch.commit();
    addLog('장비 버디 해제: $pairId');
  }

  /// 짝이 특정 장비를 함께 쓰는지 여부를 뒤집는다.
  /// 공유로 바꿀 때는 대표(순서가 앞선 대원)의 값으로 통일한다.
  Future<void> toggleGearShare(String pairId, String gear) async {
    if (!_isAdmin || pairId.isEmpty) return;

    final members = _data.where((m) => m.pairId == pairId).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    if (members.length < 2) return;

    final willShare = !members.first.sharedGears.contains(gear);
    final leadGear = members.first.gears[gear];

    final batch = _db.batch();
    for (final m in members) {
      final shared = List<String>.from(m.sharedGears);
      willShare ? shared.add(gear) : shared.remove(gear);

      final update = <String, dynamic>{'sharedGears': shared};
      if (willShare) {
        // 합쳐진 칸은 하나의 값만 가지므로 대표의 번호/체크로 맞춘다.
        update[gear] = {'value': leadGear?.value ?? '', 'checked': leadGear?.checked ?? false};
      }
      batch.set(_db.collection('members').doc(m.id), update, SetOptions(merge: true));
    }
    await batch.commit();
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