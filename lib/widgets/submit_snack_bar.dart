import 'package:flutter/material.dart';
import '../models/submit_result.dart';

/// Shows how a submit went: green uploaded, orange saved on this device,
/// red not saved. For a record still uploading in the background, the
/// snackbar is replaced with the outcome once the upload queue is done.
void showSubmitResult(BuildContext context, SubmitResult result) {
  // The app-wide messenger outlives this screen, so the follow-up still
  // shows if the scouter navigates away.
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(
    content: Text(result.message),
    backgroundColor: result.uploaded
        ? Colors.green
        : result.success
            ? Colors.orange
            : Colors.red,
    duration: result.success ? const Duration(seconds: 4) : const Duration(seconds: 8),
  ));
  result.upload?.then((uploaded) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(uploaded ? uploadedMessage : savedLocallyMessage),
      backgroundColor: uploaded ? Colors.green : Colors.orange,
    ));
  });
}
