import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/member_provider.dart';
import '../providers/buddy_provider.dart';
import '../models/buddy_model.dart';
import '../models/member_model.dart'; // MemberItem 타입을 명시적으로 사용하기 위해 추가

class BuddyScreen extends StatefulWidget {
  const BuddyScreen({super.key});

  @override
  State<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends State<BuddyScreen> {
  int _selectedDateIndex = 0;
  bool _isEditMode = false;

  // 편집을 위한 선택 상태
  int? _selectedTankIdx; // 0: 1탱크, 1: 2탱크
  String? _selectedTeam; // 'A' or 'B'
  int? _selectedSlotIdx; // -1: 리더, 0~7: 멤버

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = Provider.of<ScheduleProvider>(context);
    final memberProvider = Provider.of<MemberProvider>(context);
    final buddyProvider = Provider.of<BuddyProvider>(context);
    final auth = Provider.of<EquipmentProvider>(context);

    if (scheduleProvider.dates.isEmpty) {
      return const Scaffold(body: Center(child: Text('일정 정보를 먼저 등록해주세요.')));
    }

    final currentDayInfo = scheduleProvider.dates[_selectedDateIndex];
    final dayId = currentDayInfo['id']!;
    final dayTitle = "${currentDayInfo['title']}-${currentDayInfo['date']}";

    // 💡 8명의 멤버 공간을 보장하도록 가져옵니다.
    final buddyData = buddyProvider.getDayOrDefault(dayId, dayTitle);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('🤝 버디 시스템', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (auth.isAdmin)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                  // 편집 모드 종료 시 선택 상태 초기화
                  if (!_isEditMode) {
                    _selectedTankIdx = null;
                    _selectedTeam = null;
                    _selectedSlotIdx = null;
                  }
                });
              },
              child: Text(_isEditMode ? '수정 완료' : '수정하기',
                  style: TextStyle(color: _isEditMode ? Colors.blue : Colors.grey[700], fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildDayTabs(scheduleProvider),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border.all(color: Colors.black, width: 1.5)
                    ),
                    child: Text(dayTitle, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _buildBuddyTable(buddyData, buddyProvider),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isEditMode) _buildMemberPicker(memberProvider, buddyData, buddyProvider),
        ],
      ),
    );
  }

  Widget _buildDayTabs(ScheduleProvider provider) {
    return Container(
      height: 50,
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.dates.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedDateIndex == index;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedDateIndex = index;
              _selectedTankIdx = null;
              _selectedTeam = null;
              _selectedSlotIdx = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isSelected ? Colors.blue : Colors.transparent, width: 3)),
              ),
              child: Text(provider.dates[index]['title']!,
                  style: TextStyle(color: isSelected ? Colors.blue : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBuddyTable(BuddyDay data, BuddyProvider provider) {
    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: const {
        0: FixedColumnWidth(55),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        const TableRow(
          children: [
            SizedBox(),
            TableCell(child: Center(child: Padding(padding: EdgeInsets.all(6), child: Text('A팀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))),
            TableCell(child: Center(child: Padding(padding: EdgeInsets.all(6), child: Text('B팀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))),
          ],
        ),
        ..._buildTankRows(0, data, provider),
        ..._buildTankRows(1, data, provider),
      ],
    );
  }

  List<TableRow> _buildTankRows(int tankIdx, BuddyDay data, BuddyProvider provider) {
    final tank = data.tanks[tankIdx];

    return [
      TableRow(
        children: [
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Center(child: Text(tank.tankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ),
          _buildEditableCell(tankIdx, 'A', -1, tank.teamA.leader, isLeader: true),
          _buildEditableCell(tankIdx, 'B', -1, tank.teamB.leader, isLeader: true),
        ],
      ),
      // 💡 2열씩 4줄 = 총 8명 공간 생성
      for (int i = 0; i < 4; i++)
        TableRow(
          children: [
            const SizedBox(),
            _buildMemberGridCell(tankIdx, 'A', i * 2, tank.teamA.members),
            _buildMemberGridCell(tankIdx, 'B', i * 2, tank.teamB.members),
          ],
        ),
    ];
  }

  Widget _buildMemberGridCell(int tankIdx, String team, int startIdx, List<String> members) {
    return TableCell(
      child: Row(
        children: [
          Expanded(child: _buildEditableCell(tankIdx, team, startIdx, startIdx < members.length ? members[startIdx] : '')),
          Container(width: 1, height: 35, color: Colors.black),
          Expanded(child: _buildEditableCell(tankIdx, team, startIdx + 1, startIdx + 1 < members.length ? members[startIdx + 1] : '')),
        ],
      ),
    );
  }

  Widget _buildEditableCell(int tankIdx, String team, int slotIdx, String value, {bool isLeader = false}) {
    bool isSelected = _isEditMode && _selectedTankIdx == tankIdx && _selectedTeam == team && _selectedSlotIdx == slotIdx;

    Color bgColor = Colors.white;
    if (isLeader) {
      bgColor = team == 'A' ? const Color(0xFFE3F2FD) : const Color(0xFFFFFDE7);
    }
    if (isSelected) bgColor = Colors.blue[200]!;

    return GestureDetector(
      // 💡 behavior를 opaque로 설정하여 빈칸 터치 문제를 해결합니다.
      behavior: HitTestBehavior.opaque,
      onTap: _isEditMode ? () {
        setState(() {
          _selectedTankIdx = tankIdx;
          _selectedTeam = team;
          _selectedSlotIdx = slotIdx;
        });
      } : null,
      child: Container(
        height: 35,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
        ),
        child: Text(
            value,
            style: TextStyle(
                fontSize: isLeader ? 13 : 12,
                fontWeight: isLeader ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87
            )
        ),
      ),
    );
  }

  Widget _buildMemberPicker(MemberProvider memberProvider, BuddyDay dayData, BuddyProvider buddyProvider) {
    // 💡 화면 표시를 위해 이름 순으로 정렬된 리스트 생성
    final List<MemberItem> sortedMembers = List.from(memberProvider.members);
    sortedMembers.sort((a, b) => a.name.compareTo(b.name));

    Set<String> assignedInCurrentTank = {};
    if (_selectedTankIdx != null) {
      final tank = dayData.tanks[_selectedTankIdx!];
      assignedInCurrentTank.add(tank.teamA.leader);
      assignedInCurrentTank.addAll(tank.teamA.members.where((m) => m.isNotEmpty));
      assignedInCurrentTank.add(tank.teamB.leader);
      assignedInCurrentTank.addAll(tank.teamB.members.where((m) => m.isNotEmpty));
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('대원 선택 (이름 순)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
              if (_selectedTankIdx != null)
                Text('${_selectedTankIdx! + 1}탱크 ${_selectedTeam}팀 수정 중', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, childAspectRatio: 2.8, mainAxisSpacing: 6, crossAxisSpacing: 6
              ),
              itemCount: sortedMembers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildPickerItem('❌ 비우기', false, () => _assignMember('', dayData, buddyProvider));

                final member = sortedMembers[index - 1];
                bool isAssigned = assignedInCurrentTank.contains(member.name);

                return _buildPickerItem(member.name, isAssigned, () {
                  if (isAssigned) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${member.name}님은 이미 해당 탱크에 배치되어 있습니다.'), duration: const Duration(seconds: 1))
                    );
                    return;
                  }
                  _assignMember(member.name, dayData, buddyProvider);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerItem(String name, bool isGray, VoidCallback onTap) {
    return Material(
      color: isGray ? Colors.grey[100] : Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: isGray ? Colors.grey[200]! : Colors.blue[100]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
              name,
              style: TextStyle(
                  fontSize: 12,
                  color: isGray ? Colors.grey[400] : Colors.black87,
                  fontWeight: isGray ? FontWeight.normal : FontWeight.w500
              )
          ),
        ),
      ),
    );
  }

  void _assignMember(String name, BuddyDay dayData, BuddyProvider provider) {
    if (_selectedTankIdx == null || _selectedTeam == null || _selectedSlotIdx == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정할 칸을 먼저 선택해주세요.')));
      return;
    }

    final tank = dayData.tanks[_selectedTankIdx!];
    final team = _selectedTeam == 'A' ? tank.teamA : tank.teamB;

    if (_selectedSlotIdx == -1) {
      final newTeam = BuddyTeam(leader: name, members: team.members);
      _updateTank(dayData, _selectedTankIdx!, _selectedTeam!, newTeam, provider);
    } else {
      List<String> newMembers = List.from(team.members);
      // 리스트 크기 보장
      while (newMembers.length <= _selectedSlotIdx!) {
        newMembers.add('');
      }
      newMembers[_selectedSlotIdx!] = name;
      final newTeam = BuddyTeam(leader: team.leader, members: newMembers);
      _updateTank(dayData, _selectedTankIdx!, _selectedTeam!, newTeam, provider);
    }
  }

  void _updateTank(BuddyDay day, int tankIdx, String teamName, BuddyTeam newTeam, BuddyProvider provider) {
    List<BuddyTank> newTanks = List.from(day.tanks);
    final oldTank = newTanks[tankIdx];

    newTanks[tankIdx] = BuddyTank(
      tankName: oldTank.tankName,
      teamA: teamName == 'A' ? newTeam : oldTank.teamA,
      teamB: teamName == 'B' ? newTeam : oldTank.teamB,
    );

    final updatedDay = BuddyDay(id: day.id, title: day.title, tanks: newTanks);
    provider.saveBuddyDay(updatedDay);
  }
}