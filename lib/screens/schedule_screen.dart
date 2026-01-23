import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
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

  void _showItemDialog(BuildContext context, EquipmentProvider provider, {ScheduleItem? item, int? index}) {
    if (!provider.isAdmin) return;

    final TextEditingController _timeController = TextEditingController(text: item?.time ?? "");
    final TextEditingController _descController = TextEditingController(text: item?.description ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? '일정 추가' : '일정 수정', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: '시간 (예: 08:00)', hintText: '00:00'),
              keyboardType: TextInputType.datetime,
            ),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '내용', hintText: '장비 점검 및 집합'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          if (item != null)
            TextButton(
              onPressed: () {
                provider.deleteScheduleItem(_dates[_selectedDateIndex]['id']!, index!);
                Navigator.pop(context);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () {
              if (_timeController.text.isEmpty || _descController.text.isEmpty) return;

              final newItem = ScheduleItem(
                time: _timeController.text,
                description: _descController.text,
              );

              if (item == null) {
                provider.addScheduleItem(_dates[_selectedDateIndex]['id']!, newItem);
              } else {
                provider.updateScheduleItem(_dates[_selectedDateIndex]['id']!, index!, newItem);
              }
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EquipmentProvider>(context);
    final currentId = _dates[_selectedDateIndex]['id']!;

    // 현재 날짜의 일정 가져오기
    final dailySchedule = provider.schedules.firstWhere(
          (s) => s.id == currentId,
      orElse: () => DailySchedule(id: currentId, items: []),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('📅 원정 일정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // 상단 날짜 선택 바
          Container(
            height: 65,
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
                        if (val) setState(() => _selectedDateIndex = index);
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
          // 일정 리스트
          Expanded(
            child: dailySchedule.items.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('등록된 일정이 없습니다.', style: TextStyle(color: Colors.grey)),
                  if (provider.isAdmin)
                    const Text('하단 버튼을 눌러 추가해 보세요.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: dailySchedule.items.length,
              itemBuilder: (context, index) {
                final item = dailySchedule.items[index];
                return _buildTimelineItem(context, provider, item, index);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: provider.isAdmin
          ? FloatingActionButton(
        onPressed: () => _showItemDialog(context, provider),
        backgroundColor: Colors.blue[800],
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildTimelineItem(BuildContext context, EquipmentProvider provider, ScheduleItem item, int index) {
    return IntrinsicHeight(
      child: Row(
        children: [
          // 타임라인 장식
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: Colors.blue[800], shape: BoxShape.circle),
              ),
              Expanded(
                child: Container(width: 2, color: Colors.blue[100]),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // 내용 카드
          Expanded(
            child: GestureDetector(
              onTap: provider.isAdmin ? () => _showItemDialog(context, provider, item: item, index: index) : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.time,
                      style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF212121)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}