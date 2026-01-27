import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/executive_checklist_model.dart';

class ExecutiveChecklistProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<ExecutiveChecklistItem> _items = [];

  List<ExecutiveChecklistItem> get items => _items;

  ExecutiveChecklistProvider() {
    _listenToItems();
  }

  // 실시간 데이터 감시
  void _listenToItems() {
    _db.collection('executive_checklist').snapshots().listen((snapshot) {
      _items = snapshot.docs
          .map((doc) => ExecutiveChecklistItem.fromMap(doc.id, doc.data()))
          .toList();
      notifyListeners();
    });
  }

  // 항목 추가
  Future<void> addItem(String title, String category, {String description = ''}) async {
    await _db.collection('executive_checklist').add({
      'title': title,
      'category': category,
      'description': description,
      'isChecked': false,
    });
  }

  // 체크 상태 토글
  Future<void> toggleItem(String id, bool currentState) async {
    await _db.collection('executive_checklist').doc(id).update({
      'isChecked': !currentState,
    });
  }

  // 항목 삭제
  Future<void> deleteItem(String id) async {
    await _db.collection('executive_checklist').doc(id).delete();
  }

  // 항목 수정
  Future<void> updateItem(String id, String title, String category, String description) async {
    await _db.collection('executive_checklist').doc(id).update({
      'title': title,
      'category': category,
      'description': description,
    });
  }
}