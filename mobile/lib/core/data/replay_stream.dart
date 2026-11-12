import 'dart:async';

/// A shared stream that remembers its latest value.
///
/// Every listener first gets the latest value, then live updates, from one
/// subscription to the source. After the last listener leaves, the source is
/// kept open for [linger], so switching tabs or going back to a screen shows
/// data at once instead of re-opening a Firestore listener and spinning.
class ReplayStream<T> extends Stream<T> {
  ReplayStream(this._open, {this.linger = const Duration(seconds: 30)});

  final Stream<T> Function() _open;
  final Duration linger;

  final _hub = StreamController<T>.broadcast(sync: true);
  StreamSubscription<T>? _source;
  Timer? _closer;
  int _listeners = 0;
  bool _hasValue = false;
  T? _value;
  Object? _error;
  StackTrace? _errorStack;

  /// True once the source has emitted at least one value.
  bool get hasValue => _hasValue;

  /// Latest value; only meaningful when [hasValue].
  T get value => _value as T;

  /// Reopens a failed source even while other screens share this stream.
  Future<void> restart() async {
    final source = _source;
    _source = null;
    await source?.cancel();
    if (_listeners > 0 && _source == null) _ensureOpen();
  }

  void _ensureOpen() {
    _closer?.cancel();
    _closer = null;
    _source ??= _open().listen(
      (v) {
        _error = null;
        _errorStack = null;
        _hasValue = true;
        _value = v;
        _hub.add(v);
      },
      onError: (Object e, StackTrace s) {
        // Don't replay a stale value next to a failure (e.g. after sign-out).
        _hasValue = false;
        _value = null;
        _error = e;
        _errorStack = s;
        _hub.addError(e, s);
      },
      onDone: () {
        _source = null;
      },
    );
  }

  void _release() {
    if (--_listeners > 0) return;
    _closer?.cancel();
    _closer = Timer(linger, () {
      _source?.cancel();
      _source = null;
      _hasValue = false;
      _value = null;
      _error = null;
      _errorStack = null;
    });
  }

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    late final StreamController<T> out;
    StreamSubscription<T>? inner;
    out = StreamController<T>(
      onListen: () {
        _listeners++;
        if (_hasValue) out.add(_value as T);
        if (_error != null) out.addError(_error!, _errorStack);
        inner = _hub.stream.listen(out.add, onError: out.addError);
        _ensureOpen();
      },
      onCancel: () async {
        await inner?.cancel();
        _release();
      },
    );
    return out.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
