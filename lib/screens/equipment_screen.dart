import 'package:flutter/material.dart';
import 'equipment_check_screen.dart';
import 'search_screen.dart';

/// 💡 v2: 흩어져 있던 장비 기능(목록/체크/검색)의 단일 진입점.
/// 내부 구성은 추후 확정 예정 (현재는 기존 화면으로 연결만).
class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('장비', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _menuTile(
            context,
            title: '장비 체크',
            subtitle: '버디 조별 장비 현황 · 수정',
            icon: Icons.checklist_rtl_rounded,
            color: Colors.green,
            target: const EquipmentCheckScreen(),
          ),
          const SizedBox(height: 12),
          _menuTile(
            context,
            title: '장비 인벤토리',
            subtitle: 'BCD·호흡기 번호 및 공용 장비 수량',
            icon: Icons.inventory_2_outlined,
            color: Colors.orange,
            target: const SearchScreen(),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget target,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => target)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
