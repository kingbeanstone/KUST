import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/equipment_provider.dart';
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/notice_screen.dart';
import 'screens/meal_plan_screen.dart';
import 'screens/more_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 권한 요청
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
  } catch (e) {
    debugPrint("Firebase 초기화 에러: $e");
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => EquipmentProvider(),
      child: const KustApp(),
    ),
  );
}

class KustApp extends StatelessWidget {
  const KustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KUST 동계 원정',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
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
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${message.notification!.title}: ${message.notification!.body}'),
            backgroundColor: Colors.blue[800],
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