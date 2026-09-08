import 'package:flutter/foundation.dart';
import '../models/search_novel.dart';
import '../services/api_service.dart';

class SearchViewModel extends ChangeNotifier {
  final bool isR18;
  final ApiService _apiService;

  SearchViewModel({this.isR18 = false, ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<SearchNovel> _searchResults = [];
  bool _isLoading = false;
  bool _showFilters = false;
  bool _hasSearched = false;
  bool _disposed = false;
  int _requestId = 0;
  String? _errorMessage;

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
  bool get hasSearched => _hasSearched;
  String? get errorMessage => _errorMessage;
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
    _selectedGenres = Set.of(genres);
    notifyListeners();
  }

  void updateKeywords(Set<String> keywords) {
    _selectedKeywords = Set.of(keywords);
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
    if (_disposed) return;
    final requestId = ++_requestId;
    _isLoading = true;
    _hasSearched = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _apiService.searchNovels(
        word: keyword.trim(),
        notword: excludeKeyword?.trim().isEmpty == true
            ? null
            : excludeKeyword?.trim(),
        genres: _selectedGenres.toList(),
        keywords: _selectedKeywords.toList(),
        type: _selectedType.isEmpty ? null : _selectedType,
        lastup: _lastUpdate.isEmpty ? null : _lastUpdate,
        order: _selectedOrder,
        limit: 100,
        r18: isR18,
      );

      if (!_disposed && requestId == _requestId) {
        _searchResults = results;
      }
    } catch (_) {
      if (!_disposed && requestId == _requestId) {
        _searchResults = [];
        _errorMessage = '検索に失敗しました。通信環境を確認して再度お試しください。';
      }
    } finally {
      if (!_disposed && requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clearResults() {
    if (_disposed) return;
    ++_requestId;
    _searchResults = [];
    _isLoading = false;
    _hasSearched = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_requestId;
    super.dispose();
  }
}
