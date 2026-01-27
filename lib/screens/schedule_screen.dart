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
  bool _isEditMode = false;
  // 모든 날짜의 데이터를 관리하기 위한 맵
  Map<String, DailySchedule> _editingSchedules = {};

  // 표 설정을 위한 상수들 (식단표와 통일감 유지)
  static const double labelColumnWidth = 50.0; // 좌측 순번 열 너비
  static const double dateColumnWidth = 160.0; // 각 날짜 열 너비 (일정은 내용이 길어서 조금 더 넓게 설정)
  static const double cellHeight = 80.0;       // 각 칸의 높이
  static const double headerHeight = 60.0;     // 헤더 높이

  // 편집 모드 진입
  void _enterEditMode(ScheduleProvider provider) {
    setState(() {
      _isEditMode = true;
      _editingSchedules = {
        for (var date in provider.dates)
          date['id']!: provider.schedules.firstWhere(
                (s) => s.id == date['id'],
            orElse: () => DailySchedule(id: date['id']!, items: []),
          )
      };
    });
  }

  // 편집 내용 전체 저장
  Future<void> _saveAllSchedules(ScheduleProvider provider) async {
    for (var schedule in _editingSchedules.values) {
      await provider.updateDailySchedule(schedule);
    }
    setState(() => _isEditMode = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 원정 일정이 저장되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final scheduleProvider = Provider.of<ScheduleProvider>(context);

    // 💡 표의 행 개수를 결정하기 위해 모든 날짜 중 최대 일정 개수를 찾습니다.
    int maxItems = 0;
    for (var date in scheduleProvider.dates) {
      final s = scheduleProvider.schedules.firstWhere(
            (s) => s.id == date['id'],
        orElse: () => DailySchedule(id: date['id']!, items: []),
      );
      if (s.items.length > maxItems) maxItems = s.items.length;
    }
    // 최소 5행은 보장하도록 설정
    if (maxItems < 5) maxItems = 5;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('📅 원정 전체 일정', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (equipmentProvider.isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.blue),
              onPressed: () => _showManageDaysDialog(context, scheduleProvider),
            ),
          if (equipmentProvider.isAdmin)
            TextButton(
              onPressed: () => _isEditMode ? _saveAllSchedules(scheduleProvider) : _enterEditMode(scheduleProvider),
              child: Text(
                _isEditMode ? '전체 저장' : '편집',
                style: TextStyle(
                  color: _isEditMode ? Colors.blue[700] : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 좌측 고정 라벨 열 (순번 표시)
                    _buildFixedLabelColumn(maxItems),

                    // 2. 우측 가로 스크롤 일정 데이터 영역
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(scheduleProvider.dates.length, (index) {
                            final dayInfo = scheduleProvider.dates[index];
                            final String dayId = dayInfo['id']!;

                            final schedule = _isEditMode
                                ? _editingSchedules[dayId]!
                                : scheduleProvider.schedules.firstWhere(
                                  (s) => s.id == dayId,
                              orElse: () => DailySchedule(id: dayId, items: []),
                            );

                            return _buildDateScheduleColumn(dayInfo, schedule, maxItems);
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 좌측 고정 순번 열
  Widget _buildFixedLabelColumn(int rowCount) {
    return Container(
      width: labelColumnWidth,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        children: [
          _buildCell('순번', headerHeight, isHeader: true),
          ...List.generate(rowCount, (i) => _buildCell('${i + 1}', cellHeight)),
        ],
      ),
    );
  }

  // 날짜별 일정 데이터 열
  Widget _buildDateScheduleColumn(Map<String, String> dayInfo, DailySchedule schedule, int rowCount) {
    return Container(
      width: dateColumnWidth,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        children: [
          // 헤더: 날짜 및 일차
          Container(
            height: headerHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayInfo['title']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                Text(dayInfo['date']!, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
          // 일정 리스트 행들
          ...List.generate(rowCount, (i) {
            final bool hasData = i < schedule.items.length;
            final item = hasData ? schedule.items[i] : null;
            return _buildScheduleCell(schedule.id, i, item);
          }),
        ],
      ),
    );
  }

  // 일정 데이터 셀
  Widget _buildScheduleCell(String dayId, int index, ScheduleItem? item) {
    return Container(
      height: cellHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: _isEditMode
          ? Column(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: item?.time ?? '',
              onChanged: (v) => _updateLocalItem(dayId, index, v, item?.description ?? ''),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
              decoration: const InputDecoration(hintText: '시간', border: InputBorder.none, isDense: true),
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: item?.description ?? '',
              onChanged: (v) => _updateLocalItem(dayId, index, item?.time ?? '', v),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(hintText: '일정 내용', border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      )
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item != null) ...[
            Text(
              item.time,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              item.description,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else
            const Text('-', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // 일반 텍스트 셀 (라벨용)
  Widget _buildCell(String text, double height, {bool isHeader = false}) {
    return Container(
      height: height,
      width: labelColumnWidth,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.black87 : Colors.grey[600],
        ),
      ),
    );
  }

  // 로컬 데이터 실시간 업데이트 로직
  void _updateLocalItem(String dayId, int index, String time, String desc) {
    final schedule = _editingSchedules[dayId]!;
    final List<ScheduleItem> newItems = List.from(schedule.items);

    final newItem = ScheduleItem(time: time, description: desc);

    if (index < newItems.length) {
      newItems[index] = newItem;
    } else {
      // 새로운 행에 입력 시 리스트 확장
      while (newItems.length <= index) {
        newItems.add(ScheduleItem(time: '', description: ''));
      }
      newItems[index] = newItem;
    }

    _editingSchedules[dayId] = DailySchedule(id: dayId, items: newItems);
  }

  // (기존 날짜 관리 로직 유지)
  void _showManageDaysDialog(BuildContext context, ScheduleProvider scheduleProvider) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('📅 일정 날짜 관리', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setDialogState(() => scheduleProvider.reorderDates(oldIndex, newIndex));
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
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setDialogState(() => scheduleProvider.removeDay(index));
                      setState(() {});
                    },
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(onPressed: () { setDialogState(() => scheduleProvider.addDay()); setState(() {}); }, child: const Text('날짜 추가')),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
          ],
        ),
      ),
    );
  }
}