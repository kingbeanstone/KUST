import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dive_log_model.dart';

/// 💡 성장 그래프: 로그 기록 → 티어 · 능력치 레이더 · 잔여 바/분당 소모 그래프.
/// 이 기기(브라우저)에만 저장된다 — 열면 바로 내 기록.
class DiveLogScreen extends StatefulWidget {
  const DiveLogScreen({super.key});

  @override
  State<DiveLogScreen> createState() => _DiveLogScreenState();
}

class _DiveLogScreenState extends State<DiveLogScreen> {
  static const _prefsKey = 'my_dive_logs';
  static const _baseKey = 'my_dive_log_base';

  List<DiveLog> _logs = [];

  /// 앱 기록 전까지 쌓아둔 로그 수 (선배들의 기존 로그북 반영용)
  int _baseCount = 0;
  bool _loaded = false;

  final TextEditingController _baseController = TextEditingController();

  /// 로그 입력 컨트롤러 — State 소유 (dispose 크래시 방지)
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _siteController = TextEditingController();
  final TextEditingController _depthController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _startBarController = TextEditingController();
  final TextEditingController _endBarController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseController.dispose();
    _dateController.dispose();
    _siteController.dispose();
    _depthController.dispose();
    _durationController.dispose();
    _startBarController.dispose();
    _endBarController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- 저장/불러오기

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final logs = <DiveLog>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        for (final item in jsonDecode(raw) as List) {
          final map = Map<String, dynamic>.from(item);
          logs.add(DiveLog.fromMap((map['id'] ?? '').toString(), map));
        }
      } catch (e) {
        debugPrint('다이브 로그 로드 실패: $e');
      }
    }
    _sort(logs);
    final base = prefs.getInt(_baseKey) ?? 0;
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _baseCount = base;
      _loaded = true;
    });
  }

  Future<void> _saveBase(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_baseKey, value);
  }

  /// 기존 로그 수 입력 다이얼로그
  void _showBaseDialog() {
    _baseController.text = _baseCount > 0 ? '$_baseCount' : '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('기존 로그 수',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('앱에 기록하기 전까지 로그북에 쌓아둔 횟수를 넣으면\n총 로그 수와 티어에 합산됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5)),
            const SizedBox(height: 10),
            TextField(
              controller: _baseController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '기존 로그 수 (예: 120)', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(_baseController.text.trim()) ?? 0;
              setState(() => _baseCount = value < 0 ? 0 : value);
              _saveBase(_baseCount);
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _sort(List<DiveLog> logs) {
    logs.sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : a.id.compareTo(b.id);
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([
        for (final log in _logs) {'id': log.id, ...log.toMap()},
      ]),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  // ------------------------------------------------------------- 티어

  /// 로그 수 → 티어 (이름, 색, 다음 티어까지 남은 횟수)
  (String, Color, int?) _tierOf(int n) {
    const steps = [
      (100, '챌린저'),
      (75, '마스터'),
      (50, '다이아'),
      (35, '플래티넘'),
      (20, '골드'),
      (10, '실버'),
      (5, '브론즈'),
      (1, '아이언'),
    ];
    const colors = {
      '챌린저': Color(0xFFF57F17),
      '마스터': Color(0xFF7B1FA2),
      '다이아': Color(0xFF29B6F6),
      '플래티넘': Color(0xFF00897B),
      '골드': Color(0xFFF9A825),
      '실버': Color(0xFF78909C),
      '브론즈': Color(0xFF8D6E63),
      '아이언': Color(0xFF616161),
    };

    for (var i = 0; i < steps.length; i++) {
      if (n >= steps[i].$1) {
        final next = i == 0 ? null : steps[i - 1].$1 - n;
        return (steps[i].$2, colors[steps[i].$2]!, next);
      }
    }
    return ('언랭', const Color(0xFFBDBDBD), 1 - n);
  }

  /// 요소별 평가 평균 (평가된 로그만)
  Map<String, double> _skillAverages() {
    final sums = <String, int>{};
    final counts = <String, int>{};
    for (final log in _logs) {
      for (final e in log.scores.entries) {
        sums[e.key] = (sums[e.key] ?? 0) + e.value;
        counts[e.key] = (counts[e.key] ?? 0) + 1;
      }
    }
    return {
      for (final key in kDiveSkills.keys)
        if ((counts[key] ?? 0) > 0) key: sums[key]! / counts[key]!,
    };
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 꺾은선 그래프 데이터
    final endValues = <double>[];
    final endLabels = <String>[];
    final sacValues = <double>[];
    final sacLabels = <String>[];
    for (final log in _logs) {
      final label = _shortDate(log.date);
      if (log.endBar > 0) {
        endValues.add(log.endBar);
        endLabels.add(label);
      }
      final sac = log.consumptionPerMin;
      if (sac != null) {
        sacValues.add(sac);
        sacLabels.add(label);
      }
    }

    final averages = _skillAverages();
    final totalLogs = _baseCount + _logs.length;
    final (tierName, tierColor, tierNext) = _tierOf(totalLogs);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('📈 성장 그래프',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
        children: [
          // ── 티어 + 로그 수
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tierColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(tierName,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('총 $totalLogs회 로그',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        _baseCount > 0
                            ? '기존 $_baseCount + 앱 기록 ${_logs.length}'
                                '${tierNext != null ? ' · 다음 티어까지 $tierNext회' : ''}'
                            : (tierNext != null ? '다음 티어까지 $tierNext회' : ''),
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                // 기존 로그 수 입력 (선배들의 누적 로그 반영)
                GestureDetector(
                  onTap: _showBaseDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text('기존 로그',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600])),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 능력치 레이더
          _card(
            title: '능력치',
            subtitle: '로그마다 셀프 평가한 점수의 평균 — 강점과 약점이 보입니다.',
            child: averages.isEmpty
                ? _placeholder('로그 기록 시 셀프 평가를 하면 능력치가 그려집니다.')
                : Column(
                    children: [
                      SizedBox(
                        height: 210,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _RadarChartPainter(
                            labels: kDiveSkills.values.toList(),
                            // 미평가 요소는 0으로 (비어 보이게)
                            values: [
                              for (final key in kDiveSkills.keys)
                                (averages[key] ?? 0) / 4.0,
                            ],
                            color: Colors.blue[700]!,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          for (final e in kDiveSkills.entries)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '${e.value} ${averages[e.key] == null ? '-' : averages[e.key]!.toStringAsFixed(1)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // ── 잔여 바 그래프
          _card(
            title: '잔여 바',
            subtitle: '다이빙 후 남은 공기. 높아질수록 성장!',
            child: _lineChart(endValues, endLabels, Colors.blue[700]!, 'bar'),
          ),
          const SizedBox(height: 12),

          // ── 분당 소모 그래프
          _card(
            title: '분당 소모',
            subtitle: '1분에 쓰는 공기(bar/min). 낮아질수록 성장!',
            child: _lineChart(sacValues, sacLabels, Colors.teal[600]!, ''),
          ),
          const SizedBox(height: 12),

          // ── 로그 목록 (최근이 위)
          if (_logs.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text('로그',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
            ),
          for (var i = _logs.length - 1; i >= 0; i--) _logRow(i, _logs[i]),

          const SizedBox(height: 10),
          Center(
            child: Text('이 기록은 내 기기에만 저장됩니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogDialog(),
        backgroundColor: Colors.blue[800],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('로그 추가',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _shortDate(String date) {
    final parts = date.split('-');
    return parts.length == 3
        ? '${int.tryParse(parts[1]) ?? parts[1]}/${int.tryParse(parts[2]) ?? parts[2]}'
        : date;
  }

  Widget _card(
      {required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _placeholder(String text) => SizedBox(
        height: 80,
        child: Center(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ),
      );

  Widget _lineChart(
      List<double> values, List<String> labels, Color color, String unit) {
    if (values.length < 2) {
      return _placeholder('로그가 2개 이상 쌓이면 그래프가 그려집니다.');
    }
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(
            values: values, labels: labels, color: color, unit: unit),
      ),
    );
  }

  Widget _logRow(int index, DiveLog log) {
    final sac = log.consumptionPerMin;
    final scoreAvg = log.scores.isEmpty
        ? null
        : log.scores.values.reduce((a, b) => a + b) / log.scores.length;
    final infoParts = <String>[
      if (log.depth > 0) '${_fmt(log.depth)}m',
      if (log.duration > 0) '${_fmt(log.duration)}분',
      if (log.startBar > 0) '${_fmt(log.startBar)}→${_fmt(log.endBar)}bar',
      if (sac != null) '소모 ${sac.toStringAsFixed(1)}/분',
      if (scoreAvg != null) '평가 ${scoreAvg.toStringAsFixed(1)}',
    ];

    return GestureDetector(
      onTap: () => _showLogDialog(log: log),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800])),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log.date}${log.site.isNotEmpty ? ' · ${log.site}' : ''}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (infoParts.isNotEmpty)
                    Text(infoParts.join('  ·  '),
                        style:
                            TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, size: 13, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- 로그 입력

  void _showLogDialog({DiveLog? log}) {
    final now = DateTime.now();
    _dateController.text = log?.date ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _siteController.text = log?.site ?? '';
    _depthController.text = log != null && log.depth > 0 ? _fmt(log.depth) : '';
    _durationController.text =
        log != null && log.duration > 0 ? _fmt(log.duration) : '';
    _startBarController.text =
        log != null && log.startBar > 0 ? _fmt(log.startBar) : '';
    _endBarController.text =
        log != null && log.endBar > 0 ? _fmt(log.endBar) : '';

    // 셀프 평가 점수 (다이얼로그 안 로컬 상태)
    final scores = Map<String, int>.from(log?.scores ?? {});

    Widget numField(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, isDense: true),
          ),
        );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(log == null ? '로그 추가' : '로그 수정',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                            labelText: '날짜 (YYYY-MM-DD)', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _siteController,
                        decoration: const InputDecoration(
                            labelText: '장소', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    numField(_depthController, '수심 m'),
                    const SizedBox(width: 8),
                    numField(_durationController, '시간 분'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    numField(_startBarController, '시작 bar'),
                    const SizedBox(width: 8),
                    numField(_endBarController, '종료 bar'),
                  ],
                ),
                const SizedBox(height: 16),
                Text('셀프 평가',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600])),
                const SizedBox(height: 6),
                for (final skill in kDiveSkills.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text(skill.value,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              for (final grade in kSkillGrades.entries)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setDialogState(() {
                                      // 같은 등급 다시 탭 = 평가 해제
                                      if (scores[skill.key] == grade.key) {
                                        scores.remove(skill.key);
                                      } else {
                                        scores[skill.key] = grade.key;
                                      }
                                    }),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1.5),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: scores[skill.key] == grade.key
                                            ? Colors.blue[700]
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Text(
                                        grade.value,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: scores[skill.key] == grade.key
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (log != null)
              TextButton(
                onPressed: () {
                  setState(() => _logs.removeWhere((l) => l.id == log.id));
                  _save();
                  Navigator.pop(dialogContext);
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                double num0(TextEditingController c) =>
                    double.tryParse(c.text.trim()) ?? 0;

                final date = _dateController.text.trim();
                if (date.isEmpty) return;
                final newLog = DiveLog(
                  id: log?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  date: date,
                  site: _siteController.text.trim(),
                  depth: num0(_depthController),
                  duration: num0(_durationController),
                  startBar: num0(_startBarController),
                  endBar: num0(_endBarController),
                  scores: Map<String, int>.from(scores),
                );
                setState(() {
                  _logs.removeWhere((l) => l.id == newLog.id);
                  _logs.add(newLog);
                  _sort(_logs);
                });
                _save();
                Navigator.pop(dialogContext);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 간단한 꺾은선 그래프 (외부 라이브러리 없이)
class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final String unit;

  _LineChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 34.0;
    const bottomPad = 18.0;
    const topPad = 12.0;
    final chartW = size.width - leftPad - 6;
    final chartH = size.height - topPad - bottomPad;

    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    if ((maxV - minV).abs() < 0.001) {
      maxV += 1;
      minV -= 1;
    } else {
      final margin = (maxV - minV) * 0.15;
      maxV += margin;
      minV -= margin;
    }
    if (minV < 0) minV = 0;

    double x(int i) => values.length == 1
        ? leftPad + chartW / 2
        : leftPad + chartW * i / (values.length - 1);
    double y(double v) => topPad + chartH * (1 - (v - minV) / (maxV - minV));

    final gridPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final gv = minV + (maxV - minV) * g / 2;
      final gy = y(gv);
      canvas.drawLine(
          Offset(leftPad, gy), Offset(size.width - 4, gy), gridPaint);
      _text(canvas, _fmtV(gv), Offset(0, gy - 6), 9.5, Colors.grey[500]!);
    }

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

    final dotPaint = Paint()..color = color;
    final dotOutline = Paint()..color = Colors.white;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), 4, dotOutline);
      canvas.drawCircle(Offset(x(i), y(values[i])), 3, dotPaint);
    }

    final last = values.length - 1;
    _text(
      canvas,
      _fmtV(values[last]) + (unit.isEmpty ? '' : ' $unit'),
      Offset(math.min(x(last) - 14, size.width - 40), y(values[last]) - 18),
      10.5,
      color,
      bold: true,
    );

    final step = math.max(1, (values.length / 6).ceil());
    for (var i = 0; i < values.length; i += step) {
      _text(canvas, labels[i], Offset(x(i) - 12, size.height - 13), 9,
          Colors.grey[500]!);
    }
  }

  String _fmtV(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

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
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values || old.color != color;
}

/// 5각 능력치 레이더 차트
class _RadarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values; // 0.0 ~ 1.0
  final Color color;

  _RadarChartPainter({
    required this.labels,
    required this.values,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    final center = Offset(size.width / 2, size.height / 2 + 4);
    final radius = math.min(size.width, size.height) / 2 - 26;

    Offset point(int i, double r) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      return Offset(
          center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
    }

    // ── 배경 격자 (4단계 링) + 축선
    final gridPaint = Paint()
      ..color = const Color(0xFFE3E8EE)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var level = 1; level <= 4; level++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = point(i, radius * level / 4);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, point(i, radius), gridPaint);
    }

    // ── 데이터 다각형
    final fillPaint = Paint()..color = color.withAlpha(56);
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final p = point(i, radius * values[i].clamp(0.0, 1.0));
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    final dotPaint = Paint()..color = color;
    for (var i = 0; i < n; i++) {
      final p = point(i, radius * values[i].clamp(0.0, 1.0));
      canvas.drawCircle(p, 3, dotPaint);
    }

    // ── 축 라벨
    for (var i = 0; i < n; i++) {
      final p = point(i, radius + 14);
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
          canvas, Offset(p.dx - painter.width / 2, p.dy - painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter old) =>
      old.values != values || old.color != color;
}
