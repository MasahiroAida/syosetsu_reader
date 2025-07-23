import 'package:flutter/material.dart';
import 'reading_list_screen.dart';
import 'ranking_screen.dart';
import 'review_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import '../../widgets/banner_ad_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  bool _isR18Search = false;
  int _searchTapCount = 0;
  DateTime? _lastSearchTap;

  final GlobalKey<ReadingListScreenState> _readingListKey = GlobalKey();

  // 各画面のインスタンスを一度だけ作成して保持
  late final List<Widget> _screens = [
    ReadingListScreen(key: _readingListKey),
    const RankingScreen(),
    const ReviewScreen(),
    SearchScreen(isR18: _isR18Search),
    const SettingsScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: PageView(
        controller: _pageController,
        physics: _selectedIndex == 3 ? const NeverScrollableScrollPhysics() : null, // 検索画面ではスワイプ無効
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens.map((screen) => _KeepAliveWrapper(child: screen)).toList(),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 読書中画面でのみバナー広告を表示
          if (_selectedIndex == 0) const BannerAdWidget(),
          BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          final now = DateTime.now();

          if (index == 3) {
            if (_lastSearchTap != null && now.difference(_lastSearchTap!) < const Duration(seconds: 2)) {
              _searchTapCount++;
            } else {
              _searchTapCount = 1;
            }
            _lastSearchTap = now;

            if (_searchTapCount >= 5) {
              _searchTapCount = 0;
              _isR18Search = !_isR18Search;
              _screens[3] = SearchScreen(isR18: _isR18Search);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_isR18Search ? 'R18検索モードに切替' : '通常検索モードに戻りました')),
              );
            }
          } else {
            _searchTapCount = 0;
          }

          setState(() {
            _selectedIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          if (index == 0) {
            _readingListKey.currentState?.reloadTabs();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: '読書中',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'ランキング',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'イチオシ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '検索',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
        ],
      ),
    );
  }
}

// ページの状態を保持するためのWrapper
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}