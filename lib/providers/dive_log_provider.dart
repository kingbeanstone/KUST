import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dive_log_model.dart';

/// 💡 개인 다이브 로그 — club_members/{memberId}/dive_logs.
/// '내 이름 선택'은 기기에 저장되고, 로그는 동아리 레벨이라 원정과 무관하게 쌓인다.
class DiveLogProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _memberId;
  String? get memberId => _memberId;

  StreamSubscription? _sub;

  List<DiveLog> _logs = [];

  /// 날짜순 (같은 날은 문서 생성순)
  List<DiveLog> get logs => _logs;

  CollectionReference<Map<String, dynamic>> _col(String memberId) =>
      _db.collection('club_members').doc(memberId).collection('dive_logs');

  void setMember(String? memberId) {
    if (_memberId == memberId) return;
    _memberId = memberId;

    _sub?.cancel();
    _sub = null;
    _logs = [];
    notifyListeners();

    if (memberId == null) return;
    _listen();
  }

  void _listen() {
    final id = _memberId;
    if (id == null) return;
    _sub = _col(id).orderBy('date').snapshots().listen((snapshot) {
      _logs =
          snapshot.docs.map((d) => DiveLog.fromMap(d.id, d.data())).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('다이브 로그 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), () {
        if (_memberId == id) _listen();
      });
    });
  }

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    if (_memberId == null) return;
    _sub?.cancel();
    _listen();
  }

  Future<void> addLog(DiveLog log) async {
    final id = _memberId;
    if (id == null) return;
    await _col(id).add({
      ...log.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLog(DiveLog log) async {
    final id = _memberId;
    if (id == null) return;
    await _col(id).doc(log.id).set(log.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteLog(String logId) async {
    final id = _memberId;
    if (id == null) return;
    await _col(id).doc(logId).delete();
  }
}
