import 'package:flutter/material.dart';

/// 💡 서비스 준비 중 화면 — 개발 중인 탭을 배포(릴리즈) 빌드에서 가릴 때 사용.
/// 디버그(핫리로드)에서는 실제 화면이 보이도록 main.dart에서 kReleaseMode로 분기한다.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🚧', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            const Text('서비스 준비 중입니다',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '다이브 사이트 지도를 다듬고 있어요.\n조금만 기다려주세요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[500], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
