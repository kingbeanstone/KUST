import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe_model.dart';

/// 💡 동아리 공용 레시피북. 원정과 무관한 최상위 'recipes' 컬렉션.
class RecipeProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Recipe> _recipes = [];
  List<Recipe> get recipes => _recipes;

  /// 사용자가 정한 카테고리 순서 (club_config/recipes 문서)
  List<String> _categoryOrder = [];

  StreamSubscription? _sub;
  StreamSubscription? _configSub;

  RecipeProvider() {
    _listen();
    _listenConfig();
  }

  void _listen() {
    _sub = _db.collection('recipes').orderBy('name').snapshots().listen((snapshot) {
      _recipes =
          snapshot.docs.map((d) => Recipe.fromMap(d.id, d.data())).toList()
            ..sort((a, b) {
              final d = a.order.compareTo(b.order);
              return d != 0 ? d : a.name.compareTo(b.name);
            });
      notifyListeners();
    }, onError: (e) {
      debugPrint('레시피 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), _listen);
    });
  }

  void _listenConfig() {
    _configSub =
        _db.collection('club_config').doc('recipes').snapshots().listen((doc) {
      _categoryOrder =
          List<String>.from(doc.data()?['categoryOrder'] as List? ?? []);
      notifyListeners();
    }, onError: (e) {
      debugPrint('레시피 설정 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), _listenConfig);
    });
  }

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    _sub?.cancel();
    _configSub?.cancel();
    _listen();
    _listenConfig();
  }

  /// 카테고리 순서 저장 (드래그 정렬 결과)
  Future<void> saveCategoryOrder(List<String> order) async {
    await _db
        .collection('club_config')
        .doc('recipes')
        .set({'categoryOrder': order}, SetOptions(merge: true));
  }

  /// 카테고리 안 메뉴 순서 저장 (드래그 정렬 결과)
  Future<void> saveRecipeOrder(List<Recipe> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_db.collection('recipes').doc(ordered[i].id), {'order': i});
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
  /// 순서: 사용자 지정(club_config) → 기본 목록 → 가나다순, 미지정은 맨 뒤.
  Map<String, List<Recipe>> get byCategory {
    final map = <String, List<Recipe>>{};
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
      String name, String category, String ingredients, String steps) async {
    await _db.collection('recipes').add({
      'name': name.trim(),
      'category': category.trim(),
      'ingredients': ingredients,
      'steps': steps,
      // 새 메뉴는 카테고리 맨 뒤에 (시간값이라 기존 정렬 인덱스보다 항상 큼)
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _db.collection('recipes').doc(recipe.id).set(
          recipe.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteRecipe(String id) async {
    await _db.collection('recipes').doc(id).delete();
  }
}
