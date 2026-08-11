import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ── Weather Data Model ────────────────────────────────────────────────────────

class WeatherData {
  final String city;
  final double tempC;
  final String description;
  final String icon;
  final int humidity;
  final double windKmh;
  final String dayOfWeek;

  const WeatherData({
    required this.city,
    required this.tempC,
    required this.description,
    required this.icon,
    required this.humidity,
    required this.windKmh,
    required this.dayOfWeek,
  });

  String get tempDisplay => '${tempC.round()}°C';
  String get humidityDisplay => 'Độ ẩm $humidity%';
  String get windDisplay => 'Gió ${windKmh.round()} km/h';
}

// ── Status ────────────────────────────────────────────────────────────────────

enum WeatherStatus { idle, loading, ready, error }

// ── Source (để debug / hiển thị nếu cần) ─────────────────────────────────────

enum WeatherSource { openWeatherMap, openMeteo }

// ── Service ───────────────────────────────────────────────────────────────────

import '../core/app_config.dart';

class WeatherService extends ChangeNotifier {
  // ── OpenWeatherMap ────────────────────────────────────────────────────
  static const _owmApiKey = AppConfig.openWeatherMapApiKey;
  static const _owmBaseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  // ── Open-Meteo (miễn phí, không cần API key) ──────────────────────────
  // Docs: https://open-meteo.com/en/docs
  static const _omBaseUrl = 'https://api.open-meteo.com/v1/forecast';

  // ── Reverse geocoding (để lấy tên thành phố cho Open-Meteo) ──────────
  // Dùng Nominatim (OpenStreetMap) – miễn phí
  static const _nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';

  WeatherStatus _status = WeatherStatus.idle;
  WeatherData? _weather;
  String? _errorMessage;
  WeatherSource? _activeSource;

  WeatherStatus get status => _status;
  WeatherData? get weather => _weather;
  String? get errorMessage => _errorMessage;
  bool get isReady => _status == WeatherStatus.ready && _weather != null;
  WeatherSource? get activeSource => _activeSource;

  // ── Public API ────────────────────────────────────────────────────────

  Future<void> fetchWeather() async {
    _status = WeatherStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final position = await _getLocation();
      final lat = position.latitude;
      final lon = position.longitude;

      // Thử nguồn 1: OpenWeatherMap
      bool owmSuccess = await _tryOpenWeatherMap(lat, lon);

      // Nếu thất bại → tự động chuyển sang nguồn 2: Open-Meteo
      if (!owmSuccess) {
        debugPrint('[WeatherService] OWM thất bại → chuyển sang Open-Meteo');
        await _fetchFromOpenMeteo(lat, lon);
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = WeatherStatus.error;
      notifyListeners();
    }
  }

  // ── Nguồn 1: OpenWeatherMap ───────────────────────────────────────────

  /// Trả về true nếu thành công, false nếu thất bại (để fallback).
  Future<bool> _tryOpenWeatherMap(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        '$_owmBaseUrl?lat=$lat&lon=$lon&appid=$_owmApiKey&units=metric&lang=vi',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      // 401 = API key hết hạn/sai, 429 = vượt quota → fallback
      if (res.statusCode == 401 || res.statusCode == 429) {
        debugPrint('[WeatherService] OWM lỗi ${res.statusCode} → fallback');
        return false;
      }
      if (res.statusCode != 200) {
        debugPrint('[WeatherService] OWM HTTP ${res.statusCode} → fallback');
        return false;
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      _weather = _parseOwmWeather(json);
      _activeSource = WeatherSource.openWeatherMap;
      _status = WeatherStatus.ready;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[WeatherService] OWM exception: $e → fallback');
      return false;
    }
  }

  WeatherData _parseOwmWeather(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;
    final weatherList = json['weather'] as List<dynamic>;
    final w = weatherList.first as Map<String, dynamic>;

    final tempC = (main['temp'] as num).toDouble();
    final humidity = (main['humidity'] as num).toInt();
    final windKmh = (wind['speed'] as num).toDouble() * 3.6;
    final conditionId = (w['id'] as num).toInt();
    final descRaw = (w['description'] as String?) ?? '';

    return WeatherData(
      city: _parseOwmCityName(json),
      tempC: tempC,
      description: _translateDescription(conditionId, descRaw),
      icon: _conditionToEmoji(conditionId),
      humidity: humidity,
      windKmh: windKmh,
      dayOfWeek: _todayVietnamese(),
    );
  }

  String _parseOwmCityName(Map<String, dynamic> json) {
    return (json['name'] as String?)?.isNotEmpty == true
        ? json['name'] as String
        : 'Vị trí hiện tại';
  }

  // ── Nguồn 2: Open-Meteo ───────────────────────────────────────────────

