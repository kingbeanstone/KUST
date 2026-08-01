import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/dive_site_provider.dart';

/// 💡 다이브 사이트: 울릉도 포인트를 지도 마커로.
/// 마커/목록 탭 = 상세, 관리자는 지도를 길게 눌러 포인트 추가.
class DiveSiteScreen extends StatefulWidget {
  const DiveSiteScreen({super.key});

  @override
  State<DiveSiteScreen> createState() => _DiveSiteScreenState();
}

class _DiveSiteScreenState extends State<DiveSiteScreen> {
  final MapController _mapController = MapController();

  // 울릉도 중심
  static const _ulleungCenter = LatLng(37.505, 130.868);
  static const _initialZoom = 11.4;

  /// 입력 컨트롤러 — State 소유 (dispose 크래시 방지)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _depthController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _featuresController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _mapController.dispose();
    _nameController.dispose();
    _depthController.dispose();
    _levelController.dispose();
    _featuresController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final provider = context.watch<DiveSiteProvider>();
    final sites = provider.sites;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('🗺 다이브 사이트',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (isAdmin)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Center(
                child: Text('지도 길게 누르기 = 추가',
                    style: TextStyle(fontSize: 11, color: Colors.blue)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── 지도
          Expanded(
            flex: 11,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _ulleungCenter,
                initialZoom: _initialZoom,
                onLongPress: isAdmin
                    ? (tapPos, latLng) => _showEditDialog(provider,
                        presetLat: latLng.latitude, presetLng: latLng.longitude)
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.kust.expedition',
                ),
                MarkerLayer(
                  markers: [
                    for (final site in sites)
                      Marker(
                        point: LatLng(site.lat, site.lng),
                        width: 86,
                        height: 52,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _showSiteSheet(site, isAdmin, provider),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on,
                                  size: 28, color: Colors.blue[800]),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(7),
                                  border:
                                      Border.all(color: Colors.blue[200]!),
                                ),
                                child: Text(
                                  site.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(3),
                    child: Text('© OpenStreetMap',
                        style: TextStyle(fontSize: 9, color: Colors.black45)),
                  ),
                ),
              ],
            ),
          ),

          // ── 포인트 목록 (탭 = 지도 이동 + 상세)
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, -2)),
                ],
              ),
              child: sites.isEmpty
                  ? Center(
                      child: Text(
                        isAdmin
                            ? '지도를 길게 눌러 포인트를 추가하세요.'
                            : '등록된 포인트가 없습니다.',
                        style:
                            const TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      children: [
                        for (final site in sites)
                          GestureDetector(
                            onTap: () {
                              _mapController.move(
                                  LatLng(site.lat, site.lng), 13.5);
                              _showSiteSheet(site, isAdmin, provider);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 16, color: Colors.blue[800]),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(site.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  if (site.depth.isNotEmpty)
                                    Text(site.depth,
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.grey[600])),
                                  if (site.level.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius:
                                            BorderRadius.circular(7),
                                      ),
                                      child: Text(site.level,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[800])),
                                    ),
                                  ],
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

  // ------------------------------------------------------------- 상세 시트

  void _showSiteSheet(DiveSite site, bool isAdmin, DiveSiteProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.blue[800]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(site.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (isAdmin)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showEditDialog(provider, site: site);
                      },
                      child: const Text('수정', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _infoRow('수심', site.depth),
              _infoRow('난이도', site.level),
              _infoRow('특징', site.features),
              _infoRow('참고', site.note),
              if (site.depth.isEmpty &&
                  site.level.isEmpty &&
                  site.features.isEmpty &&
                  site.note.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('상세 정보가 아직 없습니다.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[400])),
          ),
          Expanded(
            child: Text(value.trim(),
                style: const TextStyle(fontSize: 13.5, height: 1.5)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- 추가/수정

  void _showEditDialog(DiveSiteProvider provider,
      {DiveSite? site, double? presetLat, double? presetLng}) {
    _nameController.text = site?.name ?? '';
    _depthController.text = site?.depth ?? '';
    _levelController.text = site?.level ?? '';
    _featuresController.text = site?.features ?? '';
    _noteController.text = site?.note ?? '';
    final lat = site?.lat ?? presetLat ?? _ulleungCenter.latitude;
    final lng = site?.lng ?? presetLng ?? _ulleungCenter.longitude;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(site == null ? '포인트 추가' : '포인트 수정',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                autofocus: site == null,
                decoration: const InputDecoration(
                    labelText: '포인트 이름 (예: 죽도)', isDense: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _depthController,
                      decoration: const InputDecoration(
                          labelText: '수심 (예: 10~25m)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _levelController,
                      decoration: const InputDecoration(
                          labelText: '난이도 (예: 중급)', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _featuresController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: '특징 (지형·생물)', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: '참고 (입수 방법·주의)', isDense: true),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '위치: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (site != null)
            TextButton(
              onPressed: () {
                provider.deleteSite(site.id);
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
              final newSite = DiveSite(
                id: site?.id ?? '',
                name: name,
                lat: lat,
                lng: lng,
                depth: _depthController.text.trim(),
                level: _levelController.text.trim(),
                features: _featuresController.text.trim(),
                note: _noteController.text.trim(),
              );
              if (site == null) {
                provider.addSite(newSite);
              } else {
                provider.updateSite(newSite);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
