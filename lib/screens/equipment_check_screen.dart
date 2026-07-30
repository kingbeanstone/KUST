import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/equipment_model.dart';
import '../models/member_model.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_provider.dart';

const List<String> _gearKeys = [
  '가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타'
];

const Color _pairColor = Color(0xFF00796B);
const Color _pairSoft = Color(0xFFDCEFEC);
const Color _pairTint = Color(0xFFF0F7F6); // 조 블록 배경용 아주 옅은 초록
const Color _okColor = Color(0xFF2E7D32);
const Color _okSoft = Color(0xFFE5F2E6);
const Color _badColor = Color(0xFFD14842);
const Color _badSoft = Color(0xFFFBE8E7);
const Color _editSoft = Color(0xFFF0F8FF);

/// 표에 그려질 한 덩어리. 혼자 쓰는 대원은 1명, 장비 버디는 2명이 들어온다.
class _Block {
  final List<MemberEquipment> members;
  const _Block(this.members);

  bool get isPair => members.length > 1;
  String get pairId => members.first.pairId;

  /// 짝이 이 장비를 함께 쓰는지. 대표(순서가 앞선 대원) 기준으로 판단한다.
  bool sharesGear(String gear) => isPair && members.first.sharedGears.contains(gear);
}

/// 그룹(교육 1팀 등) 단위의 섹션. title이 null이면 그룹 기능 미사용(헤더 없이 평평한 표).
class _Section {
  final String key; // 접기 상태 식별용
  final String? title;
  final List<_Block> blocks;
  const _Section({required this.key, required this.title, required this.blocks});

  List<MemberEquipment> get allMembers => blocks.expand((b) => b.members).toList();
}

/// 💡 동아리원 명단과 조인해서 기수 오름차순 → 이름순으로 비교한다.
///    (장비 행 ID = 동아리원 ID. 명단에 없는 구버전 행은 맨 뒤에서 이름순)
int _compareByGeneration(Map<String, MemberItem> club, MemberEquipment a, MemberEquipment b) {
  int genKey(MemberEquipment m) {
    final gen = club[m.id]?.generation ?? '';
    final match = RegExp(r'\d+').firstMatch(gen);
    return match == null ? 1 << 30 : int.parse(match.group(0)!);
  }

  final cmp = genKey(a).compareTo(genKey(b));
  return cmp != 0 ? cmp : a.name.compareTo(b.name);
}

/// 💡 표시 순서: 저장된 order(드래그로 변경 가능) 우선, 같으면 기수→이름.
int _compareRows(Map<String, MemberItem> club, MemberEquipment a, MemberEquipment b) {
  final cmp = a.order.compareTo(b.order);
  return cmp != 0 ? cmp : _compareByGeneration(club, a, b);
}

/// 저장된 순서대로 훑으면서 같은 pairId끼리 인접하게 묶는다.
List<_Block> _buildBlocks(List<MemberEquipment> data, Map<String, MemberItem> club) {
  final sorted = List<MemberEquipment>.from(data)
    ..sort((a, b) => _compareRows(club, a, b));
  final blocks = <_Block>[];
  final taken = <String>{};

  for (final member in sorted) {
    if (taken.contains(member.id)) continue;

    if (member.hasPair) {
      final mates = sorted
          .where((m) => m.pairId == member.pairId && !taken.contains(m.id))
          .take(2)
          .toList();
      for (final m in mates) {
        taken.add(m.id);
      }
      blocks.add(_Block(mates));
    } else {
      taken.add(member.id);
      blocks.add(_Block([member]));
    }
  }
  return blocks;
}

/// 💡 v2: 장비 '목록'과 '체크'를 한 화면의 두 모드로 통합.
///  - 보기 모드: 장비 번호 + O/X 체크
///  - 수정 모드: O/X 대신 번호를 편집하고, 장비 버디 편성과 장비별 공유 여부를 지정
class EquipmentCheckScreen extends StatefulWidget {
  const EquipmentCheckScreen({super.key});

