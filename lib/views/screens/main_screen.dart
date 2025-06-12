import 'package:flutter/material.dart';
import 'reading_list_screen.dart';
import 'ranking_screen.dart';
import 'review_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final GlobalKey<ReadingListScreenState> _readingListKey = GlobalKey();

  // 各画面のインスタンスを一度だけ作成して保持
  late final List<Widget> _screens = [
    ReadingListScreen(key: _readingListKey),
    const RankingScreen(),
    const ReviewScreen(),
    const SearchScreen(),
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
      body: PageView(
        controller: _pageController,
        physics: _selectedIndex == 3 ? const NeverScrollableScrollPhysics() : null, // 検索画面ではスワイプ無効
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens.map((screen) => _KeepAliveWrapper(child: screen)).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
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