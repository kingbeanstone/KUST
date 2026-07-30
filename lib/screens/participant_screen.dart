import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member_model.dart';
import '../providers/equipment_provider.dart';
import '../providers/expedition_provider.dart';
import '../providers/member_provider.dart';
import '../providers/participant_provider.dart';

/// 💡 v2: 원정 참가자 화면.
///  - 보기 모드: 참가자만 기수별로 표시
///  - 수정 모드: 동아리원 전체가 보이고, 탭하면 제자리에서 참가/해제 토글
class ParticipantScreen extends StatefulWidget {
  const ParticipantScreen({super.key});

  @override
  State<ParticipantScreen> createState() => _ParticipantScreenState();
}

class _ParticipantScreenState extends State<ParticipantScreen> {
  bool _isEditMode = false;

  /// 기수별 그룹핑 — 숫자를 뽑아 "33" / "33기" 를 같은 섹션으로 묶는다
  Map<String, List<MemberItem>> _groupByGeneration(List<MemberItem> members) {
    final groups = <String, List<MemberItem>>{};
    for (final m in members) {
      final match = RegExp(r'\d+').firstMatch(m.generation);
      final label = match == null ? '기수 미입력' : '${match.group(0)}기';
      groups.putIfAbsent(label, () => []).add(m);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final expedition = context.watch<ExpeditionProvider>().selected;
    final memberProvider = context.watch<MemberProvider>();
    final participantProvider = context.watch<ParticipantProvider>();

    final clubMembers = memberProvider.members; // 이미 기수 오름차순 정렬됨
    final participants =
        clubMembers.where((m) => participantProvider.isParticipant(m.id)).toList();

    // 💡 보기 모드에서는 참가자만, 수정 모드에서는 동아리원 전체를 그룹핑
    final groups = _groupByGeneration(_isEditMode ? clubMembers : participants);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          expedition == null ? '원정 참가자' : '${expedition.label} 참가자',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (isAdmin && expedition != null)
            TextButton(
              onPressed: () => setState(() => _isEditMode = !_isEditMode),
              child: Text(
                _isEditMode ? '완료' : '수정',
                style: TextStyle(
                  color: _isEditMode ? Colors.blue : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: expedition == null
          ? const Center(
              child: Text('홈에서 원정을 먼저 선택해주세요.',
                  style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- 상단 요약 ---
                Row(
                  children: [
                    const Text('참가자',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${participants.length}명',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800])),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isEditMode
                      ? '탭하면 참가자로 추가되고, 다시 탭하면 빠집니다.'
                      : (isAdmin
                          ? '우측 상단 [수정]에서 참가자를 추가/해제할 수 있습니다.'
                          : '이번 원정에 참가하는 대원입니다.'),
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),

                const SizedBox(height: 14),
                Divider(color: Colors.grey[200], height: 1),
                const SizedBox(height: 14),

                // --- 본문 ---
                if (_isEditMode && clubMembers.isEmpty)
                  _emptyClubGuide(context, memberProvider)
                else if (!_isEditMode && participants.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        isAdmin
                            ? '아직 참가자가 없습니다.\n우측 상단 [수정]을 눌러 등록하세요.'
                            : '아직 참가자가 없습니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...groups.entries.expand((entry) => [
                        _sectionLabel(entry.key),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: entry.value
                              .map((m) => _memberChip(
                                    m,
                                    selected:
                                        participantProvider.isParticipant(m.id),
                                    onTap: _isEditMode
                                        ? () => participantProvider.toggle(m)
                                        : null,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ]),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54));
  }

  Widget _memberChip(MemberItem member, {required bool selected, VoidCallback? onTap}) {
    final isOb = member.memberType == 'OB';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue[800] : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.blue[800]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && _isEditMode) ...[
              const Icon(Icons.check, size: 13, color: Colors.white70),
              const SizedBox(width: 4),
            ],
            Text(
              member.name.isEmpty ? '(이름없음)' : member.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            if (isOb) ...[
              const SizedBox(width: 4),
              Text(
                'OB',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white60 : Colors.indigo[300],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 동아리원 명단이 비어있을 때: v1 명단 가져오기 안내 (관리자 수정 모드)
  Widget _emptyClubGuide(BuildContext context, MemberProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('동아리원 명단이 비어 있습니다.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'v1의 대원 명단을 동아리원으로 가져오거나,\n사이드바의 [동아리원 명단]에서 직접 추가하세요.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final count = await provider.importFromLegacy();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ 기존 명단 $count명을 가져왔습니다.')),
                );
              }
            },
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('v1 대원 명단 가져오기', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
