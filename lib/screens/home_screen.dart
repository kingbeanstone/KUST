import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/notice_provider.dart';
import '../models/notice_model.dart';
import 'input_screen.dart';
import 'search_screen.dart';
import 'checklist_screen.dart';
import 'qna_screen.dart';
import 'executive_checklist_screen.dart';
import 'member_management_screen.dart';
import 'buddy_screen.dart'; // 💡 신규 버디 화면 임포트

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final noticeProvider = Provider.of<NoticeProvider>(context);

    final isAdmin = equipmentProvider.isAdmin;
    final homeNotice = noticeProvider.homeNotice;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: _buildSideBar(context, equipmentProvider, isAdmin),
      appBar: AppBar(
        title: const Text('KUST 동계 원정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
              color: isAdmin ? Colors.blue : Colors.black87,
            ),
            onPressed: () {},
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('안녕하세요, 대원님!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('오늘의 장비 점검을 잊지 마세요.', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),

            _buildQuickNoticeCard(context, noticeProvider, isAdmin, homeNotice),

            const SizedBox(height: 24),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.15,
              children: [
                _buildMenuCard(context,
                    title: '장비 목록', subtitle: '대원 정보 입력',
                    icon: Icons.assignment_outlined, color: Colors.blue,
                    target: const InputScreen()),

                _buildMenuCard(context,
                    title: '체크리스트', subtitle: '최종 준비 확인',
                    icon: Icons.checklist_rtl_rounded, color: Colors.green,
                    target: const ChecklistScreen()),

                _buildMenuCard(context,
                    title: '장비 검색', subtitle: '품목별 빠른 찾기',
                    icon: Icons.search_rounded, color: Colors.orange,
                    target: const SearchScreen()),

                // 💡 [변경 완료] Placeholder를 지우고 실제 BuddyScreen으로 연결했습니다.
                _buildMenuCard(context,
                    title: '버디 시스템', subtitle: '다이빙 짝꿍 확인',
                    icon: Icons.people_outline_rounded, color: Colors.teal,
                    target: const BuddyScreen()),

                _buildMenuCard(context,
                    title: '임단 체크', subtitle: '임원진 전용 관리',
                    icon: isAdmin ? Icons.verified_user_outlined : Icons.lock_outline,
                    color: isAdmin ? Colors.indigo : Colors.grey,
                    target: const ExecutiveChecklistScreen(),
                    isAdminRequired: true,
                    isAdmin: isAdmin),

                _buildMenuCard(context,
                    title: 'QnA', subtitle: '궁금한 점 문의',
                    icon: Icons.question_answer_outlined, color: Colors.purple,
                    target: const QnaScreen()),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBar(BuildContext context, EquipmentProvider provider, bool isAdmin) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[800]),
            accountName: const Text('KUST 원정대원', style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(isAdmin ? '관리자 권한 활성화됨' : '일반 사용자 모드'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.blue[800], size: 40),
            ),
          ),
          ListTile(
            leading: Icon(isAdmin ? Icons.people_alt_outlined : Icons.lock_outline, color: Colors.black87),
            title: const Text('원정 멤버 관리', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('대원 명단 및 정보 수정', style: TextStyle(fontSize: 11)),
            onTap: () {
              if (!isAdmin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('관리자 인증이 필요한 메뉴입니다.'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MemberManagementScreen()));
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('v1.8.4', style: TextStyle(color: Colors.grey, fontSize: 12)),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () {
                      provider.logoutAdmin();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                    label: const Text('관리자 해제', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget target,
    bool isAdminRequired = false,
    bool isAdmin = true,
  }) {
    return GestureDetector(
      onTap: () {
        if (isAdminRequired && !isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이 메뉴는 임원진(관리자)만 접근할 수 있습니다.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (context) => target));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 8)
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28)
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black38)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNoticeCard(BuildContext context, NoticeProvider noticeProvider, bool isAdmin, NoticeItem? notice) {
    final bool isPinned = notice?.isPinned ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: isPinned
                  ? [Colors.blue[900]!, Colors.blue[700]!]
                  : [Colors.blue[800]!, Colors.blue[600]!]
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: isPinned ? Colors.indigo.withOpacity(0.3) : Colors.blue.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5)
            )
          ]
      ),
      child: Row(
        children: [
          Icon(isPinned ? Icons.push_pin : Icons.campaign, color: Colors.white, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isPinned ? '[필독] ${notice?.title ?? ""}' : (notice?.title ?? '최신 공지사항'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)
                ),
                const SizedBox(height: 2),
                Text(
                  notice?.content ?? '등록된 공지가 없습니다.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.white, size: 28),
              onPressed: () => _showQuickEditDialog(context, noticeProvider, notice),
            ),
        ],
      ),
    );
  }

  void _showQuickEditDialog(BuildContext context, NoticeProvider noticeProvider, NoticeItem? existingNotice) {
    final titleController = TextEditingController(text: existingNotice?.title ?? '');
    final contentController = TextEditingController(text: existingNotice?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingNotice == null ? '새 공지 등록' : '공지 내용 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '제목')),
            TextField(controller: contentController, decoration: const InputDecoration(labelText: '내용'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || contentController.text.isEmpty) return;
              if (existingNotice == null) {
                await noticeProvider.addNotice(titleController.text, contentController.text);
              } else {
                await noticeProvider.updateNotice(
                    existingNotice.id,
                    titleController.text,
                    contentController.text,
                    imageUrls: existingNotice.imageUrls
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('$title 기능 준비 중입니다.', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}