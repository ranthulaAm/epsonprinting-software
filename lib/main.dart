import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/diagnostics/diagnostic_logger.dart';
import 'features/workspace/presentation/queue_controller.dart';

Future<void> main(List<String> args) async {
  final startupStopwatch = Stopwatch()..start();

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Wire global Flutter framework and platform error handlers into DiagnosticLogger
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        DiagnosticLogger.instance.error(
          'FlutterError',
          details.exceptionAsString(),
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        DiagnosticLogger.instance.error(
          'PlatformDispatcher',
          error.toString(),
          stackTrace: stack,
        );
        return true; // Prevent process crash; error is logged & displayed gracefully
      };

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await windowManager.ensureInitialized();
        const windowOptions = WindowOptions(
          size: AppConstants.defaultWindowSize,
          minimumSize: AppConstants.minWindowSize,
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.hidden,
        );
        unawaited(
          windowManager.waitUntilReadyToShow(windowOptions, () async {
            await windowManager.show();
            await windowManager.focus();
          }),
        );
      }

      // Extract any file paths passed via Windows Explorer "Open with Print Helper"
      final launchFiles = args
          .map((a) => a.trim().replaceAll('"', ''))
          .where((a) => a.isNotEmpty && !a.startsWith('-'))
          .toList();

      final container = ProviderContainer();

      // Render UI shell immediately (<2s startup budget) and hydrate queue asynchronously
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const PrintHelperApp(),
        ),
      );

      startupStopwatch.stop();
      DiagnosticLogger.instance.info(
        'Startup',
        'Print Helper UI mounted in ${startupStopwatch.elapsedMilliseconds} ms '
            '(launchArgs: ${launchFiles.length})',
      );

      unawaited(
        container
            .read(queueControllerProvider.notifier)
            .initialize(launchFileArgs: launchFiles),
      );
    },
    (Object error, StackTrace stackTrace) {
      // Industrial-grade crash guard: log unhandled async errors without terminating UI
      DiagnosticLogger.instance.error(
        'RootZone',
        error.toString(),
        stackTrace: stackTrace,
      );
      debugPrint('Unhandled error caught by root zone: $error\n$stackTrace');
    },
  );
}
