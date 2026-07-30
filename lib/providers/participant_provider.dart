import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';

/// 원정 임원단 직책 6종 (강사처럼 원정별로 달라진다. 강사는 임원이 아니라 별도).
/// key는 저장값, value는 표시명.
const Map<String, String> kStaffRoles = {
  'leader': '대장',
  'planning': '기획부장',
  'training': '훈련부장',
  'equipment': '장비부장',
  'pr': '홍보부장',
  'finance': '총무부장',
};

/// 직책별 이모티콘
const Map<String, String> kStaffRoleEmoji = {
  'leader': '👑',
  'planning': '📋',
  'training': '💪',
  'equipment': '🔧',
  'pr': '📷',
  'finance': '💰',
};

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

  /// 💡 이번 원정의 강사(교육생을 가르치는 역할). 원정별로 달라진다.
  Set<String> _instructorIds = {};

  /// 💡 이번 원정의 직책 (memberId → kStaffRoles의 key). 직책은 1인 1개.
  Map<String, String> _staffRoles = {};

  List<String> get participantIds => _ids;
  int get count => _ids.length;
  bool isParticipant(String clubMemberId) => _idSet.contains(clubMemberId);
  bool isInstructor(String clubMemberId) => _instructorIds.contains(clubMemberId);
  String? staffRoleOf(String clubMemberId) => _staffRoles[clubMemberId];

  /// 칩/픽커에 붙일 역할 이모티콘 (직책 + 강사 겸임 표시)
  String roleEmojiOf(String clubMemberId) {
    final buffer = StringBuffer();
    final role = _staffRoles[clubMemberId];
    if (role != null) buffer.write(kStaffRoleEmoji[role] ?? '');
    return buffer.toString();
  }

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
    _instructorIds = {};
    _staffRoles = {};
    notifyListeners();

    if (expeditionId == null) return;
    _sub = _col.orderBy('order').snapshots().listen((snapshot) {
      _ids = snapshot.docs.map((d) => d.id).toList();
      _idSet = _ids.toSet();
      _instructorIds = snapshot.docs
          .where((d) => d.data()['isInstructor'] == true)
          .map((d) => d.id)
          .toSet();
      _staffRoles = {
        for (final d in snapshot.docs)
          if (kStaffRoles.containsKey(d.data()['staffRole'])) d.id: d.data()['staffRole'] as String
      };
      notifyListeners();
      _reconcileGearRows(); // 💡 참가자인데 장비 행이 없는 사람을 자동 보충
    });
  }

  /// 이번 원정의 강사 지정/해제 (참가자만 가능)
  Future<void> toggleInstructor(String clubMemberId) async {
    if (_expeditionId == null || !_idSet.contains(clubMemberId)) return;
    await _col.doc(clubMemberId).set(
      {'isInstructor': !_instructorIds.contains(clubMemberId)},
      SetOptions(merge: true),
    );
  }

  /// 이번 원정의 직책 지정. 같은 직책을 다시 탭하면 해제, 다른 직책이면 교체.
  Future<void> toggleStaffRole(String clubMemberId, String roleKey) async {
    if (_expeditionId == null || !_idSet.contains(clubMemberId)) return;
    final next = _staffRoles[clubMemberId] == roleKey ? '' : roleKey;
    await _col.doc(clubMemberId).set({'staffRole': next}, SetOptions(merge: true));
  }

  /// 💡 자가 치유: 참가자 명단과 장비 표(members)를 대조해서
  /// 장비 행이 없는 참가자의 행을 만들어준다.
  /// (장비 행 자동 생성 기능이 생기기 전에 등록된 참가자 복구 + 이후 어긋남 방지)
  Future<void> _reconcileGearRows() async {
    final expId = _expeditionId;
    if (expId == null || _ids.isEmpty) return;

    try {
      final membersCol =
          _db.collection('expeditions').doc(expId).collection('members');
      final existing = await membersCol.get();
      final existingIds = existing.docs.map((d) => d.id).toSet();
      final missing = _ids.where((id) => !existingIds.contains(id)).toList();
      if (missing.isEmpty) return;

      final batch = _db.batch();
      var added = 0;
      for (var i = 0; i < missing.length; i++) {
        final clubDoc =
            await _db.collection('club_members').doc(missing[i]).get();
        if (!clubDoc.exists) continue; // 명단에서 지워진 유령 참가자는 건너뜀

        final name = (clubDoc.data()?['name'] ?? '').toString().trim();
        batch.set(membersCol.doc(missing[i]), {
          'id': missing[i],
          '이름': name,
          'order': DateTime.now().millisecondsSinceEpoch + i,
        }, SetOptions(merge: true));
        added++;
      }

      // 진행 중 원정이 바뀌었으면 엉뚱한 원정에 쓰지 않도록 중단
      if (_expeditionId != expId || added == 0) return;
      await batch.commit();
      debugPrint('참가자 장비 행 $added개 자동 보충');
    } catch (e) {
      debugPrint('장비 행 보충 실패: $e');
    }
  }

  /// 참가 여부 토글. 장비 표(members) 행도 함께 생성/삭제해서
  /// 참가자 명단과 장비 표가 항상 같은 사람을 가리키게 한다.
  Future<void> toggle(MemberItem clubMember) async {
    if (_expeditionId == null) return;

    final expRef = _db.collection('expeditions').doc(_expeditionId!);
    final partRef = _col.doc(clubMember.id);
    // 💡 장비 행의 문서 ID = 동아리원 ID (외래키). 이름 타이핑이 필요 없어진다.
    final gearRef = expRef.collection('members').doc(clubMember.id);

    final batch = _db.batch();
    if (_idSet.contains(clubMember.id)) {
      // 참가 취소: 장비 행도 함께 제거 (기록된 장비 번호/체크 포함)
      batch.delete(partRef);
      batch.delete(gearRef);
    } else {
      batch.set(partRef, {
        'order': _ids.length,
        'addedAt': FieldValue.serverTimestamp(),
      });
      // 장비 행 자동 생성 — 표에는 참가 순서대로 뒤에 붙는다.
      // merge라서 같은 ID의 과거 장비 데이터가 남아있으면 보존된다.
      batch.set(gearRef, {
        'id': clubMember.id,
        '이름': clubMember.name,
        'order': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
