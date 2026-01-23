import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class QnaScreen extends StatelessWidget {
  const QnaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 💡 context.watch를 사용하여 데이터 변경 시 즉시 리빌드되도록 함
    final provider = context.watch<EquipmentProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('❓ 질문과 답변', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      // 💡 수동 새로고침 기능을 추가하여 동기화 지연 시 대응
      body: RefreshIndicator(
        onRefresh: () async {
          // Provider에 강제 새로고침 로직이 있다면 호출, 없다면 리스너가 재작동하도록 유도
          // 여기서는 리스너가 살아있다는 전제하에 UI만 다시 그리는 트리거 역할
          provider.notifyListeners();
        },
        child: provider.qnaPosts.isEmpty
            ? const Center(
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Text('첫 질문을 남겨보세요!'),
          ),
        )
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(), // 리스트가 짧아도 당겨서 새로고침 가능하게 함
          padding: const EdgeInsets.all(16),
          itemCount: provider.qnaPosts.length,
          itemBuilder: (context, index) {
            final post = provider.qnaPosts[index];
            // 💡 고유한 ValueKey를 사용하여 삭제 시 리스트가 올바르게 재정렬되도록 함
            return _buildQnaCard(context, post, provider, ValueKey(post.id));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWriteDialog(context, provider),
        backgroundColor: Colors.blue[800],
        child: const Icon(Icons.create, color: Colors.white),
      ),
    );
  }

  Widget _buildQnaCard(BuildContext context, QnaPost post, EquipmentProvider provider, Key key) {
    final dateStr = DateFormat('MM/dd HH:mm').format(post.timestamp);
    final replyCount = post.replies.length;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[50],
          child: const Text('Q', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
        title: Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${post.author} • $dateStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: replyCount > 0 ? Colors.green[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '답변 $replyCount',
            style: TextStyle(fontSize: 10, color: replyCount > 0 ? Colors.green[700] : Colors.grey[600], fontWeight: FontWeight.bold),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(post.content, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
                const SizedBox(height: 20),
                const Text('답변 목록', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                if (post.replies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('아직 답변이 없습니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  )
                else
                  ...post.replies.map((reply) => _buildReplyItem(context, provider, post.id, reply)).toList(),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showReplyDialog(context, provider, post.id),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('답변 달기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.blue[800],
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 36),
                  ),
                ),
                if (provider.isAdmin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showDeleteConfirm(context, () async {
                        await provider.deleteQnaPost(post.id);
                      }, '게시글'),
                      icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                      label: const Text('게시글 삭제', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(BuildContext context, EquipmentProvider provider, String postId, QnaReply reply) {
    final dateStr = DateFormat('MM/dd HH:mm').format(reply.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(reply.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
              Row(
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  if (provider.isAdmin) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showDeleteConfirm(context, () async {
                        await provider.deleteQnaReply(postId, reply.id);
                      }, '답변'),
                      child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                    ),
                  ]
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(reply.content, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, Future<void> Function() onConfirm, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$type 삭제'),
        content: Text('정말로 이 $type을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 다이얼로그 먼저 닫기
              await onConfirm(); // 삭제 실행 대기
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showWriteDialog(BuildContext context, EquipmentProvider provider) {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        title: const Text('새 질문 작성', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: '작성자 이름', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder(), alignLabelWithHint: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty && authorController.text.isNotEmpty) {
                await provider.addQnaPost(titleController.text, contentController.text, authorController.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(BuildContext context, EquipmentProvider provider, String postId) {
    final authorController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        title: const Text('답변 남기기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: '작성자 이름', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: '답변 내용', border: OutlineInputBorder(), alignLabelWithHint: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (contentController.text.isNotEmpty && authorController.text.isNotEmpty) {
                await provider.addQnaReply(postId, contentController.text, authorController.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }
}