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

    // 💡 정의된 순서에 있는 카테고리를 먼저 배치하고, 그 외(기존 데이터 등)는 뒤로 보냄
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
              onPressed: () => _showAddDialog(context, checklistProvider),
            ),
        ],
      ),
      body: checklistProvider.items.isEmpty
          ? const Center(child: Text('등록된 업무가 없습니다.', style: TextStyle(color: Colors.grey)))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: sortedCategories.map((category) {
          return _buildCategorySection(context, authProvider, checklistProvider, category, groupedItems[category]!);
        }).toList(),
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
        ...items.map((item) => _buildCheckItem(context, auth, provider, item)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCheckItem(BuildContext context, EquipmentProvider auth, ExecutiveChecklistProvider provider, ExecutiveChecklistItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.isChecked ? Colors.green[100]! : Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: auth.isAdmin ? () => provider.toggleItem(item.id, item.isChecked) : null,
        leading: Icon(
          item.isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
          color: item.isChecked ? Colors.green : Colors.grey[400],
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
        trailing: auth.isAdmin
            ? IconButton(
          icon: const Icon(Icons.more_vert, size: 20),
          onPressed: () => _showEditDeleteSheet(context, provider, item),
        )
            : null,
      ),
    );
  }

  void _showAddDialog(BuildContext context, ExecutiveChecklistProvider provider) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    // 💡 요청하신 카테고리 리스트로 수정
    String selectedCategory = '일반';
    final categories = ['일반', '대장', '장비', '홍보', '기획', '총무', '훈련'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('새 업무 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDialogState(() => selectedCategory = v!),
                decoration: const InputDecoration(labelText: '카테고리'),
              ),
              TextField(controller: titleController, decoration: const InputDecoration(labelText: '업무명')),
              TextField(controller: descController, decoration: const InputDecoration(labelText: '상세 설명')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isEmpty) return;
                provider.addItem(titleController.text, selectedCategory, description: descController.text);
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDeleteSheet(BuildContext context, ExecutiveChecklistProvider provider, ExecutiveChecklistItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('삭제하기', style: TextStyle(color: Colors.red)),
              onTap: () {
                provider.deleteItem(item.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}