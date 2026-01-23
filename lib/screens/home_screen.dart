import 'package:flutter/material.dart';
import 'input_screen.dart';
import 'search_screen.dart';
import 'checklist_screen.dart';
import 'qna_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('KUST 동계 원정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () {}),
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

            // 💡 2x2 그리드 버튼 영역
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
            // 하단 퀵 공지나 정보 섹션 (필요시)
            _buildQuickInfoCard(),
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

  Widget _buildQuickInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[800]!, Colors.blue[600]!]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.campaign, color: Colors.white, size: 30),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('알림', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('내일 오전 8시 장비 총 점검 예정입니다.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}