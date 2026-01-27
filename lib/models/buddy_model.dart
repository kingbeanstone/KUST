class BuddyDay {
  final String id; // 일차 ID (schedule의 id와 매칭)
  final String title; // 예: 1일차-동파
  final List<BuddyTank> tanks;

  BuddyDay({required this.id, required this.title, required this.tanks});

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'tanks': tanks.map((t) => t.toMap()).toList(),
    };
  }

  factory BuddyDay.fromMap(String id, Map<String, dynamic> map) {
    return BuddyDay(
      id: id,
      title: map['title'] ?? '',
      tanks: (map['tanks'] as List? ?? [])
          .map((t) => BuddyTank.fromMap(t))
          .toList(),
    );
  }
}

class BuddyTank {
  final String tankName; // 1탱크, 2탱크
  final BuddyTeam teamA;
  final BuddyTeam teamB;

  BuddyTank({required this.tankName, required this.teamA, required this.teamB});

  Map<String, dynamic> toMap() => {
    'tankName': tankName,
    'teamA': teamA.toMap(),
    'teamB': teamB.toMap(),
  };

  factory BuddyTank.fromMap(Map<String, dynamic> map) => BuddyTank(
    tankName: map['tankName'] ?? '',
    teamA: BuddyTeam.fromMap(map['teamA'] ?? {}),
    teamB: BuddyTeam.fromMap(map['teamB'] ?? {}),
  );
}

class BuddyTeam {
  final String leader;
  final List<String> members; // 최대 6~8명

  BuddyTeam({required this.leader, required this.members});

  Map<String, dynamic> toMap() => {
    'leader': leader,
    'members': members,
  };

  factory BuddyTeam.fromMap(Map<String, dynamic> map) => BuddyTeam(
    leader: map['leader'] ?? '',
    members: List<String>.from(map['members'] ?? []),
  );
}