import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/equipment_model.dart';

class EquipmentProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 💡 [필독] Firebase 콘솔 -> 프로젝트 설정 -> 서비스 계정에서 생성한 JSON 내용
  final Map<String, dynamic> _serviceAccountJson = {
    "type": "service_account",
    "project_id": "kust-88683",
    "private_key_id": "e2f856b0db39325f4ed80bfb161c4fb59e471bf4",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDJO2MLFPd19xgj\nBHDRNeu4IaGCeP8roWo3jgwG4qG4WgKWMXC4fK7m4n/7czN2s62sEyGoLq88Epio\nxiFFS1R9n26i8tCmsDMGWEV5ecnhHxZk1PLOBhj1N+Dlqaje16J/l6imdzAlWXj0\nWmMnUCy5hckotMmY3DJGVoKmXa1kiWafsbekKM4ZVM3aTeAaiTaUOr+K1uC3jLlh\nAVtlsqUwHhvlF2xje3wR0uLYloFRo8dqbqhcJYOtClSxSsYGvbUULKQerUIec/B6\nf2gi73qQ/pWPAEnABAmaC6JM42BtnH6dF4+71kfJ8LYRwnfWo6yt7S/f2lHd5v0Q\nXs7zcdnzAgMBAAECggEAFTWksUjS8kSKbzprF6nqv9wPlVxibLtVIijfHKSrbe5S\nwnjQjClcF+q8mYihXnv+rJnRnNPa1WaSX4uOeyq+64Sv2Q3lrwP4RM1t+Sk8fXVU\n22jUdKGQ5NuwYRR6P46TyoX2GSGL2gvtozeZps2dASrYMmmnq+xdgithFt7dxTBE\nJj4SEYEz1RxwjePVKbHGgbNU9ydDiMce/I2GA5S/U16/CkTjtisI2lWQxfi5ZUfo\WU9xzXa6VFKCZk64Na7SsPke9uZICBtvG+hsHvEbSJca+wM8PN5Wczbq8GKzBf0x\np/elr9qXRiHLeyh9SUIxIgFLO4Ue+OHbNTRqbQkfbQKBgQD6FMFcZVOUgR3hEcz/\nMGI/PMC6qxKw485z6cGx/EbwzcEg6lbAGyC4rarHEcHCbwAYIv8i71CB9yDLg8xJ\n/2RhVw9Xml2HIH5LTK73Msui7EnOHT+HNTQIof9Qia8BphrtKuIh+jxqZ0bZ7DuN\nxLzTB1CpExGyiyqtqmeDG9xJDQKBgQDN/qd7j1tWOzMQf3qFR6jp6G3IX03JuNmA\nYvnRSSY36PK6twHmvpbNMuMKgTryXPLS8T0wHRzDx48w56EeFQ9zSQu79YFzVqEx\nf5apZ+BO/demqMyg9gJW7i0c4i69hOrte0cG7hUpnKlkelL05rByzH2b1suuIQY+\nbAoZlsfu/wKBgElfJYwSPn9nkniiXF7St0COdo1N++HiNIRVpPqvZbDo7SzXFDSw\nwNzuNxjI4OxG3OQ4AFsjk59N/lU3igx73duhS2MMazxmECfPi9YDFTPr14udkTH+\LhIKVXovqyT0sxm6ZzZI0Mj3HBZ79M0XV78iekvgyGR16EOjp1MULYFRAoGAPO47\KgAgWyRNmW6rleq5Wt7GQkN2ZdmIdEJSdIY3iMgdq/7f0BnFz1Ji98N75R57MMvs\ndmPWE07e2u9Yp+ZA2K/dia43qR8RtOtxbBBut867z+8T//RkgsQWkfmRK7u6JZ6W\nRsV7ewB81lycVxY5UOuNp9/kBVB9YU9huWnxH48CgYAU9fTU5nO2B6SERu0d4Zp+\nGFVe3q0Oc8B1/V7JdVWTTN23Ic1proQleis+SlZeHIMWltgUM7vXG3o58zaSKbcM\nuPAkcUCzi+7zteMlfVMp0jdjCuq8JcKXDWeH0t8Kck/JmDq1zuC9v9GMiC5boMwm\n4UVMhUR8ttnfVfvYW7m+GA==\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-fbsvc@kust-88683.iam.gserviceaccount.com",
    "client_id": "106582988868650414164",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40kust-88683.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  };

  final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  bool _isPasswordSaved = false;
  bool get isPasswordSaved => _isPasswordSaved;

  List<MemberEquipment> _data = [];
  List<MemberEquipment> get data => _data;

  List<MealPlan> _meals = [];
  List<MealPlan> get meals => _meals;

  List<DailySchedule> _schedules = [];
  List<DailySchedule> get schedules => _schedules;

  List<NoticeItem> _notices = [];
  List<NoticeItem> get notices => _notices;

  List<QnaPost> _qnaPosts = [];
  List<QnaPost> get qnaPosts => _qnaPosts;

  EquipmentProvider() {
    _initProvider();
  }

  // 💡 초기화 시 로컬 저장소에서 설정 불러오기 및 리스너 등록
  Future<void> _initProvider() async {
    await _loadPreferences();
    _listenToMembers();
    _listenToMeals();
    _listenToSchedules();
    _listenToNotices();
    _listenToQna();
    _subscribeToNotices();
  }

  // --- 설정 로드/저장 로직 (SharedPreferences) ---

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isPasswordSaved = prefs.getBool('isPasswordSaved') ?? false;
    notifyListeners();
  }

  // --- 관리자 인증 및 세션 로직 ---

  Future<bool> authenticate(String password, {bool remember = false}) async {
    if (password == "779") {
      _isAdmin = true;
      if (remember) {
        _isPasswordSaved = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPasswordSaved', true);
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  void logoutAdmin() {
    _isAdmin = false;
    notifyListeners();
  }

  Future<void> clearSavedPassword() async {
    _isPasswordSaved = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isPasswordSaved');
    notifyListeners();
  }

  // --- QnA 관련 로직 (게시글 및 댓글 관리) ---

  void _listenToQna() {
    _db.collection('qna').snapshots().listen((snapshot) async {
      List<QnaPost> posts = [];
      for (var doc in snapshot.docs) {
        var replySnapshot = await doc.reference.collection('replies').orderBy('timestamp').get();
        var replies = replySnapshot.docs.map((r) => QnaReply.fromMap(r.id, r.data())).toList();
        posts.add(QnaPost.fromMap(doc.id, doc.data(), replies: replies));
      }
      _qnaPosts = posts;
      _qnaPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    });
  }

  Future<void> addQnaPost(String title, String content, String author) async {
    await _db.collection('qna').add({
      'title': title,
      'content': content,
      'author': author,
      'timestamp': DateTime.now().toIso8601String(),
      'lastReplyAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> addQnaReply(String postId, String content, String author) async {
    await _db.collection('qna').doc(postId).collection('replies').add({
      'content': content,
      'author': author,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _db.collection('qna').doc(postId).update({
      'lastReplyAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteQnaPost(String postId) async {
    if (!_isAdmin) return;
    await _db.collection('qna').doc(postId).delete();
  }

  Future<void> deleteQnaReply(String postId, String replyId) async {
    if (!_isAdmin) return;
    await _db.collection('qna').doc(postId).collection('replies').doc(replyId).delete();

    await _db.collection('qna').doc(postId).update({
      'lastReplyAt': DateTime.now().toIso8601String(),
    });
  }

  // --- 푸시 알림 로직 (HTTP v1) ---

  Future<String> _getAccessToken() async {
    final accountCredentials = auth.ServiceAccountCredentials.fromJson(_serviceAccountJson);
    final client = await auth.clientViaServiceAccount(accountCredentials, _scopes);
    final accessCredentials = await auth.obtainAccessCredentialsViaServiceAccount(
      accountCredentials,
      _scopes,
      client,
    );
    client.close();
    return accessCredentials.accessToken.data;
  }

  Future<void> sendNoticePush(NoticeItem notice) async {
    if (!_isAdmin) return;
    try {
      final String accessToken = await _getAccessToken();
      final String projectId = _serviceAccountJson['project_id'];
      final String url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'topic': 'notices',
            'notification': {
              'title': '[KUST 공지] ${notice.title}',
              'body': notice.content.length > 50
                  ? '${notice.content.substring(0, 50)}...'
                  : notice.content,
            },
            'android': { 'priority': 'high', 'notification': { 'sound': 'default' } },
            'apns': { 'payload': { 'aps': { 'sound': 'default' } } },
            'data': { 'noticeId': notice.id },
          }
        }),
      );
    } catch (e) {
      debugPrint("알림 전송 에러: $e");
    }
  }

  // --- Firestore 리스너 ---

  void _listenToMembers() {
    _db.collection('members').snapshots().listen((snapshot) {
      _data = snapshot.docs.map((doc) => MemberEquipment.fromMap(doc.id, doc.data())).toList();
      _data.sort((a, b) => a.order.compareTo(b.order));
      notifyListeners();
    });
  }

  void _listenToMeals() {
    _db.collection('meals').snapshots().listen((snapshot) {
      _meals = snapshot.docs.map((doc) => MealPlan.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  void _listenToSchedules() {
    _db.collection('schedules').snapshots().listen((snapshot) {
      _schedules = snapshot.docs.map((doc) => DailySchedule.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  void _listenToNotices() {
    _db.collection('notices').snapshots().listen((snapshot) {
      _notices = snapshot.docs.map((doc) => NoticeItem.fromMap(doc.id, doc.data())).toList();
      _notices.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    });
  }

  Future<void> _subscribeToNotices() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('notices');
    } catch (e) {
      debugPrint("토픽 구독 에러: $e");
    }
  }

  // --- 데이터 CRUD 메서드 ---

  Future<void> addNotice(String title, String content) async {
    if (!_isAdmin) return;
    await _db.collection('notices').add({
      'title': title, 'content': content, 'timestamp': DateTime.now().toIso8601String()
    });
  }

  Future<void> updateNotice(String id, String title, String content) async {
    if (!_isAdmin) return;
    await _db.collection('notices').doc(id).update({'title': title, 'content': content});
  }

  Future<void> deleteNotice(String id) async {
    if (!_isAdmin) return;
    await _db.collection('notices').doc(id).delete();
  }

  Future<void> saveBulkChanges(List<MemberEquipment> updatedList) async {
    if (!_isAdmin) return;
    final batch = _db.batch();
    for (var member in updatedList) {
      batch.set(_db.collection('members').doc(member.id), member.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> toggleCheck(String id, String field) async {
    if (!_isAdmin) return;
    final member = _data.firstWhere((m) => m.id == id);
    final bool currentStatus = member.gears[field]?.checked ?? false;
    await _db.collection('members').doc(id).set({ field: { 'checked': !currentStatus } }, SetOptions(merge: true));
  }

  Future<void> deleteMember(String id) async {
    if (!_isAdmin) return;
    await _db.collection('members').doc(id).delete();
  }

  Future<void> addRow() async {
    if (!_isAdmin) return;
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    int nextOrder = _data.isEmpty ? 0 : _data.last.order + 1;
    final newRow = MemberEquipment(
      id: id, name: '', order: nextOrder,
      gears: { for (var k in ['가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타']) k: GearStatus() },
    );
    await _db.collection('members').doc(id).set(newRow.toMap());
  }

  Future<void> resetAllChecks() async {
    if (!_isAdmin) return;
    final batch = _db.batch();
    for (var member in _data) {
      Map<String, dynamic> resetGears = {};
      member.gears.forEach((key, gear) { resetGears[key] = {'value': gear.value, 'checked': false}; });
      batch.set(_db.collection('members').doc(member.id), resetGears, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> saveMeal(MealPlan meal) async {
    if (!_isAdmin) return;
    await _db.collection('meals').doc(meal.id).set(meal.toMap());
  }

  Future<void> addScheduleItem(String dateId, ScheduleItem newItem) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('schedules').doc(dateId);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({'items': FieldValue.arrayUnion([newItem.toMap()])});
    } else {
      await docRef.set({'items': [newItem.toMap()]});
    }
  }

  Future<void> updateScheduleItem(String dateId, int index, ScheduleItem updatedItem) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('schedules').doc(dateId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    List items = List.from(doc.data()?['items'] as List);
    items[index] = updatedItem.toMap();
    await docRef.update({'items': items});
  }

  Future<void> deleteScheduleItem(String dateId, int index) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('schedules').doc(dateId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    List items = List.from(doc.data()?['items'] as List);
    items.removeAt(index);
    await docRef.update({'items': items});
  }
}