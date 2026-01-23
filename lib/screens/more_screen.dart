import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _rememberMe = false;

  // 관리자 인증 다이얼로그
  void _showAdminAuthDialog(BuildContext context, EquipmentProvider provider) async {
    if (provider.isPasswordSaved) {
      await provider.authenticate("779");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장된 정보로 자동 인증되었습니다.')),
        );
      }
      return;
    }

    final TextEditingController _pwdController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('관리자 인증', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('비밀번호 3자리를 입력하세요.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: _pwdController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 3,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 10),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) {
                          setDialogState(() {
                            _rememberMe = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('비밀번호 기억하기', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              TextButton(
                onPressed: () async {
                  final success = await provider.authenticate(_pwdController.text, remember: _rememberMe);
                  if (!mounted) return;
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('관리자 인증에 성공했습니다.')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호가 틀렸습니다.'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 💡 앱 소개 상세 화면 (BottomSheet)
  void _showAppIntro(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('KUST 앱 소개', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/best.png', // 첨부하신 이미지 경로
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '안녕하세요! KUST 동계 원정 앱입니다.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '본 애플리케이션은 경북대학교 스킨스쿠버 동아리 KUST 동계 원정에서 대원들의 원활한 장비 관리와 정보 공유를 위해 제작되었습니다.\n\n'
                          '주요 기능:\n'
                          '• 개인 및 공용 장비 실시간 현황 확인\n'
                          '• 식단 및 원정 일정 공유\n'
                          '• 관리자 알림 및 QnA 게시판\n\n'
                          'KUST 대원 여러분의 안전하고 즐거운 다이빙을 응원합니다!',
                      style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 임원단 추가/수정 다이얼로그
  void _showExecutiveDialog(BuildContext context, EquipmentProvider provider, {ExecutiveItem? existing}) {
    final bool isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? "");
    final genController = TextEditingController(text: existing?.generation ?? "");
    final posController = TextEditingController(text: existing?.position ?? "");
    final phoneController = TextEditingController(text: existing?.phone ?? "");
    final introController = TextEditingController(text: existing?.intro ?? "");
    String selectedGender = existing?.gender ?? "male";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? '임원 정보 수정' : '새 임원 등록', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _genderOption(setDialogState, "male", "👦 남자", selectedGender == "male", (v) => selectedGender = v),
                      const SizedBox(width: 20),
                      _genderOption(setDialogState, "female", "👧 여자", selectedGender == "female", (v) => selectedGender = v),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: genController, decoration: const InputDecoration(labelText: '기수', hintText: '예: 25기', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: posController, decoration: const InputDecoration(labelText: '직책', hintText: '예: 회장', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '전화번호', hintText: '010-0000-0000', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                    controller: introController,
                    maxLength: 30,
                    decoration: const InputDecoration(labelText: '한 줄 소개', hintText: '간단한 각오나 소개를 입력하세요.', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              if (isEdit)
                TextButton(
                  onPressed: () {
                    provider.deleteExecutive(existing.id);
                    Navigator.pop(context);
                  },
                  child: const Text('삭제', style: TextStyle(color: Colors.red)),
                ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty) return;
                  final item = ExecutiveItem(
                    id: existing?.id ?? "",
                    gender: selectedGender,
                    name: nameController.text,
                    generation: genController.text,
                    position: posController.text,
                    phone: phoneController.text,
                    intro: introController.text,
                  );
                  if (isEdit) {
                    provider.updateExecutive(item);
                  } else {
                    provider.addExecutive(item);
                  }
                  Navigator.pop(context);
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _genderOption(StateSetter setDialogState, String value, String label, bool isSelected, Function(String) onSelect) {
    return GestureDetector(
      onTap: () {
        setDialogState(() => onSelect(value));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.blue : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.blue : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EquipmentProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('더보기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 관리자 상태 카드
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: provider.isAdmin ? Colors.blue[50] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: provider.isAdmin ? Colors.blue[200]! : Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isAdmin ? Icons.admin_panel_settings : Icons.lock_outline,
                    color: provider.isAdmin ? Colors.blue : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.isAdmin ? '관리자 모드 활성' : '일반 사용자 모드',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          provider.isAdmin ? '모든 데이터를 수정할 수 있습니다.' : '데이터 수정 권한이 없습니다.',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: provider.isAdmin
                        ? () => provider.logoutAdmin()
                        : () => _showAdminAuthDialog(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.isAdmin ? Colors.white : Colors.blue,
                      foregroundColor: provider.isAdmin ? Colors.blue : Colors.white,
                      elevation: 0,
                    ),
                    child: Text(provider.isAdmin ? '해제' : '인증'),
                  ),
                ],
              ),
            ),

            // 임원단 소개 섹션
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('👥 임원단 소개', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (provider.isAdmin)
                    IconButton(
                      onPressed: () => _showExecutiveDialog(context, provider),
                      icon: const Icon(Icons.person_add_alt_1, color: Colors.blue, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            if (provider.executives.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('등록된 임원단이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: provider.executives.length,
                itemBuilder: (context, index) {
                  final ex = provider.executives[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(ex.gender == "male" ? "👦" : "👧", style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(width: 6),
                                      Text(ex.generation, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(ex.position, style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(ex.phone, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                if (provider.isAdmin)
                                  GestureDetector(
                                    onTap: () => _showExecutiveDialog(context, provider, existing: ex),
                                    child: const Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text('수정', style: TextStyle(color: Colors.grey, fontSize: 11, decoration: TextDecoration.underline)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (ex.intro.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(height: 1, thickness: 0.5),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.format_quote, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  ex.intro,
                                  style: const TextStyle(fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

            // 💡 앱 정보 섹션 (새로 추가됨)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('📱 앱 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: const Text('KUST 앱 소개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showAppIntro(context),
              ),
            ),

            const SizedBox(height: 40),
            const Center(child: Text('버전 정보 v1.6.0', style: TextStyle(color: Colors.grey, fontSize: 11))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}