  @override
  State<EquipmentCheckScreen> createState() => _EquipmentCheckScreenState();
}

class _EquipmentCheckScreenState extends State<EquipmentCheckScreen> {
  bool _isEditMode = false;

  /// 수정 모드 진입 시 만들어지는 편집용 사본 (id -> 사본)
  final Map<String, MemberEquipment> _editing = {};

  /// 접혀 있는 그룹 섹션의 key 모음
  final Set<String> _collapsed = {};

  /// 그룹 편성 시트의 이름 입력 컨트롤러.
  /// 💡 시트 안에서 만들고 whenComplete로 dispose하면 닫힘 애니메이션 중에
  ///    살아있는 TextField의 컨트롤러를 먼저 죽여 크래시가 난다. (_dependents.isEmpty)
  ///    그래서 화면 State가 소유하고 화면 dispose에서 정리한다.
  final TextEditingController _groupNameController = TextEditingController();

  final ScrollController _headerHController = ScrollController();
  final ScrollController _bodyHController = ScrollController();

  static const double nameWidth = 78.0;
  static const double colWidth = 56.0;
  static const double headerHeight = 38.0;
  static const double bandHeight = 30.0;
  static const double valueHeight = 34.0;
  static const double statusHeight = 26.0;
  static const double groupHeaderHeight = 30.0;
  static const Color groupHeaderColor = Color(0xFF455A64);

  double get _gearsWidth => _gearKeys.length * colWidth;

  /// 대원 한 명이 차지하는 세로 높이 (수정 모드에서는 O/X 행이 사라진다)
  double get _slotHeight => valueHeight + (_isEditMode ? 0 : statusHeight);

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
    _groupNameController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- 블록 구성

  /// 편집 중이면 사본을, 아니면 원본을 돌려준다.
  MemberEquipment _visible(MemberEquipment member) => _editing[member.id] ?? member;

  /// 그룹 순서대로 섹션을 만든다. 그룹이 하나도 없으면 헤더 없는 단일 섹션.
  /// 그룹에 속하지 않은 대원은 맨 아래 '미지정' 섹션으로.
  List<_Section> _buildSections(EquipmentProvider provider, Map<String, MemberItem> club) {
    final groups = provider.groups;
    if (groups.isEmpty) {
      return [_Section(key: '__all__', title: null, blocks: _buildBlocks(provider.data, club))];
    }

    final sections = <_Section>[];
    final knownIds = groups.map((g) => g.id).toSet();

    for (final g in groups) {
      sections.add(_Section(
        key: g.id,
        title: g.name,
        blocks: _buildBlocks(provider.data.where((m) => m.groupId == g.id).toList(), club),
      ));
    }

    final rest = provider.data.where((m) => !knownIds.contains(m.groupId)).toList();
    if (rest.isNotEmpty) {
      sections.add(_Section(key: '__rest__', title: '미지정', blocks: _buildBlocks(rest, club)));
    }
    return sections;
  }

  void _toggleCollapse(String key) {
    setState(() {
      _collapsed.contains(key) ? _collapsed.remove(key) : _collapsed.add(key);
    });
  }

  /// 섹션 헤더 우측에 붙는 요약 (보기: 완료 수 / 수정: 인원수)
  String _sectionSummary(_Section section) {
    final members = section.allMembers;
    if (_isEditMode) return '${members.length}명';
    int done = 0;
    int total = 0;
    for (final block in section.blocks) {
      for (final gear in _gearKeys) {
        if (block.sharesGear(gear)) {
          total += 1;
          if (block.members.first.gears[gear]?.checked ?? false) done += 1;
        } else {
          for (final m in block.members) {
            total += 1;
            if (m.gears[gear]?.checked ?? false) done += 1;
          }
        }
      }
    }
    return '$done/$total';
  }

