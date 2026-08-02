import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../providers/equipment_provider.dart';
import '../providers/dive_site_provider.dart';
import '../util/maps_ready_stub.dart'
    if (dart.library.js_interop) '../util/maps_ready_web.dart';

/// 💡 다이브 사이트: 울릉도 포인트를 구글맵 마커로.
/// 마커/목록 탭 = 상세, 관리자는 지도를 길게 눌러 포인트 추가.
class DiveSiteScreen extends StatefulWidget {
  const DiveSiteScreen({super.key});

  @override
  State<DiveSiteScreen> createState() => _DiveSiteScreenState();
}

class _DiveSiteScreenState extends State<DiveSiteScreen> {
  GoogleMapController? _mapController;

  /// 💡 세부 포인트가 펼쳐진 핵심 포인트 (클러스터 확장 상태)
  String? _expandedSiteId;

  /// 💡 구글맵 JS가 준비된 뒤에만 지도 위젯을 만든다 (타이밍 크래시 방지)
  late final Future<bool> _mapsReady = waitForGoogleMaps();

  // 울릉도 중심
  static const _ulleungCenter = LatLng(37.505, 130.868);

  /// 대장의 구글 어스 프로젝트 (울릉도 포인트 지도).
  /// 어스는 iframe 임베드를 차단해서 외부 브라우저로 연다.
  /// 💡 fdl=1: 모바일 접속 시 플레이스토어로 보내는 리다이렉트를 건너뛴다.
  static const _earthUrl =
      'https://earth.google.com/web/data=MkEKPwo9CiExLW4zV1F4eUd0ODZmQ3MweWhpWHdpWXZmOHQtU0M2SU8SFgoUMEZFNDkwQkUwRTQwRjgwQkRGMzQgAUICCABKCAiN_bqqBxAB?hl=ko&fdl=1';

  void _openEarth() {
    launchUrlString(_earthUrl, mode: LaunchMode.externalApplication);
  }

  /// 입력 컨트롤러 — State 소유 (dispose 크래시 방지)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _depthController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _featuresController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    _depthController.dispose();
    _levelController.dispose();
    _featuresController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 세부 포인트 마커 위치: 저장된 좌표가 있으면 그대로, 없으면
  /// 부모 포인트 주변에 도식적으로 원형 배치한다 (실측 아님).
  LatLng _subPos(DiveSite site, int index) {
    final sp = site.subPoints[index];
    final lat = double.tryParse(sp['lat'] ?? '');
    final lng = double.tryParse(sp['lng'] ?? '');
    if (lat != null && lng != null) return LatLng(lat, lng);

    final n = site.subPoints.length;
    final angle = 2 * math.pi * index / n - math.pi / 2;
    const radius = 0.0038; // 약 400m
    return LatLng(
      site.lat + radius * math.cos(angle),
      site.lng + radius * math.sin(angle) * 1.27,
    );
  }

  /// 난이도 → 마커 색조 (지도에서 난이도 분포가 바로 보이게)
  double _levelHue(String level) {
    if (level.contains('중상')) return 15; // 주홍
    if (level.contains('상급')) return BitmapDescriptor.hueRed;
    if (level.contains('중급')) return BitmapDescriptor.hueOrange;
    if (level.contains('초') || level.contains('오픈')) {
      return BitmapDescriptor.hueGreen;
    }
    return BitmapDescriptor.hueViolet;
  }

