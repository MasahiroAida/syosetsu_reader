import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'views/screens/main_screen.dart';
import 'views/screens/webview_screen.dart';
import 'views/screens/search_screen.dart';

class NovelReaderApp extends StatelessWidget {
  const NovelReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..initialize()),
        ChangeNotifierProxyProvider<ThemeProvider, SettingsViewModel>(
          create: (_) => SettingsViewModel()..loadSettings(),
          update: (_, theme, settings) => settings!..setThemeProvider(theme),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: '小説リーダー',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const MainScreen(),
            routes: {
              '/webview': (context) => const WebViewScreen(
                    novelId: '',
                    title: '',
                  ),
              '/search': (context) => const SearchScreen(),
            },
          );
        },
      ),
    );
  }
}
