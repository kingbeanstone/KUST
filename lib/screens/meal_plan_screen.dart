import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  final List<Map<String, String>> _dates = [
    {'label': '목 1.29', 'id': '1.29'},
    {'label': '금 1.30', 'id': '1.30'},
    {'label': '토 1.31', 'id': '1.31'},
    {'label': '일 2.1', 'id': '2.1'},
    {'label': '월 2.2', 'id': '2.2'},
    {'label': '화 2.3', 'id': '2.3'},
    {'label': '수 2.4', 'id': '2.4'},
    {'label': '목 2.5', 'id': '2.5'},
  ];

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

  void _loadMealData(EquipmentProvider provider) {
    final currentId = _dates[_selectedDateIndex]['id']!;
    final meal = provider.meals.firstWhere(
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
    final provider = Provider.of<EquipmentProvider>(context);
    if (!_isEditMode) _loadMealData(provider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🍱 원정 식단표', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          // 💡 관리자 인증이 된 경우에만 수정 버튼 노출
          if (provider.isAdmin) ...[
            if (_isEditMode)
              TextButton(
                onPressed: () => setState(() => _isEditMode = false),
                child: const Text('취소', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () async {
                if (_isEditMode) {
                  final updatedMeal = MealPlan(
                    id: _dates[_selectedDateIndex]['id']!,
                    breakfast: _breakfastController.text,
                    lunch: _lunchController.text,
                    dinner: _dinnerController.text,
                    snack: _snackController.text,
                  );
                  await provider.saveMeal(updatedMeal);
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
          Container(
            height: 60,
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: List.generate(_dates.length, (index) {
                  bool isSelected = _selectedDateIndex == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_dates[index]['label']!),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() {
                          _selectedDateIndex = index;
                          _isEditMode = false;
                        });
                      },
                      selectedColor: Colors.blue[700],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      showCheckmark: false,
                    ),
                  );
                }),
              ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isEditMode
                ? TextField(
              controller: controller,
              maxLines: null,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: '메뉴를 입력하세요',
                border: InputBorder.none,
                isDense: true,
              ),
            )
                : Text(
              controller.text.isEmpty ? '등록된 식단이 없습니다.' : controller.text,
              style: TextStyle(
                fontSize: 15,
                color: controller.text.isEmpty ? Colors.grey : const Color(0xFF212121),
              ),
            ),
          ),
        ],
      ),
    );
  }
}