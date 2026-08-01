import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ingredient_model.dart';

/// 💡 원정 재료 잔량 관리 — expeditions/{id}/ingredients.
/// 기획부장이 잔량을 갱신하면 모두의 화면에 실시간 반영된다.
class IngredientProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _expeditionId;
  StreamSubscription? _sub;

  List<IngredientItem> _items = [];
  List<IngredientItem> get items => _items;

  CollectionReference<Map<String, dynamic>> get _col => _db
      .collection('expeditions')
      .doc(_expeditionId!)
      .collection('ingredients');

  /// ExpeditionProvider(ProxyProvider)가 호출. 원정 전환 시 구독을 갈아탄다.
  void setExpedition(String? expeditionId) {
    if (_expeditionId == expeditionId) return;
    _expeditionId = expeditionId;

    _sub?.cancel();
    _sub = null;
    _items = [];
    notifyListeners();

    if (expeditionId == null) return;
    _listen();
  }

  void _listen() {
    final expId = _expeditionId;
    _sub = _col.orderBy('name').snapshots().listen((snapshot) {
      _items = snapshot.docs
          .map((d) => IngredientItem.fromMap(d.id, d.data()))
          .toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('재료 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), () {
        if (_expeditionId == expId && expId != null) _listen();
      });
    });
  }

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    if (_expeditionId == null) return;
    _sub?.cancel();
    _listen();
  }

  Future<void> addItem(String name, String unit, double total) async {
    if (_expeditionId == null) return;
    await _col.add({
      'name': name.trim(),
      'unit': unit.trim(),
      'total': total,
      'remaining': total, // 처음엔 전량 보유
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem(IngredientItem item) async {
    if (_expeditionId == null) return;
    await _col.doc(item.id).set({
      ...item.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteItem(String id) async {
    if (_expeditionId == null) return;
    await _col.doc(id).delete();
  }
}
