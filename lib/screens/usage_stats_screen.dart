import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../util/usage_stats.dart';

/// 💡 기능별 이용 통계: 누적 접속 횟수를 막대 차트로 보여준다.
class UsageStatsScreen extends StatelessWidget {
  const UsageStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('📊 이용 통계',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: UsageStats.doc.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final raw = snapshot.data!.data() ?? {};
          // 💡 집계 대상 8개는 0회여도 항상 표시. 순서는 labels 맵 정의 순 고정.
          final entries = <MapEntry<String, int>>[
            for (final e in UsageStats.labels.entries)
              MapEntry(e.value, (raw[e.key] as num?)?.toInt() ?? 0),
          ];

          final maxCount =
              entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
          final total = entries.fold<int>(0, (s, e) => s + e.value);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('총 누적 접속',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('$total회',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800])),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('기능별 접속 횟수',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    for (final e in entries) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maxCount == 0
                                    ? 0
                                    : e.value / maxCount,
                                minHeight: 14,
                                backgroundColor: const Color(0xFFF1F3F5),
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.blue[600]!),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text('${e.value}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text('모든 대원의 접속이 실시간으로 누적됩니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
              // 💡 개발자(800) 인증 기기 표시: 이 기기 접속은 집계에 안 들어감
              if (UsageStats.optOut) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text('🧑‍💻 이 기기의 접속은 집계에서 제외되고 있습니다.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[400])),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