  Future<void> _fetchFromOpenMeteo(double lat, double lon) async {
    // Lấy dữ liệu thời tiết
    final uri = Uri.parse(
      '$_omBaseUrl'
          '?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code'
          '&wind_speed_unit=kmh'
          '&timezone=auto',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Open-Meteo lỗi HTTP ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;

    final tempC = (current['temperature_2m'] as num).toDouble();
    final humidity = (current['relative_humidity_2m'] as num).toInt();
    final windKmh = (current['wind_speed_10m'] as num).toDouble();
    final weatherCode = (current['weather_code'] as num).toInt();

    // Lấy tên thành phố qua reverse geocoding
    final cityName = await _reverseGeocode(lat, lon);

    _weather = WeatherData(
      city: cityName,
      tempC: tempC,
      description: _omCodeToDescription(weatherCode),
      icon: _omCodeToEmoji(weatherCode),
      humidity: humidity,
      windKmh: windKmh,
      dayOfWeek: _todayVietnamese(),
    );
    _activeSource = WeatherSource.openMeteo;
    _status = WeatherStatus.ready;
    notifyListeners();
  }

  // ── Reverse Geocoding (Nominatim) ─────────────────────────────────────

  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        '$_nominatimUrl?lat=$lat&lon=$lon&format=json&accept-language=vi',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'FlutterWeatherApp/1.0'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final address = json['address'] as Map<String, dynamic>?;
        if (address != null) {
          // Ưu tiên: suburb > city_district > city > town > county
          return (address['suburb'] as String?) ??
              (address['city_district'] as String?) ??
              (address['city'] as String?) ??
              (address['town'] as String?) ??
              (address['county'] as String?) ??
              'Vị trí hiện tại';
        }
      }
    } catch (_) {
      // Không block nếu geocoding thất bại
    }
    return 'Vị trí hiện tại';
  }

  // ── Open-Meteo WMO Weather Code → Emoji & Description ────────────────
  // Tham khảo: https://open-meteo.com/en/docs#weathervariables

  String _omCodeToEmoji(int code) {
    if (code == 0) return '☀️';
    if (code <= 2) return '🌤️';
    if (code == 3) return '☁️';
    if (code <= 49) return '🌫️';  // Fog / depositing rime fog
    if (code <= 59) return '🌦️';  // Drizzle
    if (code <= 69) return '🌧️';  // Rain
    if (code <= 79) return '❄️';  // Snow
    if (code <= 84) return '🌧️';  // Rain showers
    if (code <= 86) return '❄️';  // Snow showers
    if (code <= 99) return '⛈️';  // Thunderstorm
    return '🌡️';
  }

  String _omCodeToDescription(int code) {
    if (code == 0) return 'Trời quang, nắng đẹp';
    if (code == 1) return 'Nắng nhẹ, ít mây';
    if (code == 2) return 'Nắng nhẹ, có mây';
    if (code == 3) return 'Nhiều mây, u ám';
    if (code <= 49) return 'Sương mù';
    if (code <= 59) return 'Mưa phùn nhẹ';
    if (code <= 65) return 'Mưa nhỏ đến vừa';
    if (code <= 69) return 'Mưa lạnh, có tuyết mưa';
    if (code <= 79) return 'Có tuyết';
    if (code <= 82) return 'Mưa rào nhẹ';
    if (code <= 84) return 'Mưa rào vừa đến to';
    if (code <= 86) return 'Mưa tuyết';
    if (code <= 99) return 'Có dông, sấm sét';
    return 'Không rõ';
  }

  // ── Shared Helpers ────────────────────────────────────────────────────

  Future<Position> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS chưa được bật. Vui lòng bật vị trí trên thiết bị.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Ứng dụng cần quyền truy cập vị trí để hiển thị thời tiết.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Quyền vị trí bị từ chối vĩnh viễn. Vào Cài đặt để cấp lại.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 10),
    );
  }

  String _conditionToEmoji(int id) {
    if (id >= 200 && id < 300) return '⛈️';
    if (id >= 300 && id < 400) return '🌦️';
    if (id >= 500 && id < 600) return '🌧️';
    if (id >= 600 && id < 700) return '❄️';
    if (id >= 700 && id < 800) return '🌫️';
    if (id == 800) return '☀️';
    if (id == 801) return '🌤️';
    if (id == 802) return '⛅';
    return '☁️';
  }

  String _translateDescription(int id, String raw) {
    if (id >= 200 && id < 300) return 'Có dông, sấm sét';
    if (id >= 300 && id < 400) return 'Mưa phùn nhẹ';
    if (id == 500) return 'Mưa nhỏ';
    if (id == 501) return 'Mưa vừa';
    if (id >= 502 && id < 600) return 'Mưa to';
    if (id >= 600 && id < 700) return 'Có tuyết';
    if (id == 701 || id == 741) return 'Sương mù';
    if (id == 721) return 'Khói mờ, haze';
    if (id == 800) return 'Trời quang, nắng đẹp';
    if (id == 801) return 'Nắng nhẹ, ít mây';
    if (id == 802) return 'Nắng nhẹ, có mây';
    if (id == 803 || id == 804) return 'Nhiều mây';
    return raw.isNotEmpty ? raw[0].toUpperCase() + raw.substring(1) : 'Không rõ';
  }

  String _todayVietnamese() {
    const days = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
    return days[DateTime.now().weekday % 7];
  }
}