import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/buddy_model.dart';
import '../models/equipment_model.dart';
import '../providers/buddy_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/schedule_provider.dart';

const List<String> _gearKeys = [
  '가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타'
];

const Color _teamColor = Color(0xFF00796B);
const Color _teamSoft = Color(0xFFDCEFEC);
const Color _okColor = Color(0xFF2E7D32);
const Color _okSoft = Color(0xFFE5F2E6);
const Color _badColor = Color(0xFFD14842);
const Color _badSoft = Color(0xFFFBE8E7);

/// 버디 조 단위로 묶인 대원 묶음.
class _MemberGroup {
  final String label; // 좌측 고정열에 들어갈 짧은 이름 (예: 1탱크 A)
  final String caption; // 우측 밴드에 들어갈 부가 정보
  final List<MemberEquipment> members;

  const _MemberGroup({required this.label, required this.caption, required this.members});
}

/// 💡 v2: 장비 '목록'과 '체크'를 한 화면의 두 모드로 통합.
///  - 보기 모드: 장비 번호 + O/X 체크 (O/X 탭하여 토글)
///  - 수정 모드: O/X 행이 사라지고 장비 번호를 직접 편집
class EquipmentCheckScreen extends StatefulWidget {
  const EquipmentCheckScreen({super.key});

  @override
  State<EquipmentCheckScreen> createState() => _EquipmentCheckScreenState();
}

class _EquipmentCheckScreenState extends State<EquipmentCheckScreen> {
  int _selectedDayIndex = 0;
  bool _isEditMode = false;

  /// 수정 모드 진입 시 만들어지는 편집용 사본 (id -> 사본)
  final Map<String, MemberEquipment> _editing = {};

  final ScrollController _headerHController = ScrollController();
  final ScrollController _bodyHController = ScrollController();

  static const double nameWidth = 72.0;
  static const double colWidth = 56.0;
  static const double headerHeight = 38.0;
  static const double groupHeight = 34.0;
  static const double valueHeight = 32.0;
  static const double statusHeight = 26.0;

  double get _gearsWidth => _gearKeys.length * colWidth;
  double get _memberHeight => valueHeight + (_isEditMode ? 0 : statusHeight);

  @override
  void initState() {
    super.initState();
    _headerHController.addListener(() {
      if (_bodyHController.hasClients && _bodyHController.offset != _headerHController.offset) {
        _bodyHController.jumpTo(_headerHController.offset);
      }
    });
    _bodyHController.addListener(() {
      if (_headerHController.hasClients && _headerHController.offset != _bodyHController.offset) {
        _headerHController.jumpTo(_bodyHController.offset);
      }
    });
  }

  @override
  void dispose() {
    _headerHController.dispose();
    _bodyHController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 그룹 구성

  MemberEquipment? _findByName(List<MemberEquipment> data, String name) {
    final target = name.trim();
    if (target.isEmpty) return null;
    for (final m in data) {
      if (m.name.trim() == target) return m;
    }
    return null;
  }

  /// 버디 편성표 순서대로 대원을 묶고, 편성에 없는 대원은 '미배정'으로 모은다.
  List<_MemberGroup> _buildGroups(BuddyDay day, List<MemberEquipment> data) {
    final used = <String>{};
    final groups = <_MemberGroup>[];

    for (final tank in day.tanks) {
      final teams = <MapEntry<String, BuddyTeam>>[
        MapEntry('A', tank.teamA),
        MapEntry('B', tank.teamB),
      ];
      for (final entry in teams) {
        final team = entry.value;
        final names = <String>[team.leader, ...team.members];
        final members = <MemberEquipment>[];

        for (final name in names) {
          final found = _findByName(data, name);
          if (found != null && used.add(found.id)) members.add(found);
        }
        if (members.isEmpty) continue;

        final tankLabel = tank.tankName.isEmpty ? '탱크' : tank.tankName;
        groups.add(_MemberGroup(
          label: '$tankLabel ${entry.key}',
          caption: team.leader.trim().isEmpty ? '리더 미지정' : '리더 ${team.leader.trim()}',
          members: members,
        ));
      }
    }

    final rest = data.where((m) => !used.contains(m.id)).toList();
    if (rest.isNotEmpty) {
      groups.add(_MemberGroup(label: '미배정', caption: '버디 편성에 없는 대원', members: rest));
    }
    return groups;
  }

  /// 그룹의 체크 완료 개수 / 전체 개수
  String _groupScore(_MemberGroup group) {
    int done = 0;
    for (final m in group.members) {
      for (final k in _gearKeys) {
        if (m.gears[k]?.checked ?? false) done++;
      }
    }
    return '$done/${group.members.length * _gearKeys.length}';
  }

  // ---------------------------------------------------------------- 모드 전환

  void _enterEditMode(EquipmentProvider provider) {
    setState(() {
      _isEditMode = true;
      _editing
        ..clear()
        ..addEntries(provider.data.map((m) => MapEntry(m.id, m.copy())));
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _editing.clear();
    });
  }

  Future<void> _saveEdits(EquipmentProvider provider) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    await provider.saveBulkChanges(_editing.values.toList());
    if (mounted) _exitEditMode();
  }

