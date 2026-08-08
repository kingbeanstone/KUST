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
              // 💡 이용 추이: 시간이 위→아래, 가로축이 접속 수, 기능별 색깔 선
              const _UsageTrend(),
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

/// 기능별 선 색 (이용 추이 그래프)
const Map<String, Color> _kTrendColors = {
  'weather': Color(0xFFFFB300), // 호박색
  'trip': Color(0xFFFF7043), // 주황(진한)
  'equipment_check': Color(0xFF1E88E5), // 파랑
  'buddy': Color(0xFF00897B), // 청록
  'personal_checklist': Color(0xFF3949AB), // 남색
  'guide': Color(0xFFFB8C00), // 주황
  'growth': Color(0xFF8E24AA), // 보라
  'species': Color(0xFFAFB42B), // 라임
  'game': Color(0xFF546E7A), // 청회색
  'tab_schedule': Color(0xFFD81B60), // 분홍
  'tab_site': Color(0xFF43A047), // 초록
  'earth': Color(0xFF00ACC1), // 청록(밝은)
  'tab_meal': Color(0xFFE53935), // 빨강
  'tab_more': Color(0xFF6D4C41), // 갈색
};

/// 💡 이용 추이 그래프.
/// 시간이 위→아래로 흐르고 가로축(왼→오른쪽)이 접속 수.
/// 기능 8종이 색깔 선으로 함께 그려지며, 범례 칩을 딸깍해 켜고 끌 수 있다.
/// 저장은 시간 버킷이 기본 — 일 단위 보기는 버킷을 합산해 만든다.
class _UsageTrend extends StatefulWidget {
  const _UsageTrend();

  @override
  State<_UsageTrend> createState() => _UsageTrendState();
}

class _UsageTrendState extends State<_UsageTrend> {
  bool _byHour = true; // 기본 = 시간 단위
  final Set<String> _hidden = {}; // 숨긴 기능 선

