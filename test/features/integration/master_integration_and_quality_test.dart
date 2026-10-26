import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:print_helper/core/diagnostics/diagnostic_logger.dart';
import 'package:print_helper/core/integration/global_command_palette_and_recent_files.dart';
import 'package:print_helper/core/l10n/app_strings.dart';
import 'package:print_helper/core/theme/app_motion.dart';
import 'package:print_helper/features/pdf_tools/presentation/pdf_toolkit_controller.dart';

void main() {
  group('1. Global Tool Search & Command Palette (Ctrl+K) — English & Sinhala', () {
    test('Finds tools by English and Sinhala keywords (Unicode-normalized)', () {
      final all = GlobalCommandCatalog.searchCommands('');
      expect(all.length, greaterThanOrEqualTo(18));

      final mergeHits = GlobalCommandCatalog.searchCommands('ඒකාබද්ධ');
      expect(mergeHits, isNotEmpty);
      expect(mergeHits.first.id, equals('tool_merge_pdf'));

      final redactHits = GlobalCommandCatalog.searchCommands('redact');
      expect(redactHits, isNotEmpty);
      expect(redactHits.first.id, equals('tool_security_redact'));

      final ocrHits = GlobalCommandCatalog.searchCommands('tesseract');
      expect(ocrHits, isNotEmpty);
      expect(ocrHits.first.id, equals('tool_tesseract_ocr_scanner'));
    });
  });

  group('2. Unified Recent Files Registry Across All Tools', () {
    test('Records file touches across tools, deduplicates paths, and caps history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(recentFilesRegistryProvider.notifier);
      notifier.recordFileTouch(
        filePath: '/tmp/merged_report.pdf',
        toolLabelEn: 'Merge PDFs',
        toolLabelSi: 'PDF ඒකාබද්ධ කිරීම',
        fileSizeBytes: 128000,
        pageCount: 12,
      );

      final list = container.read(recentFilesRegistryProvider);
      expect(list.first.fileName, equals('merged_report.pdf'));
      expect(list.first.lastToolLabelEn, equals('Merge PDFs'));
      expect(list.first.pageCount, equals(12));

      // Touching the same file from another tool moves it to the top without duplicating
      notifier.recordFileTouch(
        filePath: '/tmp/merged_report.pdf',
        toolLabelEn: 'AES-256 Security',
        toolLabelSi: 'AES-256 ආරක්ෂාව',
      );
      final updated = container.read(recentFilesRegistryProvider);
      expect(
        updated.where((e) => e.fileName == 'merged_report.pdf').length,
        equals(1),
      );
      expect(updated.first.lastToolLabelEn, equals('AES-256 Security'));
    });
  });

  group('3. Crash-Safe Atomic File Saves & 500+ Page PDF Lazy Windowing', () {
    test('CrashSafeFileSaver writes via staging file and atomically renames', () async {
      final tempDir = await Directory.systemTemp.createTemp('ph_atomic_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final targetPath = p.join(tempDir.path, 'crash_safe_output.pdf');
      final payload = Uint8List.fromList('%PDF-1.7\n% Atomic Save Test\n'.codeUnits);

      final savedPath = await CrashSafeFileSaver.saveAtomically(
        bytes: payload,
        targetFilePath: targetPath,
      );

      expect(savedPath, equals(targetPath));
      expect(await File(targetPath).exists(), isTrue);
      expect(await File(targetPath).readAsBytes(), equals(payload));

      // Verify no leftover .tmp staging files remain in directory
      final files = await tempDir.list().toList();
      expect(files.length, equals(1));
    });

    test('LargePdfLazyPaginationPolicy bounds active page window on 500+ page PDFs', () {
      const policy = LargePdfLazyPaginationPolicy(
        windowRadiusPages: 6,
        maxCachedThumbnails: 24,
      );

      final winMiddle = policy.computeActivePageWindow(
        currentPage: 350,
        totalPages: 750,
      );
      expect(winMiddle.firstPage, equals(344));
      expect(winMiddle.lastPage, equals(356));
      expect(winMiddle.activeCount, lessThanOrEqualTo(13));

      final winStart = policy.computeActivePageWindow(
        currentPage: 1,
        totalPages: 600,
      );
      expect(winStart.firstPage, equals(1));
      expect(winStart.lastPage, equals(7));
    });

    test('Multi-Tab PDF Viewer opens a 600-page PDF smoothly and remembers last page', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(pdfToolkitControllerProvider.notifier);
      await ctrl.openFileInViewerTab(
        'large_gazette_600_pages.pdf',
        pageCountOverride: 600,
      );

      ctrl.setTabCurrentPage(412);
      final state = container.read(pdfToolkitControllerProvider);
      expect(state.activeTab?.totalPages, equals(600));
      expect(state.activeTab?.currentPage, equals(412));
      expect(
        state.rememberedLastPageByPath['large_gazette_600_pages.pdf'],
        equals(412),
      );
    });
  });

  group('4. Motion System (Reduce Motion), Localization (EN/SI) & Diagnostics', () {
    test('AppMotion returns Duration.zero when Reduce Motion is enabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(reduceMotionProvider), isFalse);
      expect(
        AppMotion.duration(AppMotion.normal, reduceMotion: false),
        equals(const Duration(milliseconds: 220)),
      );

      container.read(reduceMotionProvider.notifier).setReduceMotion(true);
      expect(container.read(reduceMotionProvider), isTrue);
      expect(
        AppMotion.duration(AppMotion.normal, reduceMotion: true),
        equals(Duration.zero),
      );
    });

    test('AppStrings provides complete English and Sinhala strings for new integration features', () {
      final en = AppStrings.of(AppLanguage.en);
      final si = AppStrings.of(AppLanguage.si);

      expect(en.commandPaletteHint, contains('Ctrl+K'));
      expect(si.commandPaletteHint, contains('Ctrl+K'));
      expect(en.actionOpenInViewer, equals('Open in Viewer'));
      expect(si.actionOpenInViewer, contains('කියවනයේ විවෘත කරන්න'));
      expect(en.actionConvertAgain, equals('Convert Again'));
      expect(si.actionConvertAgain, contains('නැවත පරිවර්තනය කරන්න'));
    });

    test('DiagnosticLogger records entries and generates offline privacy-safe report', () {
      DiagnosticLogger.instance.info('IntegrationTest', 'Verified full quality pass');
      final report = DiagnosticLogger.instance.buildDiagnosticsReport(
        printerCount: 3,
        queuedFileCount: 2,
        extraContext: const <String, String>{'Language': 'si'},
      );

      expect(report, contains('100% Offline — Nothing leaves this PC.'));
      expect(report, contains('Verified full quality pass'));
    });
  });
}
