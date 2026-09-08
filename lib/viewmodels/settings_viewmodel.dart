import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class SettingsViewModel extends ChangeNotifier {
  ThemeProvider? _themeProvider;
  bool _showAds = true;
  String _adPosition = 'bottom';
  bool _isInitialized = false;
  bool _disposed = false;
  Future<void>? _loading;
  bool _showAdsChanged = false;
  bool _adPositionChanged = false;

  bool get darkMode => _themeProvider?.isDarkMode ?? false;
  bool get showAds => _showAds;
  String get adPosition => _adPosition;
  bool get isInitialized => _isInitialized;
  int get colorId => _themeProvider?.colorId ?? 1;
  AppThemeMode get currentTheme =>
      _themeProvider?.currentTheme ?? AppThemeMode.light;

  void setThemeProvider(ThemeProvider themeProvider) {
    _themeProvider = themeProvider;
  }

  Future<void> loadSettings() {
    if (_isInitialized || _disposed) return Future.value();
    return _loading ??= _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      // A late initial read must not overwrite a setting the user just changed.
      if (!_showAdsChanged) _showAds = prefs.getBool('show_ads') ?? true;
      if (!_adPositionChanged) {
        _adPosition =
            prefs.getString('ad_position') == 'top' ? 'top' : 'bottom';
      }
    } catch (e) {
      debugPrint('設定読み込みエラー: $e');
    } finally {
      if (!_disposed) {
        _isInitialized = true;
        notifyListeners();
      }
    }
  }

  Future<void> updateDarkMode(bool value) async {
    await _themeProvider
        ?.setThemeMode(value ? AppThemeMode.dark : AppThemeMode.light);
    if (!_disposed) notifyListeners();
  }

  Future<void> setColorScheme(int colorId) async {
    await _themeProvider?.setColorScheme(colorId);
    if (!_disposed) notifyListeners();
  }

  Future<void> updateShowAds(bool value) async {
    if (_disposed) return;
    _showAdsChanged = true;
    _showAds = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_ads', _showAds);
    } catch (e) {
      debugPrint('広告設定保存エラー: $e');
    }
  }

  Future<void> updateAdPosition(String value) async {
    if (_disposed || (value != 'top' && value != 'bottom')) return;
    _adPositionChanged = true;
    _adPosition = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ad_position', _adPosition);
    } catch (e) {
      debugPrint('広告位置保存エラー: $e');
    }
  }

  Future<void> clearCache() async {
    ApiService.clearCache();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
