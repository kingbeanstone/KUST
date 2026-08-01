import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/guide_provider.dart';

/// 💡 신입생 가이드: 장비 준비 → 체결 → 입수 전 점검.
/// 내용은 관리자(훈련부장)가 앱에서 바로 수정한다.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  /// 다이얼로그 입력 컨트롤러 — State 소유 (dispose 크래시 방지)
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _showEditDialog(GuideProvider provider, {GuideSection? section}) {
    _titleController.text = section?.title ?? '';
    _contentController.text = section?.content ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(section == null ? '섹션 추가' : '섹션 수정',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: '제목 (예: 🔧 장비 체결 순서)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 6,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: '내용 (줄바꿈으로 항목 구분)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소')),
          if (section != null)
            TextButton(
              onPressed: () {
                provider.deleteSection(section.id);
                Navigator.pop(dialogContext);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () {
              final title = _titleController.text.trim();
              if (title.isEmpty) return;
              if (section == null) {
                provider.addSection(title, _contentController.text);
              } else {
                provider.updateSection(
                    section.id, title, _contentController.text);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final provider = context.watch<GuideProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🤿 신입생 가이드',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: provider.sections.isEmpty
          ? Center(
              child: Text(
                isAdmin ? '섹션을 추가해주세요.' : '아직 내용이 없습니다.',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
              children: [
                for (final section in provider.sections)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(section.title,
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (isAdmin)
                              GestureDetector(
                                onTap: () => _showEditDialog(provider,
                                    section: section),
                                child: Icon(Icons.edit_outlined,
                                    size: 16, color: Colors.grey[400]),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(section.content,
                            style: const TextStyle(
                                fontSize: 13, height: 1.65)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Center(
                  child: Text('※ 실제 교육에서는 강사·훈련부장의 지시가 우선입니다.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ),
              ],
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showEditDialog(provider),
              backgroundColor: Colors.blue[800],
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('섹션 추가',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}
