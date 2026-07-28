import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/equipment_model.dart';
import '../providers/equipment_provider.dart';

const List<String> _gearKeys = [
  '가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타'
];

const Color _pairColor = Color(0xFF00796B);
const Color _pairSoft = Color(0xFFDCEFEC);
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

  final ScrollController _headerHController = ScrollController();
  final ScrollController _bodyHController = ScrollController();

  static const double nameWidth = 78.0;
  static const double colWidth = 56.0;
  static const double headerHeight = 38.0;
  static const double bandHeight = 30.0;
  static const double valueHeight = 34.0;
  static const double statusHeight = 26.0;

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
    super.dispose();
  }

  // ------------------------------------------------------------- 블록 구성

  /// 명단 순서대로 훑으면서 같은 pairId끼리 인접하게 묶는다.
  List<_Block> _buildBlocks(List<MemberEquipment> data) {
    final sorted = List<MemberEquipment>.from(data)..sort((a, b) => a.order.compareTo(b.order));
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

  /// 편집 중이면 사본을, 아니면 원본을 돌려준다.
  MemberEquipment _visible(MemberEquipment member) => _editing[member.id] ?? member;

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
    final blocks = _buildBlocks(provider.data);

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
            child: blocks.isEmpty
                ? const Center(child: Text('등록된 대원이 없습니다.', style: TextStyle(color: Colors.grey)))
                : SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFixedColumn(blocks, provider),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _bodyHController,
                            scrollDirection: Axis.horizontal,
                            child: _buildScrollColumn(blocks, provider),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: _editSoft,
      child: const Text(
        '이름 사이 🔗 를 눌러 장비 버디를 묶고, 묶인 조의 장비 칸을 눌러 공유 여부를 바꾸세요.',
        style: TextStyle(fontSize: 11, color: Colors.blue),
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

  Widget _separator(double width) => Container(width: width, height: 0.5, color: Colors.grey[300]);

  // ------------------------------------------------------- 좌측 고정 이름열

  Widget _buildFixedColumn(List<_Block> blocks, EquipmentProvider provider) {
    final cells = <Widget>[];

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      if (block.isPair) {
        cells.add(Container(
          width: nameWidth,
          height: bandHeight,
          alignment: Alignment.center,
          color: _pairSoft,
          child: _isEditMode
              ? _pairBandButton(
                  label: '🔗 해제',
                  onTap: () => provider.unpairMembers(block.pairId),
                )
              : const Text('장비 버디',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _pairColor)),
        ));
        cells.add(_separator(nameWidth));
      } else if (_isEditMode) {
        // 혼자인 대원은 바로 아래 대원과 묶을 수 있도록 버튼을 띄운다.
        final next = i + 1 < blocks.length ? blocks[i + 1] : null;
        final canPair = next != null && !next.isPair;
        cells.add(Container(
          width: nameWidth,
          height: bandHeight,
          alignment: Alignment.center,
          color: canPair ? _editSoft : Colors.white,
          child: canPair
              ? _pairBandButton(
                  label: '🔗 아래와 묶기',
                  onTap: () => provider.pairMembers(
                    block.members.first.id,
                    next.members.first.id,
                  ),
                )
              : null,
        ));
        cells.add(_separator(nameWidth));
      }

      // 💡 블록 안에서는 셀 '내부' 테두리로 구분선을 그린다.
      //    바깥 구분선은 블록당 한 번만 — 우측 영역과 높이를 정확히 맞추기 위함.
      for (var j = 0; j < block.members.length; j++) {
        final member = block.members[j];
        final isLast = j == block.members.length - 1;
        cells.add(Container(
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
      cells.add(_separator(nameWidth));
    }

    return Container(
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[400]!))),
      child: Column(children: cells),
    );
  }

  Widget _pairBandButton({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _pairColor),
        ),
      ),
    );
  }

  // --------------------------------------------------- 우측 가로 스크롤 영역

  Widget _buildScrollColumn(List<_Block> blocks, EquipmentProvider provider) {
    final rows = <Widget>[];

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      // 짝일 때만 장비별 공유 토글 줄을 띄운다. 열 위치가 아래 표와 정확히 맞는다.
      if (block.isPair) {
        rows.add(_buildShareBand(block, provider));
        rows.add(_separator(_gearsWidth));
      } else if (_isEditMode) {
        rows.add(Container(width: _gearsWidth, height: bandHeight, color: Colors.white));
        rows.add(_separator(_gearsWidth));
      }

      rows.add(_buildBlockBody(block, provider));
      rows.add(_separator(_gearsWidth));
    }

    return Column(children: rows);
  }

  /// 짝의 장비별 공유 여부 토글 줄.
  Widget _buildShareBand(_Block block, EquipmentProvider provider) {
    return Container(
      width: _gearsWidth,
      height: bandHeight,
      color: _pairSoft,
      child: Row(
        children: _gearKeys.map((gear) {
          final shared = block.sharesGear(gear);
          final label = shared ? '공유' : '개인';

          return GestureDetector(
            onTap: _isEditMode ? () => provider.toggleGearShare(block.pairId, gear) : null,
            child: Container(
              width: colWidth,
              height: bandHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: shared ? FontWeight.bold : FontWeight.normal,
                  color: shared ? _pairColor : Colors.blueGrey,
                  decoration: _isEditMode ? TextDecoration.underline : null,
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
              child: _isEditMode
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
                      style: const TextStyle(fontSize: 11, color: Colors.black87)),
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
