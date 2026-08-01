import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/dive_log_provider.dart';
import '../providers/member_provider.dart';
import '../models/dive_log_model.dart';
import '../models/member_model.dart';

/// 💡 나의 다이브 로그 + 성장 그래프.
/// 로그인 없이 '내 이름'을 기기에 기억시키고, 로그는 동아리원 문서 밑에 쌓인다.
class DiveLogScreen extends StatefulWidget {
  const DiveLogScreen({super.key});

  @override
  State<DiveLogScreen> createState() => _DiveLogScreenState();
}

class _DiveLogScreenState extends State<DiveLogScreen> {
  static const _prefsKey = 'my_member_id';

  String? _myId;
  bool _loaded = false;

  /// 그래프 기준: 'end'(잔여 바) | 'sac'(분당 소모)
  String _metric = 'end';

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
    _loadMyId();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _siteController.dispose();
    _depthController.dispose();
    _durationController.dispose();
    _startBarController.dispose();
    _endBarController.dispose();
    super.dispose();
  }

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKey);
    if (!mounted) return;
    setState(() {
      _myId = id;
      _loaded = true;
    });
    if (id != null) context.read<DiveLogProvider>().setMember(id);
  }

  Future<void> _pickMe(String memberId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, memberId);
    if (!mounted) return;
    setState(() => _myId = memberId);
    context.read<DiveLogProvider>().setMember(memberId);
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final memberProvider = context.watch<MemberProvider>();

    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    MemberItem? me;
    for (final m in memberProvider.members) {
      if (m.id == _myId) me = m;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('📈 나의 다이브 로그',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (me != null)
            TextButton(
              onPressed: () => setState(() => _myId = null),
              child: Text('이름 변경',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
            ),
        ],
      ),
      body: me == null
          ? _buildNamePicker(memberProvider)
          : _buildLogBody(me),
      floatingActionButton: me != null
          ? FloatingActionButton.extended(
              onPressed: () => _showLogDialog(),
              backgroundColor: Colors.blue[800],
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('로그 추가',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  // ------------------------------------------------------------- 이름 선택

  Widget _buildNamePicker(MemberProvider memberProvider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('내 이름을 선택하세요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Text('이 기기에 기억되고, 내 로그는 내 이름에 쌓입니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in memberProvider.members)
              GestureDetector(
                onTap: () => _pickMe(m.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    '${m.generation}기 ${m.name}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------- 로그 본문

  Widget _buildLogBody(MemberItem me) {
    final provider = context.watch<DiveLogProvider>();
    final logs = provider.logs;

    // 그래프 값 (기준에 따라)
    final values = <double>[];
    final labels = <String>[];
    for (final log in logs) {
      final v = _metric == 'end' ? log.endBar : log.consumptionPerMin;
      if (v == null || (_metric == 'end' && log.endBar <= 0)) continue;
      values.add(v is double ? v : (v as num).toDouble());
      // 'YYYY-MM-DD' → 'M/D'
      final parts = log.date.split('-');
      labels.add(parts.length == 3
          ? '${int.tryParse(parts[1]) ?? parts[1]}/${int.tryParse(parts[2]) ?? parts[2]}'
          : log.date);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
      children: [
        // ── 요약
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text('${me.generation}기 ${me.name}',
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('총 ${logs.length}회',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800])),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 성장 그래프
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('성장 그래프',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  _metricChip('end', '잔여 바'),
                  const SizedBox(width: 6),
                  _metricChip('sac', '분당 소모'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _metric == 'end'
                    ? '다이빙 후 남은 공기. 높아질수록 성장!'
                    : '1분에 쓰는 공기(bar/min). 낮아질수록 성장!',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 170,
                width: double.infinity,
                child: values.length < 2
                    ? Center(
                        child: Text(
                          '로그가 2개 이상 쌓이면 그래프가 그려집니다.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                      )
                    : CustomPaint(
                        painter: _LineChartPainter(
                          values: values,
                          labels: labels,
                          color: _metric == 'end'
                              ? Colors.blue[700]!
                              : Colors.teal[600]!,
                          unit: _metric == 'end' ? 'bar' : '',
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 로그 목록 (최근이 위)
        if (logs.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('로그',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
          ),
        for (var i = logs.length - 1; i >= 0; i--) _logRow(i, logs[i]),
      ],
    );
  }

  Widget _metricChip(String key, String label) {
    final selected = _metric == key;
    return GestureDetector(
      onTap: () => setState(() => _metric = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.blue[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.black54,
            )),
      ),
    );
  }

  Widget _logRow(int index, DiveLog log) {
    final sac = log.consumptionPerMin;
    final infoParts = <String>[
      if (log.depth > 0) '${_fmt(log.depth)}m',
      if (log.duration > 0) '${_fmt(log.duration)}분',
      if (log.startBar > 0) '${_fmt(log.startBar)}→${_fmt(log.endBar)}bar',
      if (sac != null) '소모 ${sac.toStringAsFixed(1)}/분',
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

    final provider = context.read<DiveLogProvider>();

    Widget numField(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, isDense: true),
          ),
        );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(log == null ? '로그 추가' : '로그 수정',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
            ],
          ),
        ),
        actions: [
          if (log != null)
            TextButton(
              onPressed: () {
                provider.deleteLog(log.id);
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
                id: log?.id ?? '',
                date: date,
                site: _siteController.text.trim(),
                depth: num0(_depthController),
                duration: num0(_durationController),
                startBar: num0(_startBarController),
                endBar: num0(_endBarController),
              );
              if (log == null) {
                provider.addLog(newLog);
              } else {
                provider.updateLog(newLog);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
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
      // 값이 전부 같으면 위아래 여유를 준다
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

    // ── 가로 격자 3줄 + 축 라벨
    final gridPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final gv = minV + (maxV - minV) * g / 2;
      final gy = y(gv);
      canvas.drawLine(Offset(leftPad, gy), Offset(size.width - 4, gy), gridPaint);
      _text(canvas, _fmtV(gv), Offset(0, gy - 6), 9.5, Colors.grey[500]!);
    }

    // ── 꺾은선 + 점
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

    // 마지막 값 강조
    final last = values.length - 1;
    _text(
      canvas,
      _fmtV(values[last]) + (unit.isEmpty ? '' : ' $unit'),
      Offset(math.min(x(last) - 14, size.width - 40), y(values[last]) - 18),
      10.5,
      color,
      bold: true,
    );

    // ── X축 날짜 라벨 (겹치지 않게 최대 6개만)
    final step = math.max(1, (values.length / 6).ceil());
    for (var i = 0; i < values.length; i += step) {
      _text(canvas, labels[i], Offset(x(i) - 12, size.height - 13), 9,
          Colors.grey[500]!);
    }
  }

  String _fmtV(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _text(Canvas canvas, String text, Offset offset, double size, Color color,
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
