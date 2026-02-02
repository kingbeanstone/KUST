import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/qna_model.dart';

// ✅ 클래스 이름을 QnaProvider로 지정해야 충돌이 나지 않습니다.
class QnaProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<QnaPost> _qnaPosts = [];
  List<QnaPost> get qnaPosts => _qnaPosts;

  bool _isAdmin = false; // 관리자 권한 여부

  QnaProvider() {
    _listenToQna();
  }

  // 관리자 상태 동기화 (EquipmentProvider에서 로그인 시 호출 필요)
  void setAdminStatus(bool isAdmin) {
    _isAdmin = isAdmin;
    notifyListeners();
  }

  // 실시간 데이터 리스너
  void _listenToQna() {
    _db.collection('qna').orderBy('timestamp', descending: true).snapshots().listen((snapshot) async {
      List<QnaPost> posts = [];
      for (var doc in snapshot.docs) {
        // 각 게시글의 댓글 컬렉션 가져오기
        var replySnapshot = await doc.reference.collection('replies').orderBy('timestamp').get();
        var replies = replySnapshot.docs.map((r) => QnaReply.fromMap(r.id, r.data())).toList();

        posts.add(QnaPost.fromMap(doc.id, doc.data(), replies: replies));
      }
      _qnaPosts = posts;
      notifyListeners();
    });
  }

  // 게시글 작성
  Future<void> addQnaPost(String title, String content, String author) async {
    await _db.collection('qna').add({
      'title': title,
      'content': content,
      'author': author,
      'timestamp': DateTime.now().toIso8601String(),
      'lastReplyAt': DateTime.now().toIso8601String()
    });
  }

  // 댓글 작성
  Future<void> addQnaReply(String postId, String content, String author) async {
    await _db.collection('qna').doc(postId).collection('replies').add({
      'content': content,
      'author': author,
      'timestamp': DateTime.now().toIso8601String()
    });
    // 댓글 달리면 게시글의 '최근 활동 시간' 업데이트 (정렬용)
    await _db.collection('qna').doc(postId).update({
      'lastReplyAt': DateTime.now().toIso8601String()
    });
  }

  // 게시글 삭제 (관리자용)
  Future<void> deleteQnaPost(String postId) async {
    if (!_isAdmin) return;
    await _db.collection('qna').doc(postId).delete();
  }

  // 댓글 삭제 (관리자용)
  Future<void> deleteQnaReply(String postId, String replyId) async {
    if (!_isAdmin) return;
    await _db.collection('qna').doc(postId).collection('replies').doc(replyId).delete();

    // 댓글 삭제 후에도 갱신 날짜 업데이트 (선택 사항)
    await _db.collection('qna').doc(postId).update({
      'lastReplyAt': DateTime.now().toIso8601String()
    });
  }
}