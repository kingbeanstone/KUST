import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/member_provider.dart';
import '../providers/participant_provider.dart';
import '../util/game_audio.dart';

/// 주루마블 칸 하나: (이모지, 짧은 라벨, 자세한 설명, 종류)
/// 종류: drink(마시기) / game(게임) / mission(미션) / move(이동) / chance(찬스)
class _Tile {
  final String emoji;
  final String label;
  final String desc;
  final String type;
  final int move; // 이동 칸 수 (move 타입: +앞으로/-뒤로, -99 = 처음으로)

  const _Tile(this.emoji, this.label, this.desc, this.type, {this.move = 0});
}

/// 💡 주루마블: 폰 하나를 가운데 두고 1팀 vs 2팀으로 즐기는 술게임 보드.
/// 모든 미션은 팀 단위 — 팀원이 돌아가면서 주사위를 굴린다.
class JurumarbleScreen extends StatefulWidget {
  const JurumarbleScreen({super.key});

  @override
  State<JurumarbleScreen> createState() => _JurumarbleScreenState();
}

class _JurumarbleScreenState extends State<JurumarbleScreen> {
  // 💡 5x9 보드 = 24칸, 시계방향. 미션은 전부 팀 단위!
  static const List<_Tile> _tiles = [
    _Tile('🚩', '시작', '한 바퀴 완주! 굴린 팀이 상대 팀에게 단체 건배를 제의하세요.', 'chance'),
    _Tile('🍺', '상대 팀\n한 잔', '상대 팀 전원 한 잔!', 'drink'),
    _Tile('👀', '눈치\n게임', '전원 눈치게임! 걸린 사람이 속한 팀 전원 한 잔.', 'game'),
    _Tile('📣', '건배사', '굴린 팀이 다같이 건배사 외치기! 그리고 전원 한 모금.', 'mission'),
    _Tile('⏩', '앞으로\n3칸', '기세를 몰아 앞으로 3칸 전진!', 'move', move: 3),
    _Tile('🤢', '소주\n가글', '굴린 팀 전원이 소주 한 잔으로 가글! (삼킬지는 각자 선택)', 'drink'),
    _Tile('3️⃣1️⃣', '베라\n31', '팀 대항 베스킨라빈스 31! 팀별로 번갈아 외치고, 31 걸린 팀 전원 한 잔.', 'game'),
    _Tile('🔤', '초성\n게임', '상대 팀이 초성 2글자를 제시! (예: ㅂㅇ) 굴린 팀이 10초 안에 단어 3개를 말하면 통과, 실패하면 팀 전원 한 잔.', 'game'),
    _Tile('🍻', '다같이\n건배', '두 팀 모두 잔을 들고 건배! 전원 마십니다.', 'drink'),
    _Tile('✊', '손병호\n게임', '상대 팀 전원 손가락 3개 펴기! 굴린 팀이 "~한 사람 접어!" 질문 3번 공격. 손가락을 다 접은 상대 팀 사람만 한 잔.', 'game'),
    _Tile('🎟', '면제권', '굴린 팀 한 잔 면제권 획득! 아껴뒀다 쓰세요.', 'chance'),
    _Tile('🎲', '랜덤\n손병호', '질문 하나가 랜덤으로 나옵니다!', 'sonbyeongho'),
    _Tile('⏪', '뒤로\n2칸', '아쉽지만 뒤로 2칸 후진...', 'move', move: -2),
    _Tile('🔗', '릴레이\n원샷', '굴린 팀 전원이 순서대로 끊기지 않게 릴레이 원샷!', 'drink'),
    _Tile('🍪', '과자\n타임', '굴린 팀 전원 과자 한 개씩 집어먹기! 냠냠 🍪', 'mission'),
    _Tile('💧', '냉수\n한 잔', '굴린 팀 전원 시원한 냉수 한 잔씩! 착한 벌칙, 수분 보충 찬스.', 'chance'),
    _Tile('🥰', '단체\n애교', '굴린 팀 전원 단체 애교! 상대 팀 판정으로 실패하면 전원 한 잔.', 'mission'),
    _Tile('💕', '버디\n러브샷', '굴린 팀 전원, 각자 자기 버디와 러브샷! 버디가 상대 팀에 있어도 무조건 같이 마십니다.', 'drink'),
    _Tile('🕺', '몸으로\n말해요', '상대 팀이 단어 하나 제시! 굴린 팀 전원이 소리 없이 몸으로 표현합니다. 상대 팀이 맞추면 굴린 팀 한 잔, 못 맞추면 상대 팀 한 잔.', 'mission'),
    _Tile('↩️', '처음\n으로', '미끄러졌다! 시작 칸으로 돌아갑니다.', 'move', move: -99),
    _Tile('✌️', '대표\n가위바위보', '각 팀 대표 1명 가위바위보! 진 팀 전원 한 잔.', 'game'),
    _Tile('⚖️', '밸런스\n게임', '상대 팀이 밸런스 질문(A vs B)을 제시! 굴린 팀 전원이 "하나둘셋!"에 동시에 선택하고, 소수 쪽을 고른 사람들이 한 잔.', 'game'),
    _Tile('🍼', '어린 팀\n한 잔', '두 팀 중 평균 나이가 어린 팀 전원 한 잔! (사회의 쓴맛 🥲)', 'drink'),
    _Tile('🍷', '우리 팀\n한 잔', '군말 없이 굴린 팀 전원 한 잔!', 'drink'),
  ];

