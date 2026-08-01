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

/// 💡 신입생 가이드: 폴딩 마인드맵.
/// 처음엔 대분류 카드(이모티콘+이름)만 → 탭하면 오른쪽에 소분류 →
/// 소분류를 또 탭하면 구성품 칩이 펼쳐진다.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  /// 펼쳐진 대분류(단계) / 소분류(항목) — 접힘이 기본
  final Set<String> _openStages = {};
  final Set<String> _openItems = {};

  /// 이모티콘이 비어있는 옛 데이터용 기본값 (단계 순서별)
  static const List<String> _fallbackEmoji = ['🤿', '🔧', '🦺', '🌊', '🚿'];

  /// 다이얼로그 입력 컨트롤러 — State 소유 (dispose 크래시 방지)
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _emojiController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _emojiController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- 파서

  _GuideItem _parseLine(String line) {
    final match = RegExp(r'^(.*?)\s*\((.*)\)\s*$').firstMatch(line.trim());
    if (match == null) return _GuideItem(line.trim(), const [], const []);

    var inner = match.group(2)!.trim();
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
    _emojiController.text = section?.emoji ?? '';
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
              Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: TextField(
                      controller: _emojiController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                          labelText: '이모티콘', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                          labelText: '단계 이름 (예: 장비 체결)', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: '소분류 (한 줄 = 한 항목)',
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
                provider.addSection(
                    title, _contentController.text, _emojiController.text);
              } else {
                provider.updateSection(section.id, title,
                    _contentController.text, _emojiController.text);
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
      backgroundColor: const Color(0xFFF8F9FA),
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
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
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

  /// 단계 한 줄: [대분류 카드] ─(타임라인 노드)─ [펼쳐진 소분류]
  Widget _buildStage(GuideSection section, int index, bool isLast,
      bool isAdmin, GuideProvider provider) {
    final open = _openStages.contains(section.id);
    final emoji = section.emoji.isNotEmpty
        ? section.emoji
        : (index < _fallbackEmoji.length ? _fallbackEmoji[index] : '📌');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 대분류 카드 (탭 = 펼치기/접기)
          Expanded(
            flex: 5,
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: GestureDetector(
                onTap: () => setState(() {
                  open ? _openStages.remove(section.id) : _openStages.add(section.id);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: open ? Colors.blue[300]! : Colors.grey[200]!,
                        width: open ? 1.4 : 1),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 8),
                      Text(
                        '${index + 1}단계: ${section.title}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () =>
                              _showEditDialog(provider, section: section),
                          child: Icon(Icons.edit_outlined,
                              size: 14, color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 타임라인 (세로선 + 노드)
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 3,
                    color: index == 0 ? Colors.transparent : Colors.blue[700],
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: open ? Colors.blue[700] : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue[700]!, width: 2.5),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 3,
                    color: isLast ? Colors.transparent : Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),

          // ── 소분류 (펼쳤을 때만)
          Expanded(
            flex: 6,
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: open
                  ? _buildItems(section)
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  /// 소분류 카드: 항목 나열, 항목 탭하면 구성품 칩이 한 번 더 펼쳐진다
  Widget _buildItems(GuideSection section) {
    final items = section.content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map(_parseLine)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) _buildItem(section.id, i, items[i]),
        ],
      ),
    );
  }

  Widget _buildItem(String stageId, int index, _GuideItem item) {
    final key = '$stageId|$index';
    final hasSub = item.chips.isNotEmpty;
    final open = _openItems.contains(key);

    return GestureDetector(
      onTap: hasSub
          ? () => setState(() {
                open ? _openItems.remove(key) : _openItems.add(key);
              })
          : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.title,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                if (hasSub) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text('${item.chips.length}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800])),
                  ),
                  const SizedBox(width: 3),
                  Icon(open ? Icons.expand_less : Icons.expand_more,
                      size: 15, color: Colors.grey[500]),
                ],
              ],
            ),
            if (hasSub && open) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final chip in item.chips)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Text(chip,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
              for (final detail in item.details) ...[
                const SizedBox(height: 4),
                Text('· $detail',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
