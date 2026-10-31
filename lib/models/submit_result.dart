/// Shown when a record could neither be stored on the device (usually
/// browser storage full) nor uploaded, so the form must stay filled in.
const notSavedMessage = "Couldn't save on this device (storage full?) or "
    'upload. Your entries are still on the form; try again, or upload '
    'Held Data to free space.';

const uploadedMessage = 'Uploaded';
const savedLocallyMessage = 'Saved on this device – will upload';

class SubmitResult {
  /// The record is safe (uploaded, or held on this device), so the form can
  /// be reset. Submitting again would only make a duplicate.
  final bool success;
  final bool uploaded;
  final String message;
  SubmitResult(
      {required this.success, required this.message, this.uploaded = false});
}
