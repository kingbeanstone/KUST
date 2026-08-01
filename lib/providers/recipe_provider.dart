import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe_model.dart';

/// 💡 동아리 공용 레시피북. 원정과 무관한 최상위 'recipes' 컬렉션.
class RecipeProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Recipe> _recipes = [];
  List<Recipe> get recipes => _recipes;

  StreamSubscription? _sub;

  RecipeProvider() {
    _listen();
  }

  void _listen() {
    _sub = _db.collection('recipes').orderBy('name').snapshots().listen((snapshot) {
      _recipes =
          snapshot.docs.map((d) => Recipe.fromMap(d.id, d.data())).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('레시피 스트림 오류: $e — 재연결 예약');
      Future.delayed(const Duration(seconds: 3), _listen);
    });
  }

  /// 앱 복귀 시 끊겼을 수 있는 실시간 연결 복구
  void resubscribe() {
    _sub?.cancel();
    _listen();
  }

  /// 식단 칸 텍스트에서 이름이 등장하는 레시피들
  List<Recipe> matchesIn(String mealText) {
    if (mealText.trim().isEmpty) return [];
    return _recipes
        .where((r) => r.name.isNotEmpty && mealText.contains(r.name))
        .toList();
  }

  Future<void> addRecipe(String name, String ingredients, String steps) async {
    await _db.collection('recipes').add({
      'name': name.trim(),
      'ingredients': ingredients,
      'steps': steps,
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
