/// Shown when a record could neither be stored on the device (usually
/// browser storage full) nor uploaded, so the form must stay filled in.
const notSavedMessage = "Couldn't save on this device (storage full?) or "
    'upload. Your entries are still on the form; try again, or upload '
    'Held Data to free space.';

const uploadedMessage = 'Uploaded';
const uploadingMessage = 'Saved on this device – uploading…';
const savedLocallyMessage = 'Saved on this device – will upload';

class SubmitResult {
  /// The record is safe (uploaded, or held on this device), so the form can
  /// be reset. Submitting again would only make a duplicate.
  final bool success;
  final bool uploaded;
  final String message;

  /// For a record saved on the device: completes with whether the upload
  /// queue got it to the server.
  final Future<bool>? upload;

  SubmitResult(
      {required this.success,
      required this.message,
      this.uploaded = false,
      this.upload});
}
