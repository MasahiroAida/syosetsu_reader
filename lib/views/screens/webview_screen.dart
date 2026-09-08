import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../../viewmodels/webview_viewmodel.dart';
import '../../models/reading_history.dart';
import '../../models/bookmark.dart';
import '../../providers/theme_provider.dart';
import '../../utils/theme_helper.dart';
import '../../utils/novel_url.dart';

class WebViewScreen extends StatefulWidget {
  final String novelId;
  final String title;
  final String? url;

  const WebViewScreen({
    super.key,
    required this.novelId,
    required this.title,
    this.url,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  late WebViewViewModel _viewModel;
  bool _hasScrolledToTitle = false;
  int _currentChapter = 0;
  double _scrollPosition = 0.0;
  int _pageGeneration = 0;
  Future<void>? _pageDetailsFuture;
  String? _restoreTargetUrl;
  ThemeProvider? _themeProvider;
  bool _allowPop = false;
  bool _isClosing = false;
  Future<void>? _positionSaveFuture;
  bool _hasKnownScrollPosition = false;
  final Map<String, double> _sessionScrollPositions = {};

  String _positionKey(NovelUrl page) =>
      '${page.isR18}:${page.ncode}:${page.chapter}';

  NovelUrl? get _currentNovelPage =>
      _currentUrl == null ? null : NovelUrl.parse(_currentUrl!);

  bool _isCurrentPage(int generation) =>
      mounted && generation == _pageGeneration;
  String? _currentUrl;

  // 現在読み込んでいるページで onPageFinished が発火済みかどうかを管理
  bool _pageLoadCompleted = false;

  bool _useNovel18Domain = false;

  // WebViewの初期化状態を管理する変数を追加
  bool _isWebViewInitialized = false;

  bool _isJavaScriptReady = false; // JavaScript実行可能性
  Timer? _initializationTimer; // 初期化確認タイマー
  int _initializationAttempts = 0; // 初期化試行回数
  static const int maxInitializationAttempts = 5; // 最大試行回数

  bool _shouldRestoreScrollPosition = false;
  bool _scrollRestoreCompleted = false;
  final List<Timer> _scrollRestoreTimers = [];
  static const List<int> _scrollRestoreDelaysMs = [
    0,
    50,
    150,
    300,
    600,
    1000,
    1500
  ];
  bool _userInteracted = false;

  // 小説の種類を判定するフィールドを追加
  bool _isSerialNovel = false; // 連載小説かどうか
  Map<String, dynamic>? _novelDetails; // API から取得した小説詳細情報

  // 表示設定
  double _fontSize = 16.0; // フォントサイズをスライダーで調整するための状態

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ライフサイクル監視を追加
    _viewModel = WebViewViewModel();
    _initializeWebView();
    _viewModel.checkBookmarkStatus(widget.novelId);
    if (widget.url != null && widget.url!.contains('novel18.syosetu.com')) {
      _useNovel18Domain = true;
    }
    _loadFromHistory();

    // テーマ変更を監視してWebViewのテーマを同期
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listenToThemeChanges();
    });