  void _showResetDialog(EquipmentProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('체크 초기화'),
        content: const Text('모든 대원의 장비 체크를 미완료(X)로 되돌립니다.\n출발 전 / 복귀 시 체크를 새로 시작할 때 사용하세요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              provider.resetAllChecks();
              Navigator.pop(context);
            },
            child: const Text('초기화', style: TextStyle(color: _badColor)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EquipmentProvider>();
    final buddyProvider = context.watch<BuddyProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    final dates = scheduleProvider.dates;
    if (dates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('장비 체크')),
        body: const Center(child: Text('일정 정보를 먼저 등록해주세요.')),
      );
    }

    final dayIndex = _selectedDayIndex.clamp(0, dates.length - 1);
    final dayInfo = dates[dayIndex];
    final buddyDay = buddyProvider.getDayOrDefault(
      dayInfo['id']!,
      '${dayInfo['title']}-${dayInfo['date']}',
    );
    final groups = _buildGroups(buddyDay, provider.data);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditMode ? '장비 목록 수정' : '장비 체크',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: _buildActions(provider),
      ),
      body: Column(
        children: [
          _buildDayTabs(dates, dayIndex),
          if (_isEditMode) _buildEditBanner(),
          _buildHeader(),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: groups.isEmpty
                ? const Center(child: Text('표시할 대원이 없습니다.', style: TextStyle(color: Colors.grey)))
                : SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFixedColumn(groups),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _bodyHController,
                            scrollDirection: Axis.horizontal,
                            child: _buildScrollableColumn(groups, provider),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(EquipmentProvider provider) {
    if (!provider.isAdmin) return const [];

    if (_isEditMode) {
      return [
        TextButton(onPressed: _exitEditMode, child: const Text('취소', style: TextStyle(color: _badColor))),
        TextButton(
          onPressed: () => _saveEdits(provider),
          child: const Text('완료', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
      ];
    }
    return [
      IconButton(
        tooltip: '체크 초기화',
        icon: const Icon(Icons.refresh, color: Colors.blueGrey, size: 20),
        onPressed: () => _showResetDialog(provider),
      ),
      TextButton(
        onPressed: () => _enterEditMode(provider),
        child: const Text('수정', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
      ),
    ];
  }

  Widget _buildEditBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFF0F8FF),
      child: const Text(
        '수정 모드 · 장비 번호를 직접 입력하세요. 체크(O/X)는 완료 후 다시 표시됩니다.',
        style: TextStyle(fontSize: 11, color: Colors.blue),
      ),
    );
  }

  Widget _buildDayTabs(List<Map<String, String>> dates, int dayIndex) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final isSelected = dayIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isSelected ? Colors.blue : Colors.transparent, width: 2.5),
                ),
              ),
              child: Text(
                dates[index]['title'] ?? '',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isSelected ? Colors.blue[800] : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: headerHeight,
      color: const Color(0xFFF8F9FA),
      child: Row(
        children: [
          Container(
            width: nameWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[400]!)),
            ),
            child: const Text('이름', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _headerHController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _gearKeys
                    .map((k) => Container(
                          width: colWidth,
                          height: headerHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: Colors.grey[300]!)),
                          ),
                          child: Text(k,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 행 구분선. 좌/우 영역이 정확히 같은 높이를 갖도록 양쪽에 동일하게 넣는다.
  Widget _separator(double width) => Container(width: width, height: 0.5, color: Colors.grey[300]);

  /// 좌측 고정열: 그룹 라벨 + 대원 이름
  Widget _buildFixedColumn(List<_MemberGroup> groups) {
    final cells = <Widget>[];

    for (final group in groups) {
      cells.add(Container(
        width: nameWidth,
        height: groupHeight,
        alignment: Alignment.center,
        color: _teamSoft,
        child: Text(
          group.label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _teamColor),
        ),
      ));
      cells.add(_separator(nameWidth));

      for (final member in group.members) {
        cells.add(SizedBox(
          width: nameWidth,
          height: _memberHeight,
          child: Center(
            child: Text(
              member.name.isEmpty ? '-' : member.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ));
        cells.add(_separator(nameWidth));
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[400]!)),
      ),
      child: Column(children: cells),
    );
  }

  /// 우측 스크롤 영역: 그룹 밴드 + 장비 번호행(+ 보기 모드일 때 O/X행)
  Widget _buildScrollableColumn(List<_MemberGroup> groups, EquipmentProvider provider) {
    final rows = <Widget>[];

    for (final group in groups) {
      rows.add(Container(
        width: _gearsWidth,
        height: groupHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        color: _teamSoft,
        child: Row(
          children: [
            Text(group.caption,
                style: const TextStyle(fontSize: 11, color: _teamColor, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (!_isEditMode)
              Text(_groupScore(group),
                  style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)),
          ],
        ),
      ));
      rows.add(_separator(_gearsWidth));

      for (final member in group.members) {
        rows.add(_buildMemberRows(member, provider));
        rows.add(_separator(_gearsWidth));
      }
    }

    return Column(children: rows);
  }

  Widget _buildMemberRows(MemberEquipment member, EquipmentProvider provider) {
    final editable = _isEditMode ? _editing[member.id] : null;

    return SizedBox(
      width: _gearsWidth,
      height: _memberHeight,
      child: Column(
        children: [
          // 장비 번호 행 (수정 모드에서는 입력 가능)
          Row(
            children: _gearKeys.map((key) {
              final value = (editable ?? member).gears[key]?.value ?? '';
              return Container(
                width: colWidth,
                height: valueHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isEditMode ? const Color(0xFFF0F8FF) : Colors.transparent,
                  border: Border(right: BorderSide(color: Colors.grey[200]!)),
                ),
                child: _isEditMode
                    ? _GearValueField(
                        key: ValueKey('${member.id}-$key'),
                        initialValue: value,
                        onChanged: (v) => editable?.gears[key]?.value = v,
                      )
                    : Text(value.isEmpty ? '-' : value,
                        style: const TextStyle(fontSize: 11, color: Colors.black87)),
              );
            }).toList(),
          ),

          // O/X 행 (수정 모드에서는 숨김)
          if (!_isEditMode)
            Row(
              children: _gearKeys.map((key) {
                final checked = member.gears[key]?.checked ?? false;
                return GestureDetector(
                  onTap: () => _handleToggle(provider, member.id, key),
                  child: Container(
                    width: colWidth,
                    height: statusHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: checked ? _okSoft : _badSoft,
                      border: Border(right: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Text(
                      checked ? 'O' : 'X',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: checked ? _okColor : _badColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _handleToggle(EquipmentProvider provider, String memberId, String key) {
    if (!provider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자만 체크할 수 있습니다.'), duration: Duration(seconds: 1)),
      );
      return;
    }
    provider.toggleCheck(memberId, key);
  }
}

/// 수정 모드에서 장비 번호를 입력하는 셀.
class _GearValueField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _GearValueField({super.key, required this.initialValue, required this.onChanged});

  @override
  State<_GearValueField> createState() => _GearValueFieldState();
}

class _GearValueFieldState extends State<_GearValueField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: '-',
      ),
      onChanged: (v) => widget.onChanged(v.trim()),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }
}
