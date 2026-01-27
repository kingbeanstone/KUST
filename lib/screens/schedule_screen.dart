import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/schedule_provider.dart';
import '../models/schedule_model.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _selectedDateIndex = 0;

  // 💡 날짜 탭 관리 다이얼로그 (ScheduleProvider와 연결)
  void _showManageDaysDialog(BuildContext context, ScheduleProvider scheduleProvider) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('📅 일정 날짜 관리', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                const Text('길게 눌러 순서 변경 / 클릭하여 수정', style: TextStyle(fontSize: 12, color: Colors.blue)),
                const SizedBox(height: 10),
                Expanded(
                  child: ReorderableListView(
                    onReorder: (oldIndex, newIndex) {
                      setDialogState(() {
                        scheduleProvider.reorderDates(oldIndex, newIndex);
                      });
                      setState(() {});
                    },
                    children: List.generate(scheduleProvider.dates.length, (index) {
                      final day = scheduleProvider.dates[index];
                      return ListTile(
                        key: ValueKey(day['id']),
                        leading: const Icon(Icons.drag_handle),
                        title: Text(day['title']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text(day['date']!, style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.blue),
                          onPressed: () => _editDayInfo(context, index, scheduleProvider, setDialogState),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  scheduleProvider.addDay();
                });
                setState(() {});
              },
              child: const Text('날짜 추가'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 개별 날짜 텍스트 수정 (ScheduleProvider와 연결)
  void _editDayInfo(BuildContext context, int index, ScheduleProvider scheduleProvider, StateSetter setDialogState) {
    final dateController = TextEditingController(text: scheduleProvider.dates[index]['date']);
    final titleController = TextEditingController(text: scheduleProvider.dates[index]['title']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('날짜 정보 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: dateController, decoration: const InputDecoration(labelText: '날짜 (예: 1.29 (목))')),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '제목 (예: 1일차 (장소))')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setDialogState(() {
                scheduleProvider.removeDay(index);
              });
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('이 날짜 삭제', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              setDialogState(() {
                scheduleProvider.updateDayInfo(index, dateController.text, titleController.text);
              });
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  // 일정 항목 다이얼로그 (ScheduleProvider와 연결)
  void _showItemDialog(BuildContext context, ScheduleProvider scheduleProvider, bool isAdmin, {ScheduleItem? item, int? index, int? insertAtIndex}) {
    if (!isAdmin) return;
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
                scheduleProvider.deleteScheduleItem(scheduleProvider.dates[_selectedDateIndex]['id']!, index);
                Navigator.pop(context);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () {
              if (_timeController.text.isEmpty || _descController.text.isEmpty) return;
              final newItem = ScheduleItem(time: _timeController.text, description: _descController.text);
              final dayId = scheduleProvider.dates[_selectedDateIndex]['id']!;
              if (item == null) {
                scheduleProvider.saveScheduleItem(dayId, newItem, atIndex: insertAtIndex);
              } else {
                scheduleProvider.updateScheduleItem(dayId, index!, newItem);
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
    // 💡 두 Provider를 동시에 가져옵니다.
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final scheduleProvider = Provider.of<ScheduleProvider>(context);

    final isAdmin = equipmentProvider.isAdmin;
    final dates = scheduleProvider.dates;

    if (_selectedDateIndex >= dates.length) _selectedDateIndex = 0;

    final currentId = dates.isNotEmpty ? dates[_selectedDateIndex]['id']! : "";

    final dailySchedule = scheduleProvider.schedules.firstWhere(
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
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.blue),
              onPressed: () => _showManageDaysDialog(context, scheduleProvider),
              tooltip: '일자 관리',
            ),
          if (isAdmin && dailySchedule.items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(child: Text('길게 눌러 이동', style: TextStyle(fontSize: 11, color: Colors.blue))),
            )
        ],
      ),
      body: Column(
        children: [
          // 상단 날짜 바
          Container(
            height: 90,
            color: Colors.white,
            child: dates.isEmpty
                ? const Center(child: Text('설정된 일자가 없습니다.'))
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: dates.length,
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
                          dates[index]['date']!,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            color: isSelected ? Colors.white.withOpacity(0.8) : Colors.black45,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dates[index]['title']!,
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
            child: dates.isEmpty
                ? _buildEmptyState()
                : dailySchedule.items.isEmpty
                ? _buildEmptyState()
                : isAdmin
                ? ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              itemCount: dailySchedule.items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = dailySchedule.items.removeAt(oldIndex);
                  dailySchedule.items.insert(newIndex, item);
                  scheduleProvider.updateDailySchedule(dailySchedule);
                });
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 5, color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final item = dailySchedule.items[index];
                return Column(
                  key: ValueKey('${item.time}_${item.description}_$index'),
                  children: [
                    _buildTimelineItem(context, scheduleProvider, isAdmin, item, index),
                    if (index < dailySchedule.items.length - 1)
                      _buildInsertPoint(context, scheduleProvider, isAdmin, index + 1),
                  ],
                );
              },
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              itemCount: dailySchedule.items.length,
              itemBuilder: (context, index) {
                final item = dailySchedule.items[index];
                return _buildTimelineItem(context, scheduleProvider, isAdmin, item, index);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin && dates.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () => _showItemDialog(context, scheduleProvider, isAdmin),
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
          const Text('일정이 없습니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInsertPoint(BuildContext context, ScheduleProvider scheduleProvider, bool isAdmin, int atIndex) {
    return Row(
      children: [
        const SizedBox(width: 5),
        Container(width: 2, height: 30, color: Colors.blue[100]),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () => _showItemDialog(context, scheduleProvider, isAdmin, insertAtIndex: atIndex),
          icon: Icon(Icons.add_circle, color: Colors.blue[200], size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
        const Expanded(child: Divider(color: Colors.transparent)),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, ScheduleProvider scheduleProvider, bool isAdmin, ScheduleItem item, int index) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: Colors.blue[800], shape: BoxShape.circle),
              ),
              Expanded(child: Container(width: 2, color: Colors.blue[100])),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: GestureDetector(
              onTap: isAdmin ? () => _showItemDialog(context, scheduleProvider, isAdmin, item: item, index: index) : null,
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
                          Text(item.time, style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(item.description, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF212121))),
                        ],
                      ),
                    ),
                    if (isAdmin) const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
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