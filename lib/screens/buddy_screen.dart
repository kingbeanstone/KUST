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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        // 💡 일차 유형 표시 (수정 모드에서 탭하면 전환)
                        if (buddyData.type.isNotEmpty || _isEditMode) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _isEditMode
                                ? () {
                                    buddyData.type = buddyData.type == 'beach'
                                        ? 'boating'
                                        : (buddyData.type == 'boating' ? '' : 'beach');
                                    buddyProvider.saveBuddyDay(buddyData);
                                  }
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: buddyData.type == 'beach'
                                    ? Colors.amber[100]
                                    : (buddyData.type == 'boating'
                                        ? Colors.lightBlue[100]
                                        : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                buddyData.type == 'beach'
                                    ? '🏖 비치'
                                    : (buddyData.type == 'boating' ? '🚤 보팅' : '유형'),
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (buddyData.blocks.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _isEditMode
                            ? '템플릿으로 시작하거나 [조 추가]로 직접 만드세요.'
                            : '이 날의 버디 편성이 아직 없습니다.',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                    // 💡 대장의 편성 방식 템플릿 — 딸깍 한 번으로 뼈대 생성
                    if (_isEditMode) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _applyBeachTemplate(buddyData, buddyProvider),
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
                              onPressed: () =>
                                  _applyBoatingTemplate(buddyData, buddyProvider),
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
                      const SizedBox(height: 8),
                    ],
                  ],

                  for (var b = 0; b < buddyData.blocks.length; b++)
                    _buildBlock(b, buddyData, buddyProvider),

                  if (_isEditMode) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _addBlockDialog(buddyData, buddyProvider),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('조 추가', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 💡 전날 편성 복사 → 몇 명만 교체하는 흐름
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
                  ],

                  _buildRoundsSection(buddyData, buddyProvider),
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
                              // 💡 수정 모드에서 팀 이름 탭 = 이름 변경
                              GestureDetector(
                                onTap: _isEditMode
                                    ? () => _showNameDialog(
                                          title: '팀 이름 변경',
                                          initial: block.teams[t].name,
                                          onSave: (name) {
                                            block.teams[t].name = name;
                                            provider.saveBuddyDay(day);
                                          },
                                        )
                                    : null,
                                child: Text(block.teams[t].name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
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

  /// 고유 ID를 가진 새 팀 생성 (회차가 이 ID로 참조한다)
  BuddyTeam _newTeam(BuddyDay day) => BuddyTeam(
        id: 'team_${DateTime.now().microsecondsSinceEpoch}',
        name: _nextTeamName(day),
        leader: '',
        members: [],
      );

  /// 팀 삭제 시 회차 참조도 함께 정리
  void _removeTeamFromRounds(BuddyDay day, Iterable<String> teamIds) {
    final ids = teamIds.toSet();
    for (final round in day.rounds) {
      round.teamIds.removeWhere(ids.contains);
    }
  }

  /// 💡 비치 템플릿: YB(A·B) / 교육팀(C·D) 두 조로 쪼개고,
  ///    오전=[A,C] 오후=[B,D] 회차를 미리 깔아준다. 전부 수정 가능.
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
    day.blocks.addAll([
      BuddyBlock(name: 'YB', teams: [a, b]),
      BuddyBlock(name: '교육팀', teams: [c, d]),
    ]);
    day.rounds.addAll([
      BuddyRound(name: '오전', teamIds: [a.id, c.id]),
      BuddyRound(name: '오후', teamIds: [b.id, d.id]),
    ]);
    provider.saveBuddyDay(day);
  }

  /// 💡 보팅 템플릿: YB·신입 혼성 A~D팀 한 조 + 오전/오후 2회차씩.
  ///    오전엔 A팀 2탱크, 오후엔 B팀 2탱크 예시 배치 (전부 수정 가능).
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
    day.blocks.add(BuddyBlock(name: '보팅 (혼성)', teams: [a, b, c, d]));
    day.rounds.addAll([
      BuddyRound(name: '오전 1', teamIds: [a.id]),
      BuddyRound(name: '오전 2', teamIds: [a.id]),
      BuddyRound(name: '오후 1', teamIds: [b.id]),
      BuddyRound(name: '오후 2', teamIds: [b.id]),
    ]);
    provider.saveBuddyDay(day);
  }

  // ---------------------------------------------------------------- 편성 불러오기

  /// 💡 편성이 있는 다른 일차 목록에서 골라 통째로 복사한다.
  void _showImportSheet(
      BuddyDay currentDay, BuddyProvider provider, ScheduleProvider scheduleProvider) {
    // 일정 탭 순서대로 정렬
    final order = {
      for (var i = 0; i < scheduleProvider.dates.length; i++)
        scheduleProvider.dates[i]['id']!: i
    };
    final labels = {
      for (final d in scheduleProvider.dates)
        d['id']!: '${d['title']} · ${d['date']}'
    };

    final candidates = provider.buddyDays
        .where((d) => d.id != currentDay.id && d.blocks.isNotEmpty)
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
              const Text('선택한 일차의 조/팀/입수 순서가 그대로 복사됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: candidates.map((source) {
                    final teamCount =
                        source.blocks.fold<int>(0, (s, b) => s + b.teams.length);
                    final memberCount = source.blocks.fold<int>(
                        0, (s, b) => s + b.teams.fold<int>(0, (s2, t) => s2 + _namesOf(t).length));
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
                          '조 ${source.blocks.length} · 팀 $teamCount · 배치 $memberCount명 · 회차 ${source.rounds.length}',
                          style: const TextStyle(fontSize: 11.5)),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (currentDay.blocks.isNotEmpty || currentDay.rounds.isNotEmpty) {
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

  /// 조/팀/회차/유형을 깊은 복사로 가져온다 (원본 일차와 독립적으로 수정 가능)
  void _importFrom(BuddyDay source, BuddyDay target, BuddyProvider provider) {
    target.blocks
      ..clear()
      ..addAll([
        for (final b in source.blocks)
          BuddyBlock(
            name: b.name,
            teams: [
              for (final t in b.teams)
                BuddyTeam(
                  id: t.id,
                  name: t.name,
                  leader: t.leader,
                  members: List.of(t.members),
                ),
            ],
          ),
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

  /// 팀에 배치된 사람 이름들 (리더 포함)
  Set<String> _namesOf(BuddyTeam t) => {
        if (t.leader.isNotEmpty) t.leader,
        ...t.members.where((m) => m.isNotEmpty),
      };

  /// 💡 회차에 팀을 추가하기 전 검증.
  /// 같은 사람이 두 팀으로 동시에 들어가거나, 장비버디가 같은 회차에
  /// 겹치게 되면 사유 문자열을 돌려준다 (null이면 통과).
  String? _roundAddViolation(BuddyDay day, BuddyRound round, BuddyTeam team) {
    final newNames = _namesOf(team);
    final allTeams = [for (final b in day.blocks) ...b.teams];

    final existingNames = <String>{};
    for (final t in allTeams) {
      if (t.id != team.id && round.teamIds.contains(t.id)) {
        existingNames.addAll(_namesOf(t));
      }
    }

    // 1) 같은 사람이 같은 회차의 두 팀에 (예: 리더가 C·D 겸임)
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

  /// 이름 입력 공용 다이얼로그 (조/팀/회차). 컨트롤러는 State 소유라 안전하다.
  void _showNameDialog({
    required String title,
    String initial = '',
    String hint = '',
    required void Function(String name) onSave,
  }) {
    _blockNameController.text = initial;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _blockNameController,
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
              final name = _blockNameController.text.trim();
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

  void _addBlockDialog(BuddyDay day, BuddyProvider provider) {
    _showNameDialog(
      title: '조 추가',
      hint: '조 이름 (예: YB, 교육 1조)',
      onSave: (name) {
        day.blocks.add(BuddyBlock(
          name: name,
          teams: [_newTeam(day)],
        ));
        provider.saveBuddyDay(day);
      },
    );
  }

  void _renameBlockDialog(BuddyBlock block, BuddyDay day, BuddyProvider provider) {
    _showNameDialog(
      title: '조 이름 변경',
      initial: block.name,
      onSave: (name) {
        block.name = name;
        provider.saveBuddyDay(day);
      },
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
              _removeTeamFromRounds(day, block.teams.map((t) => t.id));
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
    block.teams.add(_newTeam(day));
    provider.saveBuddyDay(day);
  }

  void _deleteTeamDialog(int blockIdx, int teamIdx, BuddyDay day, BuddyProvider provider) {
    final team = day.blocks[blockIdx].teams[teamIdx];
    final hasMembers = team.leader.isNotEmpty || team.members.any((m) => m.isNotEmpty);

    void doDelete() {
      _removeTeamFromRounds(day, [team.id]);
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

  // ---------------------------------------------------------------- 입수 순서

  /// 💡 회차별 입수 팀 표. 같은 팀을 여러 회차에 넣을 수 있고 회차 이름은 자유(중복 허용).
  /// 장비버디 충돌 검사는 이 표의 "같은 회차" 기준으로 이뤄진다.
  Widget _buildRoundsSection(BuddyDay day, BuddyProvider provider) {
    if (!_isEditMode && day.rounds.isEmpty) return const SizedBox.shrink();

    final allTeams = [for (final b in day.blocks) ...b.teams];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Row(
          children: [
            Icon(Icons.pool, size: 16, color: Colors.blueGrey),
            SizedBox(width: 6),
            Text('입수 순서', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        if (_isEditMode)
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              '회차의 팀을 탭해 넣고 빼세요. 같은 팀을 여러 회차에 넣을 수 있습니다.\n'
              '장비버디 충돌은 같은 회차에 들어가는 팀 기준으로 검사됩니다.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 6),

        for (var r = 0; r < day.rounds.length; r++)
          _buildRoundRow(r, day, allTeams, provider),

        if (_isEditMode)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                day.rounds.add(BuddyRound(
                    name: '${day.rounds.length + 1}탱크', teamIds: []));
                provider.saveBuddyDay(day);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('회차 추가', style: TextStyle(fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _buildRoundRow(
      int roundIdx, BuddyDay day, List<BuddyTeam> allTeams, BuddyProvider provider) {
    final round = day.rounds[roundIdx];
    // 보기 모드에서는 포함된 팀만, 수정 모드에서는 전체 팀을 토글 칩으로
    final visibleTeams = _isEditMode
        ? allTeams
        : allTeams.where((t) => round.teamIds.contains(t.id)).toList();

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
          // 회차 이름 (수정 모드에서 탭하면 변경)
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
              child: Text(
                round.name,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
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

    // 💡 선택된 팀 기준의 검사 범위:
    //  - selectedTeamNames: 같은 팀 안 중복 배치 방지
    //  - conflictScope: 같은 회차 기준 — 선택한 팀 + 입수 순서표에서 그 팀과
    //    같은 회차에 함께 들어가는 모든 팀의 대원들 (본인 중복·장비버디 검사)
    //  같은 조의 다른 팀이라도 회차가 안 겹치면 중복 배치를 허용한다.
    var selectedTeamNames = <String>{};
    var conflictScope = <String>{};

    if (_selBlockIdx != null && _selBlockIdx! < dayData.blocks.length) {
      final block = dayData.blocks[_selBlockIdx!];
      if (_selTeamIdx != null && _selTeamIdx! < block.teams.length) {
        final selTeam = block.teams[_selTeamIdx!];
        selectedTeamNames = _namesOf(selTeam);
        conflictScope = {...selectedTeamNames};
        final allTeams = [for (final b in dayData.blocks) ...b.teams];
        for (final round in dayData.rounds) {
          if (!round.teamIds.contains(selTeam.id)) continue;
          for (final t in allTeams) {
            if (round.teamIds.contains(t.id)) conflictScope.addAll(_namesOf(t));
          }
        }
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
                        // 같은 팀 안 중복만 '배치됨'으로 취급
                        final isAssigned = selectedTeamNames.contains(member.name);
                        // 💡 본인이 같은 회차의 다른 팀에 이미 배치된 경우 (리더 겸임 등)
                        final selfConflict =
                            !isAssigned && conflictScope.contains(member.name);
                        final partner = gearPartnerName(member);
                        // 💡 장비버디 짝이 충돌 범위 안에 있으면 선택 불가(회색)
                        final conflict = !isAssigned &&
                            !selfConflict &&
                            partner != null &&
                            conflictScope.contains(partner);

                        return SizedBox(
                          width: 76,
                          height: 30,
                          child: _buildPickerItem(
                            member.name,
                            isAssigned || selfConflict || conflict,
                            () {
                              if (isAssigned) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('${member.name}님은 이미 이 팀에 배치되어 있습니다.'),
                                    duration: const Duration(seconds: 1)));
                                return;
                              }
                              if (selfConflict) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                        '${member.name}님은 같은 회차에 입수하는 다른 팀에 이미 배치되어 있습니다.'),
                                    duration: const Duration(seconds: 2)));
                                return;
                              }
                              if (conflict) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                        '장비버디 $partner님과 같은 회차에 입수하게 되어 배치할 수 없습니다.'),
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
