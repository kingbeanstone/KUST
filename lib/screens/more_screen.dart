import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../app_version.dart';
import '../providers/auth_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/executive_provider.dart';
import '../providers/qna_provider.dart';
import '../providers/notice_provider.dart';
import '../models/executive_model.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _rememberMe = false;
  bool _isSettingUp = false;
  bool _showDebugConsole = false;

  // 💡 알림 권한 상태를 뱃지 형태로 표시
  Widget _buildStatusBadge(AuthorizationStatus status) {
    String text = "알 수 없음";
    Color color = Colors.grey;

    switch (status) {
      case AuthorizationStatus.authorized:
        text = "허용됨";
        color = Colors.green;
        break;
      case AuthorizationStatus.denied:
        text = "거부됨";
        color = Colors.red;
        break;
      case AuthorizationStatus.provisional:
        text = "임시 허용";
        color = Colors.orange;
        break;
      case AuthorizationStatus.notDetermined:
        text = "설정 필요";
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.redAccent : Colors.blue[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 💡 모든 프로바이더를 구독하여 실시간 권한 변화를 감지합니다.
    final auth = context.watch<AuthProvider>();
    final equipProv = context.watch<EquipmentProvider>();
    final noticeProv = context.watch<NoticeProvider>();
    final execProv = context.watch<ExecutiveProvider>();
    final qnaProv = context.watch<QnaProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('더보기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 관리자 카드 (인증 및 해제 핵심부)
                  _buildAdminCard(auth, equipProv, noticeProv, execProv, qnaProv),

                  // 2. 실시간 알림 설정
                  _buildSettingTile(noticeProv),

                  // 3. 👥 임원단 소개 섹션
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('👥 임원단 소개', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (auth.isAdmin)
                          IconButton(
                              onPressed: () => _showExecutiveDialog(context, execProv),
                              icon: const Icon(Icons.person_add_alt_1, color: Colors.blue, size: 20)
                          ),
                      ],
                    ),
                  ),
                  _buildExecutiveList(execProv, auth.isAdmin),

                  // 4. 📱 앱 정보 섹션 (정보 삭제 기능 포함)
                  _buildAppInfoSection(context, auth, equipProv, noticeProv, execProv, qnaProv),

                  const SizedBox(height: 40),
                  const Center(child: Text('버전 정보 $kAppVersion', style: TextStyle(color: Colors.grey, fontSize: 11))),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // 5. 💡 시스템 로그 콘솔
          if (_showDebugConsole) _buildDebugConsole(auth),
        ],
      ),
    );
  }

  Widget _buildAdminCard(AuthProvider auth, EquipmentProvider equip, NoticeProvider notice, ExecutiveProvider exec, QnaProvider qna) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: auth.isAdmin ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: auth.isAdmin ? Colors.blue[200]! : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(auth.isAdmin ? Icons.admin_panel_settings : Icons.lock_outline, color: auth.isAdmin ? Colors.blue : Colors.grey, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auth.isAdmin ? '관리자 모드 활성' : '일반 사용자 모드', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(auth.isAdmin ? '모든 탭에서 데이터를 수정할 수 있습니다.' : '데이터 수정 권한이 없습니다.', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: auth.isAdmin
                ? () {
              // 관리자 해제 (비밀번호 기억 설정은 유지됨)
              auth.logout();
              equip.setAdminStatus(false);
              notice.setAdminStatus(false);
              exec.setAdminStatus(false);
              qna.setAdminStatus(false);
              _showToast("🔓 관리자 모드가 해제되었습니다.");
            }
                : () async {
              // 💡 [핵심] 기억하기가 되어있다면 다이얼로그 건너뛰고 즉시 인증
              if (auth.isPasswordSaved) {
                final success = await auth.authenticate("779", remember: true);
                if (success) {
                  equip.setAdminStatus(true);
                  notice.setAdminStatus(true);
                  exec.setAdminStatus(true);
                  qna.setAdminStatus(true);
                  _showToast("✅ 자동 인증되었습니다.");
                }
              } else {
                _showAdminAuthDialog(auth, equip, notice, exec, qna);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: auth.isAdmin ? Colors.white : Colors.blue,
                foregroundColor: auth.isAdmin ? Colors.blue : Colors.white,
                elevation: 0
            ),
            child: Text(auth.isAdmin ? '해제' : '인증'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(NoticeProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: ListTile(
        leading: _isSettingUp
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.notifications_active_outlined, color: Colors.orange),
        title: const Text('실시간 알림 설정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: const Text('공지사항 푸시 알림을 받습니다.', style: TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusBadge(provider.notificationStatus),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: _isSettingUp ? null : () async {
          setState(() => _isSettingUp = true);
          final success = await provider.setupNotifications();
          if (mounted) setState(() => _isSettingUp = false);
          if (success) _showToast("✅ 실시간 알림 설정 완료!");
        },
      ),
    );
  }

  Widget _buildExecutiveList(ExecutiveProvider provider, bool isAdmin) {
    if (provider.executives.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('등록된 임원단이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13))));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: provider.executives.map((ex) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
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
                          Row(children: [
                            Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(ex.generation, style: const TextStyle(fontSize: 12, color: Colors.blueGrey))
                          ]),
                          const SizedBox(height: 2),
                          Text(ex.position, style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(ex.phone, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        if (isAdmin)
                          GestureDetector(
                              onTap: () => _showExecutiveDialog(context, provider, existing: ex),
                              child: const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text('수정', style: TextStyle(color: Colors.grey, fontSize: 11, decoration: TextDecoration.underline))
                              )
                          )
                      ],
                    ),
                  ],
                ),
                if (ex.intro.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1, thickness: 0.5)),
                  Row(children: [
                    const Icon(Icons.format_quote, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(ex.intro, style: const TextStyle(fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic)))
                  ])
                ]
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAppInfoSection(BuildContext context, AuthProvider auth, EquipmentProvider equip, NoticeProvider notice, ExecutiveProvider exec, QnaProvider qna) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('📱 앱 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: const Text('KUST 앱 소개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showAppIntro(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined, color: Colors.blueGrey),
                title: const Text('디버그 로그 보기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                trailing: Switch(
                  value: _showDebugConsole,
                  onChanged: (val) => setState(() => _showDebugConsole = val),
                ),
              ),
              // 💡 저장된 비밀번호 정보를 삭제할 수 있는 관리자용 옵션
              if (auth.isPasswordSaved) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.no_accounts_outlined, color: Colors.redAccent),
                  title: const Text('관리자 인증 정보 삭제', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                  onTap: () async {
                    await auth.forgetAdminSetting();
                    equip.setAdminStatus(false);
                    notice.setAdminStatus(false);
                    exec.setAdminStatus(false);
                    qna.setAdminStatus(false);
                    _showToast("저장된 인증 정보가 삭제되었습니다.");
                  },
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDebugConsole(AuthProvider auth) {
    return Container(
      height: 180, width: double.infinity, color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.black,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SYSTEM LOGS', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  GestureDetector(
                      onTap: () => setState(() => _showDebugConsole = false),
                      child: const Icon(Icons.close, color: Colors.white, size: 14)
                  )
                ]
            ),
          ),
          Expanded(
              child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: auth.debugLogs.length,
                  itemBuilder: (context, index) => Text(
                      auth.debugLogs[index],
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')
                  )
              )
          ),
        ],
      ),
    );
  }

  void _showAdminAuthDialog(AuthProvider auth, EquipmentProvider equip, NoticeProvider notice, ExecutiveProvider exec, QnaProvider qna) {
    final TextEditingController pwdController = TextEditingController();
    // 다이얼로그 열릴 때 체크박스 상태 초기화
    _rememberMe = auth.isPasswordSaved;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('관리자 인증', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('비밀번호 3자리를 입력하세요.', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: pwdController, keyboardType: TextInputType.number, obscureText: true, maxLength: 3, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 10),
                decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setDialogState(() => _rememberMe = val ?? false)
                  ),
                  const Text('비밀번호 기억하기', style: TextStyle(fontSize: 13)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: () async {
                final success = await auth.authenticate(pwdController.text, remember: _rememberMe);
                if (success) {
                  // 💡 모든 데이터 Provider의 권한 상태 일괄 동기화
                  equip.setAdminStatus(true);
                  notice.setAdminStatus(true);
                  exec.setAdminStatus(true);
                  qna.setAdminStatus(true);

                  if (!mounted) return;
                  Navigator.pop(context);
                  _showToast("✅ 관리자 권한이 활성화되었습니다.");
                } else {
                  _showToast("❌ 비밀번호가 틀렸습니다.", isError: true);
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExecutiveDialog(BuildContext context, ExecutiveProvider provider, {ExecutiveItem? existing}) {
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
        builder: (context, setDialogState) => AlertDialog(
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
                TextField(controller: genController, decoration: const InputDecoration(labelText: '기수', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: posController, decoration: const InputDecoration(labelText: '직책', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '전화번호', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: introController, maxLength: 30, decoration: const InputDecoration(labelText: '한 줄 소개', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            if (isEdit) TextButton(onPressed: () { provider.deleteExecutive(existing.id); Navigator.pop(context); }, child: const Text('삭제', style: TextStyle(color: Colors.red))),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                final item = ExecutiveItem(id: existing?.id ?? "", gender: selectedGender, name: nameController.text, generation: genController.text, position: posController.text, phone: phoneController.text, intro: introController.text);
                isEdit ? provider.updateExecutive(item) : provider.addExecutive(item);
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderOption(StateSetter setDialogState, String value, String label, bool isSelected, Function(String) onSelect) {
    return GestureDetector(
      onTap: () => setDialogState(() => onSelect(value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.blue[50] : Colors.grey[100], borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.blue : Colors.transparent)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.blue : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  void _showAppIntro(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
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
                        'assets/images/best.png', width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(height: 200, width: double.infinity, color: Colors.grey[100], child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('안녕하세요! KUST 원정 앱입니다.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 12),
                    const Text(
                      '본 애플리케이션은 경북대학교 스킨스쿠버 동아리 KUST의 원정 운영을 위해 제작되었습니다. '
                          '춘계·하계·추계·동계 모든 원정의 데이터를 시즌별로 관리합니다.\n\n'
                          '주요 기능:\n'
                          '• 장비 체크 — 가방 단위 준비 현황과 장비 버디 공유 관리\n'
                          '• 버디 시스템 — 팀 편성, 입수 순서, 충돌 자동 검사\n'
                          '• 원정별 일정·식단 공유\n'
                          '• 동아리원 명단과 원정 참가자 관리\n\n'
                          'KUST 대원 여러분의 안전하고 즐거운 다이빙을 응원합니다!',
                      style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}