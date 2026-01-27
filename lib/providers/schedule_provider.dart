import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_model.dart';

class ScheduleProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 일정 날짜 탭 정보 (Firestore의 'config/schedule_tabs' 문서에서 관리하거나 초기값 사용)
  List<Map<String, String>> _dates = [
    {'date': '1.29 (목)', 'title': '1일차 (동방파제)', 'id': '1.29'},
    {'date': '1.30 (금)', 'title': '2일차 (보목)', 'id': '1.30'},
    {'date': '1.31 (토)', 'title': '3일차 (입도)', 'id': '1.31'},
    {'date': '2.1 (일)', 'title': '4일차 (드라이데이)', 'id': '2.1'},
    {'date': '2.2 (월)', 'title': '5일차 (입도)', 'id': '2.2'},
    {'date': '2.3 (화)', 'title': '6일차 (보팅)', 'id': '2.3'},
    {'date': '2.4 (수)', 'title': '7일차 (동기여행)', 'id': '2.4'},
    {'date': '2.5 (목)', 'title': '8일차 (복귀)', 'id': '2.5'},
  ];

  List<Map<String, String>> get dates => _dates;

  List<DailySchedule> _schedules = [];
  List<DailySchedule> get schedules => _schedules;

  ScheduleProvider() {
    _listenToSchedules();
  }

  // Firestore 실시간 리스너
  void _listenToSchedules() {
    _db.collection('schedules').snapshots().listen((snapshot) {
      _schedules = snapshot.docs.map((doc) {
        return DailySchedule.fromFirestore(doc.id, doc.data());
      }).toList();
      notifyListeners();
    });
  }

  // --- 날짜 탭 관리 ---
  void reorderDates(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _dates.removeAt(oldIndex);
    _dates.insert(newIndex, item);
    notifyListeners();
    // 💡 필요 시 Firestore에 탭 순서 저장 로직 추가 가능
  }

  void updateDayInfo(int index, String date, String title) {
    _dates[index]['date'] = date;
    _dates[index]['title'] = title;
    notifyListeners();
  }

  void addDay() {
    _dates.add({
      'date': '0.00 (요일)',
      'title': '신규 일정',
      'id': DateTime.now().millisecondsSinceEpoch.toString()
    });
    notifyListeners();
  }

  void removeDay(int index) {
    _dates.removeAt(index);
    notifyListeners();
  }

  // --- 개별 일정 항목 관리 ---
  Future<void> updateDailySchedule(DailySchedule schedule) async {
    await _db.collection('schedules').doc(schedule.id).set(schedule.toMap());
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