import 'package:flutter/material.dart';
import 'jurumarble_screen.dart';

/// 💡 미니 게임 허브: 대원들과 함께 하는 게임 모음.
/// 지금은 주루마블 하나 — 앞으로 하나씩 늘려간다.
class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🎮 미니 게임',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const JurumarbleScreen())),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.blue[800]!, Colors.blue[600]!]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Text('🎲', style: TextStyle(fontSize: 34)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('주루마블',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        SizedBox(height: 3),
                        Text('1팀 vs 2팀! 주사위 굴리고 걸린 미션 수행',
                            style: TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Text('🕹', style: TextStyle(fontSize: 28, color: Colors.grey[400])),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('다른 게임도 준비 중이에요!',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[500])),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
