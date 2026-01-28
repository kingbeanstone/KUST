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
import 'buddy_screen.dart';

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

            // 💡 3행 2열 그리드 구성
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              // 💡 부제목이 빠져서 높이를 줄이기 위해 비율 조정 (1.15 -> 1.4)
              childAspectRatio: 1.4,
              children: [
                // 1행: 장비 목록, 장비 체크
                _buildMenuCard(context,
                    title: '장비 목록',
                    icon: Icons.assignment_outlined, color: Colors.blue,
                    target: const InputScreen(),
                    isAdminRequired: false,
                    isAdmin: isAdmin),
                _buildMenuCard(context,
                    title: '장비 체크',
                    icon: Icons.checklist_rtl_rounded, color: Colors.green,
                    target: const ChecklistScreen()),

                // 2행: 장비 검색, 버디 시스템
                _buildMenuCard(context,
                    title: '장비 검색',
                    icon: Icons.search_rounded, color: Colors.orange,
                    target: const SearchScreen()),
                _buildMenuCard(context,
                    title: '버디 시스템',
                    icon: Icons.people_outline_rounded, color: Colors.teal,
                    target: const BuddyScreen()),

                // 3행: 임단 체크, QnA
                _buildMenuCard(context,
                    title: '임단 체크',
                    icon: isAdmin ? Icons.verified_user_outlined : Icons.lock_outline,
                    color: isAdmin ? Colors.indigo : Colors.grey,
                    target: const ExecutiveChecklistScreen(),
                    isAdminRequired: true,
                    isAdmin: isAdmin),
                _buildMenuCard(context,
                    title: 'QnA',
                    icon: Icons.question_answer_outlined, color: Colors.purple,
                    target: const QnaScreen()),
              ],
            ),

            const SizedBox(height: 32),

            // 💡 알림 배너 (버튼들 아래 위치)
            _buildQuickNoticeCard(context, noticeProvider, isAdmin, homeNotice),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 사이드바 구성
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

          _drawerItem(
            context,
            icon: isAdmin ? Icons.people_alt_outlined : Icons.lock_outline,
            title: '원정 멤버 관리',
            subtitle: '대원 명단 및 정보 수정',
            isAdmin: isAdmin,
            target: const MemberManagementScreen(),
          ),

          _drawerItem(
            context,
            icon: isAdmin ? Icons.assignment_outlined : Icons.lock_outline,
            title: '장비 목록 관리',
            subtitle: '대원별 장비 정보 입력/수정',
            isAdmin: isAdmin,
            target: const InputScreen(),
          ),

          _drawerItem(
            context,
            icon: isAdmin ? Icons.verified_user_outlined : Icons.lock_outline,
            title: '임원단 체크리스트',
            subtitle: '임원진 전용 업무 관리',
            isAdmin: isAdmin,
            target: const ExecutiveChecklistScreen(),
          ),

          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('v1.8.8', style: TextStyle(color: Colors.grey, fontSize: 12)),
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

  // 사이드바 아이템 공통 위젯
  Widget _drawerItem(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isAdmin,
    required Widget target
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      onTap: () {
        if (!isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('관리자 인증이 필요한 메뉴입니다.'), backgroundColor: Colors.redAccent),
          );
          return;
        }
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => target));
      },
    );
  }

  // 💡 메뉴 카드 위젯 (제목만 표시하도록 수정)
  Widget _buildMenuCard(BuildContext context, {
    required String title,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 26)
            ),
            const SizedBox(height: 10),
            Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
            ),
          ],
        ),
      ),
    );
  }

  // 💡 알림 배너 카드
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

  // 공지사항 빠른 수정 다이얼로그
  void _showQuickEditDialog(BuildContext context, NoticeProvider noticeProvider, NoticeItem? existingNotice) {
    final titleController = TextEditingController(text: existingNotice?.title ?? '');
    final contentController = TextEditingController(text: existingNotice?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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