import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 사용을 위해 필수
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ✅ 모든 Provider Import
import 'providers/expedition_provider.dart';
import 'providers/equipment_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/meal_plan_provider.dart';
import 'providers/notice_provider.dart';
import 'providers/executive_checklist_provider.dart';
import 'providers/member_provider.dart';
import 'providers/buddy_provider.dart';
import 'providers/participant_provider.dart';
import 'providers/qna_provider.dart';
import 'providers/executive_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/ingredient_provider.dart';
import 'providers/guide_provider.dart';
import 'providers/dive_site_provider.dart';


// ✅ 모든 Screen Import
import 'util/web_plugins_fix_stub.dart'
    if (dart.library.js_interop) 'util/web_plugins_fix_web.dart';
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/dive_site_screen.dart';
import 'util/usage_stats.dart';
import 'screens/meal_plan_screen.dart';
import 'screens/more_screen.dart';

// 💡 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 💡 웹 플러그인 등록 복구 (지도 unregistered_view_type 대응)
  ensureWebPluginsRegistered();

  // 💡 진단용 전역 오류 핸들러: 잡히지 않는 오류의 본문을 콘솔에 그대로 찍는다.
  //    (모바일에서 원인 불명 흰 화면을 추적하기 위함)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('KUST 위젯 오류: ${details.exceptionAsString()}');
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('KUST 전역 오류: $error');
    debugPrint('KUST 전역 오류 스택: $stack');
    return true; // 오류를 삼켜서 앱이 계속 돌게 한다
  };

  bool isFirebaseInitialized = false;

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyAZnDCZeKVdUBC1eM6e6X-tYvUXZz6kUfU",
          authDomain: "kust-88683.firebaseapp.com",
          projectId: "kust-88683",
          storageBucket: "kust-88683.firebasestorage.app",
          messagingSenderId: "320857165783",
          appId: "1:320857165783:web:1094126f5f522b90938592",
        ),
      );
    } else {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
    isFirebaseInitialized = true;
    debugPrint("파이어베이스 초기화 성공");
    // 💡 이용 통계 '이 기기 집계 제외' 설정 로드 (실패해도 무시)
    await UsageStats.init();

    _setupNotifications();
  } catch (e) {
    debugPrint("파이어베이스 초기화 에러: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        // 0. 원정(시즌) 선택 — 아래 원정별 provider들이 이 선택을 따라간다
        ChangeNotifierProvider(create: (_) => ExpeditionProvider()),

        // 1. 장비 및 기본 설정 관리 (원정별)
        ChangeNotifierProxyProvider<ExpeditionProvider, EquipmentProvider>(
          create: (_) => EquipmentProvider(),
          update: (_, expedition, equipment) =>
              equipment!..setExpedition(expedition.selectedId),
        ),

        // 2. 일정 관리 (원정별)
        ChangeNotifierProxyProvider<ExpeditionProvider, ScheduleProvider>(
          create: (_) => ScheduleProvider(),
          update: (_, expedition, schedule) =>
              schedule!..setExpedition(expedition.selectedId),
        ),

        // 3. 식단 관리 (원정별)
        ChangeNotifierProxyProvider<ExpeditionProvider, MealPlanProvider>(
          create: (_) => MealPlanProvider(),
          update: (_, expedition, meal) =>
              meal!..setExpedition(expedition.selectedId),
        ),

        // 4. 공지사항 관리
        ChangeNotifierProvider(create: (_) => NoticeProvider()),

        // 5. 임원 체크리스트
        ChangeNotifierProvider(create: (_) => ExecutiveChecklistProvider()),

        // 6. 동아리원 명단 (원정 무관 원본)
        ChangeNotifierProvider(create: (_) => MemberProvider()),

        // 6-1. 원정 참가자 (원정별, 동아리원 ID 참조)
        // 💡 lazy: false — 화면이 안 열려도 앱 시작 시 바로 구독을 시작해야
        //    참가자↔장비 행 자동 보충(자가 치유)이 동작한다
        ChangeNotifierProxyProvider<ExpeditionProvider, ParticipantProvider>(
          create: (_) => ParticipantProvider(),
          lazy: false,
          update: (_, expedition, participant) =>
              participant!..setExpedition(expedition.selectedId),
        ),

        // 7. 버디/탱크 관리 (원정별)
        ChangeNotifierProxyProvider<ExpeditionProvider, BuddyProvider>(
          create: (_) => BuddyProvider(),
          update: (_, expedition, buddy) =>
              buddy!..setExpedition(expedition.selectedId),
        ),

        // 7-1. 식단·레시피 (원정별)
        ChangeNotifierProxyProvider<ExpeditionProvider, RecipeProvider>(
          create: (_) => RecipeProvider(),
          update: (_, expedition, recipe) =>
              recipe!..setExpedition(expedition.selectedId),
        ),

        // 7-3. 신입생 가이드 (동아리 공용)
        ChangeNotifierProvider(create: (_) => GuideProvider()),

        // 7-4. 다이브 사이트 (동아리 공용, 지도 마커)
        ChangeNotifierProvider(create: (_) => DiveSiteProvider()),

        // 7-2. 남은 재료 (원정별)
        ChangeNotifierProxyProvider<ExpeditionProvider, IngredientProvider>(
          create: (_) => IngredientProvider(),
          update: (_, expedition, ingredient) =>
              ingredient!..setExpedition(expedition.selectedId),
        ),

        // 8. QnA 게시판
        ChangeNotifierProvider(create: (_) => QnaProvider()),

        // 9. 임원진 소개 관리
        ChangeNotifierProvider(create: (_) => ExecutiveProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()), // 👈 반드시 추가되어야 함
      ],
      child: KustApp(isInitialized: isFirebaseInitialized),
    ),
  );
}

