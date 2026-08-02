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

  StreamSubscription? _sub;

  DiveSiteProvider() {
    _listen();
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

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    _sub?.cancel();
    _listen();
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
}
