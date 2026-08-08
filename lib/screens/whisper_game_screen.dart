import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// 💡 귓속말 게임: 술래가 오른쪽 사람에게만 귓속말로 질문 → 들은 사람이
/// 어울리는 사람을 조용히 지목 → 지목당한 사람이 이어받아 자기 오른쪽에게
/// 새 질문 → 무한 체인. 질문이 궁금하면 누구든 벌주 한 잔 마시고 귓속말로
/// 들을 수 있고, 궁금한 사람이 전체 1/3 이상이면 다 같이 마시고 전체 공개.
/// 앱은 질문이 안 떠오를 때 뽑아 쓰는 "질문 카드" 역할만 한다.
class WhisperGameScreen extends StatefulWidget {
  const WhisperGameScreen({super.key});

  @override
  State<WhisperGameScreen> createState() => _WhisperGameScreenState();
}

class _WhisperGameScreenState extends State<WhisperGameScreen> {
  // 💡 질문 뱅크: 뽑히는 순간 그 사람이 웃겨지는 질문 위주
  // (엉뚱함·우스꽝·인기·외모·변태 몰이). 한 바퀴 다 돌기 전엔 중복이 안 나온다.
  static const List<String> _questions = [
    // 인기·외모
    '여기서 제일 잘생긴 사람은?',
    '여기서 제일 예쁜 사람은?',
    '내 이상형에 제일 가까운 사람은?',
    '고백 제일 많이 받아봤을 것 같은 사람은?',
    '길에서 헌팅 제일 많이 당할 것 같은 사람은?',
    '몰래 연애하고 있을 것 같은 사람은?',
    '알고 보면 제일 잘 놀 것 같은 사람은?',
    // 변태·흑역사 몰이
    '알고 보면 제일 변태일 것 같은 사람은?',
    '검색 기록 절대 못 보여줄 것 같은 사람은?',
    'SNS 염탐 제일 많이 할 것 같은 사람은?',
    '술 취하면 흑역사 제일 많이 만들 것 같은 사람은?',
    '방귀 뀌고 모른 척했을 것 같은 사람은?',
    // 엉뚱·우스꽝
    '눈치가 제일 없는 것 같은 사람은?',
    // 원정 특화
    '바닷속에서 문어 보면 제일 소리 지를 것 같은 사람은?',
    '장비 하나 두고 왔을 것 같은 사람은?',
    '다이빙 중에 혼자 딴 데 보고 있을 것 같은 사람은?',
    '버디 몰래 먼저 올라갈 것 같은 사람은?',
  ];

  // 💡 수위 UP 전용 질문. [수위 질문 뽑기]로만 뽑히고,
  // 뽑히면 빨간 경고 + 새로고침 버튼이 함께 나온다.
  static const List<String> _spicyQuestions = [
    '이 중에서 나를 좋아하고 있을 것 같은 사람은?',
    '지금 이 자리에서 짝사랑 중인 것 같은 사람은?',
    '술김에 오늘 밤 누군가에게 고백할 것 같은 사람은?',
    '첫 경험이 제일 빨랐을 것 같은 사람은?',
    '키스 제일 잘할 것 같은 사람은?',
    '연애하면 어장관리할 것 같은 사람은?',
    '사귀다 헤어지면 스토커 될 것 같은 사람은?',
    '바람 피워도 절대 안 걸릴 것 같은 사람은?',
  ];

  final AudioPlayer _sfx = AudioPlayer();
  bool _soundOn = true;

  /// 0=홈(룰+뽑기 버튼), 1=질문 카드
  int _stage = 0;
  late List<int> _order; // 일반 질문 셔플 순서
  int _cursor = 0;
  late List<int> _spicyOrder; // 수위 질문 셔플 순서
  int _spicyCursor = 0;
  String _question = '';
  bool _isSpicy = false;
  bool _peeking = false; // 꾹 누르는 동안만 질문 표시

  @override
  void initState() {
    super.initState();
    _shufflePools();
  }

  @override
  void dispose() {
    _sfx.dispose();
    super.dispose();
  }

  void _shufflePools() {
    _order = List.generate(_questions.length, (i) => i)
      ..shuffle(math.Random());
    _cursor = 0;
    _spicyOrder = List.generate(_spicyQuestions.length, (i) => i)
      ..shuffle(math.Random());
    _spicyCursor = 0;
  }