// 💡 알림 설정
Future<void> _setupNotifications() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('알림 권한 허용됨');
      if (kIsWeb) {
        String? token = await messaging.getToken(
            vapidKey: "BMkK18nQuhq3wGivZk_2HfDiQ9ojEW6U9WT3c0F-_6zn-8O0XNFYjdJ1eHopIR65gBQGzhq_0xnzLkxyxjvm9bU"
        );
        debugPrint("웹 푸시 토큰: $token");
      }
    }
  } catch (e) {
    debugPrint("알림 설정 중 에러 발생: $e");
  }
}

class KustApp extends StatelessWidget {
  final bool isInitialized;
  const KustApp({super.key, required this.isInitialized});

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.error_outline, color: Colors.red, size: 50),
                SizedBox(height: 16),
                Text("서버 연결에 실패했습니다."),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'KUST 원정',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue[800]!),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      builder: (context, child) {
        // 시스템 폰트 크기 설정 무시 (레이아웃 깨짐 방지)
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
      home: const MainTabScreen(),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // 💡 메인 탭에 들어갈 화면들. (사이트 탭 2026-08-05 정식 오픈)
  final List<Widget> _screens = [
    const HomeScreen(),
    const ScheduleScreen(),
    const DiveSiteScreen(),
    const MealPlanScreen(),
    const MoreScreen(),
  ];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 포그라운드 메시지 리스너
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification!.title ?? '알림'),
            backgroundColor: Colors.blue[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 💡 백그라운드에 다녀오면 Firestore 실시간 스트림이 죽어있을 수 있다.
    //    포그라운드 복귀 시 전부 다시 구독해 실시간 동기화를 보장한다.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ExpeditionProvider>().resubscribe();
      context.read<EquipmentProvider>().resubscribe();
      context.read<ScheduleProvider>().resubscribe();
      context.read<MealPlanProvider>().resubscribe();
      context.read<BuddyProvider>().resubscribe();
      context.read<ParticipantProvider>().resubscribe();
      context.read<MemberProvider>().resubscribe();
      context.read<RecipeProvider>().resubscribe();
      context.read<IngredientProvider>().resubscribe();
      context.read<GuideProvider>().resubscribe();
      context.read<DiveSiteProvider>().resubscribe();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 앱 시작 때 5개 탭을 전부 만들어둔다 — 탭 전환 즉시,
      //    편집 상태·스크롤·지도 로딩 상태 모두 유지.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          // 💡 기능별 이용 집계 (일정·사이트·식단·더보기 탭 대상)
          const tabKeys = {
            1: 'tab_schedule',
            2: 'tab_site',
            3: 'tab_meal',
            4: 'tab_more',
          };
          final key = tabKeys[index];
          if (index != _selectedIndex && key != null) {
            UsageStats.log(key);
          }
          setState(() => _selectedIndex = index);
        },
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '일정'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: '사이트'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '식단'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: '더보기'),
        ],
      ),
    );
  }
}