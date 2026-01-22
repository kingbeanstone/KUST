import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? _currentSortKey;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EquipmentProvider>(context);
    // 💡 '이름' 정렬 필터를 추가하여 목록을 구성
    final sortKeys = ['이름', '가방', 'BCD', '호흡기'];

    List<MemberEquipment> sortedData = List.from(provider.data);

    // 정렬 로직
    if (_currentSortKey != null) {
      sortedData.sort((a, b) {
        // 💡 '이름' 기준 정렬일 경우 단순 문자열 비교 수행
        if (_currentSortKey == '이름') {
          return a.name.compareTo(b.name);
        }

        // 장비 기준 정렬 로직
        String valA = a.gears[_currentSortKey]?.value ?? '';
        String valB = b.gears[_currentSortKey]?.value ?? '';

        if (valA.isEmpty) return 1;
        if (valB.isEmpty) return -1;

        double? numA = double.tryParse(valA.replaceAll(RegExp(r'[^0-9.]'), ''));
        double? numB = double.tryParse(valB.replaceAll(RegExp(r'[^0-9.]'), ''));

        if (numA != null && numB != null) {
          return numA.compareTo(numB);
        }

        return valA.compareTo(valB);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('장비별 정렬 검색', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // 장비 및 이름 선택 칩 영역
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: sortKeys.map((key) {
                  bool isSelected = _currentSortKey == key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(key, style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      )),
                      selected: isSelected,
                      selectedColor: Colors.blue[700],
                      backgroundColor: Colors.grey[100],
                      onSelected: (selected) {
                        setState(() => _currentSortKey = selected ? key : null);
                      },
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? Colors.blue[700]! : Colors.transparent),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          // 결과 리스트 뷰
          Expanded(
            child: sortedData.isEmpty
                ? const Center(child: Text('데이터가 없습니다.'))
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedData.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final member = sortedData[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[50],
                      child: Text("${index + 1}", style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                      member.name.isEmpty ? "(이름 없음)" : member.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildMiniInfo("가방", member.gears['가방']?.value),
                          _buildMiniInfo("BCD", member.gears['BCD']?.value),
                          _buildMiniInfo("호흡기", member.gears['호흡기']?.value),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(String label, String? value) {
    bool isHighlighted = _currentSortKey == label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Colors.black54),
          children: [
            TextSpan(text: "$label: ", style: TextStyle(color: isHighlighted ? Colors.blue[800] : Colors.black54)),
            TextSpan(
              text: (value == null || value.isEmpty) ? "-" : value,
              style: TextStyle(
                color: isHighlighted ? Colors.blue[900] : Colors.black87,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}