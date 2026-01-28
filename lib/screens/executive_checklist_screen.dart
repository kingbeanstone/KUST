import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/executive_checklist_provider.dart';
import '../models/executive_checklist_model.dart';

class ExecutiveChecklistScreen extends StatelessWidget {
  const ExecutiveChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<EquipmentProvider>(context);
    final checklistProvider = Provider.of<ExecutiveChecklistProvider>(context);

    // 💡 정의된 업무 순서대로 정렬하기 위한 리스트
    const categoryOrder = ['일반', '대장', '장비', '홍보', '기획', '총무', '훈련'];

    // 카테고리별로 데이터 분류
    Map<String, List<ExecutiveChecklistItem>> groupedItems = {};
    for (var item in checklistProvider.items) {
      groupedItems.putIfAbsent(item.category, () => []).add(item);
    }

    // 💡 정의된 순서에 있는 카테고리를 먼저 배치
    List<String> sortedCategories = groupedItems.keys.toList();
    sortedCategories.sort((a, b) {
      int indexA = categoryOrder.indexOf(a);
      int indexB = categoryOrder.indexOf(b);
      if (indexA == -1) indexA = 99;
      if (indexB == -1) indexB = 99;
      return indexA.compareTo(indexB);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('📋 임원단 체크리스트', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (authProvider.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_task, color: Colors.blue),
              onPressed: () => _showEditDialog(context, checklistProvider),
            ),
        ],
      ),
      body: checklistProvider.items.isEmpty
          ? const Center(child: Text('등록된 업무가 없습니다.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedCategories.length,
        itemBuilder: (context, index) {
          final category = sortedCategories[index];
          return _buildCategorySection(context, authProvider, checklistProvider, category, groupedItems[category]!);
        },
      ),
    );
  }

  // 💡 ReorderableListView를 사용하여 카테고리 내 순서 변경 지원
  Widget _buildCategorySection(BuildContext context, EquipmentProvider auth, ExecutiveChecklistProvider provider, String category, List<ExecutiveChecklistItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(category, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo[700])),
        ),
        // 💡 꾹 눌러서 순서 이동 가능
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          onReorder: (oldIndex, newIndex) {
            // 참고: 실제 DB에 순서를 저장하려면 Provider에 order 필드 업데이트 로직이 필요합니다.
            // 현재는 UI 상에서 정렬 로직에 따라 다시 그려집니다.
          },
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildCheckItem(context, auth, provider, item, key: ValueKey(item.id));
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCheckItem(BuildContext context, EquipmentProvider auth, ExecutiveChecklistProvider provider, ExecutiveChecklistItem item, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.isChecked ? Colors.green[100]! : Colors.grey[200]!),
      ),
      child: ListTile(
        // 💡 리스트를 누르면 수정 다이얼로그 팝업
        onTap: auth.isAdmin ? () => _showEditDialog(context, provider, existing: item) : null,
        // 💡 체크 아이콘을 눌러야 토글되도록 변경하여 텍스트 클릭과 구분함
        leading: GestureDetector(
          onTap: auth.isAdmin ? () => provider.toggleItem(item.id, item.isChecked) : null,
          child: Icon(
            item.isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: item.isChecked ? Colors.green : Colors.grey[400],
            size: 26,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: item.description.isNotEmpty ? Text(item.description, style: const TextStyle(fontSize: 12)) : null,
        trailing: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
      ),
    );
  }

  // 💡 추가 및 수정 통합 다이얼로그
  void _showEditDialog(BuildContext context, ExecutiveChecklistProvider provider, {ExecutiveChecklistItem? existing}) {
    final bool isEdit = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? "");
    final descController = TextEditingController(text: existing?.description ?? "");

    String selectedCategory = existing?.category ?? '일반';
    final categories = ['일반', '대장', '장비', '홍보', '기획', '총무', '훈련'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? '업무 수정' : '새 업무 추가', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v!),
                  decoration: const InputDecoration(labelText: '카테고리', isDense: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '업무명', hintText: '예: 숙소 예약 확인'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '상세 설명', hintText: '추가 전달 사항 입력'),
                ),
              ],
            ),
          ),
          actions: [
            if (isEdit)
              TextButton(
                onPressed: () {
                  provider.deleteItem(existing.id);
                  Navigator.pop(context);
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isEmpty) return;
                if (isEdit) {
                  provider.updateItem(existing.id, titleController.text, selectedCategory, descController.text);
                } else {
                  provider.addItem(titleController.text, selectedCategory, description: descController.text);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
              child: Text(isEdit ? '수정 완료' : '추가'),
            ),
          ],
        ),
      ),
    );
  }
}