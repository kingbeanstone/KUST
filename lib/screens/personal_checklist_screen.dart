import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기본 개인 준비물 (모든 대원 공통)
const List<String> kDefaultPersonalItems = [
  '수영복', '세면도구', '수건', '썬크림', '개인복용 약', '로그북', '여벌 옷', '신분증',
];

/// 파란색 강조 항목 (자주 까먹는 필수품)
const Set<String> kHighlightedItems = {'로그북', '여벌 옷', '신분증'};

/// 💡 개인 체크리스트: 로그인 없이 이 기기(브라우저)에만 저장한다.
/// 내 짐 싸기 확인 용도라 다른 사람과 공유할 필요가 없기 때문.
class PersonalChecklistScreen extends StatefulWidget {
  const PersonalChecklistScreen({super.key});

  @override
  State<PersonalChecklistScreen> createState() => _PersonalChecklistScreenState();
}

class _PersonalChecklistScreenState extends State<PersonalChecklistScreen> {
  static const _customKey = 'personal_custom_items';
  static const _checkedKey = 'personal_checked_items';

  List<String> _custom = [];
  Set<String> _checked = {};
  bool _loaded = false;

  /// 항목 추가 입력 컨트롤러 — State 소유 (다이얼로그 dispose 크래시 방지)
  final TextEditingController _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _custom = prefs.getStringList(_customKey) ?? [];
      _checked = (prefs.getStringList(_checkedKey) ?? []).toSet();
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customKey, _custom);
    await prefs.setStringList(_checkedKey, _checked.toList());
  }

  void _toggle(String name) {
    setState(() {
      _checked.contains(name) ? _checked.remove(name) : _checked.add(name);
    });
    _save();
  }

  void _addItem() {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    if (kDefaultPersonalItems.contains(name) || _custom.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('[$name]은(는) 이미 목록에 있습니다.'),
            duration: const Duration(seconds: 1)),
      );
      return;
    }
    setState(() {
      _custom.add(name);
      _addController.clear();
    });
    _save();
  }

  void _removeCustom(String name) {
    setState(() {
      _custom.remove(name);
      _checked.remove(name);
    });
    _save();
  }

  void _resetChecks() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('체크 초기화'),
        content: const Text('모든 체크가 해제됩니다. 추가한 항목은 유지돼요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          TextButton(
            onPressed: () {
              setState(() => _checked.clear());
              _save();
              Navigator.pop(dialogContext);
            },
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allItems = [...kDefaultPersonalItems, ..._custom];
    final done = allItems.where(_checked.contains).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🧳 개인 체크리스트',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _resetChecks,
            child: Text('체크 초기화',
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 진행 상황
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done == allItems.length
                            ? '🎉 짐 싸기 완료!'
                            : '$done / ${allItems.length} 챙겼어요',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: allItems.isEmpty ? 0 : done / allItems.length,
                          minHeight: 7,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                              done == allItems.length
                                  ? Colors.green
                                  : Colors.blue[700]!),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text('기본 준비물',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                ),
                for (final name in kDefaultPersonalItems) _itemTile(name),

                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text('내가 추가한 준비물',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                ),
                for (final name in _custom) _itemTile(name, removable: true),

                // 항목 추가 입력줄
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _addController,
                          decoration: const InputDecoration(
                            hintText: '준비물 추가 (예: 멀미약)',
                            hintStyle: TextStyle(fontSize: 13.5),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          style: const TextStyle(fontSize: 13.5),
                          onSubmitted: (_) => _addItem(),
                        ),
                      ),
                      TextButton(
                        onPressed: _addItem,
                        child: const Text('추가',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Center(
                  child: Text('이 목록은 내 기기에만 저장됩니다.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _itemTile(String name, {bool removable = false}) {
    final checked = _checked.contains(name);
    final highlighted = kHighlightedItems.contains(name);

    final Color textColor = checked
        ? Colors.grey[400]!
        : (highlighted ? Colors.blue[800]! : Colors.black87);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: checked
            ? Colors.grey[100]
            : (highlighted ? Colors.blue[50] : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checked
              ? Colors.grey[200]!
              : (highlighted ? Colors.blue[200]! : Colors.grey[300]!),
        ),
      ),
      child: InkWell(
        onTap: () => _toggle(name),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                checked ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: checked ? Colors.green : Colors.grey[400],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        highlighted && !checked ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                    decoration: checked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (removable)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeCustom(name),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
