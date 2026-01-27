import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';

class MemberProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<MemberItem> _members = [];

  List<MemberItem> get members => _members;

  MemberProvider() {
    _listenToMembers();
  }

  void _listenToMembers() {
    _db.collection('expedition_members').snapshots().listen((snapshot) {
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
    await _db.collection('expedition_members').add(member.copyWith(order: nextOrder).toMap());
  }

  Future<void> updateMember(MemberItem member) async {
    await _db.collection('expedition_members').doc(member.id).update(member.toMap());
  }

  Future<void> deleteMember(String id) async {
    await _db.collection('expedition_members').doc(id).delete();
  }
}