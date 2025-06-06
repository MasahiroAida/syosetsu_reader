import 'package:flutter/material.dart';
import 'views/screens/main_screen.dart';
import 'views/screens/webview_screen.dart';
import 'views/screens/search_screen.dart';

class NovelReaderApp extends StatelessWidget {
  const NovelReaderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小説リーダー',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
      routes: {
        '/webview': (context) => const WebViewScreen(
              novelId: '',
              title: '',
            ),
        '/search': (context) => const SearchScreen(),
      },
    );
  }
}