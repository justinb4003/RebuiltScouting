import 'package:flutter/foundation.dart';
import '../models/rankings.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Event rankings: cached copy shows immediately, the API is hit at most once
/// automatically per app session per event, and [refresh] forces a re-fetch.
class RankingsProvider extends ChangeNotifier {
  final _api = ApiService.instance;
  final _storage = StorageService.instance;

  String? _eventKey;
  RankingsData? _data;
  bool _loading = false;
  String? _error;
  final Set<String> _autoFetched = {};

  RankingsData? get data => _data;
  bool get loading => _loading;
  String? get error => _error;

  /// Called when the screen opens (or the selected event changes).
  Future<void> load(String eventKey) async {
    if (eventKey.isEmpty) return;
    if (_eventKey != eventKey) {
      _eventKey = eventKey;
      _data = null;
      _error = null;
      notifyListeners();
      final cached = await _storage.loadCachedRankings(eventKey);
      if (_eventKey != eventKey) return;
      _data = cached;
      notifyListeners();
    }
    if (_autoFetched.add(eventKey)) await _fetch(eventKey);
  }

  Future<void> refresh() async {
    final eventKey = _eventKey;
    if (eventKey == null) return;
    _autoFetched.add(eventKey);
    await _fetch(eventKey);
  }

  Future<void> _fetch(String eventKey) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final fresh = await _api.getRankings(eventKey);
      if (_eventKey == eventKey) {
        // Keep a good cached table if the event now reports nothing.
        if (!fresh.isEmpty || _data == null) _data = fresh;
        if (!fresh.isEmpty) await _storage.cacheRankings(eventKey, fresh);
      }
    } catch (e) {
      debugPrint('Rankings fetch failed: $e');
      _error =
          'Could not load rankings. ${_data != null ? 'Showing saved data.' : ''}'
              .trim();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