  /// 💡 랜덤 손병호: 걸리면 이 중 하나가 무작위로 나온다.
  /// (해당되는 사람은 모두 한 잔!)
  static const List<String> _sonbyeonghoQuestions = [
    '안경 쓴 사람 접어',
    '키 160cm 안되는 사람 접어',
    '앞머리 있는 사람 접어',
    '자취하는 사람 접어',
    '나는 사실 지금 취했다 접어',
    '양말 안 신은 사람 접어',
    '검은색 상의 입은 사람 접어',
    '슬리퍼·샌들 신고 온 사람 접어',
    '지금 휴대폰 배터리 50% 아래인 사람 접어',
    '아이폰 쓰는 사람 접어',
    '폰 케이스 없는 사람 접어',
    '카톡 프사가 본인 얼굴인 사람 접어',
    '머리 묶은 사람 접어',
    '생일이 1~6월인 사람 접어',
  ];

  /// 💡 팀 구성 모드: null = 모드 선택 화면, 'basic'/'gender'/'random'
  String? _mode;
  List<String> _teamNames = ['1팀', '2팀'];
  List<Color> _teamColors = const [Color(0xFFFF5252), Color(0xFF448AFF)];

  /// 랜덤/남녀 모드에서 앱이 짜준 팀 명단 (기본 모드는 빈 목록)
  List<List<String>> _rosters = [[], []];

  final List<int> _positions = [0, 0];
  int _current = 0;
  int _dice = 1;
  bool _rolling = false;

  /// 💡 브금·효과음 (자작 칩튠).
  /// _soundOn = 사용자 스위치, _bgmStarted = 실제 재생 여부.
  /// 브라우저가 자동재생을 막아도, 굴리기 버튼(사용자 제스처)에서 반드시 재시작한다.
  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();
  bool _soundOn = true;
  bool _bgmStarted = false;

  @override
  void initState() {
    super.initState();
    _setupAudio();
  }

