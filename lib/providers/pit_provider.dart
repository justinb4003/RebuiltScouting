import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/pit_result.dart';
import '../models/submit_result.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class PitProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;
  final ImagePicker _picker = ImagePicker();

  int? selectedTeamNumber;
  String driveTrain = 'Swerve';
  String driveTrainOther = '';
  bool groundPickup = false;
  bool humanPlayerPickup = false;
  int fuelCapacity = 0;
  String autoStartingSpot = 'Left';
  bool autoStartLeftTrench = false;
  bool autoStartLeftBump = false;
  bool autoStartHub = false;
  bool autoStartRightBump = false;
  bool autoStartRightTrench = false;
  bool autoCrashConcern = false;
  bool autoHang = false;
  String autoNotes = '';
  bool hangingWorks = false;
  int hangingLevel = 1;
  String hangingTime = '';
  String hangingHow = '';
  String teleopActivePlan = '';
  String teleopInactivePlan = '';
  bool willingToPlayDefense = false;
  bool ratherPlayDefense = false;
  bool shootOnMove = false;
  String hopperEmptyTime = '';
  String funQuestion = '';
  String notes = '';
  String? photoBase64;
  Uint8List? photoBytes;

  List<PitResult> scoutedTeams = [];
  bool _submitting = false;
  bool get submitting => _submitting;

  static const driveTrainOptions = ['Swerve', 'Tank', 'Mecanum', 'Other'];

  void resetForm() {
    driveTrain = 'Swerve';
    driveTrainOther = '';
    groundPickup = false;
    humanPlayerPickup = false;
    fuelCapacity = 0;
    autoStartingSpot = 'Left';
    autoStartLeftTrench = false;
    autoStartLeftBump = false;
    autoStartHub = false;
    autoStartRightBump = false;
    autoStartRightTrench = false;
    autoCrashConcern = false;
    autoHang = false;
    autoNotes = '';
    hangingWorks = false;
    hangingLevel = 1;
    hangingTime = '';
    hangingHow = '';
    teleopActivePlan = '';
    teleopInactivePlan = '';
    willingToPlayDefense = false;
    ratherPlayDefense = false;
    shootOnMove = false;
    hopperEmptyTime = '';
    funQuestion = '';
    notes = '';
    photoBase64 = null;
    photoBytes = null;
    selectedTeamNumber = null;
    notifyListeners();
  }

  void updateField(VoidCallback update) {
    update();
    notifyListeners();
  }

  Future<void> pickPhoto() => _pickImage(ImageSource.gallery);
  Future<void> capturePhoto() => _pickImage(ImageSource.camera);

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      photoBytes = bytes;
      photoBase64 = base64Encode(bytes);
      notifyListeners();
    }
  }

  Future<void> loadScoutedTeams(String eventKey) async {
    try {
      scoutedTeams = await _api.getPitResults(eventKey);
      notifyListeners();
    } catch (_) {
      // Silently fail - not critical
    }
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

    final result = PitResult(
      scouterName: scouterName,
      secretTeamKey: secretTeamKey,
      eventKey: eventKey,
      teamNumber: selectedTeamNumber!,
      driveTrain: driveTrain,
      driveTrainOther: driveTrainOther,
      groundPickup: groundPickup,
      humanPlayerPickup: humanPlayerPickup,
      fuelCapacity: fuelCapacity,
      autoStartingSpot: autoStartingSpot,
      autoStartLeftTrench: autoStartLeftTrench,
      autoStartLeftBump: autoStartLeftBump,
      autoStartHub: autoStartHub,
      autoStartRightBump: autoStartRightBump,
      autoStartRightTrench: autoStartRightTrench,
      autoCrashConcern: autoCrashConcern,
      autoHang: autoHang,
      autoNotes: autoNotes,
      hangingWorks: hangingWorks,
      hangingLevel: hangingLevel,
      hangingTime: hangingTime,
      hangingHow: hangingHow,
      teleopActivePlan: teleopActivePlan,
      teleopInactivePlan: teleopInactivePlan,
      willingToPlayDefense: willingToPlayDefense,
      ratherPlayDefense: ratherPlayDefense,
      shootOnMove: shootOnMove,
      hopperEmptyTime: hopperEmptyTime,
      funQuestion: funQuestion,
      notes: notes,
      photoBase64: photoBase64,
    );

    await _storage.addHeldPitResult(result);

    try {
      final success = await _api.postPitResults(result);
      if (success) {
        await _storage.removeHeldPitResult(result.id);
        _submitting = false;
        notifyListeners();
        return SubmitResult(
            success: true, message: 'Pit data submitted successfully!');
      } else {
        _submitting = false;
        notifyListeners();
        return SubmitResult(
            success: false, message: 'API error. Data saved locally.');
      }
    } catch (e, stackTrace) {
      debugPrint('Pit submit error: $e');
      debugPrint('$stackTrace');
      _submitting = false;
      notifyListeners();
      return SubmitResult(
          success: false, message: 'Network error. Data saved locally.');
    }
  }
}
