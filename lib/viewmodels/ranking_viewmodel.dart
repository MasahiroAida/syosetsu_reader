import 'package:flutter/foundation.dart';
import '../models/ranking_novel.dart';
import '../services/api_service.dart';

class RankingViewModel extends ChangeNotifier {
  final ApiService _apiService;

  RankingViewModel({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final Map<String, int> _requestIds = {};
  final Map<String, String?> _errors = {};
  bool _disposed = false;

  final Map<String, List<RankingNovel>> _rankings = {};
  final Map<String, bool> _loadingStates = {
    'd': true,
    'w': true,
    'm': true,
    'q': true,
  };
  int _selectedGenre = 0;

  int get selectedGenre => _selectedGenre;
  String? errorMessage(String type) => _errors[type];

  Map<String, List<RankingNovel>> get rankings => _rankings;
  Map<String, bool> get loadingStates => _loadingStates;

  bool isLoading(String type) => _loadingStates[type] ?? true;
  List<RankingNovel> getRanking(String type) => _rankings[type] ?? [];

  Future<void> loadRankings() async {
    await Future.wait(['d', 'w', 'm', 'q'].map(loadRankingByType));
  }

  Future<void> loadRankingByType(String type,
      {bool forceRefresh = false}) async {
    if (_disposed) return;
    final requestId = (_requestIds[type] ?? 0) + 1;
    _requestIds[type] = requestId;
    _loadingStates[type] = true;
    _errors[type] = null;
    notifyListeners();

    try {
      final ranking = await _apiService.getRanking(
        rtype: type,
        genre: _selectedGenre == 0 ? null : _selectedGenre,
        forceRefresh: forceRefresh,
      );
      if (!_disposed && _requestIds[type] == requestId) {
        _rankings[type] = ranking;
      }
    } catch (_) {
      if (!_disposed && _requestIds[type] == requestId) {
        _rankings[type] = [];
        _errors[type] = 'ランキングの取得に失敗しました。再度お試しください。';
      }
    } finally {
      if (!_disposed && _requestIds[type] == requestId) {
        _loadingStates[type] = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshRanking(String type) async {
    await loadRankingByType(type, forceRefresh: true);
  }

  void updateGenre(int genre) {
    if (_disposed || _selectedGenre == genre) return;
    _selectedGenre = genre;
    loadRankings();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
