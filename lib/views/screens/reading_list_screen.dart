import 'package:flutter/material.dart';
import '../tabs/bookmark_tab.dart';
import '../tabs/history_tab.dart';

class ReadingListScreen extends StatefulWidget {
  const ReadingListScreen({Key? key}) : super(key: key);

  @override
  State<ReadingListScreen> createState() => _ReadingListScreenState();
}

class _ReadingListScreenState extends State<ReadingListScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  
  // タブの状態を保持するために各ウィジェットを保持
  late final List<Widget> _tabs;

  @override
  bool get wantKeepAlive => true; // ページ全体の状態を保持

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // タブのウィジェットを初期化時に一度だけ作成
    _tabs = const [
      BookmarkTab(),
      HistoryTab(),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixinのために必要
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('読書中'),
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