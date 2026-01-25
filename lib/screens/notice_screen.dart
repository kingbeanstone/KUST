import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // 💡 사진 선택 패키지
import 'dart:io' show File; // 💡 파일 처리 (모바일용)
import 'package:flutter/foundation.dart' show kIsWeb; // 💡 웹/모바일 구분용
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  // --- 공지 작성/수정 다이얼로그 (사진 첨부 기능 포함) ---
  void _showNoticeDialog(BuildContext context, EquipmentProvider provider, {NoticeItem? existingNotice}) {
    final bool isEdit = existingNotice != null;
    final titleController = TextEditingController(text: existingNotice?.title ?? "");
    final contentController = TextEditingController(text: existingNotice?.content ?? "");

    // 다이얼로그 내 상태 관리를 위한 변수들
    List<XFile> pickedImages = []; // 새로 선택한 이미지 리스트
    List<String> existingUrls = List.from(existingNotice?.imageUrls ?? []); // 기존 이미지 URL 리스트
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false, // 업로드 중 닫기 방지
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(isEdit ? '공지사항 수정' : '공지사항 작성',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),

                  const Text("📷 사진 첨부", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // [사진 추가 버튼]
                        GestureDetector(
                          onTap: isUploading ? null : () async {
                            final ImagePicker picker = ImagePicker();
                            final List<XFile> images = await picker.pickMultiImage();
                            if (images.isNotEmpty) {
                              setDialogState(() => pickedImages.addAll(images));
                            }
                          },
                          child: Container(
                            width: 90,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, color: Colors.blue, size: 24),
                                SizedBox(height: 4),
                                Text("추가", style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),

                        // [새로 선택한 사진 미리보기]
                        ...pickedImages.asMap().entries.map((entry) {
                          int idx = entry.key;
                          XFile file = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 90,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    // 💡 보다 안전한 이미지 로딩 처리
                                    image: (kIsWeb
                                        ? NetworkImage(file.path)
                                        : FileImage(File(file.path))) as ImageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4, right: 12,
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => pickedImages.removeAt(idx)),
                                  child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                                ),
                              ),
                            ],
                          );
                        }),

                        // [기존 등록된 사진 미리보기]
                        ...existingUrls.asMap().entries.map((entry) {
                          int idx = entry.key;
                          String url = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 90,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 4, right: 12,
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => existingUrls.removeAt(idx)),
                                  child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  if (isUploading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Column(
                        children: [
                          LinearProgressIndicator(),
                          SizedBox(height: 8),
                          Text("이미지를 서버에 업로드 중...", style: TextStyle(fontSize: 11, color: Colors.blue)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isUploading ? null : () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                  setDialogState(() => isUploading = true);

                  // 1. 이미지 업로드 실행 (Storage)
                  List<String> newUrls = await provider.uploadImages(pickedImages);

                  // 2. 주소 병합
                  List<String> finalUrls = [...existingUrls, ...newUrls];

                  // 3. DB 저장
                  if (isEdit) {
                    await provider.updateNotice(existingNotice.id, titleController.text, contentController.text, imageUrls: finalUrls);
                  } else {
                    await provider.addNotice(titleController.text, contentController.text, imageUrls: finalUrls);
                  }

                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
              child: Text(isUploading ? '대기...' : (isEdit ? '수정 완료' : '등록')),
            ),
          ],
        ),
      ),
    );
  }

  // --- 푸시 알림 전송 확인 다이얼로그 ---
  void _showPushConfirmDialog(BuildContext context, EquipmentProvider provider, NoticeItem notice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('푸시 알림 전송'),
        content: Text("'${notice.title}' 공지를 모든 대원에게 알림으로 보낼까요?\n(등록된 모든 기기에 발송됩니다.)"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.sendNoticePush(notice);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('알림 전송 프로세스가 시작되었습니다.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('지금 전송'),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 💡 InteractiveViewer를 사용하여 확대/축소 지원
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.9),
                child: InteractiveViewer(
                  clipBehavior: Clip.none,
                  maxScale: 5.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white, size: 50),
                    ),
                  ),
                ),
              ),
            ),
            // 닫기 버튼
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EquipmentProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('📢 공지사항', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (provider.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined, color: Colors.blue),
              onPressed: () => _showNoticeDialog(context, provider),
            ),
        ],
      ),
      body: provider.notices.isEmpty
          ? const Center(child: Text('등록된 공지사항이 없습니다.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.notices.length,
        itemBuilder: (context, index) {
          final notice = provider.notices[index];
          return _buildNoticeCard(context, provider, notice);
        },
      ),
    );
  }



  Widget _buildNoticeCard(BuildContext context, EquipmentProvider provider, NoticeItem notice) {
    String dateStr;
    try {
      final dt = DateTime.parse(notice.timestamp);
      dateStr = DateFormat('yyyy.MM.dd HH:mm').format(dt);
    } catch (e) {
      dateStr = notice.timestamp;
    }

    final PageController pageController = PageController();
    int currentPage = 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: notice.isPinned ? Colors.blue[300]! : Colors.grey[200]!, width: notice.isPinned ? 2 : 1),
        boxShadow: notice.isPinned ? [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10)] : null,
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          backgroundColor: notice.isPinned ? Colors.blue : Colors.grey[100],
          child: Icon(notice.isPinned ? Icons.push_pin : Icons.campaign_outlined,
              color: notice.isPinned ? Colors.white : Colors.blueGrey, size: 20),
        ),
        title: Text(notice.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        children: [
          StatefulBuilder(
              builder: (context, setState) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),

                      // 💡 인스타그램 스타일 비율 고정 슬라이더
                      if (notice.imageUrls.isNotEmpty) ...[
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // 💡 AspectRatio(1.0)을 사용하여 1:1 정사각형 비율로 고정
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: PageView.builder(
                                controller: pageController,
                                onPageChanged: (index) => setState(() => currentPage = index),
                                itemCount: notice.imageUrls.length,
                                physics: const BouncingScrollPhysics(),
                                itemBuilder: (context, idx) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: GestureDetector(
                                        // 💡 터치 시 원본 이미지를 보여주는 함수 호출
                                        onTap: () => _showFullImage(context, notice.imageUrls[idx]),
                                        child: Image.network(
                                          notice.imageUrls[idx],
                                          fit: BoxFit.cover, // 정사각형 영역을 가득 채우도록 설정
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.grey[100],
                                            child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            if (notice.imageUrls.length > 1 && currentPage > 0)
                              Positioned(
                                left: 10,
                                child: GestureDetector(
                                  onTap: () => pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black.withOpacity(0.3),
                                    radius: 16,
                                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),

                            if (notice.imageUrls.length > 1 && currentPage < notice.imageUrls.length - 1)
                              Positioned(
                                right: 10,
                                child: GestureDetector(
                                  onTap: () => pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black.withOpacity(0.3),
                                    radius: 16,
                                    child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        if (notice.imageUrls.length > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                notice.imageUrls.length,
                                    (index) => Container(
                                  width: 6, height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: currentPage == index ? Colors.blue : const Color(0xFFE0E0E0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],

                      Text(notice.content, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6)),
                      const SizedBox(height: 16),

                      if (provider.isAdmin)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _actionButton(onPressed: () => provider.pinNotice(notice.id), icon: Icons.home_outlined, label: notice.isPinned ? '게시 중' : '홈 게시', color: notice.isPinned ? Colors.blue : Colors.grey),
                            const SizedBox(width: 12),
                            _actionButton(onPressed: () => _showPushConfirmDialog(context, provider, notice), icon: Icons.notifications_active_outlined, label: '알림', color: Colors.orange),
                            const SizedBox(width: 12),
                            _actionButton(onPressed: () => _showNoticeDialog(context, provider, existingNotice: notice), icon: Icons.edit_outlined, label: '수정', color: Colors.blueGrey),
                            const SizedBox(width: 12),
                            _actionButton(onPressed: () => _showDeleteConfirmDialog(context, provider, notice.id), icon: Icons.delete_outline, label: '삭제', color: Colors.redAccent),
                          ],
                        ),
                    ],
                  ),
                );
              }
          ),
        ],
      ),
    );

  }
  Widget _actionButton({required VoidCallback onPressed, required IconData icon, required String label, required Color color}) {
    return InkWell(onTap: onPressed, child: Column(children: [Icon(icon, size: 20, color: color), const SizedBox(height: 2), Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))]));
  }

  void _showDeleteConfirmDialog(BuildContext context, EquipmentProvider provider, String id) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('공지 삭제'), content: const Text('정말로 삭제하시겠습니까?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), TextButton(onPressed: () { provider.deleteNotice(id); Navigator.pop(context); }, child: const Text('삭제', style: TextStyle(color: Colors.red)))]));
  }


}