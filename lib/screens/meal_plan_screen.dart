import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/recipe_provider.dart';
import '../models/meal_plan_model.dart';
import '../models/recipe_model.dart';
import 'recipe_book_screen.dart';
import 'ingredient_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  bool _isEditMode = false;
  Map<String, MealPlan> _editingMeals = {};

  /// 레시피 원클릭 삽입 시 입력칸을 다시 그리기 위한 논스
  int _insertNonce = 0;

  static const Map<String, String> _fieldLabels = {
    'breakfast': '아침',
    'lunch': '점심',
    'dinner': '저녁',
    'snack': '야식',
  };

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
          IconButton(
            icon: const Icon(Icons.menu_book_outlined, color: Colors.blueGrey),
            tooltip: '레시피북',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecipeBookScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_basket_outlined, color: Colors.blueGrey),
            tooltip: '남은 재료',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const IngredientScreen())),
          ),
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
    if (_isEditMode) {
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              // 💡 레시피 삽입 시 논스가 바뀌며 새 값으로 다시 그려진다
              key: ValueKey('$dayId|$field|$_insertNonce'),
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
            ),
            // 💡 원클릭 레시피 삽입 버튼
            InkWell(
              onTap: () => _showRecipePicker(dayId, field),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 11, color: Colors.blue[300]),
                    const SizedBox(width: 3),
                    Text('레시피',
                        style: TextStyle(fontSize: 9.5, color: Colors.blue[300])),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 보기 모드: 탭하면 전체 내용 + 등장하는 요리의 레시피를 보여준다
    return InkWell(
      onTap: value.isEmpty ? null : () => _showMealDetail(dayId, field, value),
      child: Container(
        padding: const EdgeInsets.all(10),
        alignment: Alignment.center,
        child: Text(
          value.isEmpty ? '-' : value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
        ),
      ),
    );
  }

  /// 💡 레시피 선택 시트: 탭 한 번으로 식단 칸에 요리 이름을 추가한다.
  void _showRecipePicker(String dayId, String field) {
    final recipes = context.read<RecipeProvider>().recipes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text('${_fieldLabels[field]}에 레시피 넣기',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RecipeBookScreen()));
                    },
                    child: const Text('레시피북 관리',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              if (recipes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('레시피가 없습니다. [레시피북 관리]에서 먼저 추가하세요.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recipes.map((recipe) {
                        return GestureDetector(
                          onTap: () {
                            _appendRecipe(dayId, field, recipe.name);
                            Navigator.pop(sheetContext);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Text(recipe.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _appendRecipe(String dayId, String field, String name) {
    final current = _editingMeals[dayId]!;
    String value = '';
    if (field == 'breakfast') value = current.breakfast;
    if (field == 'lunch') value = current.lunch;
    if (field == 'dinner') value = current.dinner;
    if (field == 'snack') value = current.snack;

    final appended = value.trim().isEmpty ? name : '$value\n$name';
    _updateLocalMeal(dayId, field, appended);
    setState(() => _insertNonce++); // 입력칸을 새 값으로 다시 그린다
  }

  /// 보기 모드: 식단 내용 + 그 칸에 등장하는 요리의 레시피 상세
  void _showMealDetail(String dayId, String field, String value) {
    final matches = context.read<RecipeProvider>().matchesIn(value);
    final dayLabel = context
        .read<MealPlanProvider>()
        .dates
        .firstWhere((d) => d['id'] == dayId, orElse: () => {'title': ''})['title'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('$dayLabel · ${_fieldLabels[field]}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 13.5, height: 1.5)),
              if (matches.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(color: Colors.grey[200], height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 10),
                    children: [
                      for (final recipe in matches) _recipeCard(recipe),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _recipeCard(Recipe recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 5),
              Text(recipe.name,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.bold)),
            ],
          ),
          if (recipe.ingredients.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('재료',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[400])),
            const SizedBox(height: 2),
            Text(recipe.ingredients.trim(),
                style: const TextStyle(fontSize: 12.5, height: 1.5)),
          ],
          if (recipe.steps.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('조리법',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[400])),
            const SizedBox(height: 2),
            Text(recipe.steps.trim(),
                style: const TextStyle(fontSize: 12.5, height: 1.5)),
          ],
        ],
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