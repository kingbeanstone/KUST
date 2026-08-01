/// 다이빙 버디 편성.
/// 계층: BuddyDay(일차) > BuddyBlock(조: 팀 묶음) + BuddyRound(입수 순서).
///  - 팀 구성(누가 어느 팀인가)과 입수 순서(어느 회차에 어느 팀이 들어가는가)를 분리한다.
///  - 같은 팀을 여러 회차에 넣을 수 있어 (AB)(AB), AA BB 등 어떤 패턴도 표현 가능.
class BuddyDay {
  final String id; // 일차 ID (schedule의 id와 매칭)
  final String title;

  /// 일차 유형: 'beach'(비치) | 'boating'(보팅) | ''(미지정)
  String type;

  final List<BuddyBlock> blocks;
  final List<BuddyRound> rounds;

  BuddyDay({
    required this.id,
    required this.title,
    required this.blocks,
    required this.rounds,
    this.type = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'blocks': blocks.map((b) => b.toMap()).toList(),
      'rounds': rounds.map((r) => r.toMap()).toList(),
    };
  }

  factory BuddyDay.fromMap(String id, Map<String, dynamic> map) {
    // v2 형식 (blocks)
    if (map['blocks'] is List) {
      return BuddyDay(
        id: id,
        title: map['title'] ?? '',
        type: map['type'] ?? '',
        blocks: (map['blocks'] as List)
            .map((b) => BuddyBlock.fromMap(Map<String, dynamic>.from(b)))
            .toList(),
        rounds: (map['rounds'] as List? ?? [])
            .map((r) => BuddyRound.fromMap(Map<String, dynamic>.from(r)))
            .toList(),
      );
    }

    // 💡 v1 호환: tanks(1탱크/2탱크 × A/B팀)를 변환해서 읽는다.
    //    v1의 탱크는 '한 회차'였으므로, 블록 하나 + 회차(두 팀 동시 입수)로 만든다.
    final tanks = map['tanks'] as List? ?? [];
    final blocks = <BuddyBlock>[];
    final rounds = <BuddyRound>[];

    for (var i = 0; i < tanks.length; i++) {
      final tankMap = Map<String, dynamic>.from(tanks[i]);
      final tankName =
          (tankMap['tankName'] ?? '').toString().isEmpty ? '${i + 1}탱크' : tankMap['tankName'] as String;

      BuddyTeam teamFrom(String key, String suffix) {
        final m = Map<String, dynamic>.from(tankMap[key] ?? {});
        return BuddyTeam(
          id: 'v1_${i}_$suffix',
          name: '$suffix팀',
          leader: m['leader'] ?? '',
          members: List<String>.from(m['members'] ?? []),
        );
      }

      final teamA = teamFrom('teamA', 'A');
      final teamB = teamFrom('teamB', 'B');
      blocks.add(BuddyBlock(name: tankName, teams: [teamA, teamB]));
      rounds.add(BuddyRound(name: tankName, teamIds: [teamA.id, teamB.id]));
    }

    return BuddyDay(
      id: id,
      title: map['title'] ?? '',
      blocks: blocks,
      rounds: rounds,
    );
  }
}

/// 조(블록): 팀들을 묶는 구성 단위. 예: YB, 교육 1조. (시간 의미 없음)
class BuddyBlock {
  String name;
  List<BuddyTeam> teams;

  BuddyBlock({required this.name, required this.teams});

  Map<String, dynamic> toMap() => {
        'name': name,
        'teams': teams.map((t) => t.toMap()).toList(),
      };

  factory BuddyBlock.fromMap(Map<String, dynamic> map) => BuddyBlock(
        name: map['name'] ?? '',
        teams: (map['teams'] as List? ?? [])
            .map((t) => BuddyTeam.fromMap(Map<String, dynamic>.from(t)))
            .toList(),
      );
}

class BuddyTeam {
  /// 회차(rounds)가 참조하는 고유 ID. 팀 이름을 바꿔도 참조가 유지된다.
  final String id;
  String name;
  String leader; // 강사/리더 (없으면 '')
  List<String> members;

  BuddyTeam({
    required this.id,
    required this.name,
    required this.leader,
    required this.members,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'leader': leader,
        'members': members,
      };

  static int _fallbackSeq = 0;

  factory BuddyTeam.fromMap(Map<String, dynamic> map) => BuddyTeam(
        // 구버전 문서에 id가 없으면 임시 생성 — 다음 저장 때 영구화된다
        id: (map['id'] ?? '').toString().isEmpty
            ? 'team_${DateTime.now().microsecondsSinceEpoch}_${_fallbackSeq++}'
            : map['id'] as String,
        name: map['name'] ?? '',
        leader: map['leader'] ?? '',
        members: List<String>.from(map['members'] ?? []),
      );
}

/// 회차(입수 순서 한 줄): 이 회차에 함께 물에 들어가는 팀들.
/// 이름은 자유(1탱크, 2탱크…)이고 중복도 허용된다.
class BuddyRound {
  String name;
  List<String> teamIds;

  BuddyRound({required this.name, required this.teamIds});

  Map<String, dynamic> toMap() => {'name': name, 'teamIds': teamIds};

  factory BuddyRound.fromMap(Map<String, dynamic> map) => BuddyRound(
        name: map['name'] ?? '',
        teamIds: List<String>.from(map['teamIds'] ?? []),
      );
}
