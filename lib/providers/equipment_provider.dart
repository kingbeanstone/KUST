import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/equipment_model.dart';

class EquipmentProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 💡 앱 내 디버그 콘솔용 로그 리스트
  final List<String> _debugLogs = [];
  List<String> get debugLogs => _debugLogs;

  void addLog(String message) {
    final time = DateTime.now().toString().substring(11, 19);
    _debugLogs.insert(0, "[$time] $message");
    notifyListeners();
  }

  // Firebase 서비스 계정 JSON (푸시 알림 발송용)
  final Map<String, dynamic> _serviceAccountJson = {
    "type": "service_account",
    "project_id": "kust-88683",
    "private_key_id": "e2f856b0db39325f4ed80bfb161c4fb59e471bf4",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDJO2MLFPd19xgj\nBHDRNeu4IaGCeP8roWo3jgwG4qG4WgKWMXC4fK7m4n/7czN2s62sEyGoLq88Epio\nxiFFS1R9n26i8tCmsDMGWEV5ecnhHxZk1PLOBhj1N+Dlqaje16J/l6imdzAlWXj0\nWmMnUCy5hckotMmY3DJGVoKmXa1kiWafsbekKM4ZVM3aTeAaiTaUOr+K1uC3jLlh\nAVtlsqUwHhvlF2xje3wR0uLYloFRo8dqbqhcJYOtClSxSsYGvbUULKQerUIec/B6\nf2gi73qQ/pWPAEnABAmaC6JM42BtnH6dF4+71kfJ8LYRwnfWo6yt7S/f2lHd5v0Q\nXs7zcdnzAgMBAAECggEAFTWksUjS8kSKbzprF6nqv9wPlVxibLtVIijfHKSrbe5S\nwnjQjClcF+q8mYihXnv+rJnRnNPa1WaSX4uOeyq+64Sv2Q3lrwP4RM1t+Sk8fXVU\n22jUdKGQ5NuwYRR6P46TyoX2GSGL2gvtozeZps2dASrYMmmnq+xdgithFt7dxTBE\nJj4SEYEz1RxwjePVKbHGgbNU9ydDiMce/I2GA5S/U16/CkTjtisI2lWQxfi5ZUfo\WU9xzXa6VFKCZk64Na7SsPke9uZICBtvG+hsHvEbSJca+wM8PN5Wczbq8GKzBf0x\np/elr9qXRiHLeyh9SUIxIgFLO4Ue+OHbNTRqbQkfbQKBgQD6FMFcZVOUgR3hEcz/\nMGI/PMC6qxKw485z6cGx/EbwzcEg6lbAGyC4rarHEcHCbwAYIv8i71CB9yDLg8xJ\n/2RhVw9Xml2HIH5LTK73Msui7EnOHT+HNTQIof9Qia8BphrtKuIh+jxqZ0bZ7DuN\nxLzTB1CpExGyiyqtqmeDG9xJDQKBgQDN/qd7j1tWOzMQf3qFR6jp6G3IX03JuNmA\nYvnRSSY36PK6twHmvpbNMuMKgTryXPLS8T0wHRzDx48w56EeFQ9zSQu79YFzVqEx\nf5apZ+BO/demqMyg9gJW7i0c4i69hOrte0cG7hUpnKlkelL05rByzH2b1suuIQY+\nbAoZlsfu/wKBgElfJYwSPn9nkniiXF7St0COdo1N++HiNIRVpPqvZbDo7SzXFDSw\nwNzuNxjI4OxG3OQ4AFsjk59N/lU3igx73duhS2MMazxmECfPi9YDFTPr14udkTH+\LhIKVXovqyT0sxm6ZzZI0Mj3HBZ79M0XV78iekvgyGR16EOjp1MULYFRAoGAPO47\KgAgWyRNmW6rleq5Wt7GQkN2ZdmIdEJSdIY3iMgdq/7f0BnFz1Ji98N75R57MMvs\ndmPWE07e2u9Yp+ZA2K/dia43qR8RtOtxbBBut867z+8T//RkgsQWkfmRK7u6JZ6W\nRsV7ewB81lycVxY5UOuNp9/kBVB9YU9huWnxH48CgYAU9fTU5nO2B6SERu0d4Zp+\nGFVe3q0Oc8B1/V7JdVWTTN23Ic1proQleis+SlZeHIMWltgUM7vXG3o58zaSKbcM\nuPAkcUCzi+7zteMlfVMp0jdjCuq8JcKXDWeH0t8Kck/JmDq1zuC9v9GMiC5boMwm\n4UVMhUR8ttnfVfvYW7m+GA==\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-fbsvc@kust-88683.iam.gserviceaccount.com",
    "client_id": "106582988868650414164",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
  };

  final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  bool _isPasswordSaved = false;
  bool get isPasswordSaved => _isPasswordSaved;

  AuthorizationStatus _notificationStatus = AuthorizationStatus.notDetermined;
  AuthorizationStatus get notificationStatus => _notificationStatus;

  // 데이터 리스트
  List<MemberEquipment> _data = [];
  List<NoticeItem> _notices = [];
  List<QnaPost> _qnaPosts = [];
  List<BcdItem> _bcds = [];
  List<RegulatorItem> _regulators = [];
  List<MealPlan> _meals = [];
  List<DailySchedule> _schedules = [];
  List<ExecutiveItem> _executives = [];
  List<GeneralGearItem> _generalGears = [];

  List<MemberEquipment> get data => _data;
  List<NoticeItem> get notices => _notices;
  List<QnaPost> get qnaPosts => _qnaPosts;
  List<BcdItem> get bcds => _bcds;
  List<RegulatorItem> get regulators => _regulators;
  List<MealPlan> get meals => _meals;
  List<DailySchedule> get schedules => _schedules;
  List<ExecutiveItem> get executives => _executives;
  List<GeneralGearItem> get generalGears => _generalGears;

  EquipmentProvider() {
    _initProvider();
  }

  NoticeItem? get homeNotice {
    if (_notices.isEmpty) return null;
    return _notices.firstWhere((n) => n.isPinned, orElse: () => _notices.first);
  }

  Future<void> _initProvider() async {
    addLog("시스템 초기화...");
    await _loadPreferences();
    await checkNotificationStatus();

    // 데이터 리스너 시작
    _listenToMembers();
    _listenToNotices();
    _listenToQna();
    _listenToInventory();
    _listenToMeals();
    _listenToSchedules();
    _listenToExecutives();
    _listenToGeneralGears();
    _subscribeToNotices();
  }
  Future<void> pinNotice(String id) async {
    if (!_isAdmin) return;
    try {
      final batch = _db.batch();

      // 1. 기존에 고정된 모든 공지의 고정 해제
      for (var notice in _notices) {
        if (notice.isPinned) {
          batch.update(_db.collection('notices').doc(notice.id), {'isPinned': false});
        }
      }

      // 2. 선택한 공지만 고정 설정
      batch.update(_db.collection('notices').doc(id), {'isPinned': true});

      await batch.commit();
      addLog("홈 화면 공지 설정 완료");
    } catch (e) {
      addLog("공지 고정 에러: $e");
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isPasswordSaved = prefs.getBool('isPasswordSaved') ?? false;
    notifyListeners();
  }

  Future<void> checkNotificationStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    _notificationStatus = settings.authorizationStatus;
    addLog("알림 상태: $_notificationStatus");
    notifyListeners();
  }

  // --- 알림 설정 및 토큰 저장 ---
  Future<bool> setupNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      addLog("권한 요청 시도...");
      NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      _notificationStatus = settings.authorizationStatus;
      notifyListeners();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        addLog("토큰 획득 중...");
        // 웹/아이폰 PWA 필수 VAPID 키 적용
        String? token = await messaging.getToken(vapidKey: "BMkK18nQuhq3wGivZk_2HfDiQ9ojEW6U9WT3c0F-_6zn-8O0XNFYjdJ1eHopIR65gBQGzhq_0xnzLkxyxjvm9bU");
        if (token != null) {
          await _db.collection('fcm_tokens').doc(token).set({
            'token': token,
            'updatedAt': FieldValue.serverTimestamp(),
            'platform': kIsWeb ? 'web' : 'mobile',
          });
          addLog("DB에 토큰 저장 성공");
          return true;
        }
      } else {
        addLog("알림 권한 거절됨");
      }
    } catch (e) {
      addLog("설정 에러: $e");
    }
    return false;
  }

  // --- 알림 발송 (30명 규모: 모든 토큰에 개별 발송) ---
  Future<void> sendNoticePush(NoticeItem notice) async {
    if (!_isAdmin) return;
    try {
      addLog("알림 발송 준비...");
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(_serviceAccountJson);
      final client = await auth.clientViaServiceAccount(accountCredentials, _scopes);
      final accessCredentials = await auth.obtainAccessCredentialsViaServiceAccount(accountCredentials, _scopes, client);
      final accessToken = accessCredentials.accessToken.data;
      client.close();

      final fcmUrl = 'https://fcm.googleapis.com/v1/projects/${_serviceAccountJson['project_id']}/messages:send';

      // fcm_tokens 컬렉션에서 모든 토큰 가져오기
      final tokenSnapshot = await _db.collection('fcm_tokens').get();
      if (tokenSnapshot.docs.isEmpty) {
        addLog("발송 대상(토큰)이 없습니다.");
        return;
      }

      addLog("${tokenSnapshot.docs.length}명에게 발송 시작...");
      int count = 0;
      for (var doc in tokenSnapshot.docs) {
        final token = doc.data()['token'];
        if (token == null) continue;

        try {
          final response = await http.post(
            Uri.parse(fcmUrl),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
            body: jsonEncode({
              'message': {
                'token': token,
                'notification': {
                  'title': '[KUST 공지] ${notice.title}',
                  'body': notice.content.length > 50 ? '${notice.content.substring(0, 50)}...' : notice.content
                },
                'webpush': { 'notification': { 'icon': '/icons/Icon-192.png', 'click_action': '/' } }
              }
            }),
          );
          if (response.statusCode == 200) count++;
        } catch (e) {
          debugPrint("개별 발송 에러: $e");
        }
      }
      addLog("$count명 발송 완료!");
    } catch (e) {
      addLog("발송 프로세스 실패: $e");
    }
  }

  // --- 관리자 인증 및 설정 ---
  Future<bool> authenticate(String password, {bool remember = false}) async {
    if (password == "779") {
      _isAdmin = true;
      if (remember) {
        _isPasswordSaved = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPasswordSaved', true);
      }
      addLog("관리자 인증 성공");
      notifyListeners();
      return true;
    }
    return false;
  }

  void logoutAdmin() { _isAdmin = false; addLog("관리자 로그아웃"); notifyListeners(); }

  Future<void> clearSavedPassword() async {
    _isPasswordSaved = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isPasswordSaved');
    notifyListeners();
  }

  // --- 실시간 리스너 (서버측 정렬 사용) ---
  void _listenToMembers() {
    _db.collection('members').orderBy('order').snapshots().listen((snapshot) {
      _data = snapshot.docs.map((doc) => MemberEquipment.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  void _listenToNotices() {
    _db.collection('notices').orderBy('timestamp', descending: true).snapshots().listen((snapshot) {
      _notices = snapshot.docs.map((doc) => NoticeItem.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  void _listenToQna() {
    _db.collection('qna').orderBy('timestamp', descending: true).snapshots().listen((snapshot) async {
      List<QnaPost> posts = [];
      for (var doc in snapshot.docs) {
        var replySnapshot = await doc.reference.collection('replies').orderBy('timestamp').get();
        var replies = replySnapshot.docs.map((r) => QnaReply.fromMap(r.id, r.data())).toList();
        posts.add(QnaPost.fromMap(doc.id, doc.data(), replies: replies));
      }
      _qnaPosts = posts;
      notifyListeners();
    });
  }

  void _listenToInventory() {
    _db.collection('bcds').snapshots().listen((snapshot) {
      _bcds = snapshot.docs.map((doc) => BcdItem.fromMap(doc.id, doc.data())).toList();
      _bcds.sort((a, b) => int.tryParse(a.id)?.compareTo(int.tryParse(b.id) ?? 0) ?? a.id.compareTo(b.id));
      notifyListeners();
    });
    _db.collection('regulators').snapshots().listen((snapshot) {
      _regulators = snapshot.docs.map((doc) => RegulatorItem.fromMap(doc.id, doc.data())).toList();
      _regulators.sort((a, b) => int.tryParse(a.id)?.compareTo(int.tryParse(b.id) ?? 0) ?? a.id.compareTo(b.id));
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

  void _listenToExecutives() {
    _db.collection('executives').snapshots().listen((snapshot) {
      _executives = snapshot.docs.map((doc) => ExecutiveItem.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  void _listenToGeneralGears() {
    _db.collection('general_gears').snapshots().listen((snapshot) {
      _generalGears = snapshot.docs.map((doc) => GeneralGearItem.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  Future<void> _subscribeToNotices() async {
    if (kIsWeb) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic('notices');
    } catch (e) {
      debugPrint("토픽 구독 실패 (웹 미지원): $e");
    }
  }

  // --- 데이터 CRUD 조작 ---
  Future<void> updateGeneralGearCount(String gearId, int delta) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('general_gears').doc(gearId);
    final doc = await docRef.get();
    if (doc.exists) {
      int current = doc.data()?['count'] ?? 0;
      await docRef.update({'count': (current + delta) < 0 ? 0 : (current + delta)});
    } else {
      await docRef.set({'count': delta < 0 ? 0 : delta, 'memos': []});
    }
  }

  Future<void> addGeneralGearMemo(String gearId, String memo) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('general_gears').doc(gearId);
    final doc = await docRef.get();
    if (doc.exists) { await docRef.update({'memos': FieldValue.arrayUnion([memo])}); }
    else { await docRef.set({'count': 0, 'memos': [memo]}); }
  }

  Future<void> deleteGeneralGearMemo(String gearId, int index) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('general_gears').doc(gearId);
    final doc = await docRef.get();
    if (doc.exists) {
      List<String> memos = List<String>.from(doc.data()?['memos'] ?? []);
      if (index >= 0 && index < memos.length) { memos.removeAt(index); await docRef.update({'memos': memos}); }
    }
  }

  Future<void> addExecutive(ExecutiveItem item) async { if (!_isAdmin) return; await _db.collection('executives').add(item.toMap()); }
  Future<void> updateExecutive(ExecutiveItem item) async { if (!_isAdmin) return; await _db.collection('executives').doc(item.id).update(item.toMap()); }
  Future<void> deleteExecutive(String id) async { if (!_isAdmin) return; await _db.collection('executives').doc(id).delete(); }

  Future<void> addBcd(String id, String name, String memo) async { await _db.collection('bcds').doc(id).set({'name': name, 'memo': memo}); }
  Future<void> updateBcd(String id, String name, String memo) async { await _db.collection('bcds').doc(id).update({'name': name, 'memo': memo}); }
  Future<void> deleteBcd(String id) async { if (!_isAdmin) return; await _db.collection('bcds').doc(id).delete(); }

  Future<void> addRegulator(String id, String name, String memo) async { await _db.collection('regulators').doc(id).set({'name': name, 'memo': memo}); }
  Future<void> updateRegulator(String id, String name, String memo) async { await _db.collection('regulators').doc(id).update({'name': name, 'memo': memo}); }
  Future<void> deleteRegulator(String id) async { if (!_isAdmin) return; await _db.collection('regulators').doc(id).delete(); }

  Future<void> saveBulkChanges(List<MemberEquipment> updatedList) async {
    if (!_isAdmin) return;
    final batch = _db.batch();
    for (var member in updatedList) { batch.set(_db.collection('members').doc(member.id), member.toMap(), SetOptions(merge: true)); }
    await batch.commit();
    addLog("장비 데이터 일괄 저장");
  }

  Future<void> addRow() async {
    if (!_isAdmin) return;
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    int nextOrder = _data.isEmpty ? 0 : _data.last.order + 1;
    final newRow = MemberEquipment(id: id, name: '', order: nextOrder, gears: {for (var k in ['가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타']) k: GearStatus()});
    await _db.collection('members').doc(id).set(newRow.toMap());
  }

  Future<void> deleteMember(String id) async { if (!_isAdmin) return; await _db.collection('members').doc(id).delete(); }

  Future<void> toggleCheck(String id, String field) async {
    if (!_isAdmin) return;
    final member = _data.firstWhere((m) => m.id == id);
    final bool currentStatus = member.gears[field]?.checked ?? false;
    await _db.collection('members').doc(id).set({field: {'checked': !currentStatus}}, SetOptions(merge: true));
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
    addLog("체크리스트 리셋 완료");
  }

  Future<void> saveMeal(MealPlan meal) async { if (!_isAdmin) return; await _db.collection('meals').doc(meal.id).set(meal.toMap()); }

  Future<void> addScheduleItem(String dateId, ScheduleItem newItem) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('schedules').doc(dateId);
    final doc = await docRef.get();
    if (doc.exists) { await docRef.update({'items': FieldValue.arrayUnion([newItem.toMap()])}); }
    else { await docRef.set({'items': [newItem.toMap()]}); }
  }

  Future<void> updateScheduleItem(String dateId, int index, ScheduleItem updatedItem) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('schedules').doc(dateId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    List items = List.from((doc.data() as Map<String, dynamic>)['items'] as List);
    items[index] = updatedItem.toMap();
    await docRef.update({'items': items});
  }

  Future<void> deleteScheduleItem(String dateId, int index) async {
    if (!_isAdmin) return;
    final docRef = _db.collection('schedules').doc(dateId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    List items = List.from((doc.data() as Map<String, dynamic>)['items'] as List);
    items.removeAt(index);
    await docRef.update({'items': items});
  }

  Future<void> addNotice(String title, String content) async {
    if (!_isAdmin) return;
    await _db.collection('notices').add({'title': title, 'content': content, 'timestamp': DateTime.now().toIso8601String()});
  }

  Future<void> updateNotice(String id, String title, String content) async {
    if (!_isAdmin) return;
    await _db.collection('notices').doc(id).update({'title': title, 'content': content});
  }

  Future<void> deleteNotice(String id) async {
    if (!_isAdmin) return;
    await _db.collection('notices').doc(id).delete();
  }

  Future<void> addQnaPost(String title, String content, String author) async {
    await _db.collection('qna').add({'title': title, 'content': content, 'author': author, 'timestamp': DateTime.now().toIso8601String(), 'lastReplyAt': DateTime.now().toIso8601String()});
  }

  Future<void> addQnaReply(String postId, String content, String author) async {
    await _db.collection('qna').doc(postId).collection('replies').add({'content': content, 'author': author, 'timestamp': DateTime.now().toIso8601String()});
    await _db.collection('qna').doc(postId).update({'lastReplyAt': DateTime.now().toIso8601String()});
  }

  Future<void> deleteQnaPost(String postId) async { if (!_isAdmin) return; await _db.collection('qna').doc(postId).delete(); }
  Future<void> deleteQnaReply(String postId, String replyId) async {
    if (!_isAdmin) return;
    await _db.collection('qna').doc(postId).collection('replies').doc(replyId).delete();
    await _db.collection('qna').doc(postId).update({'lastReplyAt': DateTime.now().toIso8601String()});
  }
}