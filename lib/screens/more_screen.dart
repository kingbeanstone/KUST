import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../app_version.dart';
import '../util/app_update.dart';
import '../providers/auth_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/executive_provider.dart';
import '../providers/member_provider.dart';
import '../providers/participant_provider.dart';
import '../providers/qna_provider.dart';
import '../providers/notice_provider.dart';
import '../models/member_model.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _rememberMe = false;
  bool _isSettingUp = false;

  /// 한 줄 메시지 편집용 (State 소유 — dispose 크래시 방지)
  final TextEditingController _introController = TextEditingController();

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

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

                  // 2. 👥 이번 원정 임원단 — 참가자 관리의 역할 지정과 자동 연동
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 2),
                    child: Text('👥 이번 원정 임원단',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('원정 참가자 관리의 역할 지정과 자동으로 연동됩니다.',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  _buildExpeditionStaffList(context),

                  // 3. 📱 앱 정보 섹션 (정보 삭제 기능 포함)
                  _buildAppInfoSection(context, auth, equipProv, noticeProv, execProv, qnaProv),

                  // 4. 실시간 알림 설정 (맨 아래)
                  const SizedBox(height: 24),
                  _buildSettingTile(noticeProv),

                  const SizedBox(height: 40),
                  const Center(child: Text('버전 정보 $kAppVersion', style: TextStyle(color: Colors.grey, fontSize: 11))),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
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
          Icon(auth.isAdmin ? Icons.admin_panel_settings : Icons.lock_outline,
              color: auth.isAdmin
                  ? (auth.isDeveloper ? Colors.red[600] : Colors.blue)
                  : Colors.grey,
              size: 32),
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

  /// 💡 현재 원정 참가자의 직책(대장~총무)과 강사를 자동으로 보여준다.
  /// 이름·기수는 동아리원 명단에서 조인, 한 줄 메시지는 참가자 문서에 저장.
  Widget _buildExpeditionStaffList(BuildContext context) {
    final participantProvider = context.watch<ParticipantProvider>();
    final memberProvider = context.watch<MemberProvider>();
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final byId = {for (final m in memberProvider.members) m.id: m};

    // 직책별 담당자 수집
    final roleHolders = <String, List<MemberItem>>{};
    final instructors = <MemberItem>[];
    for (final id in participantProvider.participantIds) {
      final member = byId[id];
      if (member == null) continue;
      final role = participantProvider.staffRoleOf(id);
      if (role != null) roleHolders.putIfAbsent(role, () => []).add(member);
      if (participantProvider.isInstructor(id)) instructors.add(member);
    }

    if (roleHolders.isEmpty && instructors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('아직 지정된 임원이 없습니다.\n[원정 참가자 관리] 수정 모드에서 역할을 지정하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 임원단 (대장~총무)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                for (final entry in kStaffRoles.entries)
                  _staffTile(
                    emoji: kStaffRoleEmoji[entry.key] ?? '',
                    roleName: entry.value,
                    members: roleHolders[entry.key] ?? const [],
                    participantProvider: participantProvider,
                    isAdmin: isAdmin,
                  ),
              ],
            ),
          ),
        ),

        // ── 강사진 (임원 아님 — 별도 섹션)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text('⭐ 강사진',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: instructors.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('지정된 강사가 없습니다.',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      for (final m in instructors)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Colors.grey[100]!)),
                          ),
                          child: _personRow(m, participantProvider, isAdmin,
                              emoji: '⭐', roleName: '강사'),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _staffTile({
    required String emoji,
    required String roleName,
    required List<MemberItem> members,
    required ParticipantProvider participantProvider,
    required bool isAdmin,
  }) {
    final hasHolder = members.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(roleName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
          ),
          Expanded(
            child: !hasHolder
                ? Text('미지정',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final m in members)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _personRow(m, participantProvider, isAdmin,
                              emoji: emoji, roleName: roleName),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 이름·기수 + 한 마디 미리보기. 💡 탭하면 상세 미니 창이 뜬다.
  Widget _personRow(MemberItem m, ParticipantProvider participantProvider, bool isAdmin,
      {required String emoji, required String roleName}) {
    final intro = participantProvider.introOf(m.id);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPersonDialog(m, participantProvider, isAdmin,
          emoji: emoji, roleName: roleName),
      child: Row(
        children: [
          Text(m.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          if (m.generation.isNotEmpty)
            Text('${m.generation}기',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          const SizedBox(width: 10),
          Expanded(
            child: intro.isEmpty
                ? const SizedBox.shrink()
                : Text(
                    '❝ $intro',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54),
                  ),
          ),
          Icon(Icons.chevron_right, size: 16, color: Colors.grey[300]),
        ],
      ),
    );
  }

  /// 💡 사람 상세 미니 창: 역할·이름·기수·연락처·한 마디.
  /// 관리자는 이 창에서 한 마디를 바로 수정할 수 있다.
  void _showPersonDialog(
      MemberItem m, ParticipantProvider participantProvider, bool isAdmin,
      {required String emoji, required String roleName}) {
    final intro = participantProvider.introOf(m.id);
    _introController.text = intro;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$roleName ${m.name}'
                '${m.generation.isNotEmpty ? ' · ${m.generation}기' : ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone, size: 15, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  m.phone.isEmpty ? '연락처 미등록' : m.phone,
                  style: TextStyle(
                      fontSize: 14,
                      color: m.phone.isEmpty ? Colors.grey : Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isAdmin)
              TextField(
                controller: _introController,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '한 마디',
                  hintText: '예: 안전 다이빙! 무리하지 맙시다',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              )
            else if (intro.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote, size: 15, color: Colors.grey[400]),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(intro,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                            color: Colors.black54,
                            height: 1.4)),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext), child: const Text('닫기')),
          if (isAdmin)
            ElevatedButton(
              onPressed: () {
                participantProvider.setIntro(m.id, _introController.text);
                Navigator.pop(dialogContext);
              },
              child: const Text('저장'),
            ),
        ],
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
              // 💡 인앱 업데이트: 최신 버전 여부 표시 + 탭 한 번으로 갱신
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: AppUpdate.doc.snapshots(),
                builder: (context, snap) {
                  final latest =
                      (snap.data?.data()?['latest'] ?? '').toString();
                  final hasUpdate = AppUpdate.isNewer(latest);
                  return ListTile(
                    leading: Icon(
                      hasUpdate
                          ? Icons.system_update_alt
                          : Icons.verified_outlined,
                      color:
                          hasUpdate ? Colors.orange[700] : Colors.green[600],
                    ),
                    title: Text(
                        hasUpdate ? '새 버전 업데이트' : '앱 업데이트',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      hasUpdate
                          ? '$latest 나왔어요! (현재 ${AppUpdate.current}) — 탭하면 바로 업데이트'
                          : '최신 버전을 사용 중입니다 (${AppUpdate.current})',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    trailing: hasUpdate
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange[600],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('업데이트',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          )
                        : null,
                    onTap: () {
                      if (hasUpdate) {
                        _showToast('⬇️ 최신 버전으로 업데이트합니다...');
                        AppUpdate.apply();
                      } else {
                        _showToast('✅ 이미 최신 버전이에요!');
                      }
                    },
                  );
                },
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

}