  Future<void> _playSfx(String file) async {
    if (!_soundOn) return;
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource('audio/$file'), volume: 0.9);
    } catch (_) {
      // 오디오 실패는 게임 진행에 영향 없음
    }
  }

  void _draw({bool spicy = false}) {
    _playSfx(spicy ? 'beep.wav' : 'land.wav');
    setState(() {
      if (spicy) {
        if (_spicyCursor >= _spicyOrder.length) {
          _spicyOrder.shuffle(math.Random());
          _spicyCursor = 0;
        }
        _question = _spicyQuestions[_spicyOrder[_spicyCursor++]];
      } else {
        if (_cursor >= _order.length) {
          _order.shuffle(math.Random());
          _cursor = 0;
        }
        _question = _questions[_order[_cursor++]];
      }
      _isSpicy = spicy;
      _stage = 1;
      _peeking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤫 귓속말 게임',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        backgroundColor: const Color(0xFF0D2137),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: Text(_soundOn ? '🔊' : '🔇',
                style: const TextStyle(fontSize: 18)),
            onPressed: () => setState(() => _soundOn = !_soundOn),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2137), Color(0xFF14385C), Color(0xFF0E5A73)],
          ),
        ),
        child: SafeArea(
          child: _stage == 0 ? _buildHome() : _buildCard(),
        ),
      ),
    );
  }

  // ─────────────────────────── 0. 홈: 룰 설명 + 질문 뽑기
  Widget _buildHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('🤫', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          const Text('귓속말 게임',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RuleLine('1️⃣', '술래가 오른쪽 사람에게만 귓속말로 질문! (직접 만들어도, 아래에서 뽑아도 OK)'),
                _RuleLine('2️⃣', '질문 들은 사람은 어울리는 사람을 조용히 지목 🫵'),
                _RuleLine('3️⃣', '지목당한 사람이 이어받아 자기 오른쪽에게 새 질문 → 무한 체인!'),
                _RuleLine('4️⃣', '질문이 궁금하면? 누구든 한 잔 마시고 귓속말로 듣기 🍺'),
                _RuleLine('5️⃣', '궁금한 사람이 전체 ⅓ 이상이면 다 같이 마시고 질문 전체 공개! 📢'),
                _RuleLine('6️⃣', '지목할 사람이 안 떠오르면 한 잔 마시고 옆으로 패스'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _draw,
              child: const Text('🎁 일반 질문 뽑기',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFFF5252))),
              ),
              onPressed: () => _draw(spicy: true),
              child: const Text('🔞 수위 질문 뽑기 — 분위기 보고!',
                  style:
                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 1. 질문 카드
  Widget _buildCard() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('질문할 사람만 보세요! 👀',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          if (_isSpicy) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF5252)),
              ),
              child: const Text(
                '🔞 수위 UP 질문! ⚠️ 분위기 보고 질문할 것!\n애매하면 아래 새로고침으로 다른 질문!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
          const SizedBox(height: 18),
          // 💡 꾹 누르는 동안만 질문이 보인다 — 옆 사람 훔쳐보기 방지
          GestureDetector(
            onTapDown: (_) => setState(() => _peeking = true),
            onTapUp: (_) => setState(() => _peeking = false),
            onTapCancel: () => setState(() => _peeking = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 150),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _peeking
                    ? const Color(0xFFFFF8E1)
                    : Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: _peeking
                        ? const Color(0xFFFFB300)
                        : Colors.white.withAlpha(60),
                    width: 1.5),
              ),
              child: Center(
                child: _peeking
                    ? Text('"$_question"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                            color: Colors.black87))
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('👆', style: TextStyle(fontSize: 30)),
                          SizedBox(height: 8),
                          Text('꾹 누르는 동안만 질문이 보여요',
                              style: TextStyle(
                                  fontSize: 14.5, color: Colors.white70)),
                        ],
                      ),
              ),
            ),
          ),
          if (_isSpicy) ...[
            const SizedBox(height: 8),
            // 💡 수위 질문은 다른 수위 질문으로 새로고침 가능
            TextButton.icon(
              onPressed: () => _draw(spicy: true),
              icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
              label: const Text('다른 수위 질문으로 새로고침',
                  style: TextStyle(fontSize: 13.5, color: Colors.white70)),
            ),
          ],
          const SizedBox(height: 14),
          Text('질문을 외웠으면 오른쪽 사람에게 귓속말!\n들은 사람은 어울리는 사람을 조용히 지목 🫵',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: Colors.white.withAlpha(200))),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => setState(() => _stage = 0),
              child: const Text('외웠다! 귓속말하러 가기 🤫',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final String emoji;
  final String text;
  const _RuleLine(this.emoji, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.45, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
