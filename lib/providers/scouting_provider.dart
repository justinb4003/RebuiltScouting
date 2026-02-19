import 'package:flutter/foundation.dart';
import '../models/scout_result.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class ScoutingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  // Form state
  int matchNumber = 1;
  int? selectedTeamNumber;
  bool scoutingActive = false;
  bool practiceMode = false;

  // Auto
  bool autoDidNothing = false;
  int autoFuelScored = 0;
  int autoFuelMissed = 0;
  int autoTowerLevel = 0;
  int autoMiddlePickup = 0;
  int autoDepotPickup = 0;
  int autoHumanStationPickup = 0;

  // Teleop
  int hopperSize = 50;
  int teleopFuelScored = 0;
  int teleopFuelMissed = 0;
  List<int> volleyScoredList = [];
  List<int> volleyMissedList = [];

  // Teleop Inactive
  bool teleopInactiveScoredFuel = false;
  bool teleopInactiveCollectedFuel = false;

  // Endgame
  int endgameTowerLevel = 0;

  // Pickups
  bool fuelGroundPickup = false;
  bool fuelHumanPickup = false;

  // Defense - Teleop Active
  String teleopActiveDefenseTime = 'N/A';
  String teleopActiveDefenseQuality = 'N/A';

  // Defense - Teleop Inactive
  String teleopInactiveDefenseTime = 'N/A';
  String teleopInactiveDefenseQuality = 'N/A';

  // General
  String matchNotes = '';

  bool _submitting = false;
  bool get submitting => _submitting;

  void beginScouting() {
    scoutingActive = true;
    notifyListeners();
  }

  void resetForm() {
    final wasPractice = practiceMode;
    scoutingActive = false;
    practiceMode = false;
    autoDidNothing = false;
    autoFuelScored = 0;
    autoFuelMissed = 0;
    autoTowerLevel = 0;
    autoMiddlePickup = 0;
    autoDepotPickup = 0;
    autoHumanStationPickup = 0;
    hopperSize = 50;
    teleopFuelScored = 0;
    teleopFuelMissed = 0;
    volleyScoredList = [];
    volleyMissedList = [];
    teleopInactiveScoredFuel = false;
    teleopInactiveCollectedFuel = false;
    endgameTowerLevel = 0;
    fuelGroundPickup = false;
    fuelHumanPickup = false;
    teleopActiveDefenseTime = 'N/A';
    teleopActiveDefenseQuality = 'N/A';
    teleopInactiveDefenseTime = 'N/A';
    teleopInactiveDefenseQuality = 'N/A';
    matchNotes = '';
    selectedTeamNumber = null;
    if (!wasPractice) matchNumber++;
    notifyListeners();
  }

  void recordVolley() {
    volleyScoredList.add(teleopFuelScored);
    volleyMissedList.add(teleopFuelMissed);
    teleopFuelScored = 0;
    teleopFuelMissed = 0;
    notifyListeners();
  }

  String get volleyLog {
    final entries = <String>[];
    for (var i = 0; i < volleyScoredList.length; i++) {
      entries.add('${volleyScoredList[i]} in, ${volleyMissedList[i]} missed');
    }
    return entries.join(' \u2022 ');
  }

  void updateField(VoidCallback update) {
    update();
    notifyListeners();
  }

  Future<SubmitResult> submit({
    required String scouterName,
    required String secretTeamKey,
    required String eventKey,
  }) async {
    if (selectedTeamNumber == null) {
      return SubmitResult(success: false, message: 'No team selected');
    }

    _submitting = true;
    notifyListeners();

    final result = ScoutResult(
      scouterName: scouterName,
      secretTeamKey: secretTeamKey,
      eventKey: eventKey,
      matchNumber: matchNumber,
      teamNumber: selectedTeamNumber!,
      autoDidNothing: autoDidNothing,
      autoFuelScored: autoFuelScored,
      autoFuelMissed: autoFuelMissed,
      autoTowerLevel: autoTowerLevel,
      autoMiddlePickup: autoMiddlePickup,
      autoDepotPickup: autoDepotPickup,
      autoHumanStationPickup: autoHumanStationPickup,
      hopperSize: hopperSize,
      teleopFuelScored: volleyScoredList.fold(0, (a, b) => a + b),
      teleopFuelMissed: volleyMissedList.fold(0, (a, b) => a + b),
      volleyScoredList: List.of(volleyScoredList),
      volleyMissedList: List.of(volleyMissedList),
      teleopInactiveScoredFuel: teleopInactiveScoredFuel,
      teleopInactiveCollectedFuel: teleopInactiveCollectedFuel,
      endgameTowerLevel: endgameTowerLevel,
      fuelGroundPickup: fuelGroundPickup,
      fuelHumanPickup: fuelHumanPickup,
      teleopActiveDefenseTime: teleopActiveDefenseTime,
      teleopActiveDefenseQuality: teleopActiveDefenseQuality,
      teleopInactiveDefenseTime: teleopInactiveDefenseTime,
      teleopInactiveDefenseQuality: teleopInactiveDefenseQuality,
      matchNotes: matchNotes,
    );

    // Always cache first
    await _storage.addHeldScoutResult(result);

    try {
      final success = await _api.postResults(result);
      if (success) {
        await _storage.removeHeldScoutResult(result.id);
        _submitting = false;
        notifyListeners();
        return SubmitResult(success: true, message: 'Submitted successfully!');
      } else {
        _submitting = false;
        notifyListeners();
        return SubmitResult(
            success: false, message: 'API error. Data saved locally.');
      }
    } catch (e) {
      _submitting = false;
      notifyListeners();
      return SubmitResult(
          success: false, message: 'Network error. Data saved locally.');
    }
  }
}

class SubmitResult {
  final bool success;
  final String message;
  SubmitResult({required this.success, required this.message});
}
