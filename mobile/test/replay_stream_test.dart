import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/replay_stream.dart';

void main() {
  test('shares one source, replays the latest value and lingers', () async {
    var opens = 0;
    final source = StreamController<int>.broadcast();
    final s = ReplayStream<int>(() {
      opens++;
      return source.stream;
    }, linger: const Duration(milliseconds: 50));

    final a = <int>[];
    final subA = s.listen(a.add);
    await Future<void>.delayed(Duration.zero);
    source.add(1);
    await Future<void>.delayed(Duration.zero);
    expect(a, [1]);
    expect(s.hasValue, isTrue);

    final b = <int>[];
    final subB = s.listen(b.add);
    await Future<void>.delayed(Duration.zero);
    expect(b, [1], reason: 'late listener gets the latest value');
    await subA.cancel();
    await subB.cancel();

    // Re-listening within the linger window reuses the source.
    final c = <int>[];
    final subC = s.listen(c.add);
    await Future<void>.delayed(Duration.zero);
    expect(c, [1]);
    expect(opens, 1);
    await subC.cancel();

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(s.hasValue, isFalse, reason: 'closed after linger');
    final subD = s.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(opens, 2);
    await subD.cancel();
    await source.close();
  });

  test('an error clears the replayed value', () async {
    final source = StreamController<int>();
    final s = ReplayStream<int>(() => source.stream);
    final errors = <Object>[];
    final sub = s.listen((_) {}, onError: errors.add);
    source.add(1);
    await Future<void>.delayed(Duration.zero);
    source.addError(StateError('denied'));
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    expect(s.hasValue, isFalse);
    final lateErrors = <Object>[];
    final lateSub = s.listen((_) {}, onError: lateErrors.add);
    await Future<void>.delayed(Duration.zero);
    expect(lateErrors, hasLength(1),
        reason: 'a new screen must see the failure, not an empty list');
    source.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(s.hasValue, isTrue);
    await lateSub.cancel();
    await sub.cancel();
    await source.close();
  });
}
