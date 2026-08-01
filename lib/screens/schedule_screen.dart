import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/expedition_provider.dart';
import '../providers/schedule_provider.dart';
import '../models/schedule_model.dart';

/// 일정 블록 색상 팔레트 (키가 Firestore에 저장된다)
const Map<String, Color> kItemColors = {
  'blue': Color(0xFF1565C0),
  'teal': Color(0xFF00796B),
  'green': Color(0xFF2E7D32),
  'orange': Color(0xFFEF6C00),
  'purple': Color(0xFF6A1B9A),
  'red': Color(0xFFC62828),
  'grey': Color(0xFF546E7A),
};

/// 💡 v2: 구글 캘린더식 주간 그리드.
/// 좌측 00~24시 시간축 + 일차별 열. 일정 블록은 시간 위치에 절대 배치되어
/// 하루 전체의 흐름과 각 일정의 길이감이 한눈에 보인다.
///  - 관리자: 빈 칸을 탭하면 그 시간으로 일정 추가, 블록 탭 = 수정
///  - 일반: 블록 탭 = 상세 보기
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const double _hourHeight = 40.0; // 1시간의 세로 픽셀
  static const double _axisWidth = 46.0; // 좌측 시간축 폭
  static const double _headerHeight = 42.0; // 일차 헤더 높이

  // 아침 6시부터 보이도록 초기 스크롤
  final ScrollController _vScroll =
      ScrollController(initialScrollOffset: 6 * _hourHeight);
  final ScrollController _headerHScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();

  /// 현재 시각선을 1분마다 갱신
  Timer? _nowTimer;

  @override
  void initState() {
    super.initState();
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    // 헤더와 본문의 가로 스크롤 동기화
    _headerHScroll.addListener(() {
      if (_bodyHScroll.hasClients && _bodyHScroll.offset != _headerHScroll.offset) {
        _bodyHScroll.jumpTo(_headerHScroll.offset);
      }
    });
    _bodyHScroll.addListener(() {
      if (_headerHScroll.hasClients && _headerHScroll.offset != _bodyHScroll.offset) {
        _headerHScroll.jumpTo(_bodyHScroll.offset);
      }
    });
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    _vScroll.dispose();
    _headerHScroll.dispose();
    _bodyHScroll.dispose();
    super.dispose();
  }

  /// 일차 id('8.3' 형태)를 실제 날짜로 변환 (파싱 불가 시 null)
  DateTime? _dateOfDay(String dayId, int year) {
    final match = RegExp(r'^(\d{1,2})\.(\d{1,2})$').firstMatch(dayId.trim());
    if (match == null) return null;
    return DateTime(year, int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  // ------------------------------------------------------------- 시간 유틸

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

  // ------------------------------------------------------------- 다이얼로그

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

  // 일정 항목 추가/수정 다이얼로그
  void _showItemDialog(
    BuildContext context,
    ScheduleProvider scheduleProvider,
    bool isAdmin, {
    required String dayId,
    ScheduleItem? item,
    int? index,
    String? presetTime,
  }) {
    if (!isAdmin) return;
    final timeController = TextEditingController(text: item?.time ?? presetTime ?? "");
    final descController = TextEditingController(text: item?.description ?? "");
    var selectedColor =
        kItemColors.containsKey(item?.color) ? item!.color : 'blue';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          item == null ? '새 일정 추가' : '일정 수정',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: timeController,
              decoration: const InputDecoration(labelText: '시간 (예: 08:00)', hintStyle: TextStyle(fontSize: 12)),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            // 💡 멀티라인: 엔터로 줄바꿈, 최대 4줄까지 늘어남
            TextField(
              controller: descController,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '내용', hintText: '활동 내용을 입력하세요'),
            ),
            const SizedBox(height: 16),
            // 💡 블록 색상 선택
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                children: kItemColors.entries.map((entry) {
                  final isSelected = selectedColor == entry.key;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = entry.key),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black87, width: 2.5)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 15, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          if (item != null && index != null)
            TextButton(
              onPressed: () {
                scheduleProvider.deleteScheduleItem(dayId, index);
                Navigator.pop(context);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () {
              if (descController.text.isEmpty) return;
              final newItem = ScheduleItem(
                  time: timeController.text,
                  description: descController.text,
                  color: selectedColor);
              if (item == null) {
                // 💡 새 일정은 시간순으로 자동 삽입
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
      ),
    );
  }

  /// 일반 사용자용 상세 보기 (좁은 열에서 잘린 내용 확인)
  void _showItemDetail(BuildContext context, String dayLabel, ScheduleItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$dayLabel ${item.time}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text(item.description,
            style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final scheduleProvider = Provider.of<ScheduleProvider>(context);

    final isAdmin = equipmentProvider.isAdmin;
    final dates = scheduleProvider.dates;
    final schedulesById = {for (final s in scheduleProvider.schedules) s.id: s};

    // ── 실제 날짜 기반 진행 상태 (원정 연도 기준)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final year = context.read<ExpeditionProvider>().selected?.year ?? now.year;
    final nowMinutes = now.hour * 60 + now.minute;

    DateTime? firstDay;
    DateTime? lastDay;
    for (final day in dates) {
      final d = _dateOfDay(day['id']!, year);
      if (d == null) continue;
      if (firstDay == null || d.isBefore(firstDay)) firstDay = d;
      if (lastDay == null || d.isAfter(lastDay)) lastDay = d;
    }

    // 원정 진행률: 첫날 00:00 ~ 마지막 날 24:00
    double? progress;
    if (firstDay != null && lastDay != null) {
      final total =
          lastDay.add(const Duration(days: 1)).difference(firstDay).inMinutes;
      final elapsed = now.difference(firstDay).inMinutes;
      progress = (elapsed / total).clamp(0.0, 1.0);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('📅 원정 일정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (isAdmin)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(
                  child: Text('빈 칸 탭 = 일정 추가',
                      style: TextStyle(fontSize: 11, color: Colors.blue))),
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.blue),
              onPressed: () => _showManageDaysDialog(context, scheduleProvider),
              tooltip: '일자 관리',
            ),
        ],
      ),
      body: dates.isEmpty
          ? _buildEmptyState()
          : LayoutBuilder(
              builder: (context, constraints) {
                // 화면에 다 들어가면 균등 분할, 아니면 84px씩 가로 스크롤
                final colWidth = math.max(
                    84.0, (constraints.maxWidth - _axisWidth) / dates.length);
                final gridWidth = colWidth * dates.length;

                return Column(
                  children: [
                    // ── 진행률 (날짜 헤더 위): 원정 전체 + 오늘 하루(07~24시)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: Column(
                        children: [
                          if (progress != null)
                            _progressRow('원정 진행률', progress,
                                barColor: Colors.blue[700]!),
                          if (progress != null) const SizedBox(height: 5),
                          _progressRow(
                            '오늘 진행률',
                            ((nowMinutes - 7 * 60) / (24 * 60 - 7 * 60))
                                .clamp(0.0, 1.0),
                            barColor: Colors.teal[600]!,
                          ),
                        ],
                      ),
                    ),

                    // ── 일차 헤더 행 (세로 스크롤과 무관하게 고정)
                    SizedBox(
                      height: _headerHeight,
                      child: Row(
                        children: [
                          const SizedBox(width: _axisWidth),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _headerHScroll,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: gridWidth,
                                child: Row(
                                  children: [
                                    for (final day in dates)
                                      Container(
                                        width: colWidth,
                                        padding:
                                            const EdgeInsets.symmetric(horizontal: 2),
                                        decoration: BoxDecoration(
                                          border: Border(
                                              left: BorderSide(
                                                  color: Colors.grey[200]!)),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              day['date']!.split(' ').first,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              day['title']!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 9.5,
                                                  color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // ── 시간축 + 그리드
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _vScroll,
                        child: SizedBox(
                          height: 24 * _hourHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 시간축 (00~24)
                              SizedBox(
                                width: _axisWidth,
                                height: 24 * _hourHeight,
                                child: Stack(
                                  children: [
                                    for (var h = 1; h < 24; h++)
                                      Positioned(
                                        top: h * _hourHeight - 7,
                                        right: 6,
                                        child: Text(
                                          '${h.toString().padLeft(2, '0')}:00',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500]),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // 그리드
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: _bodyHScroll,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: gridWidth,
                                    height: 24 * _hourHeight,
                                    child: Stack(
                                      children: [
                                        // 시간 격자선
                                        for (var h = 0; h <= 24; h++)
                                          Positioned(
                                            top: math.min(
                                                h * _hourHeight, 24 * _hourHeight - 1),
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                                height: 0.7,
                                                color: Colors.grey[200]),
                                          ),
                                        // 일차 열
                                        for (var i = 0; i < dates.length; i++)
                                          Positioned(
                                            left: i * colWidth,
                                            top: 0,
                                            width: colWidth,
                                            height: 24 * _hourHeight,
                                            child: Builder(builder: (context) {
                                              final colDate = _dateOfDay(
                                                  dates[i]['id']!, year);
                                              // -1: 지난 날, 0: 오늘, 1: 미래/모름
                                              var dayStatus = 1;
                                              if (colDate != null) {
                                                if (colDate.isBefore(today)) {
                                                  dayStatus = -1;
                                                } else if (colDate
                                                    .isAtSameMomentAs(today)) {
                                                  dayStatus = 0;
                                                }
                                              }
                                              return _buildDayColumn(
                                                context,
                                                scheduleProvider,
                                                isAdmin,
                                                dates[i],
                                                schedulesById[dates[i]['id']],
                                                dayStatus: dayStatus,
                                                nowMinutes: nowMinutes,
                                              );
                                            }),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// 얇은 진행률 한 줄 (라벨 + 바 + %)
  Widget _progressRow(String label, double value, {required Color barColor}) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                  value >= 1.0 ? Colors.green : barColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text('${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('설정된 일자가 없습니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- 일차 열

  Widget _buildDayColumn(
    BuildContext context,
    ScheduleProvider scheduleProvider,
    bool isAdmin,
    Map<String, String> day,
    DailySchedule? schedule, {
    int dayStatus = 1, // -1: 지난 날, 0: 오늘, 1: 미래/모름
    int nowMinutes = 0,
  }) {
    final dayId = day['id']!;
    final items = schedule?.items ?? const <ScheduleItem>[];

    final children = <Widget>[
      // 열 왼쪽 경계선
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.grey[200]!)),
          ),
        ),
      ),
      // 💡 빈 칸 탭 → 그 시간으로 일정 추가 (관리자)
      if (isAdmin)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final minutes = (details.localPosition.dy / _hourHeight * 60).round();
              final rounded = (minutes / 30).round() * 30; // 30분 단위 반올림
              final clamped = rounded.clamp(0, 23 * 60 + 30);
              final preset =
                  '${(clamped ~/ 60).toString().padLeft(2, '0')}:${(clamped % 60).toString().padLeft(2, '0')}';
              _showItemDialog(context, scheduleProvider, isAdmin,
                  dayId: dayId, presetTime: preset);
            },
          ),
        ),
    ];

    // 일정 블록 배치
    var unparsedCount = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final start = _parseMinutes(item.time);

      double top;
      double height;
      final bool timeless = start == null;
      var durationMinutes = 60;

      if (timeless) {
        // 시간 미정 항목은 열 상단에 쌓는다
        top = 2.0 + unparsedCount * 24;
        height = 22;
        unparsedCount++;
      } else {
        top = start / 60.0 * _hourHeight;
        // 다음 시간 파싱 가능한 항목까지가 이 일정의 '길이'
        int? next;
        for (var j = i + 1; j < items.length; j++) {
          final t = _parseMinutes(items[j].time);
          if (t != null && t > start) {
            next = t;
            break;
          }
        }
        durationMinutes = next != null ? next - start : 60;
        height = (durationMinutes / 60.0 * _hourHeight)
            .clamp(20.0, 24 * _hourHeight - top);
      }

      // 💡 완료된 일정: 지난 날 전체, 오늘은 끝난 시각이 현재보다 이전인 것
      final bool completed = dayStatus == -1 ||
          (dayStatus == 0 && !timeless && start + durationMinutes <= nowMinutes);

      children.add(Positioned(
        top: top,
        left: 2,
        right: 2.5,
        height: height,
        child: GestureDetector(
          onTap: () => isAdmin
              ? _showItemDialog(context, scheduleProvider, isAdmin,
                  dayId: dayId, item: item, index: i)
              : _showItemDetail(context, day['date']!.split(' ').first, item),
          child: Builder(builder: (context) {
            // 💡 항목별 색상 (미지정: 파랑, 시간 미정 항목은 주황)
            //    완료된 일정은 색을 빼고 회색으로 가라앉힌다.
            var accent = kItemColors[item.color] ??
                (timeless ? Colors.orange[400]! : Colors.blue[800]!);
            if (completed) accent = Colors.grey[400]!;
            return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Color.alphaBlend(accent.withAlpha(26), Colors.white),
              borderRadius: BorderRadius.circular(5),
              border: Border(
                left: BorderSide(color: accent, width: 2.5),
              ),
            ),
            child: Text(
              item.description,
              maxLines: math.max(1, (height - 6) ~/ 13),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: completed ? Colors.grey[500] : Colors.blueGrey[800],
              ),
            ),
          );
          }),
        ),
      ));
    }

    // 💡 오늘 열: 현재 시각 위치에 얇은 회색선 (1분마다 갱신)
    if (dayStatus == 0) {
      final nowTop = nowMinutes / 60.0 * _hourHeight;
      children.add(Positioned(
        top: nowTop - 3,
        left: 0,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey[600],
            shape: BoxShape.circle,
          ),
        ),
      ));
      children.add(Positioned(
        top: nowTop - 0.75,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Container(height: 1.5, color: Colors.grey[600]),
        ),
      ));
    }

    return Stack(children: children);
  }
}