  void _onMainMarkerTap(DiveSite site, bool isAdmin, DiveSiteProvider provider) {
    if (site.subPoints.isEmpty) {
      _showSiteSheet(site, isAdmin, provider);
      return;
    }
    if (_expandedSiteId == site.id) {
      // 이미 펼쳐진 상태에서 한 번 더 탭 = 상세 시트
      _showSiteSheet(site, isAdmin, provider);
    } else {
      setState(() => _expandedSiteId = site.id);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(site.lat, site.lng), 14.2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EquipmentProvider>().isAdmin;
    final provider = context.watch<DiveSiteProvider>();
    final sites = provider.sites;

    DiveSite? expanded;
    for (final s in sites) {
      if (s.id == _expandedSiteId) expanded = s;
    }

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
              padding: EdgeInsets.only(right: 4),
              child: Center(
                child: Text('길게 누르기 = 추가',
                    style: TextStyle(fontSize: 11, color: Colors.blue)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── 지도 (JS 라이브러리 준비 후에만 그린다)
          Expanded(
            flex: 11,
            child: FutureBuilder<bool>(
              future: _mapsReady,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data != true) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        '지도를 불러오지 못했습니다.\n앱을 완전히 종료했다가 다시 실행해주세요.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12.5, color: Colors.grey[500]),
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    GoogleMap(
                  initialCameraPosition: const CameraPosition(
                      target: _ulleungCenter, zoom: 11.3),
                  onMapCreated: (c) => _mapController = c,
                  // 💡 웹에서 마우스 드래그/휠이 지도에 바로 먹히게 한다
                  webGestureHandling: WebGestureHandling.greedy,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  // 빈 지도를 탭하면 펼쳐진 세부 포인트를 접는다
                  onTap: (_) {
                    if (_expandedSiteId != null) {
                      setState(() => _expandedSiteId = null);
                    }
                  },
                  onLongPress: isAdmin
                      ? (latLng) => _showEditDialog(provider,
                          presetLat: latLng.latitude,
                          presetLng: latLng.longitude)
                      : null,
                  markers: {
                    // ── 핵심 포인트 마커
                    for (final site in sites)
                      Marker(
                        markerId: MarkerId(site.id),
                        position: LatLng(site.lat, site.lng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            site.isBase
                                ? BitmapDescriptor.hueYellow
                                : BitmapDescriptor.hueAzure),
                        infoWindow: InfoWindow(
                          title: site.isBase
                              ? '⭐ ${site.name} (베이스)'
                              : site.name,
                          snippet: site.subPoints.isNotEmpty
                              ? '한 번 더 탭 = 상세 · 세부 ${site.subPoints.length}곳 펼침'
                              : null,
                        ),
                        onTap: () =>
                            _onMainMarkerTap(site, isAdmin, provider),
                      ),
                    // ── 펼쳐진 핵심 포인트의 세부 마커 (색 = 난이도)
                    if (expanded != null)
                      for (var i = 0; i < expanded.subPoints.length; i++)
                        Marker(
                          markerId: MarkerId('${expanded.id}_sub_$i'),
                          position: _subPos(expanded, i),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              _levelHue(
                                  expanded.subPoints[i]['level'] ?? '')),
                          infoWindow: InfoWindow(
                            title: expanded.subPoints[i]['name'] ?? '',
                            snippet: [
                              if ((expanded.subPoints[i]['depth'] ?? '')
                                  .isNotEmpty)
                                expanded.subPoints[i]['depth'],
                              if ((expanded.subPoints[i]['level'] ?? '')
                                  .isNotEmpty)
                                expanded.subPoints[i]['level'],
                            ].join(' · '),
                          ),
                          onTap: () => _showSubPointSheet(
                              expanded!, expanded.subPoints[i]),
                        ),
                  },
                    ),
                    // 펼침 상태 안내 칩
                    if (expanded != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _expandedSiteId = null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withAlpha(40),
                                    blurRadius: 6),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${expanded.name} 세부 포인트',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 5),
                                Icon(Icons.close,
                                    size: 14, color: Colors.grey[500]),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
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
              child: Column(
                children: [
                  // 💡 구글 어스 버튼 — 눈에 띄게 목록 패널 맨 위에
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _openEarth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🌍', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Text('구글 어스에서 포인트 보기',
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 💡 참고용 안내 배너 (항상 표시)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFFF8E1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 13, color: Colors.orange[800]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '포인트 정보는 참고용이에요 — 실제 입수는 당일 브리핑 기준!',
                            style: TextStyle(
                                fontSize: 11, color: Colors.orange[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
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
                              if (site.subPoints.isNotEmpty) {
                                setState(() => _expandedSiteId = site.id);
                              }
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                    LatLng(site.lat, site.lng), 14.2),
                              );
                              _showSiteSheet(site, isAdmin, provider);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: site.isBase
                                    ? const Color(0xFFFFFDE7)
                                    : const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(10),
                                border: site.isBase
                                    ? Border.all(color: Colors.amber[400]!)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  site.isBase
                                      ? Icon(Icons.star_rounded,
                                          size: 18, color: Colors.amber[700])
                                      : Icon(Icons.location_on,
                                          size: 16, color: Colors.blue[800]),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(site.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        if (site.isBase) ...[
                                          const SizedBox(width: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber[600],
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                            child: const Text('베이스',
                                                style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white)),
                                          ),
                                        ],
                                      ],
                                    ),
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
                                  if (site.subPoints.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.teal[50],
                                        borderRadius:
                                            BorderRadius.circular(7),
                                      ),
                                      child: Text('세부 ${site.subPoints.length}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal[800])),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.78),
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
              Row(
                children: [
                  site.isBase
                      ? Icon(Icons.star_rounded,
                          size: 20, color: Colors.amber[700])
                      : Icon(Icons.location_on,
                          size: 18, color: Colors.blue[800]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        site.isBase ? '${site.name} (베이스)' : site.name,
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
                  site.note.isEmpty &&
                  site.subPoints.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('상세 정보가 아직 없습니다.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                ),
              // 💡 세부 포인트: 난이도 색 뱃지가 붙은 카드 목록
              if (site.subPoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('세부 포인트 ${site.subPoints.length}곳',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400])),
                const SizedBox(height: 6),
                for (final sp in site.subPoints) _subPointCard(sp),
              ],
              const SizedBox(height: 10),
              Text('※ 참고용 정보입니다. 수심·조류·입수 지점은 당일 브리핑으로 확인하세요.',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
              const SizedBox(height: 6),
            ],
          ),
          ),
        ),
      ),
    );
  }

  /// 세부 포인트 미니 시트 (마커 탭)
  void _showSubPointSheet(DiveSite site, Map<String, String> sp) {
    final level = (sp['level'] ?? '').trim();
    final depth = (sp['depth'] ?? '').trim();
    final desc = (sp['desc'] ?? '').trim();
    final color = _levelColor(level);
    final autoPlaced = double.tryParse(sp['lat'] ?? '') == null;

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
                  Icon(Icons.place, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${site.name} · ${sp['name'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.bold)),
                  ),
                  if (level.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(level,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _infoRow('수심', depth),
              _infoRow('특징', desc),
              const SizedBox(height: 8),
              Text(
                autoPlaced
                    ? '※ 이 마커 위치는 보기 좋게 배치한 것으로 실제 위치가 아닙니다. 입수 지점은 당일 브리핑 기준!'
                    : '※ 참고용 정보입니다. 입수 지점은 당일 브리핑 기준!',
                style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 난이도 문자열 → 색 (초급 초록 ~ 상급 빨강)
  Color _levelColor(String level) {
    if (level.contains('중상')) return const Color(0xFFE64A19);
    if (level.contains('상급')) return const Color(0xFFC62828);
    if (level.contains('중급')) return const Color(0xFFEF6C00);
    if (level.contains('초') || level.contains('오픈')) {
      return const Color(0xFF2E7D32);
    }
    return const Color(0xFF546E7A);
  }

  Widget _subPointCard(Map<String, String> sp) {
    final level = (sp['level'] ?? '').trim();
    final depth = (sp['depth'] ?? '').trim();
    final desc = (sp['desc'] ?? '').trim();
    final color = _levelColor(level);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(sp['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              if (depth.isNotEmpty)
                Text(depth,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
              if (level.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(level,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ],
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(desc,
                style: TextStyle(
                    fontSize: 11.5, color: Colors.grey[700], height: 1.4)),
          ],
        ],
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
    var isBase = site?.isBase ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
              const SizedBox(height: 10),
              // 베이스 포인트 토글 (노란 마커 + 목록 상단 고정)
              GestureDetector(
                onTap: () => setDialogState(() => isBase = !isBase),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isBase ? Colors.amber[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: isBase ? Colors.amber[500]! : Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded,
                          size: 16,
                          color:
                              isBase ? Colors.amber[700] : Colors.grey[400]),
                      const SizedBox(width: 5),
                      Text('베이스 포인트',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isBase
                                ? Colors.amber[900]
                                : Colors.grey[500],
                          )),
                    ],
                  ),
                ),
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
                isBase: isBase,
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
      ),
    );
  }
}
