import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../viewmodels/history_viewmodel.dart';
import '../screens/webview_screen.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({Key? key}) : super(key: key);

  @override
  State<HistoryTab> createState() => HistoryTabState();
}

class HistoryTabState extends State<HistoryTab>
    with AutomaticKeepAliveClientMixin {
  late HistoryViewModel _viewModel;
  bool _isDisposed = false;
  bool _isInitialized = false; // 初期化フラグを追加
  Timer? _cooldownTimer;

  @override
  bool get wantKeepAlive => true; // 状態を保持

  @override
  void initState() {
    super.initState();
    _viewModel = HistoryViewModel();
    // 初回読み込み（API更新あり）を分離
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  // 初期化を分離して一度だけ実行
  void _initializeData() {
    if (!_isDisposed && mounted && !_isInitialized) {
      _viewModel.loadHistory();
      _isInitialized = true;
    }
  }

  Future<void> reloadFromDb() async {
    await _viewModel.loadHistory();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cooldownTimer?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      
      if (!_viewModel.isApiUpdateOnCooldown) {
        timer.cancel();
        if (mounted) {
          setState(() {}); // UI更新
        }
      } else {
        if (mounted) {
          setState(() {}); // 残り時間表示を更新
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixinのために必要
    
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<HistoryViewModel>(
        builder: (context, viewModel, child) {
          return _buildBody(viewModel);
        },
      ),
    );
  }

  Widget _buildRefreshButton(HistoryViewModel viewModel) {
    final isOnCooldown = viewModel.isApiUpdateOnCooldown;
    final isUpdating = viewModel.isUpdatingFromApi;
    
    return IconButton(
      icon: Icon(
        Icons.refresh,
        color: isOnCooldown ? Colors.grey : null,
      ),
      onPressed: (isUpdating || isOnCooldown) 
          ? null 
          : () => _refreshFromApi(viewModel),
      tooltip: isOnCooldown 
          ? '更新クールタイム中 (${viewModel.cooldownRemainingSeconds}秒)'
          : 'APIから最新情報を取得',
    );
  }

  Widget _buildBody(HistoryViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '閲覧履歴がありません',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '小説を読むと履歴が表示されます',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (!_isDisposed && mounted) {
          final success = await viewModel.refreshFromApi();
          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('更新クールタイム中です (${viewModel.cooldownRemainingSeconds}秒)'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: viewModel.history.length,
        itemBuilder: (context, index) {
          final item = viewModel.history[index];
          return _buildHistoryCard(context, item, viewModel);
        },
      ),
    );
  }

  Future<void> _refreshFromApi(HistoryViewModel viewModel) async {
    if (_isDisposed || !mounted) return;
    
    try {
      final success = await viewModel.refreshFromApi();
      
      if (success) {
        _startCooldownTimer(); // クールダウンタイマー開始
        
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('履歴情報を更新しました'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新クールタイム中です (${viewModel.cooldownRemainingSeconds}秒)'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('更新に失敗しました'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _confirmClearAll(HistoryViewModel viewModel) async {
    if (_isDisposed || !mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('全履歴削除'),
          content: const Text('すべての閲覧履歴を削除しますか？この操作は元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted && !_isDisposed) {
      // TODO: 全削除機能を実装
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全削除機能は今後実装予定です')),
      );
    }
  }

  void sortHistory(String sortType) {
    if (_isDisposed || !mounted) return;
    
    // ソート機能は今回は簡単な実装
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${sortType == 'title' ? 'タイトル' : '日時'}順ソート機能は今後実装予定です')),
    );
  }

  Widget _buildHistoryCard(BuildContext context, dynamic item, HistoryViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openNovel(context, item, viewModel),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイトル行
              Row(
                children: [
                  const Icon(
                    Icons.history,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.novelTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildOptionsMenu(context, item, viewModel),
                ],
              ),
              const SizedBox(height: 8),
              
              // 作者情報
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '作者: ${item.author}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // 進捗情報
              Row(
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.isSerialNovel && item.currentChapter > 0
                        ? '第${item.currentChapter}話まで読了'
                        : '目次/短編',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  if (item.totalChapters > 0) ...[
                    Text(
                      ' / ${item.totalChapters}話',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    viewModel.getTimeAgo(item.lastViewed),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              
              // 進捗バー（総話数がある場合）
              if (item.totalChapters > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: item.currentChapter / item.totalChapters,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(item.currentChapter / item.totalChapters * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              
              // スクロール位置情報（あれば表示）
              if (item.scrollPosition != null && item.scrollPosition! > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.vertical_align_center,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '読書位置保存済み',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // アクションボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openNovel(context, item, viewModel),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text(
                        '続きを読む',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openFromBeginning(context, item, viewModel),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text(
                      '最初から',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsMenu(BuildContext context, dynamic item, HistoryViewModel viewModel) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (value) async {
        if (_isDisposed || !mounted) return;
        
        switch (value) {
          case 'refresh_single':
            await _refreshSingleHistory(item, viewModel);
            break;
          case 'delete':
            await _confirmDelete(context, item, viewModel);
            break;
          case 'info':
            _showHistoryInfo(context, item, viewModel);
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'refresh_single',
          enabled: !viewModel.isApiUpdateOnCooldown,
          child: ListTile(
            leading: Icon(
              Icons.cloud_download,
              color: viewModel.isApiUpdateOnCooldown ? Colors.grey : null,
            ),
            title: Text(
              viewModel.isApiUpdateOnCooldown 
                  ? 'この作品を更新 (${viewModel.cooldownRemainingSeconds}秒)'
                  : 'この作品を更新',
              style: TextStyle(
                color: viewModel.isApiUpdateOnCooldown ? Colors.grey : null,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'info',
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('詳細情報'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('削除', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _refreshSingleHistory(dynamic item, HistoryViewModel viewModel) async {
    if (_isDisposed || !mounted) return;
    
    try {
      final success = await viewModel.refreshSingleHistory(item.novelId);
      
      if (success) {
        _startCooldownTimer(); // クールダウンタイマー開始
        
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${item.novelTitle}」の情報を更新しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新クールタイム中です (${viewModel.cooldownRemainingSeconds}秒)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('更新中にエラーが発生しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openNovel(BuildContext context, dynamic item, HistoryViewModel viewModel) {
    if (_isDisposed || !mounted) return;
    
    // 保存された位置から開く
    final url = viewModel.buildChapterUrl(item.novelId, item.currentChapter);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          novelId: item.novelId,
          title: item.novelTitle,
          url: url,
        ),
      ),
    ).then((_) {
      // 戻ってきたときに履歴リストを更新（API更新なし）
      if (!_isDisposed && mounted) {
        _viewModel.loadHistory(forceApiUpdate: false);
      }
    });
  }

  void _openFromBeginning(BuildContext context, dynamic item, HistoryViewModel viewModel) {
    if (_isDisposed || !mounted) return;
    
    // 最初から開く
    final url = viewModel.buildHomeUrl(item.novelId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          novelId: item.novelId,
          title: item.novelTitle,
          url: url,
        ),
      ),
    ).then((_) {
      if (!_isDisposed && mounted) {
        _viewModel.loadHistory(forceApiUpdate: false);
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, dynamic item, HistoryViewModel viewModel) async {
    if (_isDisposed || !mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('履歴削除'),
          content: Text('「${item.novelTitle}」の履歴を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted && !_isDisposed) {
      await viewModel.deleteHistory(item.novelId);
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${item.novelTitle}」の履歴を削除しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHistoryInfo(BuildContext context, dynamic item, HistoryViewModel viewModel) {
    if (_isDisposed || !mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(item.novelTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('作者', item.author),
                _buildInfoRow('現在の章', item.isSerialNovel && item.currentChapter > 0
                    ? '第${item.currentChapter}話'
                    : '目次/短編'),
                if (item.totalChapters > 0)
                  _buildInfoRow('総章数', '${item.totalChapters}話'),
                _buildInfoRow('最終閲覧', _formatDateTime(item.lastViewed)),
                if (item.scrollPosition != null && item.scrollPosition! > 0)
                  _buildInfoRow('スクロール位置', '${item.scrollPosition!.toInt()}px'),
                _buildInfoRow('小説ID', item.novelId),
                if (item.url.isNotEmpty)
                  _buildInfoRow('URL', item.url),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: viewModel.isApiUpdateOnCooldown ? null : () async {
                    Navigator.of(context).pop();
                    if (!_isDisposed && mounted) {
                      await _refreshSingleHistory(item, viewModel);
                    }
                  },
                  icon: const Icon(Icons.cloud_download),
                  label: Text(
                    viewModel.isApiUpdateOnCooldown 
                        ? '最新情報を取得 (${viewModel.cooldownRemainingSeconds}秒)'
                        : '最新情報を取得'
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}