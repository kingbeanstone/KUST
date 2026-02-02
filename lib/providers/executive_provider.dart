import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/executive_model.dart';

class ExecutiveProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<ExecutiveItem> _executives = [];
  List<ExecutiveItem> get executives => _executives;

  bool _isAdmin = false;

  ExecutiveProvider() {
    _listenToExecutives();
  }

  void setAdminStatus(bool isAdmin) {
    _isAdmin = isAdmin;
    notifyListeners();
  }

  void _listenToExecutives() {
    _db.collection('executives').snapshots().listen((snapshot) {
      _executives = snapshot.docs.map((doc) => ExecutiveItem.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  Future<void> addExecutive(ExecutiveItem item) async {
    if (!_isAdmin) return;
    await _db.collection('executives').add(item.toMap());
  }

  Future<void> updateExecutive(ExecutiveItem item) async {
    if (!_isAdmin) return;
    await _db.collection('executives').doc(item.id).update(item.toMap());
  }

  Future<void> deleteExecutive(String id) async {
    if (!_isAdmin) return;
    await _db.collection('executives').doc(id).delete();
  }
}