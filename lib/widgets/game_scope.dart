import 'package:flutter/material.dart';

import '../models/state_teams.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'fixed_segmented_button.dart';

/// Which teams a game draws from: the selected event's, or every team in
/// the user's team's state.
enum GameScope { event, state }

/// Loads the statewide team list for a game screen: the saved copy right
/// away, then the API at most once per app session per team/season.
class StateTeamsLoader extends ChangeNotifier {
  StateTeamsLoader({required this.locations});

  /// Whether hometowns are needed (Hometown) or just names (Name That Team).
  final bool locations;

  static final Set<String> _fetched = {};

  String? _key;
  StateTeams? data;
  bool loading = false;
  String? error;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Loads [teamNumber]'s state for [year] unless it's already loaded.
  Future<void> ensure(int teamNumber, int year) async {
    final key = '$teamNumber|$year|${locations ? 'loc' : 'names'}';
    if (key == _key) return;
    _key = key;
    data = null;
    error = null;
    loading = true;
    _notify();
    final cached = await StorageService.instance.loadCachedStateTeams(key);
    if (key != _key) return;
    if (cached != null) {
      data = cached;
      _notify();
    }
    if (cached == null || !_fetched.contains(key)) {
      try {
        final fresh = await ApiService.instance
            .getStateTeams(teamNumber: teamNumber, year: year, locations: locations);
        _fetched.add(key);
        await StorageService.instance.cacheStateTeams(key, fresh);
        if (key != _key) return;
        data = fresh;
      } on ApiStatusException catch (e) {
        if (key != _key) return;
        if (cached == null) {
          error = e.statusCode == 404
              ? 'Team $teamNumber isn\'t a US or Canadian team on The Blue Alliance.'
              : 'Couldn\'t load the teams in your state.';
        }
      } catch (e) {
        if (key != _key) return;
        if (cached == null) error = 'Couldn\'t load the teams in your state.';
      }
    }
    if (key != _key) return;
    loading = false;
    _notify();
  }
}

/// The This event / Statewide switch shown above a game's Start button.
class GameScopePicker extends StatelessWidget {
  final GameScope scope;
  final ValueChanged<GameScope> onChanged;
  final bool eventAvailable;
  final bool stateAvailable;
  // e.g. 'MI', once known.
  final String? state;

  const GameScopePicker({
    super.key,
    required this.scope,
    required this.onChanged,
    required this.eventAvailable,
    required this.stateAvailable,
    this.state,
  });

  @override
  Widget build(BuildContext context) => FixedSegmentedButton<GameScope>(
        segments: [
          ButtonSegment(
            value: GameScope.event,
            label: const Text('This event'),
            icon: const Icon(Icons.event),
            enabled: eventAvailable,
          ),
          ButtonSegment(
            value: GameScope.state,
            label: Text(state == null ? 'Statewide' : 'All of $state'),
            icon: const Icon(Icons.map),
            enabled: stateAvailable,
          ),
        ],
        selected: {scope},
        onSelectionChanged: (s) => onChanged(s.first),
      );
}
