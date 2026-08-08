import 'dart:convert';

import 'package:http/http.dart' as http;

/// 💡 울릉도 시간별 날씨 — Open-Meteo (무료·키 불필요·CORS 허용).
/// 홈 배너가 빨리 떠야 하므로 예보(기온·날씨·바람·강수)와
/// 파고(marine API)를 분리: 배너는 예보만 기다리고,
/// 파고는 백그라운드로 미리 받아 상세 화면에서 나중에 채워진다.
class HourlyWeather {
  final String key; // API 시간 문자열 (파고 매칭용)
  final DateTime time;
  final double temp; // ℃
  final int code; // WMO weather code
  final double wind; // m/s
  final int precipProb; // %

  const HourlyWeather({
    required this.key,
    required this.time,
    required this.temp,
    required this.code,
    required this.wind,
    required this.precipProb,
  });
}

class WeatherData {
  final List<HourlyWeather> hours; // 오늘 0시 ~ 내일 23시 (KST)

  const WeatherData(this.hours);

  /// 지금 시각에 해당하는 시간대 데이터
  HourlyWeather? get now {
    final n = DateTime.now();
    for (final h in hours) {
      if (h.time.year == n.year &&
          h.time.month == n.month &&
          h.time.day == n.day &&
          h.time.hour == n.hour) {
        return h;
      }
    }
    return hours.isEmpty ? null : hours.first;
  }
}

class WeatherService {
  // 울릉도 (저동항 부근)
  static const double lat = 37.49;
  static const double lon = 130.91;
  static const String placeName = '울릉도';

  static const Duration _ttl = Duration(minutes: 10);

  static Future<WeatherData>? _forecastFuture;
  static DateTime? _forecastAt;
  static Future<Map<String, double>>? _marineFuture;
  static DateTime? _marineAt;

  /// 💡 배너용 예보 — Future 자체를 메모이즈해서 홈/상세가 호출을 공유한다.
  /// 호출과 동시에 파고도 백그라운드로 데워 둔다.
  static Future<WeatherData> fetchForecast() {
    final cached = _forecastFuture;
    if (cached != null &&
        _forecastAt != null &&
        DateTime.now().difference(_forecastAt!) < _ttl) {
      return cached;
    }
    _forecastAt = DateTime.now();
    late final Future<WeatherData> f;
    f = _getForecast().then((d) => d, onError: (e) {
      // 실패한 결과는 캐시에 남기지 않는다 — 다음 빌드에서 재시도
      if (_forecastFuture == f) _forecastFuture = null;
      throw e;
    });
    _forecastFuture = f;
    fetchMarine(); // 상세 화면 대비 미리 시작 (기다리지 않음)
    return f;
  }

  /// 파고 — 시간 문자열 → 파고(m). 실패하면 빈 맵 (상세에서 '-' 표시).
  static Future<Map<String, double>> fetchMarine() {
    final cached = _marineFuture;
    if (cached != null &&
        _marineAt != null &&
        DateTime.now().difference(_marineAt!) < _ttl) {
      return cached;
    }
    _marineAt = DateTime.now();
    _marineFuture = _getMarine().then((m) => m,
        onError: (_) => <String, double>{});
    return _marineFuture!;
  }

  static Future<WeatherData> _getForecast() async {
    final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&hourly=temperature_2m,precipitation_probability,weather_code,wind_speed_10m'
        '&wind_speed_unit=ms&timezone=Asia%2FSeoul&forecast_days=2');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('날씨 API 응답 오류 (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final temps = (hourly['temperature_2m'] as List);
    final probs = (hourly['precipitation_probability'] as List);
    final codes = (hourly['weather_code'] as List);
    final winds = (hourly['wind_speed_10m'] as List);

    final hours = <HourlyWeather>[];
    for (var i = 0; i < times.length; i++) {
      hours.add(HourlyWeather(
        key: times[i],
        time: DateTime.parse(times[i]),
        temp: (temps[i] as num?)?.toDouble() ?? 0,
        code: (codes[i] as num?)?.toInt() ?? 0,
        wind: (winds[i] as num?)?.toDouble() ?? 0,
        precipProb: (probs[i] as num?)?.toInt() ?? 0,
      ));
    }
    return WeatherData(hours);
  }

  static Future<Map<String, double>> _getMarine() async {
    final uri = Uri.parse(
        'https://marine-api.open-meteo.com/v1/marine?latitude=$lat&longitude=$lon'
        '&hourly=wave_height&timezone=Asia%2FSeoul&forecast_days=2');
    final res = await http.get(uri);
    if (res.statusCode != 200) return {};
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final heights = (hourly['wave_height'] as List);
    final map = <String, double>{};
    for (var i = 0; i < times.length; i++) {
      final v = heights[i];
      if (v != null) map[times[i]] = (v as num).toDouble();
    }
    return map;
  }

  /// WMO weather code → (이모지, 설명)
  static (String, String) describe(int code) {
    switch (code) {
      case 0:
        return ('☀️', '맑음');
      case 1:
        return ('🌤️', '대체로 맑음');
      case 2:
        return ('⛅', '구름 조금');
      case 3:
        return ('☁️', '흐림');
      case 45:
      case 48:
        return ('🌫️', '안개');
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return ('🌦️', '이슬비');
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return ('🌧️', '비');
      case 71:
      case 73:
      case 75:
      case 77:
        return ('🌨️', '눈');
      case 80:
      case 81:
      case 82:
        return ('🌦️', '소나기');
      case 95:
      case 96:
      case 99:
        return ('⛈️', '뇌우');
      default:
        return ('☁️', '흐림');
    }
  }
}
