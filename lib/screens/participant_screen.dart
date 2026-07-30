import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member_model.dart';
import '../providers/equipment_provider.dart';
import '../providers/expedition_provider.dart';
import '../providers/member_provider.dart';
import '../providers/participant_provider.dart';

/// 💡 v2: 동아리원 명단에서 이번 원정에 갈 대원을 고르는 화면.
/// 참가자는 expeditions/{id}/participants 에 동아리원 ID로 저장된다.
class ParticipantScreen extends StatelessWidget {
  const ParticipantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final expedition = context.watch<ExpeditionProvider>().selected;
    final memberProvider = context.watch<MemberProvider>();
    final participantProvider = context.watch<ParticipantProvider>();

    final clubMembers = memberProvider.members;
    final byId = {for (final m in clubMembers) m.id: m};

    // 참가자: 참가 순서대로, 명단에서 지워진 ID는 건너뛴다
    final participants = participantProvider.participantIds
        .map((id) => byId[id])
        .whereType<MemberItem>()
        .toList();

    // 미참가 동아리원을 YB/OB로 나눈다
    final rest = clubMembers
        .where((m) => !participantProvider.isParticipant(m.id))
        .toList();
    final restYb = rest.where((m) => m.memberType != 'OB').toList();
    final restOb = rest.where((m) => m.memberType == 'OB').toList();

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
                // --- 참가자 현황 ---
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
                const SizedBox(height: 10),
                if (participants.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.center,
                    child: Text(
                      isAdmin
                          ? '아래 동아리원을 탭해서 참가자로 추가하세요.'
                          : '아직 참가자가 없습니다.',
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: participants
                        .map((m) => _memberChip(
                              m,
                              selected: true,
                              onTap: isAdmin
                                  ? () => participantProvider.toggle(m)
                                  : null,
                            ))
                        .toList(),
                  ),

                const SizedBox(height: 24),
                Divider(color: Colors.grey[200], height: 1),
                const SizedBox(height: 16),

                // --- 동아리원 명단 (미참가) ---
                Text(
                  isAdmin ? '동아리원 · 탭하여 추가' : '동아리원',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (clubMembers.isEmpty)
                  _emptyClubGuide(context, isAdmin, memberProvider)
                else ...[
                  if (restYb.isNotEmpty) ...[
                    _sectionLabel('YB'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: restYb
                          .map((m) => _memberChip(
                                m,
                                selected: false,
                                onTap: isAdmin
                                    ? () => participantProvider.toggle(m)
                                    : null,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (restOb.isNotEmpty) ...[
                    _sectionLabel('OB'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: restOb
                          .map((m) => _memberChip(
                                m,
                                selected: false,
                                onTap: isAdmin
                                    ? () => participantProvider.toggle(m)
                                    : null,
                              ))
                          .toList(),
                    ),
                  ],
                  if (rest.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text('모든 동아리원이 참가자로 등록되었습니다.',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                      ),
                    ),
                ],
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
            Text(
              member.name.isEmpty ? '(이름없음)' : member.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            if (member.generation.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                member.generation,
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
            if (selected && onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.close, size: 13, color: Colors.white70),
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
