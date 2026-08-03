import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe_model.dart';

/// 💡 원정별 식단(레시피) — expeditions/{id}/recipes.
/// 카테고리 순서는 expeditions/{id}/config/recipes 문서에 저장한다.
/// (v2.14까지는 최상위 'recipes' 공용 컬렉션이었음 — backups/ 폴더에 백업 보존)
class RecipeProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _expeditionId;
  StreamSubscription? _sub;
  StreamSubscription? _configSub;

  List<Recipe> _recipes = [];
  List<Recipe> get recipes => _recipes;

  /// 사용자가 정한 카테고리 순서 (expeditions/{id}/config/recipes 문서)
  List<String> _categoryOrder = [];

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('expeditions').doc(_expeditionId!).collection('recipes');

  DocumentReference<Map<String, dynamic>> get _configDoc => _db
      .collection('expeditions')
      .doc(_expeditionId!)
      .collection('config')
      .doc('recipes');

  /// ExpeditionProvider(ProxyProvider)가 호출. 원정 전환 시 구독을 갈아탄다.
  void setExpedition(String? expeditionId) {
    if (_expeditionId == expeditionId) return;
    _expeditionId = expeditionId;

    _sub?.cancel();
    _sub = null;
    _configSub?.cancel();
    _configSub = null;
    _recipes = [];
    _categoryOrder = [];
    notifyListeners();

    if (expeditionId == null) return;
    _listen();
    _listenConfig();
  }

  void _listen() {
    final expId = _expeditionId;
    _sub = _col.orderBy('name').snapshots().listen((snapshot) {
      _recipes =
          snapshot.docs.map((d) => Recipe.fromMap(d.id, d.data())).toList()
            ..sort((a, b) {
              final d = a.order.compareTo(b.order);
              return d != 0 ? d : a.name.compareTo(b.name);
            });
      notifyListeners();
    }, onError: (e) {
      debugPrint('레시피 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), () {
        if (_expeditionId == expId && expId != null) _listen();
      });
    });
  }

  void _listenConfig() {
    final expId = _expeditionId;
    _configSub = _configDoc.snapshots().listen((doc) {
      _categoryOrder =
          List<String>.from(doc.data()?['categoryOrder'] as List? ?? []);
      notifyListeners();
    }, onError: (e) {
      debugPrint('레시피 설정 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), () {
        if (_expeditionId == expId && expId != null) _listenConfig();
      });
    });
  }

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    if (_expeditionId == null) return;
    _sub?.cancel();
    _configSub?.cancel();
    _listen();
    _listenConfig();
  }

  /// 카테고리 순서 저장 (드래그 정렬 결과)
  Future<void> saveCategoryOrder(List<String> order) async {
    if (_expeditionId == null) return;
    await _configDoc.set({'categoryOrder': order}, SetOptions(merge: true));
  }

  /// 💡 드래그 드롭: 레시피를 다른 카테고리로 이동 (대상 카테고리 맨 뒤로)
  Future<void> moveRecipeToCategory(Recipe recipe, String category) async {
    if (_expeditionId == null) return;
    await _col.doc(recipe.id).set({
      'category': category == '미지정' ? '' : category,
      'order': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  /// 카테고리 이름 변경: 소속 레시피 전체 + 순서 목록에 반영
  Future<void> renameCategory(String from, String to) async {
    if (_expeditionId == null) return;
    final target = to.trim();
    if (target.isEmpty || target == from) return;

    final batch = _db.batch();
    for (final r in _recipes) {
      final cat = r.category.isEmpty ? '미지정' : r.category;
      if (cat == from) {
        batch.update(_col.doc(r.id), {'category': target});
      }
    }
    await batch.commit();

    final newOrder = [
      for (final c in _categoryOrder) c == from ? target : c,
    ];
    await saveCategoryOrder(newOrder);
  }

  /// 카테고리 안 메뉴 순서 저장 (드래그 정렬 결과)
  Future<void> saveRecipeOrder(List<Recipe> ordered) async {
    if (_expeditionId == null) return;
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_col.doc(ordered[i].id), {'order': i});
    }
    await batch.commit();
  }

  /// 식단 칸 텍스트에서 이름이 등장하는 레시피들
  List<Recipe> matchesIn(String mealText) {
    if (mealText.trim().isEmpty) return [];
    return _recipes
        .where((r) => r.name.isNotEmpty && mealText.contains(r.name))
        .toList();
  }

  /// 기본 카테고리 순서 (사용자 지정 순서가 없을 때의 폴백)
  static const List<String> kCategoryOrder = [
    '밥·면', '메인', '국·사이드', '야식·안주', '과일·디저트',
  ];

  /// 카테고리 → 레시피 목록.
  /// 순서: 사용자 지정(config) → 기본 목록 → 가나다순, 미지정은 맨 뒤.
  /// 💡 순서 목록에 있는 카테고리는 비어 있어도 포함된다 (드래그 드롭 대상용).
  Map<String, List<Recipe>> get byCategory {
    final map = <String, List<Recipe>>{};
    for (final c in _categoryOrder) {
      if (c.trim().isNotEmpty) map.putIfAbsent(c, () => []);
    }
    for (final r in _recipes) {
      map.putIfAbsent(r.category.isEmpty ? '미지정' : r.category, () => []).add(r);
    }
    int rank(String c) {
      if (c == '미지정') return 99999;
      final saved = _categoryOrder.indexOf(c);
      if (saved >= 0) return saved;
      final basic = kCategoryOrder.indexOf(c);
      return basic >= 0 ? 1000 + basic : 2000;
    }

    final keys = map.keys.toList()
      ..sort((a, b) {
        final d = rank(a).compareTo(rank(b));
        return d != 0 ? d : a.compareTo(b);
      });
    return {for (final k in keys) k: map[k]!};
  }

  /// 등록된 카테고리 목록 (선택 칩용, 미지정 제외)
  List<String> get categories =>
      byCategory.keys.where((c) => c != '미지정').toList();

  Future<void> addRecipe(
      String name, String category, String ingredients, String steps,
      {String slot = ''}) async {
    if (_expeditionId == null) return;
    await _col.add({
      'name': name.trim(),
      'category': category.trim(),
      'ingredients': ingredients,
      'steps': steps,
      'slot': slot,
      // 새 메뉴는 카테고리 맨 뒤에 (시간값이라 기존 정렬 인덱스보다 항상 큼)
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 💡 편집 취소: 스냅샷 시점으로 전체 복원.
  /// 변경된 메뉴는 되돌리고, 편집 중 생긴 메뉴는 지우고, 지운 메뉴는 되살린다.
  Future<void> restoreRecipesSnapshot(List<Recipe> snapshot) async {
    if (_expeditionId == null) return;
    final batch = _db.batch();
    final snapIds = <String>{};
    for (final r in snapshot) {
      snapIds.add(r.id);
      batch.set(_col.doc(r.id), r.toMap());
    }
    for (final r in _recipes) {
      if (!snapIds.contains(r.id)) {
        batch.delete(_col.doc(r.id));
      }
    }
    await batch.commit();
  }

  /// 💡 식단표 드래그 드롭: 메뉴를 (일차, 끼니) 칸으로 이동
  Future<void> moveRecipe(Recipe recipe, String category, String slot) async {
    if (_expeditionId == null) return;
    await _col.doc(recipe.id).set({
      'category': category,
      'slot': slot,
      'order': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  Future<void> updateRecipe(Recipe recipe) async {
    if (_expeditionId == null) return;
    await _col.doc(recipe.id).set(
          recipe.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteRecipe(String id) async {
    if (_expeditionId == null) return;
    await _col.doc(id).delete();
  }
}
