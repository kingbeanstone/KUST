import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_version.dart';
import '../util/app_update.dart';
import '../providers/auth_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/executive_provider.dart';
import '../providers/expedition_provider.dart';
import '../providers/notice_provider.dart';
import '../providers/qna_provider.dart';
import '../models/expedition_model.dart';
import '../models/notice_model.dart';
import 'equipment_check_screen.dart';
import 'search_screen.dart';
import 'member_management_screen.dart';
import 'participant_screen.dart';
import 'buddy_screen.dart';
import 'personal_checklist_screen.dart';
import 'guide_screen.dart';
import 'dive_log_screen.dart';
import 'usage_stats_screen.dart';
import 'game_hub_screen.dart';
import 'species_guide_screen.dart';
import 'weather_screen.dart';
import '../util/usage_stats.dart';
import '../util/weather_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final noticeProvider = Provider.of<NoticeProvider>(context);
    final expeditionProvider = Provider.of<ExpeditionProvider>(context);

    final isAdmin = equipmentProvider.isAdmin;
    // 💡 800(개발자) 인증이면 관리자 표시가 빨간색 + 개발 중 화면 미리보기 가능.
    // 관리자 모드를 끄면 미리보기도 꺼져서 일반 사용자와 같은 화면을 본다
    // (통계 집계 제외는 기기 단위로 계속 유지됨).
    final isDev = context.watch<AuthProvider>().isDeveloper && isAdmin;
    final adminColor = isDev ? Colors.red[600]! : Colors.blue;
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
              color: isAdmin ? adminColor : Colors.black87,
            ),
            tooltip: isAdmin ? '관리자 모드 해제' : '관리자 인증',
            onPressed: () => _toggleAdmin(context),
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
            const SizedBox(height: 16),

            // 💡 울릉도 날씨 배너 — 탭하면 시간대별 상세
            _buildWeatherBanner(context),
            const SizedBox(height: 16),

            // 💡 v2: 장비 3분할을 하나로 통합하여 1행 2열로 단순화
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              // 💡 카드가 5→4개로 줄면서 아래 여백이 커져, 카드를 세로로 키워 채운다
              childAspectRatio: 1.15,
              children: [
                _buildMenuCard(context,
                    title: '장비 체크',
                    icon: Icons.checklist_rounded, color: Colors.blue,
                    statKey: 'equipment_check',
                    target: const EquipmentCheckScreen()),
                _buildMenuCard(context,
                    title: '버디',
                    icon: Icons.people_outline_rounded, color: Colors.teal,
                    statKey: 'buddy',
                    target: const BuddyScreen()),
                _buildMenuCard(context,
                    title: '성장 그래프',
                    icon: Icons.show_chart_rounded, color: Colors.purple,
                    statKey: 'growth',
                    target: const DiveLogScreen()),
                // 💡 생물 도감: 일반은 준비 중, 개발자(800)만 실화면 미리보기
                _buildMenuCard(context,
                    title: '생물 도감',
                    icon: Icons.emoji_nature_outlined, color: Colors.cyan,
                    statKey: 'species',
                    target: const SpeciesGuideScreen()),
              ],
            ),

            const SizedBox(height: 32),

            // 💡 알림 배너 (버튼들 아래 위치)
            _buildQuickNoticeCard(context, noticeProvider, isAdmin, homeNotice),

            // 💡 새 버전이 나오면 공지 아래에 업데이트 버튼이 짠 하고 뜬다
            _buildUpdateBanner(),

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
    // 💡 시트 안에서는 로컬 선택만 (버튼 반응 즉시) — [선택 완료]에서 실제 적용
    int? pickedYear;
    String? pickedSeason;

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
            final selYear = pickedYear ??
                selected?.year ??
                DateTime.now().year.clamp(_minYear, _maxYear);
            final selSeason = pickedSeason ?? selected?.season ?? 'winter';
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
                            onTap: () => setSheetState(() => pickedYear = year),
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
                              onTap: () =>
                                  setSheetState(() => pickedSeason = entry.key),
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
                    // 💡 선택 완료: 이때 실제로 원정을 전환하고 시트를 닫는다
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          expProvider.select('${selYear}_$selSeason');
                          Navigator.pop(ctx);
                        },
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

  /// 💡 인앱 업데이트 배너: 새 버전이 있을 때만 나타난다 (탭 = 즉시 업데이트)
  Widget _buildUpdateBanner() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppUpdate.doc.snapshots(),
      builder: (context, snap) {
        final latest = (snap.data?.data()?['latest'] ?? '').toString();
        if (!AppUpdate.isNewer(latest)) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('⬇️ 새 버전으로 업데이트하는 중...'),
              duration: Duration(seconds: 3),
            ));
            AppUpdate.apply();
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [Colors.blue[700]!, Colors.blue[500]!]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.blue.withAlpha(70),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                const Text('🚀', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('새 버전이 나왔어요!',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5)),
                      Text('$latest — 탭 한 번이면 업데이트 완료',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11.5)),
                    ],
                  ),
                ),
                const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 💡 앱바 사람 아이콘 = 관리자 전환 버튼 (더보기 탭의 인증 버튼과 동일 동작).
  /// 인증 중이면 해제, 아니면 기억된 정보로 즉시 인증하거나 비밀번호를 묻는다.
  Future<void> _toggleAdmin(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final equip = context.read<EquipmentProvider>();
    final notice = context.read<NoticeProvider>();
    final exec = context.read<ExecutiveProvider>();
    final qna = context.read<QnaProvider>();

    void syncAdmin(bool value) {
      equip.setAdminStatus(value);
      notice.setAdminStatus(value);
      exec.setAdminStatus(value);
      qna.setAdminStatus(value);
    }

    void toast(String msg, {bool isError = false}) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.redAccent : Colors.black87,
          duration: const Duration(seconds: 2),
        ));
    }

    // 1) 인증 상태 → 해제 (비밀번호 기억 설정은 유지)
    if (auth.isAdmin) {
      auth.logout();
      syncAdmin(false);
      toast('🔓 관리자 모드가 해제되었습니다.');
      return;
    }

    // 2) 기억된 정보가 있으면 다이얼로그 없이 즉시 인증
    if (auth.isPasswordSaved) {
      final success = await auth.authenticate('779', remember: true);
      if (success) {
        syncAdmin(true);
        if (context.mounted) toast('✅ 관리자 권한이 활성화되었습니다.');
      }
      return;
    }

    // 3) 처음이면 비밀번호 입력 다이얼로그
    if (!context.mounted) return;
    final pwdController = TextEditingController();
    bool rememberMe = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('관리자 인증',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('비밀번호 3자리를 입력하세요.', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: pwdController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 3,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 10),
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), counterText: ''),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                      value: rememberMe,
                      onChanged: (val) =>
                          setDialogState(() => rememberMe = val ?? false)),
                  const Text('비밀번호 기억하기', style: TextStyle(fontSize: 13)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소')),
            TextButton(
              onPressed: () async {
                final success = await auth.authenticate(pwdController.text,
                    remember: rememberMe);
                if (success) {
                  syncAdmin(true);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  toast('✅ 관리자 권한이 활성화되었습니다.');
                } else {
                  toast('❌ 비밀번호가 틀렸습니다.', isError: true);
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  /// 💡 울릉도 날씨 배너 — 현재 시각 기온·날씨·바람·파고 요약.
  /// 탭하면 오늘/내일 시간대별 상세 화면으로 이동한다.
  Widget _buildWeatherBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        UsageStats.log('weather');
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WeatherScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        // 💡 폰 날씨 위젯 느낌: 푸른 그라데이션 + 흰 글씨 (라운드 20 + 은은한 그림자)
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A80D6), Color(0xFF77AAE8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.blue.withAlpha(60),
                blurRadius: 6,
                offset: const Offset(0, 3)),
          ],
        ),
        child: FutureBuilder<WeatherData>(
          future: WeatherService.fetchForecast(),
          builder: (context, snap) {
            final now = snap.data?.now;
            if (now == null) {
              return Row(
                children: [
                  const Text('🌊', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      snap.hasError
                          ? '날씨를 불러올 수 없어요 — 탭해서 다시 시도'
                          : '울릉도 날씨 불러오는 중...',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              );
            }
            final (emoji, desc) = WeatherService.describe(now.code);
            return Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('울릉도  ${now.temp.round()}°  $desc',
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            );
          },
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
            accountEmail: Text(isAdmin
                ? (Provider.of<AuthProvider>(context).isDeveloper
                    ? '개발자 모드 활성화됨'
                    : '관리자 권한 활성화됨')
                : '일반 사용자 모드'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: isAdmin && Provider.of<AuthProvider>(context).isDeveloper
                    ? Colors.red[600]
                    : Colors.blue[800],
                size: 40,
              ),
            ),
          ),

          // 💡 홈 카드에서 옮겨온 메뉴 (누구나 접근)
          _drawerItem(
            context,
            icon: Icons.luggage_outlined,
            title: '개인 체크리스트',
            subtitle: '내 짐 목록 체크 (기기 저장)',
            isAdmin: true,
            statKey: 'personal_checklist',
            target: const PersonalChecklistScreen(),
          ),

          _drawerItem(
            context,
            icon: Icons.school_outlined,
            title: '신입생 가이드',
            subtitle: '장비 준비부터 반납까지 단계별 안내',
            isAdmin: true,
            statKey: 'guide',
            target: const GuideScreen(),
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
            icon: Icons.how_to_reg_outlined,
            title: '원정 참가자',
            subtitle: '이번 원정에 가는 대원 명단',
            isAdmin: true, // 💡 열람은 누구나 (수정은 화면 안에서 관리자만)
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

          _drawerItem(
            context,
            icon: Icons.bar_chart_rounded,
            title: '이용 통계',
            subtitle: '기능별 누적 접속 횟수',
            isAdmin: true, // 열람은 누구나
            target: const UsageStatsScreen(),
          ),

          // 💡 미니 게임: 일반은 준비 중, 개발자(800)만 미리보기
          _drawerItem(
            context,
            icon: Icons.casino_outlined,
            title: '미니 게임',
            subtitle: '주루마블·귓속말 게임 — 대원들과 한 판!',
            isAdmin: true,
            statKey: 'game',
            target: const GameHubScreen(),
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
    required Widget target,
    String? statKey,
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
        if (statKey != null) UsageStats.log(statKey);
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
    String? statKey,
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
        if (statKey != null) UsageStats.log(statKey);
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
                // 💡 태그는 수정 다이얼로그에서 선택 ([필독]/[참고]/없음)
                //    구버전 공지(태그 없음)는 고정 공지일 때만 [필독] 유지
                Builder(builder: (_) {
                  final tag = notice == null
                      ? ''
                      : (notice.tag.isNotEmpty
                          ? notice.tag
                          : (isPinned ? '필독' : ''));
                  final title = notice?.title ?? '최신 공지사항';
                  return Text(
                      tag.isEmpty ? title : '[$tag] $title',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600));
                }),
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

  // 공지사항 빠른 수정 다이얼로그 (머리말 태그 선택 포함)
  void _showQuickEditDialog(BuildContext context, NoticeProvider noticeProvider, NoticeItem? existingNotice) {
    final titleController = TextEditingController(text: existingNotice?.title ?? '');
    final contentController = TextEditingController(text: existingNotice?.content ?? '');
    // 구버전 공지(태그 필드 없음)는 고정 공지면 '필독'으로 시작
    var tag = existingNotice == null
        ? ''
        : (existingNotice.tag.isNotEmpty
            ? existingNotice.tag
            : (existingNotice.isPinned ? '필독' : ''));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existingNotice == null ? '새 공지 등록' : '공지 내용 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💡 머리말 태그 딸깍 선택
            Wrap(
              spacing: 6,
              children: [
                for (final (value, label) in const [
                  ('', '없음'),
                  ('필독', '[필독]'),
                  ('참고', '[참고]'),
                ])
                  GestureDetector(
                    onTap: () => setDialogState(() => tag = value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: tag == value
                            ? Colors.blue[700]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              tag == value ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
                await noticeProvider.addNotice(
                    titleController.text, contentController.text,
                    tag: tag);
              } else {
                await noticeProvider.updateNotice(
                    existingNotice.id,
                    titleController.text,
                    contentController.text,
                    imageUrls: existingNotice.imageUrls,
                    tag: tag,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
        ),
      ),
    );
  }
}