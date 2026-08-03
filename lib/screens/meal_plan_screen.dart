import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe_model.dart';

/// 💡 v3 식단표: 표 자체가 편집 화면이다.
///  - 각 칸의 메뉴 = 버튼(칩). 탭 = 레시피 보기/수정
///  - 관리자: 길게 눌러 드래그 → 다른 칸/보관함으로 이동, 칸의 [+]로 추가
///  - 편집 모드/전체 저장 없음 — 모두 즉시 저장 · 실시간 동기화
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  static const List<List<String>> _slots = [
    ['breakfast', '아침'],
    ['lunch', '점심'],
    ['dinner', '저녁'],
    ['snack', '야식'],
  ];
  static const String _storage = '보관함';

  /// 편집 모드 (관리자 전용) — 평상시엔 관리자도 보기 모드
  bool _isEditing = false;

  /// 편집 시작 시점 스냅샷 — [수정 취소] 시 이 상태로 복원
  List<Recipe>? _editSnapshot;

  /// 다이얼로그 입력 컨트롤러 — State 소유 (dispose 크래시 방지)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  /// 일차 탭 index → 카테고리 이름 ('1일차'…)
  String _dayCat(int index) => '${index + 1}일차';

  List<Recipe> _recipesAt(RecipeProvider provider, String cat, String slot) {
    final list = provider.recipes
        .where((r) => r.category == cat && r.slot == slot)
        .toList()
      ..sort((a, b) {
        final d = a.order.compareTo(b.order);
        return d != 0 ? d : a.name.compareTo(b.name);
      });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final edit = isAdmin && _isEditing;
    final mealProvider = Provider.of<MealPlanProvider>(context);
    final recipeProvider = context.watch<RecipeProvider>();

    if (mealProvider.dates.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 날짜를 3개씩 묶어 블록으로
    final chunks = <List<int>>[];
    for (var i = 0; i < mealProvider.dates.length; i += 3) {
      chunks.add([
        for (var j = i;
            j < (i + 3 > mealProvider.dates.length
                ? mealProvider.dates.length
                : i + 3);
            j++)
          j
      ]);
    }

    final storageItems = recipeProvider.recipes
        .where((r) => r.category == _storage)
        .toList()
      ..sort((a, b) {
        final d = a.order.compareTo(b.order);
        return d != 0 ? d : a.name.compareTo(b.name);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🍱 원정 식단표',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          if (isAdmin && _isEditing)
            TextButton(
              onPressed: () {
                final snapshot = _editSnapshot;
                if (snapshot != null) {
                  recipeProvider.restoreRecipesSnapshot(snapshot);
                }
                setState(() => _isEditing = false);
              },
              child: const Text('수정 취소',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          if (isAdmin)
            TextButton(
              onPressed: () => setState(() {
                if (!_isEditing) {
                  // 편집 시작 — 취소 대비 스냅샷
                  _editSnapshot = List.of(recipeProvider.recipes);
                }
                _isEditing = !_isEditing;
              }),
              child: Text(
                _isEditing ? '완료' : '편집',
                style: TextStyle(
                  color: _isEditing ? Colors.blue[700] : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (edit)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Text('메뉴 드래그 드롭 가능',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700])),
            ),
          for (final chunk in chunks)
            _buildTableBlock(chunk, mealProvider, recipeProvider, edit),

          // ── 보관함 (임시 보관 · 드롭 가능) — 편집 모드에서만
          if (edit)
          DragTarget<Recipe>(
            onWillAcceptWithDetails: (d) =>
                edit && d.data.category != _storage,
            onAcceptWithDetails: (d) =>
                recipeProvider.moveRecipe(d.data, _storage, ''),
            builder: (context, candidates, rejected) => Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: candidates.isNotEmpty ? Colors.blue[50] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: candidates.isNotEmpty
                      ? Colors.blue[400]!
                      : Colors.grey[200]!,
                  width: candidates.isNotEmpty ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📦 보관함',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('식단에서 뺀 메뉴를 잠시 두는 곳',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showAddDialog(
                            recipeProvider, _storage, '', '보관함'),
                        child: Icon(Icons.add_circle_outline,
                            size: 19, color: Colors.blue[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  storageItems.isEmpty
                      ? Text('비어 있음',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey[400]))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final r in storageItems)
                              SizedBox(
                                width: 100,
                                child:
                                    _menuChip(r, edit, recipeProvider, 100),
                              ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- 표 블록

  Widget _buildTableBlock(List<int> dayIndexes, MealPlanProvider mealProvider,
      RecipeProvider recipeProvider, bool edit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: {
            0: const FixedColumnWidth(46),
            for (int i = 1; i <= dayIndexes.length; i++)
              i: const FlexColumnWidth(),
          },
          border: TableBorder.all(color: Colors.grey[200]!, width: 1),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // 헤더: 구분 + 일차들
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F3F5)),
              children: [
                _labelCell('구분', isHeader: true),
                for (final i in dayIndexes)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: Colors.blue[50],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mealProvider.dates[i]['title']!,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                        const SizedBox(height: 2),
                        Text(mealProvider.dates[i]['date']!,
                            style: const TextStyle(
                                fontSize: 9, color: Colors.black54)),
                      ],
                    ),
                  ),
              ],
            ),
            // 끼니 행들
            for (final slot in _slots)
              TableRow(
                children: [
                  _labelCell(slot[1]),
                  for (final i in dayIndexes)
                    _mealCell(recipeProvider, _dayCat(i), slot[0],
                        '${mealProvider.dates[i]['title']} ${slot[1]}', edit),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _labelCell(String text, {bool isHeader = false}) {
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

  /// 식단 칸: 메뉴 칩 세로 나열 + (편집) [+] · 드롭 대상
  Widget _mealCell(RecipeProvider provider, String cat, String slot,
      String cellLabel, bool edit) {
    final items = _recipesAt(provider, cat, slot);

    return DragTarget<Recipe>(
      onWillAcceptWithDetails: (d) =>
          edit && (d.data.category != cat || d.data.slot != slot),
      onAcceptWithDetails: (d) => provider.moveRecipe(d.data, cat, slot),
      builder: (context, candidates, rejected) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(5),
        color: candidates.isNotEmpty ? Colors.blue[50] : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in items)
              _menuChip(r, edit, provider, null,
                  onView: () => _showCellRecipes(cellLabel, items)),
            if (edit)
              GestureDetector(
                onTap: () => _showAddDialog(provider, cat, slot, cellLabel),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Icon(Icons.add,
                      size: 14,
                      color: items.isEmpty
                          ? Colors.grey[300]
                          : Colors.grey[350]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 메뉴 버튼 (레시피북 스타일)
  ///  - 편집: 탭 = 수정, 길게 끌기 = 이동
  ///  - 보기: 탭 = 그 칸의 레시피 한번에 보기
  Widget _menuChip(
      Recipe r, bool edit, RecipeProvider provider, double? dragWidth,
      {VoidCallback? onView}) {
    final chip = GestureDetector(
      onTap: () => edit
          ? _showEditDialog(provider, r)
          : (onView ?? () => _showViewDialog(r))(),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          r.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
    );

    if (!edit) return chip;

    return LongPressDraggable<Recipe>(
      data: r,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: dragWidth ?? 100,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[400]!, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 8),
            ],
          ),
          child: Text(r.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: chip,
    );
  }

  /// 💡 보기 모드: 그 칸(그날 그 끼니)의 전체 메뉴 레시피를 한번에
  void _showCellRecipes(String cellLabel, List<Recipe> items) {
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
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
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
              Text(cellLabel,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in items)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            if (r.ingredients.trim().isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text('재료',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey[400])),
                              const SizedBox(height: 2),
                              Text(r.ingredients.trim(),
                                  style: const TextStyle(
                                      fontSize: 12.5, height: 1.5)),
                            ],
                            if (r.steps.trim().isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text('조리법',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey[400])),
                              const SizedBox(height: 2),
                              Text(r.steps.trim(),
                                  style: const TextStyle(
                                      fontSize: 12.5, height: 1.5)),
                            ],
                            if (r.ingredients.trim().isEmpty &&
                                r.steps.trim().isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text('레시피 내용이 아직 없습니다.',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey[400])),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- 다이얼로그

  /// 메뉴 추가 — 같은 이름의 레시피가 있으면 재료/조리법을 복사해온다
  void _showAddDialog(
      RecipeProvider provider, String cat, String slot, String cellLabel) {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$cellLabel에 메뉴 추가',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: '메뉴 이름 (예: 김치찌개)', isDense: true),
          onSubmitted: (_) => _submitAdd(dialogContext, provider, cat, slot),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => _submitAdd(dialogContext, provider, cat, slot),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _submitAdd(BuildContext dialogContext, RecipeProvider provider,
      String cat, String slot) {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    // 같은 이름 레시피가 이미 있으면 내용(재료·조리법)을 물려받는다
    Recipe? sameName;
    for (final r in provider.recipes) {
      if (r.name == name) {
        sameName = r;
        break;
      }
    }
    provider.addRecipe(
      name,
      cat,
      sameName?.ingredients ?? '',
      sameName?.steps ?? '',
      slot: slot,
    );
    Navigator.pop(dialogContext);
  }

  /// 관리자: 레시피 수정 + 삭제
  void _showEditDialog(RecipeProvider provider, Recipe recipe) {
    _nameController.text = recipe.name;
    _ingredientsController.text = recipe.ingredients;
    _stepsController.text = recipe.steps;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('메뉴 수정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: '메뉴 이름', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ingredientsController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '재료',
                  hintText: '돼지고기 500g\n김치 1/4포기',
                  hintStyle: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _stepsController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '조리법',
                  hintText: '1. 고기 볶기\n2. 김치 넣고 볶기',
                  hintStyle: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.deleteRecipe(recipe.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              provider.updateRecipe(Recipe(
                id: recipe.id,
                name: name,
                category: recipe.category,
                ingredients: _ingredientsController.text,
                steps: _stepsController.text,
                order: recipe.order,
                slot: recipe.slot,
              ));
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  /// 일반 대원: 레시피 보기
  void _showViewDialog(Recipe recipe) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(recipe.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recipe.ingredients.trim().isNotEmpty) ...[
                Text('재료',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400])),
                const SizedBox(height: 3),
                Text(recipe.ingredients.trim(),
                    style: const TextStyle(fontSize: 13, height: 1.5)),
                const SizedBox(height: 10),
              ],
              if (recipe.steps.trim().isNotEmpty) ...[
                Text('조리법',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400])),
                const SizedBox(height: 3),
                Text(recipe.steps.trim(),
                    style: const TextStyle(fontSize: 13, height: 1.5)),
              ],
              if (recipe.ingredients.trim().isEmpty &&
                  recipe.steps.trim().isEmpty)
                const Text('레시피 내용이 아직 없습니다.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기')),
        ],
      ),
    );
  }
}
