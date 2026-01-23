import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  // 💡 공지사항 작성 및 수정을 통합한 다이얼로그
  void _showNoticeDialog(BuildContext context, EquipmentProvider provider, {NoticeItem? existingNotice}) {
    final bool isEdit = existingNotice != null;
    final titleController = TextEditingController(text: existingNotice?.title ?? "");
    final contentController = TextEditingController(text: existingNotice?.content ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // 💡 다이얼로그의 전체 너비를 화면의 90% 정도로 고정
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(
            isEdit ? '공지사항 수정' : '공지사항 작성',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        ),
        content: SizedBox(
          // 💡 다이얼로그 내부 너비를 명시적으로 설정하여 크게 보이게 함
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: '제목',
                  hintText: '공지 제목을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 8, // 💡 줄 수를 늘려 내용 칸을 더 크게 만듬
                decoration: const InputDecoration(
                  labelText: '내용',
                  hintText: '대원들에게 전달할 상세 내용을 입력하세요',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                if (isEdit) {
                  provider.updateNotice(existingNotice.id, titleController.text, contentController.text);
                } else {
                  provider.addNotice(titleController.text, contentController.text);
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEdit ? '공지사항이 수정되었습니다.' : '공지사항이 등록되었습니다.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
            ),
            child: Text(isEdit ? '수정 완료' : '등록'),
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
    final dateStr = DateFormat('yyyy.MM.dd HH:mm').format(notice.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE3F2FD),
          child: Icon(Icons.campaign, color: Colors.blue, size: 20),
        ),
        title: Text(
          notice.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                Text(
                  notice.content,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                ),
                if (provider.isAdmin)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 💡 수정 버튼 추가
                      TextButton.icon(
                        onPressed: () => _showNoticeDialog(context, provider, existingNotice: notice),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                        label: const Text('수정', style: TextStyle(color: Colors.blue, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      // 삭제 버튼
                      TextButton.icon(
                        onPressed: () {
                          _showDeleteConfirmDialog(context, provider, notice.id);
                        },
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        label: const Text('삭제', style: TextStyle(color: Colors.red, fontSize: 12)),
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

  void _showDeleteConfirmDialog(BuildContext context, EquipmentProvider provider, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지 삭제'),
        content: const Text('이 공지사항을 정말로 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
              onPressed: () {
                provider.deleteNotice(id);
                Navigator.pop(context);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}