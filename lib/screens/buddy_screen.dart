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

/// 조 이름이 들어가는 왼쪽 라벨 열 폭
const double _blockLabelWidth = 46;
const Color _morningTint = Color(0xFFFFF3E0);
const Color _morningText = Color(0xFFE65100);
const Color _afternoonTint = Color(0xFFE3F2FD);
const Color _afternoonText = Color(0xFF1565C0);

/// 💡 v2: 다이빙 버디 편성. 수정 모드는 4단계 흐름으로 유도한다.
///  1️⃣ 팀 만들기 → 2️⃣ 조 구성 → 3️⃣ 입수 순서 → 4️⃣ 사람 배치
/// 팀·입수 순서가 정해져야 장비버디 충돌 검사가 정확해지기 때문.
class BuddyScreen extends StatefulWidget {
  const BuddyScreen({super.key});

  @override
  State<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends State<BuddyScreen> {
  int _selectedDateIndex = 0;
  bool _isEditMode = false;

  /// 하단 픽커 확장 여부 (끌거나 탭해서 전환)
  bool _pickerExpanded = false;

  // 사람 배치 선택 상태
  int? _selBlockIdx;
  int? _selTeamIdx; // block.teamIds 안에서의 위치
  int? _selSlotIdx; // -1: 리더, 0~: 멤버 칸

  /// 이름 입력 다이얼로그 공용 컨트롤러 (State 소유 — dispose 크래시 방지)
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDayTitleBox(dayTitle, buddyData, buddyProvider),
                  const SizedBox(height: 8),

                  if (_isEditMode) ...[
                    // ── 불러와서 고치는 흐름이 기본이라 맨 위에 둔다
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showImportSheet(
                            buddyData, buddyProvider, scheduleProvider),
                        icon: const Icon(Icons.copy_outlined, size: 15),
                        label: const Text('다른 일차 편성 불러오기',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),

                    // ── 빈 편성이면 템플릿 제안
                    if (buddyData.teams.isEmpty && buddyData.blocks.isEmpty)
                      _buildTemplateButtons(buddyData, buddyProvider),

                    _buildTeamPoolSection(buddyData, buddyProvider),
                    _buildBlockCompositionSection(buddyData, buddyProvider),
                    _buildRoundsSection(buddyData, buddyProvider),
                    _stepHeader('4️⃣ 사람 배치'),
                    if (buddyData.rounds.isEmpty && buddyData.teams.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⚠ 입수 순서(3️⃣)를 먼저 정해야 장비버디 충돌 검사가 정확해집니다.',
                          style: TextStyle(fontSize: 11.5, color: Colors.deepOrange),
                        ),
                      ),
                  ],

                  // ── 보기 모드: 입수 순서 (열 레이아웃이면 헤더가 대신한다)
                  if (!_isEditMode && !_useColumnLayout(buddyData))
                    _buildRoundsSection(buddyData, buddyProvider),

                  // ── 조별 표 (보기: 편성 결과 / 수정: 사람 배치)
                  if (buddyData.blocks.isEmpty && !_isEditMode)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('이 날의 버디 편성이 아직 없습니다.',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                    ),
                  if (_useColumnLayout(buddyData) && buddyData.blocks.isNotEmpty)
                    _buildRoundHeaderRow(buddyData),
                  for (var b = 0; b < buddyData.blocks.length; b++)
                    _useColumnLayout(buddyData)
                        ? _buildBlockRow(b, buddyData, buddyProvider)
                        : _buildBlockTable(b, buddyData, buddyProvider),

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

  // ---------------------------------------------------------------- 공통 UI

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

