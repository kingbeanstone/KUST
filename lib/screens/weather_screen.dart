import 'package:flutter/material.dart';

import '../util/weather_service.dart';

/// 💡 울릉도 시간대별 날씨 — 오늘/내일 시간별 기온·강수확률·바람·파고.
/// 예보는 홈 배너가 이미 받아둔 캐시를 재사용해 즉시 뜨고,
/// 파고는 별도 API라 나중에 도착하면 그때 채워진다.
class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🌊 울릉도 날씨',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: FutureBuilder<WeatherData>(
        future: WeatherService.fetchForecast(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('날씨를 불러오지 못했어요 😥\n잠시 후 다시 시도해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], height: 1.6)),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;

          // 💡 파고는 늦게 도착해도 리스트는 먼저 그린다 ('-' → 값 채움)
          return FutureBuilder<Map<String, double>>(
            future: WeatherService.fetchMarine(),
            builder: (context, marineSnap) {
              final waves = marineSnap.data ?? const <String, double>{};
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final tomorrow = today.add(const Duration(days: 1));

              // 오늘은 지난 시간은 빼고 지금 시각부터 보여준다
              final todayHours = data.hours
                  .where((h) =>
                      h.time.day == today.day &&
                      h.time.month == today.month &&
                      !h.time.isBefore(
                          DateTime(now.year, now.month, now.day, now.hour)))
                  .toList();
              final tomorrowHours = data.hours
                  .where((h) =>
                      h.time.day == tomorrow.day &&
                      h.time.month == tomorrow.month)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _daySection(context, '오늘 (${today.month}/${today.day})',
                      todayHours, waves, now),
                  const SizedBox(height: 20),
                  _daySection(
                      context,
                      '내일 (${tomorrow.month}/${tomorrow.day})',
                      tomorrowHours,
                      waves,
                      now),
                  const SizedBox(height: 12),
                  Text('자료: Open-Meteo · 파고는 울릉도 연안 예보 기준',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _daySection(BuildContext context, String title,
      List<HourlyWeather> hours, Map<String, double> waves, DateTime now) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          // 열 머리
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                    child: Text('날씨',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500]))),
                _head('기온', 38),
                _head('강수', 38),
                _head('바람', 50),
                _head('파도', 38),
              ],
            ),
          ),
          const Divider(height: 1),
          ...hours.map((h) => _hourRow(h, waves[h.key],
              isNow: h.time.day == now.day && h.time.hour == now.hour)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _head(String t, double w) => SizedBox(
        width: w,
        child: Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500])),
      );

  Widget _hourRow(HourlyWeather h, double? wave, {required bool isNow}) {
    final (emoji, desc) = WeatherService.describe(h.code);
    // 💡 다이빙 관점 경고색: 강수확률 60%↑ 빨강/30%↑ 주황, 파고 1m↑ 빨강/0.7m↑ 주황
    final probColor = h.precipProb >= 60
        ? Colors.red[600]
        : (h.precipProb >= 30 ? Colors.orange[700] : Colors.grey[600]);
    final waveColor = (wave ?? 0) >= 1.0
        ? Colors.red[600]
        : ((wave ?? 0) >= 0.7 ? Colors.orange[700] : Colors.grey[600]);

    return Container(
      color: isNow ? Colors.blue[50] : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              isNow ? '지금' : '${h.time.hour}시',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: isNow ? FontWeight.bold : FontWeight.w500,
                  color: isNow ? Colors.blue[700] : Colors.black87),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(desc,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[700])),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 38,
            child: Text('${h.temp.round()}°',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 38,
            child: Text('${h.precipProb}%',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: probColor)),
          ),
          SizedBox(
            width: 50,
            child: Text('${h.wind.toStringAsFixed(1)}m/s',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
          ),
          SizedBox(
            width: 38,
            child: Text(wave == null ? '-' : '${wave.toStringAsFixed(1)}m',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: waveColor)),
          ),
        ],
      ),
    );
  }
}