  Widget _unitChip(String name, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.blue[700] : Colors.grey[100],
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _legendChip(String key) {
    final color = _kTrendColors[key]!;
    final off = _hidden.contains(key);
    return GestureDetector(
      onTap: () => setState(() {
        if (off) {
          _hidden.remove(key);
        } else {
          _hidden.add(key);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: off ? Colors.grey[100] : color.withAlpha(26),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: off ? Colors.grey[400] : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              UsageStats.shortLabels[key] ?? key,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: off
                    ? Colors.grey[500]
                    : Color.lerp(color, Colors.black, 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          Row(
            children: [
              Text('이용 추이',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600])),
              const Spacer(),
              _unitChip('시간 단위', _byHour, () => setState(() => _byHour = true)),
              const SizedBox(width: 5),
              _unitChip(
                  '일 단위', !_byHour, () => setState(() => _byHour = false)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
              _byHour
                  ? '최근 48시간 · 위가 최신 · 오른쪽일수록 많이 사용'
                  : '최근 14일 · 위가 최신 · 오른쪽일수록 많이 사용',
              style: TextStyle(fontSize: 10.5, color: Colors.grey[400])),
          const SizedBox(height: 10),
          // 범례 (딸깍해서 선 켜고 끄기)
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final key in UsageStats.labels.keys) _legendChip(key),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // 💡 orderBy 없이 전체 로드 — 문서 ID 내림차순 정렬은 별도 인덱스가
            //    필요해서 쿼리가 거부됐었다(추이가 안 보이던 원인). 어차피 아래에서
            //    버킷 ID로 직접 조회하므로 정렬이 필요 없다. (원정 규모 = 수백 개 이하)
            stream: UsageStats.hourly.limit(1000).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SizedBox(
                  height: 80,
                  child: Center(
                    child: Text('추이 데이터를 불러오지 못했습니다.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10.5, color: Colors.red[300])),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return SizedBox(
                  height: 80,
                  child: Center(
                    child: Text('아직 추이 데이터가 없습니다.\n지금부터 쌓이기 시작합니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey[400])),
                  ),
                );
              }

              // 버킷 ID → 데이터
              final byId = {for (final d in docs) d.id: d.data()};

              String two(int v) => v.toString().padLeft(2, '0');

              // 💡 활동 없는 시간/일도 0으로 채워 연속된 시간축을 만든다.
              // 위=최신 → 아래=과거 (시간이 아래에서 위로 흐른다).
              // 라벨은 기준 시각에만: 자정=날짜(진한 선), 6·12·18시=보조선.
              final now = DateTime.now();
              final rowLabels = <String>[];
              final rowLevels = <int>[]; // 0 없음 · 1 보조 · 2 날짜 · 3 지금
              final series = {
                for (final k in UsageStats.labels.keys) k: <double>[],
              };

              if (_byHour) {
                for (var i = 0; i <= 47; i++) {
                  final t = now.subtract(Duration(hours: i));
                  final id =
                      '${t.year}-${two(t.month)}-${two(t.day)}-${two(t.hour)}';
                  final data = byId[id];
                  if (t.hour == 0) {
                    rowLabels.add('${t.month}/${t.day}');
                    rowLevels.add(2);
                  } else if (t.hour == 6 || t.hour == 12 || t.hour == 18) {
                    rowLabels.add('${t.hour}시');
                    rowLevels.add(1);
                  } else {
                    rowLabels.add('');
                    rowLevels.add(0);
                  }
                  for (final k in UsageStats.labels.keys) {
                    series[k]!.add(
                        ((data?[k] as num?)?.toInt() ?? 0).toDouble());
                  }
                }
              } else {
                for (var i = 0; i <= 13; i++) {
                  final t = now.subtract(Duration(days: i));
                  final prefix = '${t.year}-${two(t.month)}-${two(t.day)}';
                  rowLabels.add('${t.month}/${t.day}');
                  // 매주 월요일·매달 1일은 진한 구분선
                  rowLevels.add(
                      (t.day == 1 || t.weekday == DateTime.monday) ? 2 : 1);
                  final sums = {for (final k in UsageStats.labels.keys) k: 0};
                  for (final e in byId.entries) {
                    if (!e.key.startsWith(prefix)) continue;
                    for (final k in UsageStats.labels.keys) {
                      sums[k] = sums[k]! + ((e.value[k] as num?)?.toInt() ?? 0);
                    }
                  }
                  for (final k in UsageStats.labels.keys) {
                    series[k]!.add(sums[k]!.toDouble());
                  }
                }
              }

              // 맨 위(현재) 행: 라벨이 없으면 '지금'으로 표시
              if (rowLabels.first.isEmpty) rowLabels[0] = '지금';
              rowLevels[0] = 3;

              final visible = {
                for (final e in series.entries)
                  if (!_hidden.contains(e.key)) e.key: e.value,
              };

              final rowH = _byHour ? 13.0 : 24.0;
              final chartHeight = 24 + rowLabels.length * rowH;

              return SizedBox(
                height: chartHeight,
                width: double.infinity,
                child: CustomPaint(
                  painter: _VerticalTrendPainter(
                    rowLabels: rowLabels,
                    rowLevels: rowLevels,
                    series: visible,
                    colors: _kTrendColors,
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

/// 세로형 다중 꺾은선 그래프 (외부 라이브러리 없이).
/// 세로축 = 시간(위→아래), 가로축 = 접속 수(왼→오른쪽).
/// 시간축 라벨은 기준 시각에만: 자정=날짜(진한 구분선), 6·12·18시=보조선, 지금=파랑.
class _VerticalTrendPainter extends CustomPainter {
  final List<String> rowLabels; // '' = 라벨 없음
  final List<int> rowLevels; // 0 없음 · 1 보조 · 2 날짜(진한 선) · 3 지금(파랑)
  final Map<String, List<double>> series;
  final Map<String, Color> colors;

  _VerticalTrendPainter({
    required this.rowLabels,
    required this.rowLevels,
    required this.series,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 48.0;
    const rightPad = 10.0;
    const topPad = 16.0;
    const bottomPad = 4.0;
    final chartW = size.width - leftPad - rightPad;
    final n = rowLabels.length;
    if (n == 0) return;
    final rowH = (size.height - topPad - bottomPad) / n;

    var maxV = 1.0;
    for (final values in series.values) {
      for (final v in values) {
        if (v > maxV) maxV = v;
      }
    }
    maxV *= 1.08;

    double x(double v) => leftPad + chartW * v / maxV;
    double y(int i) => topPad + rowH * i + rowH / 2;

    // ── 값 눈금 (세로 격자선 + 상단 숫자)
    final gridPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final gv = maxV * g / 2;
      final gx = x(gv);
      canvas.drawLine(Offset(gx, topPad),
          Offset(gx, size.height - bottomPad), gridPaint);
      _text(canvas, gv.round().toString(), Offset(gx - 5, 0), 8.5,
          Colors.grey[500]!);
    }

    // ── 시간축: 기준 시각에만 구분선 + 라벨
    final minorGuide = Paint()
      ..color = const Color(0xFFE3E8EE)
      ..strokeWidth = 1;
    final majorGuide = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 1.3;
    final nowGuide = Paint()
      ..color = Colors.blue[300]!
      ..strokeWidth = 1.2;
    for (var i = 0; i < n; i++) {
      final level = rowLevels[i];
      if (level == 0) continue;
      final paint = level == 2
          ? majorGuide
          : level == 3
              ? nowGuide
              : minorGuide;
      canvas.drawLine(
          Offset(leftPad, y(i)), Offset(size.width - rightPad, y(i)), paint);
      if (rowLabels[i].isEmpty) continue;
      _text(
        canvas,
        rowLabels[i],
        Offset(0, y(i) - 5),
        level == 2 ? 9.5 : 8.5,
        level == 3
            ? Colors.blue[600]!
            : (level == 2 ? Colors.grey[800]! : Colors.grey[500]!),
        bold: level >= 2,
      );
    }

    // ── 기능별 선 (모두 0인 기능은 생략해 왼쪽 끝 겹침을 줄인다)
    for (final e in series.entries) {
      final values = e.value;
      if (values.every((v) => v == 0)) continue;
      final color = colors[e.key] ?? Colors.blueGrey;

      final linePaint = Paint()
        ..color = color.withAlpha(210)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        if (i == 0) {
          path.moveTo(x(values[i]), y(i));
        } else {
          path.lineTo(x(values[i]), y(i));
        }
      }
      canvas.drawPath(path, linePaint);

      // 값이 있는 지점만 점 표시
      final dotPaint = Paint()..color = color;
      for (var i = 0; i < values.length; i++) {
        if (values[i] > 0) {
          canvas.drawCircle(Offset(x(values[i]), y(i)), 2.4, dotPaint);
        }
      }
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
  bool shouldRepaint(covariant _VerticalTrendPainter old) =>
      old.rowLabels != rowLabels || old.series != series;
}
