import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 💡 서비스 제안: 일반 사용자는 작성만, 관리자는 목록 열람.
/// 최상위 'suggestions' 컬렉션 — {content, name, timestamp}.

/// 제안 작성 다이얼로그 (누구나)
void showSuggestionDialog(BuildContext context) {
  final contentController = TextEditingController();
  final nameController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('💡 서비스 제안',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('필요한 기능이나 있으면 좋겠다 싶은 것,\n불편한 점 무엇이든 편하게 적어주세요!',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey[600], height: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: contentController,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '제안 내용',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '이름 (선택 — 비우면 익명)',
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: () async {
            final content = contentController.text.trim();
            if (content.isEmpty) return;
            await FirebaseFirestore.instance.collection('suggestions').add({
              'content': content,
              'name': nameController.text.trim(),
              'timestamp': DateTime.now().toIso8601String(),
            });
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('💡 제안이 전달됐어요! 감사합니다 🙏'),
              backgroundColor: Colors.black87,
              duration: Duration(seconds: 2),
            ));
          },
          child: const Text('보내기'),
        ),
      ],
    ),
  );
}

/// 제안 목록 (관리자 전용 열람)
class SuggestionListScreen extends StatelessWidget {
  const SuggestionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('💡 서비스 제안함',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('suggestions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text('아직 들어온 제안이 없습니다.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final name = (data['name'] ?? '').toString().trim();
              final time = (data['timestamp'] ?? '').toString();
              // '2026-08-05T21:03:11.123' → '8/5 21:03'
              String timeLabel = '';
              final dt = DateTime.tryParse(time);
              if (dt != null) {
                timeLabel =
                    '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((data['content'] ?? '').toString(),
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.5)),
                          const SizedBox(height: 6),
                          Text(
                            [name.isEmpty ? '익명' : name, timeLabel]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 16, color: Colors.grey[400]),
                      onPressed: () => docs[i].reference.delete(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
