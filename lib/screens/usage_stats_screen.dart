import 'dart:math' as math;

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
              // 💡 일별 이용 추이: 하루 증가량을 점으로 찍어 선으로 잇는다
              const _DailyTrend(),
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

/// 💡 일별 이용 추이: 하루 동안 늘어난 접속 수를 점으로 찍어 선으로 잇는다.
/// 상단 칩으로 전체 합계 또는 기능 하나를 골라 본다 (딸깍).
class _DailyTrend extends StatefulWidget {
  const _DailyTrend();

  @override
  State<_DailyTrend> createState() => _DailyTrendState();
}

class _DailyTrendState extends State<_DailyTrend> {
  String _filter = 'all'; // 'all' 또는 기능 키

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('일별 이용 추이',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text('하루 동안 늘어난 접속 수',
              style: TextStyle(fontSize: 10.5, color: Colors.grey[400])),
          const SizedBox(height: 10),
          // 기능 필터 칩
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final (key, name) in [
                ('all', '전체'),
                for (final e in UsageStats.shortLabels.entries)
                  (e.key, e.value),
              ])
                GestureDetector(
                  onTap: () => setState(() => _filter = key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          _filter == key ? Colors.blue[700] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            _filter == key ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: UsageStats.daily
                .orderBy(FieldPath.documentId, descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              // 최근 30일분을 날짜 오름차순으로
              final rows = docs.reversed.toList();

              final values = <double>[];
              final labels = <String>[];
              for (final d in rows) {
                final data = d.data();
                int count;
                if (_filter == 'all') {
                  count = 0;
                  for (final k in UsageStats.labels.keys) {
                    count += (data[k] as num?)?.toInt() ?? 0;
                  }
                } else {
                  count = (data[_filter] as num?)?.toInt() ?? 0;
                }
                values.add(count.toDouble());
                // '2026-08-04' → '8/4'
                final p = d.id.split('-');
                labels.add(p.length == 3
                    ? '${int.tryParse(p[1]) ?? p[1]}/${int.tryParse(p[2]) ?? p[2]}'
                    : d.id);
              }

              if (values.length < 2) {
                return SizedBox(
                  height: 80,
                  child: Center(
                    child: Text('이틀 이상 쌓이면 선이 그려집니다.',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey[400])),
                  ),
                );
              }

              return SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendLinePainter(
                    values: values,
                    labels: labels,
                    color: Colors.blue[700]!,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 간단한 꺾은선 그래프 (외부 라이브러리 없이)
class _TrendLinePainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;

  _TrendLinePainter({
    required this.values,
    required this.labels,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 30.0;
    const bottomPad = 18.0;
    const topPad = 14.0;
    final chartW = size.width - leftPad - 8;
    final chartH = size.height - topPad - bottomPad;

    var minV = 0.0;
    var maxV = values.reduce(math.max);
    if (maxV < 1) maxV = 1;
    maxV *= 1.15;

    double x(int i) => values.length == 1
        ? leftPad + chartW / 2
        : leftPad + chartW * i / (values.length - 1);
    double y(double v) => topPad + chartH * (1 - (v - minV) / (maxV - minV));

    // 가로 눈금 3줄 + 값
    final gridPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final gv = minV + (maxV - minV) * g / 2;
      final gy = y(gv);
      canvas.drawLine(
          Offset(leftPad, gy), Offset(size.width - 4, gy), gridPaint);
      _text(canvas, gv.round().toString(), Offset(0, gy - 6), 9.5,
          Colors.grey[500]!);
    }

    // 꺾은선
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      if (i == 0) {
        path.moveTo(x(i), y(values[i]));
      } else {
        path.lineTo(x(i), y(values[i]));
      }
    }
    canvas.drawPath(path, linePaint);

    // 점
    final dotPaint = Paint()..color = color;
    final dotOutline = Paint()..color = Colors.white;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), 4, dotOutline);
      canvas.drawCircle(Offset(x(i), y(values[i])), 3, dotPaint);
    }

    // 마지막 값 강조
    final last = values.length - 1;
    _text(
      canvas,
      values[last].round().toString(),
      Offset(math.min(x(last) - 8, size.width - 30), y(values[last]) - 18),
      10.5,
      color,
      bold: true,
    );

    // 날짜 라벨 (겹치지 않게 건너뛰기)
    final step = math.max(1, (values.length / 7).ceil());
    for (var i = 0; i < values.length; i += step) {
      _text(canvas, labels[i], Offset(x(i) - 10, size.height - 13), 9,
          Colors.grey[500]!);
    }
  }

  void _text(
      Canvas canvas, String text, Offset offset, double size, Color color,
      {bool bold = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter old) =>
      old.values != values || old.color != color;
}
