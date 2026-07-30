/// 다이빙 버디 편성.
/// 계층: BuddyDay(일차) > BuddyBlock(조: YB·교육1조 등) > BuddyTeam(팀) > 대원 이름.
class BuddyDay {
  final String id; // 일차 ID (schedule의 id와 매칭)
  final String title;
  final List<BuddyBlock> blocks;

  BuddyDay({required this.id, required this.title, required this.blocks});

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'blocks': blocks.map((b) => b.toMap()).toList(),
    };
  }

  factory BuddyDay.fromMap(String id, Map<String, dynamic> map) {
    // v2 형식 (blocks)
    if (map['blocks'] is List) {
      return BuddyDay(
        id: id,
        title: map['title'] ?? '',
        blocks: (map['blocks'] as List)
            .map((b) => BuddyBlock.fromMap(Map<String, dynamic>.from(b)))
            .toList(),
      );
    }

    // 💡 v1 호환: tanks(1탱크/2탱크 × A/B팀)를 블록으로 변환해서 읽는다.
    //    v1에서는 한 탱크의 A/B가 같은 회차에 입수했으므로 '동시 입수'로 본다.
    final tanks = map['tanks'] as List? ?? [];
    return BuddyDay(
      id: id,
      title: map['title'] ?? '',
      blocks: tanks.map((t) {
        final tankMap = Map<String, dynamic>.from(t);

        BuddyTeam teamFrom(String key, String name) {
          final m = Map<String, dynamic>.from(tankMap[key] ?? {});
          return BuddyTeam(
            name: name,
            leader: m['leader'] ?? '',
            members: List<String>.from(m['members'] ?? []),
          );
        }

        return BuddyBlock(
          name: tankMap['tankName'] ?? '',
          simultaneous: true,
          teams: [teamFrom('teamA', 'A팀'), teamFrom('teamB', 'B팀')],
        );
      }).toList(),
    );
  }
}

/// 조(블록): 같은 편성 단위로 묶이는 팀들. 예: YB, 교육 1조.
class BuddyBlock {
  String name;

  /// 💡 그날 이 조의 입수 방식.
  ///  - true  = 동시 입수: 조의 팀들이 같은 회차에 함께 들어간다 → 장비버디는 조 전체에서 금지
  ///  - false = 로테이션: 팀별로 시간대가 다르다 → 장비버디는 같은 팀 안에서만 금지
  bool simultaneous;

  List<BuddyTeam> teams;

  BuddyBlock({required this.name, required this.simultaneous, required this.teams});

  Map<String, dynamic> toMap() => {
        'name': name,
        'simultaneous': simultaneous,
        'teams': teams.map((t) => t.toMap()).toList(),
      };

  factory BuddyBlock.fromMap(Map<String, dynamic> map) => BuddyBlock(
        name: map['name'] ?? '',
        simultaneous: map['simultaneous'] == true,
        teams: (map['teams'] as List? ?? [])
            .map((t) => BuddyTeam.fromMap(Map<String, dynamic>.from(t)))
            .toList(),
      );
}

class BuddyTeam {
  String name;
  String leader; // 강사/리더 (없으면 '')
  List<String> members;

  BuddyTeam({required this.name, required this.leader, required this.members});

  Map<String, dynamic> toMap() => {
        'name': name,
        'leader': leader,
        'members': members,
      };

  factory BuddyTeam.fromMap(Map<String, dynamic> map) => BuddyTeam(
        name: map['name'] ?? '',
        leader: map['leader'] ?? '',
        members: List<String>.from(map['members'] ?? []),
      );
}
