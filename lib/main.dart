import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 사용을 위해 필수
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Providers
import 'providers/equipment_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/meal_plan_provider.dart';
import 'providers/notice_provider.dart';
import 'providers/executive_checklist_provider.dart';
import 'providers/member_provider.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/notice_screen.dart';
import 'screens/meal_plan_screen.dart';
import 'screens/more_screen.dart';
import 'screens/executive_checklist_screen.dart';
import 'screens/member_management_screen.dart';



// 💡 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
}

void main() async {
  // 1. 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  bool isFirebaseInitialized = false;

  // 2. 파이어베이스 초기화
  try {
    if (kIsWeb) {
      // 💡 웹/PWA 환경 명시적 옵션 설정
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

    // 💡 3. 알림 및 웹 푸시(VAPID) 설정 호출
    _setupNotifications();

  } catch (e) {
    debugPrint("파이어베이스 초기화 에러: $e");
  }

  runApp(
    // 💡 MultiProvider를 사용하여 여러 Provider를 등록합니다.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => EquipmentProvider()),
        ChangeNotifierProvider(create: (context) => ScheduleProvider()),
        ChangeNotifierProvider(create: (context) => MealPlanProvider()), // 이 줄이 있어야 합니다!
        ChangeNotifierProvider(create: (context) => NoticeProvider()), // 이 줄이 있어야 합니다!
        ChangeNotifierProvider(create: (context) => ExecutiveChecklistProvider()),
        ChangeNotifierProvider(create: (context) => MemberProvider()),
      ],
      child: KustApp(isInitialized: isFirebaseInitialized),
    ),
  );
}

// 💡 알림 권한 및 웹 푸시(VAPID) 설정
Future<void> _setupNotifications() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 권한 요청 (알림 허용 팝업)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('알림 권한 허용됨');

      // 💡 아이폰 PWA 환경에서 푸시를 받으려면 VAPID 키가 반드시 필요합니다.
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
    // 파이어베이스 초기화 실패 시 방어 화면
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
                Text("인터넷 연결을 확인하고 다시 실행해주세요."),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'KUST 동계 원정',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue[800]!),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      builder: (context, child) {
        return MediaQuery(
          // 시스템 폰트 크기 무시 (UI 깨짐 방지)
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

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ScheduleScreen(),
    const NoticeScreen(),
    const MealPlanScreen(),
    const MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // 앱 실행 중(포그라운드) 메시지 수신 시 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.notification!.title ?? '알림', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(message.notification!.body ?? ''),
              ],
            ),
            backgroundColor: Colors.blue[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '일정'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '공지'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '식단'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: '더보기'),

        ],
      ),
    );
  }
}