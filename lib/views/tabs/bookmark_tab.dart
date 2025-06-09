import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/bookmark_viewmodel.dart';
import '../screens/webview_screen.dart';

class BookmarkTab extends StatefulWidget {
  const BookmarkTab({Key? key}) : super(key: key);

  @override
  State<BookmarkTab> createState() => BookmarkTabState();
}

class BookmarkTabState extends State<BookmarkTab>
    with AutomaticKeepAliveClientMixin {
  late BookmarkViewModel _viewModel;
  bool _isInitialized = false; // 初期化フラグを追加

  @override
  bool get wantKeepAlive => true; // 状態を保持

  @override
  void initState() {
    super.initState();
    _viewModel = BookmarkViewModel();
    _initializeData();
  }

  // 初期化を分離して一度だけ実行
  void _initializeData() {
    if (!_isInitialized) {
      _viewModel.loadBookmarks();
      _isInitialized = true;
    }
  }

  Future<void> reloadFromDb() async {
    await _viewModel.loadBookmarks();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixinのために必要
    
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<BookmarkViewModel>(
        builder: (context, viewModel, child) {
          return _buildBody(viewModel);
        },
      ),
    );
  }

  Widget _buildBody(BookmarkViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.bookmarks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'ブックマークがありません',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '小説を読んでブックマークに追加しましょう',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshFromApi(viewModel),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: viewModel.bookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = viewModel.bookmarks[index];
          return _buildBookmarkCard(context, bookmark, viewModel);
        },
      ),
    );
  }

  Future<void> _refreshFromApi(BookmarkViewModel viewModel) async {
    try {
      final success = await viewModel.refreshFromApi();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ブックマーク情報を更新しました'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新中です... 残り${viewModel.cooldownRemainingSeconds}秒お待ちください'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
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

  void sortBookmarks(String sortType) {
    final viewModel = _viewModel;
    // ソート機能は今回は簡単な実装
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${sortType == 'title' ? 'タイトル' : '日時'}順ソート機能は今後実装予定です')),
    );
  }

  Widget _buildBookmarkCard(BuildContext context, dynamic bookmark, BookmarkViewModel viewModel) {
    final unread = viewModel.getUnreadCount(bookmark.novelId);
    final hasUnread = unread > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      // 未読があるカードの背景色を変更
      color: hasUnread ? Colors.orange[50] : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // 未読がある場合は薄いオレンジ色のボーダーを追加
        side: hasUnread
            ? BorderSide(color: Colors.orange[200]!, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openNovel(context, bookmark),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイトル行
              Row(
                children: [
                  Icon(
                    Icons.bookmark,
                    color: hasUnread ? Colors.orange[600] : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  // 未読バッジ
                  if (hasUnread) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unread話未読',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      bookmark.novelTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        // 未読がある場合は少し色を変える
                        color: hasUnread ? Colors.orange[800] : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildOptionsMenu(context, bookmark, viewModel),
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
                    '作者: ${bookmark.author}',
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
                    bookmark.isSerialNovel && bookmark.currentChapter > 0
                        ? '第${bookmark.currentChapter}話まで読了'
                        : '目次/短編',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    viewModel.getTimeAgo(bookmark.lastViewed),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              
              // スクロール位置情報（あれば表示）
              if (bookmark.scrollPosition != null && bookmark.scrollPosition! > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.vertical_align_center,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '読書位置保存済み',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
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
                      onPressed: () => _openNovel(context, bookmark),
                      icon: Icon(
                        hasUnread ? Icons.fiber_new : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(
                        hasUnread ? '新着を読む' : '続きを読む',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasUnread ? Colors.orange[600] : null,
                        foregroundColor: hasUnread ? Colors.white : null,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openFromBeginning(context, bookmark),
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

  Widget _buildOptionsMenu(BuildContext context, dynamic bookmark, BookmarkViewModel viewModel) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (value) async {
        switch (value) {
          case 'refresh_single':
            await _refreshSingleBookmark(bookmark, viewModel);
            break;
          case 'delete':
            await _confirmDelete(context, bookmark, viewModel);
            break;
          case 'info':
            _showBookmarkInfo(context, bookmark, viewModel);
            break;
          case 'share':
            _shareBookmark(bookmark);
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'refresh_single',
          child: ListTile(
            leading: Icon(Icons.cloud_download),
            title: Text('この作品を更新'),
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
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.share),
            title: Text('共有'),
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

  Future<void> _refreshSingleBookmark(dynamic bookmark, BookmarkViewModel viewModel) async {
    try {
      final success = await viewModel.refreshSingleBookmark(bookmark.novelId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${bookmark.novelTitle}」の情報を更新しました'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('更新に失敗しました（クールタイム中かエラー）'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('更新中にエラーが発生しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openNovel(BuildContext context, dynamic bookmark) {
    // ViewModelのメソッドを使用してURL構築
    final url = _viewModel.buildChapterUrl(bookmark.novelId, bookmark.currentChapter);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          novelId: bookmark.novelId,
          title: bookmark.novelTitle,
          url: url,
        ),
      ),
    ).then((_) {
      // 戻ってきたときにブックマークリストを更新
      _viewModel.loadBookmarks();
    });
  }

  void _openFromBeginning(BuildContext context, dynamic bookmark) {
    // ViewModelのメソッドを使用してURL構築
    final url = _viewModel.buildHomeUrl(bookmark.novelId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          novelId: bookmark.novelId,
          title: bookmark.novelTitle,
          url: url,
        ),
      ),
    ).then((_) {
      _viewModel.loadBookmarks();
    });
  }

  Future<void> _confirmDelete(BuildContext context, dynamic bookmark, BookmarkViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ブックマーク削除'),
          content: Text('「${bookmark.novelTitle}」をブックマークから削除しますか？'),
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

    if (confirmed == true) {
      await viewModel.deleteBookmark(bookmark.novelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${bookmark.novelTitle}」を削除しました'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '元に戻す',
              textColor: Colors.white,
              onPressed: () {
                // TODO: 削除の取り消し機能
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('取り消し機能は未実装です')),
                );
              },
            ),
          ),
        );
      }
    }
  }

  void _showBookmarkInfo(BuildContext context, dynamic bookmark, BookmarkViewModel viewModel) {
    final unread = viewModel.getUnreadCount(bookmark.novelId);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(bookmark.novelTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('作者', bookmark.author),
                _buildInfoRow('現在の章', '${bookmark.currentChapter}話'),
                if (unread > 0) _buildInfoRow('未読話数', '$unread話', Colors.red),
                _buildInfoRow('追加日時', _formatDateTime(bookmark.addedAt)),
                _buildInfoRow('最終閲覧', _formatDateTime(bookmark.lastViewed)),
                if (bookmark.scrollPosition != null && bookmark.scrollPosition! > 0)
                  _buildInfoRow('スクロール位置', '${bookmark.scrollPosition!.toInt()}px'),
                _buildInfoRow('小説ID', bookmark.novelId),
                _buildInfoRow('小説種別', bookmark.isSerialNovel ? '連載' : '短編'),
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

  Widget _buildInfoRow(String label, String value, [Color? textColor]) {
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
            child: Text(
              value,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _shareBookmark(dynamic bookmark) {
    // TODO: 共有機能を実装
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('共有機能は未実装です')),
    );
  }
}