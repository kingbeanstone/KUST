import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final ScrollController _headerHController = ScrollController();
  final ScrollController _bodyHController = ScrollController();

  static const double noWidth = 20.0;
  static const double nameWidth = 60.0;
  static const double cellWidth = 60.0;

  static const double dataRowHeight = 40.0;
  static const double oxRowHeight = 40.0;
  static const double headerHeight = 40.0;
  static const double fixedBorderWidth = 1.0;

  @override
  void initState() {
    super.initState();
    _headerHController.addListener(() {
      if (_bodyHController.hasClients && _bodyHController.offset != _headerHController.offset) {
        _bodyHController.jumpTo(_headerHController.offset);
      }
    });
    _bodyHController.addListener(() {
      if (_headerHController.hasClients && _headerHController.offset != _bodyHController.offset) {
        _headerHController.jumpTo(_bodyHController.offset);
      }
    });
  }

  @override
  void dispose() {
    _headerHController.dispose();
    _bodyHController.dispose();
    super.dispose();
  }

  void _showResetDialog(EquipmentProvider provider) {
    if (!provider.isAdmin) return; // 권한 체크
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('체크리스트 초기화'),
        content: const Text('모든 대원의 장비 체크 현황을 미완료(X) 상태로 되돌리시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              provider.resetAllChecks();
              Navigator.pop(context);
            },
            child: const Text('초기화 실행', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EquipmentProvider>(context);
    final gearKeys = ['가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('✅ 장비 체크 현황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          // 💡 관리자만 초기화 버튼 노출
          if (provider.isAdmin)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.blue),
              onPressed: () => _showResetDialog(provider),
              tooltip: '전체 초기화',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFullHeader(gearKeys),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: noWidth + nameWidth + fixedBorderWidth,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey[400]!, width: fixedBorderWidth)),
                    ),
                    child: Column(
                      children: List.generate(provider.data.length, (index) {
                        final member = provider.data[index];
                        return Container(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5))),
                          child: Column(
                            children: [
                              Container(
                                height: dataRowHeight,
                                color: Colors.white,
                                child: Row(
                                  children: [
                                    _dataCell(Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey)), noWidth),
                                    _dataCell(Text(member.name.isEmpty ? '-' : member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), nameWidth),
                                  ],
                                ),
                              ),
                              Container(height: oxRowHeight, color: const Color(0xFFF8F9FA)),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _bodyHController,
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: List.generate(provider.data.length, (index) {
                          final member = provider.data[index];
                          return Container(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5))),
                            child: Row(
                              children: gearKeys.map((key) {
                                final gear = member.gears[key]!;
                                return GestureDetector(
                                  // 💡 관리자 인증이 된 경우에만 토글 가능
                                  onTap: provider.isAdmin
                                      ? () => provider.toggleCheck(member.id, key)
                                      : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('데이터를 수정하려면 관리자 인증이 필요합니다.'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                  child: Container(
                                    width: cellWidth,
                                    decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[200]!, width: 0.5))),
                                    child: Column(
                                      children: [
                                        Container(
                                          height: dataRowHeight,
                                          alignment: Alignment.center,
                                          color: Colors.white,
                                          child: Text(gear.value.isEmpty ? '-' : gear.value, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                        ),
                                        Container(
                                          height: oxRowHeight,
                                          alignment: Alignment.center,
                                          color: gear.checked ? const Color(0xFFE8F5E9) : const Color(0xFFFFF5F5),
                                          child: Text(
                                            gear.checked ? 'O' : 'X',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: gear.checked ? Colors.green : Colors.red[300]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullHeader(List<String> gearKeys) {
    return Container(
      height: headerHeight,
      decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
      child: Row(
        children: [
          Container(
            width: noWidth + nameWidth + fixedBorderWidth,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[400]!, width: fixedBorderWidth))),
            child: Row(
              children: [
                _headerCell('No.', noWidth),
                _headerCell('이름', nameWidth),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _headerHController,
              scrollDirection: Axis.horizontal,
              child: Row(children: gearKeys.map((k) => _headerCell(k, cellWidth)).toList()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, double width) => Container(
    width: width, alignment: Alignment.center,
    decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!))),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF495057))),
  );

  Widget _dataCell(Widget child, double width) => Container(
    width: width, alignment: Alignment.center,
    decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[200]!))),
    child: child,
  );
}