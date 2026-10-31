import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../models/submit_result.dart';
import 'api_service.dart';
import 'browser.dart';
import 'storage_service.dart';

/// One held record, ready to post.
class HeldUpload {
  final String id;
  final Future<void> Function() post;
  final Future<void> Function() remove;
  HeldUpload({required this.id, required this.post, required this.remove});
}

class UploadPassResult {
  final Set<String> uploaded = {};
  /// Records the API turned down (kept, with the error, for a later pass).
  final Map<String, String> rejected = {};
  /// The pass stopped early because the server couldn't be reached.
  bool offline = false;

  bool get failed => offline || rejected.isNotEmpty;
}

/// Tries [items] in order. A rejected record is marked and skipped; a
/// network error or timeout ends the pass, since on bad Wi-Fi every other
/// record would just wait out its own timeout too. Never deletes a record
/// that didn't upload.
Future<UploadPassResult> uploadPass(
  List<HeldUpload> items, {
  required Future<void> Function(String id, String error) recordFailure,
}) async {
  final result = UploadPassResult();
  for (final item in items) {
    try {
      await item.post();
    } catch (e) {
      final offline = e is! ApiStatusException || e.transient;
      final error = _describe(e);
      debugPrint('Upload ${item.id} failed: $error');
      try {
        await recordFailure(item.id, error);
      } catch (e) {
        debugPrint('Recording upload failure failed: $e');
      }
      if (offline) {
        result.offline = true;
        break;
      }
      result.rejected[item.id] = error;
      continue;
    }
    result.uploaded.add(item.id);
    try {
      await item.remove();
    } catch (e) {
      // It's on the server; worst case the next pass posts it again, which
      // the API upserts by id.
      debugPrint('Removing uploaded ${item.id} failed: $e');
    }
  }
  return result;
}

String _describe(Object e) {
  if (e is ApiStatusException) {
    final body = e.body.trim();
    return body.isEmpty
        ? 'Server error ${e.statusCode}'
        : 'Server error ${e.statusCode}: '
            '${body.length > 120 ? '${body.substring(0, 120)}…' : body}';
  }
  if (e is TimeoutException) return 'Timed out';
  if (e is http.ClientException) return 'No connection';
  return '$e';
}

/// How long to wait before the next automatic pass. After a clean pass,
/// [idleRetry]; after [failures] failed passes in a row, back off from 5s to
/// 5 min, with jitter so a room full of tablets doesn't retry in lockstep
/// when the Wi-Fi comes back.
Duration retryDelay(int failures, math.Random random) {
  if (failures <= 0) return UploadQueue.idleRetry;
  final base = UploadQueue.minBackoff.inMilliseconds *
      math.pow(2, math.min(failures - 1, 20));
  final capped = math.min(base, UploadQueue.maxBackoff.inMilliseconds);
  final jittered = capped * (0.75 + random.nextDouble() * 0.5);
  return Duration(
      milliseconds:
          math.min(jittered, UploadQueue.maxBackoff.inMilliseconds).round());
}

/// Uploads held (saved-on-device) scouting records in the background.
///
/// One pass at a time; a pass asked for while one is running is queued and
/// runs right after. Passes start after each save, at app start, when the
/// tab becomes visible, when the browser comes back online, and on a timer
/// while anything is still held. The Held Data screen's "Upload now" uses
/// the same queue, so manual and automatic uploads never overlap.
class UploadQueue extends ChangeNotifier {
  static final instance = UploadQueue();

  static const idleRetry = Duration(seconds: 60);
  static const minBackoff = Duration(seconds: 5);
  static const maxBackoff = Duration(minutes: 5);

  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;
  final _random = math.Random();

  Future<UploadPassResult>? _current;
  Future<UploadPassResult>? _next;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  int _failures = 0;
  // Ids uploaded since launch, so a screen can tell whether its record went
  // up in whichever pass happened to pick it up.
  final Set<String> _uploadedIds = {};

  bool get running => _current != null;
  UploadPassResult? lastPass;

  bool wasUploaded(String id) => _uploadedIds.contains(id);

  /// Submit flow for a new record: [hold] it on the device and return right
  /// away while a pass uploads it. If it can't be held (storage full), try
  /// [post]ing it directly so it isn't lost; if that fails too the form
  /// must keep its entries.
  Future<SubmitResult> submit({
    required String id,
    required String what,
    required Future<void> Function() hold,
    required Future<void> Function() post,
  }) async {
    try {
      await hold();
    } catch (e) {
      debugPrint('Saving $what locally failed: $e');
      try {
        await post();
        _uploadedIds.add(id);
        return SubmitResult(
            success: true, uploaded: true, message: uploadedMessage);
      } catch (e) {
        debugPrint('$what direct upload failed: $e');
        return SubmitResult(success: false, message: notSavedMessage);
      }
    }
    return SubmitResult(
      success: true,
      message: uploadingMessage,
      upload: run().then((_) => wasUploaded(id)),
    );
  }

  /// Hook up the automatic triggers and do a first pass.
  void start() {
    _lifecycle ??= AppLifecycleListener(onShow: run);
    onBrowserOnline(run);
    run();
  }

  /// Runs a pass now, or right after the one in progress. Never throws.
  Future<UploadPassResult> run() {
    if (_current == null) {
      _timer?.cancel();
      _timer = null;
      final pass = _pass();
      _current = pass;
      notifyListeners();
      pass.whenComplete(() {
        _current = null;
        notifyListeners();
      });
      return pass;
    }
    return _next ??= _current!.then((_) {
      _next = null;
      return run();
    });
  }

  Future<UploadPassResult> _pass() async {
    UploadPassResult result;
    try {
      result = await uploadPass(await _loadItems(),
          recordFailure: _storage.recordUploadFailure);
    } catch (e) {
      // Only reading storage can land here; treat it like a failed pass.
      debugPrint('Upload pass failed: $e');
      result = UploadPassResult()..offline = true;
    }
    _uploadedIds.addAll(result.uploaded);
    lastPass = result;
    _failures = result.failed ? _failures + 1 : 0;

    var pending = 1;
    try {
      pending = (await _loadItems()).length;
    } catch (_) {}
    // A newer pass is already queued; let it decide the schedule.
    if (pending > 0 && _next == null) {
      final delay = retryDelay(_failures, _random);
      debugPrint('Upload queue: $pending held, next try in ${delay.inSeconds}s');
      _timer?.cancel();
      _timer = Timer(delay, run);
    }
    return result;
  }

  // Matches first (small, and what the pick list needs), then notes, then
  // pit records last since a big photo is the likeliest to time out and end
  // the pass.
  Future<List<HeldUpload>> _loadItems() async => [
        for (final r in await _storage.loadHeldScoutData())
          HeldUpload(
              id: r.id,
              post: () => _api.postResults(r),
              remove: () => _storage.removeHeldScoutResult(r.id)),
        for (final n in await _storage.loadHeldRobotNotes())
          HeldUpload(
              id: n.id,
              post: () => _api.postRobotNote(n),
              remove: () => _storage.removeHeldRobotNote(n.id)),
        for (final p in await _storage.loadHeldPitData())
          HeldUpload(
              id: p.id,
              post: () => _api.postPitResults(p),
              remove: () => _storage.removeHeldPitResult(p.id)),
      ];
}
