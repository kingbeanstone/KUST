import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _showAdminAuthDialog(BuildContext context, EquipmentProvider provider) {
    final TextEditingController _pwdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('관리자 인증', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('비밀번호 3자리를 입력하세요.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _pwdController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 3,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final success = provider.authenticate(_pwdController.text);
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('관리자 인증에 성공했습니다.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('비밀번호가 틀렸습니다.'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EquipmentProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('더보기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 관리자 상태 카드
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: provider.isAdmin ? Colors.blue[50] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: provider.isAdmin ? Colors.blue[200]! : Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isAdmin ? Icons.admin_panel_settings : Icons.lock_outline,
                    color: provider.isAdmin ? Colors.blue : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.isAdmin ? '관리자 모드 활성' : '일반 사용자 모드',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          provider.isAdmin ? '모든 데이터를 수정할 수 있습니다.' : '데이터 수정 권한이 없습니다.',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: provider.isAdmin
                        ? () => provider.logoutAdmin()
                        : () => _showAdminAuthDialog(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.isAdmin ? Colors.white : Colors.blue,
                      foregroundColor: provider.isAdmin ? Colors.blue : Colors.white,
                      elevation: 0,
                    ),
                    child: Text(provider.isAdmin ? '해제' : '인증'),
                  ),
                ],
              ),
            ),

            // 기타 메뉴 (기존 그리드 메뉴 등...)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('기타 설정 및 서비스 준비 중', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }
}