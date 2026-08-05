/// 💡 포인트 사진 목록 (자동 생성 — scratchpad/prep_photos.py).
/// key: '사이트명' 또는 '사이트명|세부 포인트명'.
/// 값은 Firebase Hosting 정적 파일 경로 — 서비스워커가 첫 조회 때 기기에 캐시한다.
const Map<String, List<String>> kSitePhotos = {
  '죽도|사랑의 포인트': [
    'https://kust-88683.web.app/site_photos/jukdo_love/1.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_love/2.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_love/3.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_love/4.jpg',
  ],
  '죽도|동굴 포인트': [
    'https://kust-88683.web.app/site_photos/jukdo_cave/1.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_cave/2.jpg',
  ],
  '죽도|큰바위 포인트': [
    'https://kust-88683.web.app/site_photos/jukdo_bigrock/1.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_bigrock/2.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_bigrock/3.jpg',
  ],
  '죽도|작은바위 포인트': [
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/1.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/2.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/3.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/4.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/5.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/6.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/7.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/8.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/9.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/10.jpg',
    'https://kust-88683.web.app/site_photos/jukdo_smallrock/11.jpg',
  ],
  '관음도|쌍굴 포인트': [
    'https://kust-88683.web.app/site_photos/gwaneum_ssanggul/1.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_ssanggul/2.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_ssanggul/3.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_ssanggul/4.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_ssanggul/5.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_ssanggul/6.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_ssanggul/7.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_ssanggul/8.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_ssanggul/9.jpg',
  ],
  '관음도|솔밭 포인트': [
    'https://kust-88683.web.app/site_photos/gwaneum_solbat/1.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_solbat/2.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_solbat/3.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_solbat/4.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_solbat/5.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_solbat/6.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_solbat/7.jpg',
  ],
  '관음도|평바위 포인트': [
    'https://kust-88683.web.app/site_photos/gwaneum_flatrock/1.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_flatrock/2.jpg',
    'https://kust-88683.web.app/site_photos/gwaneum_flatrock/3.jpg',
  ],
  '쌍정초': [
    'https://kust-88683.web.app/site_photos/ssangjeongcho/1.jpg',
    'https://kust-88683.web.app/site_photos/ssangjeongcho/2.jpg',
    'https://kust-88683.web.app/site_photos/ssangjeongcho/3.jpg',
    'https://kust-88683.web.app/site_photos/ssangjeongcho/4.jpg',
    'https://kust-88683.web.app/site_photos/ssangjeongcho/5.jpg',
    'https://kust-88683.web.app/site_photos/ssangjeongcho/6.jpg',
    'https://kust-88683.web.app/site_photos/ssangjeongcho/7.jpg',
  ],
  '공암': [
    'https://kust-88683.web.app/site_photos/gongam/1.jpg',
    'https://kust-88683.web.app/site_photos/gongam/2.jpg',
    'https://kust-88683.web.app/site_photos/gongam/3.jpg',
    'https://kust-88683.web.app/site_photos/gongam/4.jpg',
  ],
};
