import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _currentTab = 'BCD'; // 'BCD' 또는 '호흡기'

  void _showAddEditDialog(BuildContext context, EquipmentProvider provider, {dynamic existingItem}) {
    final bool isEdit = existingItem != null;
    final idController = TextEditingController(text: isEdit ? existingItem.id : "");
    final nameController = TextEditingController(text: isEdit ? existingItem.name : "");
    final memoController = TextEditingController(text: isEdit ? existingItem.memo : "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? '장비 정보 수정' : '새 장비 추가', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEdit) // 추가 시에만 번호 입력 가능 (Key이므로 수정 불가)
              TextField(
                controller: idController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '$_currentTab 번호 (필수)', border: const OutlineInputBorder()),
              ),
            if (!isEdit) const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '사용자 이름', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memoController,
              decoration: const InputDecoration(labelText: '기타 (상태 등)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (idController.text.isEmpty) return;

              if (_currentTab == 'BCD') {
                if (isEdit) {
                  await provider.updateBcd(idController.text, nameController.text, memoController.text);
                } else {
                  await provider.addBcd(idController.text, nameController.text, memoController.text);
                }
              } else {
                if (isEdit) {
                  await provider.updateRegulator(idController.text, nameController.text, memoController.text);
                } else {
                  await provider.addRegulator(idController.text, nameController.text, memoController.text);
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
            child: Text(isEdit ? '수정' : '추가'),
          ),
          if (isEdit && provider.isAdmin)
            TextButton(
              onPressed: () {
                _currentTab == 'BCD'
                    ? provider.deleteBcd(existingItem.id)
                    : provider.deleteRegulator(existingItem.id);
                Navigator.pop(context);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EquipmentProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('장비 인벤토리 현황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (provider.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              onPressed: () => _showAddEditDialog(context, provider),
            ),
        ],
      ),
      body: Column(
        children: [
          // 상단 탭 버튼
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton('BCD'),
                const SizedBox(width: 16),
                _buildTabButton('호흡기'),
              ],
            ),
          ),
          // 리스트 영역
          Expanded(
            child: _currentTab == 'BCD'
                ? _buildBcdList(provider)
                : _buildRegulatorList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label) {
    bool isSelected = _currentTab == label;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBcdList(EquipmentProvider provider) {
    if (provider.bcds.isEmpty) return const Center(child: Text('등록된 BCD가 없습니다.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.bcds.length,
      itemBuilder: (context, index) {
        final item = provider.bcds[index];
        return _buildInventoryTile(context, provider, 'BCD', item.id, item.name, item.memo, item);
      },
    );
  }

  Widget _buildRegulatorList(EquipmentProvider provider) {
    if (provider.regulators.isEmpty) return const Center(child: Text('등록된 호흡기가 없습니다.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.regulators.length,
      itemBuilder: (context, index) {
        final item = provider.regulators[index];
        return _buildInventoryTile(context, provider, '호흡기', item.id, item.name, item.memo, item);
      },
    );
  }

  Widget _buildInventoryTile(BuildContext context, EquipmentProvider provider, String type, String no, String name, String memo, dynamic item) {
    return GestureDetector(
      onTap: () => _showAddEditDialog(context, provider, existingItem: item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Text('$type : ', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            SizedBox(width: 30, child: Text(no, style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            const Text('이름 : ', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(child: Text(name.isEmpty ? '(미지정)' : name, style: const TextStyle(fontSize: 14))),
            const Text('기타 : ', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(child: Text(memo.isEmpty ? '-' : memo, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.edit, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}