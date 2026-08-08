import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// 💡 동기여행 추천 가이드.
/// 원정 마지막 날 다이빙 없이 동기끼리 울릉도를 도는 날 —
/// 관람·사진·자연·스노클·맛집 스팟을 카테고리로 훑어보고
/// 탭하면 구글 지도 검색으로 바로 연결한다.
/// 데이터는 하드코딩 (울릉도 한정, 자주 안 바뀜).
class TripGuideScreen extends StatefulWidget {
  const TripGuideScreen({super.key});

  @override
  State<TripGuideScreen> createState() => _TripGuideScreenState();
}

/// 카테고리 정의 — key, 라벨, 이모지, 색
class _TripCategory {
  final String key;
  final String label;
  final String emoji;
  final Color color;
  const _TripCategory(this.key, this.label, this.emoji, this.color);
}

const List<_TripCategory> _kCategories = [
  _TripCategory('sight', '관람', '🎡', Color(0xFF1E88E5)),
  _TripCategory('photo', '사진', '📸', Color(0xFF8E24AA)),
  _TripCategory('nature', '자연', '🌿', Color(0xFF43A047)),
  _TripCategory('snorkel', '스노클', '🤿', Color(0xFF00ACC1)),
  _TripCategory('food', '맛집', '🍚', Color(0xFFF4511E)),
  _TripCategory('cafe', '카페', '☕', Color(0xFF6D4C41)),
];

class _TripSpot {
  final String category; // _kCategories key
  final String emoji;
  final String name;
  final String area; // 위치 뱃지
  final String desc;
  final String? mapQuery; // null이면 name으로 검색, http로 시작하면 그 링크를 바로 연다
  const _TripSpot(this.category, this.emoji, this.name, this.area, this.desc,
      [this.mapQuery]);
}

