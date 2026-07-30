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

      // 💡 기수 오름차순 정렬 (숫자를 뽑아 비교해 "3기" < "12기"가 올바르게),
      //    기수가 같으면 이름순, 기수 없는 대원은 맨 뒤
      int genKey(MemberItem m) {
        final match = RegExp(r'\d+').firstMatch(m.generation);
        return match == null ? 1 << 30 : int.parse(match.group(0)!);
      }

      _members.sort((a, b) {
        final cmp = genKey(a).compareTo(genKey(b));
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });

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
