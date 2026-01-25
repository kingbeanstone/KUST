import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 사용을 위해 필수
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/equipment_provider.dart';
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/notice_screen.dart';
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
  // 1. 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 파이어베이스 초기화
  try {
    if (kIsWeb) {
      // 💡 웹 환경에서는 이 옵션 설정이 index.html의 설정보다 우선시되어야 합니다.
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
    debugPrint("파이어베이스 초기화 성공");
  } catch (e) {
    debugPrint("파이어베이스 초기화 에러: $e");
  }

  // 알림 설정 (비동기 실행)
  _initNotifications();

  runApp(
    ChangeNotifierProvider(
      create: (context) => EquipmentProvider(),
      child: const KustApp(),
    ),
  );
}

// 알림 관련 설정
Future<void> _initNotifications() async {
  try {
    // 웹 브라우저 환경에서도 푸시 알림 인스턴스를 안전하게 가져옵니다.
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    debugPrint("알림 권한 요청 실패 또는 지원되지 않는 브라우저: $e");
  }
}

class KustApp extends StatelessWidget {
  const KustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KUST 동계 원정',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue[800]!),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      // 💡 빌드 에러 로그를 확인하기 위해 간단한 에러 핸들링 추가 (선택 사항)
      builder: (context, child) {
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

    // 포그라운드 메시지 리스너
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${message.notification!.title}: ${message.notification!.body}'),
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