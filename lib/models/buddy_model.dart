/// 다이빙 버디 편성.
/// 계층: BuddyDay(일차)가 팀 풀(teams)을 소유하고,
/// 조(blocks)와 입수 순서(rounds)는 팀을 ID로 참조한다.
/// 편성 순서: 팀 만들기 → 조에 팀 배정 → 입수 순서 → 사람 배치.
class BuddyDay {
  final String id; // 일차 ID (schedule의 id와 매칭)
  final String title;

  /// 일차 유형: 'beach'(비치) | 'boating'(보팅) | ''(미지정)
  String type;

  /// 팀 풀 — 팀의 유일한 원본. 조/회차는 여기의 id만 참조한다.
  final List<BuddyTeam> teams;

  final List<BuddyBlock> blocks;
  final List<BuddyRound> rounds;

  BuddyDay({
    required this.id,
    required this.title,
    required this.teams,
    required this.blocks,
    required this.rounds,
    this.type = '',
  });

  BuddyTeam? teamById(String teamId) {
    for (final t in teams) {
      if (t.id == teamId) return t;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'teams': teams.map((t) => t.toMap()).toList(),
      'blocks': blocks.map((b) => b.toMap()).toList(),
      'rounds': rounds.map((r) => r.toMap()).toList(),
    };
  }

  factory BuddyDay.fromMap(String id, Map<String, dynamic> map) {
    final rounds = (map['rounds'] as List? ?? [])
        .map((r) => BuddyRound.fromMap(Map<String, dynamic>.from(r)))
        .toList();

    // v3 형식: 일차 레벨 팀 풀
    if (map['teams'] is List) {
      return BuddyDay(
        id: id,
        title: map['title'] ?? '',
        type: map['type'] ?? '',
        teams: (map['teams'] as List)
            .map((t) => BuddyTeam.fromMap(Map<String, dynamic>.from(t)))
            .toList(),
        blocks: (map['blocks'] as List? ?? [])
            .map((b) => BuddyBlock.fromMap(Map<String, dynamic>.from(b)))
            .toList(),
        rounds: rounds,
      );
    }

    // 💡 v2 호환: 팀이 조 안에 중첩된 형식 → 팀을 풀로 끌어올린다
    if (map['blocks'] is List) {
      final teams = <BuddyTeam>[];
      final blocks = <BuddyBlock>[];
      for (final raw in map['blocks'] as List) {
        final blockMap = Map<String, dynamic>.from(raw);
        final teamIds = <String>[];
        for (final rawTeam in blockMap['teams'] as List? ?? []) {
          final team = BuddyTeam.fromMap(Map<String, dynamic>.from(rawTeam));
          teams.add(team);
          teamIds.add(team.id);
        }
        blocks.add(BuddyBlock(name: blockMap['name'] ?? '', teamIds: teamIds));
      }
      return BuddyDay(
        id: id,
        title: map['title'] ?? '',
        type: map['type'] ?? '',
        teams: teams,
        blocks: blocks,
        rounds: rounds,
      );
    }

    // 💡 v1 호환: tanks(1탱크/2탱크 × A/B팀).
    //    v1의 탱크는 '한 회차'였으므로 조 + 회차(두 팀 동시 입수)로 변환한다.
    final tanks = map['tanks'] as List? ?? [];
    final teams = <BuddyTeam>[];
    final blocks = <BuddyBlock>[];
    final v1Rounds = <BuddyRound>[];

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
      teams.addAll([teamA, teamB]);
      blocks.add(BuddyBlock(name: tankName, teamIds: [teamA.id, teamB.id]));
      v1Rounds.add(BuddyRound(name: tankName, teamIds: [teamA.id, teamB.id]));
    }

    return BuddyDay(
      id: id,
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      teams: teams,
      blocks: blocks,
      rounds: v1Rounds,
    );
  }
}

/// 조(블록): 팀들을 묶는 구성 단위. 예: YB, 교육팀. 팀은 ID로 참조한다.
class BuddyBlock {
  String name;
  List<String> teamIds;

  BuddyBlock({required this.name, required this.teamIds});

  Map<String, dynamic> toMap() => {'name': name, 'teamIds': teamIds};

  factory BuddyBlock.fromMap(Map<String, dynamic> map) => BuddyBlock(
        name: map['name'] ?? '',
        teamIds: List<String>.from(map['teamIds'] ?? []),
      );
}

class BuddyTeam {
  /// 조/회차가 참조하는 고유 ID. 팀 이름을 바꿔도 참조가 유지된다.
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
/// 이름은 자유(오전, 오후, 1탱크…)이고 중복도 허용된다.
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
