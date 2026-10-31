/// Shown when a record could neither be stored on the device (usually
/// browser storage full) nor uploaded, so the form must stay filled in.
const notSavedMessage = "Couldn't save on this device (storage full?) or "
    'upload. Your entries are still on the form; try again, or upload '
    'Held Data to free space.';

class SubmitResult {
  final bool success;
  final String message;
  SubmitResult({required this.success, required this.message});
}
