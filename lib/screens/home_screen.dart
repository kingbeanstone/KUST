import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/notice_provider.dart';
import '../models/notice_model.dart';
import 'input_screen.dart';
import 'search_screen.dart';
import 'checklist_screen.dart';
import 'qna_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 💡 권한 정보와 공지 정보를 각각의 프로바이더에서 가져옵니다.
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final noticeProvider = Provider.of<NoticeProvider>(context);

    final isAdmin = equipmentProvider.isAdmin;
    final homeNotice = noticeProvider.homeNotice;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
            onPressed: () {
              // 필요 시 프로필 또는 더보기 탭으로 이동 로직 추가 가능
            },
          ),
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
            const SizedBox(height: 30),

            // 메인 메뉴 그리드
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildMenuCard(context, title: '장비 목록', subtitle: '대원 정보 입력', icon: Icons.assignment_outlined, color: Colors.blue, target: const InputScreen()),
                _buildMenuCard(context, title: '장비 검색', subtitle: '품목별 빠른 찾기', icon: Icons.search_rounded, color: Colors.orange, target: const SearchScreen()),
                _buildMenuCard(context, title: '체크리스트', subtitle: '최종 준비 확인', icon: Icons.checklist_rtl_rounded, color: Colors.green, target: const ChecklistScreen()),
                _buildMenuCard(context, title: 'QnA', subtitle: '궁금한 점 문의', icon: Icons.question_answer_outlined, color: Colors.purple, target: const QnaScreen()),
              ],
            ),

            const SizedBox(height: 30),

            // 💡 실시간 공지사항 퀵 카드 (NoticeProvider 연동)
            _buildQuickNoticeCard(context, noticeProvider, isAdmin, homeNotice),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required Widget target}) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => target)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 30)
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black38)),
          ],
        ),
      ),
    );
  }

  // 💡 공지사항 카드 UI
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
                color: isPinned ? Colors.indigo.withOpacity(0.4) : Colors.blue.withOpacity(0.3),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)
                ),
                const SizedBox(height: 2),
                Text(
                  notice?.content ?? '등록된 공지가 없습니다.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 💡 관리자라면 홈에서 바로 공지 수정 팝업을 띄울 수 있는 버튼
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.white, size: 28),
              onPressed: () => _showQuickEditDialog(context, noticeProvider, notice),
            ),
        ],
      ),
    );
  }

  // 💡 홈에서 간단히 공지를 수정할 수 있는 다이얼로그 (NoticeProvider 호출)
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