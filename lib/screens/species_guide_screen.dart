import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';

/// 💡 생물 도감: 울릉도에서 만나는 해양 생물을 사진·설명과 함께.
/// 'species' 컬렉션 — {name, category, photo, identify, look, note}.
/// 카테고리 칩 + 2열 카드 그리드, 탭하면 상세 시트. 관리자는 추가·수정·삭제.
class SpeciesGuideScreen extends StatefulWidget {
  const SpeciesGuideScreen({super.key});

  @override
  State<SpeciesGuideScreen> createState() => _SpeciesGuideScreenState();
}

class _SpeciesGuideScreenState extends State<SpeciesGuideScreen> {
  static const _categories = ['어류', '무척추', '해조·산호'];
  static const _points = ['죽도', '관음도', '공암', '쌍정초', '내수전 몽돌해변'];
  String _filter = '전체';

  /// 선택된 포인트 (null = 전체). 하나만 선택 가능, 같은 걸 다시 누르면 해제.
  String? _pointFilter;

  String _pointShort(String p) => p == '내수전 몽돌해변' ? '내수전' : p;

  /// 입력 컨트롤러 — State 소유 (dispose 크래시 방지)
  final _nameController = TextEditingController();
  final _photoController = TextEditingController();
  final _identifyController = TextEditingController();
  final _lookController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    _identifyController.dispose();
    _lookController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Color _categoryColor(String category) {
    switch (category) {
      case '어류':
        return const Color(0xFF1E88E5);
      case '무척추':
        return const Color(0xFF8E24AA);
      case '해조·산호':
        return const Color(0xFF43A047);
      default:
        return const Color(0xFF546E7A);
    }
  }

  /// 💡 자체 호스팅 사진의 목록용 400px 썸네일 주소.
  /// 외부 URL이거나 이미 썸네일이면 그대로 둔다.
  String _thumbUrl(String url) {
    const marker = '/species_photos/';
    if (!url.contains(marker) || url.contains('${marker}thumb/')) return url;
    return url.replaceFirst(marker, '${marker}thumb/');
  }

