import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../providers/auth_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/dive_site_provider.dart';
import '../util/maps_ready_stub.dart'
    if (dart.library.js_interop) '../util/maps_ready_web.dart';
import '../util/site_photos.dart';
import '../util/usage_stats.dart';

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

  /// 하단 포인트 목록 표시 여부
  static bool get _showPointList => true;

  /// 💡 하단 목록 고정 순서 (사용자 지정)
  static const List<String> _listOrder = [
    '죽도', '관음도', '공암', '쌍정초', '내수전 몽돌해변', '행남등대', '북저바위',
  ];

  int _listRank(DiveSite s) {
    final i = _listOrder.indexWhere(
        (o) => s.name == o || s.name.contains(o) || o.contains(s.name));
    if (i >= 0) return i;
    return s.isBase ? -1 : 999; // 베이스는 맨 위, 그 외 미지정은 맨 뒤
  }

  /// 💡 관리자 위치 조정 모드: 켜면 마커를 끌어서 위치를 저장할 수 있다
  bool _moveMode = false;

  /// 💡 줌에 따른 마커 크기 배율 (줌 아웃하면 라벨도 작아져 덜 뭉친다)
  double _markerScale = 1.0;

  /// 캔버스로 그린 라벨 마커 캐시 (내용+배율 → 아이콘)
  final Map<String, BitmapDescriptor> _labelIcons = {};
  final Set<String> _labelPending = {};

  /// 💡 마지막 카메라 상태 (800의 '카메라 저장'용)
  CameraPosition? _lastCamera;

  @override
  void initState() {
    super.initState();
    // 💡 웹(CanvasKit)은 한글 폰트를 뒤늦게 내려받는다 — 폰트가 준비되기 전에
    // 그린 라벨은 글자가 □□(tofu)로 깨진 채 캐시되므로, 폰트 로딩이 끝나는
    // 순간 캐시를 비우고 전부 다시 그린다.
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
  }

  void _onFontsChanged() {
    if (!mounted) return;
    setState(() {
      _labelIcons.clear();
      _labelPending.clear();
    });
  }

  /// 💡 구글맵 JS가 준비된 뒤에만 지도 위젯을 만든다 (타이밍 크래시 방지)
  late final Future<bool> _mapsReady = waitForGoogleMaps();

  // 울릉도 중심
  static const _ulleungCenter = LatLng(37.505, 130.868);

  /// 대장의 구글 어스 프로젝트 — 포인트별 바로가기 링크.
  /// 어스는 iframe 임베드를 차단해서 외부 브라우저로 연다.
  /// 💡 fdl=1: 모바일 접속 시 플레이스토어로 보내는 리다이렉트를 건너뛴다.
  /// 빈 문자열 = 아직 링크 미연결 (버튼 누르면 준비 중 안내).
  static const Map<String, String> _earthLinks = {
    '죽도':
        'https://earth.google.com/web/data=MkEKPwo9CiExLW4zV1F4eUd0ODZmQ3MweWhpWHdpWXZmOHQtU0M2SU8SFgoUMEY5NkM1RkM4RjQwRjg2MERGN0UgAUICCABKCAixjf3tBhAB?hl=ko&fdl=1',
    '관음도':
        'https://earth.google.com/web/data=MkEKPwo9CiExOW9tT2x4NGJ6UEhDajc4dmUxTnI4elhKMXRCT0FFTHoSFgoUMDg4RENERThCQTQxMDMyOUJFMjggAUICCABKCAin2IWMAxAB?hl=ko&authuser=0&fdl=1',
    '공암':
        'https://earth.google.com/web/data=MkEKPwo9CiExUVBkZ1g5WGtCMmZtRUxUTkhzNXZ4czYteWdWTWMxNm8SFgoUMDc5QjA5OTlDNDQxMDVFMzM3RDAgAUICCABKCAiruKqfAhAB?hl=ko&authuser=0&fdl=1',
    '쌍정초':
        'https://earth.google.com/web/data=MkEKPwo9CiExWElFckRhMFFQMHZrbHp0RFBuMGZtWUJzLUhqVHV6OG0SFgoUMDkwQjdFNDhFNDQxMDVEODk5QTkgAUICCABKCAjv962oAhAB?hl=ko&authuser=0&fdl=1',
  };

  void _openEarth(String url) {
    // 💡 어스 버튼 4개(죽도·관음도·공암·쌍정초)를 하나로 묶어 집계
    UsageStats.log('earth');
    // PC(넓은 화면)는 바로 열림 — 안내가 필요 없다
    if (MediaQuery.of(context).size.width > 700) {
      launchUrlString(url, mode: LaunchMode.externalApplication);
      return;
    }

    // 📱 폰: 어스가 모바일 브라우저를 앱 설치 페이지로 보내므로
    //    "그 화면에서 데스크톱 모드 켜기" 1회 설정을 안내한다.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🌍 구글 어스 — 처음 한 번만 설정!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '1. 아래 버튼을 누르면 "앱 다운로드" 화면이 떠요\n'
                  '    → 정상입니다! 당황 금지 🙅\n'
                  '2. 그 화면에서 브라우저 메뉴(⋮) 열기\n'
                  '3. "데스크톱 사이트" 체크 ✓ (+앱으로 설치)\n'
                  '4. 자동 새로고침되며 어스가 열립니다\n\n'
                  '한 번 해두면 다음부터는 버튼만 눌러도 바로 열려요.',
                  style: TextStyle(fontSize: 13, height: 1.65),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    launchUrlString(url,
                        mode: LaunchMode.externalApplication);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.public, size: 18),
                  label: const Text('구글 어스 열기',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 입력 컨트롤러 — State 소유 (dispose 크래시 방지)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _depthController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _featuresController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    _mapController?.dispose();
    _nameController.dispose();
    _depthController.dispose();
    _levelController.dispose();
    _featuresController.dispose();
    _noteController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- 포인트 사진

  /// 이 포인트(또는 세부 포인트)의 사진 목록 (존재·개수 확인용, 기본 순서)
  /// 💡 세부 포인트 이름 앞의 번호("1. ")를 뗀 원래 이름.
  /// 사진 매핑(kSitePhotos)·저장된 사진 순서 키는 번호 없는 이름 기준이라,
  /// 번호를 새로 붙이거나 바꿔도 사진 연결이 깨지지 않는다.
  String _plainName(String name) =>
      name.replaceFirst(RegExp(r'^\d+\.\s*'), '');

  List<String> _photosFor(String siteName, [String? subName]) =>
      kSitePhotos[subName == null
          ? siteName
          : '$siteName|${_plainName(subName)}'] ??
      const [];

  /// 갤러리 위젯 — 저장된 순서 적용. 관리자는 길게 눌러 드래그로 재정렬.
  Widget _photoGallery(String photoKey, {bool isAdmin = false}) {
    final provider = context.read<DiveSiteProvider>();
    final photos =
        provider.orderedPhotos(photoKey, kSitePhotos[photoKey] ?? const []);
    if (photos.isEmpty) return const SizedBox.shrink();
    return _PhotoGallery(
      photoKey: photoKey,
      photos: photos,
      isAdmin: isAdmin,
      provider: provider,
    );
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

  // ------------------------------------------------------- 라벨 마커 생성

  /// 💡 이름·정보가 적힌 말풍선 라벨 마커를 캔버스로 직접 그린다.
  /// 하단 점이 실제 좌표에 오도록 anchor(0.5, 1.0)와 함께 쓴다.
  /// 라벨 정렬: 마커 점은 그대로 두고 말풍선만 좌/우로 비켜 겹침을 줄인다.
  /// 반환값 = 이미지 안에서 점(실좌표)이 놓일 가로 비율 (anchor.x와 동일하게 사용)
  double _labelAlignX(String name) {
    if (name.contains('행남등대')) return 0.88; // 라벨이 점 왼쪽으로
    if (name.contains('북저바위')) return 0.12; // 라벨이 점 오른쪽으로
    return 0.5;
  }

  Future<BitmapDescriptor> _makeLabelIcon({
    required String title,
    String? subtitle,
    required Color accent,
    double scale = 1.0,
    double alignX = 0.5,
  }) async {
    const dpr = 2.0; // 선명하게 2배로 그려서 절반 크기로 표시
    final s = scale * dpr;

    final titleTp = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
            fontSize: 12.5 * s,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    TextPainter? subTp;
    if (subtitle != null && subtitle.isNotEmpty) {
      subTp = TextPainter(
        text: TextSpan(
          text: subtitle,
          style: TextStyle(
              fontSize: 10 * s,
              fontWeight: FontWeight.w600,
              color: Colors.white70),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final padH = 7.0 * s;
    final padV = 4.5 * s;
    final gap = 1.5 * s;
    final boxW = math.max(titleTp.width, subTp?.width ?? 0) + padH * 2;
    final boxH =
        titleTp.height + (subTp == null ? 0 : subTp.height + gap) + padV * 2;
    final tailH = 6.0 * s;
    final dotR = 3.5 * s;
    final width = boxW + 6 * s; // 테두리·그림자 여유
    final height = boxH + tailH + dotR * 2 + 4 * s;
    final cx = width / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - boxW / 2, 1 * s, boxW, boxH),
        Radius.circular(7 * s));

    // 💡 색으로 꽉 채운 말풍선 (흰 배경보다 눈에 확 띄게)
    final darker = Color.lerp(accent, Colors.black, 0.35)!;
    canvas.drawRRect(
        rrect.shift(Offset(0, 1.5 * s)),
        Paint()
          ..color = Colors.black.withAlpha(55)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5 * s));
    canvas.drawRRect(rrect, Paint()..color = accent);
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * s
          ..color = darker);

    // 꼬리 삼각형 + 실좌표 점 (alignX에 따라 좌/우로 비켜난 위치)
    final dotX = (width * alignX)
        .clamp(dotR + 2 * s, width - dotR - 2 * s)
        .toDouble();
    final tailTop = 1 * s + boxH;
    final tail = Path()
      ..moveTo(dotX - 4.5 * s, tailTop)
      ..lineTo(dotX + 4.5 * s, tailTop)
      ..lineTo(dotX, tailTop + tailH)
      ..close();
    canvas.drawPath(tail, Paint()..color = accent);
    final dotY = tailTop + tailH + dotR;
    canvas.drawCircle(Offset(dotX, dotY), dotR, Paint()..color = accent);
    canvas.drawCircle(
        Offset(dotX, dotY), dotR * 0.45, Paint()..color = Colors.white);

    // 텍스트
    titleTp.paint(canvas, Offset(cx - titleTp.width / 2, 1 * s + padV));
    subTp?.paint(canvas,
        Offset(cx - subTp.width / 2, 1 * s + padV + titleTp.height + gap));

    final img =
        await recorder.endRecording().toImage(width.ceil(), height.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }

  /// 캐시에 없으면 백그라운드로 생성하고, 완성되면 다시 그린다
  void _ensureLabelIcon(String key,
      {required String title,
      String? subtitle,
      required Color accent,
      required double scale,
      double alignX = 0.5}) {
    if (_labelIcons.containsKey(key) || _labelPending.contains(key)) return;
    _labelPending.add(key);
    _makeLabelIcon(
            title: title,
            subtitle: subtitle,
            accent: accent,
            scale: scale,
            alignX: alignX)
        .then((icon) {
      if (!mounted) return;
      setState(() => _labelIcons[key] = icon);
    }).catchError((_) {
      _labelPending.remove(key);
    });
  }

  /// 💡 세부 보기 카메라 — 800이 저장해둔 화면이 있으면 그 위치·줌으로,
  /// 없으면 포인트 중심 + 기본 줌.
  CameraUpdate _siteCamera(DiveSite site) => CameraUpdate.newLatLngZoom(
        LatLng(site.camLat ?? site.lat, site.camLng ?? site.lng),
        site.camZoom ?? 14.2,
      );

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
      _mapController?.animateCamera(_siteCamera(site));
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

    // 하단 목록: 사용자 지정 순서
    final orderedSites = [...sites]
      ..sort((a, b) => _listRank(a).compareTo(_listRank(b)));

    // 라벨 아이콘: 캐시에 있으면 쓰고, 없으면 생성 예약 후 기본 마커로 대기
    BitmapDescriptor labelIcon(
        String key, String title, String? subtitle, Color accent,
        {double alignX = 0.5}) {
      final cacheKey =
          '$key|$title|$subtitle|${accent.toARGB32()}|$_markerScale|$alignX';
      _ensureLabelIcon(cacheKey,
          title: title,
          subtitle: subtitle,
          accent: accent,
          scale: _markerScale,
          alignX: alignX);
      return _labelIcons[cacheKey] ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
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
                  // 💡 줌 아웃하면 마커 라벨도 함께 작아진다 (3단계)
                  onCameraMove: (pos) {
                    _lastCamera = pos; // 800 '카메라 저장'용
                    final s = pos.zoom >= 13
                        ? 1.0
                        : pos.zoom >= 11.8
                            ? 0.85
                            : 0.7;
                    if (s != _markerScale) {
                      setState(() => _markerScale = s);
                    }
                  },
                  markers: {
                    // ── 핵심 포인트: 이름·수심·난이도·세부수가 적힌 라벨 마커
                    for (final site in sites)
                      Marker(
                        markerId: MarkerId(site.id),
                        position: LatLng(site.lat, site.lng),
                        // 💡 겹치는 포인트는 라벨만 좌/우로 비킨다 (점 위치는 그대로)
                        anchor: Offset(_labelAlignX(site.name), 1.0),
                        // 💡 라벨은 포인트명만 — 정보는 하단 목록·시트에서
                        icon: labelIcon(
                          'site_${site.id}',
                          site.isBase ? '⭐ ${site.name}' : site.name,
                          null,
                          site.isBase
                              ? const Color(0xFFF9A825)
                              : Colors.blue[700]!,
                          alignX: _labelAlignX(site.name),
                        ),
                        draggable: isAdmin && _moveMode,
                        onDragEnd: (p) => provider.moveSite(
                            site.id, p.latitude, p.longitude),
                        onTap: () =>
                            _onMainMarkerTap(site, isAdmin, provider),
                      ),
                    // ── 펼쳐진 핵심 포인트의 세부 마커 (테두리 색 = 난이도)
                    if (expanded != null)
                      for (var i = 0; i < expanded.subPoints.length; i++)
                        Marker(
                          markerId: MarkerId('${expanded.id}_sub_$i'),
                          position: _subPos(expanded, i),
                          anchor: const Offset(0.5, 1.0),
                          icon: labelIcon(
                            'sub_${expanded.id}_$i',
                            expanded.subPoints[i]['name'] ?? '',
                            null,
                            _levelColor(
                                expanded.subPoints[i]['level'] ?? ''),
                          ),
                          draggable: isAdmin && _moveMode,
                          onDragEnd: (p) => provider.moveSubPoint(
                              expanded!, i, p.latitude, p.longitude),
                          onTap: () => _showSubPointSheet(
                              expanded!, expanded.subPoints[i]),
                        ),
                  },
                    ),
                    // 💡 서비스 소개 (왜 만들었는지 + 어스 사용법)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: GestureDetector(
                        onTap: _showServiceInfo,
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withAlpha(40),
                                  blurRadius: 6),
                            ],
                          ),
                          child: Icon(Icons.question_mark_rounded,
                              size: 17, color: Colors.grey[700]),
                        ),
                      ),
                    ),
                    // 💡 관리자: 위치 조정 모드 토글
                    if (isAdmin)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _moveMode = !_moveMode),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color:
                                  _moveMode ? Colors.red[600] : Colors.white,
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
                                Icon(Icons.open_with,
                                    size: 14,
                                    color: _moveMode
                                        ? Colors.white
                                        : Colors.grey[700]),
                                const SizedBox(width: 4),
                                Text(
                                  _moveMode ? '조정 끝내기' : '위치 조정',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: _moveMode
                                        ? Colors.white
                                        : Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // 💡 800 전용: 세부 포인트가 펼쳐진 상태에서 지도를 원하는
                    // 위치·줌으로 맞춘 뒤 누르면, 그 화면이 이 포인트의
                    // 세부 보기 카메라로 저장된다 (모든 사용자에게 적용).
                    if (isAdmin &&
                        context.watch<AuthProvider>().isDeveloper &&
                        expanded != null)
                      Positioned(
                        top: 52,
                        right: 10,
                        child: GestureDetector(
                          onTap: () {
                            final cam = _lastCamera;
                            if (cam == null) return;
                            provider.saveCamera(
                                expanded!.id,
                                cam.target.latitude,
                                cam.target.longitude,
                                cam.zoom);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '📷 ${expanded.name} 세부 보기 카메라 저장! (줌 ${cam.zoom.toStringAsFixed(1)})'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withAlpha(40),
                                    blurRadius: 6),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera_outlined,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  '카메라 저장',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // 위치 조정 모드 안내
                    if (isAdmin && _moveMode)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Text(
                              '마커를 끌어서 놓으면 위치가 저장됩니다',
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    // 펼침 상태 안내 칩 (? 버튼 아래)
                    if (expanded != null)
                      Positioned(
                        top: 52,
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

          // ── 하단 패널: 어스 버튼 + 안내 배너 (포인트 목록은 잠시 숨김)
          Container(
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
                  // 💡 구글 어스 버튼 — 포인트별 바로가기 4개
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        for (final e in _earthLinks.entries) ...[
                          if (e.key != _earthLinks.keys.first)
                            const SizedBox(width: 6),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (e.value.isEmpty) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(const SnackBar(
                                        content:
                                            Text('이 포인트의 어스 링크는 준비 중이에요!'),
                                        duration: Duration(seconds: 2),
                                      ));
                                    return;
                                  }
                                  _openEarth(e.value);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: e.value.isEmpty
                                      ? Colors.blueGrey[200]
                                      : Colors.blue[800],
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(11)),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Text('🌍',
                                        style: TextStyle(fontSize: 13)),
                                    Text(e.key,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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
                  if (_showPointList)
                    SizedBox(
                    height: 210,
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
                        for (final site in orderedSites)
                          GestureDetector(
                            onTap: () {
                              if (site.subPoints.isNotEmpty) {
                                setState(() => _expandedSiteId = site.id);
                              }
                              _mapController?.animateCamera(_siteCamera(site));
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
        ],
      ),
    );
  }

  /// 💡 ? 버튼: 이 서비스를 만든 이유 + 구글 어스 사용법
  void _showServiceInfo() {
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
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                const Text('🗺 사이트 기능 설명',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '처음 다이빙을 하면, 포인트 브리핑을 들어도 머릿속에 잘 그려지지 않고, '
                    '다녀와도 자신이 어디를 다녀온 것인지 잘 모를 수 있습니다.\n\n'
                    '따라서 포인트 위치와 간단한 설명을 쉽게 확인할 수 있도록 하여, '
                    '포인트에 대한 이해를 돕고 다이빙을 더욱 재밌게 하는 서비스를 '
                    '구현하고자 했습니다.\n\n'
                    '여러분의 원정 다이빙이 더욱 재밌어지고, 소중한 추억으로 '
                    '오랫도록 잘 간직할 수 있길 바랍니다.',
                    style: TextStyle(fontSize: 13, height: 1.7),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('📖 구글 어스 사용법',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '1. 구글 어스 왼쪽 하단의 [계속] 버튼을 누르면 슬라이드쇼로 '
                    '포인트를 차례대로 볼 수 있어요.\n\n'
                    '2. 두 손가락으로 회전하면서 울릉도와 다이빙 포인트의 위치·모양을 '
                    '다각도로 살펴보세요.\n\n'
                    '3. 화면 오른쪽 하단을 두 손가락으로 위아래로 밀면 기울기를 '
                    '조정할 수 있어요.\n\n'
                    '💻 PC로 보면 더 편해요!',
                    style: TextStyle(fontSize: 13, height: 1.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- 상세 시트

  void _showSiteSheet(DiveSite site, bool isAdmin, DiveSiteProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // 💡 지도를 계속 볼 수 있게: 배경을 어둡게 덮지 않고,
      //    낮게 열리는 드래그 시트로 (위로 끌면 전체 내용)
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.28,
        maxChildSize: 0.85,
        builder: (sheetContext, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 14),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
          controller: scrollController,
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
              // 💡 유튜브 링크 (핵심 포인트 전용)
              if (site.youtube.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrlString(site.youtube.trim(),
                        mode: LaunchMode.externalApplication),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.play_circle_fill, size: 18),
                    label: const Text('유튜브 영상 보기',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              // 💡 포인트 사진 (사이트 직속 — 쌍정초·공암 등)
              if (_photosFor(site.name).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('📷 사진 (탭하면 크게)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400])),
                const SizedBox(height: 6),
                _photoGallery(site.name, isAdmin: isAdmin),
              ],
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
                for (final sp in site.subPoints) _subPointCard(site, sp),
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
    final isAdmin = context.read<EquipmentProvider>().isAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
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
              // 💡 세부 포인트 사진 갤러리
              if (_photosFor(site.name, (sp['name'] ?? '').trim())
                  .isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('📷 사진 (탭하면 크게)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400])),
                const SizedBox(height: 6),
                _photoGallery(
                    '${site.name}|${_plainName((sp['name'] ?? '').trim())}',
                    isAdmin: isAdmin),
              ],
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

  Widget _subPointCard(DiveSite site, Map<String, String> sp) {
    final level = (sp['level'] ?? '').trim();
    final depth = (sp['depth'] ?? '').trim();
    final desc = (sp['desc'] ?? '').trim();
    final color = _levelColor(level);
    final photoCount = _photosFor(site.name, (sp['name'] ?? '').trim()).length;

    return GestureDetector(
      // 💡 카드 탭 = 세부 포인트 시트 (사진 갤러리 포함)
      onTap: () => _showSubPointSheet(site, sp),
      child: Container(
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
              if (photoCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text('📷 $photoCount',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700])),
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
    _youtubeController.text = site?.youtube ?? '';
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
              const SizedBox(height: 8),
              TextField(
                controller: _youtubeController,
                decoration: const InputDecoration(
                    labelText: '유튜브 링크 (선택)', isDense: true),
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
                youtube: _youtubeController.text.trim(),
                isBase: isBase,
                // 💡 세부 포인트는 이 다이얼로그에서 안 다루므로 기존 것을 보존
                //    (빼먹으면 빈 배열로 덮어써 세부 포인트가 날아간다!)
                subPoints: site?.subPoints ?? const [],
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

/// 💡 사진 갤러리: 가로 썸네일, 탭 = 전체화면 뷰어.
/// 관리자는 썸네일을 길게 눌러 끌면 순서가 바뀌고 Firestore에 저장된다 (전 기기 공유).
class _PhotoGallery extends StatefulWidget {
  final String photoKey;
  final List<String> photos;
  final bool isAdmin;
  final DiveSiteProvider provider;

  const _PhotoGallery({
    required this.photoKey,
    required this.photos,
    required this.isAdmin,
    required this.provider,
  });

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  late List<String> _photos = List.of(widget.photos);

  Widget _thumb(int i) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _PhotoViewerScreen(photos: List.of(_photos), initial: i),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            _photos[i],
            width: 150,
            height: 110,
            fit: BoxFit.cover,
            loadingBuilder: (c, child, progress) => progress == null
                ? child
                : Container(
                    width: 150,
                    height: 110,
                    color: const Color(0xFFF1F3F5),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
            errorBuilder: (c, e, s) => Container(
              width: 150,
              height: 110,
              color: const Color(0xFFF1F3F5),
              child:
                  Icon(Icons.broken_image_outlined, color: Colors.grey[400]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gallery = SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        separatorBuilder: (_, i) => const SizedBox(width: 6),
        itemBuilder: (context, i) => _thumb(i),
      ),
    );

    if (!widget.isAdmin) return gallery;

    // 관리자: [순서 수정] → 전체가 한눈에 보이는 격자 화면에서 드래그 드롭
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        gallery,
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PhotoOrderScreen(
                  photoKey: widget.photoKey,
                  photos: List.of(_photos),
                  provider: widget.provider,
                ),
              ),
            );
            // 순서 화면에서 돌아오면 저장된 최신 순서로 갱신
            if (!mounted) return;
            setState(() {
              _photos = widget.provider.orderedPhotos(
                  widget.photoKey, kSitePhotos[widget.photoKey] ?? const []);
            });
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            side: BorderSide(color: Colors.grey[300]!),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9)),
          ),
          icon: Icon(Icons.swap_horiz_rounded,
              size: 15, color: Colors.grey[700]),
          label: Text('순서 수정',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700])),
        ),
      ],
    );
  }
}

/// 💡 사진 순서 수정 화면: 전체 사진이 격자로 한눈에 보이고,
/// 길게 눌러 끌어서 원하는 자리에 놓으면 그 위치로 이동한다 (놓는 즉시 저장).
class _PhotoOrderScreen extends StatefulWidget {
  final String photoKey;
  final List<String> photos;
  final DiveSiteProvider provider;

  const _PhotoOrderScreen({
    required this.photoKey,
    required this.photos,
    required this.provider,
  });

  @override
  State<_PhotoOrderScreen> createState() => _PhotoOrderScreenState();
}

class _PhotoOrderScreenState extends State<_PhotoOrderScreen> {
  late final List<String> _photos = List.of(widget.photos);

  Widget _cell(int i, {bool dragging = false, bool highlight = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Opacity(
            opacity: dragging ? 0.35 : 1,
            child: Image.network(
              _photos[i],
              fit: BoxFit.cover,
              loadingBuilder: (c, child, progress) => progress == null
                  ? child
                  : Container(color: const Color(0xFFF1F3F5)),
              errorBuilder: (c, e, s) => Container(
                color: const Color(0xFFF1F3F5),
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.grey[400]),
              ),
            ),
          ),
        ),
        // 순서 번호 뱃지
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(140),
              shape: BoxShape.circle,
            ),
            child: Text('${i + 1}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
        // 드롭 대상 강조 테두리
        if (highlight)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue[600]!, width: 2.5),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('사진 순서 수정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('완료',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE3F2FD),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text('사진을 길게 눌러 끌어서 원하는 자리에 놓으세요. 놓는 즉시 저장됩니다.',
                style: TextStyle(fontSize: 11.5, color: Colors.blue[900])),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, i) => DragTarget<int>(
                onWillAcceptWithDetails: (d) => d.data != i,
                onAcceptWithDetails: (d) {
                  setState(() {
                    final item = _photos.removeAt(d.data);
                    _photos.insert(i, item);
                  });
                  widget.provider
                      .savePhotoOrder(widget.photoKey, List.of(_photos));
                },
                builder: (context, candidates, rejected) =>
                    LongPressDraggable<int>(
                  data: i,
                  feedback: SizedBox(
                    width: 100,
                    height: 100,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(_photos[i], fit: BoxFit.cover),
                    ),
                  ),
                  childWhenDragging: _cell(i, dragging: true),
                  child: _cell(i, highlight: candidates.isNotEmpty),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 💡 전체화면 사진 뷰어: 좌우 스와이프 + 핀치 줌
class _PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initial;

  const _PhotoViewerScreen({required this.photos, required this.initial});

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _pageController =
      PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text('${_index + 1} / ${widget.photos.length}',
            style: const TextStyle(fontSize: 14, color: Colors.white)),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.photos[i],
              fit: BoxFit.contain,
              loadingBuilder: (c, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white54, strokeWidth: 2),
                    ),
              errorBuilder: (c, e, s) => Icon(Icons.broken_image_outlined,
                  color: Colors.grey[600], size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
