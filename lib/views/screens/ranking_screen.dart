import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/ranking_viewmodel.dart';
import '../../services/api_service.dart';
import 'webview_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({Key? key}) : super(key: key);

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late RankingViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _viewModel = RankingViewModel();
    _viewModel.loadRankings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<RankingViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('ランキング'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: DropdownButton<int>(
                    value: viewModel.selectedGenre,
                    underline: const SizedBox(),
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('すべて')),
                      ...ApiService.genres.entries.map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value,
                                overflow: TextOverflow.ellipsis),
                          ))
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        viewModel.updateGenre(value);
                      }
                    },
                  ),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '日間'),
                  Tab(text: '週間'),
                  Tab(text: '月間'),
                  Tab(text: '四半期'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildRankingList('d', viewModel),
                _buildRankingList('w', viewModel),
                _buildRankingList('m', viewModel),
                _buildRankingList('q', viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRankingList(String type, RankingViewModel viewModel) {
    final isLoading = viewModel.isLoading(type);
    final novels = viewModel.getRanking(type);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (novels.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('ランキングデータを取得できませんでした'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshRanking(type),
      child: ListView.builder(
        itemCount: novels.length,
        itemBuilder: (context, index) {
          final novel = novels[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getRankingColor(index + 1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              title: Text(
                novel.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('作者: ${novel.author}'),
                  Text('ジャンル: ${novel.genre}'),
                  if (novel.novelType != 1) // 連載中以外のタイプ
                    Text('短編小説')
                  else
                    if (novel.end == 1)
                      Text('連載中 ${novel.general_all_no}話 ${novel.length}文字')
                    else
                      Text('完結済み ${novel.general_all_no}話 ${novel.length}文字'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${novel.point} pt',  
                        style: TextStyle(
                          color: Colors.amber[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: _buildRankingBadge(index + 1),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(
                      novelId: novel.ncode,
                      title: novel.title,
                      url: 'https://ncode.syosetu.com/${novel.ncode.toLowerCase()}/',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getRankingColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // 金
      case 2:
        return Colors.grey[400]!; // 銀
      case 3:
        return Colors.brown[300]!; // 銅
      default:
        return Colors.blue;
    }
  }

  Widget? _buildRankingBadge(int rank) {
    if (rank <= 3) {
      IconData icon;
      Color color;
      
      switch (rank) {
        case 1:
          icon = Icons.emoji_events;
          color = Colors.amber;
          break;
        case 2:
          icon = Icons.emoji_events;
          color = Colors.grey[400]!;
          break;
        case 3:
          icon = Icons.emoji_events;
          color = Colors.brown[300]!;
          break;
        default:
          return null;
      }
      
      return Icon(icon, color: color, size: 28);
    }
    return null;
  }
}