/// 💡 울릉도 스팟 목록. 순서 = 화면 표시 순서 (카테고리 내 추천순).
const List<_TripSpot> _kSpots = [
  // ── 🎡 관람 ──
  _TripSpot('sight', '🚠', '독도전망대 케이블카', '도동',
      '망향봉 정상까지 케이블카로 슝. 도동항이 한눈에 내려다보이고, 날이 아주 맑으면 독도까지 보인다.',
      '울릉도 독도전망대 케이블카'),
  _TripSpot('sight', '💧', '봉래폭포', '저동',
      '3단으로 떨어지는 25m 폭포. 가는 길의 천연 에어컨 "풍혈" 앞에 서면 한여름에도 서늘하다. 가벼운 산책 코스.',
      '울릉도 봉래폭포'),
  _TripSpot('sight', '🚞', '태하 향목전망대 모노레일', '태하',
      '모노레일 타고 올라가서 대풍감 절벽을 내려다보는 코스. 울릉도에서 전망 하나로는 최상위.',
      '태하향목관광모노레일'),
  _TripSpot('sight', '🌉', '관음도', '섬목',
      '보행 연도교를 건너 들어가는 무인도. 섬 위 산책로를 한 바퀴 돌면 삼선암·죽도가 다 보인다.',
      '울릉도 관음도'),
  _TripSpot('sight', '🇰🇷', '독도', '배편 왕복',
      '저동·사동항에서 배로 왕복. 접안은 그날 파도 운에 달렸다 — 삼대가 덕을 쌓아야 밟는다는 그 섬.',
      '독도'),
  _TripSpot('sight', '🚶', '행남 해안산책로', '도동↔저동',
      '해안 절벽을 따라 도동과 저동을 잇는 데크길. 통제 구간이 있을 수 있으니 현지에서 확인하고 걷자.',
      '울릉도 행남해안산책로'),

  // ── 📸 사진 ──
  _TripSpot('photo', '⛰️', '대풍감', '태하',
      '향목전망대에서 내려다보는 해안 절벽 — 한국 10대 비경. 울릉도 인생샷 1순위.',
      '울릉도 대풍감'),
  _TripSpot('photo', '🗿', '삼선암', '북면 섬목',
      '세 신선이 돌이 됐다는 전설의 기암. 도로변에서 바로 보여서 차 세우고 찍기 좋다.',
      '울릉도 삼선암'),
  _TripSpot('photo', '🐘', '코끼리바위 (공암)', '북면 현포',
      '코를 물에 담근 코끼리 모양의 주상절리 바위. 해질녘 실루엣이 예술이다.',
      '울릉도 코끼리바위'),
  _TripSpot('photo', '🐢', '거북바위', '통구미',
      '거북이들이 기어오르는 모양의 바위. 마을 풍경과 같이 담으면 그림이 된다.',
      '울릉도 통구미 거북바위'),
  _TripSpot('photo', '🌅', '학포해변 노을', '학포',
      '작고 조용한 몽돌해변. 서쪽 해안이라 울릉도에서 노을 보기 가장 좋은 자리 중 하나.',
      '울릉도 학포해변'),

  // ── 🌿 자연 ──
  _TripSpot('nature', '🌋', '나리분지', '북면',
      '울릉도 유일의 평지이자 칼데라 분지. 너와집·투막집 구경하고 산채비빔밥까지 먹으면 코스 완성.',
      '울릉도 나리분지'),
  _TripSpot('nature', '🏔️', '성인봉', '울릉도 최고봉',
      '984m 원시림 등산. 나리분지 기준 왕복 4~5시간이라 하루 여행엔 빡세다 — 체력 자신 있는 팀만.',
      '울릉도 성인봉'),
  _TripSpot('nature', '⛲', '신령수', '나리분지',
      '성인봉 물이 솟아나는 약수터. 나리분지 산책의 반환점으로 딱 좋다.',
      '울릉도 신령수'),
  _TripSpot('nature', '🪨', '죽암 몽돌해변', '천부',
      '파도가 빠질 때마다 몽돌 구르는 소리가 나는 해변. 물색도 울릉도답게 맑다.',
      '울릉도 죽암몽돌해변'),

  // ── 🤿 스노클 ──
  _TripSpot('snorkel', '🐠', '통구미 거북바위 앞', '통구미',
      '울릉도 스노클 성지. 진입이 편하고 자리돔 떼가 반겨준다. 거북바위 구경은 덤.',
      '울릉도 통구미 거북바위'),
  _TripSpot('snorkel', '🌊', '학포해변', '학포',
      '물 맑고 잔잔한 날이 많은 작은 해변. 스노클 후 노을까지 보면 마무리 완벽.',
      '울릉도 학포해변'),
  _TripSpot('snorkel', '🪸', '내수전 몽돌해변', '저동',
      '저동에서 가까워 접근이 쉽다. 몽돌해변이라 물이 탁해질 일도 적다.',
      '울릉도 내수전해변'),
  _TripSpot('snorkel', '💙', '죽암 몽돌해변', '천부',
      '북면 드라이브 중 물이 예뻐서 그냥 지나치기 힘든 곳. 장비 있으면 입수각.',
      '울릉도 죽암몽돌해변'),

  // ── 🍚 맛집 ──
  _TripSpot('food', '🥟', '독도반점', '도동',
      '울릉도의 명물 중국집. 홍합짬뽕이 유명하다 — 웨이팅 각오하고 가자.',
      'https://naver.me/GKUAW3sv'),
  _TripSpot('food', '🍜', '동백식당', '도동',
      '울릉도 별미 따개비집. 따개비밥·따개비칼국수 국물이 진하다.',
      '울릉도 동백식당'),
  _TripSpot('food', '🐟', '신비섬횟집', '도동 인근',
      '물회 맛집. 울릉도 근해에서 잡은 회를 시원한 물회로 — 다이빙 후에 이만한 게 없다.',
      '울릉도 신비섬횟집'),
  _TripSpot('food', '🍲', '현포교동반점', '북면 현포',
      '북면 드라이브 중 만나는 중국집. 코끼리바위 보러 갔다면 여기서 식사각.',
      '울릉도 현포교동반점'),
  _TripSpot('food', '🍙', '아리랑김밥', '저동',
      '오징어먹물김밥·명이김밥이 시그니처. 오후 1시 반이면 닫으니 아침·점심용 — 성수기엔 예약 필수.',
      '울릉도 아리랑김밥'),
  _TripSpot('food', '🥗', '나리촌식당', '나리분지',
      '명이·부지깽이 등 울릉도 나물 산채비빔밥. 나리분지 갔다면 무조건.',
      '울릉도 나리촌식당'),
  _TripSpot('food', '🌿', '야영장식당', '나리분지',
      '나리분지 야영장 옆 산채비빔밥집. 나리촌과 함께 분지 산채 양대산맥.',
      '울릉도 야영장식당'),
  _TripSpot('food', '🍚', '홍합밥', '도동',
      '자연산 홍합을 넣은 돌솥밥. 간장에 쓱쓱 비비면 끝난다.',
      '울릉도 홍합밥'),
  _TripSpot('food', '🦑', '오징어내장탕', '저동항',
      '울릉도식 해장 원탑. 저동항 근처가 원조 동네다.',
      '울릉도 오징어내장탕'),
  _TripSpot('food', '🥩', '울릉약소', '도동·사동',
      '약초 먹고 자란 울릉도 소. 마지막 날 동기 회식각 — 단, 가격은 각오하고 가자.',
      '울릉도 약소'),
  _TripSpot('food', '🦐', '독도새우', '저동항',
      '물량 없으면 못 먹는 귀한 몸. 가격이 사악하니 시세 확인은 필수.',
      '울릉도 독도새우'),
  _TripSpot('food', '🎃', '호박엿·호박막걸리', '도동',
      '울릉도 하면 호박. 선물용 호박엿에 저녁엔 호박막걸리 한 잔.',
      '울릉도 호박엿'),

  // ── ☕ 카페 ──
  _TripSpot('cafe', '🦍', '카페 울라', '북면 추산',
      '송곳봉 아래 추산항 뷰의 울릉도 대표 카페. 시그니처는 울라치노.',
      '울릉도 카페울라'),
  _TripSpot('cafe', '🧺', '숲크닉커피', '북면',
      '숲속 피크닉 감성 카페. 북면 드라이브에 끼워 넣기 좋다.',
      '울릉도 숲크닉커피'),
  _TripSpot('cafe', '🎨', '팔레트', '북면',
      '북면 바닷가의 아기자기한 카페. 사진 찍기 좋은 인테리어.',
      '울릉도 팔레트 카페'),
  _TripSpot('cafe', '🪵', '카페 너와', '울릉도',
      '울릉도 감성 카페 투어 필수 코스 중 하나.',
      '울릉도 카페 너와'),
  _TripSpot('cafe', '🌼', '울릉국화', '오션뷰',
      '문 열면 바로 앞이 바다. 뷰 하나로 커피값 하는 곳.',
      '울릉도 울릉국화'),
  _TripSpot('cafe', '🛋️', '글림', '울릉도',
      '조용하고 아늑한 소파 카페. 일정 사이 쉬어가기 좋다.',
      '울릉도 글림'),
];

