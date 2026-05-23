import 'dart:async';
import 'package:flutter/foundation.dart';

/// Debouncer utility to delay execution of a function
/// Useful for preventing excessive API calls or state updates
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  /// Run the action after the delay
  /// If called again before delay expires, the previous call is cancelled
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel any pending action
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose the debouncer
  void dispose() {
    _timer?.cancel();
  }
}
