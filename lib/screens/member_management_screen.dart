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

    // 💡 [핵심 수정] 현재 리스트의 인덱스를 order로 할당하여 순서 저장
    for (int i = 0; i < _localData.length; i++) {
      final memberWithOrder = _localData[i].copyWith(order: i);

      if (memberWithOrder.id.isEmpty) {
        await provider.addMember(memberWithOrder);
      } else {
        await provider.updateMember(memberWithOrder);
      }
    }

    setState(() {
      _isEditMode = false;
      _localData = [];
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정렬 순서와 변경 사항이 저장되었습니다.')),
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
        title: const Text('👥 원정 대원 명단', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          : _isEditMode
          ? ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: displayData.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _localData.removeAt(oldIndex);
            _localData.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final member = displayData[index];
          return _buildInlineEditableCard(context, auth, memberProvider, member, index);
        },
      )
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

    return Container(
      key: ValueKey(member.id.isEmpty ? 'new_${member.hashCode}_$index' : member.id),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: enabled ? Colors.blue[100]! : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 36,
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: enabled
                ? () => _updateLocalItem(index, gender: member.gender == 'male' ? 'female' : 'male')
                : null,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: member.gender == 'male' ? Colors.blue[50] : Colors.red[50],
              child: Text(member.gender == 'male' ? '👦' : '👧', style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _inlineTextField(
                      initialValue: member.name,
                      hint: "이름",
                      width: 70,
                      isBold: true,
                      enabled: enabled,
                      onChanged: (v) => _updateLocalItem(index, name: v),
                    ),
                    const SizedBox(width: 4),
                    _inlineTextField(
                      initialValue: member.generation,
                      hint: "기수",
                      width: 50,
                      fontSize: 11,
                      textColor: Colors.grey,
                      enabled: enabled,
                      onChanged: (v) => _updateLocalItem(index, generation: v),
                    ),
                    const Spacer(),
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
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, provider, member, index),
                      ),
                  ],
                ),

                Row(
                  children: [
                    const Icon(Icons.phone, size: 10, color: Colors.blue),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _inlineTextField(
                        initialValue: member.phone,
                        hint: "본인 연락처",
                        fontSize: 11,
                        enabled: enabled,
                        onChanged: (v) => _updateLocalItem(index, phone: v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.emergency, size: 10, color: Colors.red),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _inlineTextField(
                        initialValue: member.emergencyContact,
                        hint: "비상 연락처",
                        fontSize: 11,
                        enabled: enabled,
                        onChanged: (v) => _updateLocalItem(index, emergencyContact: v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text("신장: ", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    _inlineTextField(
                      initialValue: member.height,
                      hint: "000",
                      width: 40,
                      fontSize: 11,
                      enabled: enabled,
                      onChanged: (v) => _updateLocalItem(index, height: v),
                    ),
                    const Text("cm", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 20),
                    const Text("족장: ", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    _inlineTextField(
                      initialValue: member.shoeSize,
                      hint: "000",
                      width: 40,
                      fontSize: 11,
                      enabled: enabled,
                      onChanged: (v) => _updateLocalItem(index, shoeSize: v),
                    ),
                    const Text("mm", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          if (enabled)
            const Padding(
              padding: EdgeInsets.only(top: 10, left: 8),
              child: Icon(Icons.drag_handle, color: Colors.grey, size: 20),
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
    String? emergencyContact, String? bloodType, String? height, String? shoeSize
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