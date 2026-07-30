import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 💡 현재 원정의 참가자 목록.
/// expeditions/{expId}/participants/{clubMemberId} — 문서 ID 자체가
/// club_members 문서의 ID다(외래키). 이름 등 정보는 저장하지 않고
/// 화면에서 MemberProvider와 조인해서 보여준다.
class ParticipantProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _expeditionId;
  StreamSubscription? _sub;

  List<String> _ids = []; // order 순 참가자(동아리원) ID 목록
  Set<String> _idSet = {};

  List<String> get participantIds => _ids;
  int get count => _ids.length;
  bool isParticipant(String clubMemberId) => _idSet.contains(clubMemberId);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('expeditions').doc(_expeditionId!).collection('participants');

  /// ExpeditionProvider(ProxyProvider)가 호출. 원정 전환 시 구독을 갈아탄다.
  void setExpedition(String? expeditionId) {
    if (_expeditionId == expeditionId) return;
    _expeditionId = expeditionId;

    _sub?.cancel();
    _sub = null;
    _ids = [];
    _idSet = {};
    notifyListeners();

    if (expeditionId == null) return;
    _sub = _col.orderBy('order').snapshots().listen((snapshot) {
      _ids = snapshot.docs.map((d) => d.id).toList();
      _idSet = _ids.toSet();
      notifyListeners();
    });
  }

  /// 참가 여부 토글: 있으면 빼고, 없으면 맨 뒤 순서로 추가.
  Future<void> toggle(String clubMemberId) async {
    if (_expeditionId == null) return;
    if (_idSet.contains(clubMemberId)) {
      await _col.doc(clubMemberId).delete();
    } else {
      await _col.doc(clubMemberId).set({
        'order': _ids.length,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
