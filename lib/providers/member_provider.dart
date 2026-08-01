import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';

/// 💡 v2: 동아리원 원본 명단 (OB/YB). 원정과 무관하게 유지되며,
/// 원정 참가자는 expeditions/{id}/participants 에서 이 문서의 ID를 참조한다.
class MemberProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<MemberItem> _members = [];
  StreamSubscription? _sub;

  /// 💡 항상 정렬된 목록을 돌려준다: 기수 오름차순("3기" < "12기") → 이름순,
  ///    기수 미입력은 맨 뒤. 읽는 시점에 정렬하므로 데이터가 언제 왔든 순서가 보장된다.
  List<MemberItem> get members {
    int genKey(MemberItem m) {
      final match = RegExp(r'\d+').firstMatch(m.generation);
      return match == null ? 1 << 30 : int.parse(match.group(0)!);
    }

    final sorted = List<MemberItem>.from(_members);
    sorted.sort((a, b) {
      final cmp = genKey(a).compareTo(genKey(b));
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });
    return sorted;
  }

  MemberProvider() {
    _listenToMembers();
  }

  void _listenToMembers() {
    _sub = _db.collection('club_members').snapshots().listen((snapshot) {
      _members = snapshot.docs
          .map((doc) => MemberItem.fromMap(doc.id, doc.data()))
          .toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('동아리원 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), _listenToMembers);
    });
  }

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    _sub?.cancel();
    _listenToMembers();
  }

  /// 저장 전 앞뒤 공백 정리 (보이지 않는 공백이 정렬·이름 매칭을 망가뜨린다)
  MemberItem _sanitize(MemberItem m) =>
      m.copyWith(name: m.name.trim(), generation: m.generation.trim());

  Future<void> addMember(MemberItem member) async {
    // 💡 새로운 대원은 기존 명단 가장 뒤의 순서를 가짐
    int nextOrder = _members.isEmpty ? 0 : _members.last.order + 1;
    await _db
        .collection('club_members')
        .add(_sanitize(member).copyWith(order: nextOrder).toMap());
  }

  Future<void> updateMember(MemberItem member) async {
    await _db.collection('club_members').doc(member.id).update(_sanitize(member).toMap());
  }

  Future<void> deleteMember(String id) async {
    await _db.collection('club_members').doc(id).delete();
  }

  /// 💡 v1의 expedition_members(25 동계 명단)를 동아리원 명단으로 복사한다.
  /// 문서 ID를 그대로 유지해 이후 참조가 어긋나지 않게 한다. 원본은 백업으로 남는다.
  Future<int> importFromLegacy() async {
    final snapshot = await _db.collection('expedition_members').get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.set(
        _db.collection('club_members').doc(doc.id),
        doc.data(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    return snapshot.docs.length;
  }
}
