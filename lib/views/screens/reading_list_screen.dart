import 'package:flutter/material.dart';
import '../tabs/bookmark_tab.dart';
import '../tabs/history_tab.dart';

class ReadingListScreen extends StatefulWidget {
  const ReadingListScreen({Key? key}) : super(key: key);

  @override
  State<ReadingListScreen> createState() => ReadingListScreenState();
}

class ReadingListScreenState extends State<ReadingListScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;

  // タブの状態を保持するために各ウィジェットを保持
  late final List<Widget> _tabs;
  final GlobalKey<BookmarkTabState> _bookmarkKey = GlobalKey();
  final GlobalKey<HistoryTabState> _historyKey = GlobalKey();

  @override
  bool get wantKeepAlive => true; // ページ全体の状態を保持

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // タブのウィジェットを初期化時に一度だけ作成
    _tabs = [
      BookmarkTab(key: _bookmarkKey),
      HistoryTab(key: _historyKey),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void reloadTabs() {
    _bookmarkKey.currentState?.reloadFromDb();
    _historyKey.currentState?.reloadFromDb();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixinのために必要
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('読書中'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'sort_title':
                  if (_tabController.index == 0) {
                    _bookmarkKey.currentState?.sortBookmarks('title');
                  } else {
                    _historyKey.currentState?.sortHistory('title');
                  }
                  break;
                case 'sort_date':
                  if (_tabController.index == 0) {
                    _bookmarkKey.currentState?.sortBookmarks('date');
                  } else {
                    _historyKey.currentState?.sortHistory('date');
                  }
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'sort_title',
                child: ListTile(
                  leading: Icon(Icons.sort_by_alpha),
                  title: Text('タイトル順'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'sort_date',
                child: ListTile(
                  leading: Icon(Icons.access_time),
                  title: Text('更新日時順'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ブックマーク'),
            Tab(text: '閲覧履歴'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _KeepAliveWrapper(child: tab)).toList(),
      ),
    );
  }
}

// タブの状態を保持するためのWrapper
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