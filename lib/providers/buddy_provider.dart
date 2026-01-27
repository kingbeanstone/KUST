import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/buddy_model.dart';

class BuddyProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<BuddyDay> _buddyDays = [];

  List<BuddyDay> get buddyDays => _buddyDays;

  BuddyProvider() {
    _listenToBuddies();
  }

  void _listenToBuddies() {
    _db.collection('buddy_system').snapshots().listen((snapshot) {
      _buddyDays = snapshot.docs
          .map((doc) => BuddyDay.fromMap(doc.id, doc.data()))
          .toList();
      notifyListeners();
    });
  }

  // 특정 일차의 데이터 가져오기 (없으면 초기 객체 생성)
  BuddyDay getDayOrDefault(String dayId, String title) {
    return _buddyDays.firstWhere(
          (d) => d.id == dayId,
      orElse: () => BuddyDay(
        id: dayId,
        title: title,
        tanks: [
          BuddyTank(
            tankName: '1탱크',
            teamA: BuddyTeam(leader: '', members: List.filled(7, '')),
            teamB: BuddyTeam(leader: '', members: List.filled(7, '')),
          ),
          BuddyTank(
            tankName: '2탱크',
            teamA: BuddyTeam(leader: '', members: List.filled(7, '')),
            teamB: BuddyTeam(leader: '', members: List.filled(7, '')),
          ),
        ],
      ),
    );
  }

  Future<void> saveBuddyDay(BuddyDay day) async {
    await _db.collection('buddy_system').doc(day.id).set(day.toMap());
  }
}