  // ------------------------------------------------------------- 모드 전환

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
    // 💡 편집 도중 버디/그룹 편성이 바뀌었을 수 있으므로, 사본의 편성 정보를
    //    최신 데이터로 갱신한 뒤 저장한다. (안 하면 저장 시 편성이 과거로 되돌아감)
    for (final m in provider.data) {
      final copy = _editing[m.id];
      if (copy != null) {
        copy.pairId = m.pairId;
        copy.sharedGears = List<String>.from(m.sharedGears);
        copy.groupId = m.groupId;
      }
    }
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

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EquipmentProvider>();
    final club = {for (final m in context.watch<MemberProvider>().members) m.id: m};
    final sections = _buildSections(provider, club);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditMode ? '장비 수정' : '장비 체크',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: _buildActions(provider),
      ),
      body: Column(
        children: [
          if (_isEditMode) _buildEditGuide(),
          _buildHeader(),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: provider.data.isEmpty
                ? const Center(child: Text('등록된 대원이 없습니다.', style: TextStyle(color: Colors.grey)))
                : SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFixedColumn(sections),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _bodyHController,
                            scrollDirection: Axis.horizontal,
                            child: _buildScrollColumn(sections, provider),
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

  Widget _buildEditGuide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      color: _editSoft,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '번호 입력 · 공유/개인 버튼으로 전환',
              style: TextStyle(fontSize: 11, color: Colors.blue),
            ),
          ),
          TextButton.icon(
            onPressed: _showOrderSheet,
            icon: const Icon(Icons.swap_vert, size: 15, color: Colors.blueGrey),
            label: const Text('순서',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          TextButton.icon(
            onPressed: _showGroupSheet,
            icon: const Icon(Icons.folder_outlined, size: 15, color: groupHeaderColor),
            label: const Text('그룹',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: groupHeaderColor)),
          ),
          TextButton.icon(
            onPressed: _showPairSheet,
            icon: const Icon(Icons.group_add_outlined, size: 15, color: _pairColor),
            label: const Text('버디',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _pairColor)),
          ),
        ],
      ),
    );
  }

  /// 💡 행 순서를 드래그(≡ 핸들)로 바꾸는 바텀시트.
  ///    버디 조는 한 덩어리로 움직이고, 이동은 같은 그룹 안에서만 가능하다.
  ///    [완료]를 눌러야 저장된다.
  void _showOrderSheet() {
    final provider = context.read<EquipmentProvider>();
    final club = {for (final m in context.read<MemberProvider>().members) m.id: m};
    final sections = _buildSections(provider, club)
        .where((s) => s.blocks.isNotEmpty)
        .toList();

    // 시트 안에서만 쓰는 로컬 편집 상태 (완료 시 일괄 저장)
    final localTitles = [for (final s in sections) s.title];
    final localBlocks = [for (final s in sections) List<_Block>.of(s.blocks)];

    String blockLabel(_Block b) =>
        b.members.map((m) => m.name.isEmpty ? '(이름없음)' : m.name).join(' · ');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.8,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
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
                Row(
                  children: [
                    const Text('행 순서 변경',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setSheetState(() {
                        for (final blocks in localBlocks) {
                          blocks.sort((a, b) => _compareByGeneration(
                              club, a.members.first, b.members.first));
                        }
                      }),
                      icon: const Icon(Icons.sort, size: 15),
                      label: const Text('기수순 정렬', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const Text('≡ 핸들을 눌러 끌면 순서가 바뀝니다. 버디 조는 함께 움직입니다.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var s = 0; s < localBlocks.length; s++) ...[
                          if (localTitles[s] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 6),
                              child: Text(localTitles[s]!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54)),
                            ),
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            itemCount: localBlocks[s].length,
                            onReorder: (oldIndex, newIndex) => setSheetState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = localBlocks[s].removeAt(oldIndex);
                              localBlocks[s].insert(newIndex, item);
                            }),
                            itemBuilder: (context, index) {
                              final block = localBlocks[s][index];
                              return Container(
                                key: ValueKey(block.members.first.id),
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 11),
                                decoration: BoxDecoration(
                                  color: block.isPair ? _pairTint : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(Icons.drag_handle,
                                          size: 20, color: Colors.blueGrey),
                                    ),
                                    const SizedBox(width: 10),
                                    if (block.isPair) ...[
                                      const Icon(Icons.link,
                                          size: 13, color: _pairColor),
                                      const SizedBox(width: 5),
                                    ],
                                    Expanded(
                                      child: Text(
                                        blockLabel(block),
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final ids = <String>[];
                      for (final blocks in localBlocks) {
                        for (final b in blocks) {
                          ids.addAll(b.members.map((m) => m.id));
                        }
                      }
                      await provider.saveRowOrder(ids);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('완료',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 💡 그룹(교육 1팀 등)을 만들고 대원을 배정하는 바텀시트.
  ///    배정 단위는 블록(버디 조 또는 혼자) — 장비 버디는 항상 함께 이동한다.
  void _showGroupSheet() {
    String? selectedGroupId;
    _groupNameController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Consumer<EquipmentProvider>(
          builder: (ctx2, provider, _) {
            final club =
                {for (final m in ctx2.watch<MemberProvider>().members) m.id: m};
            final groups = provider.groups;
            final blocks = _buildBlocks(provider.data, club);
            final groupNames = {for (final g in groups) g.id: g.name};

            String blockLabel(_Block b) => b.members
                .map((m) => m.name.isEmpty ? '(이름없음)' : m.name)
                .join(' · ');

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.8,
                ),
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
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
                    const Text('그룹 편성',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // --- 새 그룹 만들기 ---
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _groupNameController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: '새 그룹 이름 (예: 교육 1팀)',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            // 시트 안 다른 곳을 탭하면 키보드를 내린다.
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            onSubmitted: (v) {
                              provider.addGroup(v);
                              _groupNameController.clear();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            provider.addGroup(_groupNameController.text);
                            _groupNameController.clear();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: groupHeaderColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: const Text('추가'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- 그룹 선택 칩 ---
                    if (groups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('아직 그룹이 없습니다. 먼저 그룹을 만들어주세요.',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: groups.map((g) {
                          final isSelected = selectedGroupId == g.id;
                          final count =
                              provider.data.where((m) => m.groupId == g.id).length;
                          return GestureDetector(
                            onTap: () => setSheetState(
                                () => selectedGroupId = isSelected ? null : g.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? groupHeaderColor : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      isSelected ? groupHeaderColor : Colors.grey[300]!,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${g.name} ($count)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isSelected ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _confirmDeleteGroup(
                                          ctx, provider, g.id, g.name),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Colors.white70),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedGroupId == null
                            ? '그룹을 선택한 뒤 아래에서 대원을 탭하세요.'
                            : '탭하면 넣고, 다시 탭하면 뺍니다. 장비 버디는 함께 이동합니다.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: selectedGroupId == null
                              ? Colors.grey
                              : groupHeaderColor,
                          fontWeight: selectedGroupId == null
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey[200], height: 1),
                    const SizedBox(height: 12),

                    // --- 대원(블록) 칩 ---
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: blocks.map((b) {
                            final gid = b.members.first.groupId;
                            final inSelected =
                                selectedGroupId != null && gid == selectedGroupId;
                            final otherGroup =
                                gid.isNotEmpty && gid != selectedGroupId
                                    ? groupNames[gid]
                                    : null;

                            return GestureDetector(
                              onTap: () {
                                if (selectedGroupId == null) return;
                                provider.assignToGroup(b.members.first.id,
                                    inSelected ? '' : selectedGroupId!);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: inSelected
                                      ? groupHeaderColor
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: inSelected
                                        ? groupHeaderColor
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (b.isPair) ...[
                                          Icon(Icons.link,
                                              size: 12,
                                              color: inSelected
                                                  ? Colors.white70
                                                  : _pairColor),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          blockLabel(b),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: inSelected
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (otherGroup != null)
                                      Text(
                                        otherGroup,
                                        style: TextStyle(
                                            fontSize: 9, color: Colors.grey[500]),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDeleteGroup(
      BuildContext sheetCtx, EquipmentProvider provider, String groupId, String name) {
    showDialog(
      context: sheetCtx,
      builder: (dCtx) => AlertDialog(
        title: const Text('그룹 삭제'),
        content: Text('[$name] 그룹을 삭제합니다.\n소속 대원은 미지정으로 돌아갑니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              provider.deleteGroup(groupId);
              Navigator.pop(dCtx);
            },
            child: const Text('삭제', style: TextStyle(color: _badColor)),
          ),
        ],
      ),
    );
  }

  /// 💡 멤버 버튼을 두 번 탭해서 장비 버디를 묶는 바텀시트.
  ///    편성 결과는 Firestore에 바로 반영되고 뒤의 표도 자동으로 다시 그려진다.
  void _showPairSheet() {
    String? firstPickId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Consumer<EquipmentProvider>(
          builder: (ctx2, provider, _) {
            final club =
                {for (final m in ctx2.watch<MemberProvider>().members) m.id: m};
            final sorted = List<MemberEquipment>.from(provider.data)
              ..sort((a, b) => _compareRows(club, a, b));

            // 짝이 온전히 2명인 조와, 나머지(혼자) 대원을 나눈다.
            final byPair = <String, List<MemberEquipment>>{};
            for (final m in sorted.where((m) => m.hasPair)) {
              byPair.putIfAbsent(m.pairId, () => []).add(m);
            }
            final pairs = byPair.values.where((l) => l.length >= 2).toList();
            final pairedIds = pairs.expand((l) => l).map((m) => m.id).toSet();
            final solos = sorted.where((m) => !pairedIds.contains(m.id)).toList();

            String displayName(MemberEquipment m) => m.name.isEmpty ? '(이름없음)' : m.name;
            final firstPickName = firstPickId == null
                ? null
                : displayName(sorted.firstWhere((m) => m.id == firstPickId));

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                ),
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
                    const Text('장비 버디 편성',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      firstPickId == null
                          ? '묶을 두 명을 차례로 탭하세요.'
                          : '$firstPickName 님과 묶을 대원을 탭하세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: firstPickId == null ? Colors.grey : _pairColor,
                        fontWeight: firstPickId == null ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- 편성된 조 목록 ---
                            if (pairs.isNotEmpty) ...[
                              ...pairs.map((pair) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: _pairSoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.link, size: 15, color: _pairColor),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '${displayName(pair[0])}  ·  ${displayName(pair[1])}',
                                            style: const TextStyle(
                                                fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => provider.unpairMembers(pair.first.pairId),
                                          child: const Text('해제',
                                              style: TextStyle(fontSize: 12, color: _badColor)),
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 8),
                              Divider(color: Colors.grey[200], height: 1),
                              const SizedBox(height: 12),
                            ],

                            // --- 아직 혼자인 대원 버튼 ---
                            if (solos.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('모든 대원이 편성되었습니다.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: solos.map((m) {
                                  final isPicked = firstPickId == m.id;
                                  return GestureDetector(
                                    onTap: () {
                                      if (firstPickId == null) {
                                        setSheetState(() => firstPickId = m.id);
                                      } else if (firstPickId == m.id) {
                                        setSheetState(() => firstPickId = null);
                                      } else {
                                        provider.pairMembers(firstPickId!, m.id);
                                        setSheetState(() => firstPickId = null);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: isPicked ? _pairColor : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isPicked ? _pairColor : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        displayName(m),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              isPicked ? FontWeight.bold : FontWeight.w500,
                                          color: isPicked ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[400]!))),
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
                          child: Text(k, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 블록(조/혼자) 사이를 띄우는 간격. 얇은 선 대신 여백을 줘서 조가 한 덩어리로 읽힌다.
  Widget _gap(double width) => Container(width: width, height: 8, color: const Color(0xFFF1F3F5));

  // ------------------------------------------------------- 좌측 고정 이름열

  Widget _buildFixedColumn(List<_Section> sections) {
    final cells = <Widget>[];

    for (final section in sections) {
      final collapsed = _collapsed.contains(section.key);

      if (section.title != null) {
        cells.add(GestureDetector(
          onTap: () => _toggleCollapse(section.key),
          child: Container(
            width: nameWidth,
            height: groupHeaderHeight,
            color: groupHeaderColor,
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Icon(collapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 14, color: Colors.white70),
                Expanded(
                  child: Text(
                    section.title!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ));
        if (collapsed || section.blocks.isEmpty) {
          cells.add(_gap(nameWidth));
          continue;
        }
      }

      for (final block in section.blocks) {
      final inner = <Widget>[];

      // 수정 모드에서 공유 토글 줄과 높이를 맞추기 위한 라벨 칸
      if (_isEditMode && block.isPair) {
        inner.add(Container(
          width: nameWidth,
          height: bandHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5)),
          ),
          child: const Text('공유 설정',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _pairColor)),
        ));
      }

      // 💡 블록 안에서는 셀 '내부' 테두리로 구분선을 그린다.
      //    (Container의 border는 지정한 높이 안쪽에 그려지므로 좌우 높이가 어긋나지 않는다)
      for (var j = 0; j < block.members.length; j++) {
        final member = block.members[j];
        final isLast = j == block.members.length - 1;
        inner.add(Container(
          width: nameWidth,
          height: _slotHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
          ),
          child: Text(
            member.name.isEmpty ? '-' : member.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ));
      }

      // 조는 초록 레일 + 옅은 배경으로 한 덩어리처럼 감싼다.
      cells.add(Container(
        decoration: block.isPair
            ? const BoxDecoration(
                color: _pairTint,
                border: Border(left: BorderSide(color: _pairColor, width: 3)),
              )
            : null,
        child: Column(children: inner),
      ));
      cells.add(_gap(nameWidth));
      }
    }

    return Container(
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[400]!))),
      child: Column(children: cells),
    );
  }

  // --------------------------------------------------- 우측 가로 스크롤 영역

  Widget _buildScrollColumn(List<_Section> sections, EquipmentProvider provider) {
    final rows = <Widget>[];

    for (final section in sections) {
      final collapsed = _collapsed.contains(section.key);

      if (section.title != null) {
        rows.add(GestureDetector(
          onTap: () => _toggleCollapse(section.key),
          child: Container(
            width: _gearsWidth,
            height: groupHeaderHeight,
            color: groupHeaderColor,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(
              _sectionSummary(section),
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
        ));
        if (collapsed || section.blocks.isEmpty) {
          rows.add(_gap(_gearsWidth));
          continue;
        }
      }

      for (final block in section.blocks) {
        final inner = <Widget>[];

        // 💡 공유/개인 토글 줄은 수정 모드에서만 나타난다.
        //    보기 모드에서는 '칸이 병합되어 있는 것' 자체가 공유 표시라 줄이 필요 없다.
        if (_isEditMode && block.isPair) {
          inner.add(_buildShareBand(block, provider));
        }
        inner.add(_buildBlockBody(block, provider));

        rows.add(Column(children: inner));
        rows.add(_gap(_gearsWidth));
      }
    }

    return Column(children: rows);
  }

  /// 짝의 장비별 공유 여부 토글 줄 (수정 모드 전용).
  Widget _buildShareBand(_Block block, EquipmentProvider provider) {
    return Container(
      width: _gearsWidth,
      height: bandHeight,
      decoration: BoxDecoration(
        color: _pairTint,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: Row(
        children: _gearKeys.map((gear) {
          final shared = block.sharesGear(gear);

          return GestureDetector(
            onTap: () => provider.toggleGearShare(block.pairId, gear),
            child: Container(
              width: colWidth,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
                decoration: BoxDecoration(
                  color: shared ? _pairColor : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: shared ? _pairColor : Colors.grey[400]!, width: 0.8),
                ),
                child: Text(
                  shared ? '공유' : '개인',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: shared ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 한 덩어리(혼자 또는 짝)의 장비 칸들.
  /// 공유 장비는 두 사람 높이를 하나로 합쳐서 그린다.
  Widget _buildBlockBody(_Block block, EquipmentProvider provider) {
    final blockHeight = _slotHeight * block.members.length;

    return SizedBox(
      width: _gearsWidth,
      height: blockHeight,
      child: Row(
        children: _gearKeys.map((gear) {
          if (block.sharesGear(gear)) {
            return _mergedCell(block, gear, blockHeight, provider);
          }
          return SizedBox(
            width: colWidth,
            height: blockHeight,
            child: Column(
              children: List.generate(
                block.members.length,
                (j) => _memberCell(
                  block.members[j],
                  gear,
                  provider,
                  showDivider: j < block.members.length - 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 짝이 함께 쓰는 장비 — 번호도 체크도 하나뿐이다.
  Widget _mergedCell(_Block block, String gear, double height, EquipmentProvider provider) {
    final lead = block.members.first;
    final source = _visible(lead);
    final value = source.gears[gear]?.value ?? '';
    final checked = lead.gears[gear]?.checked ?? false;

    return Container(
      width: colWidth,
      height: height,
      decoration: BoxDecoration(
        color: _pairSoft,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 병합 칸임을 알리는 표시 — "둘이 하나를 같이 쓴다"
                  const Icon(Icons.link_rounded, size: 13, color: _pairColor),
                  const SizedBox(height: 2),
                  _isEditMode
                      ? _GearValueField(
                          key: ValueKey('merged-${block.pairId}-$gear'),
                          initialValue: value,
                          onChanged: (v) {
                            for (final m in block.members) {
                              _editing[m.id]?.gears[gear]?.value = v;
                            }
                          },
                        )
                      : Text(value.isEmpty ? '-' : value,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                ],
              ),
            ),
          ),
          if (!_isEditMode)
            GestureDetector(
              onTap: () => _handleToggle(provider, lead.id, gear),
              child: Container(
                height: statusHeight,
                width: colWidth,
                alignment: Alignment.center,
                color: checked ? _okSoft : _badSoft,
                child: Text(
                  checked ? 'O' : 'X',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: checked ? _okColor : _badColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 각자 챙기는 장비 — 대원 한 명분의 번호 + O/X.
  Widget _memberCell(
    MemberEquipment member,
    String gear,
    EquipmentProvider provider, {
    bool showDivider = false,
  }) {
    final value = _visible(member).gears[gear]?.value ?? '';
    final checked = member.gears[gear]?.checked ?? false;

    return Container(
      width: colWidth,
      height: _slotHeight,
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5))
            : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: colWidth,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isEditMode ? _editSoft : Colors.transparent,
                border: Border(right: BorderSide(color: Colors.grey[200]!)),
              ),
              child: _isEditMode
                  ? _GearValueField(
                      key: ValueKey('${member.id}-$gear'),
                      initialValue: value,
                      onChanged: (v) => _editing[member.id]?.gears[gear]?.value = v,
                    )
                  : Text(value.isEmpty ? '-' : value,
                      style: const TextStyle(fontSize: 11, color: Colors.black87)),
            ),
          ),
          if (!_isEditMode)
            GestureDetector(
              onTap: () => _handleToggle(provider, member.id, gear),
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
            ),
        ],
      ),
    );
  }

  void _handleToggle(EquipmentProvider provider, String memberId, String gear) {
    if (!provider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자만 체크할 수 있습니다.'), duration: Duration(seconds: 1)),
      );
      return;
    }
    provider.toggleCheck(memberId, gear);
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
