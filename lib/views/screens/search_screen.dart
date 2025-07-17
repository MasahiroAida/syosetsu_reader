import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme_helper.dart';
import 'webview_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool isR18;
  const SearchScreen({super.key, this.isR18 = false});

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
    _viewModel = SearchViewModel(isR18: widget.isR18);
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
          return GestureDetector(
            onPanUpdate: (_) {}, // スワイプを無効化
            child: Scaffold(
              appBar: AppBar(
                leading: widget.isR18
                    ? IconButton(
                        icon: const Icon(Icons.language),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WebViewScreen(
                                novelId: 'noc',
                                title: 'ノクターン',
                                url: 'https://noc.syosetu.com/top/top/',
                              ),
                            ),
                          );
                        },
                      )
                    : null,
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
                  if (viewModel.showFilters) 
                    Expanded(
                      flex: 0,
                      child: SingleChildScrollView(
                        child: _buildFilters(viewModel),
                      ),
                    ),
                  
                  // 検索結果
                  Expanded(
                    child: _buildSearchResults(viewModel),
                  ),
                ],
              ),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _excludeController,
                  decoration: const InputDecoration(
                    labelText: '除外キーワード',
                    hintText: '除外したいキーワード',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.remove_circle),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56, // TextFieldの高さに合わせる
                child: ElevatedButton(
                  onPressed: viewModel.isLoading ? null : () => _performSearch(viewModel),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: viewModel.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('検索'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(SearchViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ThemeHelper.getBoxDecoration(
        context,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ジャンル選択
          const Text('ジャンル', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: ApiService.genres.entries.map((entry) {
                  return FilterChip(
                    label: Text(
                      entry.value.replaceAll('〔', '\n').replaceAll('〕', ''),
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  );
                }).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 作品に含まれる要素
          const Text('作品に含まれる要素', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: NovelKeywords.keywords.map((keyword) {
                  return FilterChip(
                    label: Text(keyword, style: const TextStyle(fontSize: 11)),
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  );
                }).toList(),
              ),
            ),
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
                    url: widget.isR18
                        ? 'https://novel18.syosetu.com/${novel.ncode.toLowerCase()}/'
                        : 'https://ncode.syosetu.com/${novel.ncode.toLowerCase()}/',
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