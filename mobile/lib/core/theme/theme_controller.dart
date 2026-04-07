import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeOption {
  const ThemeOption({
    required this.id,
    required this.label,
    required this.previewColors,
  });

  final String id;
  final String label;
  final List<Color> previewColors;
}

class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'selected_theme_id';

  static const List<ThemeOption> options = [
    ThemeOption(
      id: 'heritage',
      label: 'Heritage',
      previewColors: [Color(0xFF1F5C57), Color(0xFFBF6D4F), Color(0xFFF8F1E7)],
    ),
    ThemeOption(
      id: 'ocean',
      label: 'Ocean',
      previewColors: [Color(0xFF0F4C81), Color(0xFF2A9D8F), Color(0xFFEAF4F4)],
    ),
    ThemeOption(
      id: 'sunset',
      label: 'Sunset',
      previewColors: [Color(0xFFA33B20), Color(0xFFF4A261), Color(0xFFFEF3E7)],
    ),
    ThemeOption(
      id: 'forest',
      label: 'Forest',
      previewColors: [Color(0xFF2F5D50), Color(0xFF7A9E7E), Color(0xFFF1F5EC)],
    ),
  ];

  String _selectedThemeId = options.first.id;
  bool _loaded = false;

  String get selectedThemeId => _selectedThemeId;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null && options.any((option) => option.id == stored)) {
      _selectedThemeId = stored;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> selectTheme(String themeId) async {
    if (_selectedThemeId == themeId) {
      return;
    }
    _selectedThemeId = themeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, themeId);
    notifyListeners();
  }
}
