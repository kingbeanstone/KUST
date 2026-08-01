import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/guide_provider.dart';

/// 파싱된 가이드 항목: "제목 (부품1, 부품2, 이름: 상세)" 한 줄 → 칩 구조
class _GuideItem {
  final String title;
  final List<String> chips;
  final List<String> details; // '이름: 상세' 형태의 부연
  _GuideItem(this.title, this.chips, this.details);
}

/// 💡 신입생 가이드: 아침 준비부터 반납·세척까지를
/// 마인드맵식 타임라인(단계 → 항목 → 구성품 칩)으로 보여준다.
/// 데이터는 텍스트라 관리자(훈련부장)가 앱에서 그대로 수정할 수 있다.
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

  // ------------------------------------------------------------- 파서

  /// 한 줄 → 항목. "슈트 입기 (슈트, 부츠, 조끼, 후드)" 형태면 괄호 안을 칩으로.
  /// 칩에 "이름: 상세"가 있으면 칩은 이름만, 상세는 아래 부연으로.
  _GuideItem _parseLine(String line) {
    final match = RegExp(r'^(.*?)\s*\((.*)\)\s*$').firstMatch(line.trim());
    if (match == null) return _GuideItem(line.trim(), const [], const []);

    var inner = match.group(2)!.trim();
    // 앞에 "6:" 같은 수동 개수 표기가 있으면 제거 (개수는 자동 계산)
    inner = inner.replaceFirst(RegExp(r'^\d+\s*[:：]\s*'), '');

    final chips = <String>[];
    final details = <String>[];
    for (final raw in inner.split(',')) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      final colon = part.indexOf(':');
      if (colon > 0) {
        final name = part.substring(0, colon).trim();
        chips.add(name);
        details.add('$name — ${part.substring(colon + 1).trim()}');
      } else {
        chips.add(part);
      }
    }
    return _GuideItem(match.group(1)!.trim(), chips, details);
  }

  // ------------------------------------------------------------- 수정

  void _showEditDialog(GuideProvider provider, {GuideSection? section}) {
    _titleController.text = section?.title ?? '';
    _contentController.text = section?.content ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(section == null ? '단계 추가' : '단계 수정',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: '단계 이름 (예: 장비 체결)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: '항목 (한 줄 = 한 항목)',
                  hintText: '수영복\n슈트 입기 (슈트, 부츠, 조끼, 후드)\n레귤 (1단계, 2단계, 공기체크: 200바·인플·디플)',
                  hintStyle: TextStyle(fontSize: 11.5),
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

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final provider = context.watch<GuideProvider>();
    final sections = provider.sections;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('🤿 신입생 가이드',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: sections.isEmpty
          ? Center(
              child: Text(
                isAdmin ? '단계를 추가해주세요.' : '아직 내용이 없습니다.',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                for (var i = 0; i < sections.length; i++)
                  _buildStage(sections[i], i, i == sections.length - 1,
                      isAdmin, provider),
              ],
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showEditDialog(provider),
              backgroundColor: Colors.blue[800],
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('단계 추가',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  /// 단계 하나: 왼쪽 번호 노드·연결선 + 오른쪽 항목들
  Widget _buildStage(GuideSection section, int index, bool isLast,
      bool isAdmin, GuideProvider provider) {
    final items = section.content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map(_parseLine)
        .toList();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 타임라인 노드 + 연결선
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue[800],
                    shape: BoxShape.circle,
                  ),
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: Colors.blue[100]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── 단계 내용
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(section.title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                      if (isAdmin)
                        GestureDetector(
                          onTap: () =>
                              _showEditDialog(provider, section: section),
                          child: Icon(Icons.edit_outlined,
                              size: 15, color: Colors.grey[400]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final item in items) _buildItem(item),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 항목 하나: 제목 [개수] + 구성품 칩 + 부연
  Widget _buildItem(_GuideItem item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(item.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (item.chips.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${item.chips.length}',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800])),
                ),
              ],
            ],
          ),
          if (item.chips.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final chip in item.chips)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Text(chip,
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ],
          for (final detail in item.details) ...[
            const SizedBox(height: 5),
            Text('· $detail',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }
}