class _TripGuideScreenState extends State<TripGuideScreen> {
  String? _filter; // null = 전체

  void _openMap(_TripSpot spot) {
    // 💡 네이버 지도 검색 — 폰에 네이버 지도 앱이 있으면 앱으로,
    // 없으면 모바일 웹 지도로 열린다 (국내 장소는 구글보다 검색 적중률이 좋음)
    // 특정 가게는 네이버 공유 링크(naver.me)로 정확한 장소를 바로 연다
    if (spot.mapQuery != null && spot.mapQuery!.startsWith('http')) {
      launchUrlString(spot.mapQuery!, mode: LaunchMode.externalApplication);
      return;
    }
    final q = Uri.encodeComponent(spot.mapQuery ?? '울릉도 ${spot.name}');
    launchUrlString('https://map.naver.com/p/search/$q',
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final spots = _filter == null
        ? _kSpots
        : _kSpots.where((s) => s.category == _filter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('동기여행 추천 🏝️',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // 카테고리 필터 칩
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _chip(null, '전체', '🗺️', Colors.blueGrey),
                for (final c in _kCategories)
                  _chip(c.key, c.label, c.emoji, c.color),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                // 안내 배너 (필터별로 문구가 다름)
                if (_filter == 'snorkel')
                  _banner('🤿', '스노클도 바다다',
                      '2인 1조, 입수 전 너울·파도 확인, 오리발 착용. 우리가 제일 잘 알지?',
                      const Color(0xFF00ACC1))
                else if (_filter == 'food')
                  _banner('⏰', '대부분 저녁 6~7시면 마감!',
                      '울릉도 식당은 일찍 닫는다. 저녁은 무조건 일찍 해결하자.',
                      const Color(0xFFF4511E))
                else if (_filter == 'cafe')
                  _banner('☀️', '카페는 낮 일정에 끼워 넣자',
                      '카페 좋아하는 동기가 있다면 드라이브 코스 중간중간 낮에 들르는 걸 추천.',
                      const Color(0xFF6D4C41))
                else if (_filter == null)
                  _banner('🚌', '마지막 날은 동기끼리 울릉도 한 바퀴',
                      '탭하면 네이버 지도로 바로 연결됩니다. 동선은 도동 → 통구미 → 태하 → 북면 → 섬목 순이 한 바퀴 코스. 식당은 저녁 6~7시면 대부분 마감!',
                      Colors.blue[700]!),
                const SizedBox(height: 4),
                for (final spot in spots) _spotCard(spot),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String? key, String label, String emoji, Color color) {
    final selected = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$emoji $label',
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.white : Colors.black87)),
        selected: selected,
        onSelected: (_) => setState(() => _filter = key),
        selectedColor: color,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? color : Colors.grey[300]!),
        showCheckmark: false,
      ),
    );
  }

  Widget _banner(String emoji, String title, String body, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji $title',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(body,
              style: TextStyle(
                  fontSize: 12.5, height: 1.5, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _spotCard(_TripSpot spot) {
    final cat = _kCategories.firstWhere((c) => c.key == spot.category);
    return GestureDetector(
      onTap: () => _openMap(spot),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: cat.color.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.1), shape: BoxShape.circle),
              child: Text(spot.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(spot.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: cat.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(spot.area,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: cat.color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(spot.desc,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Colors.grey[700])),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.map_outlined, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
