import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Pemantau konektivitas sederhana untuk banner offline.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isOffline = false;

  bool get isOffline => _isOffline;
  Stream<bool> get changes => _controller.stream;

  Future<void> start() async {
    _subscription ??= _connectivity.onConnectivityChanged.listen(_emit);
    await _refresh();
  }

  Future<bool> refresh() => _refresh();

  Future<bool> _refresh() async {
    try {
      _emit(await _connectivity.checkConnectivity());
    } catch (_) {
      _emit(const [ConnectivityResult.none]);
    }
    return _isOffline;
  }

  void _emit(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    if (offline != _isOffline) {
      _isOffline = offline;
      if (!_controller.isClosed) _controller.add(offline);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
