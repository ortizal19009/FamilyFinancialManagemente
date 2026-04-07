import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _baseUrlKey = 'backend_base_url';
  static const String defaultBaseUrl = 'http://10.0.2.2:5000/api';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_baseUrlKey);
    if (stored == null || stored.trim().isEmpty) {
      return defaultBaseUrl;
    }
    return _normalizeBaseUrl(stored);
  }

  static Future<void> saveBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _normalizeBaseUrl(value));
  }

  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return defaultBaseUrl;
    }

    var normalized = trimmed;
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.endsWith('/api')) {
      normalized = '$normalized/api';
    }
    return normalized;
  }
}
