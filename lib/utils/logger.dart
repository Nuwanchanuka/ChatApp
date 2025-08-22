import 'package:flutter/foundation.dart';

class AppLogger {
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final logTag = tag ?? 'ChatApp';
      print('[$timestamp] [$logTag] $message');
    }
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [ERROR] $message');
      if (error != null) {
        print('Error details: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  static void info(String message) {
    log(message, tag: 'INFO');
  }

  static void warning(String message) {
    log(message, tag: 'WARNING');
  }

  static void debug(String message) {
    log(message, tag: 'DEBUG');
  }

  static void connection(String message) {
    log(message, tag: 'CONNECTION');
  }

  static void database(String message) {
    log(message, tag: 'DATABASE');
  }

  static void ui(String message) {
    log(message, tag: 'UI');
  }
}
