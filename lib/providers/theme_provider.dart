import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light(1, 'ライト'),
  dark(2, 'ダーク');

  const AppThemeMode(this.colorId, this.displayName);
  final int colorId;
  final String displayName;

  static AppThemeMode fromColorId(int colorId) {
    switch (colorId) {
      case 1:
        return AppThemeMode.light;
      case 2:
        return AppThemeMode.dark;
      default:
        return AppThemeMode.light;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';

  AppThemeMode _currentTheme = AppThemeMode.light;
  bool _isInitialized = false;
  bool _disposed = false;
  bool _themeChanged = false;
  Future<void>? _initializing;
  late final ThemeData _lightTheme = _buildLightTheme();
  late final ThemeData _darkTheme = _buildDarkTheme();

  AppThemeMode get currentTheme => _currentTheme;
  int get colorId => _currentTheme.colorId;
  bool get isDarkMode => _currentTheme == AppThemeMode.dark;
  bool get isInitialized => _isInitialized;

  // アプリの統一テーマデータを取得
  ThemeData get lightTheme => _lightTheme;
  ThemeData get darkTheme => _darkTheme;
  ThemeData get currentThemeData => isDarkMode ? darkTheme : lightTheme;

  /// 初期化（SharedPreferencesからテーマを読み込み）
  Future<void> initialize() {
    if (_isInitialized || _disposed) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_disposed && !_themeChanged) {
        _currentTheme = AppThemeMode.fromColorId(prefs.getInt(_themeKey) ?? 1);
      }
    } catch (e) {
      debugPrint('テーマ初期化エラー: $e');
    } finally {
      if (!_disposed) {
        _isInitialized = true;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// テーマ変更（colorIdと互換性のある方法）
  Future<void> setColorScheme(int colorId) async {
    if (_disposed) return;
    _themeChanged = true;
    final newTheme = AppThemeMode.fromColorId(colorId);

    _currentTheme = newTheme;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _currentTheme.colorId);
    } catch (e) {
      debugPrint('テーマ保存エラー: $e');
    }
  }

  /// テーマモード直接変更
  Future<void> setThemeMode(AppThemeMode mode) async {
    await setColorScheme(mode.colorId);
  }

  /// ダークモード切り替え（既存のAPI互換性のため）
  Future<void> toggleDarkMode() async {
    final newMode = isDarkMode ? AppThemeMode.light : AppThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// ライトテーマの定義
  ThemeData _buildLightTheme() {
    const primaryColor = Colors.blue;
    const backgroundColor = Colors.white;
    const surfaceColor = Color(0xFFF5F5F5);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: surfaceColor,
      ),

      // AppBar テーマ
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),

      // Scaffold テーマ
      scaffoldBackgroundColor: backgroundColor,

      // BottomNavigationBar テーマ
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Card テーマ
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ListTile テーマ
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // Text テーマ
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Colors.black87),
        headlineMedium: TextStyle(color: Colors.black87),
        headlineSmall: TextStyle(color: Colors.black87),
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black87),
        bodySmall: TextStyle(color: Colors.black54),
      ),
    );
  }

  /// ダークテーマの定義
  ThemeData _buildDarkTheme() {
    const primaryColor = Colors.blue;
    const backgroundColor = Color(0xFF121212);
    const surfaceColor = Color(0xFF1E1E1E);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        surface: surfaceColor,
      ),

      // AppBar テーマ
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Scaffold テーマ
      scaffoldBackgroundColor: backgroundColor,

      // BottomNavigationBar テーマ
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Card テーマ
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ListTile テーマ
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        textColor: Colors.white,
        iconColor: Colors.white70,
      ),

      // Text テーマ
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Colors.white),
        headlineMedium: TextStyle(color: Colors.white),
        headlineSmall: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),
      ),
    );
  }
}
