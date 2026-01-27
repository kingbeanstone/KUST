import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_plan_model.dart';

class MealPlanProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 💡 관리자 모드에서 수정 가능한 날짜 데이터 구조
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

  List<MealPlan> _meals = [];
  List<MealPlan> get meals => _meals;

  MealPlanProvider() {
    _listenToMeals();
    _loadTabConfig(); // 💡 저장된 날짜 설정 불러오기
  }

  // 💡 파이어베이스에 저장된 날짜 탭 설정 불러오기
  void _loadTabConfig() async {
    try {
      final doc = await _db.collection('config').doc('meal_tabs').get();
      if (doc.exists && doc.data() != null) {
        final List<dynamic> savedTabs = doc.data()!['tabs'] ?? [];
        if (savedTabs.isNotEmpty) {
          _dates = savedTabs.map((item) => Map<String, String>.from(item)).toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("탭 설정 로드 실패: $e");
    }
  }

  // 💡 날짜 탭 설정 저장 (순서/제목/날짜 텍스트 전체 저장)
  Future<void> saveTabConfig() async {
    try {
      await _db.collection('config').doc('meal_tabs').set({
        'tabs': _dates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      debugPrint("탭 설정 저장 실패: $e");
    }
  }

  // 💡 탭 순서 변경 및 저장
  void reorderDates(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _dates.removeAt(oldIndex);
    _dates.insert(newIndex, item);
    saveTabConfig(); // 변경 즉시 서버 저장
  }

  // 💡 개별 탭 텍스트 수정
  void updateDayInfo(int index, String date, String title) {
    _dates[index]['date'] = date;
    _dates[index]['title'] = title;
    saveTabConfig();
  }

  // 💡 탭 추가/삭제
  void addDay() {
    final String newId = DateTime.now().millisecondsSinceEpoch.toString();
    _dates.add({'date': '0.00 (요일)', 'title': '신규 일차', 'id': newId});
    saveTabConfig();
  }

  void removeDay(int index) {
    _dates.removeAt(index);
    saveTabConfig();
  }

  // 실시간 식단 데이터 감시
  void _listenToMeals() {
    _db.collection('meals').snapshots().listen((snapshot) {
      _meals = snapshot.docs.map((doc) => MealPlan.fromFirestore(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  // 식단 저장 로직
  Future<void> saveMeal(MealPlan meal) async {
    try {
      await _db.collection('meals').doc(meal.id).set(meal.toMap());
    } catch (e) {
      debugPrint("식단 저장 에러: $e");
    }
  }
}