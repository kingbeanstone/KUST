import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  // --- 공지 작성/수정 다이얼로그 ---
  void _showNoticeDialog(BuildContext context, EquipmentProvider provider, {NoticeItem? existingNotice}) {
    final bool isEdit = existingNotice != null;
    final titleController = TextEditingController(text: existingNotice?.title ?? "");
    final contentController = TextEditingController(text: existingNotice?.content ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(isEdit ? '공지사항 수정' : '공지사항 작성',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 8,
                decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                if (isEdit) {
                  provider.updateNotice(existingNotice.id, titleController.text, contentController.text);
                } else {
                  provider.addNotice(titleController.text, contentController.text);
                }
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
            child: Text(isEdit ? '수정 완료' : '등록'),
          ),
        ],
      ),
    );
  }

  // --- 푸시 알림 전송 확인 다이얼로그 ---
  void _showPushConfirmDialog(BuildContext context, EquipmentProvider provider, NoticeItem notice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('푸시 알림 전송'),
        content: Text("'${notice.title}' 공지를 모든 대원에게 알림으로 보낼까요?\n(등록된 모든 기기에 직접 발송됩니다.)"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.sendNoticePush(notice);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('알림 전송 프로세스가 시작되었습니다. 디버그 로그를 확인하세요.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('지금 전송'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EquipmentProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('📢 공지사항', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (provider.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined, color: Colors.blue),
              onPressed: () => _showNoticeDialog(context, provider),
            ),
        ],
      ),
      body: provider.notices.isEmpty
          ? const Center(child: Text('등록된 공지사항이 없습니다.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.notices.length,
        itemBuilder: (context, index) {
          final notice = provider.notices[index];
          return _buildNoticeCard(context, provider, notice);
        },
      ),
    );
  }

  Widget _buildNoticeCard(BuildContext context, EquipmentProvider provider, NoticeItem notice) {
    // 날짜 형식 변환 (문자열 -> DateTime -> String)
    String dateStr;
    try {
      final dt = DateTime.parse(notice.timestamp);
      dateStr = DateFormat('yyyy.MM.dd HH:mm').format(dt);
    } catch (e) {
      dateStr = notice.timestamp;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // 💡 홈 화면 게시 중인 공지는 테두리 강조
        border: Border.all(color: notice.isPinned ? Colors.blue[300]! : Colors.grey[200]!, width: notice.isPinned ? 2 : 1),
        boxShadow: notice.isPinned ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 8)] : null,
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Row(
          children: [
            if (notice.isPinned)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.push_pin, size: 16, color: Colors.blue),
              ),
            Expanded(child: Text(notice.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          ],
        ),
        subtitle: Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(notice.content, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
                const SizedBox(height: 16),
                if (provider.isAdmin)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 💡 홈 화면 게시(고정) 버튼
                      _actionButton(
                        onPressed: () => provider.pinNotice(notice.id),
                        icon: notice.isPinned ? Icons.home : Icons.home_outlined,
                        label: notice.isPinned ? '홈 게시 중' : '홈 게시',
                        color: notice.isPinned ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      // 푸시 알림 전송 버튼
                      _actionButton(
                        onPressed: () => _showPushConfirmDialog(context, provider, notice),
                        icon: Icons.notifications_active_outlined,
                        label: '알림',
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      // 수정 버튼
                      _actionButton(
                        onPressed: () => _showNoticeDialog(context, provider, existingNotice: notice),
                        icon: Icons.edit_outlined,
                        label: '수정',
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 8),
                      // 삭제 버튼
                      _actionButton(
                        onPressed: () => _showDeleteConfirmDialog(context, provider, notice.id),
                        icon: Icons.delete_outline,
                        label: '삭제',
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 버튼 스타일 공통 위젯
  Widget _actionButton({required VoidCallback onPressed, required IconData icon, required String label, required Color color}) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, EquipmentProvider provider, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지 삭제'),
        content: const Text('정말로 이 공지사항을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              provider.deleteNotice(id);
              Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}