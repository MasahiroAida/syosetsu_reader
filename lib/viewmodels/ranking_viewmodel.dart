import 'package:flutter/foundation.dart';
import '../models/ranking_novel.dart';
import '../services/api_service.dart';

class RankingViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  Map<String, List<RankingNovel>> _rankings = {};
  Map<String, bool> _loadingStates = {
    'd': true,
    'w': true,
    'm': true,
    'q': true,
  };
  int _selectedGenre = 0;

  int get selectedGenre => _selectedGenre;

  Map<String, List<RankingNovel>> get rankings => _rankings;
  Map<String, bool> get loadingStates => _loadingStates;

  bool isLoading(String type) => _loadingStates[type] ?? true;
  List<RankingNovel> getRanking(String type) => _rankings[type] ?? [];

  Future<void> loadRankings() async {
    final types = ['d', 'w', 'm', 'q'];
    
    for (String type in types) {
      await loadRankingByType(type);
    }
  }

  Future<void> loadRankingByType(String type) async {
    _loadingStates[type] = true;
    notifyListeners();

    try {
      final ranking = await _apiService.getRanking(
        rtype: type,
        genre: _selectedGenre == 0 ? null : _selectedGenre,
      );
      _rankings[type] = ranking;
    } catch (e) {
      print('ランキング取得エラー: $e');
      _rankings[type] = [];
    } finally {
      _loadingStates[type] = false;
      notifyListeners();
    }
  }

  Future<void> refreshRanking(String type) async {
    await loadRankingByType(type);
  }

  void updateGenre(int genre) {
    _selectedGenre = genre;
    loadRankings();
  }
}