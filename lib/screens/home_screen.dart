import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_version.dart';
import '../providers/equipment_provider.dart';
import '../providers/expedition_provider.dart';
import '../providers/notice_provider.dart';
import '../models/expedition_model.dart';
import '../models/notice_model.dart';
import 'equipment_check_screen.dart';
import 'search_screen.dart';
import 'member_management_screen.dart';
import 'participant_screen.dart';
import 'buddy_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final noticeProvider = Provider.of<NoticeProvider>(context);
    final expeditionProvider = Provider.of<ExpeditionProvider>(context);

    final isAdmin = equipmentProvider.isAdmin;
    final homeNotice = noticeProvider.homeNotice;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: _buildSideBar(context, equipmentProvider, isAdmin),
      appBar: AppBar(
        // 💡 v2: 타이틀 자리가 원정(시즌) 선택기. 탭하면 원정 목록 시트가 열린다.
        title: GestureDetector(
          onTap: () => _showExpeditionSheet(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expeditionProvider.selected?.label ?? 'KUST 원정',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.black54),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
              color: isAdmin ? Colors.blue : Colors.black87,
            ),
            onPressed: () {},
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('안녕하세요, 대원님!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // 💡 선택된 원정과 연동된 부제 (시즌 중립)
            Text(
              expeditionProvider.selected != null
                  ? '${expeditionProvider.selected!.label} — 오늘의 장비 점검을 잊지 마세요.'
                  : '상단에서 원정을 선택해주세요.',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // 💡 v2: 장비 3분할을 하나로 통합하여 1행 2열로 단순화
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildMenuCard(context,
                    title: '장비 체크',
                    icon: Icons.checklist_rounded, color: Colors.blue,
                    target: const EquipmentCheckScreen()),
                _buildMenuCard(context,
                    title: '버디',
                    icon: Icons.people_outline_rounded, color: Colors.teal,
                    target: const BuddyScreen()),
              ],
            ),

            const SizedBox(height: 32),

            // 💡 알림 배너 (버튼들 아래 위치)
            _buildQuickNoticeCard(context, noticeProvider, isAdmin, homeNotice),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 원정 연도 선택 범위
  static const int _minYear = 2025;
  static const int _maxYear = 2040;

  // 💡 원정 선택 시트: 연도 하나 + 계절 하나를 고르면 그게 곧 원정 선택이다.
  //    '만들기' 개념 없음 — 아직 데이터가 없는 시즌은 빈 상태에서 시작한다.
  void _showExpeditionSheet(BuildContext context) {
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Consumer2<ExpeditionProvider, EquipmentProvider>(
          builder: (ctx2, expProvider, equipProvider, _) {
            final isAdmin = equipProvider.isAdmin;
            final selected = expProvider.selected;
            final selYear =
                selected?.year ?? DateTime.now().year.clamp(_minYear, _maxYear);
            final selSeason = selected?.season ?? 'winter';
            final hasLegacyTarget =
                expProvider.expeditions.every((e) => e.id != '2025_winter');

            return SafeArea(
              child: Container(
                // 💡 시트를 위로 끌어올려 계절 영역이 폰 하단에 붙지 않게 한다.
                height: MediaQuery.of(ctx).size.height * 0.72,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text('원정 선택',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('연도와 계절을 고르면 해당 원정으로 바로 전환됩니다.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),

                      const Text('연도',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_maxYear - _minYear + 1, (i) {
                          final year = _minYear + i;
                          final isSel = year == selYear;
                          return _expeditionPill(
                            label: '$year',
                            selected: isSel,
                            width: 62,
                            // 💡 둘러보기는 선택만 — 문서를 만들지 않는다
                            onTap: () => expProvider.select('${year}_$selSeason'),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      const Text('계절',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                      const SizedBox(height: 8),
                      // 💡 계절: 가운데 정렬 + 살짝 넓은 고정 폭 버튼
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: Expedition.seasonLabels.entries.map((entry) {
                            final isSel = selSeason == entry.key;
                            return _expeditionPill(
                              label: entry.value,
                              selected: isSel,
                              width: 74,
                              // 💡 둘러보기는 선택만 — 문서를 만들지 않는다
                              onTap: () =>
                                  expProvider.select('${selYear}_${entry.key}'),
                            );
                          }).toList(),
                        ),
                      ),

                      // 관리자 전용: v1 최상위 데이터(25 동계) 이사
                      if (isAdmin && hasLegacyTarget) ...[
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey[200], height: 1),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    setSheetState(() => busy = true);
                                    final result =
                                        await expProvider.migrateLegacyData(
                                            year: 2025, season: 'winter');
                                    if (ctx.mounted) {
                                      setSheetState(() => busy = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('✅ $result')),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                            label: const Text('기존 데이터를 25년 동계 원정으로 이사',
                                style: TextStyle(fontSize: 12.5)),
                          ),
                        ),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Center(
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))),
                          ),
                      ],
                    ],
                  ),
                ),
                    ),
                    const SizedBox(height: 12),
                    // 💡 선택 완료: 시트를 닫는다 (선택은 탭 즉시 이미 반영된 상태)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('선택 완료',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 연도/계절 공용 선택 버튼
  Widget _expeditionPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    double? width,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(horizontal: width == null ? 18 : 0, vertical: 9),
        // 💡 alignment는 고정 폭일 때만. 폭 미지정 상태에서 주면
        //    Container가 가로 전체로 늘어나 버튼이 세로로 쌓인다.
        alignment: width == null ? null : Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.blue[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.blue[800]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // 사이드바 구성
  Widget _buildSideBar(BuildContext context, EquipmentProvider provider, bool isAdmin) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[800]),
            accountName: const Text('KUST 원정대원', style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(isAdmin ? '관리자 권한 활성화됨' : '일반 사용자 모드'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.blue[800], size: 40),
            ),
          ),

          _drawerItem(
            context,
            icon: isAdmin ? Icons.groups_outlined : Icons.lock_outline,
            title: '동아리원 명단',
            subtitle: 'OB/YB 명단 및 정보 관리',
            isAdmin: isAdmin,
            target: const MemberManagementScreen(),
          ),

          _drawerItem(
            context,
            icon: isAdmin ? Icons.how_to_reg_outlined : Icons.lock_outline,
            title: '원정 참가자 관리',
            subtitle: '이번 원정에 갈 대원 선택',
            isAdmin: isAdmin,
            target: const ParticipantScreen(),
          ),

          _drawerItem(
            context,
            icon: Icons.inventory_2_outlined,
            title: '장비 인벤토리',
            subtitle: 'BCD·호흡기 번호 및 공용 장비 수량',
            isAdmin: true, // 💡 열람은 누구나 (수정은 화면 안에서 관리자만)
            target: const SearchScreen(),
          ),

          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(kAppVersion, style: TextStyle(color: Colors.grey, fontSize: 12)),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () {
                      provider.logoutAdmin();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                    label: const Text('관리자 해제', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 사이드바 아이템 공통 위젯
  Widget _drawerItem(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isAdmin,
    required Widget target
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      onTap: () {
        if (!isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('관리자 인증이 필요한 메뉴입니다.'), backgroundColor: Colors.redAccent),
          );
          return;
        }
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => target));
      },
    );
  }

  // 💡 메뉴 카드 위젯 (제목만 표시하도록 수정)
  Widget _buildMenuCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget target,
    bool isAdminRequired = false,
    bool isAdmin = true,
  }) {
    return GestureDetector(
      onTap: () {
        if (isAdminRequired && !isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이 메뉴는 임원진(관리자)만 접근할 수 있습니다.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (context) => target));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 8)
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 26)
            ),
            const SizedBox(height: 10),
            Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
            ),
          ],
        ),
      ),
    );
  }

  // 💡 알림 배너 카드
  Widget _buildQuickNoticeCard(BuildContext context, NoticeProvider noticeProvider, bool isAdmin, NoticeItem? notice) {
    final bool isPinned = notice?.isPinned ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: isPinned
                  ? [Colors.blue[900]!, Colors.blue[700]!]
                  : [Colors.blue[800]!, Colors.blue[600]!]
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: isPinned ? Colors.indigo.withOpacity(0.3) : Colors.blue.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5)
            )
          ]
      ),
      child: Row(
        children: [
          Icon(isPinned ? Icons.push_pin : Icons.campaign, color: Colors.white, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isPinned ? '[필독] ${notice?.title ?? ""}' : (notice?.title ?? '최신 공지사항'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)
                ),
                const SizedBox(height: 2),
                Text(
                  notice?.content ?? '등록된 공지가 없습니다.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.white, size: 28),
              onPressed: () => _showQuickEditDialog(context, noticeProvider, notice),
            ),
        ],
      ),
    );
  }

  // 공지사항 빠른 수정 다이얼로그
  void _showQuickEditDialog(BuildContext context, NoticeProvider noticeProvider, NoticeItem? existingNotice) {
    final titleController = TextEditingController(text: existingNotice?.title ?? '');
    final contentController = TextEditingController(text: existingNotice?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existingNotice == null ? '새 공지 등록' : '공지 내용 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '제목')),
            TextField(controller: contentController, decoration: const InputDecoration(labelText: '내용'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || contentController.text.isEmpty) return;
              if (existingNotice == null) {
                await noticeProvider.addNotice(titleController.text, contentController.text);
              } else {
                await noticeProvider.updateNotice(
                    existingNotice.id,
                    titleController.text,
                    contentController.text,
                    imageUrls: existingNotice.imageUrls
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}