  Widget _buildDayTitleBox(String dayTitle, BuddyDay day, BuddyProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: Colors.grey[50], border: Border.all(color: Colors.black, width: 1.5)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(dayTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (day.type.isNotEmpty || _isEditMode) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isEditMode
                  ? () {
                      day.type = day.type == 'beach'
                          ? 'boating'
                          : (day.type == 'boating' ? '' : 'beach');
                      provider.saveBuddyDay(day);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: day.type == 'beach'
                      ? Colors.amber[100]
                      : (day.type == 'boating' ? Colors.lightBlue[100] : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  day.type == 'beach' ? '🏖 비치' : (day.type == 'boating' ? '🚤 보팅' : '유형'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 템플릿

  Widget _buildTemplateButtons(BuddyDay day, BuddyProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _applyBeachTemplate(day, provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[600],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('🏖 비치 편성으로 시작\nYB(A·B) + 교육팀(C·D)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, height: 1.4)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _applyBoatingTemplate(day, provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue[600],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('🚤 보팅 편성으로 시작\n혼성 A~D팀',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, height: 1.4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  void _applyBeachTemplate(BuddyDay day, BuddyProvider provider) {
    BuddyTeam newTeam(String letter) => BuddyTeam(
          id: 'team_${DateTime.now().microsecondsSinceEpoch}_$letter',
          name: '$letter팀',
          leader: '',
          members: [],
        );

    final a = newTeam('A');
    final b = newTeam('B');
    final c = newTeam('C');
    final d = newTeam('D');

    day.type = 'beach';
    day.teams.addAll([a, b, c, d]);
    day.blocks.addAll([
      BuddyBlock(name: 'YB', teamIds: [a.id, b.id]),
      BuddyBlock(name: '교육팀', teamIds: [c.id, d.id]),
    ]);
    day.rounds.addAll([
      BuddyRound(name: '오전', teamIds: [a.id, c.id]),
      BuddyRound(name: '오후', teamIds: [b.id, d.id]),
    ]);
    provider.saveBuddyDay(day);
  }

  void _applyBoatingTemplate(BuddyDay day, BuddyProvider provider) {
    BuddyTeam newTeam(String letter) => BuddyTeam(
          id: 'team_${DateTime.now().microsecondsSinceEpoch}_$letter',
          name: '$letter팀',
          leader: '',
          members: [],
        );

    final a = newTeam('A');
    final b = newTeam('B');
    final c = newTeam('C');
    final d = newTeam('D');

    day.type = 'boating';
    day.teams.addAll([a, b, c, d]);
    day.blocks.add(BuddyBlock(name: '보팅 (혼성)', teamIds: [a.id, b.id, c.id, d.id]));
    day.rounds.addAll([
      BuddyRound(name: '오전 1', teamIds: [a.id]),
      BuddyRound(name: '오전 2', teamIds: [a.id]),
      BuddyRound(name: '오후 1', teamIds: [b.id]),
      BuddyRound(name: '오후 2', teamIds: [b.id]),
    ]);
    provider.saveBuddyDay(day);
  }

  // ---------------------------------------------------------------- 1️⃣ 팀

  String _nextTeamName(BuddyDay day) =>
      '${String.fromCharCode(65 + (day.teams.length % 26))}팀';

  Widget _buildTeamPoolSection(BuddyDay day, BuddyProvider provider) {
    final assignedIds = {for (final b in day.blocks) ...b.teamIds};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('1️⃣ 팀 만들기',
            trailing: TextButton.icon(
              onPressed: () {
                day.teams.add(BuddyTeam(
                  id: 'team_${DateTime.now().microsecondsSinceEpoch}',
                  name: _nextTeamName(day),
                  leader: '',
                  members: [],
                ));
                provider.saveBuddyDay(day);
              },
              icon: const Icon(Icons.add, size: 15),
              label: const Text('팀 추가', style: TextStyle(fontSize: 12)),
            )),
        if (day.teams.isEmpty)
          const Text('팀을 추가하세요. (예: A, B, C…)',
              style: TextStyle(fontSize: 12, color: Colors.grey))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: day.teams.map((team) {
              final assigned = assignedIds.contains(team.id);
              return GestureDetector(
                onTap: () => _showNameDialog(
                  title: '팀 이름 변경',
                  initial: team.name,
                  onSave: (name) {
                    team.name = name;
                    provider.saveBuddyDay(day);
                  },
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: assigned ? Colors.grey[100] : Colors.amber[50],
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: assigned ? Colors.grey[300]! : Colors.amber[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(team.name,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      if (!assigned)
                        const Text(' 미배정',
                            style: TextStyle(fontSize: 9.5, color: Colors.orange)),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () => _deleteTeamDialog(team, day, provider),
                        child: const Icon(Icons.close, size: 13, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _deleteTeamDialog(BuddyTeam team, BuddyDay day, BuddyProvider provider) {
    void doDelete() {
      day.teams.removeWhere((t) => t.id == team.id);
      for (final b in day.blocks) {
        b.teamIds.remove(team.id);
      }
      for (final r in day.rounds) {
        r.teamIds.remove(team.id);
      }
      provider.saveBuddyDay(day);
      setState(_clearSelection);
    }

    final hasMembers = team.leader.isNotEmpty ||
        team.leaderBuddy.isNotEmpty ||
        team.members.any((m) => m.isNotEmpty);
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

  // ---------------------------------------------------------------- 2️⃣ 조 구성

  Widget _buildBlockCompositionSection(BuddyDay day, BuddyProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('2️⃣ 조 구성',
            trailing: TextButton.icon(
              onPressed: () => _showNameDialog(
                title: '조 추가',
                hint: '조 이름 (예: YB, 교육팀)',
                onSave: (name) {
                  day.blocks.add(BuddyBlock(name: name, teamIds: []));
                  provider.saveBuddyDay(day);
                },
              ),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('조 추가', style: TextStyle(fontSize: 12)),
            )),
        if (day.blocks.isEmpty)
          const Text('조를 추가하고 팀을 배정하세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey))
        else
          for (var b = 0; b < day.blocks.length; b++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showNameDialog(
                      title: '조 이름 변경',
                      initial: day.blocks[b].name,
                      onSave: (name) {
                        day.blocks[b].name = name;
                        provider.saveBuddyDay(day);
                      },
                    ),
                    child: Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(day.blocks[b].name,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final teamId in day.blocks[b].teamIds)
                          if (day.teamById(teamId) != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(day.teamById(teamId)!.name,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      // 팀을 조에서만 빼고 풀에는 남긴다 (대원 유지)
                                      day.blocks[b].teamIds.remove(teamId);
                                      provider.saveBuddyDay(day);
                                    },
                                    child: const Icon(Icons.close,
                                        size: 12, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                        // 팀 배정 버튼
                        GestureDetector(
                          onTap: () => _showTeamSelectSheet(day, b, provider),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: const Text('+ 팀',
                                style:
                                    TextStyle(fontSize: 11.5, color: Colors.black54)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _deleteBlockDialog(b, day, provider),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6, top: 4),
                      child: Icon(Icons.close, size: 16, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  /// 💡 조에 넣을 팀 선택 바텀시트 — 아직 어느 조에도 없는 팀만 나온다
  void _showTeamSelectSheet(BuddyDay day, int blockIdx, BuddyProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final assignedIds = {for (final b in day.blocks) ...b.teamIds};
          final available =
              day.teams.where((t) => !assignedIds.contains(t.id)).toList();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('[${day.blocks[blockIdx].name}] 조에 팀 배정',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('배정할 수 있는 팀이 없습니다.\n1️⃣ 팀 만들기에서 팀을 추가하세요.',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: available.map((team) {
                        return GestureDetector(
                          onTap: () {
                            day.blocks[blockIdx].teamIds.add(team.id);
                            provider.saveBuddyDay(day);
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(team.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _deleteBlockDialog(int blockIdx, BuddyDay day, BuddyProvider provider) {
    final block = day.blocks[blockIdx];
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('조 삭제'),
        content: Text('[${block.name}] 조를 삭제할까요?\n팀과 대원 배치는 유지되고 미배정으로 돌아갑니다.'),
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

  // ---------------------------------------------------------------- 3️⃣ 입수 순서

  Widget _buildRoundsSection(BuddyDay day, BuddyProvider provider) {
    if (!_isEditMode && day.rounds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _isEditMode
            ? _stepHeader('3️⃣ 입수 순서',
                trailing: TextButton.icon(
                  onPressed: () {
                    day.rounds.add(BuddyRound(
                        name: '${day.rounds.length + 1}회차', teamIds: []));
                    provider.saveBuddyDay(day);
                  },
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('회차 추가', style: TextStyle(fontSize: 12)),
                ))
            : const Padding(
                padding: EdgeInsets.only(top: 14, bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.pool, size: 16, color: Colors.blueGrey),
                    SizedBox(width: 6),
                    Text('입수 순서',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
        if (_isEditMode)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('회차의 팀을 탭해 넣고 빼세요. 같은 팀을 여러 회차에 넣을 수 있습니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        if (_isEditMode && day.rounds.isEmpty)
          const Text('회차를 추가하세요. (예: 오전, 오후 / 1탱크, 2탱크)',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        for (var r = 0; r < day.rounds.length; r++)
          _buildRoundRow(r, day, provider),
      ],
    );
  }

  Widget _buildRoundRow(int roundIdx, BuddyDay day, BuddyProvider provider) {
    final round = day.rounds[roundIdx];
    final visibleTeams = _isEditMode
        ? day.teams
        : day.teams.where((t) => round.teamIds.contains(t.id)).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _isEditMode
                ? () => _showNameDialog(
                      title: '회차 이름 변경',
                      initial: round.name,
                      onSave: (name) {
                        round.name = name;
                        provider.saveBuddyDay(day);
                      },
                    )
                : null,
            child: Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(round.name,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (visibleTeams.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('-', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                for (final team in visibleTeams)
                  Builder(builder: (context) {
                    final included = round.teamIds.contains(team.id);
                    return GestureDetector(
                      onTap: _isEditMode
                          ? () {
                              if (included) {
                                round.teamIds.remove(team.id);
                              } else {
                                // 💡 같은 사람/장비버디가 같은 회차에 겹치면 차단
                                final violation =
                                    _roundAddViolation(day, round, team);
                                if (violation != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(violation),
                                          duration: const Duration(seconds: 2)));
                                  return;
                                }
                                round.teamIds.add(team.id);
                              }
                              provider.saveBuddyDay(day);
                            }
                          : null,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: included ? Colors.blue[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: included ? Colors.blue[800]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          team.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: included ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          if (_isEditMode)
            GestureDetector(
              onTap: () {
                day.rounds.removeAt(roundIdx);
                provider.saveBuddyDay(day);
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6, top: 4),
                child: Icon(Icons.close, size: 16, color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  /// 팀에 배치된 사람 이름들 (리더·리더 버디 포함)
  Set<String> _namesOf(BuddyTeam t) => {
        if (t.leader.isNotEmpty) t.leader,
        if (t.leaderBuddy.isNotEmpty) t.leaderBuddy,
        ...t.members.where((m) => m.isNotEmpty),
      };

  /// 💡 리더 버디 모드 토글: 켜면 리더 칸이 [리더|버디]로 쪼개진다.
  void _toggleLeaderBuddy(BuddyTeam team, BuddyDay day, BuddyProvider provider) {
    if (team.leaderBuddyOn && team.leaderBuddy.isNotEmpty) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('리더 버디 끄기'),
          content: Text('[${team.name}]의 리더 버디 ${team.leaderBuddy}님 배치가 해제됩니다.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소')),
            TextButton(
              onPressed: () {
                team.leaderBuddyOn = false;
                team.leaderBuddy = '';
                provider.saveBuddyDay(day);
                setState(_clearSelection);
                Navigator.pop(dialogContext);
              },
              child: const Text('끄기', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      team.leaderBuddyOn = !team.leaderBuddyOn;
      if (!team.leaderBuddyOn) {
        team.leaderBuddy = '';
        _clearSelection();
      }
    });
    provider.saveBuddyDay(day);
  }

  /// 팀 이름 헤더 셀 — 수정 모드에선 리더 버디 on/off 토글이 붙는다
  Widget _teamHeaderCell(BuddyTeam team, BuddyDay day, BuddyProvider provider,
      {double height = 28}) {
    return Container(
      height: height,
      color: Colors.grey[100],
      child: Row(
        children: [
          if (_isEditMode) const SizedBox(width: 4),
          Expanded(
            child: Center(
              child: Text(team.name,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ),
          ),
          if (_isEditMode)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: InkWell(
                onTap: () => _toggleLeaderBuddy(team, day, provider),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: team.leaderBuddyOn ? Colors.blue[700] : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: team.leaderBuddyOn
                            ? Colors.blue[700]!
                            : Colors.grey[400]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link,
                          size: 10,
                          color:
                              team.leaderBuddyOn ? Colors.white : Colors.grey[600]),
                      const SizedBox(width: 2),
                      Text(
                        '리더버디',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color:
                              team.leaderBuddyOn ? Colors.white : Colors.grey[600],
                        ),
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

  /// 리더 행: 리더 버디 모드면 [리더|버디] 두 칸, 아니면 한 칸
  Widget _leaderRowCell(int blockIdx, int teamIdx, BuddyTeam team) {
    if (!team.leaderBuddyOn) {
      return _buildCell(blockIdx, teamIdx, -1, team.leader, isLeader: true);
    }
    return Row(
      children: [
        Expanded(child: _buildCell(blockIdx, teamIdx, -1, team.leader, isLeader: true)),
        Container(width: 1, height: 35, color: Colors.black),
        Expanded(
            child:
                _buildCell(blockIdx, teamIdx, -2, team.leaderBuddy, isLeader: true)),
      ],
    );
  }

  /// 💡 회차에 팀을 추가하기 전 검증.
  String? _roundAddViolation(BuddyDay day, BuddyRound round, BuddyTeam team) {
    final newNames = _namesOf(team);

    final existingNames = <String>{};
    for (final t in day.teams) {
      if (t.id != team.id && round.teamIds.contains(t.id)) {
        existingNames.addAll(_namesOf(t));
      }
    }

    // 1) 같은 사람이 같은 회차의 두 팀에 (예: 리더가 두 팀 겸임)
    final duplicated = newNames.intersection(existingNames);
    if (duplicated.isNotEmpty) {
      return '${duplicated.join(', ')}님이 이 회차의 다른 팀에 이미 있어 함께 넣을 수 없습니다.';
    }

    // 2) 장비버디가 같은 회차에 갈라져 들어가는 경우
    final equipProvider = context.read<EquipmentProvider>();
    final pairByName = <String, String>{};
    for (final r in equipProvider.data) {
      if (r.pairId.isNotEmpty && r.name.isNotEmpty) pairByName[r.name] = r.pairId;
    }
    for (final name in newNames) {
      final pair = pairByName[name];
      if (pair == null) continue;
      for (final other in existingNames) {
        if (other != name && pairByName[other] == pair) {
          return '장비버디($name·$other)가 같은 회차에 입수하게 되어 넣을 수 없습니다.';
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- 4️⃣ 조별 표

  /// 팀이 속한 첫 회차의 순번 (미배정은 맨 뒤)
  int _firstRoundIndexOf(BuddyDay day, BuddyTeam team) {
    for (var r = 0; r < day.rounds.length; r++) {
      if (day.rounds[r].teamIds.contains(team.id)) return r;
    }
    return day.rounds.length;
  }

  /// 팀이 속한 회차 이름들 (예: 오전 / 오전·오후)
  String _roundLabelOf(BuddyDay day, BuddyTeam team) {
    final names = [
      for (final r in day.rounds)
        if (r.teamIds.contains(team.id)) r.name,
    ];
    return names.isEmpty ? '회차 미정' : names.join('·');
  }

  /// 💡 엑셀식 열 레이아웃 사용 여부: 회차(오전/오후)가 열이 된다.
  /// 회차가 너무 많으면 열이 좁아져 기존 조별 표로 보여준다.
  bool _useColumnLayout(BuddyDay day) =>
      day.rounds.isNotEmpty && day.rounds.length <= 3;

  bool _isMorningish(BuddyDay day, BuddyRound round) =>
      round.name.contains('오전') ||
      (!round.name.contains('오후') && day.rounds.indexOf(round) == 0);

  /// 표 전체 상단의 회차 헤더 1줄: [    ][ 오전 ][ 오후 ]
  Widget _buildRoundHeaderRow(BuddyDay day) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          const SizedBox(width: _blockLabelWidth),
          for (final round in day.rounds)
            Expanded(
              child: Container(
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isMorningish(day, round) ? _morningTint : _afternoonTint,
                  border: Border.all(color: Colors.black),
                ),
                child: Text(
                  round.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: _isMorningish(day, round) ? _morningText : _afternoonText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 💡 조 한 줄: 왼쪽 조 라벨 + 회차별 열(팀 표). 팀은 자기 회차 열에 들어간다.
  Widget _buildBlockRow(int blockIdx, BuddyDay day, BuddyProvider provider) {
    final block = day.blocks[blockIdx];

    // (block.teamIds 안의 실제 위치, 팀) — 선택/배치는 실제 위치 기준
    final entries = <MapEntry<int, BuddyTeam>>[
      for (var i = 0; i < block.teamIds.length; i++)
        if (day.teamById(block.teamIds[i]) != null)
          MapEntry(i, day.teamById(block.teamIds[i])!),
    ];

    // 회차별 열 배정 — 여러 회차에 입수하는 팀은 각 회차 열마다 반복해 그린다.
    // (예: 오전 1 = A·B, 오전 2 = A·B 같은 연속 입수 패턴)
    final columns =
        List.generate(day.rounds.length, (_) => <MapEntry<int, BuddyTeam>>[]);
    final unassigned = <MapEntry<int, BuddyTeam>>[];
    for (final e in entries) {
      var placed = false;
      for (var r = 0; r < day.rounds.length; r++) {
        if (day.rounds[r].teamIds.contains(e.value.id)) {
          columns[r].add(e);
          placed = true;
        }
      }
      if (!placed) unassigned.add(e);
    }

    final teams = [for (final e in entries) e.value];
    final showLeaderRow = _isEditMode ||
        teams.any((t) => t.leader.isNotEmpty || t.leaderBuddy.isNotEmpty);

    int slotsOf(BuddyTeam t) {
      var n = t.members.length + (_isEditMode ? 1 : 0);
      if (n.isOdd) n++;
      return math.max(n, 2);
    }

    final maxSlots = teams.isEmpty ? 2 : teams.map(slotsOf).reduce(math.max);
    final rowCount = maxSlots ~/ 2;

    Widget teamBox(MapEntry<int, BuddyTeam> e) {
      final team = e.value;
      final teamIdx = e.key;
      return Table(
        border: TableBorder.all(color: Colors.black, width: 1),
        children: [
          TableRow(children: [
            _teamHeaderCell(team, day, provider),
          ]),
          if (showLeaderRow)
            TableRow(children: [
              _leaderRowCell(blockIdx, teamIdx, team),
            ]),
          for (var r = 0; r < rowCount; r++)
            TableRow(children: [
              Row(
                children: [
                  Expanded(
                      child: _buildCell(
                          blockIdx, teamIdx, r * 2, _memberAt(team, r * 2))),
                  Container(width: 1, height: 35, color: Colors.black),
                  Expanded(
                      child: _buildCell(
                          blockIdx, teamIdx, r * 2 + 1, _memberAt(team, r * 2 + 1))),
                ],
              ),
            ]),
        ],
      );
    }

    Widget blockLabel() => Container(
          width: _blockLabelWidth,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.black),
          ),
          alignment: Alignment.center,
          child: Text(
            block.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          if (teams.isEmpty)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  blockLabel(),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                      alignment: Alignment.center,
                      child: Text(
                        _isEditMode ? '2️⃣ 조 구성에서 팀을 배정하세요.' : '팀이 없습니다.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  blockLabel(),
                  for (final col in columns)
                    Expanded(
                      child: col.isEmpty
                          ? Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black),
                              ),
                            )
                          : Column(children: [for (final e in col) teamBox(e)]),
                    ),
                ],
              ),
            ),
          // 어느 회차에도 없는 팀 — 숨기지 않고 아래에 표시해 배정을 유도한다
          for (final e in unassigned)
            Row(
              children: [
                const SizedBox(width: _blockLabelWidth),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 20,
                        color: Colors.orange[50],
                        alignment: Alignment.center,
                        child: const Text('⚠ 회차 미정 — 3️⃣ 입수 순서에서 배정하세요',
                            style: TextStyle(
                                fontSize: 10, color: Colors.deepOrange,
                                fontWeight: FontWeight.bold)),
                      ),
                      teamBox(e),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBlockTable(int blockIdx, BuddyDay day, BuddyProvider provider) {
    final block = day.blocks[blockIdx];

    // (실제 teamIds 안의 위치, 팀) — 선택/배치는 실제 위치 기준을 유지한다
    var entries = <MapEntry<int, BuddyTeam>>[
      for (var i = 0; i < block.teamIds.length; i++)
        if (day.teamById(block.teamIds[i]) != null)
          MapEntry(i, day.teamById(block.teamIds[i])!),
    ];

    // 💡 비치: 열 순서를 입수 순서(오전→오후)에 맞춰 정렬해
    //    모든 조에서 왼쪽=오전, 오른쪽=오후로 통일한다.
    final isBeachColumns = day.type == 'beach' && day.rounds.isNotEmpty;
    if (isBeachColumns) {
      entries = List.of(entries)
        ..sort((a, b) {
          final d = _firstRoundIndexOf(day, a.value)
              .compareTo(_firstRoundIndexOf(day, b.value));
          return d != 0 ? d : a.key.compareTo(b.key);
        });
    }

    final teams = [for (final e in entries) e.value];
    final showLeaderRow = _isEditMode ||
        teams.any((t) => t.leader.isNotEmpty || t.leaderBuddy.isNotEmpty);

    int slotsOf(BuddyTeam t) {
      var n = t.members.length + (_isEditMode ? 1 : 0);
      if (n.isOdd) n++;
      return math.max(n, 2);
    }

    final maxSlots = teams.isEmpty ? 0 : teams.map(slotsOf).reduce(math.max);
    final rowCount = maxSlots ~/ 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 34,
            color: _blockHeaderColor,
            alignment: Alignment.centerLeft,
            child: Text(
              block.name.isEmpty ? '(이름 없음)' : block.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          if (teams.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Colors.black)),
              child: Text(
                _isEditMode ? '2️⃣ 조 구성에서 팀을 배정하세요.' : '팀이 없습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            Table(
              border: TableBorder.all(color: Colors.black, width: 1),
              children: [
                // 💡 비치: 각 열이 어느 회차(오전/오후)인지 라벨로 못박는다
                if (isBeachColumns)
                  TableRow(
                    children: [
                      for (final team in teams)
                        TableCell(
                          child: Builder(builder: (context) {
                            final ri = _firstRoundIndexOf(day, team);
                            final unassigned = ri >= day.rounds.length;
                            final label = _roundLabelOf(day, team);
                            // 이름 우선(오전=햇살/오후=물빛), 그 외는 순번으로
                            final isMorning = label.contains('오전') ||
                                (!label.contains('오후') && ri == 0);
                            return Container(
                              height: 24,
                              alignment: Alignment.center,
                              color: unassigned
                                  ? Colors.white
                                  : (isMorning
                                      ? const Color(0xFFFFF3E0)
                                      : const Color(0xFFE3F2FD)),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: unassigned
                                      ? Colors.grey[400]
                                      : (isMorning
                                          ? const Color(0xFFE65100)
                                          : const Color(0xFF1565C0)),
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                TableRow(
                  children: [
                    for (final team in teams)
                      TableCell(
                        child: _teamHeaderCell(team, day, provider, height: 30),
                      ),
                  ],
                ),
                if (showLeaderRow)
                  TableRow(
                    children: [
                      for (var t = 0; t < teams.length; t++)
                        _leaderRowCell(blockIdx, entries[t].key, teams[t]),
                    ],
                  ),
                for (var r = 0; r < rowCount; r++)
                  TableRow(
                    children: [
                      for (var t = 0; t < teams.length; t++)
                        TableCell(
                          child: Row(
                            children: [
                              Expanded(
                                  child: _buildCell(blockIdx, entries[t].key, r * 2,
                                      _memberAt(teams[t], r * 2))),
                              Container(width: 1, height: 35, color: Colors.black),
                              Expanded(
                                  child: _buildCell(blockIdx, entries[t].key,
                                      r * 2 + 1, _memberAt(teams[t], r * 2 + 1))),
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

    // 리더 버디(-2)는 일반 대원처럼 — 리더 색·굵은 글씨 없이 표시한다
    final isPlainBuddy = slotIdx == -2;
    Color bgColor = isLeader && !isPlainBuddy ? _leaderTint : Colors.white;
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
          isLeader && value.isEmpty && _isEditMode
              ? (slotIdx == -2 ? '버디' : '리더/강사')
              : value,
          style: TextStyle(
            fontSize: isLeader && !isPlainBuddy ? 13 : 12,
            fontWeight:
                isLeader && !isPlainBuddy ? FontWeight.bold : FontWeight.normal,
            color: isLeader && value.isEmpty ? Colors.grey[400] : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 이름 다이얼로그

  void _showNameDialog({
    required String title,
    String initial = '',
    String hint = '',
    required void Function(String name) onSave,
  }) {
    _nameController.text = initial;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              onSave(name);
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 편성 불러오기

  void _showImportSheet(
      BuddyDay currentDay, BuddyProvider provider, ScheduleProvider scheduleProvider) {
    final order = {
      for (var i = 0; i < scheduleProvider.dates.length; i++)
        scheduleProvider.dates[i]['id']!: i
    };
    final labels = {
      for (final d in scheduleProvider.dates)
        d['id']!: '${d['title']} · ${d['date']}'
    };

    final candidates = provider.buddyDays
        .where((d) => d.id != currentDay.id && d.teams.isNotEmpty)
        .toList()
      ..sort((a, b) => (order[a.id] ?? 999).compareTo(order[b.id] ?? 999));

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('불러올 편성이 있는 일차가 없습니다.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('편성 불러오기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('선택한 일차의 팀/조/입수 순서가 그대로 복사됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: candidates.map((source) {
                    final memberCount = source.teams
                        .fold<int>(0, (s, t) => s + _namesOf(t).length);
                    final typeLabel = source.type == 'beach'
                        ? '🏖'
                        : (source.type == 'boating' ? '🚤' : '');

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Text(typeLabel, style: const TextStyle(fontSize: 18)),
                      title: Text(labels[source.id] ?? source.title,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '팀 ${source.teams.length} · 조 ${source.blocks.length} · 배치 $memberCount명 · 회차 ${source.rounds.length}',
                          style: const TextStyle(fontSize: 11.5)),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (currentDay.teams.isNotEmpty ||
                            currentDay.blocks.isNotEmpty ||
                            currentDay.rounds.isNotEmpty) {
                          _confirmImportOverwrite(source, currentDay, provider);
                        } else {
                          _importFrom(source, currentDay, provider);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmImportOverwrite(
      BuddyDay source, BuddyDay target, BuddyProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('편성 덮어쓰기'),
        content: const Text('현재 일차의 편성이 불러온 내용으로 교체됩니다. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          TextButton(
            onPressed: () {
              _importFrom(source, target, provider);
              Navigator.pop(dialogContext);
            },
            child: const Text('덮어쓰기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _importFrom(BuddyDay source, BuddyDay target, BuddyProvider provider) {
    target.teams
      ..clear()
      ..addAll([
        for (final t in source.teams)
          BuddyTeam(
              id: t.id,
              name: t.name,
              leader: t.leader,
              leaderBuddyOn: t.leaderBuddyOn,
              leaderBuddy: t.leaderBuddy,
              members: List.of(t.members)),
      ]);
    target.blocks
      ..clear()
      ..addAll([
        for (final b in source.blocks)
          BuddyBlock(name: b.name, teamIds: List.of(b.teamIds)),
      ]);
    target.rounds
      ..clear()
      ..addAll([
        for (final r in source.rounds)
          BuddyRound(name: r.name, teamIds: List.of(r.teamIds)),
      ]);
    target.type = source.type;

    provider.saveBuddyDay(target);
    setState(_clearSelection);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ 편성을 불러왔습니다. 필요한 대원만 교체하세요.')),
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
    if (_selTeamIdx! >= block.teamIds.length) return;
    final team = day.teamById(block.teamIds[_selTeamIdx!]);
    if (team == null) return;

    if (_selSlotIdx == -1) {
      team.leader = name;
    } else if (_selSlotIdx == -2) {
      team.leaderBuddy = name;
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

    // 💡 선택된 팀 기준의 검사 범위:
    //  - selectedTeamNames: 같은 팀 안 중복 배치 방지
    //  - conflictScope: 같은 회차 기준 — 선택한 팀 + 같은 회차의 모든 팀 대원
    var selectedTeamNames = <String>{};
    var conflictScope = <String>{};

    if (_selBlockIdx != null && _selBlockIdx! < dayData.blocks.length) {
      final block = dayData.blocks[_selBlockIdx!];
      if (_selTeamIdx != null && _selTeamIdx! < block.teamIds.length) {
        final selTeam = dayData.teamById(block.teamIds[_selTeamIdx!]);
        if (selTeam != null) {
          selectedTeamNames = _namesOf(selTeam);
          conflictScope = {...selectedTeamNames};
          for (final round in dayData.rounds) {
            if (!round.teamIds.contains(selTeam.id)) continue;
            for (final t in dayData.teams) {
              if (round.teamIds.contains(t.id)) conflictScope.addAll(_namesOf(t));
            }
          }
        }
      }
    }

    // 💡 장비 화면의 데이터(그룹·장비버디)를 가져와 픽커를 구분한다.
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

    // 💡 섹션 안에서 장비버디 짝을 한 단위로 묶는다 (캡슐 하나 = 한 짝)
    List<List<MemberItem>> unitsOf(List<MemberItem> members) {
      final byId = {for (final m in members) m.id: m};
      final units = <List<MemberItem>>[];
      final taken = <String>{};
      for (final m in members) {
        if (taken.contains(m.id)) continue;
        taken.add(m.id);

        MemberItem? partner;
        final row = gearRows[m.id];
        if (row != null && row.pairId.isNotEmpty) {
          for (final r in equipProvider.data) {
            if (r.pairId == row.pairId && r.id != m.id) {
              partner = byId[r.id];
              break;
            }
          }
        }
        if (partner != null && !taken.contains(partner.id)) {
          taken.add(partner.id);
          units.add([m, partner]);
        } else {
          units.add([m]);
        }
      }
      return units;
    }

    // 대원 한 명의 버튼 (bare=true면 캡슐 내부용 — 테두리 없이 절반만)
    Widget memberButton(MemberItem member, {required bool bare}) {
      final isAssigned = selectedTeamNames.contains(member.name);
      final selfConflict = !isAssigned && conflictScope.contains(member.name);
      final partner = gearPartnerName(member);
      final conflict = !isAssigned &&
          !selfConflict &&
          partner != null &&
          conflictScope.contains(partner);
      final gray = isAssigned || selfConflict || conflict;

      void handleTap() {
        if (isAssigned) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${member.name}님은 이미 이 팀에 배치되어 있습니다.'),
              duration: const Duration(seconds: 1)));
          return;
        }
        if (selfConflict) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${member.name}님은 같은 회차에 입수하는 다른 팀에 이미 배치되어 있습니다.'),
              duration: const Duration(seconds: 2)));
          return;
        }
        if (conflict) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('장비버디 $partner님과 같은 회차에 입수하게 되어 배치할 수 없습니다.'),
              duration: const Duration(seconds: 2)));
          return;
        }
        _assignMember(member.name, dayData, buddyProvider);
      }

      final roleEmoji = participantProvider.staffRoleOf(member.id) == 'leader'
          ? kStaffRoleEmoji['leader']!
          : '';
      final isInstructor = participantProvider.isInstructor(member.id);

      if (!bare) {
        return SizedBox(
          width: 76,
          height: 30,
          child: _buildPickerItem(
            member.name,
            gray,
            handleTap,
            isPaired: partner != null, // 짝이 다른 섹션에 있는 예외 케이스 표시
            isInstructor: isInstructor,
            roleEmoji: roleEmoji,
          ),
        );
      }

      // 캡슐 내부 절반: 테두리 없이 자기 상태(회색)만 표현
      return InkWell(
        onTap: handleTap,
        child: Container(
          width: 70,
          height: 30,
          alignment: Alignment.center,
          color: gray ? Colors.grey[100] : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (roleEmoji.isNotEmpty) ...[
                Text(roleEmoji,
                    style: TextStyle(
                        fontSize: 9.5, color: gray ? Colors.grey[300] : null)),
                const SizedBox(width: 2),
              ],
              if (isInstructor) ...[
                Icon(Icons.star_rounded,
                    size: 11, color: gray ? Colors.grey[300] : Colors.amber[600]),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: gray ? Colors.grey[400] : Colors.black87,
                      fontWeight: gray ? FontWeight.normal : FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 💡 짝 캡슐: 두 명을 초록 테두리 하나로 감싸 "이 둘이 한 짝"임을 보여준다
    Widget buildUnit(List<MemberItem> unit) {
      if (unit.length == 1) return memberButton(unit[0], bare: false);

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF00796B), width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            memberButton(unit[0], bare: true),
            Container(
              width: 16,
              height: 30,
              color: const Color(0xFFDCEFEC),
              child: const Icon(Icons.link, size: 11, color: Color(0xFF00796B)),
            ),
            memberButton(unit[1], bare: true),
          ],
        ),
      );
    }

    // 선택 중인 팀 이름 안내
    String? selectionLabel;
    if (_selBlockIdx != null && _selBlockIdx! < dayData.blocks.length) {
      final block = dayData.blocks[_selBlockIdx!];
      if (_selTeamIdx != null && _selTeamIdx! < block.teamIds.length) {
        final team = dayData.teamById(block.teamIds[_selTeamIdx!]);
        selectionLabel = '${block.name} ${team?.name ?? ''} 수정 중';
      }
    }

    // 💡 살짝 끌면 화면 절반 이상으로 확장, 다시 내리면 원래 높이로
    final expandedHeight = MediaQuery.of(context).size.height * 0.55;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: _pickerExpanded ? expandedHeight : 250,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들 + 헤더 (끌거나 탭하면 확장/축소)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _pickerExpanded = !_pickerExpanded),
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < 0) setState(() => _pickerExpanded = true);
              if (velocity > 0) setState(() => _pickerExpanded = false);
            },
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('참가자 선택',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 24,
                          child: _buildPickerItem('❌ 비우기', false,
                              () => _assignMember('', dayData, buddyProvider)),
                        ),
                      ],
                    ),
                    if (selectionLabel != null)
                      Text(selectionLabel,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
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
                      children: unitsOf(section.value).map(buildUnit).toList(),
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
              if (roleEmoji.isNotEmpty) ...[
                Text(roleEmoji,
                    style: TextStyle(
                        fontSize: 9.5, color: isGray ? Colors.grey[300] : null)),
                const SizedBox(width: 2),
              ],
              if (isInstructor) ...[
                Icon(Icons.star_rounded,
                    size: 11, color: isGray ? Colors.grey[300] : Colors.amber[600]),
                const SizedBox(width: 2),
              ],
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
