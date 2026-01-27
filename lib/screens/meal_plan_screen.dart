import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../models/meal_plan_model.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  bool _isEditMode = false;
  // 모든 날짜의 데이터를 한 번에 관리하기 위한 맵 (날짜 ID : 식단 객체)
  Map<String, MealPlan> _editingMeals = {};

  // 표 설정을 위한 상수들
  static const double labelColumnWidth = 70.0; // 좌측 라벨 열 너비
  static const double dateColumnWidth = 140.0; // 각 날짜 열 너비
  static const double cellHeight = 100.0;      // 각 칸의 높이
  static const double headerHeight = 60.0;     // 헤더 높이

  // 편집 모드 진입 시 현재 데이터 복사
  void _enterEditMode(MealPlanProvider provider) {
    setState(() {
      _isEditMode = true;
      _editingMeals = {
        for (var date in provider.dates)
          date['id']!: provider.meals.firstWhere(
                (m) => m.id == date['id'],
            orElse: () => MealPlan(id: date['id']!),
          )
      };
    });
  }

  // 편집 내용 저장
  Future<void> _saveAllMeals(MealPlanProvider provider) async {
    for (var meal in _editingMeals.values) {
      await provider.saveMeal(meal);
    }
    setState(() => _isEditMode = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 식단이 저장되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final mealProvider = Provider.of<MealPlanProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('🍱 원정 식단표 (전체)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (equipmentProvider.isAdmin)
            TextButton(
              onPressed: () => _isEditMode ? _saveAllMeals(mealProvider) : _enterEditMode(mealProvider),
              child: Text(
                _isEditMode ? '전체 저장' : '편집',
                style: TextStyle(
                  color: _isEditMode ? Colors.blue[700] : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => setState(() => _isEditMode = false),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 좌측 고정 라벨 열 (아침, 점심, 저녁, 야식)
                    _buildFixedLabelColumn(),

                    // 2. 우측 가로 스크롤 데이터 영역 (날짜별 열들)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(mealProvider.dates.length, (index) {
                            final dayInfo = mealProvider.dates[index];
                            final String dayId = dayInfo['id']!;

                            final meal = _isEditMode
                                ? _editingMeals[dayId]!
                                : mealProvider.meals.firstWhere(
                                  (m) => m.id == dayId,
                              orElse: () => MealPlan(id: dayId),
                            );

                            return _buildDateDataColumn(dayInfo, meal);
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 좌측 고정 항목 열 생성
  Widget _buildFixedLabelColumn() {
    return Container(
      width: labelColumnWidth,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        children: [
          _buildCell('일차', headerHeight, isHeader: true),
          _buildCell('아침', cellHeight),
          _buildCell('점심', cellHeight),
          _buildCell('저녁', cellHeight),
          _buildCell('야식', cellHeight),
        ],
      ),
    );
  }

  // 날짜별 데이터 열 생성
  Widget _buildDateDataColumn(Map<String, String> dayInfo, MealPlan meal) {
    return Container(
      width: dateColumnWidth,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        children: [
          // 열 헤더 (날짜 정보)
          Container(
            height: headerHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayInfo['title']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                Text(dayInfo['date']!, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
          // 데이터 셀들
          _buildEditableCell(meal.id, 'breakfast', meal.breakfast),
          _buildEditableCell(meal.id, 'lunch', meal.lunch),
          _buildEditableCell(meal.id, 'dinner', meal.dinner),
          _buildEditableCell(meal.id, 'snack', meal.snack),
        ],
      ),
    );
  }

  // 일반 텍스트 셀 (라벨용)
  Widget _buildCell(String text, double height, {bool isHeader = false}) {
    return Container(
      height: height,
      width: labelColumnWidth,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 12 : 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
          color: isHeader ? Colors.black87 : Colors.blueGrey[700],
        ),
      ),
    );
  }

  // 입력 가능한 데이터 셀
  Widget _buildEditableCell(String mealId, String field, String value) {
    return Container(
      height: cellHeight,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: _isEditMode
          ? TextFormField(
        initialValue: value,
        onChanged: (v) => _updateLocalMeal(mealId, field, v),
        maxLines: null,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '입력...',
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      )
          : Center(
        child: Text(
          value.isEmpty ? '-' : value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: value.isEmpty ? Colors.grey[400] : Colors.black87,
          ),
        ),
      ),
    );
  }

  // 편집 중 데이터 로컬 업데이트
  void _updateLocalMeal(String id, String field, String value) {
    final current = _editingMeals[id]!;
    _editingMeals[id] = MealPlan(
      id: id,
      breakfast: field == 'breakfast' ? value : current.breakfast,
      lunch: field == 'lunch' ? value : current.lunch,
      dinner: field == 'dinner' ? value : current.dinner,
      snack: field == 'snack' ? value : current.snack,
    );
  }
}