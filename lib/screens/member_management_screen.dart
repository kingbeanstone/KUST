import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_provider.dart';
import '../models/member_model.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  bool _isEditMode = false;
  List<MemberItem> _localData = [];

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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<EquipmentProvider>(context);
    final memberProvider = Provider.of<MemberProvider>(context);

    final List<MemberItem> displayData = _isEditMode ? _localData : memberProvider.members;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('👥 동아리원 명단', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          if (auth.isAdmin) ...[
            if (!_isEditMode)
              TextButton(
                onPressed: () => _enterEditMode(memberProvider.members),
                child: const Text('수정', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              )
            else ...[
              TextButton(
                onPressed: _cancelEdit,
                child: const Text('수정 취소', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => _saveChanges(memberProvider),
                child: const Text('완료', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: displayData.isEmpty
          ? const Center(child: Text('대원을 추가해주세요.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: displayData.length,
        itemBuilder: (context, index) {
          final member = displayData[index];
          return _buildInlineEditableCard(context, auth, memberProvider, member, index);
        },
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
        label: const Text('대원 추가', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      )
          : null,
    );
  }

  Widget _buildInlineEditableCard(BuildContext context, EquipmentProvider auth, MemberProvider provider, MemberItem member, int index) {
    final bool enabled = auth.isAdmin && _isEditMode;
    final bool isMale = member.gender == 'male';
    final bool isOb = member.memberType == 'OB';

    return Container(
      key: ValueKey(member.id.isEmpty ? 'new_${member.hashCode}_$index' : member.id),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: enabled ? Colors.blue[100]! : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // ── 1줄: 성별 · 이름 · 기수 · OB/YB · 혈액형 · (삭제)
          Row(
            children: [
              SizedBox(
                width: 18,
                child: Text('${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400])),
              ),
              const SizedBox(width: 4),
              // 💡 배치: 기수 → 이름 → YB/OB … 성별 → 혈액형
              _inlineTextField(
                initialValue: member.generation,
                hint: "기수",
                width: 36,
                fontSize: 11,
                textColor: Colors.grey,
                enabled: enabled,
                onChanged: (v) => _updateLocalItem(index, generation: v),
              ),
              const SizedBox(width: 6),
              _inlineTextField(
                initialValue: member.name,
                hint: "이름",
                width: 64,
                isBold: true,
                enabled: enabled,
                onChanged: (v) => _updateLocalItem(index, name: v),
              ),
              const SizedBox(width: 4),
              // 💡 OB/YB 구분 뱃지 (수정 모드에서 탭하면 전환)
              GestureDetector(
                onTap: enabled
                    ? () => setState(() =>
                        _updateLocalItem(index, memberType: isOb ? 'YB' : 'OB'))
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOb ? Colors.indigo[50] : Colors.teal[50],
                    borderRadius: BorderRadius.circular(6),
                    border: enabled
                        ? Border.all(color: isOb ? Colors.indigo[200]! : Colors.teal[200]!)
                        : null,
                  ),
                  child: Text(
                    member.memberType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isOb ? Colors.indigo : Colors.teal[700],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // 💡 성별: 글자 뱃지 (수정 모드에서 탭하면 전환)
              GestureDetector(
                onTap: enabled
                    ? () => setState(() =>
                        _updateLocalItem(index, gender: isMale ? 'female' : 'male'))
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMale ? Colors.blue[50] : Colors.pink[50],
                    borderRadius: BorderRadius.circular(6),
                    border: enabled
                        ? Border.all(color: isMale ? Colors.blue[200]! : Colors.pink[200]!)
                        : null,
                  ),
                  child: Text(
                    isMale ? '남' : '여',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isMale ? Colors.blue[700] : Colors.pink[400],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _inlineTextField(
                initialValue: member.bloodType,
                hint: "혈액형",
                width: 40,
                fontSize: 11,
                textColor: Colors.redAccent,
                textAlign: TextAlign.center,
                enabled: enabled,
                onChanged: (v) => _updateLocalItem(index, bloodType: v),
              ),
              if (enabled)
                GestureDetector(
                  onTap: () => _confirmDelete(context, provider, member, index),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.remove_circle_outline, size: 16, color: Colors.redAccent),
                  ),
                ),
            ],
          ),

          // ── 2줄: 연락처 · 비상연락처 · 신장 · 족장
          Row(
            children: [
              const SizedBox(width: 22),
              const Icon(Icons.phone, size: 10, color: Colors.blue),
              const SizedBox(width: 3),
              Expanded(
                child: _inlineTextField(
                  initialValue: member.phone,
                  hint: "연락처",
                  fontSize: 10.5,
                  enabled: enabled,
                  onChanged: (v) => _updateLocalItem(index, phone: v),
                ),
              ),
              const Icon(Icons.emergency, size: 10, color: Colors.red),
              const SizedBox(width: 3),
              Expanded(
                child: _inlineTextField(
                  initialValue: member.emergencyContact,
                  hint: "비상연락처",
                  fontSize: 10.5,
                  enabled: enabled,
                  onChanged: (v) => _updateLocalItem(index, emergencyContact: v),
                ),
              ),
              const SizedBox(width: 6),
              _inlineTextField(
                initialValue: member.height,
                hint: "000",
                width: 30,
                fontSize: 10.5,
                enabled: enabled,
                onChanged: (v) => _updateLocalItem(index, height: v),
              ),
              Text("cm", style: TextStyle(fontSize: 9.5, color: Colors.grey[400])),
              const SizedBox(width: 6),
              _inlineTextField(
                initialValue: member.shoeSize,
                hint: "000",
                width: 30,
                fontSize: 10.5,
                enabled: enabled,
                onChanged: (v) => _updateLocalItem(index, shoeSize: v),
              ),
              Text("mm", style: TextStyle(fontSize: 9.5, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }
  Widget _inlineTextField({
    required String initialValue,
    required String hint,
    required bool enabled,
    required Function(String) onChanged,
    double? width,
    double fontSize = 13,
    bool isBold = false,
    Color? textColor,
    TextAlign textAlign = TextAlign.start,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('${initialValue}_$enabled'),
        initialValue: initialValue,
        enabled: enabled,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: textColor ?? Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey[300]),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: enabled ? const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 0.5)) : InputBorder.none,
        ),
        onChanged: onChanged,
      ),
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