    // 定期的な初期化状態チェックを開始
    _startInitializationCheck();
  }

  // アプリのライフサイクル変化を監視
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // アプリがバックグラウンドに移行する時に保存
        _savePositionOnExit();
        break;
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.detached:
        // アプリが完全に終了する時も保存
        _savePositionOnExit();
        break;
      default:
        break;
    }
  }

  bool _isSerialNovelFromUrl(String url) =>
      (NovelUrl.parse(url)?.chapter ?? 0) > 0;

  /// 適切なURLを構築
  String _buildNovelUrl(int chapter) {
    final domain = _useNovel18Domain ? 'novel18' : 'ncode';
    final novelId = _currentNovelPage?.ncode ?? widget.novelId.toLowerCase();
    final baseUrl = 'https://$domain.syosetu.com/$novelId/';

    if (chapter > 0) {
      return '$baseUrl$chapter/';
    } else {
      return baseUrl; // 目次または短編の場合
    }
  }

  Future<void> _fetchNovelDetailsAndUpdateType(String url) async {
    final generation = _pageGeneration;
    final details = await _viewModel.fetchNovelDetailsFromUrl(url);
    if (!_isCurrentPage(generation)) return;
    setState(() {
      _novelDetails = details;
      _isSerialNovel = details != null
          ? _viewModel.isSerialNovel(details)
          : _isSerialNovelFromUrl(url);
    });
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // ページ読み込み進捗をログに出力
            // 0-100 の範囲で進捗が通知される
            debugPrint('ページ読み込み進捗: $progress%');
          },
          onPageStarted: (String url) {
            if (!mounted) return;
            _pageGeneration++;
            _currentUrl = url;
            final page = NovelUrl.parse(url);
            _currentChapter = page?.chapter ?? 0;
            _useNovel18Domain = page?.isR18 ?? false;
            _novelDetails = null;
            _isSerialNovel = (page?.chapter ?? 0) > 0;
            _viewModel.checkBookmarkStatus(page?.ncode ?? '');
            _viewModel.updateLoadingState(true);
            _hasScrolledToTitle = false;
            _pageLoadCompleted = false;
            _hasKnownScrollPosition = false;
            _lastSavedScrollPosition = 0;
            final sessionPosition = page == null
                ? null
                : _sessionScrollPositions[_positionKey(page)];
            if (sessionPosition != null) {
              _scrollPosition = sessionPosition;
              _restoreTargetUrl = url;
            }
            _shouldRestoreScrollPosition = _restoreTargetUrl != null &&
                NovelUrl.matches(url, _restoreTargetUrl!);
            if (!_shouldRestoreScrollPosition) {
              _restoreTargetUrl = null;
              _scrollPosition = 0;
            }
            _stopPeriodicScrollSave();
            _isJavaScriptReady = false;
            _isWebViewInitialized = false;
            _initializationAttempts = 0;
            _initializationTimer?.cancel();
            _resetScrollRestoreState();
            _resetUserInteractionState();
            _pageDetailsFuture = _fetchNovelDetailsAndUpdateType(url);
            if (_shouldRestoreScrollPosition) _scheduleInitialScroll();
          },
          onPageFinished: (String url) async {
            debugPrint('ページ読み込み完了: $url');
            await _handlePageFinished(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView リソースエラー: ${error.description}');

            if (mounted &&
                error.isForMainFrame != false &&
                !error.description.contains('ERR_BLOCKED_BY_ORB')) {
              _viewModel.updateLoadingState(false);
              _isWebViewInitialized = false;
              _isJavaScriptReady = false;
              _stopPeriodicScrollSave();
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            debugPrint('ナビゲーションリクエスト: ${request.url}');

            // ページ遷移前に現在の位置を保存
            if (request.isMainFrame && isWebViewReady) {
              await _savePositionOnExit();
            }
            return mounted
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );

    _controller.setOnConsoleMessage((JavaScriptConsoleMessage message) {
      debugPrint('WebView Console [${message.level.name}]: ${message.message}');
    });
  }

  /// 小説URLの場合に閲覧履歴に自動登録・更新
  Future<void> _autoAddToHistory(String url) async {
    final generation = _pageGeneration;
    try {
      // なろうの小説URLかどうかチェック
      final ncode = _viewModel.extractNcodeFromUrl(url);
      if (ncode == null) {
        debugPrint('小説URLではないため履歴登録をスキップ: $url');
        return;
      }

      debugPrint('小説URLを検出、履歴に自動登録: $url');

      // 現在のスクロール位置を取得（初回の場合は0）
      double currentScrollPosition = 0.0;
      try {
        currentScrollPosition = await _getCurrentScrollPositionWithTimeout();
      } catch (e) {
        debugPrint('スクロール位置取得失敗、0で設定: $e');
      }

      final existingHistory = await _viewModel.getHistoryItem(ncode);
      if (!_isCurrentPage(generation)) return;
      if (_shouldRestoreScrollPosition && !_scrollRestoreCompleted) {
        await _refreshUserInteractionFlag();
        if (!_isCurrentPage(generation)) return;
      }
      if (_shouldRestoreScrollPosition && !_scrollRestoreCompleted) {
        currentScrollPosition = _scrollPosition;
      }

      // API情報を使用してより正確な履歴を作成
      final actualTitle = _novelDetails != null
          ? _viewModel.getNovelTitle(_novelDetails!)
          : (existingHistory?.novelTitle ??
              (ncode == widget.novelId.toLowerCase() ? widget.title : ncode));
      final actualAuthor = _novelDetails != null
          ? _viewModel.getNovelAuthor(_novelDetails!)
          : (existingHistory?.author ?? 'Unknown');
      final totalChapters = _novelDetails != null
          ? _viewModel.getTotalChapters(_novelDetails!)
          : (existingHistory?.totalChapters ??
              (_currentChapter > 0 ? _currentChapter : 1));

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
        isSerialNovel: _novelDetails != null
            ? _isSerialNovel
            : (existingHistory?.isSerialNovel ?? _isSerialNovel),
        lastUpdate: _viewModel.getLastUpdate(_novelDetails) ??
            existingHistory?.lastUpdate,
      );

      await _viewModel.addToHistory(history, novelData: _novelDetails);
      if (!_isCurrentPage(generation)) return;
      await _viewModel.updateBookmarkPosition(
        ncode,
        history.currentChapter,
        history.scrollPosition ?? 0,
      );
      debugPrint('閲覧履歴に自動登録完了: $ncode (第$_currentChapter章)');
    } catch (e) {
      debugPrint('閲覧履歴自動登録エラー: $e');
    }
  }

  /// スクロール位置を定期的に保存（新機能）
  Timer? _scrollSaveTimer;
  double _lastSavedScrollPosition = 0.0;

  void _startPeriodicScrollSave() {
    _stopPeriodicScrollSave();
    _scrollSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && isWebViewReady) _savePositionOnExit();
    });
  }

  void _stopPeriodicScrollSave() {
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = null;
  }

  /// WebView表示直後のスクロール処理をスケジュール
  void _scheduleInitialScroll() {
    if (_scrollPosition < 0 || !_shouldRestoreScrollPosition) return;
    final generation = _pageGeneration;
    _cancelScrollRestoreTimers();
    for (final delayMs in _scrollRestoreDelaysMs) {
      _scrollRestoreTimers.add(
        Timer(Duration(milliseconds: delayMs), () async {
          if (!_isCurrentPage(generation) || _scrollRestoreCompleted) return;
          await _injectUserInteractionListener();
          if (!_isCurrentPage(generation) ||
              await _refreshUserInteractionFlag()) {
            return;
          }
          if (!_isCurrentPage(generation)) return;
          final restored = await _tryRestoreScrollPosition('initial/$delayMs');
          if (_isCurrentPage(generation) && restored) {
            _markScrollRestoreCompleted();
          }
        }),
      );
    }
  }

  void _resetScrollRestoreState() {
    _scrollRestoreCompleted = false;
    _cancelScrollRestoreTimers();
  }

  void _cancelScrollRestoreTimers() {
    for (final timer in _scrollRestoreTimers) {
      timer.cancel();
    }
    _scrollRestoreTimers.clear();
  }

  void _markScrollRestoreCompleted() {
    if (_scrollRestoreCompleted) return;
    _scrollRestoreCompleted = true;
    _restoreTargetUrl = null;
    _cancelScrollRestoreTimers();
  }

  Future<bool> _tryRestoreScrollPosition(String reason) async {
    final generation = _pageGeneration;
    if (_scrollPosition < 0 || !_scrollPosition.isFinite) return false;
    if (await _refreshUserInteractionFlag()) return false;
    if (!_isCurrentPage(generation)) return false;

    final expectedUri = Uri.tryParse(_currentUrl ?? '');
    if (expectedUri == null) return false;
    final scrollScript = '''
      (function() {
        try {
          if (window.location.host !== ${jsonEncode(expectedUri.host)} ||
              window.location.pathname !== ${jsonEncode(expectedUri.path)}) return '{}';
          if (typeof document === 'undefined' || typeof window === 'undefined') {
            return JSON.stringify({ ready: false, height: 0, scrolled: false, y: 0 });
          }
          const ready = document.readyState !== 'loading';
          const body = document.body;
          const docEl = document.documentElement;
          const height = Math.max(
            body ? body.scrollHeight : 0,
            docEl ? docEl.scrollHeight : 0
          );
          if (!ready || height <= 0) {
            return JSON.stringify({ ready: ready, height: height, scrolled: false, y: 0 });
          }
          const target = Math.max(0, $_scrollPosition);
          const viewport = window.innerHeight || 0;
          const maxScroll = Math.max(0, height - viewport);
          const clamped = Math.min(target, maxScroll);
          window.__syosetsuAutoScrollUntil = Date.now() + 300;
          window.scrollTo(0, clamped);
          const y = window.pageYOffset || (docEl ? docEl.scrollTop : 0) || (body ? body.scrollTop : 0) || 0;
          const fullTargetAvailable = target <= maxScroll + 2 || document.readyState === 'complete';
          const success = fullTargetAvailable && Math.abs(y - clamped) <= 2;
          return JSON.stringify({ ready: true, height: height, scrolled: success, y: y });
        } catch (e) {
          return JSON.stringify({ ready: false, height: 0, scrolled: false, y: 0 });
        }
      })();
    ''';

    try {
      final result =
          await _controller.runJavaScriptReturningResult(scrollScript);
      if (!_isCurrentPage(generation)) return false;
      final parsed = _decodeJsonResult(result);
      final scrolled = parsed['scrolled'] == true;
      final height = parsed['height'];
      final y = parsed['y'];
      debugPrint(
          'スクロール復元試行($reason): scrolled=$scrolled height=$height y=$y target=$_scrollPosition');
      return scrolled;
    } catch (e) {
      debugPrint('スクロール復元試行失敗($reason): $e');
      return false;
    }
  }

  Map<String, dynamic> _decodeJsonResult(Object? result) {
    if (result == null) return <String, dynamic>{};
    try {
      final raw = result.toString();
      if (raw.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is String) {
        final nested = jsonDecode(decoded);
        return nested is Map<String, dynamic> ? nested : <String, dynamic>{};
      }
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _resetUserInteractionState() {
    _userInteracted = false;
  }

  void _handleUserInteractionDetected() {
    if (_userInteracted) return;
    _userInteracted = true;
    _markScrollRestoreCompleted();
    _hasScrolledToTitle = true;
  }

  Future<bool> _refreshUserInteractionFlag() async {
    final generation = _pageGeneration;
    if (_userInteracted) return true;
    const checkScript = '''
      (function() {
        try {
          return window.__syosetsuUserInteracted === true;
        } catch (e) {
          return false;
        }
      })();
    ''';

    try {
      final result =
          await _controller.runJavaScriptReturningResult(checkScript);
      if (!_isCurrentPage(generation)) return true;
      final interacted = result.toString() == 'true';
      if (interacted) {
        _handleUserInteractionDetected();
      }
      return interacted;
    } catch (e) {
      return _userInteracted;
    }
  }

  Future<void> _injectUserInteractionListener() async {
    const injectScript = '''
      (function() {
        try {
          if (window.__syosetsuUserInteractionListenerInstalled) return true;
          window.__syosetsuUserInteractionListenerInstalled = true;
          window.__syosetsuUserInteracted = false;
          window.__syosetsuAutoScrollUntil = 0;
          const mark = function() {
            try {
              if (Date.now() < (window.__syosetsuAutoScrollUntil || 0)) return;
              window.__syosetsuUserInteracted = true;
            } catch (e) {}
          };
          window.addEventListener('scroll', mark, { passive: true });
          window.addEventListener('touchstart', mark, { passive: true });
          window.addEventListener('wheel', mark, { passive: true });
          window.addEventListener('mousedown', mark, { passive: true });
          window.addEventListener('keydown', mark, { passive: true });
          return true;
        } catch (e) {
          return false;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(injectScript);
    } catch (e) {
      debugPrint('ユーザー操作検知の注入に失敗: $e');
    }
  }

  Future<void> _loadFromHistory() async {
    final history = await _viewModel.getHistoryItem(widget.novelId);
    if (!mounted) return;
    final targetUrl = widget.url ??
        (history != null && history.url.isNotEmpty
            ? history.url
            : _buildNovelUrl(0));
    final page = NovelUrl.parse(targetUrl);
    _currentChapter = page?.chapter ?? 0;
    _isSerialNovel = history?.isSerialNovel ?? (page?.chapter ?? 0) > 0;
    _useNovel18Domain = page?.isR18 ?? false;
    final savedPosition = history?.scrollPosition;
    if (history != null &&
        savedPosition != null &&
        savedPosition.isFinite &&
        savedPosition >= 0 &&
        NovelUrl.matches(targetUrl, history.url) &&
        page?.chapter == history.currentChapter) {
      _scrollPosition = savedPosition;
      _restoreTargetUrl = targetUrl;
    }
    await _controller.loadRequest(Uri.parse(targetUrl));
  }

  Future<void> _scrollToTitle() async {
    const scrollScript = '''
      (function() {
        try {
          window.__syosetsuAutoScrollUntil = Date.now() + 800;
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

  Future<double> _getCurrentScrollPosition() async {
    final generation = _pageGeneration;
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
      final result =
          await _controller.runJavaScriptReturningResult(scrollScript);
      final scrollPosition = double.tryParse(result.toString());
      if (scrollPosition == null ||
          !scrollPosition.isFinite ||
          scrollPosition < 0) {
        return _lastSavedScrollPosition;
      }
      if (_isCurrentPage(generation)) {
        _lastSavedScrollPosition = scrollPosition;
        _hasKnownScrollPosition = true;
      }
      return scrollPosition;
    } catch (e) {
      debugPrint('Error getting scroll position: $e');
      return _hasKnownScrollPosition
          ? _lastSavedScrollPosition
          : _scrollPosition;
    }
  }

  Future<void> _updateNavigationState() async {
    try {
      final canGoBack = await _controller.canGoBack();
      final canGoForward = await _controller.canGoForward();
      if (mounted) _viewModel.updateNavigationState(canGoBack, canGoForward);
    } catch (e) {
      debugPrint('ナビゲーション状態更新エラー: $e');
    }
  }

  /// ページの読み込み完了時の共通処理
  Future<void> _handlePageFinished(String url) async {
    if (!mounted || url != _currentUrl || _pageLoadCompleted) return;
    final generation = _pageGeneration;
    _pageLoadCompleted = true;
    _isWebViewInitialized = true;
    _viewModel.updateLoadingState(false);
    await _testJavaScriptExecution();
    if (!_isCurrentPage(generation)) return;
    await _injectUserInteractionListener();
    if (!_isCurrentPage(generation)) return;
    if (_isJavaScriptReady) {
      _startPeriodicScrollSave();
    } else {
      _startInitializationCheck();
    }
    await _updateNavigationState();
    if (!_isCurrentPage(generation)) return;

    if (_shouldRestoreScrollPosition) {
      if (!_scrollRestoreCompleted) {
        final restored = await _tryRestoreScrollPosition('pageFinished');
        if (!_isCurrentPage(generation)) return;
        if (restored) _markScrollRestoreCompleted();
      }
      _hasScrolledToTitle = true;
    } else if (!_hasScrolledToTitle && _currentNovelPage != null) {
      final userInteracted = await _refreshUserInteractionFlag();
      if (!_isCurrentPage(generation)) return;
      if (!userInteracted && _isJavaScriptReady) await _scrollToTitle();
      if (!_isCurrentPage(generation)) return;
      _hasScrolledToTitle = true;
    }

    // Saving before restoration would replace the persisted offset with zero.
    await _autoAddToHistory(url);
    if (!_isCurrentPage(generation)) return;
    await _pageDetailsFuture;
    if (!_isCurrentPage(generation)) return;
    if (_novelDetails != null) await _autoAddToHistory(url);
  }

  Future<void> _addToHistory() async {
    final url = _currentUrl;
    if (url != null) await _autoAddToHistory(url);
  }

  Future<void> _savePositionOnExit() {
    return _positionSaveFuture ??= _saveCurrentPosition().whenComplete(() {
      _positionSaveFuture = null;
    });
  }

  Future<void> _saveCurrentPosition() async {
    final page = _currentNovelPage;
    final generation = _pageGeneration;
    if (!isWebViewReady || !_pageLoadCompleted || page == null) return;
    await _refreshUserInteractionFlag();
    if (!_isCurrentPage(generation)) return;
    final position = await _getCurrentScrollPositionWithTimeout();
    if (!_isCurrentPage(generation)) return;
    // A pending restore owns the saved offset until it finishes or the user moves.
    final scroll = _shouldRestoreScrollPosition && !_scrollRestoreCompleted
        ? _scrollPosition
        : position;
    await _saveMinimumHistory(scroll, page: page);
  }

  // WebViewが初期化されているかチェックするヘルパーメソッド
  bool get isWebViewReady =>
      _isWebViewInitialized && _isJavaScriptReady && mounted;

  /// 定期的な初期化状態チェック
  void _startInitializationCheck() {
    _initializationTimer?.cancel();
    _initializationTimer = Timer.periodic(
        const Duration(seconds: 2), (timer) => _checkInitializationStatus());
  }

  Future<void> _checkInitializationStatus() async {
    if (!mounted || _initializationAttempts >= maxInitializationAttempts) {
      _initializationTimer?.cancel();
      return;
    }

    _initializationAttempts++;

    try {
      await _testJavaScriptExecution();

      if (_isJavaScriptReady) {
        debugPrint('WebView初期化完全完了 ($_initializationAttempts回目)');
        _initializationTimer?.cancel();
        if (_pageLoadCompleted && mounted) _startPeriodicScrollSave();
      }
    } catch (e) {
      debugPrint('初期化チェック失敗 ($_initializationAttempts回目): $e');
      if (_initializationAttempts >= maxInitializationAttempts) {
        debugPrint('最大試行回数に達したため強制再初期化を実行');
        await _forceReinitialize();
      }
    }
  }

  Future<void> _testJavaScriptExecution() async {
    final generation = _pageGeneration;
    const testScript = '''
      (function() {
        try {
          if (typeof document === 'undefined' || typeof window === 'undefined') return false;
          if (typeof window.scrollTo !== 'function') return false;
          if (document.readyState === 'loading') return false;
          const testDiv = document.createElement('div');
          if (!testDiv) return false;
          console.log('JavaScript実行テスト: 成功');
          return true;
        } catch (e) {
          console.log('JavaScript実行テスト: エラー', e);
          return false;
        }
      })();
    ''';

    try {
      final result = await _controller.runJavaScriptReturningResult(testScript);
      if (!_isCurrentPage(generation)) return;
      _isJavaScriptReady = result.toString() == 'true';

      if (_isJavaScriptReady) {
        debugPrint('JavaScript実行テスト: 成功');
      } else {
        debugPrint('JavaScript実行テスト: 失敗 - $result');
      }
    } catch (e) {
      debugPrint('JavaScript実行テスト例外: $e');
      if (_isCurrentPage(generation)) _isJavaScriptReady = false;
    }
  }

  Future<void> _forceReinitialize() async {
    try {
      await _savePositionOnExit();
      if (!mounted) return;
      debugPrint('WebView強制再初期化開始');

      _isWebViewInitialized = false;
      _isJavaScriptReady = false;
      _initializationAttempts = 0;

      await _controller.reload();

      debugPrint('WebView強制再初期化完了');
    } catch (e) {
      debugPrint('強制再初期化エラー: $e');
    }
  }

  Future<void> _manualInitializationCheck() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('WebViewの状態を確認中...'),
            ],
          ),
        ),
      );

      _initializationAttempts = 0;
      await _testJavaScriptExecution();
      if (!mounted) return;
      Navigator.of(context).pop();

      if (_isJavaScriptReady) {
        //ScaffoldMessenger.of(context).showSnackBar(
        //  const SnackBar(
        //    content: Text('WebViewの初期化が完了しました'),
        //    backgroundColor: Colors.green,
        //  ),
        //);
      } else {
        _showReinitializationDialog();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      debugPrint('手動初期化チェックエラー: $e');
      _showReinitializationDialog();
    }
  }

  void _showReinitializationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WebView初期化エラー'),
        content: const Text('WebViewの初期化に失敗しました。\nページを再読み込みしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _forceReinitialize();
            },
            child: const Text('再読み込み'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('WebViewScreen dispose開始');

    // テーマ変更リスナーを削除
    _themeProvider?.removeListener(_onThemeChanged);

    // ライフサイクル監視を削除
    WidgetsBinding.instance.removeObserver(this);

    // 定期保存タイマーを停止
    _stopPeriodicScrollSave();

    // 初期化タイマーを停止
    _initializationTimer?.cancel();

    // スクロール復元タイマーを停止
    _cancelScrollRestoreTimers();

    // 同期的に保存処理を実行（disposeは同期的なので）
    if (isWebViewReady) {
      // WebViewが有効な間に即座に保存を試行
      _executeImmediateSave();
    }

    // 初期化フラグをリセット
    _isWebViewInitialized = false;
    _pageGeneration++;
    _viewModel.dispose();
    super.dispose();
    debugPrint('WebViewScreen dispose完了');
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<WebViewViewModel>(
        builder: (context, viewModel, child) {
          // APIから取得したタイトルがある場合はそれを使用
          final displayTitle = _novelDetails != null
              ? _viewModel.getNovelTitle(_novelDetails!,
                  fallbackTitle: widget.title)
              : widget.title;

          return PopScope(
            canPop: _allowPop,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop || _isClosing) return;
              _isClosing = true;
              await _savePositionOnExit();
              if (!mounted) return;
              setState(() => _allowPop = true);
              if (context.mounted) Navigator.of(context).pop(result);
            },
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                toolbarHeight: 45,
                title: Text(displayTitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.0, fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await _savePositionOnExit();
                      if (mounted) await _controller.reload();
                    },
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
            color: Colors.black.withValues(alpha: 0.1),
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
                ? () async {
                    await _savePositionOnExit();
                    if (mounted) await _controller.goBack();
                  }
                : null,
            tooltip: '戻る',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: viewModel.canGoForward
                ? () async {
                    await _savePositionOnExit();
                    if (mounted) await _controller.goForward();
                  }
                : null,
            tooltip: '進む',
          ),
          IconButton(
            icon: Icon(
              viewModel.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color: viewModel.isBookmarked ? Colors.orange : null,
            ),
            onPressed: _currentNovelPage == null || viewModel.isLoading
                ? null
                : () => _toggleBookmark(viewModel),
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
    final page = _currentNovelPage;
    final generation = _pageGeneration;
    if (page == null) return;
    try {
      final currentScrollPosition =
          await _getCurrentScrollPositionWithTimeout();
      if (!_isCurrentPage(generation)) return;

      if (_viewModel.isBookmarked) {
        // ブックマーク削除
        final success = await viewModel.removeBookmark(page.ncode);
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
        if (!_isCurrentPage(generation)) return;

        final history = await _viewModel.getHistoryItem(page.ncode);
        if (!_isCurrentPage(generation)) return;
        final fallbackTitle = history?.novelTitle ??
            (page.ncode == widget.novelId.toLowerCase()
                ? widget.title
                : page.ncode);
        final actualTitle = _viewModel.getNovelTitle(_novelDetails,
            fallbackTitle: fallbackTitle);

        final success = await viewModel.addBookmark(
          page.ncode,
          actualTitle,
          currentChapter: _currentChapter,
          scrollPosition: currentScrollPosition,
          isSerialNovel: _isSerialNovel,
          novelData: _novelDetails, // API情報を渡す
        );

        if (_isCurrentPage(generation) && success) {
          await _addToHistory();
          if (!mounted || !_isCurrentPage(generation)) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isSerialNovel
                  ? 'ブックマークに追加しました (第$_currentChapter章)'
                  : 'ブックマークに追加しました'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ブックマーク操作エラー: $e');
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
          debugPrint('スクロール位置取得がタイムアウトしました');
          return _hasKnownScrollPosition
              ? _lastSavedScrollPosition
              : _scrollPosition;
        },
      );
    } catch (e) {
      debugPrint('スクロール位置取得エラー: $e');
      return _hasKnownScrollPosition
          ? _lastSavedScrollPosition
          : _scrollPosition;
    }
  }

  /// 最低限の履歴情報を保存
  Future<void> _saveMinimumHistory(double scrollPosition,
      {NovelUrl? page}) async {
    final savedPage = page ?? _currentNovelPage;
    if (savedPage == null) return;
    _sessionScrollPositions[_positionKey(savedPage)] = scrollPosition;
    await _viewModel.updateReadingPosition(
        savedPage.ncode, savedPage.chapter, scrollPosition);
    await _viewModel.updateBookmarkPosition(
        savedPage.ncode, savedPage.chapter, scrollPosition);
  }

  /// テーマ変更を監視してWebViewのテーマを自動同期
  void _listenToThemeChanges() {
    _themeProvider = ThemeHelper.of(context, listen: false);
    _themeProvider?.addListener(_onThemeChanged);
  }

  /// テーマ変更時のコールバック
  void _onThemeChanged() {
    if (!mounted || !isWebViewReady) return;

    final themeProvider = ThemeHelper.of(context, listen: false);
    if (themeProvider != null) {
      final colorId = themeProvider.colorId;
      debugPrint('テーマ変更を検知: colorId=$colorId');

      // WebView内のテーマを自動更新
      _setColorScheme(colorId);
    }
  }

  /// dispose時の即座の保存処理
  void _executeImmediateSave() {
    // The platform WebView can already be removed during dispose; use its last
    // successful sample instead of replacing progress with a failed JS result.
    if (_hasKnownScrollPosition && _positionSaveFuture == null) {
      final position = _shouldRestoreScrollPosition && !_scrollRestoreCompleted
          ? _scrollPosition
          : _lastSavedScrollPosition;
      unawaited(_saveMinimumHistory(position));
    }
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

  /// 指定したサイズで文字を設定
  Future<void> _setFontSize(double size) async {
    final script = '''
      (function() {
        try {
          const content = document.querySelector('.p-novel__body') || document.querySelector('body');
          if (content) {
            content.style.fontSize = '${"$size"}px';
            return true;
          }
          return false;
        } catch (e) {
          console.log('フォントサイズ設定エラー:', e);
          return false;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      debugPrint('Error setting font size: $e');
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
            const computed = window.getComputedStyle(content);
            const fontSize = parseFloat(computed.fontSize) || 16;
            const currentHeight = parseFloat(computed.lineHeight) / fontSize || 1.5;
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
      _fontSize = 16.0;
    } catch (e) {
      debugPrint('Error resetting display settings: $e');
    }
  }

  /// ブックマークページからデータを取得するJavaScript
  Future<List<Map<String, dynamic>>> _scrapeBookmarkData() async {
    const scrapeScript = r'''
      (function() {
        try {
          console.log('ブックマークスクレイピング開始...');
          
          // 現在のURLがブックマークページかチェック
          if (!window.location.href.includes('syosetu.com/favnovelmain/list/')) {
            console.log('ブックマークページではありません:', window.location.href);
            return JSON.stringify({ error: 'ブックマークページではありません' });
          }
          
          const items = document.querySelectorAll('.c-up-chk-item__content');
          console.log('見つかった要素数:', items.length);
          
          if (items.length === 0) {
            return JSON.stringify({ error: '要素が見つかりませんでした' });
          }
          
          var bookmarks = [];
          
          items.forEach(function(item, index) {
            try {
              // タイトルとリンクを取得
              var titleElement = item.querySelector('a');
              if (!titleElement) return;
              
              var title = (titleElement.textContent || '').trim() || '';
              var href = titleElement.href || '';
              
              // 小説IDを抽出
              var ncodeMatch = href.match(/\/([a-z0-9]+)\/?$/i);
              var novelId = ncodeMatch ? ncodeMatch[1].toLowerCase() : '';
              
              if (!novelId) return;
              
              // 作者名を取得
              var authorElement = item.querySelector('.c-up-chk-item__author, .author, [class*="author"]');
              var author = authorElement ? 
                (authorElement.textContent || '').trim().replace(/^作者[：:]?\s*/, '') || 'Unknown' 
                : 'Unknown';
              
              // 読書状況を取得
              var progressElement = item.querySelector('.c-up-chk-item__progress, .progress, [class*="progress"]');
              var currentChapter = 0;
              var isSerialNovel = false;
              
              if (progressElement) {
                var progressText = (progressElement.textContent || '').trim();
                console.log('進捗テキスト:', progressText);
                
                // "○話まで読了" or "第○話まで読了" のパターンをチェック
                var chapterMatch = progressText.match(/(第?)(\d+)[話章]まで読了/);
                if (chapterMatch) {
                  currentChapter = parseInt(chapterMatch[2], 10) || 0;
                  isSerialNovel = true;
                } else if (progressText.includes('読了') || progressText.includes('完読')) {
                  // 短編の場合
                  isSerialNovel = false;
                  currentChapter = 0;
                }
              }
              
              // URLから連載/短編を判定（バックアップ判定）
              if (!isSerialNovel) {
                isSerialNovel = /\/\d+\/$/.test(href);
              }
              
              var bookmark = {
                novelId: novelId,
                novelTitle: title,
                author: author,
                currentChapter: currentChapter,
                isSerialNovel: isSerialNovel,
                url: href,
                addedAt: new Date().toISOString(),
                lastViewed: new Date().toISOString()
              };
              
              console.log('ブックマークデータ:', bookmark);
              bookmarks.push(bookmark);
              
            } catch (itemError) {
              console.error('項目処理エラー:', itemError, item);
            }
          });
          
          console.log('スクレイピング完了. 取得数:', bookmarks.length);
          return JSON.stringify({ success: true, bookmarks: bookmarks });
          
        } catch (e) {
          console.error('スクレイピングエラー:', e);
          return JSON.stringify({ error: e.toString() });
        }
      })();
    ''';

    try {
      final result =
          await _controller.runJavaScriptReturningResult(scrapeScript);
      final resultStr = result.toString();

      if (resultStr.isEmpty) {
        throw Exception('スクレイピング結果が空です');
      }

      // JSON文字列をパース
      final jsonData = _decodeJsonResult(result);
      if (jsonData.isEmpty) throw Exception('ブックマークデータの形式が不正です');

      if (jsonData.containsKey('error')) {
        throw Exception(jsonData['error']);
      }

      final bookmarksList = jsonData['bookmarks'] as List? ?? [];
      return bookmarksList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('ブックマークスクレイピングエラー: $e');
      rethrow;
    }
  }

  /// スクレイピングしたデータをBookmarkオブジェクトに変換して保存
  Future<int> _importBookmarksFromScrapedData() async {
    try {
      // 現在のURLがブックマークページかチェック
      if (_currentUrl == null ||
          !_currentUrl!.contains('syosetu.com/favnovelmain/list/')) {
        throw Exception(
            'ブックマークページではありません。\nhttps://syosetu.com/favnovelmain/list/ にアクセスしてからインポートしてください。');
      }

      // スクレイピング実行
      final scrapedData = await _scrapeBookmarkData();

      if (scrapedData.isEmpty) {
        throw Exception('ブックマークデータが見つかりませんでした');
      }

      int importedCount = 0;
      int skippedCount = 0;
      final errors = <String>[];

      // 各スクレイピングデータをBookmarkオブジェクトに変換して保存
      for (final data in scrapedData) {
        try {
          final novelId = data['novelId'] as String;
          final novelTitle = data['novelTitle'] as String;
          final author = data['author'] as String;
          final currentChapter = data['currentChapter'] as int? ?? 0;
          final isSerialNovel = data['isSerialNovel'] as bool? ?? false;

          // 既に存在するかチェック
          final existingBookmark =
              await _viewModel.getBookmarkByNovelId(novelId);
          if (existingBookmark != null) {
            skippedCount++;
            continue; // 既に存在する場合はスキップ
          }

          // Bookmarkオブジェクトを作成
          final bookmark = Bookmark(
            id: novelId,
            novelId: novelId,
            novelTitle: novelTitle,
            author: author,
            currentChapter: currentChapter,
            addedAt: DateTime.now(),
            lastViewed: DateTime.now(),
            scrollPosition: 0.0, // 初期値
            isSerialNovel: isSerialNovel,
          );

          // データベースに保存
          await _viewModel.insertBookmark(bookmark);
          importedCount++;

          debugPrint('ブックマークインポート完了: $novelTitle (ID: $novelId)');
        } catch (itemError) {
          final title = data['novelTitle'] ?? 'Unknown';
          errors.add('$title: ${itemError.toString()}');
          debugPrint('個別アイテムのインポートエラー: $itemError');
        }
      }

      // 結果をログ出力
      debugPrint('ブックマークインポート結果:');
      debugPrint('  インポート成功: $importedCount件');
      debugPrint('  スキップ: $skippedCount件');
      debugPrint('  エラー: ${errors.length}件');

      if (errors.isNotEmpty) {
        debugPrint('  エラー詳細: ${errors.join(', ')}');
      }

      return importedCount;
    } catch (e) {
      debugPrint('ブックマークインポートエラー: $e');
      rethrow;
    }
  }

  /// ブックマークインポートのハンドラー
  Future<void> _handleBookmarkImport() async {
    DialogRoute<void>? loadingRoute;
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      // 確認ダイアログを表示
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ブックマークインポート'),
          content: const Text('このページからブックマーク情報を読み取り、アプリ内のブックマークに追加します。\n\n'
              '既に登録済みのブックマークはスキップされます。\n\n'
              '実行しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('実行'),
            ),
          ],
        ),
      );

      if (shouldImport != true || !mounted) return;

      // Keep the route itself so an interrupted import cannot pop the reader.
      loadingRoute = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'ブックマークを読み込み中...\n\n'
                  'ページからデータを取得しています。',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );

      unawaited(navigator.push(loadingRoute));

      // インポート実行
      final importedCount = await _importBookmarksFromScrapedData();

      if (!mounted) return;
      if (loadingRoute.isActive) navigator.removeRoute(loadingRoute);

      // 結果ダイアログを表示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('インポート完了'),
          content: Text(
            importedCount > 0
                ? '$importedCount件のブックマークを追加しました。'
                : 'インポートできるブックマークが見つかりませんでした。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (importedCount > 0) {
        // 成功時のSnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$importedCount件のブックマークを追加しました'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (loadingRoute != null && loadingRoute.isActive) {
        navigator.removeRoute(loadingRoute);
      }

      debugPrint('ブックマークインポートエラー: $e');

      // エラーダイアログを表示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('エラー'),
          content: Text('ブックマークのインポートに失敗しました。\n\n'
              'エラー詳細: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // エラー時のSnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('インポートに失敗しました: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showMoreOptions(WebViewViewModel viewModel) {
    // API情報があればそれを使用、なければフォールバック値を使用
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
              const Text(
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
                  onTap: _currentChapter > 1
                      ? () {
                          Navigator.pop(context);
                          final prevChapterUrl =
                              _buildNovelUrl(_currentChapter - 1);
                          _controller.loadRequest(Uri.parse(prevChapterUrl));
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.skip_next),
                  title: Text(
                      totalChapters != null && _currentChapter >= totalChapters
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
                  final shareUrl =
                      _currentUrl ?? _buildNovelUrl(_currentChapter);
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
                  _buildInfoRow(
                      '総話数', '${_viewModel.getTotalChapters(_novelDetails!)}話'),
                _buildInfoRow('文字数', '${_novelDetails!['length'] ?? 'N/A'}文字'),
                _buildInfoRow('読了時間', '${_novelDetails!['time'] ?? 'N/A'}分'),
                _buildInfoRow(
                    'ブックマーク数', '${_novelDetails!['fav_novel_cnt'] ?? 'N/A'}件'),
                _buildInfoRow(
                    '評価ポイント', '${_novelDetails!['global_point'] ?? 'N/A'}pt'),
                if (_novelDetails!['keyword'] != null &&
                    _novelDetails!['keyword'].toString().isNotEmpty)
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
    final screenContext = context;
    Timer? readinessTimer;
    bool isSheetActive = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        double tempFontSize = _fontSize;
        return StatefulBuilder(
          builder: (context, setState) {
            readinessTimer ??= Timer.periodic(const Duration(milliseconds: 500),
                (timer) async {
              if (!isSheetActive || !mounted) {
                timer.cancel();
                return;
              }
              if (!isWebViewReady) {
                await _testJavaScriptExecution();
                if (mounted && isSheetActive) {
                  setState(() {});
                }
              } else {
                timer.cancel();
              }
            });
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '表示設定',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isWebViewReady
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isWebViewReady ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isWebViewReady ? Icons.check_circle : Icons.warning,
                            color:
                                isWebViewReady ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isWebViewReady
                                  ? 'WebView準備完了'
                                  : 'WebView準備中... (試行: $_initializationAttempts/$maxInitializationAttempts)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isWebViewReady
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                          if (!isWebViewReady)
                            TextButton(
                              onPressed: _manualInitializationCheck,
                              child: const Text('再確認',
                                  style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.format_size),
                        Expanded(
                          child: Slider(
                            value: tempFontSize,
                            min: 10,
                            max: 30,
                            divisions: 20,
                            label: tempFontSize.round().toString(),
                            onChanged: (value) {
                              setState(() {
                                tempFontSize = value;
                                _fontSize = value;
                              });
                              if (isWebViewReady) {
                                _setFontSize(value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${tempFontSize.round()}'),
                      ],
                    ),
                    ListTile(
                      leading: const Icon(Icons.brightness_6),
                      title: const Text('ライトモード'),
                      subtitle: Text(
                          isWebViewReady ? '明るい背景色に設定' : 'WebView準備完了後に使用可能'),
                      enabled: isWebViewReady,
                      onTap: isWebViewReady
                          ? () async {
                              Navigator.pop(context);
                              // WebView内のテーマを変更
                              _setColorScheme(1); // color1 = ライトモード

                              // アプリ全体のテーマも変更
                              await ThemeHelper.setThemeMode(
                                screenContext,
                                AppThemeMode.light,
                              );

                              if (!screenContext.mounted) return;
                              ScaffoldMessenger.of(screenContext).showSnackBar(
                                const SnackBar(content: Text('ライトモードに変更しました')),
                              );
                            }
                          : null,
                    ),
                    ListTile(
                      leading: const Icon(Icons.brightness_2),
                      title: const Text('ダークモード'),
                      subtitle: Text(
                          isWebViewReady ? '暗い背景色に設定' : 'WebView準備完了後に使用可能'),
                      enabled: isWebViewReady,
                      onTap: isWebViewReady
                          ? () async {
                              Navigator.pop(context);
                              // WebView内のテーマを変更
                              _setColorScheme(2); // color2 = ダークモード

                              // アプリ全体のテーマも変更
                              await ThemeHelper.setThemeMode(
                                screenContext,
                                AppThemeMode.dark,
                              );

                              if (!screenContext.mounted) return;
                              ScaffoldMessenger.of(screenContext).showSnackBar(
                                const SnackBar(content: Text('ダークモードに変更しました')),
                              );
                            }
                          : null,
                    ),
                    ListTile(
                      leading: const Icon(Icons.line_weight),
                      title: const Text('行間広く'),
                      subtitle: const Text('読みやすい行間に調整'),
                      enabled: isWebViewReady,
                      onTap: () {
                        Navigator.pop(context);
                        if (isWebViewReady) {
                          _adjustLineHeight(increase: true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('行間を広くしました')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('WebViewの読み込みが完了していません')),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.line_weight),
                      title: const Text('行間狭く'),
                      subtitle: const Text('コンパクトな行間に調整'),
                      enabled: isWebViewReady,
                      onTap: () {
                        Navigator.pop(context);
                        if (isWebViewReady) {
                          _adjustLineHeight(increase: false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('行間を狭くしました')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('WebViewの読み込みが完了していません')),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('設定リセット'),
                      subtitle: const Text('表示設定を初期状態に戻す'),
                      enabled: isWebViewReady,
                      onTap: () {
                        Navigator.pop(context);
                        if (isWebViewReady) {
                          _resetDisplaySettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('表示設定をリセットしました')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('WebViewの読み込みが完了していません')),
                          );
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.bookmark_add),
                      title: const Text('ブックマークインポート'),
                      subtitle: Text(_currentUrl != null &&
                              _currentUrl!
                                  .contains('syosetu.com/favnovelmain/list/')
                          ? 'このページからブックマークをインポート'
                          : 'ブックマークページでのみ利用可能'),
                      enabled: isWebViewReady &&
                          _currentUrl != null &&
                          _currentUrl!
                              .contains('syosetu.com/favnovelmain/list/'),
                      onTap: () {
                        Navigator.pop(context);
                        _handleBookmarkImport();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      isSheetActive = false;
      readinessTimer?.cancel();
    });
  }
}
