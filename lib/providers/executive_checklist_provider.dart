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

  // 💡 [수정] Firestore에서 가져올 때 'order' 필드 기준으로 정렬
  void _listenToItems() {
    _db
        .collection('executive_checklist')
        .orderBy('order')
        .snapshots()
        .listen((snapshot) {
      _items = snapshot.docs
          .map((doc) => ExecutiveChecklistItem.fromMap(doc.id, doc.data()))
          .toList();
      notifyListeners();
    });
  }

  // 💡 [수정] 항목 추가 시 현재 아이템 개수를 order로 부여하여 맨 뒤에 배치
  Future<void> addItem(String title, String category, {String description = ''}) async {
    final int nextOrder = _items.length;
    await _db.collection('executive_checklist').add({
      'title': title,
      'category': category,
      'description': description,
      'isChecked': false,
      'order': nextOrder,
    });
  }

  // 💡 [신규] 순서 변경 시 Firestore의 'order' 필드를 일괄 업데이트 (Batch)
  Future<void> updateItemsOrder(String category, List<ExecutiveChecklistItem> reorderedList) async {
    final batch = _db.batch();

    for (int i = 0; i < reorderedList.length; i++) {
      final docRef = _db.collection('executive_checklist').doc(reorderedList[i].id);
      batch.update(docRef, {'order': i});
    }

    await batch.commit();
  }

  Future<void> toggleItem(String id, bool currentState) async {
    await _db.collection('executive_checklist').doc(id).update({
      'isChecked': !currentState,
    });
  }

  Future<void> deleteItem(String id) async {
    await _db.collection('executive_checklist').doc(id).delete();
  }

  Future<void> updateItem(String id, String title, String category, String description) async {
    await _db.collection('executive_checklist').doc(id).update({
      'title': title,
      'category': category,
      'description': description,
    });
  }
}