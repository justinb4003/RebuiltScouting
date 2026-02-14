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
  bool autoLeave = false;
  int autoFuelScored = 0;
  int autoFuelMissed = 0;
  bool autoTowerLevel1 = false;

  // Teleop
  int teleopFuelScored = 0;
  int teleopFuelMissed = 0;
  bool teleopCrossedBump = false;
  bool teleopEnteredTrench = false;

  // Endgame
  int endgameTowerLevel = 0;

  // Pickups
  bool fuelGroundPickup = false;
  bool fuelHumanPickup = false;

  // General
  String matchNotes = '';
  int defenseRating = 0;

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
    autoLeave = false;
    autoFuelScored = 0;
    autoFuelMissed = 0;
    autoTowerLevel1 = false;
    teleopFuelScored = 0;
    teleopFuelMissed = 0;
    teleopCrossedBump = false;
    teleopEnteredTrench = false;
    endgameTowerLevel = 0;
    fuelGroundPickup = false;
    fuelHumanPickup = false;
    matchNotes = '';
    defenseRating = 0;
    selectedTeamNumber = null;
    if (!wasPractice) matchNumber++;
    notifyListeners();
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
      autoLeave: autoLeave,
      autoFuelScored: autoFuelScored,
      autoFuelMissed: autoFuelMissed,
      autoTowerLevel1: autoTowerLevel1,
      teleopFuelScored: teleopFuelScored,
      teleopFuelMissed: teleopFuelMissed,
      teleopCrossedBump: teleopCrossedBump,
      teleopEnteredTrench: teleopEnteredTrench,
      endgameTowerLevel: endgameTowerLevel,
      fuelGroundPickup: fuelGroundPickup,
      fuelHumanPickup: fuelHumanPickup,
      matchNotes: matchNotes,
      defenseRating: defenseRating,
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
