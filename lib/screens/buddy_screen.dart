import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/member_provider.dart';
import '../providers/participant_provider.dart';
import '../providers/buddy_provider.dart';
import '../models/buddy_model.dart';
import '../models/member_model.dart';

const Color _blockHeaderColor = Color(0xFF455A64);
const Color _leaderTint = Color(0xFFFFF8E1);

/// 💡 v2: 블록(조) > 팀 > 대원 구조의 다이빙 버디 편성.
/// 조/팀은 수정 모드에서 자유롭게 추가·삭제하고, 조마다 그날의 입수 방식
/// (동시/로테이션)을 정하면 장비버디 충돌 검사 범위가 그에 맞춰 바뀐다.
class BuddyScreen extends StatefulWidget {
  const BuddyScreen({super.key});

  @override
  State<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends State<BuddyScreen> {
  int _selectedDateIndex = 0;
  bool _isEditMode = false;

  // 편집을 위한 선택 상태
  int? _selBlockIdx;
  int? _selTeamIdx;
  int? _selSlotIdx; // -1: 리더, 0~: 멤버 칸

  /// 조 추가/이름변경 다이얼로그의 입력 컨트롤러.
  /// 💡 다이얼로그 안에서 만들고 whenComplete로 dispose하면 닫힘 애니메이션 중
  ///    살아있는 TextField가 죽은 컨트롤러를 참조해 크래시가 난다. State가 소유한다.
  final TextEditingController _blockNameController = TextEditingController();

  @override
  void dispose() {
    _blockNameController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    _selBlockIdx = null;
    _selTeamIdx = null;
    _selSlotIdx = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = Provider.of<ScheduleProvider>(context);
    final memberProvider = Provider.of<MemberProvider>(context);
    final buddyProvider = Provider.of<BuddyProvider>(context);
    final auth = Provider.of<EquipmentProvider>(context);

    if (scheduleProvider.dates.isEmpty) {
      return const Scaffold(body: Center(child: Text('일정 정보를 먼저 등록해주세요.')));
    }

    final dateIndex = _selectedDateIndex.clamp(0, scheduleProvider.dates.length - 1);
    final currentDayInfo = scheduleProvider.dates[dateIndex];
    final dayId = currentDayInfo['id']!;
    final dayTitle = "${currentDayInfo['title']}-${currentDayInfo['date']}";

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
                  if (!_isEditMode) _clearSelection();
                });
              },
              child: Text(_isEditMode ? '수정 완료' : '수정하기',
                  style: TextStyle(
                      color: _isEditMode ? Colors.blue : Colors.grey[700],
                      fontWeight: FontWeight.bold)),
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
                        border: Border.all(color: Colors.black, width: 1.5)),
                    child: Text(dayTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),

                  if (buddyData.blocks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text(
                        _isEditMode
                            ? '아래 [조 추가]로 편성을 시작하세요.'
                            : '이 날의 버디 편성이 아직 없습니다.',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),

                  for (var b = 0; b < buddyData.blocks.length; b++)
                    _buildBlock(b, buddyData, buddyProvider),

                  if (_isEditMode)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _addBlockDialog(buddyData, buddyProvider),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('조 추가', style: TextStyle(fontSize: 13)),
                      ),
                    ),
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
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.dates.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedDateIndex == index;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedDateIndex = index;
              _clearSelection();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: isSelected ? Colors.blue : Colors.transparent, width: 3)),
              ),
              child: Text(provider.dates[index]['title']!,
                  style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- 블록 표

  Widget _buildBlock(int blockIdx, BuddyDay day, BuddyProvider provider) {
    final block = day.blocks[blockIdx];
    final showLeaderRow = _isEditMode || block.teams.any((t) => t.leader.isNotEmpty);

    // 💡 팀별 표시 슬롯: 2열 그리드에 맞춰 짝수. 수정 모드면 빈 칸을 하나 더 열어둔다.
    int slotsOf(BuddyTeam t) {
      var n = t.members.length + (_isEditMode ? 1 : 0);
      if (n.isOdd) n++;
      return math.max(n, 2);
    }

    final maxSlots =
        block.teams.isEmpty ? 0 : block.teams.map(slotsOf).reduce(math.max);
    final rowCount = maxSlots ~/ 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          // --- 조 헤더 ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 36,
            color: _blockHeaderColor,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isEditMode
                        ? () => _renameBlockDialog(block, day, provider)
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            block.name.isEmpty ? '(이름 없음)' : block.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        if (_isEditMode) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 12, color: Colors.white54),
                        ],
                      ],
                    ),
                  ),
                ),
                // 입수 방식 (수정 모드에서 탭하면 전환)
                GestureDetector(
                  onTap: _isEditMode
                      ? () {
                          block.simultaneous = !block.simultaneous;
                          provider.saveBuddyDay(day);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: block.simultaneous ? Colors.orange[300] : Colors.teal[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      block.simultaneous ? '동시 입수' : '로테이션',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                if (_isEditMode) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    tooltip: '팀 추가',
                    icon: const Icon(Icons.playlist_add, size: 18, color: Colors.white),
                    onPressed: () => _addTeam(block, day, provider),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    tooltip: '조 삭제',
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white70),
                    onPressed: () => _deleteBlockDialog(blockIdx, day, provider),
                  ),
                ],
              ],
            ),
          ),

          if (block.teams.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Colors.black)),
              child: Text(
                _isEditMode ? '헤더의 + 버튼으로 팀을 추가하세요.' : '팀이 없습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            Table(
              border: TableBorder.all(color: Colors.black, width: 1),
              children: [
                // 팀 이름 행
                TableRow(
                  children: [
                    for (var t = 0; t < block.teams.length; t++)
                      TableCell(
                        child: Container(
                          height: 30,
                          color: Colors.grey[100],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(block.teams[t].name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                              if (_isEditMode)
                                GestureDetector(
                                  onTap: () => _deleteTeamDialog(blockIdx, t, day, provider),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(Icons.close, size: 13, color: Colors.redAccent),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // 리더(강사) 행
                if (showLeaderRow)
                  TableRow(
                    children: [
                      for (var t = 0; t < block.teams.length; t++)
                        _buildCell(blockIdx, t, -1, block.teams[t].leader, isLeader: true),
                    ],
                  ),
                // 멤버 행 (2열 그리드)
                for (var r = 0; r < rowCount; r++)
                  TableRow(
                    children: [
                      for (var t = 0; t < block.teams.length; t++)
                        TableCell(
                          child: Row(
                            children: [
                              Expanded(
                                  child: _buildCell(blockIdx, t, r * 2,
                                      _memberAt(block.teams[t], r * 2))),
                              Container(width: 1, height: 35, color: Colors.black),
                              Expanded(
                                  child: _buildCell(blockIdx, t, r * 2 + 1,
                                      _memberAt(block.teams[t], r * 2 + 1))),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _memberAt(BuddyTeam team, int index) =>
      index < team.members.length ? team.members[index] : '';

  Widget _buildCell(int blockIdx, int teamIdx, int slotIdx, String value,
      {bool isLeader = false}) {
    bool isSelected = _isEditMode &&
        _selBlockIdx == blockIdx &&
        _selTeamIdx == teamIdx &&
        _selSlotIdx == slotIdx;

    Color bgColor = isLeader ? _leaderTint : Colors.white;
    if (isSelected) bgColor = Colors.blue[200]!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isEditMode
          ? () {
              setState(() {
                _selBlockIdx = blockIdx;
                _selTeamIdx = teamIdx;
                _selSlotIdx = slotIdx;
              });
            }
          : null,
      child: Container(
        height: 35,
        alignment: Alignment.center,
        color: bgColor,
        child: Text(
          isLeader && value.isEmpty && _isEditMode ? '리더/강사' : value,
          style: TextStyle(
            fontSize: isLeader ? 13 : 12,
            fontWeight: isLeader ? FontWeight.bold : FontWeight.normal,
            color: isLeader && value.isEmpty ? Colors.grey[400] : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 구조 편집

  /// 전체 팀 수 기준으로 다음 팀 이름을 A, B, C… 순으로 제안
  String _nextTeamName(BuddyDay day) {
    final total = day.blocks.fold<int>(0, (sum, b) => sum + b.teams.length);
    return '${String.fromCharCode(65 + (total % 26))}팀';
  }

  void _addBlockDialog(BuddyDay day, BuddyProvider provider) {
    _blockNameController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('조 추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _blockNameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '조 이름 (예: YB, 교육 1조)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final name = _blockNameController.text.trim();
              if (name.isEmpty) return;
              day.blocks.add(BuddyBlock(
                name: name,
                simultaneous: false,
                teams: [BuddyTeam(name: _nextTeamName(day), leader: '', members: [])],
              ));
              provider.saveBuddyDay(day);
              Navigator.pop(dialogContext);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _renameBlockDialog(BuddyBlock block, BuddyDay day, BuddyProvider provider) {
    _blockNameController.text = block.name;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('조 이름 변경', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _blockNameController,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final name = _blockNameController.text.trim();
              if (name.isEmpty) return;
              block.name = name;
              provider.saveBuddyDay(day);
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _deleteBlockDialog(int blockIdx, BuddyDay day, BuddyProvider provider) {
    final block = day.blocks[blockIdx];
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('조 삭제'),
        content: Text('[${block.name}] 조와 소속 팀 편성을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          TextButton(
            onPressed: () {
              day.blocks.removeAt(blockIdx);
              provider.saveBuddyDay(day);
              setState(_clearSelection);
              Navigator.pop(dialogContext);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addTeam(BuddyBlock block, BuddyDay day, BuddyProvider provider) {
    block.teams.add(BuddyTeam(name: _nextTeamName(day), leader: '', members: []));
    provider.saveBuddyDay(day);
  }

  void _deleteTeamDialog(int blockIdx, int teamIdx, BuddyDay day, BuddyProvider provider) {
    final team = day.blocks[blockIdx].teams[teamIdx];
    final hasMembers = team.leader.isNotEmpty || team.members.any((m) => m.isNotEmpty);

    void doDelete() {
      day.blocks[blockIdx].teams.removeAt(teamIdx);
      provider.saveBuddyDay(day);
      setState(_clearSelection);
    }

    if (!hasMembers) {
      doDelete();
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('팀 삭제'),
        content: Text('[${team.name}]에 배치된 대원이 있습니다. 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          TextButton(
            onPressed: () {
              doDelete();
              Navigator.pop(dialogContext);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 배치

  void _assignMember(String name, BuddyDay day, BuddyProvider provider) {
    if (_selBlockIdx == null || _selTeamIdx == null || _selSlotIdx == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('수정할 칸을 먼저 선택해주세요.')));
      return;
    }
    if (_selBlockIdx! >= day.blocks.length) return;
    final block = day.blocks[_selBlockIdx!];
    if (_selTeamIdx! >= block.teams.length) return;
    final team = block.teams[_selTeamIdx!];

    if (_selSlotIdx == -1) {
      team.leader = name;
    } else {
      while (team.members.length <= _selSlotIdx!) {
        team.members.add('');
      }
      team.members[_selSlotIdx!] = name;
    }
    provider.saveBuddyDay(day);
  }

  // ---------------------------------------------------------------- 픽커

  Widget _buildMemberPicker(
      MemberProvider memberProvider, BuddyDay dayData, BuddyProvider buddyProvider) {
    // 💡 v2: 동아리원 전체가 아니라 '이번 원정 참가자'만 노출한다
    final participantProvider = context.watch<ParticipantProvider>();
    final List<MemberItem> sortedMembers = memberProvider.members
        .where((m) => participantProvider.isParticipant(m.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (sortedMembers.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))
          ],
        ),
        child: const Text(
          '이번 원정 참가자가 없습니다.\n홈 사이드바 [원정 참가자 관리]에서 먼저 등록해주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Colors.grey),
        ),
      );
    }

    // 💡 선택된 조/팀 기준의 검사 범위:
    //  - assignedInBlock: 같은 조 안 중복 배치 방지
    //  - conflictScope: 장비버디 충돌 범위 (동시 입수=조 전체, 로테이션=선택한 팀)
    final assignedInBlock = <String>{};
    var conflictScope = <String>{};
    var selectedBlockSimultaneous = false;

    if (_selBlockIdx != null && _selBlockIdx! < dayData.blocks.length) {
      final block = dayData.blocks[_selBlockIdx!];
      selectedBlockSimultaneous = block.simultaneous;
      for (final t in block.teams) {
        if (t.leader.isNotEmpty) assignedInBlock.add(t.leader);
        assignedInBlock.addAll(t.members.where((m) => m.isNotEmpty));
      }
      if (block.simultaneous) {
        conflictScope = assignedInBlock;
      } else if (_selTeamIdx != null && _selTeamIdx! < block.teams.length) {
        final t = block.teams[_selTeamIdx!];
        conflictScope = {
          if (t.leader.isNotEmpty) t.leader,
          ...t.members.where((m) => m.isNotEmpty),
        };
      }
    }

    // 💡 장비 화면의 데이터(그룹·장비버디)를 가져와 픽커를 구분한다.
    //    장비 행 ID = 동아리원 ID라서 이름이 아닌 ID로 조회한다.
    final equipProvider = context.watch<EquipmentProvider>();
    final gearRows = {for (final r in equipProvider.data) r.id: r};

    String? gearPartnerName(MemberItem m) {
      final row = gearRows[m.id];
      if (row == null || row.pairId.isEmpty) return null;
      for (final r in equipProvider.data) {
        if (r.pairId == row.pairId && r.id != m.id) return r.name;
      }
      return null;
    }

    // 그룹 섹션 구성 (장비 그룹 순서대로, 그룹 없는 참가자는 미지정)
    final byGroup = <String, List<MemberItem>>{};
    for (final m in sortedMembers) {
      byGroup.putIfAbsent(gearRows[m.id]?.groupId ?? '', () => []).add(m);
    }
    final sections = <MapEntry<String, List<MemberItem>>>[];
    for (final g in equipProvider.groups) {
      final members = byGroup.remove(g.id);
      if (members != null) sections.add(MapEntry(g.name, members));
    }
    final rest = byGroup.values.expand((x) => x).toList();
    if (rest.isNotEmpty) sections.add(MapEntry('미지정', rest));

    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('참가자 선택',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 24,
                    child: _buildPickerItem('❌ 비우기', false,
                        () => _assignMember('', dayData, buddyProvider)),
                  ),
                ],
              ),
              if (_selBlockIdx != null && _selBlockIdx! < dayData.blocks.length)
                Text(
                  '${dayData.blocks[_selBlockIdx!].name}'
                  '${_selTeamIdx != null && _selTeamIdx! < dayData.blocks[_selBlockIdx!].teams.length ? ' ${dayData.blocks[_selBlockIdx!].teams[_selTeamIdx!].name}' : ''} 수정 중',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Text(section.key,
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: section.value.map((member) {
                        final isAssigned = assignedInBlock.contains(member.name);
                        final partner = gearPartnerName(member);
                        // 💡 장비버디 짝이 충돌 범위 안에 있으면 선택 불가(회색)
                        final conflict = !isAssigned &&
                            partner != null &&
                            conflictScope.contains(partner);

                        return SizedBox(
                          width: 76,
                          height: 30,
                          child: _buildPickerItem(
                            member.name,
                            isAssigned || conflict,
                            () {
                              if (isAssigned) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('${member.name}님은 이미 이 조에 배치되어 있습니다.'),
                                    duration: const Duration(seconds: 1)));
                                return;
                              }
                              if (conflict) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(selectedBlockSimultaneous
                                        ? '장비버디 $partner님이 같은 조(동시 입수)에 있어 함께 다이빙할 수 없습니다.'
                                        : '장비버디 $partner님이 같은 팀에 있어 함께 다이빙할 수 없습니다.'),
                                    duration: const Duration(seconds: 2)));
                                return;
                              }
                              _assignMember(member.name, dayData, buddyProvider);
                            },
                            isPaired: partner != null,
                            isInstructor: participantProvider.isInstructor(member.id),
                            // 💡 편성 판단에 필요한 대장만 표시 (그 외 직책은 생략)
                            roleEmoji:
                                participantProvider.staffRoleOf(member.id) == 'leader'
                                    ? kStaffRoleEmoji['leader']!
                                    : '',
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerItem(String name, bool isGray, VoidCallback onTap,
      {bool isPaired = false, bool isInstructor = false, String roleEmoji = ''}) {
    return Material(
      color: isGray ? Colors.grey[100] : Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border.all(color: isGray ? Colors.grey[200]! : Colors.blue[100]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 💡 이번 원정의 직책 이모티콘 (대장)
              if (roleEmoji.isNotEmpty) ...[
                Text(roleEmoji,
                    style: TextStyle(
                        fontSize: 9.5, color: isGray ? Colors.grey[300] : null)),
                const SizedBox(width: 2),
              ],
              // 💡 이번 원정의 강사 표시
              if (isInstructor) ...[
                Icon(Icons.star_rounded,
                    size: 11, color: isGray ? Colors.grey[300] : Colors.amber[600]),
                const SizedBox(width: 2),
              ],
              // 💡 장비버디가 있는 대원 표시
              if (isPaired) ...[
                Icon(Icons.link,
                    size: 10, color: isGray ? Colors.grey[300] : const Color(0xFF00796B)),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: isGray ? Colors.grey[400] : Colors.black87,
                      fontWeight: isGray ? FontWeight.normal : FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
