import 'package:flutter/foundation.dart';
import '../models/review.dart';
import '../services/api_service.dart';

class ReviewViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Review> _reviews = [];
  bool _isLoading = false;
  bool _disposed = false;

  List<Review> get reviews => _reviews;
  bool get isLoading => _isLoading;

  Future<void> loadReviews() async {
    if (_disposed || _isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      _reviews = await _apiService.getReviews();
    } catch (e) {
      debugPrint('レビュー読み込みエラー: $e');
      _reviews = [];
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refreshReviews() async {
    await loadReviews();
  }
}
