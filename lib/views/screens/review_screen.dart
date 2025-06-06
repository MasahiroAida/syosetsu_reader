import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/review_viewmodel.dart';
import 'webview_screen.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({Key? key}) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late ReviewViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ReviewViewModel();
    _viewModel.loadReviews();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<ReviewViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('イチオシレビュー'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => viewModel.refreshReviews(),
                ),
              ],
            ),
            body: _buildBody(viewModel),
          );
        },
      ),
    );
  }

  Widget _buildBody(ReviewViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.reviews.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('レビューがありません'),
            SizedBox(height: 8),
            Text(
              'おすすめの作品レビューを準備中です',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshReviews(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: viewModel.reviews.length,
        itemBuilder: (context, index) {
          final review = viewModel.reviews[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タイトルと評価
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          review.novelTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRatingStars(review.rating),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // レビュー内容
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      review.summary,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // アクションボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WebViewScreen(
                                novelId: review.id,
                                title: review.novelTitle,
                                url: review.reviewUrl,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('レビューを見る'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WebViewScreen(
                                novelId: review.id,
                                title: review.novelTitle,
                                url: 'https://ncode.syosetu.com/${review.id.toLowerCase()}/',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.book),
                        label: const Text('作品を読む'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            color: Colors.amber[600],
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.amber[800],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}