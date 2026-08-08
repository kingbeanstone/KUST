/// 네이티브용 스텁 — 웹 브리지는 항상 실패를 돌려서
/// 호출부가 audioplayers 경로를 타게 한다.
bool audioPlay(String url, bool loop, double volume) => false;

bool audioPause(String url) => false;

void audioLoad(String url) {}
