import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_provider.dart';
import '../models/member_model.dart';

/// 💡 v2: 차분한 엑셀식 표. 색 뱃지/이모티콘 없이 행열을 맞춰 보여준다.
class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  bool _isEditMode = false;
  List<MemberItem> _localData = [];

  // 열 폭 (엑셀처럼 모든 행이 같은 폭을 쓴다)
  static const double _wNo = 30;
  static const double _wGen = 42;
  static const double _wName = 72;
  static const double _wType = 38;
  static const double _wGender = 34;
  static const double _wBlood = 46;
  static const double _wPhone = 116;
  static const double _wEmergency = 116;
  static const double _wHeight = 48;
  static const double _wShoe = 48;
  static const double _wDelete = 32;

  static const Color _line = Color(0xFFD6D6D6);

  /// 고정(No·기수·이름) 열을 제외한 오른쪽 영역 가로 스크롤 동기화
  final ScrollController _hHead = ScrollController();
  final ScrollController _hBody = ScrollController();

  @override
  void initState() {
    super.initState();
    _hHead.addListener(() {
      if (_hBody.hasClients && _hBody.offset != _hHead.offset) {
        _hBody.jumpTo(_hHead.offset);
      }
    });
    _hBody.addListener(() {
      if (_hHead.hasClients && _hHead.offset != _hBody.offset) {
        _hHead.jumpTo(_hBody.offset);
      }
    });
  }

  @override
  void dispose() {
    _hHead.dispose();
    _hBody.dispose();
    super.dispose();
  }

  void _copyToClipboard(String label, String value) {
    if (value.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: value.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$label 복사됨: ${value.trim()}'),
          duration: const Duration(seconds: 1)),
    );
  }

  void _enterEditMode(List<MemberItem> remoteMembers) {
    setState(() {
      _isEditMode = true;
      _localData = List.from(remoteMembers);
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _localData = [];
    });
  }

  Future<void> _saveChanges(MemberProvider provider) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));

    // 💡 표시는 항상 기수순 정렬이므로 순서(order)는 건드리지 않는다
    for (final member in _localData) {
      if (member.id.isEmpty) {
        await provider.addMember(member);
      } else {
        await provider.updateMember(member);
      }
    }

    setState(() {
      _isEditMode = false;
      _localData = [];
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변경 사항이 저장되었습니다.')),
      );
    }
  }

  /// 오른쪽(스크롤) 영역 전체 폭
  double get _rightWidth =>
      _wType +
      _wGender +
      _wBlood +
      _wPhone +
      _wEmergency +
      _wHeight +
      _wShoe +
      (_isEditMode ? _wDelete : 0);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<EquipmentProvider>(context);
    final memberProvider = Provider.of<MemberProvider>(context);

    final List<MemberItem> displayData =
        _isEditMode ? _localData : memberProvider.members;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('동아리원 명단',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          if (auth.isAdmin) ...[
            if (!_isEditMode)
              TextButton(
                onPressed: () => _enterEditMode(memberProvider.members),
                child: const Text('수정',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              )
            else ...[
              TextButton(
                onPressed: _cancelEdit,
                child: const Text('수정 취소', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => _saveChanges(memberProvider),
                child: const Text('완료',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: displayData.isEmpty
          ? const Center(
              child: Text('대원을 추가해주세요.', style: TextStyle(color: Colors.grey)))
          : Column(
              children: [
                // ── 헤더: 왼쪽 고정 + 오른쪽 가로 스크롤 (본문과 동기화)
                Container(
                  color: const Color(0xFFF3F4F6),
                  child: Row(
                    children: [
                      _cell(_wNo, _headText('No'), height: 32),
                      _cell(_wGen, _headText('기수'), height: 32),
                      _cell(_wName, _headText('이름'), height: 32),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _hHead,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: _rightWidth,
                            child: Row(
                              children: [
                                _cell(_wType, _headText('구분'), height: 32),
                                _cell(_wGender, _headText('성별'), height: 32),
                                _cell(_wBlood, _headText('혈액형'), height: 32),
                                _cell(_wPhone, _headText('연락처'), height: 32),
                                _cell(_wEmergency, _headText('비상연락처'), height: 32),
                                _cell(_wHeight, _headText('신장'), height: 32),
                                _cell(_wShoe, _headText('족장'), height: 32),
                                if (_isEditMode)
                                  _cell(_wDelete, const SizedBox(), height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── 본문: 세로 스크롤 하나에 [고정 열들 | 가로 스크롤 열들]
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            for (var i = 0; i < displayData.length; i++)
                              _buildLeftCells(displayData[i], i),
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _hBody,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: _rightWidth,
                              child: Column(
                                children: [
                                  for (var i = 0; i < displayData.length; i++)
                                    _buildRightCells(
                                        auth, memberProvider, displayData[i], i),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: (auth.isAdmin && _isEditMode)
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _localData.add(MemberItem(
                    id: '',
                    name: '',
                    generation: '',
                    phone: '',
                    gender: 'male',
                    order: _localData.length, // 신규 대원은 마지막 순번
                  ));
                });
              },
              backgroundColor: Colors.blue[800],
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('대원 추가',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  // ------------------------------------------------------------- 표 구성

  Widget _cell(double width, Widget child,
      {Color? bg, double height = 36, VoidCallback? onTap}) {
    final cell = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          right: BorderSide(color: _line, width: 0.6),
          bottom: BorderSide(color: _line, width: 0.6),
        ),
      ),
      child: child,
    );
    if (onTap == null) return cell;
    return InkWell(onTap: onTap, child: cell);
  }

  Widget _headText(String text) => Text(text,
      style: TextStyle(
          fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey[700]));

  Text _plain(String text, {bool bold = false, Color? color}) => Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
      );

  /// 왼쪽 고정 열: No · 기수 · 이름 (가로 스크롤해도 남는다)
  Widget _buildLeftCells(MemberItem member, int index) {
    final bool enabled = _isEditMode;
    return Row(
      key: ValueKey(
          'L_${member.id.isEmpty ? 'new_${member.hashCode}_$index' : member.id}'),
      children: [
        _cell(_wNo, _plain('${index + 1}', color: Colors.grey[500])),
        enabled
            ? _cell(
                _wGen,
                _inlineTextField(
                  initialValue: member.generation,
                  hint: '기수',
                  textAlign: TextAlign.center,
                  enabled: enabled,
                  onChanged: (v) => _updateLocalItem(index, generation: v),
                ))
            : _cell(_wGen,
                _plain(member.generation.isEmpty ? '' : '${member.generation}기')),
        enabled
            ? _cell(
                _wName,
                _inlineTextField(
                  initialValue: member.name,
                  hint: '이름',
                  isBold: true,
                  textAlign: TextAlign.center,
                  enabled: enabled,
                  onChanged: (v) => _updateLocalItem(index, name: v),
                ))
            : _cell(_wName, _plain(member.name, bold: true)),
      ],
    );
  }

  /// 오른쪽 스크롤 열: 구분부터 끝까지
  Widget _buildRightCells(EquipmentProvider auth, MemberProvider provider,
      MemberItem member, int index) {
    final bool enabled = auth.isAdmin && _isEditMode;
    final bool isMale = member.gender == 'male';
    final bool isOb = member.memberType == 'OB';

    final plain = _plain;

    // 수정 모드에서 탭 전환 셀임을 알리는 옅은 배경
    final toggleBg = enabled ? const Color(0xFFF0F6FF) : null;

    // 💡 보기 모드에서 연락처 셀은 탭하면 복사된다
    Widget phoneCell(double width, String label, String value) {
      if (enabled) return const SizedBox.shrink();
      return _cell(
        width,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: plain(value)),
            if (value.trim().isNotEmpty) ...[
              const SizedBox(width: 3),
              Icon(Icons.copy, size: 10, color: Colors.grey[400]),
            ],
          ],
        ),
        onTap: () => _copyToClipboard(label, value),
      );
    }

    return Row(
      key: ValueKey(
          'R_${member.id.isEmpty ? 'new_${member.hashCode}_$index' : member.id}'),
      children: [
        _cell(
          _wType,
          plain(member.memberType),
          bg: toggleBg,
          onTap: enabled
              ? () => setState(
                  () => _updateLocalItem(index, memberType: isOb ? 'YB' : 'OB'))
              : null,
        ),
        _cell(
          _wGender,
          plain(isMale ? '남' : '여'),
          bg: toggleBg,
          onTap: enabled
              ? () => setState(
                  () => _updateLocalItem(index, gender: isMale ? 'female' : 'male'))
              : null,
        ),
        enabled
            ? _cell(
                _wBlood,
                _inlineTextField(
                  initialValue: member.bloodType,
                  hint: '혈액형',
                  textAlign: TextAlign.center,
                  enabled: enabled,
                  onChanged: (v) => _updateLocalItem(index, bloodType: v),
                ))
            : _cell(_wBlood, plain(member.bloodType)),
        enabled
            ? _cell(
                _wPhone,
                _inlineTextField(
                  initialValue: member.phone,
                  hint: '연락처',
                  textAlign: TextAlign.center,
                  enabled: enabled,
                  onChanged: (v) => _updateLocalItem(index, phone: v),
                ))
            : phoneCell(_wPhone, '연락처', member.phone),
        enabled
            ? _cell(
                _wEmergency,
                _inlineTextField(
                  initialValue: member.emergencyContact,
                  hint: '비상연락처',
                  textAlign: TextAlign.center,
                  enabled: enabled,
                  onChanged: (v) => _updateLocalItem(index, emergencyContact: v),
                ))
            : phoneCell(_wEmergency, '비상연락처', member.emergencyContact),
        enabled
            ? _cell(
                _wHeight,
                _inlineTextField(
                  initialValue: member.height,
                  hint: 'cm',
                  textAlign: TextAlign.center,
                  enabled: enabled,
                  onChanged: (v) => _updateLocalItem(index, height: v),
                ))
            : _cell(_wHeight, plain(member.height)),
        enabled
            ? _cell(
                _wShoe,
                _inlineTextField(
                  initialValue: member.shoeSize,
                  hint: 'mm',
                  textAlign: TextAlign.center,
                  enabled: enabled,
                  onChanged: (v) => _updateLocalItem(index, shoeSize: v),
                ))
            : _cell(_wShoe, plain(member.shoeSize)),
        if (_isEditMode)
          _cell(
            _wDelete,
            const Icon(Icons.remove_circle_outline, size: 15, color: Colors.redAccent),
            onTap: enabled
                ? () => _confirmDelete(context, provider, member, index)
                : null,
          ),
      ],
    );
  }

  Widget _inlineTextField({
    required String initialValue,
    required String hint,
    required bool enabled,
    required Function(String) onChanged,
    bool isBold = false,
    TextAlign textAlign = TextAlign.start,
  }) {
    return TextFormField(
      key: ValueKey('${initialValue}_$enabled'),
      initialValue: initialValue,
      enabled: enabled,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: 12,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 11, color: Colors.grey[300]),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: InputBorder.none,
      ),
      onChanged: onChanged,
    );
  }

  void _updateLocalItem(int index, {
    String? name, String? generation, String? phone, String? gender,
    String? emergencyContact, String? bloodType, String? height, String? shoeSize,
    String? memberType,
  }) {
    final m = _localData[index];
    _localData[index] = m.copyWith(
      name: name,
      generation: generation,
      phone: phone,
      gender: gender,
      emergencyContact: emergencyContact,
      bloodType: bloodType,
      height: height,
      shoeSize: shoeSize,
      memberType: memberType,
    );
  }

  void _confirmDelete(BuildContext context, MemberProvider provider, MemberItem member, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("대원 삭제"),
        content: Text("${member.name.isEmpty ? '이 대원' : member.name}을(를) 명단에서 삭제할까요?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (member.id.isNotEmpty) {
                await provider.deleteMember(member.id);
              }
              if (_isEditMode) {
                setState(() {
                  _localData.removeAt(index);
                });
              }
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
