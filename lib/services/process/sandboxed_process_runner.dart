import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/diagnostics/diagnostic_logger.dart';

/// Cancellation token that allows a running background PDF tool job or
/// isolated child process to be aborted immediately by the user.
class PdfTaskCancellationToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = <void Function()>[];

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  void addListener(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

/// Result of running an isolated OS child process (`qpdf.exe`, `tesseract.exe`, `soffice.exe`).
class SandboxedProcessResult {
  const SandboxedProcessResult({
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
    required this.timedOut,
    required this.cancelled,
    required this.elapsedMs,
  });

  final int exitCode;
  final String stdoutText;
  final String stderrText;
  final bool timedOut;
  final bool cancelled;
  final int elapsedMs;

  ///Note: qpdf returns exit code 0 on success and exit code 3 when it succeeded
  ///with warnings (e.g. when repairing a damaged PDF xref table).
  bool get isSuccess =>
      !timedOut && !cancelled && (exitCode == 0 || exitCode == 3);
}

/// Executes external CLI engines (`qpdf`, `tesseract`, `soffice`) in an isolated
/// child process with a strict timeout, bounded output buffers, and process-tree
/// termination on Windows (`taskkill /F /T /PID`) so a corrupt file can never
/// hang or crash Print Helper.
class SandboxedProcessRunner {
  const SandboxedProcessRunner();

  Future<SandboxedProcessResult> run({
    required String executable,
    required List<String> arguments,
    Duration timeout = const Duration(seconds: 45),
    PdfTaskCancellationToken? cancellationToken,
    String? workingDirectory,
  }) async {
    final stopwatch = Stopwatch()..start();
    if (cancellationToken?.isCancelled ?? false) {
      return const SandboxedProcessResult(
        exitCode: -1,
        stdoutText: '',
        stderrText: 'Operation cancelled before start.',
        timedOut: false,
        cancelled: true,
        elapsedMs: 0,
      );
    }

    Process? process;
    bool timedOut = false;
    bool cancelled = false;

    try {
      process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: false,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      final stdoutSub = process.stdout
          .transform(utf8.decoder)
          .listen((chunk) {
        if (stdoutBuffer.length < 64 * 1024) {
          stdoutBuffer.write(chunk);
        }
      });

      final stderrSub = process.stderr
          .transform(utf8.decoder)
          .listen((chunk) {
        if (stderrBuffer.length < 64 * 1024) {
          stderrBuffer.write(chunk);
        }
      });

      cancellationToken?.addListener(() {
        cancelled = true;
        _killProcessTree(process);
      });

      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          timedOut = true;
          _killProcessTree(process);
          return -999;
        },
      );

      await stdoutSub.cancel();
      await stderrSub.cancel();
      stopwatch.stop();

      return SandboxedProcessResult(
        exitCode: exitCode,
        stdoutText: stdoutBuffer.toString(),
        stderrText: stderrBuffer.toString(),
        timedOut: timedOut,
        cancelled: cancelled,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, st) {
      stopwatch.stop();
      DiagnosticLogger.instance.warn(
        'SandboxedProcessRunner',
        'Process execution fallback ($executable): $e',
      );
      return SandboxedProcessResult(
        exitCode: -1,
        stdoutText: '',
        stderrText: '$e\n$st',
        timedOut: timedOut,
        cancelled: cancelled,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  void _killProcessTree(Process? process) {
    if (process == null) return;
    try {
      if (Platform.isWindows) {
        Process.runSync('taskkill', <String>[
          '/F',
          '/T',
          '/PID',
          '${process.pid}',
        ]);
      } else {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (_) {
      // Ignore if process already exited
    }
  }
}
