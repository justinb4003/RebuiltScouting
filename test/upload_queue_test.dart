import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rebuilt_scouting/services/api_service.dart';
import 'package:rebuilt_scouting/services/upload_queue.dart';

class _FixedRandom implements math.Random {
  final double value;
  _FixedRandom(this.value);
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('retryDelay', () {
    final mid = _FixedRandom(0.5); // no jitter

    test('waits the idle interval after a clean pass', () {
      expect(retryDelay(0, mid), UploadQueue.idleRetry);
    });

    test('doubles from 5s and caps at 5 min', () {
      expect(retryDelay(1, mid), const Duration(seconds: 5));
      expect(retryDelay(2, mid), const Duration(seconds: 10));
      expect(retryDelay(4, mid), const Duration(seconds: 40));
      expect(retryDelay(7, mid), const Duration(minutes: 5));
      expect(retryDelay(1000, mid), const Duration(minutes: 5));
    });

    test('jitters within ±25% but never past the cap', () {
      expect(retryDelay(1, _FixedRandom(0)), const Duration(milliseconds: 3750));
      expect(retryDelay(1, _FixedRandom(0.999999)).inMilliseconds,
          closeTo(6250, 1));
      expect(retryDelay(20, _FixedRandom(0.999999)), UploadQueue.maxBackoff);
    });
  });

  group('uploadPass', () {
    late List<String> posted, removed;
    late Map<String, String> failures;

    HeldUpload item(String id, [Object? error]) => HeldUpload(
          id: id,
          post: () async {
            posted.add(id);
            if (error != null) throw error;
          },
          remove: () async => removed.add(id),
        );

    Future<UploadPassResult> pass(List<HeldUpload> items) => uploadPass(items,
        recordFailure: (id, error) async => failures[id] = error);

    setUp(() {
      posted = [];
      removed = [];
      failures = {};
    });

    test('uploads and removes everything when all succeed', () async {
      final r = await pass([item('a'), item('b')]);
      expect(r.uploaded, {'a', 'b'});
      expect(removed, ['a', 'b']);
      expect(r.failed, isFalse);
    });

    test('a rejected record is kept and marked, and the pass goes on', () async {
      final r = await pass([
        item('a'),
        item('bad', ApiStatusException(400, 'missing field')),
        item('c'),
      ]);
      expect(posted, ['a', 'bad', 'c']);
      expect(removed, ['a', 'c']);
      expect(r.rejected.keys, ['bad']);
      expect(failures['bad'], contains('400'));
      expect(r.offline, isFalse);
      expect(r.failed, isTrue);
    });

    test('a network error or timeout stops the pass', () async {
      for (final error in [
        http.ClientException('Failed to fetch'),
        TimeoutException('slow'),
        ApiStatusException(503, ''),
      ]) {
        posted.clear();
        removed.clear();
        failures.clear();
        final r = await pass([item('a'), item('b', error), item('c')]);
        expect(posted, ['a', 'b'], reason: '$error');
        expect(removed, ['a']);
        expect(r.offline, isTrue);
        expect(r.rejected, isEmpty);
        expect(failures.keys, ['b']);
      }
    });

    test('a local error (e.g. unreadable photo) marks the record, not offline',
        () async {
      final r = await pass([item('a', StateError('photo')), item('b')]);
      expect(posted, ['a', 'b']);
      expect(r.rejected.keys, ['a']);
      expect(r.offline, isFalse);
    });

    test('a failed remove after upload still counts as uploaded', () async {
      final r = await uploadPass([
        HeldUpload(
            id: 'a',
            post: () async {},
            remove: () async => throw StateError('quota')),
        item('b'),
      ], recordFailure: (_, _) async {});
      expect(r.uploaded, {'a', 'b'});
      expect(r.failed, isFalse);
    });
  });
}
