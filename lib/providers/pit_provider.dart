import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/pit_result.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class PitProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  final ImagePicker _picker = ImagePicker();

  int? selectedTeamNumber;
  String driveTrain = 'Swerve';
  List<String> wheelTypes = [];
  int robotRating = 0;
  bool canCrossBump = false;
  bool canEnterTrench = false;
  String notes = '';
  String? photoBase64;
  Uint8List? photoBytes;

  List<PitResult> scoutedTeams = [];
  bool _submitting = false;
  bool get submitting => _submitting;

  static const driveTrainOptions = ['Swerve', 'Tank', 'Mecanum', 'Other'];
  static const wheelTypeOptions = ['Omni', 'Mecanum', 'Inflated', 'Solid'];

  void resetForm() {
    driveTrain = 'Swerve';
    wheelTypes = [];
    robotRating = 0;
    canCrossBump = false;
    canEnterTrench = false;
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

  void toggleWheelType(String type) {
    if (wheelTypes.contains(type)) {
      wheelTypes.remove(type);
    } else {
      wheelTypes.add(type);
    }
    notifyListeners();
  }

  Future<void> pickPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
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

  Future<void> capturePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
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

  Future<SubmitPitResult> submit({
    required String scouterName,
    required String secretTeamKey,
    required String eventKey,
  }) async {
    if (selectedTeamNumber == null) {
      return SubmitPitResult(success: false, message: 'No team selected');
    }

    _submitting = true;
    notifyListeners();

    final result = PitResult(
      scouterName: scouterName,
      secretTeamKey: secretTeamKey,
      eventKey: eventKey,
      teamNumber: selectedTeamNumber!,
      driveTrain: driveTrain,
      wheelTypes: List.from(wheelTypes),
      robotRating: robotRating,
      canCrossBump: canCrossBump,
      canEnterTrench: canEnterTrench,
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
        return SubmitPitResult(
            success: true, message: 'Pit data submitted successfully!');
      } else {
        _submitting = false;
        notifyListeners();
        return SubmitPitResult(
            success: false, message: 'API error. Data saved locally.');
      }
    } catch (e) {
      _submitting = false;
      notifyListeners();
      return SubmitPitResult(
          success: false, message: 'Network error. Data saved locally.');
    }
  }
}

class SubmitPitResult {
  final bool success;
  final String message;
  SubmitPitResult({required this.success, required this.message});
}
