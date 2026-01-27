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

  // 1. 개인 체크 상태 저장 변수
  final Map<String, bool> _personalChecks = {};
  final List<String> gearKeys = ['가방', 'BCD', '호흡기', '슈트', '마스크', '핀', '부츠', '장갑', '후드', '조끼', '기타'];

  static const double noWidth = 30.0;
  static const double nameWidth = 70.0;
  static const double cellWidth = 60.0;
  static const double dataRowHeight = 40.0;
  static const double oxRowHeight = 40.0;
  static const double headerHeight = 40.0;
  static const double fixedBorderWidth = 1.0;

  @override
  void initState() {
    super.initState();
    // 개인 체크 변수 초기화
    for (var key in gearKeys) {
      _personalChecks[key] = false;
    }

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
    if (!provider.isAdmin) return;
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('✅ 장비 체크 현황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (provider.isAdmin)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.blue),
              onPressed: () => _showResetDialog(provider),
            ),
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
                  // --- 왼쪽 고정 열 (순번, 이름) ---
                  Container(
                    width: noWidth + nameWidth + fixedBorderWidth,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey[400]!, width: fixedBorderWidth)),
                    ),
                    child: Column(
                      children: [
                        // 💡 [신규] "나"의 개인 체크 행 왼쪽 라벨
                        _buildFixedRowLabel("My", "개인 체크", Colors.blue[50]!),

                        // 대원들 리스트 라벨
                        ...List.generate(provider.data.length, (index) {
                          final member = provider.data[index];
                          return _buildFixedRowLabel('${index + 1}', member.name, Colors.white);
                        }),
                      ],
                    ),
                  ),

                  // --- 오른쪽 스크롤 데이터 영역 ---
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _bodyHController,
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: [
                          // 💡 [신규] "나"의 개인 체크 데이터 행 (토글 가능)
                          _buildPersonalDataRow(),

                          // 대원들 데이터 행
                          ...List.generate(provider.data.length, (index) {
                            final member = provider.data[index];
                            return _buildMemberDataRow(member, provider);
                          }),
                        ],
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

  // 💡 고정 라벨 행 빌더
  Widget _buildFixedRowLabel(String no, String name, Color bgColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            height: dataRowHeight,
            child: Row(
              children: [
                _dataCell(Text(no, style: const TextStyle(fontSize: 10, color: Colors.grey)), noWidth),
                _dataCell(Text(name.isEmpty ? '-' : name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), nameWidth),
              ],
            ),
          ),
          Container(height: oxRowHeight),
        ],
      ),
    );
  }

  // 💡 개인용 체크 데이터 행 (터치 시 로컬 상태 변경)
  Widget _buildPersonalDataRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50]!.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: Colors.blue[100]!, width: 1)),
      ),
      child: Row(
        children: gearKeys.map((key) {
          final isChecked = _personalChecks[key] ?? false;
          return GestureDetector(
            onTap: () {
              setState(() {
                _personalChecks[key] = !isChecked;
              });
            },
            child: Container(
              width: cellWidth,
              decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[200]!, width: 0.5))),
              child: Column(
                children: [
                  Container(
                    height: dataRowHeight,
                    alignment: Alignment.center,
                    child: const Text('내꺼', style: TextStyle(fontSize: 10, color: Colors.blue)),
                  ),
                  Container(
                    height: oxRowHeight,
                    alignment: Alignment.center,
                    color: isChecked ? Colors.green[50] : Colors.white,
                    child: Icon(
                      isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                      color: isChecked ? Colors.green : Colors.grey,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 💡 대원용 데이터 행 빌더
  Widget _buildMemberDataRow(MemberEquipment member, EquipmentProvider provider) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5))),
      child: Row(
        children: gearKeys.map((key) {
          final gear = member.gears[key]!;
          return GestureDetector(
            onTap: provider.isAdmin
                ? () => provider.toggleCheck(member.id, key)
                : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('관리자만 수정할 수 있습니다.'), duration: Duration(seconds: 1)),
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
                    child: Text(gear.value.isEmpty ? '-' : gear.value, style: const TextStyle(fontSize: 11)),
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
    width: width,
    alignment: Alignment.center,
    decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!))),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _dataCell(Widget child, double width) => Container(
    width: width,
    alignment: Alignment.center,
    decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[200]!))),
    child: child,
  );
}