import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _currentTab = 'BCD';

  // 💡 탭 목록 확장 (공용 장비 포함)
  final List<String> _tabs = [
    'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '나침반', '스노클', '기타'
  ];

  final TextEditingController _memoController = TextEditingController();

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
            if (!isEdit)
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
          // 💡 BCD나 호흡기 탭일 때만 개별 추가 버튼 노출
          if (provider.isAdmin && (_currentTab == 'BCD' || _currentTab == '호흡기'))
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              onPressed: () => _showAddEditDialog(context, provider),
            ),
        ],
      ),
      body: Column(
        children: [
          // 상단 탭 버튼 (가로 스크롤 가능하도록 수정)
          Container(
            color: Colors.white,
            height: 55,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _tabs.length,
              itemBuilder: (context, index) => _buildTabButton(_tabs[index]),
            ),
          ),
          // 리스트 영역
          Expanded(
            child: _buildBody(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(EquipmentProvider provider) {
    if (_currentTab == 'BCD') return _buildBcdList(provider);
    if (_currentTab == '호흡기') return _buildRegulatorList(provider);

    // 💡 그 외 공용 장비 UI
    return _buildGeneralGearView(provider, _currentTab);
  }

  Widget _buildTabButton(String label) {
    bool isSelected = _currentTab == label;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = label),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.blue[800]! : Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
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

  // 💡 공용 장비(슈트, 마스크 등) 전용 뷰
  Widget _buildGeneralGearView(EquipmentProvider provider, String gearId) {
    final gear = provider.generalGears.firstWhere(
          (g) => g.id == gearId,
      orElse: () => GeneralGearItem(id: gearId),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 수량 관리 카드
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Text('총 보유 수량', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 12),
                Text('${gear.count}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue)),
                if (provider.isAdmin) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _countButton(Icons.remove, Colors.red, () => provider.updateGeneralGearCount(gearId, -1)),
                      const SizedBox(width: 40),
                      _countButton(Icons.add, Colors.green, () => provider.updateGeneralGearCount(gearId, 1)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),
          // 메모 리스트 섹션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('관리 메모', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${gear.memos.length}건', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          // 메모 입력 (관리자 전용)
          if (provider.isAdmin)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memoController,
                      decoration: const InputDecoration(
                        hintText: '장비 상태나 특이사항 기록...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_memoController.text.isNotEmpty) {
                        provider.addGeneralGearMemo(gearId, _memoController.text);
                        _memoController.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                    child: const Text('등록'),
                  ),
                ],
              ),
            ),
          // 메모 목록
          if (gear.memos.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: const Text('등록된 메모가 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gear.memos.length,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                child: Row(
                  children: [
                    const Icon(Icons.notes, size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 12),
                    Expanded(child: Text(gear.memos[index], style: const TextStyle(fontSize: 14))),
                    if (provider.isAdmin)
                      IconButton(
                        onPressed: () => provider.deleteGeneralGearMemo(gearId, index),
                        icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _countButton(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 50, height: 50,
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 28),
    ),
  );

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