  Future<void> _setupAudio() async {
    // 💡 효과음이 오디오 포커스를 뺏어 브금을 끊는 것 방지 (안드로이드 기본 동작)
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
    } catch (_) {}
    await _ensureBgm();
  }

  Future<void> _ensureBgm() async {
    if (!_soundOn || _bgmStarted) return;
    try {
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.5);
      await _bgm.play(await gameAudioSource('jurumarble_bgm.wav'));
      _bgmStarted = true;
    } catch (_) {
      // 자동재생 차단 — 다음 사용자 제스처(굴리기/토글) 때 재시도
    }
  }

  /// 어떤 이유로든 브금이 멈췄으면 다시 살린다 (매 턴 종료 시 호출)
  void _reviveBgm() {
    if (!_soundOn) return;
    if (!_bgmStarted) {
      _ensureBgm();
      return;
    }
    _bgm.resume().catchError((_) {});
  }

  Future<void> _toggleSound() async {
    if (_soundOn) {
      setState(() => _soundOn = false);
      await _bgm.pause();
    } else {
      setState(() => _soundOn = true);
      if (_bgmStarted) {
        try {
          await _bgm.resume();
        } catch (_) {
          _bgmStarted = false;
          await _ensureBgm();
        }
      } else {
        await _ensureBgm();
      }
    }
  }

  void _playSfx(String file) {
    if (!_soundOn) return;
    gameAudioSource(file)
        .then((s) => _sfx.play(s, volume: 0.9))
        .catchError((_) {});
  }

  @override
  void dispose() {
    _bgm.dispose();
    _sfx.dispose();
    super.dispose();
  }

  Color _tileColor(String type) {
    switch (type) {
      case 'drink':
        return const Color(0xFFFFE5E8);
      case 'game':
      case 'sonbyeongho':
        return const Color(0xFFDCEDFF);
      case 'mission':
        return const Color(0xFFFFF1DC);
      case 'move':
        return const Color(0xFFEFDFFB);
      default:
        return const Color(0xFFDFF5E3);
    }
  }

  Color _tileBorder(String type) {
    switch (type) {
      case 'drink':
        return const Color(0xFFE57373);
      case 'game':
      case 'sonbyeongho':
        return const Color(0xFF64B5F6);
      case 'mission':
        return const Color(0xFFFFB74D);
      case 'move':
        return const Color(0xFFBA68C8);
      default:
        return const Color(0xFF81C784);
    }
  }

  // ------------------------------------------------------------- 팀 구성

  /// 이번 원정 참가자 (이름, 성별) 목록
  List<(String, String)> _participantList() {
    final members = context.read<MemberProvider>().members;
    final ids = context.read<ParticipantProvider>().participantIds;
    final byId = {for (final m in members) m.id: m};
    return [
      for (final id in ids)
        if (byId[id] != null) (byId[id]!.name, byId[id]!.gender),
    ];
  }

  void _pickMode(String mode) {
    final people = _participantList();
    setState(() {
      _mode = mode;
      _positions[0] = 0;
      _positions[1] = 0;
      _current = 0;
      _dice = 1;

      if (mode == 'gender') {
        _teamNames = ['남자팀', '여자팀'];
        _teamColors = const [Color(0xFF448AFF), Color(0xFFFF4081)];
        // 💡 성별로만 엄격히 구분 (인원수 안 맞춰도 됨).
        //    명단 저장값은 'male'/'female' — 혹시 모를 한글 표기도 허용.
        final men = <String>[];
        final women = <String>[];
        for (final (name, gender) in people) {
          final g = gender.toLowerCase();
          if (g.startsWith('f') || gender.contains('여')) {
            women.add(name);
          } else if (g.startsWith('m') || gender.contains('남')) {
            men.add(name);
          }
          // 성별 미입력은 어느 팀에도 안 넣는다 (명단에서 입력하면 자동 반영)
        }
        _rosters = [men, women];
      } else if (mode == 'random') {
        _teamNames = ['1팀', '2팀'];
        _teamColors = const [Color(0xFFFF5252), Color(0xFF448AFF)];
        final names = [for (final (name, _) in people) name]
          ..shuffle(math.Random());
        final half = (names.length + 1) ~/ 2;
        _rosters = [names.sublist(0, half), names.sublist(half)];
      } else {
        _teamNames = ['1팀', '2팀'];
        _teamColors = const [Color(0xFFFF5252), Color(0xFF448AFF)];
        _rosters = [[], []];
      }
    });

    _ensureBgm(); // 모드 선택 탭 = 확실한 사용자 제스처 — 브금 시작
    if (mode != 'basic') {
      if (_rosters[0].isEmpty && _rosters[1].isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('참가자 명단이 비어 있어 팀 이름만 적용했어요!'),
          duration: Duration(seconds: 2),
        ));
      } else {
        _showRosterDialog();
      }
    }
  }

  /// 팀 명단 보기 (랜덤 모드는 다시 뽑기 가능)
  void _showRosterDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚔️ 팀 편성',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var t = 0; t < 2; t++) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _teamColors[t].withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _teamColors[t].withAlpha(120)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_teamNames[t]} (${_rosters[t].length}명)',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: _teamColors[t])),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final name in _rosters[t])
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(name,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (_mode == 'random')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _pickMode('random'); // 다시 셔플
              },
              child: const Text('🔀 다시 뽑기'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white),
            child: const Text('좋아, 시작!'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- 진행

  Future<void> _roll() async {
    if (_rolling) return;
    setState(() => _rolling = true);
    // 💡 버튼 탭 = 사용자 제스처 — 자동재생이 막혔던 브금을 여기서 확실히 시작
    await _ensureBgm();
    _playSfx('dice.wav');

    final rand = math.Random();
    // 주사위 굴러가는 연출
    for (var i = 0; i < 10; i++) {
      setState(() => _dice = rand.nextInt(6) + 1);
      await Future.delayed(const Duration(milliseconds: 80));
    }
    final steps = _dice;

    await _moveBy(steps);

    final tile = _tiles[_positions[_current]];
    if (!mounted) return;
    await _showTileDialog(tile);

    // 이동 칸이면 추가 이동 후 그 칸 미션까지
    if (tile.type == 'move') {
      if (tile.move == -99) {
        setState(() => _positions[_current] = 0);
      } else {
        await _moveBy(tile.move);
      }
      final next = _tiles[_positions[_current]];
      if (next.type != 'move' && mounted) {
        await _showTileDialog(next);
      }
    }

    if (!mounted) return;
    setState(() {
      _current = (_current + 1) % 2;
      _rolling = false;
    });
    _reviveBgm();
  }

  Future<void> _moveBy(int steps) async {
    final dir = steps >= 0 ? 1 : -1;
    for (var i = 0; i < steps.abs(); i++) {
      await Future.delayed(const Duration(milliseconds: 170));
      if (!mounted) return;
      setState(() => _positions[_current] =
          (_positions[_current] + dir + _tiles.length) % _tiles.length);
    }
  }

  Future<void> _showTileDialog(_Tile tile) {
    _playSfx('land.wav');
    final label = tile.label.replaceAll('\n', ' ');
    Widget body;
    if (tile.type == 'sonbyeongho') {
      final q = _sonbyeonghoQuestions[
          math.Random().nextInt(_sonbyeonghoQuestions.length)];
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDCEDFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('"$q"',
                style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    height: 1.5)),
          ),
          const SizedBox(height: 10),
          const Text('해당되는 사람은 모두 한 잔! 🍻',
              style: TextStyle(fontSize: 13.5, height: 1.5)),
        ],
      );
    } else {
      body = Text(tile.desc,
          style: const TextStyle(fontSize: 14.5, height: 1.55));
    }

    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        title: Column(
          children: [
            Text(tile.emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _teamColors[_current].withAlpha(26),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('${_teamNames[_current]} → $label',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _teamColors[_current])),
            ),
          ],
        ),
        content: body,
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teamColors[_current],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('미션 완료! 💪',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎲 주루마블',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        backgroundColor: const Color(0xFF0D2137),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // 💡 브금 켜기/끄기 (자동재생이 막힌 브라우저에선 이걸로 시작)
          IconButton(
            icon: Icon(_soundOn ? Icons.volume_up : Icons.volume_off,
                color: Colors.white70, size: 20),
            onPressed: _toggleSound,
          ),
          if (_mode != null &&
              (_rosters[0].isNotEmpty || _rosters[1].isNotEmpty))
            IconButton(
              icon: const Icon(Icons.groups, color: Colors.white70, size: 20),
              tooltip: '팀 명단',
              onPressed: _showRosterDialog,
            ),
          if (_mode != null)
            TextButton(
              onPressed: _rolling
                  ? null
                  : () => setState(() {
                        _mode = null; // 모드 선택으로
                        _positions[0] = 0;
                        _positions[1] = 0;
                        _current = 0;
                        _dice = 1;
                      }),
              child: const Text('다시 시작',
                  style: TextStyle(fontSize: 13, color: Colors.white70)),
            ),
        ],
      ),
      // 💡 밤바다 그라데이션 배경 — 칸들이 화면 테두리를 꽉 채운다
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2137), Color(0xFF14385C), Color(0xFF0E5A73)],
          ),
        ),
        child: _mode == null ? _buildModeSelect() : _buildBoard(),
      ),
    );
  }

  // ── 모드 선택 화면
  Widget _buildModeSelect() {
    Widget card(String emoji, String title, String desc, String mode) {
      return GestureDetector(
        onTap: () => _pickMode(mode),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.white60)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎲', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            const Text('팀을 어떻게 나눌까요?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 22),
            card('⚔️', '기본 모드', '1팀 vs 2팀 — 자유롭게 나눠 앉아서 시작!', 'basic'),
            card('🚻', '남녀 전쟁 모드', '남자팀 vs 여자팀 — 참가자 명단으로 자동 편성', 'gender'),
            card('🔀', '랜덤 모드', '참가자 명단을 앱이 무작위로 섞어 두 팀 편성', 'random'),
          ],
        ),
      ),
    );
  }

  // ── 게임판: 5x9 테두리 24칸
  Widget _buildBoard() {
    const cells = <(int, int)>[
      (0, 0), (0, 1), (0, 2), (0, 3), (0, 4), // 위 5
      (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), // 오른쪽 7
      (8, 4), (8, 3), (8, 2), (8, 1), (8, 0), // 아래 5
      (7, 0), (6, 0), (5, 0), (4, 0), (3, 0), (2, 0), (1, 0), // 왼쪽 7
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileW = constraints.maxWidth / 5;
          final tileH = constraints.maxHeight / 9;
          return Stack(
            children: [
              // 칸들
              for (var i = 0; i < _tiles.length; i++)
                Positioned(
                  left: cells[i].$2 * tileW,
                  top: cells[i].$1 * tileH,
                  width: tileW,
                  height: tileH,
                  child: Builder(builder: (_) {
                    // 현재 차례 팀의 말이 있는 칸은 팀 색 글로우
                    final hasCurrent = _positions[_current] == i;
                    return GestureDetector(
                      // 💡 칸을 탭하면 그 칸의 규칙 설명이 뜬다
                      onTap: () => _showTileInfo(_tiles[i]),
                      child: Container(
                      margin: const EdgeInsets.all(2),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _tileColor(_tiles[i].type),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasCurrent
                              ? _teamColors[_current]
                              : _tileBorder(_tiles[i].type),
                          width: hasCurrent ? 2.5 : 1.5,
                        ),
                        boxShadow: hasCurrent
                            ? [
                                BoxShadow(
                                    color: _teamColors[_current]
                                        .withAlpha(150),
                                    blurRadius: 10,
                                    spreadRadius: 1),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_tiles[i].emoji,
                              style: const TextStyle(fontSize: 17)),
                          const SizedBox(height: 1),
                          Text(
                            _tiles[i].label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: Color.lerp(
                                  _tileBorder(_tiles[i].type),
                                  Colors.black,
                                  0.45),
                            ),
                          ),
                          // 이 칸의 팀 말
                          SizedBox(
                            height: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var t = 0; t < 2; t++)
                                  if (_positions[t] == i)
                                    Container(
                                      width: 15,
                                      height: 15,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1.5),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _teamColors[t],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white,
                                            width: 1.5),
                                      ),
                                      child: Text('${t + 1}',
                                          style: const TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                    );
                  }),
                ),
              // 가운데: VS + 주사위 + 굴리기
              Positioned(
                left: tileW * 1.08,
                top: tileH * 1.15,
                width: tileW * 2.84,
                height: tileH * 6.7,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 팀 VS 표시 (현재 팀이 커지고 빛남)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _teamBadge(0),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('VS',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white38)),
                        ),
                        _teamBadge(1),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // 주사위 (점 찍힌 진짜 주사위)
                    _diceFace(_dice, 84),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _rolling ? null : _roll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teamColors[_current],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          elevation: 6,
                          shadowColor:
                              _teamColors[_current].withAlpha(150),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                            _rolling ? '두구두구...' : '🎲 굴리기!',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('팀원끼리 돌아가며 굴려주세요 🤿',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: Colors.white38)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 💡 칸 탭 = 규칙 미리보기 (미션 수행 아님)
  void _showTileInfo(_Tile tile) {
    final label = tile.label.replaceAll('\n', ' ');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Text(tile.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          tile.type == 'sonbyeongho'
              ? '이 칸에 걸리면 준비된 손병호 질문 ${_sonbyeonghoQuestions.length}개 중 '
                  '하나가 랜덤으로 나옵니다.\n해당되는 사람은 모두 한 잔!'
              : tile.desc,
          style: const TextStyle(fontSize: 14, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 팀 뱃지 — 현재 차례 팀은 꽉 찬 색 + 그림자
  Widget _teamBadge(int t) {
    final active = _current == t;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(
          horizontal: active ? 14 : 10, vertical: active ? 7 : 5),
      decoration: BoxDecoration(
        color: active ? _teamColors[t] : Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
            color: active ? Colors.white : Colors.white24, width: 1.5),
        boxShadow: active
            ? [
                BoxShadow(
                    color: _teamColors[t].withAlpha(170), blurRadius: 12),
              ]
            : null,
      ),
      child: Text(
        _teamNames[t],
        style: TextStyle(
          fontSize: active ? 16 : 13,
          fontWeight: FontWeight.w900,
          color: active ? Colors.white : Colors.white54,
        ),
      ),
    );
  }

  /// 점(pip)이 찍힌 클래식 주사위
  Widget _diceFace(int n, double size) {
    // 3x3 그리드에서 눈 위치
    const pips = {
      1: [4],
      2: [0, 8],
      3: [0, 4, 8],
      4: [0, 2, 6, 8],
      5: [0, 2, 4, 6, 8],
      6: [0, 2, 3, 5, 6, 8],
    };
    final on = pips[n]!;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var row = 0; row < 3; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var col = 0; col < 3; col++)
                  Container(
                    width: size * 0.14,
                    height: size * 0.14,
                    decoration: BoxDecoration(
                      color: on.contains(row * 3 + col)
                          ? (n == 1
                              ? const Color(0xFFE53935)
                              : const Color(0xFF263238))
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
