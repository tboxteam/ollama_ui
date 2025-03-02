import 'dart:io';
import 'package:flutter/foundation.dart'; // For kDebugMode

/// Logs messages to a file (`ollama_ui.log`) for debugging and tracking.
///
/// Consider enhancing this service in the future by:
/// - Using a dedicated log directory (e.g., with path_provider for mobile).
/// - Implementing log rotation to prevent file overgrowth.
/// - Adding log levels (info, warning, error).
class LoggingService {
  static Future<void> log(String message) async {
    try {
      final logFile = File('ollama_ui.log');
      final timestamp = DateTime.now().toIso8601String();
      await logFile.writeAsString('$timestamp: $message\n',
          mode: FileMode.append);
    } catch (e) {
      // If logging fails, optionally output error in debug mode.
      if (kDebugMode) {
        // ignore: avoid_print
        print('Logging failed: $e');
      }
      // Fail silently in release mode.
    }
  }
}
