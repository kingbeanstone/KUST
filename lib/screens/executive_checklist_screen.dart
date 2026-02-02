import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/executive_checklist_provider.dart';
import '../models/executive_checklist_model.dart';

class ExecutiveChecklistScreen extends StatelessWidget {
  const ExecutiveChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 💡 에러 이미지에 나온 변수명 불일치를 예방하기 위해 명확히 선언
    final equipProv = Provider.of<EquipmentProvider>(context);
    final checklistProv = Provider.of<ExecutiveChecklistProvider>(context);

    const categoryOrder = ['일반', '대장', '장비', '홍보', '기획', '총무', '훈련'];

    Map<String, List<ExecutiveChecklistItem>> groupedItems = {};
    for (var item in checklistProv.items) {
      groupedItems.putIfAbsent(item.category, () => []).add(item);
    }

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
          if (equipProv.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_task, color: Colors.blue),
              onPressed: () => _showEditDialog(context, checklistProv),
            ),
        ],
      ),
      body: checklistProv.items.isEmpty
          ? const Center(child: Text('등록된 업무가 없습니다.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedCategories.length,
        itemBuilder: (context, index) {
          final category = sortedCategories[index];
          return _buildCategorySection(context, equipProv, checklistProv, category, groupedItems[category]!);
        },
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, EquipmentProvider auth, ExecutiveChecklistProvider provider, String category, List<ExecutiveChecklistItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(category, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo[700])),
        ),
        // 💡 ReorderableListView 로직 완성
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          onReorder: (oldIndex, newIndex) async {
            // 관리자가 아닐 경우 조작 방지
            if (!auth.isAdmin) return;

            // 💡 [핵심] 드래그 앤 드롭 인덱스 보정
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }

            // 데이터 순서 변경
            final List<ExecutiveChecklistItem> updatedList = List.from(items);
            final movedItem = updatedList.removeAt(oldIndex);
            updatedList.insert(newIndex, movedItem);

            // 💡 Provider를 통해 Firestore의 'order' 필드 일괄 업데이트
            await provider.updateItemsOrder(category, updatedList);
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
        onTap: auth.isAdmin ? () => _showEditDialog(context, provider, existing: item) : null,
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