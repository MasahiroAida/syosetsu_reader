import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import '../../viewmodels/webview_viewmodel.dart';
import '../../models/reading_history.dart';
import '../../providers/theme_provider.dart';
import '../../utils/theme_helper.dart';

class WebViewScreen extends StatefulWidget {
  final String novelId;
  final String title;
  final String? url;

  const WebViewScreen({
    Key? key,
    required this.novelId,
    required this.title,
    this.url,
  }) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  late WebViewViewModel _viewModel;
  bool _hasScrolledToTitle = false;
  int _currentChapter = 0;
  double _scrollPosition = 180.0;
  String? _currentUrl;

  // WebViewの初期化状態を管理する変数を追加
  bool _isWebViewInitialized = false;
  bool _isWebViewDisplayed = false; // WebViewが表示されたタイミングを追跡

  // 小説の種類を判定するフィールドを追加
  bool _isSerialNovel = false; // 連載小説かどうか
  Map<String, dynamic>? _novelDetails; // API から取得した小説詳細情報

  bool _isAppInBackground = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ライフサイクル監視を追加
    _viewModel = WebViewViewModel();
    _initializeWebView();
    _viewModel.checkBookmarkStatus(widget.novelId);
    _loadFromHistory();
    
    // テーマ変更を監視してWebViewのテーマを同期
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToThemeChanges();
    });
  }
  
  // アプリのライフサイクル変化を監視
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // アプリがバックグラウンドに移行する時に保存
        _isAppInBackground = true;
        _savePositionOnExit();
        break;
      case AppLifecycleState.resumed:
        _isAppInBackground = false;
        break;
      case AppLifecycleState.detached:
        // アプリが完全に終了する時も保存
        _savePositionOnExit();
        break;
      default:
        break;
    }
  }

  bool _isSerialNovelFromUrl(String url) {
    final serialRegex =
        RegExp(r'https://ncode\.syosetu\.com/([^/]+)/([0-9]+)/?.*');
    return serialRegex.hasMatch(url);
  }

  /// 適切なURLを構築
  String _buildNovelUrl(int chapter) {
    final baseUrl = 'https://ncode.syosetu.com/${widget.novelId.toLowerCase()}/';
    
    if (_isSerialNovel && chapter > 0) {
      return '${baseUrl}$chapter/';
    } else {
      return baseUrl; // 目次または短編の場合
    }
  }

  /// 現在のURLから章番号を抽出し、`_currentChapter`も更新する
  int _extractChapterFromUrl(String url) {
    if (!_isSerialNovel) {
      print('目次/短編小説のURLを検出: $url');
      _currentChapter = 0; // 目次/短編の場合は章番号なし
      return 0;
    }

    final regex =
        RegExp(r'https://ncode\.syosetu\.com/([^/]+)/([0-9]+)/?.*');
    final match = regex.firstMatch(url);

    if (match != null) {
      print('連載小説のURLを検出: $url');
      final chapter = int.tryParse(match.group(2)!) ?? 0;
      _currentChapter = chapter;
      return chapter;
    }

    _currentChapter = 0;
    return 0;
  }

  /// URLから小説詳細情報を取得し、小説の種類を判定
  Future<void> _fetchNovelDetailsAndUpdateType(String url) async {
    try {
      print('小説詳細情報を取得中...: $url');

      // URLが小説ページかどうか確認
      final ncode = _viewModel.extractNcodeFromUrl(url);
      if (ncode == null) {
        print('小説URLではないため詳細取得を中止します: $url');
        _novelDetails = null;
        return;
      }

      // API から小説詳細情報を取得
      final novelDetails = await _viewModel.fetchNovelDetailsFromUrl(url);
      _extractChapterFromUrl(url);
      if (novelDetails != null) {
        _novelDetails = novelDetails;
        
        // APIから小説の種類を判定
        _isSerialNovel = _viewModel.isSerialNovel(novelDetails);
        
        print('小説詳細取得完了:');
        print('  タイトル: ${_viewModel.getNovelTitle(novelDetails)}');
        print('  作者: ${_viewModel.getNovelAuthor(novelDetails)}');
        print('  種類: ${_isSerialNovel ? "連載" : "短編"}');
        print('  総話数: ${_viewModel.getTotalChapters(novelDetails)}');
        print('  ジャンル: ${_viewModel.getNovelGenre(novelDetails)}');
        
        // UIを更新
        setState(() {});
      } else {
        print('小説詳細情報の取得に失敗しました');
        // フォールバック: URLから小説の種類を判定
        _isSerialNovel = _isSerialNovelFromUrl(url);
      }
    } catch (e) {
      print('小説詳細情報取得エラー: $e');
      // フォールバック: URLから小説の種類を判定
      _isSerialNovel = _isSerialNovelFromUrl(url);
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) async {
            _viewModel.updateLoadingState(true);
            _hasScrolledToTitle = false;
            _currentUrl = url;
            print('ページ読み込み開始: $url');
            
            // 定期保存を停止
            _stopPeriodicScrollSave();
            
            _extractChapterFromUrl(url);
            
            // 新しいURLに対して小説詳細情報を取得
            await _fetchNovelDetailsAndUpdateType(url);
            
            if (!_isWebViewDisplayed) {
              _isWebViewDisplayed = true;
              _scheduleInitialScroll();
            }
          },
          onPageFinished: (String url) async {
            print('ページ読み込み完了: $url');
            _viewModel.updateLoadingState(false);
            
            if (!_isWebViewInitialized) {
              _isWebViewInitialized = true;
              print('WebView初期化完了');
              
              // 初期化完了後に定期保存を開始
              _startPeriodicScrollSave();
            }
            
            _updateNavigationState();
            
            try {
              await _updateChapterFromUrl(url);
              
              // 小説URLの場合は閲覧履歴に自動登録・更新
              await _autoAddToHistory(url);
              
              if (!_hasScrolledToTitle) {
                await _scrollToTitle();
                _hasScrolledToTitle = true;
              }
            } catch (e) {
              print('ページ処理エラー: $e');
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView リソースエラー: ${error.description}');
            _isWebViewInitialized = false;
            _stopPeriodicScrollSave();
          },
          onNavigationRequest: (NavigationRequest request) {
            print('ナビゲーションリクエスト: ${request.url}');
            
            // ページ遷移前に現在の位置を保存
            if (isWebViewReady) {
              _savePositionOnExit();
            }
            
            return NavigationDecision.navigate;
          },
        ),
      );

    _controller.setOnConsoleMessage((JavaScriptConsoleMessage message) {
      print('WebView Console [${message.level.name}]: ${message.message}');
    });
  }

  /// 小説URLの場合に閲覧履歴に自動登録・更新
  Future<void> _autoAddToHistory(String url) async {
    try {
      // なろうの小説URLかどうかチェック
      final ncode = _viewModel.extractNcodeFromUrl(url);
      if (ncode == null) {
        print('小説URLではないため履歴登録をスキップ: $url');
        return;
      }
      
      print('小説URLを検出、履歴に自動登録: $url');
      
      // 現在のスクロール位置を取得（初回の場合は0）
      double currentScrollPosition = 0.0;
      try {
        currentScrollPosition = await _getCurrentScrollPosition();
      } catch (e) {
        print('スクロール位置取得失敗、0で設定: $e');
      }
      
      // API情報を使用してより正確な履歴を作成
      final actualTitle = _novelDetails != null 
          ? _viewModel.getNovelTitle(_novelDetails!) 
          : widget.title;
      final actualAuthor = _novelDetails != null 
          ? _viewModel.getNovelAuthor(_novelDetails!) 
          : 'Unknown';
      final totalChapters = _novelDetails != null 
          ? _viewModel.getTotalChapters(_novelDetails!) 
          : (_isSerialNovel ? 100 : 1);
      
      final history = ReadingHistory(
        id: ncode,
        novelId: ncode,
        novelTitle: actualTitle,
        author: actualAuthor,
        currentChapter: _currentChapter,
        totalChapters: totalChapters,
        lastViewed: DateTime.now(),
        url: url,
        scrollPosition: currentScrollPosition,
        isSerialNovel: _isSerialNovel,
      );
      
      await _viewModel.addToHistory(history, novelData: _novelDetails);
      print('閲覧履歴に自動登録完了: $ncode (第${_currentChapter}章)');
    } catch (e) {
      print('閲覧履歴自動登録エラー: $e');
    }
  }

  /// スクロール位置を定期的に保存（新機能）
  Timer? _scrollSaveTimer;
  double _lastSavedScrollPosition = 0.0;

  void _startPeriodicScrollSave() {
    // 30秒ごとにスクロール位置を保存
    _scrollSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted || !isWebViewReady) return;
      
      try {
        final currentScroll = await _getCurrentScrollPosition();
        
        // 前回保存した位置から50px以上変化があった場合のみ保存
        if ((currentScroll - _lastSavedScrollPosition).abs() > 50) {
          await _viewModel.updateReadingPosition(
            widget.novelId, 
            _currentChapter, 
            currentScroll
          );
          _lastSavedScrollPosition = currentScroll;
          print('定期保存実行: scroll=$currentScroll');
        }
      } catch (e) {
        print('定期保存エラー: $e');
      }
    });
  }

  void _stopPeriodicScrollSave() {
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = null;
  }

  /// WebView表示直後のスクロール処理をスケジュール
  void _scheduleInitialScroll() {
    // 複数のタイミングでスクロールを試行
    _attemptScrollToPosition(0);   // 0.01秒後
  }

  /// 指定したディレイ後にスクロール位置への移動を試行
  void _attemptScrollToPosition(int delayMs) {
    Timer(Duration(milliseconds: delayMs), () async {
      if (_scrollPosition > 0 && mounted) {
        try {
          await _scrollToPosition(_scrollPosition);
          print('スクロール試行 (${delayMs}ms後): position=$_scrollPosition');
        } catch (e) {
          print('スクロール試行失敗 (${delayMs}ms後): $e');
        }
      }
    });
  }

  Future<void> _loadFromHistory() async {
    final history = await _viewModel.getHistoryItem(widget.novelId);
    if (history != null) {
      _currentChapter = history.currentChapter;
      _scrollPosition = history.scrollPosition ?? 0.0;
      
      // 保存されたURLから小説の種類を判定（後でAPIからも取得）
      if (history.url != null) {
        _isSerialNovel = _isSerialNovelFromUrl(history.url!);
      }
      
      // 適切なURLを構築して読み込み
      final targetUrl = widget.url ?? _buildNovelUrl(_currentChapter);
      _controller.loadRequest(Uri.parse(targetUrl));
    } else {
      // 履歴がない場合は初期URLを読み込み
      final targetUrl = widget.url ?? _buildNovelUrl(0);
      _controller.loadRequest(Uri.parse(targetUrl));
    }
  }

  Future<void> _updateChapterFromUrl(String url) async {
    // 小説種別はAPIから取得した情報を使用
    if (_isSerialNovel) {
      // 連載小説の場合：章番号を抽出
      final previousChapter = _currentChapter;
      final chapterFromUrl = _extractChapterFromUrl(url);

      if (chapterFromUrl > 0 && chapterFromUrl != previousChapter) {
        print('連載小説 - チャプター更新: $previousChapter -> $chapterFromUrl');
        await _updateReadingProgress();
      }
    } else {
      // 目次/短編の場合：章番号は0に設定
      if (_currentChapter != 0) {
        print('目次/短編小説 - チャプターを0に設定');
        _currentChapter = 0;
        await _updateReadingProgress();
      }
    }
  }

  /// 読書進捗（チャプター）を更新
  Future<void> _updateReadingProgress() async {
    try {
      // 読書履歴のチャプターを更新
      await _viewModel.updateReadingChapter(widget.novelId, _currentChapter);
      
      // ブックマーク済みの場合はブックマークのチャプターも更新
      if (_viewModel.isBookmarked) {
        await _viewModel.updateBookmarkChapter(widget.novelId, _currentChapter);
        print('ブックマークのチャプターを更新: $_currentChapter');
      }
      
      print('読書進捗を更新: チャプター $_currentChapter');
    } catch (e) {
      print('読書進捗更新エラー: $e');
    }
  }

  Future<void> _scrollToTitle() async {
    const scrollScript = '''
      (function() {
        try {
          const titleElement = document.querySelector('.p-novel__title.p-novel__title--rensai') || 
                              document.querySelector('.p-novel__title') ||
                              document.querySelector('h1') ||
                              document.querySelector('.title');
          
          if (titleElement) {
            titleElement.scrollIntoView({ 
              behavior: 'smooth', 
              block: 'start' 
            });
            return true;
          }
          
          // タイトル要素が見つからない場合はページの上部にスクロール
          window.scrollTo({
            top: 0,
            behavior: 'smooth'
          });
          return false;
        } catch (e) {
          console.log('タイトルスクロールエラー:', e);
          try {
            window.scrollTo(0, 0);
          } catch (e2) {
            console.log('強制スクロールもエラー:', e2);
          }
          return false;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(scrollScript);
    } catch (e) {
      debugPrint('Error scrolling to title: $e');
    }
  }

  Future<void> _scrollToPosition(double position) async {
    if (position <= 0) return; // 無効な位置の場合は何もしない
    
    final scrollScript = '''
      (function() {
        try {
          if (typeof window !== 'undefined' && window.scrollTo) {
            // 即座にスクロール（behaviorなし）
            window.scrollTo(0, $position);
            console.log('スクロール実行: ' + $position);
            return true;
          }
          return false;
        } catch (e) {
          console.log('スクロール位置設定エラー:', e);
          return false;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(scrollScript);
    } catch (e) {
      debugPrint('Error scrolling to position: $e');
    }
  }

  Future<double> _getCurrentScrollPosition() async {
    // より安全なスクロール位置取得JavaScript
    const scrollScript = '''
      (function() {
        try {
          // 複数の方法でスクロール位置を取得し、最初に有効な値を返す
          var scrollTop = 0;
          
          // 方法1: window.pageYOffset
          if (window.pageYOffset !== undefined && window.pageYOffset !== null) {
            scrollTop = window.pageYOffset;
          }
          // 方法2: document.documentElement.scrollTop
          else if (document.documentElement && document.documentElement.scrollTop !== null) {
            scrollTop = document.documentElement.scrollTop;
          }
          // 方法3: document.body.scrollTop
          else if (document.body && document.body.scrollTop !== null) {
            scrollTop = document.body.scrollTop;
          }
          
          // 数値であることを確認
          return isNaN(scrollTop) ? 0 : Math.max(0, scrollTop);
        } catch (e) {
          console.log('スクロール位置取得エラー:', e);
          return 0;
        }
      })();
    ''';

    try {
      final result = await _controller.runJavaScriptReturningResult(scrollScript);
      final scrollPosition = double.tryParse(result.toString()) ?? 0.0;
      print('取得したスクロール位置: $scrollPosition');
      return scrollPosition;
    } catch (e) {
      debugPrint('Error getting scroll position: $e');
      return 0.0;
    }
  }

  Future<void> _updateNavigationState() async {
    try {
      final canGoBack = await _controller.canGoBack();
      final canGoForward = await _controller.canGoForward();
      _viewModel.updateNavigationState(canGoBack, canGoForward);
    } catch (e) {
      print('ナビゲーション状態更新エラー: $e');
    }
  }

  Future<void> _addToHistory() async {
    final currentScrollPosition = await _getCurrentScrollPosition();
    
    // 適切なURLを構築
    final currentUrl = _currentUrl ?? _buildNovelUrl(_currentChapter);
    
    // ncodeを抽出（URLから）
    final ncode = _viewModel.extractNcodeFromUrl(currentUrl) ?? widget.novelId;
    
    // API情報を使用してより正確な履歴を作成
    final actualTitle = _novelDetails != null 
        ? _viewModel.getNovelTitle(_novelDetails!) 
        : widget.title;
    final actualAuthor = _novelDetails != null 
        ? _viewModel.getNovelAuthor(_novelDetails!) 
        : 'Unknown';
    final totalChapters = _novelDetails != null 
        ? _viewModel.getTotalChapters(_novelDetails!) 
        : (_isSerialNovel ? 100 : 1);
    
    final history = ReadingHistory(
      id: ncode,
      novelId: ncode,
      novelTitle: actualTitle,
      author: actualAuthor,
      currentChapter: _currentChapter,
      totalChapters: totalChapters,
      lastViewed: DateTime.now(),
      url: currentUrl,
      scrollPosition: currentScrollPosition,
      isSerialNovel: _isSerialNovel,
    );
    
    await _viewModel.addToHistory(history, novelData: _novelDetails);
  }

  /// WebView終了時の位置保存
  Future<void> _savePositionOnExit() async {
    // 既に保存処理中、またはWebViewが初期化されていない場合はスキップ
    if (!mounted || !isWebViewReady) {
      print('保存をスキップ: mounted=$mounted, isWebViewReady=$isWebViewReady');
      return;
    }

    try {
      print('読書位置保存開始...');

      // 現在表示中のURLから章番号を再取得
      if (_currentUrl != null) {
        if (_isSerialNovelFromUrl(_currentUrl!)) {
          _extractChapterFromUrl(_currentUrl!);
        } else {
          _currentChapter = 0;
        }
      }

      // タイムアウト付きでスクロール位置を取得
      final currentScrollPosition = await _getCurrentScrollPositionWithTimeout();
      print('取得したスクロール位置: $currentScrollPosition');
      
      // 最低限の履歴情報を保存（スクロール位置を優先的に保存）
      await _saveMinimumHistory(currentScrollPosition);
      
      print('読書位置保存完了: chapter=$_currentChapter, scroll=$currentScrollPosition');
    } catch (e) {
      print('位置保存エラー: $e');
      // エラーが発生した場合も最低限の情報は保存
      await _saveMinimumHistoryFallback();
    }
  }

 // WebViewが初期化されているかチェックするヘルパーメソッド
  bool get isWebViewReady => _isWebViewInitialized && mounted;

  // 安全にJavaScriptを実行するヘルパーメソッド
  Future<void> _safeExecuteJavaScript(String script, {String? errorMessage}) async {
    if (!isWebViewReady) {
      print('WebViewが初期化されていないため、JavaScriptの実行をスキップします');
      return;
    }

    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      print('${errorMessage ?? "JavaScript実行エラー"}: $e');
    }
  }

  @override
  void dispose() {
    print('WebViewScreen dispose開始');
    
    // テーマ変更リスナーを削除
    final themeProvider = ThemeHelper.of(context, listen: false);
    if (themeProvider != null) {
      themeProvider.removeListener(_onThemeChanged);
    }
    
    // ライフサイクル監視を削除
    WidgetsBinding.instance.removeObserver(this);
    
    // 定期保存タイマーを停止
    _stopPeriodicScrollSave();
    
    // 同期的に保存処理を実行（disposeは同期的なので）
    if (isWebViewReady) {
      // WebViewが有効な間に即座に保存を試行
      _executeImmediateSave();
    }
    
    // 初期化フラグをリセット
    _isWebViewInitialized = false;
    
    super.dispose();
    print('WebViewScreen dispose完了');
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<WebViewViewModel>(
        builder: (context, viewModel, child) {
          // APIから取得したタイトルがある場合はそれを使用
          final displayTitle = _novelDetails != null 
              ? _viewModel.getNovelTitle(_novelDetails!, fallbackTitle: widget.title)
              : widget.title;
              
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 45,
              title: Text(
                displayTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold)
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _controller.reload(),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showMoreOptions(viewModel),
                ),
              ],
            ),
            body: SafeArea(
              child: WebViewWidget(controller: _controller),
            ),
            bottomNavigationBar: SafeArea(
              child: _buildBottomNavigationBar(viewModel),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar(WebViewViewModel viewModel) {
    return Container(
      height: 35,
      decoration: ThemeHelper.getBoxDecoration(
        context,
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: viewModel.canGoBack
                ? () => _controller.goBack()
                : null,
            tooltip: '戻る',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: viewModel.canGoForward
                ? () => _controller.goForward()
                : null,
            tooltip: '進む',
          ),
          IconButton(
            icon: Icon(
              viewModel.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color: viewModel.isBookmarked ? Colors.orange : null,
            ),
            onPressed: () => _toggleBookmark(viewModel),
            tooltip: viewModel.isBookmarked ? 'ブックマーク削除' : 'ブックマーク追加',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showWebViewSettings(viewModel),
            tooltip: '表示設定',
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark(WebViewViewModel viewModel) async {
    try {
      final currentScrollPosition = await _getCurrentScrollPosition();
      
      if (_viewModel.isBookmarked) {
        // ブックマーク削除
        final success = await viewModel.removeBookmark(widget.novelId);
        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ブックマークから削除しました'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // ブックマーク追加
        await _addBookmarkViaWeb();
        
        // API情報を使用してより正確なブックマークを追加
        final actualTitle = _novelDetails != null 
            ? _viewModel.getNovelTitle(_novelDetails!, fallbackTitle: widget.title)
            : widget.title;
            
        final success = await viewModel.addBookmark(
          widget.novelId, 
          actualTitle,
          currentChapter: _currentChapter,
          scrollPosition: currentScrollPosition,
          isSerialNovel: _isSerialNovel,
          novelData: _novelDetails, // API情報を渡す
        );
        
        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isSerialNovel 
                  ? 'ブックマークに追加しました (第${_currentChapter}章)'
                  : 'ブックマークに追加しました'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('ブックマーク操作エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ブックマーク操作に失敗しました'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// タイムアウト付きでスクロール位置を取得
  Future<double> _getCurrentScrollPositionWithTimeout() async {
    try {
      // 3秒でタイムアウト
      return await _getCurrentScrollPosition().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('スクロール位置取得がタイムアウトしました');
          return _scrollPosition; // 最後に保存された位置を返す
        },
      );
    } catch (e) {
      print('スクロール位置取得エラー: $e');
      return _scrollPosition; // 最後に保存された位置を返す
    }
  }

  /// 最低限の履歴情報を保存
  Future<void> _saveMinimumHistory(double scrollPosition) async {
    try {
      // 読書履歴のスクロール位置を更新
      await _viewModel.updateReadingPosition(
        widget.novelId, 
        _currentChapter, 
        scrollPosition
      );
      
      // ブックマーク済みの場合はブックマークの位置も更新
      if (_viewModel.isBookmarked) {
        await _viewModel.updateBookmarkPosition(
          widget.novelId, 
          _currentChapter, 
          scrollPosition
        );
        print('ブックマーク位置も更新完了');
      }
    } catch (e) {
      print('履歴保存エラー: $e');
      rethrow; // エラーを上位に伝播
    }
  }

  /// フォールバック用の最低限保存
  Future<void> _saveMinimumHistoryFallback() async {
    try {
      // エラー時は現在の章番号だけでも保存
      await _viewModel.updateReadingPosition(
        widget.novelId, 
        _currentChapter, 
        0.0 // スクロール位置は0として保存
      );
      print('フォールバック保存完了: chapter=$_currentChapter');
    } catch (e) {
      print('フォールバック保存も失敗: $e');
    }
  }

  /// テーマ変更を監視してWebViewのテーマを自動同期
  void _listenToThemeChanges() {
    final themeProvider = ThemeHelper.of(context, listen: false);
    if (themeProvider != null) {
      themeProvider.addListener(_onThemeChanged);
    }
  }
  
  /// テーマ変更時のコールバック
  void _onThemeChanged() {
    if (!mounted || !isWebViewReady) return;
    
    final themeProvider = ThemeHelper.of(context, listen: false);
    if (themeProvider != null) {
      final colorId = themeProvider.colorId;
      print('テーマ変更を検知: colorId=$colorId');
      
      // WebView内のテーマを自動更新
      _setColorScheme(colorId);
    }
  }
  
  /// dispose時の即座の保存処理
  void _executeImmediateSave() {
    // Future.microtaskを使用して非同期処理を同期的なコンテキストで実行
    Future.microtask(() async {
      try {
        final scrollPosition = await _getCurrentScrollPositionWithTimeout();
        await _saveMinimumHistory(scrollPosition);
        print('dispose時の即座保存完了');
      } catch (e) {
        print('dispose時の保存エラー: $e');
        // エラー時はフォールバック保存
        await _saveMinimumHistoryFallback();
      }
    }).catchError((e) {
      print('dispose時の保存処理で予期しないエラー: $e');
    });
  }

  /// Webサイトのブックマーク機能を利用してブックマーク追加
  Future<void> _addBookmarkViaWeb() async {
    const bookmarkScript = '''
      (function() {
        try {
          // ブックマーク追加のボタンまたはリンクを探す
          const bookmarkButton = document.querySelector('.js-bookmark_url') ||
                                document.querySelector('[onclick*="bookmark"]') ||
                                document.querySelector('a[href*="favnovelmain/addajax"]') ||
                                document.querySelector('input[value*="favnovelmain/addajax"]');
          
          if (bookmarkButton) {
            // hidden inputの場合、valueからURLを取得してAjaxリクエストを送信
            if (bookmarkButton.type === 'hidden' && bookmarkButton.value) {
              const url = bookmarkButton.value;
              
              // XMLHttpRequestでブックマーク追加
              const xhr = new XMLHttpRequest();
              xhr.open('POST', url, true);
              xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
              xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
              xhr.onreadystatechange = function() {
                if (xhr.readyState === 4) {
                  console.log('ブックマーク追加レスポンス:', xhr.status, xhr.responseText);
                }
              };
              xhr.send();
              return true;
            }
            // 通常のボタンやリンクの場合
            else if (bookmarkButton.click) {
              bookmarkButton.click();
              return true;
            }
          }
          
          console.log('ブックマークボタンが見つかりませんでした');
          return false;
        } catch (e) {
          console.log('ブックマーク追加エラー:', e);
          return false;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(bookmarkScript);
    } catch (e) {
      debugPrint('Error adding bookmark via web: $e');
      rethrow;
    }
  }

  /// 文字サイズ調整
  Future<void> _adjustFontSize({required bool increase}) async {
    final script = '''
      (function() {
        try {
          const ${increase ? 'increment' : 'decrement'} = document.querySelector('a[name="fontsize_${increase ? 'inc' : 'dec'}"]');
          if (${increase ? 'increment' : 'decrement'}) {
            ${increase ? 'increment' : 'decrement'}.click();
            return true;
          }
          
          // 直接スタイル調整
          const content = document.querySelector('.p-novel__body') || document.querySelector('body');
          if (content) {
            const currentSize = parseFloat(window.getComputedStyle(content).fontSize) || 16;
            const newSize = ${increase ? 'currentSize + 2' : 'Math.max(currentSize - 2, 10)'};
            content.style.fontSize = newSize + 'px';
            return true;
          }
          return false;
        } catch (e) {
          console.log('文字サイズ調整エラー:', e);
          return false;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      debugPrint('Error adjusting font size: $e');
    }
  }

  /// 配色設定
  Future<void> _setColorScheme(int colorId) async {
    final script = '''
      (function() {
        try {
          const colorRadio = document.querySelector('#color$colorId');
          if (colorRadio) {
            colorRadio.checked = true;
            // changeイベントを発火
            const event = new Event('change', { bubbles: true });
            colorRadio.dispatchEvent(event);
            colorRadio.click();
            return true;
          }
          return false;
        } catch (e) {
          console.log('配色変更エラー:', e);
          return false;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      debugPrint('Error setting color scheme: $e');
    }
  }

  /// 行間調整
  Future<void> _adjustLineHeight({required bool increase}) async {
    final script = '''
      (function() {
        try {
          const ${increase ? 'increment' : 'decrement'} = document.querySelector('a[name="lineheight_${increase ? 'inc' : 'dec'}"]');
          if (${increase ? 'increment' : 'decrement'}) {
            ${increase ? 'increment' : 'decrement'}.click();
            return true;
          }
          
          // 直接スタイル調整
          const content = document.querySelector('.p-novel__body') || document.querySelector('body');
          if (content) {
            const currentHeight = parseFloat(window.getComputedStyle(content).lineHeight) || 1.5;
            const newHeight = ${increase ? 'Math.min(currentHeight + 0.1, 3.0)' : 'Math.max(currentHeight - 0.1, 1.0)'};
            content.style.lineHeight = newHeight;
            return true;
          }
          return false;
        } catch (e) {
          console.log('行間調整エラー:', e);
          return false;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      debugPrint('Error adjusting line height: $e');
    }
  }

  /// 表示設定リセット
  Future<void> _resetDisplaySettings() async {
    const script = '''
      (function() {
        try {
          // フォントサイズリセット
          const fontReset = document.querySelector('a[name="fontsize_reset"]');
          if (fontReset) fontReset.click();
          
          // 行間リセット
          const lineReset = document.querySelector('a[name="lineheight_reset"]');
          if (lineReset) lineReset.click();
          
          // 標準設定（color1）に変更
          const color1 = document.querySelector('#color1');
          if (color1) {
            color1.checked = true;
            const event = new Event('change', { bubbles: true });
            color1.dispatchEvent(event);
          }
          
          return true;
        } catch (e) {
          console.log('設定リセットエラー:', e);
          return false;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      debugPrint('Error resetting display settings: $e');
    }
  }

  void _showMoreOptions(WebViewViewModel viewModel) {
    // API情報があればそれを使用、なければフォールバック値を使用
    final novelTitle = _novelDetails != null 
        ? _viewModel.getNovelTitle(_novelDetails!) 
        : widget.title;
    final totalChapters = _novelDetails != null 
        ? _viewModel.getTotalChapters(_novelDetails!) 
        : null;
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'その他のオプション',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_novelDetails != null) ...[
                const SizedBox(height: 8),
                Text(
                  '作者: ${_viewModel.getNovelAuthor(_novelDetails!)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Text(
                  'ジャンル: ${_viewModel.getNovelGenre(_novelDetails!)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                if (totalChapters != null)
                  Text(
                    '総話数: $totalChapters話',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
              ],
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.home),
                title: Text(_isSerialNovel ? '目次へ' : 'ホームページへ'),
                onTap: () {
                  Navigator.pop(context);
                  _controller.loadRequest(
                    Uri.parse(_buildNovelUrl(0)), // 目次または短編のトップページ
                  );
                },
              ),
              if (_isSerialNovel) ...[
                ListTile(
                  leading: const Icon(Icons.skip_previous),
                  title: const Text('前の章へ'),
                  onTap: _currentChapter > 1 ? () {
                    Navigator.pop(context);
                    final prevChapterUrl = _buildNovelUrl(_currentChapter - 1);
                    _controller.loadRequest(Uri.parse(prevChapterUrl));
                  } : null,
                ),
                ListTile(
                  leading: const Icon(Icons.skip_next),
                  title: Text(totalChapters != null && _currentChapter >= totalChapters
                      ? '次の章へ (最新話まで読了済み)'
                      : '次の章へ'),
                  onTap: () {
                    Navigator.pop(context);
                    final nextChapterUrl = _buildNovelUrl(_currentChapter + 1);
                    _controller.loadRequest(Uri.parse(nextChapterUrl));
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.vertical_align_top),
                title: const Text('タイトルまでスクロール'),
                onTap: () {
                  Navigator.pop(context);
                  _scrollToTitle();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('小説情報を表示'),
                onTap: () {
                  Navigator.pop(context);
                  _showNovelInfo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('この作品を共有'),
                onTap: () {
                  Navigator.pop(context);
                  // 現在のページのURLを共有
                  final shareUrl = _currentUrl ?? _buildNovelUrl(_currentChapter);
                  // TODO: Share functionality with shareUrl
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('URL: $shareUrl')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNovelInfo() {
    if (_novelDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('小説情報を読み込み中です...')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_viewModel.getNovelTitle(_novelDetails!)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('作者', _viewModel.getNovelAuthor(_novelDetails!)),
                _buildInfoRow('ジャンル', _viewModel.getNovelGenre(_novelDetails!)),
                _buildInfoRow('種類', _isSerialNovel ? '連載小説' : '短編小説'),
                if (_isSerialNovel)
                  _buildInfoRow('総話数', '${_viewModel.getTotalChapters(_novelDetails!)}話'),
                _buildInfoRow('文字数', '${_novelDetails!['length'] ?? 'N/A'}文字'),
                _buildInfoRow('読了時間', '${_novelDetails!['time'] ?? 'N/A'}分'),
                _buildInfoRow('ブックマーク数', '${_novelDetails!['fav_novel_cnt'] ?? 'N/A'}件'),
                _buildInfoRow('評価ポイント', '${_novelDetails!['global_point'] ?? 'N/A'}pt'),
                if (_novelDetails!['keyword'] != null && _novelDetails!['keyword'].toString().isNotEmpty)
                  _buildInfoRow('キーワード', _novelDetails!['keyword'].toString()),
                const SizedBox(height: 16),
                if (_novelDetails!['story'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'あらすじ:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(_novelDetails!['story'].toString()),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showWebViewSettings(WebViewViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '表示設定',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('文字サイズ大'),
                  subtitle: const Text('読みやすいサイズに調整'),
                  onTap: () {
                    Navigator.pop(context);
                    if (isWebViewReady) {
                      _adjustFontSize(increase: true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('文字サイズを大きくしました')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WebViewの読み込みが完了していません')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('文字サイズ小'),
                  subtitle: const Text('コンパクトなサイズに調整'),
                  onTap: () {
                    Navigator.pop(context);
                    if (isWebViewReady) {
                      _adjustFontSize(increase: false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('文字サイズを小さくしました')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WebViewの読み込みが完了していません')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('ライトモード'),
                  subtitle: const Text('明るい背景色に設定'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (isWebViewReady) {
                      // WebView内のテーマを変更
                      _setColorScheme(1); // color1 = ライトモード
                      
                      // アプリ全体のテーマも変更
                      await ThemeHelper.setThemeMode(
                        context,
                        AppThemeMode.light,
                      );
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ライトモードに変更しました')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WebViewの読み込みが完了していません')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.brightness_2),
                  title: const Text('ダークモード'),
                  subtitle: const Text('暗い背景色に設定'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (isWebViewReady) {
                      // WebView内のテーマを変更
                      _setColorScheme(2); // color2 = ダークモード
                      
                      // アプリ全体のテーマも変更
                      await ThemeHelper.setThemeMode(
                        context,
                        AppThemeMode.dark,
                      );
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ダークモードに変更しました')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WebViewの読み込みが完了していません')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.line_weight),
                  title: const Text('行間広く'),
                  subtitle: const Text('読みやすい行間に調整'),
                  onTap: () {
                    Navigator.pop(context);
                    if (isWebViewReady) {
                      _adjustLineHeight(increase: true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('行間を広くしました')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WebViewの読み込みが完了していません')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.line_weight),
                  title: const Text('行間狭く'),
                  subtitle: const Text('コンパクトな行間に調整'),
                  onTap: () {
                    Navigator.pop(context);
                    if (isWebViewReady) {
                      _adjustLineHeight(increase: false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('行間を狭くしました')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WebViewの読み込みが完了していません')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('設定リセット'),
                  subtitle: const Text('表示設定を初期状態に戻す'),
                  onTap: () {
                    Navigator.pop(context);
                    if (isWebViewReady) {
                      _resetDisplaySettings();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('表示設定をリセットしました')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WebViewの読み込みが完了していません')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}