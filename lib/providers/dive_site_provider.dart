import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 다이브 사이트(포인트) 하나
class DiveSite {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String depth; // 수심 (예: 10~25m)
  final String level; // 난이도 (예: 초급/중급/상급)
  final String features; // 특징 (지형·생물 등)
  final String note; // 참고 (입수 방법, 주의사항)
  final String youtube; // 유튜브 링크 (핵심 포인트 상세 시트에 버튼으로)
  final bool isBase; // 베이스 포인트 (마커·목록에서 특별 표시)

  /// 세부 포인트 목록: {name, depth, level, desc}
  final List<Map<String, String>> subPoints;

  DiveSite({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.depth = '',
    this.level = '',
    this.features = '',
    this.note = '',
    this.youtube = '',
    this.isBase = false,
    this.subPoints = const [],
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'depth': depth,
        'level': level,
        'features': features,
        'note': note,
        'youtube': youtube,
        'isBase': isBase,
        'subPoints': subPoints,
      };

  factory DiveSite.fromMap(String id, Map<String, dynamic> map) => DiveSite(
        id: id,
        name: (map['name'] ?? '').toString(),
        lat: (map['lat'] as num? ?? 0).toDouble(),
        lng: (map['lng'] as num? ?? 0).toDouble(),
        depth: (map['depth'] ?? '').toString(),
        level: (map['level'] ?? '').toString(),
        features: (map['features'] ?? '').toString(),
        note: (map['note'] ?? '').toString(),
        youtube: (map['youtube'] ?? '').toString(),
        isBase: map['isBase'] == true,
        subPoints: [
          for (final sp in (map['subPoints'] as List? ?? const []))
            if (sp is Map)
              {
                for (final e in sp.entries)
                  e.key.toString(): (e.value ?? '').toString(),
              },
        ],
      );
}

/// 💡 다이브 사이트 — 동아리 공용 'dive_sites' 컬렉션 (지도 마커의 원본)
class DiveSiteProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<DiveSite> _sites = [];
  List<DiveSite> get sites => _sites;

  /// 💡 사진 순서 재정렬 결과 (club_config/site_photos 문서, key → URL 목록)
  Map<String, List<String>> _photoOrder = {};

  StreamSubscription? _sub;
  StreamSubscription? _photoOrderSub;

  DiveSiteProvider() {
    _listen();
    _listenPhotoOrder();
  }

  void _listen() {
    _sub = _db.collection('dive_sites').orderBy('name').snapshots().listen(
        (snapshot) {
      _sites =
          snapshot.docs.map((d) => DiveSite.fromMap(d.id, d.data())).toList()
            // 베이스 포인트가 목록 맨 위로
            ..sort((a, b) {
              if (a.isBase != b.isBase) return a.isBase ? -1 : 1;
              return a.name.compareTo(b.name);
            });
      notifyListeners();
    }, onError: (e) {
      debugPrint('사이트 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), _listen);
    });
  }

  void _listenPhotoOrder() {
    _photoOrderSub = _db
        .collection('club_config')
        .doc('site_photos')
        .snapshots()
        .listen((doc) {
      _photoOrder = {
        for (final e in (doc.data() ?? {}).entries)
          if (e.value is List)
            e.key: [for (final u in e.value as List) u.toString()],
      };
      notifyListeners();
    }, onError: (e) {
      debugPrint('사진 순서 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), _listenPhotoOrder);
    });
  }

  /// 저장된 순서를 적용한 사진 목록.
  /// 저장 목록에 없는 새 사진은 뒤에 붙고, 삭제된 사진은 걸러진다.
  List<String> orderedPhotos(String key, List<String> defaults) {
    final saved = _photoOrder[key];
    if (saved == null) return defaults;
    final result = [
      for (final u in saved)
        if (defaults.contains(u)) u,
    ];
    for (final u in defaults) {
      if (!result.contains(u)) result.add(u);
    }
    return result;
  }

  /// 💡 관리자 드래그 재정렬 결과 저장
  Future<void> savePhotoOrder(String key, List<String> urls) async {
    await _db
        .collection('club_config')
        .doc('site_photos')
        .set({key: urls}, SetOptions(merge: true));
  }

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    _sub?.cancel();
    _photoOrderSub?.cancel();
    _listen();
    _listenPhotoOrder();
  }

  Future<void> addSite(DiveSite site) async {
    await _db.collection('dive_sites').add(site.toMap());
  }

  Future<void> updateSite(DiveSite site) async {
    await _db
        .collection('dive_sites')
        .doc(site.id)
        .set(site.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteSite(String id) async {
    await _db.collection('dive_sites').doc(id).delete();
  }

  /// 💡 위치 조정 모드: 마커 드래그 결과 저장
  Future<void> moveSite(String id, double lat, double lng) async {
    await _db
        .collection('dive_sites')
        .doc(id)
        .set({'lat': lat, 'lng': lng}, SetOptions(merge: true));
  }

  /// 💡 세부 포인트 마커 드래그 결과 저장 (해당 항목에 실좌표 기록)
  Future<void> moveSubPoint(
      DiveSite site, int index, double lat, double lng) async {
    if (index < 0 || index >= site.subPoints.length) return;
    final list = [
      for (final sp in site.subPoints) Map<String, String>.from(sp),
    ];
    list[index]['lat'] = lat.toString();
    list[index]['lng'] = lng.toString();
    await _db
        .collection('dive_sites')
        .doc(site.id)
        .set({'subPoints': list}, SetOptions(merge: true));
  }
}
