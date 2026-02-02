import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

// 💡 새로운 Provider와 Model 임포트
import '../providers/equipment_provider.dart';
import '../providers/notice_provider.dart';
import '../models/notice_model.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  // --- 공지 작성/수정 다이얼로그 (NoticeProvider 연동) ---
  void _showNoticeDialog(BuildContext context, NoticeProvider noticeProvider, {NoticeItem? existingNotice}) {
    final bool isEdit = existingNotice != null;
    final titleController = TextEditingController(text: existingNotice?.title ?? "");
    final contentController = TextEditingController(text: existingNotice?.content ?? "");

    List<XFile> pickedImages = [];
    List<String> existingUrls = List.from(existingNotice?.imageUrls ?? []);
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
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
                                    image: (kIsWeb ? NetworkImage(file.path) : FileImage(File(file.path))) as ImageProvider,
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
                          Text("서버 업로드 중...", style: TextStyle(fontSize: 11, color: Colors.blue)),
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
                  // 💡 NoticeProvider의 이미지 업로드 함수 호출
                  List<String> newUrls = await noticeProvider.uploadImages(pickedImages);
                  List<String> finalUrls = [...existingUrls, ...newUrls];

                  if (isEdit) {
                    await noticeProvider.updateNotice(existingNotice.id, titleController.text, contentController.text, imageUrls: finalUrls);
                  } else {
                    await noticeProvider.addNotice(titleController.text, contentController.text, imageUrls: finalUrls);
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

  // --- 푸시 알림 전송 (NoticeProvider 연동) ---
  void _showPushConfirmDialog(BuildContext context, EquipmentProvider equip, NoticeProvider noticeProv, NoticeItem notice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('푸시 알림 전송'),
        content: Text("'${notice.title}' 공지를 모든 대원에게 알림으로 보낼까요?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚀 알림 발송을 시작합니다. 로그를 확인하세요.')));

              // 💡 NoticeProvider의 전송 기능을 실행하며, 로그는 EquipmentProvider의 콘솔에 기록하게 함
              await noticeProv.sendNoticePush(
                notice,
                logger: equip.addLog,
              );
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
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity, height: double.infinity,
                color: Colors.black.withOpacity(0.9),
                child: InteractiveViewer(
                  clipBehavior: Clip.none,
                  maxScale: 5.0,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipProvider = Provider.of<EquipmentProvider>(context);
    final noticeProvider = Provider.of<NoticeProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('📢 공지사항', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (equipProvider.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined, color: Colors.blue),
              onPressed: () => _showNoticeDialog(context, noticeProvider),
            ),
        ],
      ),
      body: noticeProvider.notices.isEmpty
          ? const Center(child: Text('등록된 공지사항이 없습니다.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: noticeProvider.notices.length,
        itemBuilder: (context, index) {
          final notice = noticeProvider.notices[index];
          return _buildNoticeCard(context, equipProvider, noticeProvider, notice);
        },
      ),
    );
  }

  Widget _buildNoticeCard(BuildContext context, EquipmentProvider equipmentProvider, NoticeProvider noticeProvider, NoticeItem notice) {
    final String dateStr = DateFormat('yyyy.MM.dd HH:mm').format(notice.timestamp);
    int currentImgIndex = 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: notice.isPinned ? Colors.blue[300]! : Colors.grey[200]!, width: notice.isPinned ? 2 : 1),
      ),
      child: ExpansionTile(
        onExpansionChanged: (bool expanded) {
          // 💡 리스트가 펼쳐질 때 모든 이미지를 메모리에 미리 로드합니다.
          if (expanded) {
            for (var url in notice.imageUrls) {
              precacheImage(NetworkImage(url), context);
            }
          }
        },
        leading: CircleAvatar(
          backgroundColor: notice.isPinned ? Colors.blue : Colors.grey[100],
          child: Icon(notice.isPinned ? Icons.push_pin : Icons.campaign_outlined,
              color: notice.isPinned ? Colors.white : Colors.blueGrey, size: 20),
        ),
        title: Text(notice.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        children: [
          StatefulBuilder(builder: (context, setCardState) {
            final PageController pageController = PageController();

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  if (notice.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 1.2,
                      child: PageView(
                        controller: pageController,
                        allowImplicitScrolling: true, // 옆 페이지 미리 렌더링
                        onPageChanged: (index) {
                          setCardState(() {
                            currentImgIndex = index;
                          });
                        },
                        // 💡 builder 대신 children을 사용하여 모든 이미지 위젯을 즉시 초기화
                        children: notice.imageUrls.map((url) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: () => _showFullImage(context, url),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                gaplessPlayback: true, // 끊김 없는 재생 보장
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                    if (notice.imageUrls.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${currentImgIndex + 1} / ${notice.imageUrls.length}",
                              style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Text(notice.content, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6)),
                  const SizedBox(height: 16),
                  if (equipmentProvider.isAdmin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _actionButton(onPressed: () => noticeProvider.pinNotice(notice.id), icon: Icons.home_outlined, label: notice.isPinned ? '게시 중' : '홈 게시', color: notice.isPinned ? Colors.blue : Colors.grey),
                        const SizedBox(width: 12),
                        _actionButton(onPressed: () => _showPushConfirmDialog(context, equipmentProvider, noticeProvider, notice), icon: Icons.notifications_active_outlined, label: '알림', color: Colors.orange),
                        const SizedBox(width: 12),
                        _actionButton(onPressed: () => _showNoticeDialog(context, noticeProvider, existingNotice: notice), icon: Icons.edit_outlined, label: '수정', color: Colors.blueGrey),
                        const SizedBox(width: 12),
                        _actionButton(onPressed: () => _showDeleteConfirmDialog(context, noticeProvider, notice.id), icon: Icons.delete_outline, label: '삭제', color: Colors.redAccent),
                      ],
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _actionButton({required VoidCallback onPressed, required IconData icon, required String label, required Color color}) {
    return InkWell(onTap: onPressed, child: Column(children: [Icon(icon, size: 20, color: color), const SizedBox(height: 2), Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))]));
  }

  void _showDeleteConfirmDialog(BuildContext context, NoticeProvider noticeProvider, String id) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('공지 삭제'), content: const Text('정말로 삭제하시겠습니까?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), TextButton(onPressed: () { noticeProvider.deleteNotice(id); Navigator.pop(context); }, child: const Text('삭제', style: TextStyle(color: Colors.red)))]));
  }
}