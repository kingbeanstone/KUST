import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 가이드 섹션 (신입생 교육용 문서 한 덩어리)
class GuideSection {
  final String id;
  final String title;
  final String emoji; // 대분류 카드에 크게 보여줄 이모티콘
  final String content;
  final int order;

  GuideSection({
    required this.id,
    required this.title,
    required this.content,
    required this.order,
    this.emoji = '',
  });

  factory GuideSection.fromMap(String id, Map<String, dynamic> map) =>
      GuideSection(
        id: id,
        title: (map['title'] ?? '').toString(),
        emoji: (map['emoji'] ?? '').toString(),
        content: (map['content'] ?? '').toString(),
        order: (map['order'] as num? ?? 0).toInt(),
      );
}

/// 💡 신입생 가이드 — 동아리 공용 'guides' 컬렉션.
/// 내용은 관리자(훈련부장)가 앱에서 직접 수정한다.
class GuideProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<GuideSection> _sections = [];
  List<GuideSection> get sections => _sections;

  StreamSubscription? _sub;

  GuideProvider() {
    _listen();
  }

  void _listen() {
    _sub = _db.collection('guides').orderBy('order').snapshots().listen(
        (snapshot) {
      _sections = snapshot.docs
          .map((d) => GuideSection.fromMap(d.id, d.data()))
          .toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('가이드 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), _listen);
    });
  }

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    _sub?.cancel();
    _listen();
  }

  Future<void> addSection(String title, String content, String emoji) async {
    final maxOrder =
        _sections.isEmpty ? 0 : _sections.map((s) => s.order).reduce((a, b) => a > b ? a : b);
    await _db.collection('guides').add({
      'title': title.trim(),
      'emoji': emoji.trim(),
      'content': content,
      'order': maxOrder + 1,
    });
  }

  Future<void> updateSection(
      String id, String title, String content, String emoji) async {
    await _db.collection('guides').doc(id).set(
      {'title': title.trim(), 'content': content, 'emoji': emoji.trim()},
      SetOptions(merge: true),
    );
  }

  Future<void> deleteSection(String id) async {
    await _db.collection('guides').doc(id).delete();
  }
}
