import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expedition_model.dart';

/// 💡 원정(시즌) 목록과 "현재 선택된 원정"을 관리한다.
/// 데이터 provider들(장비/버디/일정/식단)은 main.dart의 ProxyProvider를 통해
/// 여기의 selectedId를 따라 구독 경로를 갈아탄다.
class ExpeditionProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _prefsKey = 'selectedExpeditionId';

  List<Expedition> _expeditions = [];
  String? _selectedId;
  String? _savedId; // prefs에 저장돼 있던 선택
  bool _loaded = false;

  List<Expedition> get expeditions => _expeditions;
  String? get selectedId => _selectedId;

  Expedition? get selected {
    final id = _selectedId;
    if (id == null) return null;

    // id 형식이 {year}_{season} 이면 목록 없이도 바로 파생한다.
    // (조합 선택 직후 스냅샷 도착 전에도 라벨/하이라이트가 즉시 반영되도록)
    final parts = id.split('_');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      if (year != null && Expedition.seasonLabels.containsKey(parts[1])) {
        return Expedition(id: id, year: year, season: parts[1]);
      }
    }

    for (final e in _expeditions) {
      if (e.id == id) return e;
    }
    return null;
  }

  ExpeditionProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedId = prefs.getString(_prefsKey);
    } catch (_) {}

    _db.collection('expeditions').snapshots().listen((snapshot) {
      _expeditions = snapshot.docs
          .map((doc) => Expedition.fromMap(doc.id, doc.data()))
          .toList()
        // 최신 원정이 앞으로 (연도 → 시즌 역순)
        ..sort((a, b) => b.sortKey.compareTo(a.sortKey));

      // 저장된 선택이 유효하면 그걸, 아니면 최신 원정을 기본 선택
      if (!_loaded || selected == null) {
        _loaded = true;
        final saved = _expeditions.where((e) => e.id == _savedId);
        _selectedId = saved.isNotEmpty
            ? saved.first.id
            : (_expeditions.isNotEmpty ? _expeditions.first.id : null);
      }
      notifyListeners();
    });
  }

  Future<void> select(String id) async {
    if (_selectedId == id) return;
    _selectedId = id;
    _savedId = id;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, id);
    } catch (_) {}
  }

  /// 새 원정 생성. 이미 있으면 그 원정을 선택만 한다.
  Future<void> createExpedition(int year, String season) async {
    final id = '${year}_$season';
    final expedition = Expedition(id: id, year: year, season: season);
    await _db.collection('expeditions').doc(id).set(expedition.toMap(), SetOptions(merge: true));
    await select(id);
  }

  /// 💡 v1 시절 최상위 컬렉션에 쌓인 데이터(25 동계)를
  /// expeditions/{id}/ 서브컬렉션으로 복사한다. 원본은 백업으로 남긴다.
  Future<String> migrateLegacyData({required int year, required String season}) async {
    final id = '${year}_$season';
    final expRef = _db.collection('expeditions').doc(id);

    await expRef.set({'year': year, 'season': season}, SetOptions(merge: true));

    Future<int> copyCollection(String name) async {
      final snapshot = await _db.collection(name).get();
      var batch = _db.batch();
      var count = 0;
      for (final doc in snapshot.docs) {
        batch.set(expRef.collection(name).doc(doc.id), doc.data());
        count++;
        if (count % 400 == 0) {
          await batch.commit();
          batch = _db.batch();
        }
      }
      await batch.commit();
      return snapshot.docs.length;
    }

    final members = await copyCollection('members');
    final buddies = await copyCollection('buddy_system');
    final schedules = await copyCollection('schedules');
    final meals = await copyCollection('meals');

    // config는 필요한 문서만 골라 복사
    for (final docId in ['equipment_groups', 'meal_tabs', 'schedule_tabs']) {
      final doc = await _db.collection('config').doc(docId).get();
      if (doc.exists && doc.data() != null) {
        await expRef.collection('config').doc(docId).set(doc.data()!);
      }
    }

    await select(id);
    return '장비 $members명 · 버디 $buddies일 · 일정 $schedules건 · 식단 $meals건 이사 완료';
  }
}
