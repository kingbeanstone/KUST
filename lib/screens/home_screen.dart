import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';
import 'input_screen.dart';
import 'search_screen.dart';
import 'checklist_screen.dart';
import 'qna_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider를 통해 관리자 여부 및 공지사항 데이터를 가져옵니다.
    final provider = context.watch<EquipmentProvider>();
    final isAdmin = provider.isAdmin;
    final latestNotice = provider.notices.isNotEmpty ? provider.notices.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('KUST 동계 원정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
                color: isAdmin ? Colors.blue : Colors.black87),
            onPressed: () {
              if (isAdmin) {
                // 관리자 로그아웃 혹은 설정 이동 로직 (필요시)
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 환영 메시지 영역
            const Text('안녕하세요, 대원님!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('오늘의 장비 점검을 잊지 마세요.', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 30),

            // 💡 메뉴 그리드 영역
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildMenuCard(
                  context,
                  title: '장비 목록',
                  subtitle: '대원 정보 입력',
                  icon: Icons.assignment_outlined,
                  color: Colors.blue,
                  target: const InputScreen(),
                ),
                _buildMenuCard(
                  context,
                  title: '장비 검색',
                  subtitle: '품목별 빠른 찾기',
                  icon: Icons.search_rounded,
                  color: Colors.orange,
                  target: const SearchScreen(),
                ),
                _buildMenuCard(
                  context,
                  title: '체크리스트',
                  subtitle: '최종 준비 확인',
                  icon: Icons.checklist_rtl_rounded,
                  color: Colors.green,
                  target: const ChecklistScreen(),
                ),
                _buildMenuCard(
                  context,
                  title: 'QnA',
                  subtitle: '궁금한 점 문의',
                  icon: Icons.question_answer_outlined,
                  color: Colors.purple,
                  target: const QnaScreen(),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 💡 하단 퀵 알림 카드 (관리자 편집 기능 포함)
            _buildQuickInfoCard(context, provider, latestNotice),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget target,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => target)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
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

  Widget _buildQuickInfoCard(BuildContext context, EquipmentProvider provider, NoticeItem? notice) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: provider.isAdmin
                  ? [Colors.blue[900]!, Colors.blue[700]!] // 관리자일 때 조금 더 진한 색상
                  : [Colors.blue[800]!, Colors.blue[600]!]
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ]
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: Colors.white, size: 32),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    notice?.title ?? '알림',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)
                ),
                const SizedBox(height: 2),
                Text(
                  notice?.content ?? '등록된 새로운 공지사항이 없습니다.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (provider.isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.white, size: 28),
              onPressed: () => _showEditNoticeDialog(context, provider, notice),
            ),
        ],
      ),
    );
  }

  // 💡 공지사항 수정/추가 다이얼로그
  void _showEditNoticeDialog(BuildContext context, EquipmentProvider provider, NoticeItem? existingNotice) {
    final titleController = TextEditingController(text: existingNotice?.title ?? '');
    final contentController = TextEditingController(text: existingNotice?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingNotice == null ? '새 알림 등록' : '알림 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '제목 (예: 긴급 공지)'),
            ),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(labelText: '내용'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                if (existingNotice == null) {
                  await provider.addNotice(titleController.text, contentController.text);
                } else {
                  await provider.updateNotice(existingNotice.id, titleController.text, contentController.text);
                }
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}