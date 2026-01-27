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
  Map<String, MealPlan> _editingMeals = {};

  // 편집 모드 진입
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

    if (mealProvider.dates.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 날짜 데이터를 3개씩 묶어서 리스트로 만듭니다.
    List<List<Map<String, String>>> chunkedDates = [];
    for (var i = 0; i < mealProvider.dates.length; i += 3) {
      chunkedDates.add(
        mealProvider.dates.sublist(i, i + 3 > mealProvider.dates.length ? mealProvider.dates.length : i + 3),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🍱 원정 식단표', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
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
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: chunkedDates.length,
        itemBuilder: (context, index) {
          return _buildMealTableBlock(chunkedDates[index], mealProvider);
        },
      ),
    );
  }

  // 💡 Table 위젯을 사용하여 3일치 블록 생성 (오버플로 해결의 핵심)
  Widget _buildMealTableBlock(List<Map<String, String>> currentChunk, MealPlanProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          // 열 너비 설정: 첫 번째(라벨)는 고정, 나머지는 균등 분할
          columnWidths: {
            0: const FixedColumnWidth(50),
            for (int i = 1; i <= currentChunk.length; i++) i: const FlexColumnWidth(),
          },
          border: TableBorder.all(color: Colors.grey[200]!, width: 1),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // 1. 헤더 행 (구분 + 날짜들)
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F3F5)),
              children: [
                _buildLabelCell('구분', isHeader: true),
                ...currentChunk.map((d) => _buildDateHeaderCell(d['title']!, d['date']!)),
              ],
            ),
            // 2. 식단 행들
            _buildTableRow('아침', 'breakfast', currentChunk, provider),
            _buildTableRow('점심', 'lunch', currentChunk, provider),
            _buildTableRow('저녁', 'dinner', currentChunk, provider),
            _buildTableRow('야식', 'snack', currentChunk, provider),
          ],
        ),
      ),
    );
  }

  // 💡 TableRow 빌더
  TableRow _buildTableRow(String label, String field, List<Map<String, String>> chunk, MealPlanProvider provider) {
    return TableRow(
      children: [
        _buildLabelCell(label),
        ...chunk.map((d) {
          final dayId = d['id']!;
          final meal = _isEditMode
              ? _editingMeals[dayId]!
              : provider.meals.firstWhere((m) => m.id == dayId, orElse: () => MealPlan(id: dayId));

          String value = '';
          if (field == 'breakfast') value = meal.breakfast;
          if (field == 'lunch') value = meal.lunch;
          if (field == 'dinner') value = meal.dinner;
          if (field == 'snack') value = meal.snack;

          return _buildDataCell(dayId, field, value);
        }),
      ],
    );
  }

  // 좌측 라벨 셀
  Widget _buildLabelCell(String text, {bool isHeader = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isHeader ? Colors.black87 : Colors.blueGrey[600],
        ),
      ),
    );
  }

  // 날짜 헤더 셀
  Widget _buildDateHeaderCell(String title, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.blue[50],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 2),
          Text(date, style: const TextStyle(fontSize: 9, color: Colors.black54)),
        ],
      ),
    );
  }

  // 데이터 셀 (입력 및 표시)
  Widget _buildDataCell(String dayId, String field, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      alignment: Alignment.center,
      child: _isEditMode
          ? TextFormField(
        initialValue: value,
        onChanged: (v) => _updateLocalMeal(dayId, field, v),
        maxLines: null,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, height: 1.3),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: '입력',
          hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      )
          : Text(
        value.isEmpty ? '-' : value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
      ),
    );
  }

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