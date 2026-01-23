import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/equipment_model.dart';

class EquipmentProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  List<MemberEquipment> _data = [];
  List<MemberEquipment> get data => _data;

  List<MealPlan> _meals = [];
  List<MealPlan> get meals => _meals;

  List<DailySchedule> _schedules = [];
  List<DailySchedule> get schedules => _schedules;

  List<NoticeItem> _notices = [];
  List<NoticeItem> get notices => _notices;

  EquipmentProvider() {
    _listenToMembers();
    _listenToMeals();
    _listenToSchedules();
    _listenToNotices();
  }

  bool authenticate(String password) {
    if (password == "779") {
      _isAdmin = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logoutAdmin() {
    _isAdmin = false;
    notifyListeners();
  }

  // --- Firestore 리스너 ---
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

  void _listenToSchedules() {
    _db.collection('schedules').snapshots().listen((snapshot) {
      _schedules = snapshot.docs.map((doc) => DailySchedule.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  void _listenToNotices() {
    _db.collection('notices').snapshots().listen((snapshot) {
      _notices = snapshot.docs.map((doc) => NoticeItem.fromMap(doc.id, doc.data())).toList();
      _notices.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    });
  }

  // --- 공지사항 관련 메서드 ---
  Future<void> addNotice(String title, String content) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('notices').doc();
    await docRef.set({
      'title': title,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 💡 공지사항 수정 메서드 추가
  Future<void> updateNotice(String id, String title, String content) async {
    if (!_isAdmin) return;
    await _db.collection('notices').doc(id).update({
      'title': title,
      'content': content,
      // 수정 시 시간을 갱신하고 싶다면 아래 주석을 해제하세요.
      // 'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteNotice(String id) async {
    if (!_isAdmin) return;
    await _db.collection('notices').doc(id).delete();
  }

  // --- 기존 메서드들 (장비, 식단, 일정) 유지 ---
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

  Future<void> addScheduleItem(String dateId, ScheduleItem newItem) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('schedules').doc(dateId);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({'items': FieldValue.arrayUnion([newItem.toMap()])});
    } else {
      await docRef.set({'items': [newItem.toMap()]});
    }
  }

  Future<void> updateScheduleItem(String dateId, int index, ScheduleItem updatedItem) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('schedules').doc(dateId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    List items = List.from(doc.data()?['items'] as List);
    items[index] = updatedItem.toMap();
    await docRef.update({'items': items});
  }

  Future<void> deleteScheduleItem(String dateId, int index) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('schedules').doc(dateId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    List items = List.from(doc.data()?['items'] as List);
    items.removeAt(index);
    await docRef.update({'items': items});
  }
}