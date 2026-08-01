import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_model.dart';

class ScheduleProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 날짜 탭 기본값 (원정 config에 저장된 게 없을 때 사용)
  static const List<Map<String, String>> _defaultDates = [
    {'date': '1.29 (목)', 'title': '1일차 (동방파제)', 'id': '1.29'},
    {'date': '1.30 (금)', 'title': '2일차 (보목)', 'id': '1.30'},
    {'date': '1.31 (토)', 'title': '3일차 (입도)', 'id': '1.31'},
    {'date': '2.1 (일)', 'title': '4일차 (드라이데이)', 'id': '2.1'},
    {'date': '2.2 (월)', 'title': '5일차 (입도)', 'id': '2.2'},
    {'date': '2.3 (화)', 'title': '6일차 (보팅)', 'id': '2.3'},
    {'date': '2.4 (수)', 'title': '7일차 (동기여행)', 'id': '2.4'},
    {'date': '2.5 (목)', 'title': '8일차 (복귀)', 'id': '2.5'},
  ];

  List<Map<String, String>> _dates =
      _defaultDates.map((d) => Map<String, String>.from(d)).toList();

  List<Map<String, String>> get dates => _dates;

  List<DailySchedule> _schedules = [];
  List<DailySchedule> get schedules => _schedules;

  // 💡 일정은 원정별 데이터 — expeditions/{id}/schedules 를 구독한다.
  String? _expeditionId;
  StreamSubscription? _sub;

  DocumentReference<Map<String, dynamic>> get _expRef =>
      _db.collection('expeditions').doc(_expeditionId!);

  /// ExpeditionProvider(ProxyProvider)가 호출. 원정 전환 시 구독을 갈아탄다.
  void setExpedition(String? expeditionId) {
    if (_expeditionId == expeditionId) return;
    _expeditionId = expeditionId;

    _sub?.cancel();
    _sub = null;
    _schedules = [];
    _dates = _defaultDates.map((d) => Map<String, String>.from(d)).toList();
    notifyListeners();

    if (expeditionId == null) return;
    _listen();
    _loadTabConfig();
  }

  void _listen() {
    final expId = _expeditionId;
    _sub = _expRef.collection('schedules').snapshots().listen((snapshot) {
      _schedules = snapshot.docs.map((doc) {
        return DailySchedule.fromFirestore(doc.id, doc.data());
      }).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('일정 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), () {
        if (_expeditionId == expId && expId != null) _listen();
      });
    });
  }

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    if (_expeditionId == null) return;
    _sub?.cancel();
    _listen();
    _loadTabConfig();
  }

  // --- 날짜 탭 관리 (원정 config에 저장) ---

  Future<void> _loadTabConfig() async {
    try {
      final doc = await _expRef.collection('config').doc('schedule_tabs').get();
      final List<dynamic> saved = doc.data()?['tabs'] ?? [];
      if (saved.isNotEmpty) {
        _dates = saved.map((item) => Map<String, String>.from(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("일정 탭 설정 로드 실패: $e");
    }
  }

  Future<void> saveTabConfig() async {
    if (_expeditionId == null) return;
    try {
      await _expRef.collection('config').doc('schedule_tabs').set({
        'tabs': _dates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      debugPrint("일정 탭 설정 저장 실패: $e");
    }
  }

  void reorderDates(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _dates.removeAt(oldIndex);
    _dates.insert(newIndex, item);
    saveTabConfig();
  }

  void updateDayInfo(int index, String date, String title) {
    _dates[index]['date'] = date;
    _dates[index]['title'] = title;
    saveTabConfig();
  }

  void addDay() {
    _dates.add({
      'date': '0.00 (요일)',
      'title': '신규 일정',
      'id': DateTime.now().millisecondsSinceEpoch.toString()
    });
    saveTabConfig();
  }

  void removeDay(int index) {
    _dates.removeAt(index);
    saveTabConfig();
  }

  // --- 개별 일정 항목 관리 ---
  Future<void> updateDailySchedule(DailySchedule schedule) async {
    if (_expeditionId == null) return;
    await _expRef.collection('schedules').doc(schedule.id).set(schedule.toMap());
  }

  Future<void> saveScheduleItem(String dayId, ScheduleItem item, {int? atIndex}) async {
    final schedule = _schedules.firstWhere(
          (s) => s.id == dayId,
      orElse: () => DailySchedule(id: dayId, items: []),
    );

    if (atIndex != null) {
      schedule.items.insert(atIndex, item);
    } else {
      schedule.items.add(item);
    }
    await updateDailySchedule(schedule);
  }

  Future<void> updateScheduleItem(String dayId, int index, ScheduleItem newItem) async {
    final schedule = _schedules.firstWhere((s) => s.id == dayId);
    schedule.items[index] = newItem;
    await updateDailySchedule(schedule);
  }

  Future<void> deleteScheduleItem(String dayId, int index) async {
    final schedule = _schedules.firstWhere((s) => s.id == dayId);
    schedule.items.removeAt(index);
    await updateDailySchedule(schedule);
  }
}
