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
    {'date': '1.29 (목)', 'title': '1일차 (동방파제)', 'id': '1.29'},
    {'date': '1.30 (금)', 'title': '2일차 (보목)', 'id': '1.30'},
    {'date': '1.31 (토)', 'title': '3일차 (입도)', 'id': '1.31'},
    {'date': '2.1 (일)', 'title': '4일차 (드라이데이)', 'id': '2.1'},
    {'date': '2.2 (월)', 'title': '5일차 (입도)', 'id': '2.2'},
    {'date': '2.3 (화)', 'title': '6일차 (보팅)', 'id': '2.3'},
    {'date': '2.4 (수)', 'title': '7일차 (동기여행)', 'id': '2.4'},
    {'date': '2.5 (목)', 'title': '8일차 (복귀)', 'id': '2.5'},
  ];

  int _selectedDateIndex = 0;

  void _showItemDialog(BuildContext context, EquipmentProvider provider, {ScheduleItem? item, int? index, int? insertAtIndex}) {
    if (!provider.isAdmin) return;

    final TextEditingController _timeController = TextEditingController(text: item?.time ?? "");
    final TextEditingController _descController = TextEditingController(text: item?.description ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          item == null ? (insertAtIndex != null ? '사이에 일정 삽입' : '새 일정 추가') : '일정 수정',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: '시간 (예: 08:00)', hintStyle: TextStyle(fontSize: 12)),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '내용', hintText: '활동 내용을 입력하세요'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          if (item != null && index != null)
            TextButton(
              onPressed: () {
                provider.deleteScheduleItem(_dates[_selectedDateIndex]['id']!, index);
                Navigator.pop(context);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () {
              if (_timeController.text.isEmpty || _descController.text.isEmpty) return;

              final newItem = ScheduleItem(
                time: _timeController.text,
                description: _descController.text,
              );

              final dayId = _dates[_selectedDateIndex]['id']!;
              if (item == null) {
                provider.saveScheduleItem(dayId, newItem, atIndex: insertAtIndex);
              } else {
                provider.updateScheduleItem(dayId, index!, newItem);
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
        actions: [
          if (provider.isAdmin && dailySchedule.items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: Text('길게 눌러 이동', style: TextStyle(fontSize: 11, color: Colors.blue))),
            )
        ],
      ),
      body: Column(
        children: [
          // 💡 상단 날짜 바 UI 개선
          Container(
            height: 90, // 높이를 조금 더 확보하여 여유를 줌
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedDateIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDateIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 130,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[800] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.blue[800]! : Colors.grey[200]!,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.blue[800]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dates[index]['date']!,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            color: isSelected ? Colors.white.withOpacity(0.8) : Colors.black45,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dates[index]['title']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // 일정 리스트
          Expanded(
            child: dailySchedule.items.isEmpty
                ? _buildEmptyState()
                : provider.isAdmin
                ? ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              itemCount: dailySchedule.items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = dailySchedule.items.removeAt(oldIndex);
                  dailySchedule.items.insert(newIndex, item);
                  provider.updateDailySchedule(dailySchedule);
                });
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 5,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final item = dailySchedule.items[index];
                return Column(
                  key: ValueKey('${item.time}_${item.description}_$index'),
                  children: [
                    _buildTimelineItem(context, provider, item, index),
                    if (index < dailySchedule.items.length - 1)
                      _buildInsertPoint(context, provider, index + 1),
                  ],
                );
              },
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
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
          ? FloatingActionButton.extended(
        onPressed: () => _showItemDialog(context, provider),
        backgroundColor: Colors.blue[800],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('일정 추가', style: TextStyle(color: Colors.white)),
      )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('등록된 일정이 없습니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInsertPoint(BuildContext context, EquipmentProvider provider, int atIndex) {
    return Row(
      children: [
        const SizedBox(width: 5),
        Container(width: 2, height: 30, color: Colors.blue[100]),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () => _showItemDialog(context, provider, insertAtIndex: atIndex),
          icon: Icon(Icons.add_circle, color: Colors.blue[200], size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
        const Expanded(child: Divider(color: Colors.transparent)),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, EquipmentProvider provider, ScheduleItem item, int index) {
    return IntrinsicHeight(
      child: Row(
        children: [
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
          Expanded(
            child: GestureDetector(
              onTap: provider.isAdmin ? () => _showItemDialog(context, provider, item: item, index: index) : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10, top: 2),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
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
                    if (provider.isAdmin)
                      const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
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