  Widget _photo(String url,
      {double? height, BorderRadius? radius, bool thumb = false}) {
    final r = radius ?? BorderRadius.circular(12);
    if (url.trim().isEmpty) {
      return ClipRRect(
        borderRadius: r,
        child: Container(
          height: height,
          color: const Color(0xFFE8F0F5),
          child: Center(
            child: Icon(Icons.photo_camera_outlined,
                size: 30, color: Colors.blueGrey[200]),
          ),
        ),
      );
    }
    final display = thumb ? _thumbUrl(url) : url;
    return ClipRRect(
      borderRadius: r,
      child: Image.network(
        display,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (c, child, progress) => progress == null
            ? child
            : Container(
                height: height,
                color: const Color(0xFFF1F3F5),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
        // 💡 썸네일이 없는 사진(관리자가 새로 등록 등)은 원본으로 폴백
        errorBuilder: (c, e, s) => display != url
            ? _photo(url, height: height, radius: radius)
            : Container(
                height: height,
                color: const Color(0xFFF1F3F5),
                child: Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.grey[400]),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🐠 생물 도감',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showEditDialog(),
              backgroundColor: Colors.blue[800],
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('생물 추가',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          // 💡 포인트 필터 (하나만 선택, 다시 누르면 해제)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in _points)
                    GestureDetector(
                      onTap: () => setState(() =>
                          _pointFilter = _pointFilter == p ? null : p),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _pointFilter == p
                              ? Colors.teal[600]
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _pointFilter == p
                                  ? Colors.teal[600]!
                                  : Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place,
                                size: 12,
                                color: _pointFilter == p
                                    ? Colors.white
                                    : Colors.teal[400]),
                            const SizedBox(width: 3),
                            Text(
                              _pointShort(p),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _pointFilter == p
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 카테고리 필터 칩
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                for (final c in ['전체', ..._categories]) ...[
                  GestureDetector(
                    onTap: () => setState(() => _filter = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            _filter == c ? Colors.blue[700] : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _filter == c
                                ? Colors.blue[700]!
                                : Colors.grey[300]!),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color:
                              _filter == c ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('species')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.where((d) {
                  final data = d.data();
                  if (_filter != '전체' &&
                      (data['category'] ?? '') != _filter) {
                    return false;
                  }
                  // 포인트 필터: points가 비어 있으면 '모든 포인트' 취급
                  if (_pointFilter != null) {
                    final points = [
                      for (final p in (data['points'] as List? ?? const []))
                        p.toString(),
                    ];
                    if (points.isNotEmpty &&
                        !points.contains(_pointFilter)) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text('등록된 생물이 없습니다.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500])),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final name = (data['name'] ?? '').toString();
                    final category = (data['category'] ?? '').toString();
                    final color = _categoryColor(category);
                    return GestureDetector(
                      onTap: () =>
                          _showDetailSheet(docs[i].id, data, isAdmin),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _photo(
                                (data['photo'] ?? '').toString(),
                                thumb: true,
                                radius: const BorderRadius.vertical(
                                    top: Radius.circular(14)),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 8, 10, 9),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  if (category.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withAlpha(26),
                                        borderRadius:
                                            BorderRadius.circular(7),
                                      ),
                                      child: Text(category,
                                          style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: color)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- 상세 시트

  Widget _section(String emoji, String title, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji $title',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[400])),
          const SizedBox(height: 4),
          Text(value.trim(),
              style: const TextStyle(fontSize: 13.5, height: 1.55)),
        ],
      ),
    );
  }

  void _showDetailSheet(String id, Map<String, dynamic> data, bool isAdmin) {
    final name = (data['name'] ?? '').toString();
    final category = (data['category'] ?? '').toString();
    final color = _categoryColor(category);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.82),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _photo((data['photo'] ?? '').toString(), height: 190),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withAlpha(26),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(category,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: color)),
                      ),
                    if (isAdmin)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showEditDialog(id: id, data: data);
                        },
                        child:
                            const Text('수정', style: TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _section('🔍', '구분 방법', (data['identify'] ?? '').toString()),
                _section('👀', '생김새', (data['look'] ?? '').toString()),
                _section('💡', '특징', (data['note'] ?? '').toString()),
                // 📍 볼 수 있는 포인트 (미지정 = 모든 포인트)
                Builder(builder: (_) {
                  final points = [
                    for (final p in (data['points'] as List? ?? const []))
                      p.toString(),
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📍 볼 수 있는 포인트',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[400])),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final p
                              in points.isEmpty ? ['모든 포인트'] : points)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_pointShort(p),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal[800])),
                            ),
                        ],
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- 추가/수정

  void _showEditDialog({String? id, Map<String, dynamic>? data}) {
    _nameController.text = (data?['name'] ?? '').toString();
    _photoController.text = (data?['photo'] ?? '').toString();
    _identifyController.text = (data?['identify'] ?? '').toString();
    _lookController.text = (data?['look'] ?? '').toString();
    _noteController.text = (data?['note'] ?? '').toString();
    var category = (data?['category'] ?? _categories.first).toString();
    final selectedPoints = <String>{
      for (final p in (data?['points'] as List? ?? const [])) p.toString(),
    };

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(id == null ? '생물 추가' : '생물 수정',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: id == null,
                  decoration: const InputDecoration(
                      labelText: '이름 (예: 자리돔)', isDense: true),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in _categories)
                      GestureDetector(
                        onTap: () => setDialogState(() => category = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: category == c
                                ? Colors.blue[700]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(c,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: category == c
                                    ? Colors.white
                                    : Colors.black54,
                              )),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _photoController,
                  decoration: const InputDecoration(
                      labelText: '사진 URL (선택)', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _identifyController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: '구분 방법 (이것만 보면 안다!)', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _lookController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: '생김새 특징', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: '생물 특징 (습성·볼 수 있는 곳)', isDense: true),
                ),
                const SizedBox(height: 12),
                Text('볼 수 있는 포인트 (복수 선택 · 안 고르면 모든 포인트)',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600])),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final p in _points)
                      GestureDetector(
                        onTap: () => setDialogState(() {
                          if (selectedPoints.contains(p)) {
                            selectedPoints.remove(p);
                          } else {
                            selectedPoints.add(p);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selectedPoints.contains(p)
                                ? Colors.teal[600]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(_pointShort(p),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selectedPoints.contains(p)
                                    ? Colors.white
                                    : Colors.black54,
                              )),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (id != null)
              TextButton(
                onPressed: () {
                  FirebaseFirestore.instance
                      .collection('species')
                      .doc(id)
                      .delete();
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
                if (name.isEmpty) return;
                final doc = {
                  'name': name,
                  'category': category,
                  'photo': _photoController.text.trim(),
                  'identify': _identifyController.text.trim(),
                  'look': _lookController.text.trim(),
                  'note': _noteController.text.trim(),
                  'points': selectedPoints.toList(),
                };
                final col = FirebaseFirestore.instance.collection('species');
                if (id == null) {
                  col.add(doc);
                } else {
                  col.doc(id).set(doc, SetOptions(merge: true));
                }
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
