import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// テーマ関連のヘルパークラス
class ThemeHelper {
  /// 現在のテーマプロバイダーを取得
  static ThemeProvider? of(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<ThemeProvider>(context, listen: listen);
    } catch (e) {
      return null;
    }
  }

  /// 現在のテーマが初期化されているかチェック
  static bool isInitialized(BuildContext context) {
    final themeProvider = of(context, listen: false);
    return themeProvider?.isInitialized ?? false;
  }

  /// 現在のテーマモードを取得
  static AppThemeMode getCurrentTheme(BuildContext context) {
    final themeProvider = of(context, listen: false);
    return themeProvider?.currentTheme ?? AppThemeMode.light;
  }

  /// 現在のcolorIdを取得
  static int getColorId(BuildContext context) {
    final themeProvider = of(context, listen: false);
    return themeProvider?.colorId ?? 0;
  }

  /// ダークモードかどうかを取得
  static bool isDarkMode(BuildContext context) {
    final themeProvider = of(context, listen: false);
    return themeProvider?.isDarkMode ?? false;
  }

  /// テーマを変更（colorIdベース）
  static Future<void> setColorScheme(BuildContext context, int colorId) async {
    final themeProvider = of(context, listen: false);
    await themeProvider?.setColorScheme(colorId);
  }

  /// テーマを変更（AppThemeModeベース）
  static Future<void> setThemeMode(BuildContext context, AppThemeMode mode) async {
    final themeProvider = of(context, listen: false);
    await themeProvider?.setThemeMode(mode);
  }

  /// ダークモードを切り替え
  static Future<void> toggleDarkMode(BuildContext context) async {
    final themeProvider = of(context, listen: false);
    await themeProvider?.toggleDarkMode();
  }

  /// 統一されたAppBarスタイル取得
  static AppBarTheme getAppBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.appBarTheme;
  }

  /// 統一されたCardスタイル取得
  static CardThemeData getCardTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.cardTheme;
  }

  /// 統一されたBottomNavigationBarスタイル取得
  static BottomNavigationBarThemeData getBottomNavTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.bottomNavigationBarTheme;
  }

  /// SafeAreaの背景色を取得
  static Color getSafeAreaColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.scaffoldBackgroundColor;
  }

  /// プライマリカラーを取得
  static Color getPrimaryColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.primaryColor;
  }

  /// テキストの色を取得
  static Color getTextColor(BuildContext context, {bool secondary = false}) {
    final theme = Theme.of(context);
    if (secondary) {
      return theme.textTheme.bodySmall?.color ?? Colors.grey;
    }
    return theme.textTheme.bodyLarge?.color ?? Colors.black;
  }

  /// アイコンの色を取得
  static Color getIconColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.iconTheme.color ?? Colors.black54;
  }

  /// テーマに基づいたBoxDecorationを取得
  static BoxDecoration getBoxDecoration(
    BuildContext context, {
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
    BoxShape shape = BoxShape.rectangle,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
  }) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: color ?? theme.cardColor,
      borderRadius: shape == BoxShape.circle ? null : borderRadius,
      border: border,
      shape: shape,
      boxShadow: boxShadow,
      gradient: gradient,
    );
  }
}

/// Widget拡張でテーマヘルパーを簡単に使用できるようにする
extension ThemeHelperExtension on Widget {
  /// 現在のテーマに基づいてSafeAreaでラップ
  Widget withSafeArea(BuildContext context) {
    return Container(
      color: ThemeHelper.getSafeAreaColor(context),
      child: SafeArea(child: this),
    );
  }
}
