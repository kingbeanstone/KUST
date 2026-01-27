import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/meal_plan_provider.dart';
// import '../models/equipment_model.dart';
import '../models/meal_plan_model.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  int _selectedDateIndex = 0;
  bool _isEditMode = false;

  final TextEditingController _breakfastController = TextEditingController();
  final TextEditingController _lunchController = TextEditingController();
  final TextEditingController _dinnerController = TextEditingController();
  final TextEditingController _snackController = TextEditingController();

  @override
  void dispose() {
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    _snackController.dispose();
    super.dispose();
  }

  // 💡 선택된 날짜에 맞는 식단 데이터 로드
  void _loadMealData(MealPlanProvider mealProvider) {
    if (mealProvider.dates.isEmpty) return;

    final currentId = mealProvider.dates[_selectedDateIndex]['id']!;
    final meal = mealProvider.meals.firstWhere(
          (m) => m.id == currentId,
      orElse: () => MealPlan(id: currentId),
    );

    _breakfastController.text = meal.breakfast;
    _lunchController.text = meal.lunch;
    _dinnerController.text = meal.dinner;
    _snackController.text = meal.snack;
  }

  @override
  Widget build(BuildContext context) {
    // 관리자 확인을 위한 EquipmentProvider와 데이터 관리를 위한 MealPlanProvider 사용
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final mealProvider = Provider.of<MealPlanProvider>(context);

    if (!_isEditMode) _loadMealData(mealProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🍱 원정 식단표', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (equipmentProvider.isAdmin) ...[
            if (_isEditMode)
              TextButton(
                onPressed: () => setState(() => _isEditMode = false),
                child: const Text('취소', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () async {
                if (_isEditMode) {
                  final updatedMeal = MealPlan(
                    id: mealProvider.dates[_selectedDateIndex]['id']!,
                    breakfast: _breakfastController.text,
                    lunch: _lunchController.text,
                    dinner: _dinnerController.text,
                    snack: _snackController.text,
                  );
                  await mealProvider.saveMeal(updatedMeal);
                  setState(() => _isEditMode = false);
                } else {
                  setState(() => _isEditMode = true);
                }
              },
              child: Text(_isEditMode ? '저장' : '수정',
                  style: TextStyle(color: _isEditMode ? Colors.blue : Colors.black54, fontWeight: FontWeight.bold)),
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          // 💡 상단 날짜 카드 탭 (ScheduleScreen과 동일한 스타일)
          Container(
            height: 90,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: mealProvider.dates.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedDateIndex == index;
                final dayInfo = mealProvider.dates[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDateIndex = index;
                      _isEditMode = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 120,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[800] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.blue[800]! : Colors.grey[200]!,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.blue[800]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayInfo['date']!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white.withOpacity(0.8) : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayInfo['title']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMealCard('🌅 아침', _breakfastController),
                _buildMealCard('☀️ 점심', _lunchController),
                _buildMealCard('🌙 저녁', _dinnerController),
                _buildMealCard('🍕 야식', _snackController),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(String label, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isEditMode
                ? TextField(
              controller: controller,
              maxLines: null,
              style: const TextStyle(fontSize: 15, height: 1.5),
              decoration: const InputDecoration(
                hintText: '식단 내용을 입력하세요...',
                border: InputBorder.none,
                isDense: true,
              ),
            )
                : Text(
              controller.text.isEmpty ? '아직 등록된 식단이 없습니다.' : controller.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: controller.text.isEmpty ? Colors.grey : const Color(0xFF212121),
              ),
            ),
          ),
        ],
      ),
    );
  }
}