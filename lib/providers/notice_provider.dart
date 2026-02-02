import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'dart:convert';
import '../models/notice_model.dart';

class NoticeProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<NoticeItem> _notices = [];
  List<NoticeItem> get notices => _notices;

  bool _isAdmin = false;
  AuthorizationStatus _notificationStatus = AuthorizationStatus.notDetermined;
  AuthorizationStatus get notificationStatus => _notificationStatus;

  NoticeItem? get homeNotice {
    if (_notices.isEmpty) return null;
    try {
      return _notices.firstWhere((n) => n.isPinned);
    } catch (e) {
      return _notices.first;
    }
  }

  NoticeProvider() {
    _listenToNotices();
    checkNotificationStatus();
  }

  void setAdminStatus(bool isAdmin) {
    _isAdmin = isAdmin;
    notifyListeners();
  }

  Future<void> checkNotificationStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    _notificationStatus = settings.authorizationStatus;
    notifyListeners();
  }

  Future<bool> setupNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      _notificationStatus = settings.authorizationStatus;
      notifyListeners();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken(vapidKey: "BMkK18nQuhq3wGivZk_2HfDiQ9ojEW6U9WT3c0F-_6zn-8O0XNFYjdJ1eHopIR65gBQGzhq_0xnzLkxyxjvm9bU");
        if (token != null) {
          await _db.collection('fcm_tokens').doc(token).set({
            'token': token,
            'updatedAt': FieldValue.serverTimestamp(),
            'platform': kIsWeb ? 'web' : 'mobile',
          });
          return true;
        }
      }
    } catch (e) { debugPrint("알림 설정 에러: $e"); }
    return false;
  }

  void _listenToNotices() {
    _db.collection('notices').orderBy('timestamp', descending: true).snapshots().listen((snapshot) {
      _notices = snapshot.docs.map((doc) => NoticeItem.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  // 💡 [핵심 수정] 누락된 private_key_id와 client_id를 추가하여 'Invalid argument' 해결
  final Map<String, dynamic> _serviceAccountJson = {
    "type": "service_account",
    "project_id": "kust-88683",
    "private_key_id": "e2f856b0db39325f4ed80bfb161c4fb59e471bf4",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDJO2MLFPd19xgj\nBHDRNeu4IaGCeP8roWo3jgwG4qG4WgKWMXC4fK7m4n/7czN2s62sEyGoLq88Epio\nxiFFS1R9n26i8tCmsDMGWEV5ecnhHxZk1PLOBhj1N+Dlqaje16J/l6imdzAlWXj0\nWmMnUCy5hckotMmY3DJGVoKmXa1kiWafsbekKM4ZVM3aTeAaiTaUOr+K1uC3jLlh\nAVtlsqUwHhvlF2xje3wR0uLYloFRo8dqbqhcJYOtClSxSsYGvbUULKQerUIec/B6\nf2gi73qQ/pWPAEnABAmaC6JM42BtnH6dF4+71kfJ8LYRwnfWo6yt7S/f2lHd5v0Q\nXs7zcdnzAgMBAAECggEAFTWksUjS8kSKbzprF6nqv9wPlVxibLtVIijfHKSrbe5S\nwnjQjClcF+q8mYihXnv+rJnRnNPa1WaSX4uOeyq+64Sv2Q3lrwP4RM1t+Sk8fXVU\n22jUdKGQ5NuwYRR6P46TyoX2GSGL2gvtozeZps2dASrYMmmnq+xdgithFt7dxTBE\nJj4SEYEz1RxwjePVKbHGgbNU9ydDiMce/I2GA5S/U16/CkTjtisI2lWQxfi5ZUfo\WU9xzXa6VFKCZk64Na7SsPke9uZICBtvG+hsHvEbSJca+wM8PN5Wczbq8GKzBf0x\np/elr9qXRiHLeyh9SUIxIgFLO4Ue+OHbNTRqbQkfbQKBgQD6FMFcZVOUgR3hEcz/\nMGI/PMC6qxKw485z6cGx/EbwzcEg6lbAGyC4rarHEcHCbwAYIv8i71CB9yDLg8xJ\n/2RhVw9Xml2HIH5LTK73Msui7EnOHT+HNTQIof9Qia8BphrtKuIh+jxqZ0bZ7DuN\nxLzTB1CpExGyiyqtqmeDG9xJDQKBgQDN/qd7j1tWOzMQf3qFR6jp6G3IX03JuNmA\nYvnRSSY36PK6twHmvpbNMuMKgTryXPLS8T0wHRzDx48w56EeFQ9zSQu79YFzVqEx\nf5apZ+BO/demqMyg9gJW7i0c4i69hOrte0cG7hUpnKlkelL05rByzH2b1suuIQY+\nbAoZlsfu/wKBgElfJYwSPn9nkniiXF7St0COdo1N++HiNIRVpPqvZbDo7SzXFDSw\nwNzuNxjI4OxG3OQ4AFsjk59N/lU3igx73duhS2MMazxmECfPi9YDFTPr14udkTH+\LhIKVXovqyT0sxm6ZzZI0Mj3HBZ79M0XV78iekvgyGR16EOjp1MULYFRAoGAPO47\KgAgWyRNmW6rleq5Wt7GQkN2ZdmIdEJSdIY3iMgdq/7f0BnFz1Ji98N75R57MMvs\ndmPWE07e2u9Yp+ZA2K/dia43qR8RtOtxbBBut867z+8T//RkgsQWkfmRK7u6JZ6W\nRsV7ewB81lycVxY5UOuNp9/kBVB9YU9huWnxH48CgYAU9fTU5nO2B6SERu0d4Zp+\nGFVe3q0Oc8B1/V7JdVWTTN23Ic1proQleis+SlZeHIMWltgUM7vXG3o58zaSKbcM\nuPAkcUCzi+7zteMlfVMp0jdjCuq8JcKXDWeH0t8Kck/JmDq1zuC9v9GMiC5boMwm\n4UVMhUR8ttnfVfvYW7m+GA==\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-fbsvc@kust-88683.iam.gserviceaccount.com",
    "client_id": "115049386374971788755",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40kust-88683.iam.gserviceaccount.com"
  };

  Future<void> sendNoticePush(NoticeItem notice, {Function(String)? logger}) async {
    // 💡 AuthProvider의 상태에 따라 _isAdmin이 주입되어야 합니다.
    if (!_isAdmin) {
      logger?.call("❌ 발송 권한이 없습니다.");
      return;
    }

    try {
      logger?.call("🚀 알림 발송 준비...");

      // 💡 핵심 수정: JSON 복사 후 private_key 내의 이중 이스케이프된 줄바꿈 처리
      final Map<String, dynamic> formattedJson = Map.from(_serviceAccountJson);
      formattedJson['private_key'] = (formattedJson['private_key'] as String).replaceAll('\\n', '\n');

      final accountCredentials = auth.ServiceAccountCredentials.fromJson(formattedJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      final client = await auth.clientViaServiceAccount(accountCredentials, scopes);
      final accessCredentials = await auth.obtainAccessCredentialsViaServiceAccount(accountCredentials, scopes, client);
      final accessToken = accessCredentials.accessToken.data;
      client.close();

      final fcmUrl = 'https://fcm.googleapis.com/v1/projects/${_serviceAccountJson['project_id']}/messages:send';
      final tokenSnapshot = await _db.collection('fcm_tokens').get();

      if (tokenSnapshot.docs.isEmpty) {
        logger?.call("⚠️ 발송 대상 토큰이 없습니다.");
        return;
      }

      int count = 0;
      for (var doc in tokenSnapshot.docs) {
        final token = doc.data()['token'];
        if (token == null) continue;

        final response = await http.post(
          Uri.parse(fcmUrl),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
          body: jsonEncode({
            'message': {
              'token': token,
              'notification': {'title': '[KUST 공지] ${notice.title}', 'body': notice.content},
              'webpush': {'notification': {'icon': '/icons/Icon-192.png', 'click_action': '/'}}
            }
          }),
        );
        if (response.statusCode == 200) count++;
      }
      logger?.call("🏁 $count건 전송 완료");
    } catch (e) {
      logger?.call("🚨 구글 인증 에러: $e");
    }
  }

  // 💡 메서드 이름을 uploadNoticeImages에서 uploadImages로 변경하여 Screen과 일치시킴
  Future<List<String>> uploadImages(List<XFile> images) async {
    List<String> urls = [];
    for (var image in images) {
      try {
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${image.name}";
        Reference ref = _storage.ref().child('notices/$fileName');
        final bytes = await image.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        urls.add(await ref.getDownloadURL());
      } catch (e) { debugPrint("이미지 업로드 에러: $e"); }
    }
    return urls;
  }

  Future<void> addNotice(String title, String content, {List<String> imageUrls = const []}) async {
    await _db.collection('notices').add({
      'title': title, 'content': content, 'timestamp': DateTime.now().toIso8601String(),
      'isPinned': false, 'imageUrls': imageUrls,
    });
  }

  Future<void> updateNotice(String id, String title, String content, {List<String> imageUrls = const []}) async {
    await _db.collection('notices').doc(id).update({'title': title, 'content': content, 'imageUrls': imageUrls});
  }

  Future<void> deleteNotice(String id) async {
    final notice = _notices.firstWhere((n) => n.id == id);
    for (String url in notice.imageUrls) { try { await _storage.refFromURL(url).delete(); } catch (_) {} }
    await _db.collection('notices').doc(id).delete();
  }

  Future<void> pinNotice(String id) async {
    final batch = _db.batch();
    for (var n in _notices) { if (n.isPinned) batch.update(_db.collection('notices').doc(n.id), {'isPinned': false}); }
    batch.update(_db.collection('notices').doc(id), {'isPinned': true});
    await batch.commit();
  }
}