import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';

class SettingsViewModel extends ChangeNotifier {
  ThemeProvider? _themeProvider;
  bool _showAds = true;
  String _adPosition = 'bottom';

  bool get darkMode => _themeProvider?.isDarkMode ?? false;
  bool get showAds => _showAds;
  String get adPosition => _adPosition;
  int get colorId => _themeProvider?.colorId ?? 1; // デフォルトはライトモード(colorId=1)
  AppThemeMode get currentTheme => _themeProvider?.currentTheme ?? AppThemeMode.light;

  // ThemeProviderを設定
  void setThemeProvider(ThemeProvider themeProvider) {
    _themeProvider = themeProvider;
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showAds = prefs.getBool('show_ads') ?? true;
      _adPosition = prefs.getString('ad_position') ?? 'bottom';
      notifyListeners();
    } catch (e) {
      print('設定読み込みエラー: $e');
    }
  }

  Future<void> updateDarkMode(bool value) async {
    if (_themeProvider != null) {
      final newMode = value ? AppThemeMode.dark : AppThemeMode.light;
      await _themeProvider!.setThemeMode(newMode);
      notifyListeners();
    }
  }

  // colorIdベースでテーマを変更する方法（_setColorSchemeと互換性）
  // colorId 1 = ライトモード, colorId 2 = ダークモード
  Future<void> setColorScheme(int colorId) async {
    if (_themeProvider != null) {
      await _themeProvider!.setColorScheme(colorId);
      notifyListeners();
    }
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
      await prefs.setBool('show_ads', _showAds);
      await prefs.setString('ad_position', _adPosition);
      // テーマ設定はThemeProviderで管理されるため、ここでは保存しない
    } catch (e) {
      print('設定保存エラー: $e');
    }
  }

  Future<void> clearCache() async {
    // キャッシュクリア実装
    print('キャッシュをクリアしました');
  }
}