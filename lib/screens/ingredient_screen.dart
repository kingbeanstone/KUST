import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/expedition_provider.dart';
import '../providers/ingredient_provider.dart';
import '../providers/schedule_provider.dart';
import '../models/ingredient_model.dart';

/// 💡 남은 재료 관리: 재료 잔량%와 원정 잔여%를 나란히 보여줘
/// "지금 페이스로 써도 되는지"를 한눈에 판단하게 한다.
class IngredientScreen extends StatefulWidget {
  const IngredientScreen({super.key});

  @override
  State<IngredientScreen> createState() => _IngredientScreenState();
}

class _IngredientScreenState extends State<IngredientScreen> {
  /// 다이얼로그 입력 컨트롤러 — State 소유 (dispose 크래시 방지)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// 원정 잔여 비율 (일정 탭의 일차 날짜 기준, 파싱 불가 시 null)
  double? _expeditionRemainRatio(BuildContext context) {
    final dates = context.watch<ScheduleProvider>().dates;
    final year = context.read<ExpeditionProvider>().selected?.year ??
        DateTime.now().year;

    DateTime? first;
    DateTime? last;
    for (final day in dates) {
      final match =
          RegExp(r'^(\d{1,2})\.(\d{1,2})$').firstMatch((day['id'] ?? '').trim());
      if (match == null) continue;
      final d =
          DateTime(year, int.parse(match.group(1)!), int.parse(match.group(2)!));
      if (first == null || d.isBefore(first)) first = d;
      if (last == null || d.isAfter(last)) last = d;
    }
    if (first == null || last == null) return null;

    final total = last.add(const Duration(days: 1)).difference(first).inMinutes;
    final elapsed = DateTime.now().difference(first).inMinutes;
    return (1 - elapsed / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final provider = context.watch<IngredientProvider>();
    final expRemain = _expeditionRemainRatio(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🧺 남은 재료',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
        children: [
          // ── 기준선 안내: 원정이 얼마나 남았는가
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
                    const Text('원정 잔여',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(
                      expRemain == null
                          ? '계산 불가'
                          : '${(expRemain * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (expRemain != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: expRemain,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          AlwaysStoppedAnimation(Colors.blueGrey[600]!),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '재료 잔량이 이 비율보다 넉넉하면 초록, 모자라면 빨강입니다.\n막대의 세로선이 원정 잔여 위치예요.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (provider.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  isAdmin ? '재료를 추가해주세요.' : '등록된 재료가 없습니다.',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            for (final item in provider.items)
              _ingredientRow(item, expRemain, isAdmin, provider),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(provider),
              backgroundColor: Colors.blue[800],
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('재료 추가',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _ingredientRow(IngredientItem item, double? expRemain, bool isAdmin,
      IngredientProvider provider) {
    final ratio = item.remainRatio;

    // 원정 잔여 대비 상태색: 여유(초록) / 빠듯(주황) / 부족(빨강)
    Color barColor;
    if (expRemain == null) {
      barColor = Colors.blue[600]!;
    } else if (ratio >= expRemain) {
      barColor = Colors.green[600]!;
    } else if (ratio >= expRemain - 0.15) {
      barColor = Colors.orange[600]!;
    } else {
      barColor = Colors.red[500]!;
    }

    return GestureDetector(
      onTap: isAdmin ? () => _showUpdateDialog(item, provider) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.bold)),
                ),
                Text(
                  '${_fmt(item.remaining)} / ${_fmt(item.total)} ${item.unit}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                ),
                const SizedBox(width: 6),
                Text('${(ratio * 100).round()}%',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: barColor)),
                if (isAdmin) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined, size: 13, color: Colors.grey[400]),
                ],
              ],
            ),
            const SizedBox(height: 9),
            // 잔량 바 + 원정 잔여 기준선
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 9,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                    if (expRemain != null)
                      Positioned(
                        left: (constraints.maxWidth * expRemain) - 1,
                        top: -2,
                        child: Container(
                          width: 2,
                          height: 13,
                          color: Colors.blueGrey[700],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 다이얼로그

  void _showAddDialog(IngredientProvider provider) {
    _nameController.clear();
    _unitController.clear();
    _totalController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('재료 추가',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: '품목 (예: 쌀, 돼지고기)', isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _totalController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: '총량 (숫자)', isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                        labelText: '단위 (kg, 개…)', isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              final total = double.tryParse(_totalController.text.trim());
              if (name.isEmpty || total == null || total <= 0) return;
              provider.addItem(name, _unitController.text, total);
              Navigator.pop(dialogContext);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  /// 잔량 갱신: 슬라이더 + 비율 딸깍 칩. 품목 정보 수정/삭제도 여기서.
  void _showUpdateDialog(IngredientItem item, IngredientProvider provider) {
    _nameController.text = item.name;
    _unitController.text = item.unit;
    _totalController.text = _fmt(item.total);
    var remaining = item.remaining.clamp(0.0, item.total);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final total =
              double.tryParse(_totalController.text.trim()) ?? item.total;
          if (remaining > total) remaining = total;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('${item.name} 잔량',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_fmt(remaining)} / ${_fmt(total)} ${_unitController.text.trim()}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: total <= 0 ? 0 : remaining / total,
                  onChanged: (v) => setDialogState(() {
                    // 총량의 5% 단위로 스냅 (딸깍 감각)
                    final snapped = (v * 20).round() / 20;
                    remaining = snapped * total;
                  }),
                ),
                // 비율 딸깍 칩
                Wrap(
                  spacing: 6,
                  children: [
                    for (final pct in [100, 75, 50, 25, 10, 0])
                      GestureDetector(
                        onTap: () =>
                            setDialogState(() => remaining = total * pct / 100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (total > 0 &&
                                    (remaining / total * 100).round() == pct)
                                ? Colors.blue[800]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: (total > 0 &&
                                      (remaining / total * 100).round() == pct)
                                  ? Colors.white
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.grey[200], height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                            labelText: '품목', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _totalController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                            labelText: '총량', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: TextField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                            labelText: '단위', isDense: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  provider.deleteItem(item.id);
                  Navigator.pop(dialogContext);
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  final newTotal =
                      double.tryParse(_totalController.text.trim());
                  if (name.isEmpty || newTotal == null || newTotal <= 0) return;
                  provider.updateItem(IngredientItem(
                    id: item.id,
                    name: name,
                    unit: _unitController.text.trim(),
                    total: newTotal,
                    remaining: remaining.clamp(0.0, newTotal),
                  ));
                  Navigator.pop(dialogContext);
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }
}
