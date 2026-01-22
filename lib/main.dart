import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'providers/equipment_provider.dart';
import 'screens/input_screen.dart';
import 'screens/checklist_screen.dart';
import 'screens/search_screen.dart';
import 'screens/meal_plan_screen.dart';
import 'screens/more_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
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

  // 5개의 화면을 인덱스 스택에 배치하여 탭 전환 지원
  final List<Widget> _screens = [
    const InputScreen(),
    const ChecklistScreen(),
    const SearchScreen(),
    const MealPlanScreen(),
    const MoreScreen(),
  ];

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
        type: BottomNavigationBarType.fixed, // 5개 탭을 위해 필수 설정
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: '정보 입력'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check), label: '체크리스트'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_search), label: '장비 검색'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: '식단표'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: '더보기'),
        ],
      ),
    );
  }
}