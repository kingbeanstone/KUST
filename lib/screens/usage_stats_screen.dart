import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../util/usage_stats.dart';

/// 💡 기능별 이용 통계: 누적 접속 횟수를 막대 차트로 보여준다.
class UsageStatsScreen extends StatefulWidget {
  const UsageStatsScreen({super.key});

  @override
  State<UsageStatsScreen> createState() => _UsageStatsScreenState();
}

class _UsageStatsScreenState extends State<UsageStatsScreen> {
  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
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
          final entries = <MapEntry<String, int>>[
            for (final e in raw.entries)
              if (e.value is num)
                MapEntry(UsageStats.labels[e.key] ?? e.key,
                    (e.value as num).toInt()),
          ]..sort((a, b) => b.value.compareTo(a.value));

          if (entries.isEmpty) {
            return const Center(
              child: Text('아직 집계된 데이터가 없습니다.',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            );
          }

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
              // 💡 관리자 전용: 개발/운영 기기의 접속으로 통계가 오염되지 않도록
              //    이 기기에서의 접속을 집계에서 제외하는 스위치 (기기별 저장)
              if (isAdmin) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    value: UsageStats.optOut,
                    onChanged: (v) async {
                      await UsageStats.setOptOut(v);
                      if (mounted) setState(() {});
                    },
                    title: const Text('이 기기 접속은 집계에서 제외',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('관리자/개발 기기의 접속이 통계에 섞이지 않게 합니다.',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                    activeThumbColor: Colors.blue[600],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
