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

  /// 'HH:MM' 형태를 분 단위로 파싱 ('~14:30' 같은 접두어 허용, 실패 시 null)
  int? _parseMinutes(String time) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  /// 새 일정을 시간순으로 끼워 넣을 위치 (파싱 불가면 맨 뒤)
  int _autoInsertIndex(List<ScheduleItem> items, String time) {
    final newMinutes = _parseMinutes(time);
    if (newMinutes == null) return items.length;
    for (var i = 0; i < items.length; i++) {
      final t = _parseMinutes(items[i].time);
      if (t != null && t > newMinutes) return i;
    }
    return items.length;
  }

  // 일정 항목 다이얼로그 (ScheduleProvider와 연결)
  void _showItemDialog(BuildContext context, ScheduleProvider scheduleProvider, bool isAdmin, {ScheduleItem? item, int? index}) {
    if (!isAdmin) return;
    final TextEditingController _timeController = TextEditingController(text: item?.time ?? "");
    final TextEditingController _descController = TextEditingController(text: item?.description ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          item == null ? '새 일정 추가' : '일정 수정',
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
                // 💡 새 일정은 시간순으로 자동 삽입 (사이 + 버튼 대체)
                final items = scheduleProvider.schedules
                    .firstWhere((s) => s.id == dayId,
                        orElse: () => DailySchedule(id: dayId, items: []))
                    .items;
                scheduleProvider.saveScheduleItem(dayId, newItem,
                    atIndex: _autoInsertIndex(items, newItem.time));
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
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 80),
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
                  borderRadius: BorderRadius.circular(10),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final item = dailySchedule.items[index];
                return KeyedSubtree(
                  key: ValueKey('${item.time}_${item.description}_$index'),
                  child: _buildTimelineItem(
                      context, scheduleProvider, isAdmin, dailySchedule.items, index),
                );
              },
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 80),
              itemCount: dailySchedule.items.length,
              itemBuilder: (context, index) {
                return _buildTimelineItem(
                    context, scheduleProvider, isAdmin, dailySchedule.items, index);
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

  /// 💡 구글 캘린더식 타임라인: 다음 일정까지의 시간 간격에 비례해
  /// 블록 높이가 정해져서 각 일정의 '길이감'이 한눈에 보인다.
  Widget _buildTimelineItem(BuildContext context, ScheduleProvider scheduleProvider,
      bool isAdmin, List<ScheduleItem> items, int index) {
    final item = items[index];

    // 다음 시간 파싱 가능한 항목까지의 간격으로 높이 계산
    final start = _parseMinutes(item.time);
    int? next;
    for (var j = index + 1; j < items.length; j++) {
      final t = _parseMinutes(items[j].time);
      if (t != null) {
        next = t;
        break;
      }
    }

    const minHeight = 48.0;
    const maxHeight = 150.0; // 밤샘 이동 같은 긴 공백이 화면을 다 먹지 않게
    double height = minHeight;
    if (start != null && next != null && next > start) {
      height = ((next - start) * 1.1).clamp(minHeight, maxHeight);
    }
    final isLast = next == null;
    final compact = height < 68;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 시간 라벨 열
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 6),
              child: Text(
                item.time,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[600]),
              ),
            ),
          ),
          // 타임라인 레일 (점 + 세로선)
          SizedBox(
            width: 14,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: Colors.blue[800], shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: Colors.blue[100])),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 일정 블록 — 높이가 곧 시간 길이
          Expanded(
            child: GestureDetector(
              onTap: isAdmin
                  ? () => _showItemDialog(context, scheduleProvider, isAdmin,
                      item: item, index: index)
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                      left: BorderSide(color: Colors.blue[800]!, width: 3.5)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: compact
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF212121)),
                            ),
                          ),
                          if (isAdmin)
                            const Icon(Icons.drag_indicator,
                                color: Colors.grey, size: 18),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF212121)),
                                ),
                              ),
                              if (isAdmin)
                                const Icon(Icons.drag_indicator,
                                    color: Colors.grey, size: 18),
                            ],
                          ),
                          const Spacer(),
                          if (start != null && next != null)
                            Text(
                              _durationLabel(next - start),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.blueGrey[300]),
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

  /// 분 → '1시간 30분' 형태 라벨
  String _durationLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }
}