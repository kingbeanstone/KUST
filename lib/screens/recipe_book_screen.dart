import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe_model.dart';

/// 💡 동아리 공용 레시피북: 보기(전체) + 추가/수정/삭제(관리자).
class RecipeBookScreen extends StatefulWidget {
  const RecipeBookScreen({super.key});

  @override
  State<RecipeBookScreen> createState() => _RecipeBookScreenState();
}

class _RecipeBookScreenState extends State<RecipeBookScreen> {
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

  void _showEditDialog(RecipeProvider provider, {Recipe? recipe}) {
    _nameController.text = recipe?.name ?? '';
    _ingredientsController.text = recipe?.ingredients ?? '';
    _stepsController.text = recipe?.steps ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(recipe == null ? '새 레시피' : '레시피 수정',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: '요리 이름 (예: 김치찌개)', isDense: true),
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
                  hintText: '돼지고기 500g\n김치 1/4포기\n두부 1모',
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
                  hintText: '1. 고기 볶기\n2. 김치 넣고 볶기\n3. 물 붓고 끓이기',
                  hintStyle: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소')),
          if (recipe != null)
            TextButton(
              onPressed: () {
                provider.deleteRecipe(recipe.id);
                Navigator.pop(dialogContext);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              if (recipe == null) {
                provider.addRecipe(
                    name, _ingredientsController.text, _stepsController.text);
              } else {
                provider.updateRecipe(Recipe(
                  id: recipe.id,
                  name: name,
                  ingredients: _ingredientsController.text,
                  steps: _stepsController.text,
                ));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final provider = context.watch<RecipeProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('📖 레시피북',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: provider.recipes.isEmpty
          ? Center(
              child: Text(
                isAdmin ? '아직 레시피가 없습니다.\n오른쪽 아래에서 추가하세요.' : '아직 레시피가 없습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: provider.recipes.length,
              itemBuilder: (context, index) {
                final recipe = provider.recipes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Theme(
                    // ExpansionTile 기본 구분선 제거
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(recipe.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 17, color: Colors.blueGrey),
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _showEditDialog(provider, recipe: recipe),
                            ),
                        ],
                      ),
                      children: [
                        if (recipe.ingredients.trim().isNotEmpty) ...[
                          _sectionLabel('재료'),
                          _sectionText(recipe.ingredients),
                          const SizedBox(height: 8),
                        ],
                        if (recipe.steps.trim().isNotEmpty) ...[
                          _sectionLabel('조리법'),
                          _sectionText(recipe.steps),
                        ],
                        if (recipe.ingredients.trim().isEmpty &&
                            recipe.steps.trim().isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('내용이 아직 없습니다.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showEditDialog(provider),
              backgroundColor: Colors.blue[800],
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('레시피 추가',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _sectionLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(text,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[400])),
        ),
      );

  Widget _sectionText(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text.trim(),
            style: const TextStyle(fontSize: 13, height: 1.5)),
      );
}
