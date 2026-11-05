import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Catches errors nothing else handled, so one failure doesn't close the app
/// mid-walk. Errors are kept in memory and printed in debug builds only;
/// nothing is sent off the phone (no crash reporting without a privacy
/// policy update).
class ErrorReporter {
  ErrorReporter({this.capacity = 50, void Function(String message)? log})
    : _log = log ?? _debugLog;

  final int capacity;
  final void Function(String message) _log;
  final _recent = ListQueue<String>();

  static void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// Most recent last.
  List<String> get recent => List.unmodifiable(_recent);

  void report(Object error, StackTrace? stack, {String? context}) {
    final message = [
      ?context,
      '$error',
      if (stack != null) '$stack',
    ].join('\n');
    _recent.addLast(message);
    while (_recent.length > capacity) {
      _recent.removeFirst();
    }
    _log(message);
  }

  /// Routes framework and uncaught async errors here.
  void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(
        details.exception,
        details.stack,
        context: details.context?.toDescription(),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true; // Handled: keep running.
    };
  }
}
