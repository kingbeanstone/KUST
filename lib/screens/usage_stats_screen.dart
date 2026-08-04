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
              const SizedBox(height: 12),
              // 💡 시간대별 히트맵: 기능이 가로, 시간이 세로(아래로 갈수록 최신)
              _HourlyHeatmap(),
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

/// 💡 시간대별 이용 히트맵.
/// 열 = 기능 8종, 행 = 시간(1시간 버킷, 위=과거 → 아래=최신).
/// 칸 색이 진할수록 그 시간대에 많이 쓴 기능.
class _HourlyHeatmap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final keys = UsageStats.labels.keys.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('시간대별 이용',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text('아래로 갈수록 최신 · 색이 진할수록 많이 사용',
              style: TextStyle(fontSize: 10.5, color: Colors.grey[400])),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: UsageStats.hourly
                .orderBy(FieldPath.documentId, descending: true)
                .limit(48)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return SizedBox(
                  height: 60,
                  child: Center(
                    child: Text('아직 시간대별 데이터가 없습니다.\n지금부터 쌓이기 시작합니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey[400])),
                  ),
                );
              }

              // 최신 48시간분을 시간 오름차순(위=과거)으로 표시
              final rows = docs.reversed.toList();

              // 색 농도 기준: 화면에 보이는 칸들 중 최댓값
              var maxCell = 1;
              for (final d in rows) {
                for (final v in d.data().values) {
                  if (v is num && v.toInt() > maxCell) maxCell = v.toInt();
                }
              }

              // '2026-08-04-13' → '8/4 13시'
              String rowLabel(String id) {
                final p = id.split('-');
                if (p.length != 4) return id;
                return '${int.tryParse(p[1]) ?? p[1]}/${int.tryParse(p[2]) ?? p[2]} ${p[3]}시';
              }

              return Column(
                children: [
                  // 열 머리 (기능 이름)
                  Row(
                    children: [
                      const SizedBox(width: 56),
                      for (final k in keys)
                        Expanded(
                          child: Center(
                            child: Text(
                              UsageStats.shortLabels[k] ?? k,
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[500]),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final d in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(rowLabel(d.id),
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.grey[600])),
                          ),
                          for (final k in keys)
                            Expanded(
                              child: Builder(builder: (_) {
                                final count =
                                    (d.data()[k] as num?)?.toInt() ?? 0;
                                final ratio = count / maxCell;
                                return Container(
                                  height: 20,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 1),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: count == 0
                                        ? const Color(0xFFF4F6F8)
                                        : Colors.blue.withAlpha(
                                            (45 + 210 * ratio).toInt()),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: count == 0
                                      ? null
                                      : Text(
                                          '$count',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: ratio > 0.55
                                                ? Colors.white
                                                : Colors.blue[900],
                                          ),
                                        ),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
