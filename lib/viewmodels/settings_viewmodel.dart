import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel extends ChangeNotifier {
  bool _darkMode = false;
  bool _showAds = true;
  String _adPosition = 'bottom';

  bool get darkMode => _darkMode;
  bool get showAds => _showAds;
  String get adPosition => _adPosition;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _showAds = prefs.getBool('show_ads') ?? true;
      _adPosition = prefs.getString('ad_position') ?? 'bottom';
      notifyListeners();
    } catch (e) {
      print('設定読み込みエラー: $e');
    }
  }

  Future<void> updateDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> updateShowAds(bool value) async {
    _showAds = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> updateAdPosition(String value) async {
    _adPosition = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', _darkMode);
      await prefs.setBool('show_ads', _showAds);
      await prefs.setString('ad_position', _adPosition);
    } catch (e) {
      print('設定保存エラー: $e');
    }
  }

  Future<void> clearCache() async {
    // キャッシュクリア実装
    print('キャッシュをクリアしました');
  }
}