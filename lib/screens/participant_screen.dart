import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member_model.dart';
import '../providers/equipment_provider.dart';
import '../providers/expedition_provider.dart';
import '../providers/member_provider.dart';
import '../providers/participant_provider.dart';

/// 💡 v2: 동아리원 명단에서 이번 원정에 갈 대원을 고르는 화면.
/// 칩은 기수별 섹션에 고정되어 있고, 탭하면 그 자리에서 참가/해제가 토글된다.
class ParticipantScreen extends StatelessWidget {
  const ParticipantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final expedition = context.watch<ExpeditionProvider>().selected;
    final memberProvider = context.watch<MemberProvider>();
    final participantProvider = context.watch<ParticipantProvider>();

    final clubMembers = memberProvider.members; // 이미 기수 오름차순 정렬됨

    // 참가자 요약(기수순)
    final participants =
        clubMembers.where((m) => participantProvider.isParticipant(m.id)).toList();

    // 💡 기수별 그룹핑 — 숫자를 뽑아 "33" / "33기" 를 같은 섹션으로 묶는다
    final groups = <String, List<MemberItem>>{};
    for (final m in clubMembers) {
      final match = RegExp(r'\d+').firstMatch(m.generation);
      final label = match == null ? '기수 미입력' : '${match.group(0)}기';
      groups.putIfAbsent(label, () => []).add(m);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          expedition == null ? '원정 참가자' : '${expedition.label} 참가자',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: expedition == null
          ? const Center(
              child: Text('홈에서 원정을 먼저 선택해주세요.',
                  style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- 참가자 요약 ---
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
                const SizedBox(height: 8),
                if (participants.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      participants.map((m) => m.name).join(', '),
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.black54, height: 1.6),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  isAdmin
                      ? '탭하면 참가자로 추가되고, 다시 탭하면 빠집니다.'
                      : '참가자는 파란색으로 표시됩니다.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),

                const SizedBox(height: 14),
                Divider(color: Colors.grey[200], height: 1),
                const SizedBox(height: 14),

                // --- 기수별 섹션 (칩은 제자리에서 토글) ---
                if (clubMembers.isEmpty)
                  _emptyClubGuide(context, isAdmin, memberProvider)
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
                                    onTap: isAdmin
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
            if (selected) ...[
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

  /// 동아리원 명단이 비어있을 때: v1 명단 가져오기 안내 (관리자)
  Widget _emptyClubGuide(BuildContext context, bool isAdmin, MemberProvider provider) {
    if (!isAdmin) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('등록된 동아리원이 없습니다.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey)),
      );
    }
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
