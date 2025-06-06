import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'webview_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late SearchViewModel _viewModel;
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _excludeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = SearchViewModel();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _excludeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<SearchViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('小説検索'),
              actions: [
                IconButton(
                  icon: Icon(viewModel.showFilters ? Icons.filter_list_off : Icons.filter_list),
                  onPressed: () {
                    viewModel.toggleFilters();
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                // 検索フィールド
                _buildSearchFields(viewModel),
                
                // フィルター設定
                if (viewModel.showFilters) _buildFilters(viewModel),
                
                // 検索結果
                Expanded(
                  child: _buildSearchResults(viewModel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchFields(SearchViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _keywordController,
            decoration: const InputDecoration(
              labelText: 'キーワード',
              hintText: '作品タイトル、作者名など',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _excludeController,
            decoration: const InputDecoration(
              labelText: '除外キーワード',
              hintText: '除外したいキーワード',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.remove_circle),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: viewModel.isLoading ? null : () => _performSearch(viewModel),
            child: viewModel.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('検索'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(SearchViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: const Border(
          bottom: BorderSide(color: Colors.grey),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ジャンル選択
          const Text('ジャンル', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ApiService.genres.entries.map((entry) {
              return FilterChip(
                label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                selected: viewModel.selectedGenres.contains(entry.key),
                onSelected: (selected) {
                  final newGenres = Set<int>.from(viewModel.selectedGenres);
                  if (selected) {
                    newGenres.add(entry.key);
                  } else {
                    newGenres.remove(entry.key);
                  }
                  viewModel.updateGenres(newGenres);
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // 作品に含まれる要素
          const Text('作品に含まれる要素', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: NovelKeywords.keywords.map((keyword) {
              return FilterChip(
                label: Text(keyword, style: const TextStyle(fontSize: 12)),
                selected: viewModel.selectedKeywords.contains(keyword),
                onSelected: (selected) {
                  final newKeywords = Set<String>.from(viewModel.selectedKeywords);
                  if (selected) {
                    newKeywords.add(keyword);
                  } else {
                    newKeywords.remove(keyword);
                  }
                  viewModel.updateKeywords(newKeywords);
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // 作品タイプと並び順
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: viewModel.selectedType,
                  decoration: const InputDecoration(
                    labelText: '作品タイプ',
                    border: OutlineInputBorder(),
                  ),
                  items: WorkTypes.types.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    viewModel.updateType(value ?? '');
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: viewModel.selectedOrder,
                  decoration: const InputDecoration(
                    labelText: '並び順',
                    border: OutlineInputBorder(),
                  ),
                  items: OrderTypes.types.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    viewModel.updateOrder(value ?? 'new');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(SearchViewModel viewModel) {
    if (viewModel.searchResults.isEmpty && !viewModel.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('キーワードを入力して検索してください'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: viewModel.searchResults.length,
      itemBuilder: (context, index) {
        final novel = viewModel.searchResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('作者: ${novel.author}'),
                Text(
                  novel.story,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '全${novel.totalChapters}話 • ${novel.length}文字',
                  style: const TextStyle(fontSize: 12),
                ),
                if (novel.keyword.isNotEmpty)
                  Text(
                    novel.keyword,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[600],
                    ),
                  ),
              ],
            ),
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
    );
  }

  Future<void> _performSearch(SearchViewModel viewModel) async {
    if (_keywordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('キーワードを入力してください')),
      );
      return;
    }

    await viewModel.performSearch(
      keyword: _keywordController.text,
      excludeKeyword: _excludeController.text,
    );

    if (viewModel.searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('検索結果が見つかりませんでした')),
      );
    }
  }
}