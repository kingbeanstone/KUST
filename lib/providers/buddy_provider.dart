import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/buddy_model.dart';

class BuddyProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<BuddyDay> _buddyDays = [];

  List<BuddyDay> get buddyDays => _buddyDays;

  // 💡 다이빙 버디는 원정별 데이터 — expeditions/{id}/buddy_system 을 구독한다.
  String? _expeditionId;
  StreamSubscription? _sub;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('expeditions').doc(_expeditionId!).collection('buddy_system');

  /// ExpeditionProvider(ProxyProvider)가 호출. 원정 전환 시 구독을 갈아탄다.
  void setExpedition(String? expeditionId) {
    if (_expeditionId == expeditionId) return;
    _expeditionId = expeditionId;

    _sub?.cancel();
    _sub = null;
    _buddyDays = [];
    notifyListeners();

    if (expeditionId == null) return;
    _listen();
  }

  void _listen() {
    final expId = _expeditionId;
    _sub = _col.snapshots().listen((snapshot) {
      _buddyDays = snapshot.docs
          .map((doc) => BuddyDay.fromMap(doc.id, doc.data()))
          .toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('버디 스트림 오류: $e — 재연결 예약');
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

  // 특정 일차의 데이터 가져오기 (없으면 빈 편성 — 화면에서 [조 추가]로 시작)
  BuddyDay getDayOrDefault(String dayId, String title) {
    return _buddyDays.firstWhere(
          (d) => d.id == dayId,
      orElse: () => BuddyDay(id: dayId, title: title, teams: [], blocks: [], rounds: []),
    );
  }

  Future<void> saveBuddyDay(BuddyDay day) async {
    if (_expeditionId == null) return;
    await _col.doc(day.id).set(day.toMap());
  }
}
