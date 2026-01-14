import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Prints a message to the console in color (debug mode only).
///
/// - By default, messages are printed in **green**.
/// - If [isError] is `true`, the message is printed in **red**.
/// - Automatically resets console color after printing to avoid bleed-over.
///
/// Example:
/// ```dart
/// logPrint("Upload successful!"); // green text
/// logPrint("Upload failed!", isError: true); // red text
/// ```
void logPrint(Object? message, {bool isError = false}) {
  if (kDebugMode) {
    const String red = '\x1B[31m';
    const String green = '\x1B[32m';
    const String reset = '\x1B[0m';

    final String color = isError ? red : green;

    String formattedMessage;

    if (message is String) {
      // Add a newline only if the message doesn’t already start with one
      formattedMessage = message.startsWith('\n') ? message : '\n$message';
    } else {
      formattedMessage = '\n$message';
    }

    print('$color$formattedMessage$reset');
  }
}

/// Logs error messages, errors, and stack traces to the console and to an error log file.
///
/// ### Parameters
/// - [String?] (`message`): A custom error message.
/// - [dynamic] (`error`): The error object to be logged.
/// - [StackTrace?] (`stackTrace`): The stack trace associated with the error.
///
/// ### Example
/// ```dart
/// logError(message: "An error occurred", error: e, stackTrace: stack);
/// ```
Future<void> logError(dynamic error, StackTrace? stackTrace, { String? message }) async {
    // Console Logging (Debug Mode Only)
    if (kDebugMode) {
      if (message != null) logPrint(message, isError: true);
      if (error != null) logPrint(error.toString(), isError: true);
      if (stackTrace != null) logPrint(stackTrace.toString(), isError: true);
    }

    // File Logging
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/error_log.txt');

      final logBuffer = StringBuffer();
      logBuffer.writeln('--- ${DateTime.now()} ---');
      if (message != null) logBuffer.writeln('Message: $message');
      if (error != null) logBuffer.writeln('Error: $error');
      if (stackTrace != null) logBuffer.writeln('StackTrace: $stackTrace');

      await file.writeAsString(
        logBuffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (error, stack) {
      // Fallback if file system fails
      if (kDebugMode) {
        debugPrint('\x1B[31mFailed to log error to file: $error\x1B[0m');
        debugPrint('\x1B[31m$stack\x1B[0m');
      }
    }
}