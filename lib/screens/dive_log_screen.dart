import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dive_log_model.dart';
import '../providers/dive_site_provider.dart';

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
        actions: [
          // 💡 예시 미리보기: 데이터를 넣으면 어떤 그림이 되는지 보여준다
          IconButton(
            icon: Icon(Icons.help_outline, color: Colors.grey[600]),
            tooltip: '예시 보기',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _GrowthDemoScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
        children: [
          // ── 티어 엠블럼 + 로그 수
          Container(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 💡 왼쪽 화려한 엠블럼 + 오른쪽 티어 기준 사다리
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _TierEmblem(
                            color: tierColor,
                            size: 134,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$totalLogs',
                                      style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.0)),
                                  const Text('로그',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(tierName,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: tierColor,
                                  letterSpacing: 1)),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (_baseCount > 0)
                                '기존 $_baseCount + 앱 ${_logs.length}',
                              if (tierNext != null) '다음 티어까지 $tierNext회',
                            ].join('\n'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[600],
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TierLadder(total: totalLogs),
                  ],
                ),
                const SizedBox(height: 12),
                // 기존 로그 수 입력 (선배들의 누적 로그 반영)
                GestureDetector(
                  onTap: _showBaseDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text('기존 로그 수 입력',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey[600])),
                  ),
                ),
                const SizedBox(height: 8),
                Text('티어와 로그 수는 재미로만 봐주세요 😄',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[400])),
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
      if (log.startTime.isNotEmpty && log.endTime.isNotEmpty)
        '${log.startTime}~${log.endTime}',
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

    // 셀프 평가 점수·시간 (다이얼로그 안 로컬 상태)
    final scores = Map<String, int>.from(log?.scores ?? {});
    var startTime = log?.startTime ?? '';
    var endTime = log?.endTime ?? '';

    // 사이트 탭에 등록된 포인트 이름들 (칩 선택용)
    final siteNames = [
      for (final s in context.read<DiveSiteProvider>().sites) s.name,
    ];

    Widget numField(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, isDense: true),
          ),
        );

    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    // 시작·종료가 모두 있으면 다이빙 시간(분)을 자동 계산해 채운다
    void recalcDuration() {
      if (startTime.isEmpty || endTime.isEmpty) return;
      final s = startTime.split(':');
      final e = endTime.split(':');
      var minutes = (int.parse(e[0]) * 60 + int.parse(e[1])) -
          (int.parse(s[0]) * 60 + int.parse(s[1]));
      if (minutes <= 0) minutes += 24 * 60; // 자정 넘김 대비
      _durationController.text = '$minutes';
    }

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
                            labelText: '장소 (직접 입력 가능)', isDense: true),
                      ),
                    ),
                  ],
                ),
                // 💡 사이트 탭의 포인트를 딸깍으로 선택
                if (siteNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final name in siteNames)
                        GestureDetector(
                          onTap: () => setDialogState(
                              () => _siteController.text = name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: _siteController.text == name
                                  ? Colors.blue[700]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _siteController.text == name
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // 💡 입수·출수 시각 (탭 → 시계 선택) — 시간(분) 자동 계산
                Row(
                  children: [
                    for (final isStart in [true, false]) ...[
                      if (!isStart) const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              if (isStart) {
                                startTime = fmtTime(picked);
                              } else {
                                endTime = fmtTime(picked);
                              }
                              recalcDuration();
                            });
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: isStart ? '입수 시각' : '출수 시각',
                              isDense: true,
                            ),
                            child: Text(
                              (isStart ? startTime : endTime).isEmpty
                                  ? '--:--'
                                  : (isStart ? startTime : endTime),
                              style: TextStyle(
                                fontSize: 14,
                                color: (isStart ? startTime : endTime).isEmpty
                                    ? Colors.grey[400]
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    numField(_depthController, '수심 m'),
                    const SizedBox(width: 8),
                    numField(_durationController, '시간 분 (자동 계산)'),
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
                  startTime: startTime,
                  endTime: endTime,
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

// ------------------------------------------------------------- 티어 체계

/// 티어 기준 (내림차순): 이 로그 수 이상이면 해당 티어
const List<(int, String)> _kTierSteps = [
  (200, '챌린저'),
  (170, '마스터'),
  (130, '다이아'),
  (90, '플래티넘'),
  (50, '골드'),
  (25, '실버'),
  (10, '브론즈'),
  (1, '아이언'),
];

const Map<String, Color> _kTierColors = {
  '챌린저': Color(0xFFF57F17),
  '마스터': Color(0xFF7B1FA2),
  '다이아': Color(0xFF29B6F6),
  '플래티넘': Color(0xFF00897B),
  '골드': Color(0xFFF9A825),
  '실버': Color(0xFF78909C),
  '브론즈': Color(0xFF8D6E63),
  '아이언': Color(0xFF616161),
};

/// 로그 수 → (표시명, 색, 다음 티어까지 남은 횟수).
/// 💡 롤처럼 마스터 미만 티어는 구간을 4등분한 세부 티어(4→1)가 붙는다.
(String, Color, int?) _tierOf(int n) {
  for (var i = 0; i < _kTierSteps.length; i++) {
    final (start, name) = _kTierSteps[i];
    if (n < start) continue;

    final color = _kTierColors[name]!;
    if (i == 0) return (name, color, null); // 챌린저: 최고 티어
    final nextStart = _kTierSteps[i - 1].$1;

    var label = name;
    if (i >= 2) {
      // 마스터 미만: 구간 4등분, 숫자가 작을수록 높은 세부 티어
      final span = (nextStart - start) / 4;
      final div = (4 - ((n - start) / span).floor()).clamp(1, 4);
      label = '$name $div';
    }
    return (label, color, nextStart - n);
  }
  return ('언랭', const Color(0xFFBDBDBD), 1 - n);
}

/// 💡 예시 미리보기(? 버튼): 가짜 데이터로 티어·능력치·그래프가
/// 어떤 그림이 되는지 보여준다. 저장과는 무관한 구경용 화면.
class _GrowthDemoScreen extends StatelessWidget {
  const _GrowthDemoScreen();

  @override
  Widget build(BuildContext context) {
    // 꺾임이 살아있는 예시 수치 (전체적으로는 성장 추세)
    const endValues = [45.0, 70.0, 55.0, 85.0, 65.0, 95.0, 110.0];
    const sacValues = [17.5, 13.8, 15.6, 12.2, 13.9, 10.4, 9.6];
    const labels = ['8/4', '8/5', '8/5', '8/6', '8/7', '8/8', '8/9'];
    const radarValues = [0.80, 0.55, 0.65, 0.90, 0.70];
    const tierColor = Color(0xFFF9A825); // 골드

    Widget card(String title, String subtitle, Widget child) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 10),
              child,
            ],
          ),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('이렇게 기록돼요 (예시)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          // 안내 배너
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: const Text(
              '아래는 예시 데이터입니다.\n로그를 기록하면 내 기록으로 이렇게 그려져요!',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),

          // 티어 엠블럼 예시 (82로그 = 골드 1)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const _TierEmblem(
                        color: tierColor,
                        size: 134,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('82',
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.0)),
                              Text('로그',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('골드 1',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: tierColor,
                              letterSpacing: 1)),
                      const SizedBox(height: 3),
                      Text('기존 75 + 앱 7\n다음 티어까지 8회',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey[600],
                              height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const _TierLadder(total: 82),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 능력치 레이더 예시
          card(
            '능력치',
            '로그마다 셀프 평가한 점수의 평균 — 강점과 약점이 보입니다.',
            SizedBox(
              height: 210,
              width: double.infinity,
              child: CustomPaint(
                painter: _RadarChartPainter(
                  labels: kDiveSkills.values.toList(),
                  values: radarValues,
                  color: Colors.blue[700]!,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 잔여 바 예시
          card(
            '잔여 바',
            '다이빙 후 남은 공기. 높아질수록 성장!',
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(
                painter: _LineChartPainter(
                    values: endValues,
                    labels: labels,
                    color: Colors.blue[700]!,
                    unit: 'bar'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 분당 소모 예시
          card(
            '분당 소모',
            '1분에 쓰는 공기(bar/min). 낮아질수록 성장!',
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(
                painter: _LineChartPainter(
                    values: sacValues,
                    labels: labels,
                    color: Colors.teal[600]!,
                    unit: ''),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 로그 목록 예시 한 줄
          card(
            '로그 목록',
            '기록한 로그는 이렇게 쌓입니다. 탭하면 수정할 수 있어요.',
            Column(
              children: [
                for (final (n, date, site, info) in const [
                  (7, '2026-08-09', '죽도', '10:12~10:58 · 22m · 46분 · 200→110bar'),
                  (6, '2026-08-08', '관음도', '14:05~14:47 · 18m · 42분 · 200→95bar'),
                ])
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 10),
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
                          child: Text('$n',
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
                              Text('$date · $site',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text(info,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 💡 살아있는 티어 엠블럼: 광택이 흐르고 별이 반짝이는 애니메이션 래퍼
class _TierEmblem extends StatefulWidget {
  final Color color;
  final double size;
  final Widget child;

  const _TierEmblem(
      {required this.color, required this.size, required this.child});

  @override
  State<_TierEmblem> createState() => _TierEmblemState();
}

class _TierEmblemState extends State<_TierEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => CustomPaint(
          painter:
              _TierBadgePainter(color: widget.color, t: _controller.value),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 💡 롤 티어 느낌의 화려한 육각 엠블럼:
/// 양옆 날개 + 보석 단면(파세트) + 꼭짓점 보석 + 흐르는 광택 + 반짝이 별
class _TierBadgePainter extends CustomPainter {
  final Color color;
  final double t; // 애니메이션 진행도 0~1

  _TierBadgePainter({required this.color, this.t = 0});

  Offset _vertex(Offset center, double r, int i) {
    final angle = -math.pi / 2 + math.pi / 3 * i;
    return Offset(
        center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
  }

  Path _hexagon(Offset center, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final p = _vertex(center, r, i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 날개가 밖으로 뻗을 공간을 남기고 본체 반지름을 잡는다
    final r = math.min(size.width, size.height) / 2 - 16;

    final darker = Color.lerp(color, Colors.black, 0.62)!;
    final dark = Color.lerp(color, Colors.black, 0.42)!;
    final light = Color.lerp(color, Colors.white, 0.3)!;
    final lighter = Color.lerp(color, Colors.white, 0.55)!;

    // ── 숨쉬는 후광
    final glowPulse = 0.7 + 0.3 * math.sin(t * 2 * math.pi);
    canvas.drawPath(
      _hexagon(center, r + 4),
      Paint()
        ..color = color.withAlpha((85 * glowPulse).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // ── 양옆 날개 (깃털 3장씩, 아래→위로 갈수록 길게)
    for (final sign in [-1.0, 1.0]) {
      for (var k = 0; k < 3; k++) {
        final baseX = center.dx + sign * r * 0.7;
        final baseY = center.dy + r * (0.45 - 0.35 * k);
        final tipX = center.dx + sign * r * (1.26 + 0.07 * k);
        final tipY = baseY - r * (0.36 + 0.06 * k);
        final feather = Path()
          ..moveTo(baseX, baseY)
          ..quadraticBezierTo(center.dx + sign * r * 1.32,
              baseY + r * 0.05, tipX, tipY)
          ..quadraticBezierTo(center.dx + sign * r * 0.95,
              baseY - r * 0.28, baseX, baseY - r * 0.2)
          ..close();
        canvas.drawPath(
          feather,
          Paint()
            ..shader = LinearGradient(
              begin: sign < 0 ? Alignment.centerRight : Alignment.centerLeft,
              end: sign < 0 ? Alignment.centerLeft : Alignment.centerRight,
              colors: [light, dark],
            ).createShader(
                Rect.fromCircle(center: center, radius: r * 1.4)),
        );
        canvas.drawPath(
          feather,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = darker.withAlpha(150),
        );
      }
    }

    // ── 본체 (위→아래 그라데이션)
    final body = _hexagon(center, r);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lighter, color, darker],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // ── 파세트: 중심→꼭짓점 삼각형을 밝음/어두움 교차로 겹쳐 보석 단면 느낌
    for (var i = 0; i < 6; i++) {
      final tri = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(_vertex(center, r, i).dx, _vertex(center, r, i).dy)
        ..lineTo(_vertex(center, r, (i + 1) % 6).dx,
            _vertex(center, r, (i + 1) % 6).dy)
        ..close();
      canvas.drawPath(
        tri,
        Paint()
          ..color = (i.isEven ? Colors.white : Colors.black)
              .withAlpha(i.isEven ? 22 : 26),
      );
    }

    // ── 흐르는 광택: 사선 빛줄기가 주기적으로 쓸고 지나감
    canvas.save();
    canvas.clipPath(body);
    final sweepX = size.width * (t * 2.4 - 0.7);
    final band =
        Rect.fromLTWH(sweepX, -12, size.width * 0.26, size.height + 24);
    canvas.translate(band.center.dx, band.center.dy);
    canvas.rotate(-0.45);
    canvas.translate(-band.center.dx, -band.center.dy);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withAlpha(0),
            Colors.white.withAlpha(80),
            Colors.white.withAlpha(0),
          ],
        ).createShader(band),
    );
    canvas.restore();

    // ── 삼중 테두리 (진한 외곽 + 밝은 중간 + 은은한 안쪽)
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = darker,
    );
    canvas.drawPath(
      _hexagon(center, r - 3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = lighter.withAlpha(210),
    );
    canvas.drawPath(
      _hexagon(center, r - 9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withAlpha(60),
    );

    // ── 꼭짓점 보석: 상단 큰 것 + 하단 좌우 작은 것
    void gemAt(Offset p, double s) {
      final gem = Path()
        ..moveTo(p.dx, p.dy - s)
        ..lineTo(p.dx + s * 0.8, p.dy)
        ..lineTo(p.dx, p.dy + s)
        ..lineTo(p.dx - s * 0.8, p.dy)
        ..close();
      canvas.drawPath(gem, Paint()..color = lighter);
      canvas.drawPath(
        gem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = darker,
      );
      // 보석 하이라이트 점
      canvas.drawCircle(Offset(p.dx - s * 0.2, p.dy - s * 0.3), s * 0.2,
          Paint()..color = Colors.white.withAlpha(210));
    }

    gemAt(_vertex(center, r, 0), 8);
    gemAt(_vertex(center, r, 2), 5);
    gemAt(_vertex(center, r, 4), 5);

    // ── 반짝이 별 (위상차를 두고 깜빡임)
    const sparkles = [
      (0.16, 0.30, 0.0),
      (0.84, 0.24, 2.1),
      (0.74, 0.78, 4.2),
      (0.24, 0.74, 1.2),
    ];
    for (final (fx, fy, phase) in sparkles) {
      final a = (math.sin(t * 4 * math.pi + phase) + 1) / 2;
      if (a < 0.2) continue;
      final p = Offset(size.width * fx, size.height * fy);
      final s = 2.5 + 2.5 * a;
      final star = Path()
        ..moveTo(p.dx, p.dy - s)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s)
        ..close();
      canvas.drawPath(
          star, Paint()..color = Colors.white.withAlpha((220 * a).toInt()));
    }
  }

  @override
  bool shouldRepaint(covariant _TierBadgePainter old) =>
      old.color != color || old.t != t;
}

/// 💡 티어 기준 사다리: 챌린저(위)→아이언(아래) 기준 로그 수를 한눈에.
/// 현재 티어는 색 배경으로 강조된다.
class _TierLadder extends StatelessWidget {
  final int total;

  const _TierLadder({required this.total});

  @override
  Widget build(BuildContext context) {
    String? current;
    for (final (start, name) in _kTierSteps) {
      if (total >= start) {
        current = name;
        break;
      }
    }

    return SizedBox(
      width: 106,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (start, name) in _kTierSteps)
            Builder(builder: (_) {
              final color = _kTierColors[name]!;
              final isCur = name == current;
              return Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: isCur
                    ? BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: color.withAlpha(150)),
                      )
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            isCur ? FontWeight.w800 : FontWeight.w500,
                        color: isCur
                            ? Color.lerp(color, Colors.black, 0.25)
                            : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$start+',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight:
                            isCur ? FontWeight.w700 : FontWeight.normal,
                        color: isCur
                            ? Color.lerp(color, Colors.black, 0.25)
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }),
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
