import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';

/// 💡 v2: 동아리원 원본 명단 (OB/YB). 원정과 무관하게 유지되며,
/// 원정 참가자는 expeditions/{id}/participants 에서 이 문서의 ID를 참조한다.
class MemberProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<MemberItem> _members = [];

  List<MemberItem> get members => _members;

  MemberProvider() {
    _listenToMembers();
  }

  void _listenToMembers() {
    _db.collection('club_members').snapshots().listen((snapshot) {
      _members = snapshot.docs
          .map((doc) => MemberItem.fromMap(doc.id, doc.data()))
          .toList();

      // 💡 [수정] 기수순이 아닌 저장된 order 필드 기준으로 정렬
      _members.sort((a, b) => a.order.compareTo(b.order));

      notifyListeners();
    });
  }

  Future<void> addMember(MemberItem member) async {
    // 💡 새로운 대원은 기존 명단 가장 뒤의 순서를 가짐
    int nextOrder = _members.isEmpty ? 0 : _members.last.order + 1;
    await _db.collection('club_members').add(member.copyWith(order: nextOrder).toMap());
  }

  Future<void> updateMember(MemberItem member) async {
    await _db.collection('club_members').doc(member.id).update(member.toMap());
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
