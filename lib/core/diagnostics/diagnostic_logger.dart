import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LogSeverity {
  info,
  warning,
  error,
}

class DiagnosticLogEntry {
  const DiagnosticLogEntry({
    required this.timestamp,
    required this.severity,
    required this.category,
    required this.message,
    this.details,
  });

  final DateTime timestamp;
  final LogSeverity severity;
  final String category;
  final String message;
  final String? details;

  String formatLine() {
    final ts = timestamp.toIso8601String();
    final sev = severity.name.toUpperCase().padRight(7);
    final det = details != null ? ' | $details' : '';
    return '[$ts] [$sev] [$category] $message$det';
  }
}

final diagnosticLoggerProvider =
    StateNotifierProvider<DiagnosticLogger, List<DiagnosticLogEntry>>((ref) {
  return DiagnosticLogger.instance;
});

/// Ring-buffered local diagnostic logger (zero network/cloud transmission).
/// Powers the Settings Log Viewer and "Copy Diagnostics" button.
class DiagnosticLogger extends StateNotifier<List<DiagnosticLogEntry>> {
  DiagnosticLogger._() : super(const []) {
    info('Startup', 'Print Helper diagnostic logger initialized (100% local).');
  }

  static final DiagnosticLogger instance = DiagnosticLogger._();
  static const int _maxEntries = 300;

  void info(String category, String message, {String? details}) {
    _append(LogSeverity.info, category, message, details: details);
  }

  void warn(String category, String message, {String? details}) {
    _append(LogSeverity.warning, category, message, details: details);
  }

  void error(
    String category,
    String message, {
    String? details,
    StackTrace? stackTrace,
  }) {
    final combinedDetails = stackTrace != null
        ? (details != null ? '$details\n$stackTrace' : stackTrace.toString())
        : details;
    _append(LogSeverity.error, category, message, details: combinedDetails);
  }

  void _append(
    LogSeverity severity,
    String category,
    String message, {
    String? details,
  }) {
    final entry = DiagnosticLogEntry(
      timestamp: DateTime.now(),
      severity: severity,
      category: category,
      message: message,
      details: details,
    );
    final next = [entry, ...state];
    if (next.length > _maxEntries) {
      next.removeLast();
    }
    state = next;
  }

  void clear() {
    state = const [];
  }

  void clearLogs() {
    state = const [];
  }

  /// Generates a complete, privacy-safe diagnostic report for the "Copy Diagnostics"
  /// button in Settings.
  String buildDiagnosticsReport({
    int printerCount = 0,
    int queuedFileCount = 0,
    Map<String, String> extraContext = const <String, String>{},
  }) {
    final buf = StringBuffer();
    buf.writeln('=== PRINT HELPER LOCAL DIAGNOSTIC REPORT ===');
    buf.writeln('Generated At   : ${DateTime.now().toIso8601String()}');
    buf.writeln(
      'OS Platform    : ${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
    );
    buf.writeln('CPU Cores      : ${Platform.numberOfProcessors}');
    buf.writeln('Debug Mode     : $kDebugMode');
    buf.writeln('Printers Found : $printerCount');
    buf.writeln('Queued Files   : $queuedFileCount');
    for (final kv in extraContext.entries) {
      buf.writeln('${kv.key.padRight(15)}: ${kv.value}');
    }
    buf.writeln('Privacy Policy : 100% Offline — Nothing leaves this PC.');
    buf.writeln('--------------------------------------------');
    buf.writeln('Recent Diagnostic Logs (${state.length} entries):');
    for (final entry in state.take(100)) {
      buf.writeln(entry.formatLine());
    }
    return buf.toString();
  }
}
