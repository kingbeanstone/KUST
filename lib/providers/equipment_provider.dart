import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/equipment_model.dart';

class EquipmentProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 💡 관리자 인증 상태
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  List<MemberEquipment> _data = [];
  List<MemberEquipment> get data => _data;

  List<MealPlan> _meals = [];
  List<MealPlan> get meals => _meals;

  EquipmentProvider() {
    _listenToMembers();
    _listenToMeals();
  }

  // 💡 관리자 인증 로직
  bool authenticate(String password) {
    if (password == "779") {
      _isAdmin = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  // 💡 로그아웃 로직 (필요 시)
  void logoutAdmin() {
    _isAdmin = false;
    notifyListeners();
  }

  void _listenToMembers() {
    _db.collection('members').snapshots().listen((snapshot) {
      _data = snapshot.docs.map((doc) => MemberEquipment.fromMap(doc.id, doc.data())).toList();
      _data.sort((a, b) => a.order.compareTo(b.order));
      notifyListeners();
    });
  }

  void _listenToMeals() {
    _db.collection('meals').snapshots().listen((snapshot) {
      _meals = snapshot.docs.map((doc) => MealPlan.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  // --- Firestore 수정 메서드들 (isAdmin 권한 체크는 UI단에서 수행) ---

  Future<void> resetAllChecks() async {
    if (!_isAdmin) return; // 2중 방어
    final batch = _db.batch();
    for (var member in _data) {
      Map<String, dynamic> resetGears = {};
      member.gears.forEach((key, gear) {
        resetGears[key] = {'value': gear.value, 'checked': false};
      });
      batch.set(_db.collection('members').doc(member.id), resetGears, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> addRow() async {
    if (!_isAdmin) return;
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    int nextOrder = _data.isEmpty ? 0 : _data.last.order + 1;
    final newRow = MemberEquipment(
      id: id, name: '', order: nextOrder,
      gears: { for (var k in ['가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타']) k: GearStatus() },
    );
    await _db.collection('members').doc(id).set(newRow.toMap());
  }

  Future<void> saveBulkChanges(List<MemberEquipment> updatedList) async {
    if (!_isAdmin) return;
    final batch = _db.batch();
    for (var member in updatedList) {
      batch.set(_db.collection('members').doc(member.id), member.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> toggleCheck(String id, String field) async {
    if (!_isAdmin) return;
    final member = _data.firstWhere((m) => m.id == id);
    final bool currentStatus = member.gears[field]?.checked ?? false;
    await _db.collection('members').doc(id).set({ field: { 'checked': !currentStatus } }, SetOptions(merge: true));
  }

  Future<void> deleteMember(String id) async {
    if (!_isAdmin) return;
    await _db.collection('members').doc(id).delete();
  }

  Future<void> saveMeal(MealPlan meal) async {
    if (!_isAdmin) return;
    await _db.collection('meals').doc(meal.id).set(meal.toMap());
  }
}