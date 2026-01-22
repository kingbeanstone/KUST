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
      _selectedIds.clear();
      _localEditingData = [];
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
    final displayData = _isEditMode ? _localEditingData : provider.data;

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
                                // 💡 관리자 인증 여부 반영
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
                                // 💡 관리자 인증 여부 반영
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
                _headerCell('이름', nameWidth),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _headerHController,
              scrollDirection: Axis.horizontal,
              child: Row(children: gearKeys.map((k) => _headerCell(k, colWidth)).toList()),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(EquipmentProvider provider) {
    // 💡 관리자가 아닐 경우 어떠한 액션 버튼도 보여주지 않음
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
    return [
      TextButton(onPressed: () {
        setState(() {
          _isEditMode = true;
          _localEditingData = provider.data.map((m) => m.copy()).toList();
        });
      }, child: const Text('수정', style: TextStyle(color: Colors.black54))),
      TextButton(onPressed: () => setState(() => _isSortMode = true), child: const Text('정렬', style: TextStyle(color: Colors.black54))),
      TextButton(onPressed: () => setState(() => _isDeleteMode = true), child: const Text('삭제', style: TextStyle(color: Colors.black54))),
      TextButton(onPressed: provider.addRow, child: const Text('추가', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
    ];
  }

  Widget _headerCell(String text, double width) => Container(
    width: width, alignment: Alignment.center,
    decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!))),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
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

  const _EditableCell({super.key, required this.width, required this.height, required this.initialValue, required this.enabled, required this.fontSize, required this.onUpdate, this.isGear = false});

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