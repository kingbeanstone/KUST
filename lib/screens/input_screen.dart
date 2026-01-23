import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  bool _isEditMode = false;
  bool _isSortMode = false;
  bool _isDeleteMode = false;
  final Set<String> _selectedIds = {};

  List<MemberEquipment> _localEditingData = [];

  // 💡 정렬 상태 변수
  String? _sortColumn; // 현재 정렬 기준 (null이면 기본 순서)
  bool _isAscending = true;

  final ScrollController _headerHController = ScrollController();
  final ScrollController _bodyHController = ScrollController();

  static const double colWidth = 60.0;
  static const double nameWidth = 60.0;
  static const double noWidth = 20.0;
  static const double deleteColWidth = 50.0;
  static const double sortColWidth = 50.0;
  static const double rowHeight = 45.0;
  static const double headerHeight = 40.0;
  static const double fixedBorderWidth = 1.0;

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

  void _resetModes() {
    if (!mounted) return;
    setState(() {
      _isEditMode = false;
      _isSortMode = false;
      _isDeleteMode = false;
      _sortColumn = null;
      _selectedIds.clear();
      _localEditingData = [];
    });
  }

  // 💡 정렬 버튼 클릭 로직
  void _toggleSort(String colName) {
    if (_isSortMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('순서 변경 중에는 정렬 필터를 사용할 수 없습니다.'), duration: Duration(seconds: 1)),
      );
      return;
    }
    setState(() {
      if (_sortColumn == colName) {
        if (_isAscending) {
          _isAscending = false; // 오름차순 -> 내림차순
        } else {
          _sortColumn = null; // 내림차순 -> 정렬 해제
        }
      } else {
        _sortColumn = colName;
        _isAscending = true; // 새로운 컬럼 오름차순 시작
      }
    });
  }

  void _updateLocalValue(String id, String field, String newValue) {
    setState(() {
      final index = _localEditingData.indexWhere((m) => m.id == id);
      if (index != -1) {
        if (field == '이름') {
          _localEditingData[index].name = newValue;
        } else {
          _localEditingData[index].gears[field]?.value = newValue;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EquipmentProvider>(context);
    final gearKeys = ['가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타'];

    // 💡 정렬 로직 적용
    List<MemberEquipment> baseData = _isEditMode ? _localEditingData : provider.data;
    List<MemberEquipment> displayData = List.from(baseData);

    if (_sortColumn != null && !_isSortMode) {
      displayData.sort((a, b) {
        dynamic aVal = _getSortValue(a, _sortColumn!);
        dynamic bVal = _getSortValue(b, _sortColumn!);

        int? aInt = int.tryParse(aVal.toString());
        int? bInt = int.tryParse(bVal.toString());

        int cmp;
        if (aInt != null && bInt != null) {
          cmp = aInt.compareTo(bInt);
        } else {
          cmp = aVal.toString().compareTo(bVal.toString());
        }
        return _isAscending ? cmp : -cmp;
      });
    }

    double fixedSectionWidth = noWidth + nameWidth + fixedBorderWidth;
    if (_isSortMode) fixedSectionWidth += sortColWidth;
    if (_isDeleteMode) fixedSectionWidth += deleteColWidth;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('정보 입력', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: _buildAppBarActions(provider),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // 💡 상단 정렬 버튼 바
          _buildSortButtonBar(),
          _buildFullHeader(gearKeys, fixedSectionWidth),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: fixedSectionWidth,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey[400]!, width: fixedBorderWidth)),
                    ),
                    child: Column(
                      children: List.generate(displayData.length, (index) {
                        final member = displayData[index];
                        bool isSelected = _selectedIds.contains(member.id);
                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFF5F5) : Colors.white,
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            children: [
                              if (_isSortMode) _sortHandle(),
                              if (_isDeleteMode) _deleteCheckbox(member.id),
                              _dataCell(
                                  Text(
                                      '${index + 1}',
                                      style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)
                                  ),
                                  noWidth,
                                  color: const Color(0xFFF8F9FA)
                              ),
                              _EditableCell(
                                width: nameWidth,
                                height: rowHeight,
                                initialValue: member.name,
                                enabled: _isEditMode && provider.isAdmin,
                                fontSize: 13,
                                onUpdate: (v) => _updateLocalValue(member.id, '이름', v),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _bodyHController,
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: List.generate(displayData.length, (index) {
                          final member = displayData[index];
                          bool isSelected = _selectedIds.contains(member.id);
                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFF5F5) : Colors.white,
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: Row(
                              children: gearKeys.map((k) => _EditableCell(
                                width: colWidth,
                                height: rowHeight,
                                initialValue: member.gears[k]?.value ?? '',
                                enabled: _isEditMode && provider.isAdmin,
                                fontSize: 11,
                                onUpdate: (v) => _updateLocalValue(member.id, k, v),
                                isGear: true,
                              )).toList(),
                            ),
                          );
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
    );
  }

  dynamic _getSortValue(MemberEquipment m, String col) {
    if (col == '이름') return m.name;
    return m.gears[col]?.value ?? '';
  }

  // 💡 상단 정렬 버튼 위젯
  Widget _buildSortButtonBar() {
    final sortItems = ['이름', '가방', 'BCD', '호흡기'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sortItems.map((label) {
                  bool isActive = _sortColumn == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isActive,
                      onSelected: (_) => _toggleSort(label),
                      selectedColor: Colors.blue[600],
                      labelStyle: TextStyle(
                        color: isActive ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      avatar: isActive ? Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_sortColumn != null)
            IconButton(
              onPressed: () => setState(() => _sortColumn = null),
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
        ],
      ),
    );
  }

  Widget _buildFullHeader(List<String> gearKeys, double fixedWidth) {
    return Container(
      height: headerHeight,
      color: const Color(0xFFF8F9FA),
      child: Row(
        children: [
          SizedBox(
            width: fixedWidth,
            child: Row(
              children: [
                if (_isSortMode) _headerCell('정렬', sortColWidth),
                if (_isDeleteMode) _headerCell('선택', deleteColWidth),
                _headerCell('N', noWidth),
                _headerCell('이름', nameWidth, onTap: () => _toggleSort('이름'), isSorted: _sortColumn == '이름'),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _headerHController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: gearKeys.map((k) {
                  bool canSort = (k == '가방' || k == 'BCD' || k == '호흡기');
                  return _headerCell(
                    k, colWidth,
                    onTap: canSort ? () => _toggleSort(k) : null,
                    isSorted: _sortColumn == k,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(EquipmentProvider provider) {
    if (!provider.isAdmin) return [];

    if (_isDeleteMode) {
      return [
        if (_selectedIds.isNotEmpty)
          TextButton(
            onPressed: () => _showDeleteConfirm(provider),
            child: Text('삭제실행(${_selectedIds.length})', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        TextButton(onPressed: _resetModes, child: const Text('취소', style: TextStyle(color: Colors.red))),
      ];
    }
    if (_isEditMode) {
      return [
        TextButton(onPressed: _resetModes, child: const Text('수정 취소', style: TextStyle(color: Colors.red))),
        TextButton(
          onPressed: () async {
            FocusManager.instance.primaryFocus?.unfocus();
            await Future.delayed(const Duration(milliseconds: 100));
            await provider.saveBulkChanges(_localEditingData);
            _resetModes();
          },
          child: const Text('완료', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
      ];
    }
    if (_isSortMode) {
      return [
        TextButton(onPressed: _resetModes, child: const Text('정렬 취소', style: TextStyle(color: Colors.red))),
        TextButton(
          onPressed: () async {
            _resetModes();
          },
          child: const Text('정렬 완료', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
      ];
    }
    return [
      TextButton(onPressed: () {
        setState(() {
          _isEditMode = true;
          _localEditingData = provider.data.map((m) => m.copy()).toList();
        });
      }, child: const Text('수정', style: TextStyle(color: Colors.black54))),
      TextButton(onPressed: () => setState(() {
        _isSortMode = true;
        _sortColumn = null;
      }), child: const Text('정렬', style: TextStyle(color: Colors.black54))),
      TextButton(onPressed: () => setState(() => _isDeleteMode = true), child: const Text('삭제', style: TextStyle(color: Colors.black54))),
      TextButton(onPressed: provider.addRow, child: const Text('추가', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
    ];
  }

  Widget _headerCell(String text, double width, {VoidCallback? onTap, bool isSorted = false}) => InkWell(
    onTap: onTap,
    child: Container(
      width: width, alignment: Alignment.center,
      decoration: BoxDecoration(
          color: isSorted ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          border: Border(right: BorderSide(color: Colors.grey[300]!))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSorted ? Colors.blue[800] : Colors.black)),
          if (isSorted) Icon(_isAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 14, color: Colors.blue[800]),
        ],
      ),
    ),
  );

  Widget _dataCell(Widget child, double width, {Color? color}) => Container(
    width: width,
    height: rowHeight,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, border: Border(right: BorderSide(color: Colors.grey[200]!))),
    child: child,
  );

  Widget _sortHandle() => _dataCell(const Icon(Icons.drag_handle, size: 20, color: Colors.blueGrey), sortColWidth, color: const Color(0xFFF1F3F5));

  Widget _deleteCheckbox(String id) {
    bool isSelected = _selectedIds.contains(id);
    return GestureDetector(
      onTap: () => setState(() => isSelected ? _selectedIds.remove(id) : _selectedIds.add(id)),
      child: _dataCell(
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.red : Colors.grey, width: 2), color: isSelected ? Colors.red : Colors.transparent),
          child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
        ),
        deleteColWidth,
      ),
    );
  }

  void _showDeleteConfirm(EquipmentProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'), content: Text('선택한 ${_selectedIds.length}명을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () async {
            final ids = _selectedIds.toList();
            _resetModes();
            Navigator.pop(context);
            await Future.wait(ids.map((id) => provider.deleteMember(id)));
          }, child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _EditableCell extends StatefulWidget {
  final double width;
  final double height;
  final String initialValue;
  final bool enabled;
  final double fontSize;
  final Function(String) onUpdate;
  final bool isGear;

  const _EditableCell({required this.width, required this.height, required this.initialValue, required this.enabled, required this.fontSize, required this.onUpdate, this.isGear = false});

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(() { if (!_focusNode.hasFocus) _handleSave(); });
  }

  @override
  void didUpdateWidget(_EditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() { _controller.dispose(); _focusNode.dispose(); super.dispose(); }

  void _handleSave() {
    final val = _controller.text.trim();
    if (val != widget.initialValue) widget.onUpdate(val);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.enabled ? const Color(0xFFF0F8FF) : Colors.transparent,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(fontSize: widget.fontSize, color: Colors.black87, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: false,
          contentPadding: EdgeInsets.symmetric(vertical: (widget.height - widget.fontSize) / 2 - 4),
          hintText: widget.isGear ? '-' : '',
        ),
        onFieldSubmitted: (_) => _handleSave(),
        onTapOutside: (_) => _focusNode.unfocus(),
      ),
    );
  }
}