import 'package:flutter/foundation.dart';
import '../models/scout_result.dart';
import '../models/submit_result.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class ScoutingProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  // Form state
  int matchNumber = 1;
  int? selectedTeamNumber;
  bool scoutingActive = false;
  bool practiceMode = false;

  // Auto
  bool autoDidNothing = false;
  int autoFuelScored = 0;
  double autoFuelAccuracy = 50;
  int autoTowerLevel = 0;
  int autoMiddlePickup = 0;
  bool autoDepotPickup = false;
  int autoHumanStationPickup = 0;
  bool? winAuto;

  // Teleop
  int hopperSize = 50;
  int teleopFuelScored = 0;
  bool teleopShootOnFly = false;
  double teleopFuelAccuracy = 50;
  List<int> volleyScoredList = [];
  List<int> volleyMissedList = [];

  // Teleop Inactive
  bool teleopInactiveScoredFuel = false;
  bool teleopInactiveCollectedFuel = false;
  bool teleopInactiveCollectedFuelPush = false;
  bool teleopInactiveCollectedFuelLobby = false;
  bool teleopInactiveCollectedFuelRefill = false;

  // Endgame
  int endgameTowerLevel = 0;
  int endgameFuelScored = 0;
  double endgameFuelAccuracy = 50;

  // Pickups
  bool fuelGroundPickup = false;
  bool fuelHumanPickup = false;
  bool fuelDepotPickup = false;

  // Defense - Teleop Active
  bool teleopActiveDefensePenalties = false;
  String teleopActiveDefenseQuality = 'N/A';

  // Defense - Teleop Inactive
  bool teleopInactiveDefensePenalties = false;
  String teleopInactiveDefenseQuality = 'N/A';

  // General
  String autoNotes = '';
  String matchNotes = '';

  bool _submitting = false;
  bool get submitting => _submitting;

  void beginScouting({int? defaultHopperSize}) {
    if (defaultHopperSize != null) {
      hopperSize = defaultHopperSize;
    }
    scoutingActive = true;
    notifyListeners();
  }

  void resetForm() {
    final wasPractice = practiceMode;
    scoutingActive = false;
    practiceMode = false;
    autoDidNothing = false;
    autoFuelScored = 0;
    autoFuelAccuracy = 50;
    autoTowerLevel = 0;
    autoMiddlePickup = 0;
    autoDepotPickup = false;
    autoHumanStationPickup = 0;
    winAuto = null;
    hopperSize = 50;
    teleopFuelScored = 0;
    teleopShootOnFly = false;
    teleopFuelAccuracy = 50;
    volleyScoredList = [];
    volleyMissedList = [];
    teleopInactiveScoredFuel = false;
    teleopInactiveCollectedFuel = false;
    teleopInactiveCollectedFuelPush = false;
    teleopInactiveCollectedFuelLobby = false;
    teleopInactiveCollectedFuelRefill = false;
    endgameTowerLevel = 0;
    endgameFuelScored = 0;
    endgameFuelAccuracy = 50;
    fuelGroundPickup = false;
    fuelHumanPickup = false;
    fuelDepotPickup = false;
    teleopActiveDefensePenalties = false;
    teleopActiveDefenseQuality = 'N/A';
    teleopInactiveDefensePenalties = false;
    teleopInactiveDefenseQuality = 'N/A';
    autoNotes = '';
    matchNotes = '';
    selectedTeamNumber = null;
    if (!wasPractice) matchNumber++;
    notifyListeners();
  }

  void recordVolley() {
    volleyScoredList.add(teleopFuelScored);
    teleopFuelScored = 0;
    notifyListeners();
  }

  String get volleyLog {
    final entries = <String>[];
    for (var i = 0; i < volleyScoredList.length; i++) {
      entries.add('${volleyScoredList[i]} scored, ${teleopFuelAccuracy.round()}% acc');
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
      autoFuelAccuracy: autoFuelAccuracy,
      autoTowerLevel: autoTowerLevel,
      autoMiddlePickup: autoMiddlePickup,
      autoDepotPickup: autoDepotPickup,
      autoHumanStationPickup: autoHumanStationPickup,
      winAuto: winAuto,
      hopperSize: hopperSize,
      teleopFuelScored: volleyScoredList.fold(0, (a, b) => a + b),
      teleopShootOnFly: teleopShootOnFly,
      teleopFuelAccuracy: teleopFuelAccuracy,
      volleyScoredList: List.of(volleyScoredList),
      volleyMissedList: List.of(volleyMissedList),
      teleopInactiveScoredFuel: teleopInactiveScoredFuel,
      teleopInactiveCollectedFuel: teleopInactiveCollectedFuel,
      teleopInactiveCollectedFuelPush: teleopInactiveCollectedFuelPush,
      teleopInactiveCollectedFuelLobby: teleopInactiveCollectedFuelLobby,
      teleopInactiveCollectedFuelRefill: teleopInactiveCollectedFuelRefill,
      endgameTowerLevel: endgameTowerLevel,
      endgameFuelScored: endgameFuelScored,
      endgameFuelAccuracy: endgameFuelAccuracy,
      fuelGroundPickup: fuelGroundPickup,
      fuelHumanPickup: fuelHumanPickup,
      fuelDepotPickup: fuelDepotPickup,
      teleopActiveDefensePenalties: teleopActiveDefensePenalties,
      teleopActiveDefenseQuality: teleopActiveDefenseQuality,
      teleopInactiveDefensePenalties: teleopInactiveDefensePenalties,
      teleopInactiveDefenseQuality: teleopInactiveDefenseQuality,
      autoNotes: autoNotes,
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
