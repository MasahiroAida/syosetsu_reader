import 'package:flutter/foundation.dart';
import '../models/search_novel.dart';
import '../services/api_service.dart';

class SearchViewModel extends ChangeNotifier {
  final bool isR18;
  final ApiService _apiService = ApiService();

  SearchViewModel({this.isR18 = false});
  
  List<SearchNovel> _searchResults = [];
  bool _isLoading = false;
  bool _showFilters = false;
  
  // フィルター設定
  Set<int> _selectedGenres = {};
  Set<String> _selectedKeywords = {};
  String _selectedType = '';
  String _selectedOrder = 'new';
  String _lastUpdate = '';

  // Getters
  List<SearchNovel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get showFilters => _showFilters;
  Set<int> get selectedGenres => _selectedGenres;
  Set<String> get selectedKeywords => _selectedKeywords;
  String get selectedType => _selectedType;
  String get selectedOrder => _selectedOrder;
  String get lastUpdate => _lastUpdate;

  // Setters
  void toggleFilters() {
    _showFilters = !_showFilters;
    notifyListeners();
  }

  void updateGenres(Set<int> genres) {
    _selectedGenres = genres;
    notifyListeners();
  }

  void updateKeywords(Set<String> keywords) {
    _selectedKeywords = keywords;
    notifyListeners();
  }

  void updateType(String type) {
    _selectedType = type;
    notifyListeners();
  }

  void updateOrder(String order) {
    _selectedOrder = order;
    notifyListeners();
  }

  void updateLastUpdate(String lastUpdate) {
    _lastUpdate = lastUpdate;
    notifyListeners();
  }

  Future<void> performSearch({
    required String keyword,
    String? excludeKeyword,
  }) async {
    if (keyword.trim().isEmpty) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final results = await _apiService.searchNovels(
        word: keyword.trim(),
        notword: excludeKeyword?.trim().isEmpty == true ? null : excludeKeyword?.trim(),
        genres: _selectedGenres.toList(),
        keywords: _selectedKeywords.toList(),
        type: _selectedType.isEmpty ? null : _selectedType,
        order: _selectedOrder,
        limit: 100,
        r18: isR18,
      );

      _searchResults = results;
    } catch (e) {
      print('検索エラー: $e');
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearResults() {
    _searchResults = [];
    notifyListeners();
  }
}