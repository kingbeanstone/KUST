import 'package:flutter/material.dart';

/// 💡 생물 도감 (개발 중 — 개발자(800) 전용 미리보기).
/// 울릉도에서 만나는 해양 생물을 사진·설명과 함께 보는 도감이 될 예정.
class SpeciesGuideScreen extends StatelessWidget {
  const SpeciesGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🐠 생물 도감',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚧', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('생물 도감 개발 중',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('개발자 전용 미리보기 화면입니다.\n여기에 도감 기능이 만들어질 예정이에요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, color: Colors.grey[500], height: 1.5)),
          ],
        ),
      ),
    );
  }
}
