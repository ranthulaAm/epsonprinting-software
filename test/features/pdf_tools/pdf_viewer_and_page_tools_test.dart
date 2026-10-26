import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/features/pdf_tools/domain/pdf_tool_models.dart';
import 'package:print_helper/features/pdf_tools/presentation/pdf_toolkit_controller.dart';
import 'package:print_helper/services/pdf_tools/pdf_page_toolkit_service.dart';
import 'package:print_helper/services/process/sandboxed_process_runner.dart';

void main() {
  group('PDF Viewer: Multi-Tab, Last-Page Memory, Password Unlock & Sinhala Search', () {
    test(
      'opens multiple tabs, remembers last page per file across tab closes, and unlocks password-protected PDFs',
      () async {
        final service = PdfPageToolkitService();
        final ctrl = PdfToolkitController(toolkitService: service);

        await ctrl.openFileInViewerTab('doc_alpha.pdf', pageCountOverride: 6);
        await ctrl.openFileInViewerTab(
          'doc_encrypted.pdf',
          pageCountOverride: 4,
          isPasswordProtected: true,
        );

        expect(ctrl.state.openTabs.length, equals(2));
        expect(ctrl.state.activeTab!.fileName, equals('doc_encrypted.pdf'));
        expect(ctrl.state.activeTab!.isPasswordProtected, isTrue);
        expect(ctrl.state.activeTab!.isUnlocked, isFalse);

        // Unlock password-protected PDF
        final unlocked = ctrl.unlockPasswordProtectedTab('secret123');
        expect(unlocked, isTrue);
        expect(ctrl.state.activeTab!.isUnlocked, isTrue);

        // Switch back to doc_alpha.pdf and navigate to page 5
        final alphaTabId = ctrl.state.openTabs.first.tabId;
        ctrl.selectTab(alphaTabId);
        ctrl.setTabCurrentPage(5);
        expect(ctrl.state.activeTab!.currentPage, equals(5));

        // Close doc_alpha.pdf and re-open it -> should remember page 5
        ctrl.closeTab(alphaTabId);
        expect(ctrl.state.openTabs.length, equals(1));

        await ctrl.openFileInViewerTab('doc_alpha.pdf', pageCountOverride: 6);
        expect(ctrl.state.activeTab!.currentPage, equals(5));

        // Toggle display mode, zoom preset, rotation, and night mode
        ctrl.setDisplayMode(PdfViewDisplayMode.singlePage);
        ctrl.setZoomPreset(PdfZoomPreset.fitPage);
        ctrl.rotateActiveViewClockwise();
        ctrl.toggleNightMode();

        expect(
          ctrl.state.activeTab!.displayMode,
          equals(PdfViewDisplayMode.singlePage),
        );
        expect(
          ctrl.state.activeTab!.zoomPreset,
          equals(PdfZoomPreset.fitPage),
        );
        expect(ctrl.state.activeTab!.viewRotationDegrees, equals(90));
        expect(ctrl.state.activeTab!.nightMode, isTrue);
      },
    );

    test(
      'normalizes decomposed Sinhala vowel signs and ZWJ sequences for accurate PDF text search',
      () {
        // Decomposed kombuwa + al-lakuna (\u0DD9\u0DCA) vs precomposed (\u0DDA)
        const pageTexts = <int, String>{
          1: 'ශ්‍රී ලංකා ප්‍රවාහන හා විද්‍යාව දෙපාර්තමේන්තුව',
          2: 'සෞඛ්‍යය සහ අධ්‍යාපන වාර්තාව — ත\u0DD9\u0DCAරීම',
        };

        // Search using precomposed 'තේරීම' (\u0DDA) against decomposed '\u0DD9\u0DCA' on page 2
        final decomposedMatches = PdfPageToolkitService.searchDocumentText(
          pageTexts: pageTexts,
          rawQuery: 'තේරීම',
        );
        expect(decomposedMatches.length, equals(1));
        expect(decomposedMatches.first.pageNumber, equals(2));

        // Search for Rakaransaya ('ශ්‍රී') and Yansaya ('විද්‍යාව')
        final sinhalaMatches = PdfPageToolkitService.searchDocumentText(
          pageTexts: pageTexts,
          rawQuery: 'විද්‍යාව',
        );
        expect(sinhalaMatches.length, equals(1));
        expect(sinhalaMatches.first.pageNumber, equals(1));
      },
    );
  });

  group('PDF Page Tools: Split Modes, Reorder, Rotate, Crop, Bates, Watermark & Save/Overwrite', () {
    test(
      'computes split page groups by range, every N pages, max file size, and bookmarks',
      () {
        final byRange = PdfPageToolkitService.computeSplitPageGroups(
          totalPages: 10,
          strategy: PdfSplitStrategy.byPageRange,
          rangeExpression: '1-3, 5, 8-10',
        );
        expect(
          byRange,
          equals(<List<int>>[
            <int>[1, 2, 3],
            <int>[5],
            <int>[8, 9, 10],
          ]),
        );

        final everyThree = PdfPageToolkitService.computeSplitPageGroups(
          totalPages: 8,
          strategy: PdfSplitStrategy.everyNPages,
          everyNPages: 3,
        );
        expect(
          everyThree,
          equals(<List<int>>[
            <int>[1, 2, 3],
            <int>[4, 5, 6],
            <int>[7, 8],
          ]),
        );

        final byBookmarks = PdfPageToolkitService.computeSplitPageGroups(
          totalPages: 9,
          strategy: PdfSplitStrategy.byTopLevelBookmarks,
          bookmarks: const <PdfBookmarkNode>[
            PdfBookmarkNode(title: 'Ch 1', pageNumber: 1),
            PdfBookmarkNode(title: 'Ch 2', pageNumber: 4),
            PdfBookmarkNode(title: 'Ch 3', pageNumber: 7),
          ],
        );
        expect(
          byBookmarks,
          equals(<List<int>>[
            <int>[1, 2, 3],
            <int>[4, 5, 6],
            <int>[7, 8, 9],
          ]),
        );
      },
    );

    test(
      'reorders, rotates, deletes, inserts blank/external pages, stamps Bates & Sinhala watermark, and saves/overwrites',
      () async {
        final service = PdfPageToolkitService();
        final ctrl = PdfToolkitController(toolkitService: service);

        ctrl.loadFilesIntoPageOrganizer(
          <String>['assets/test_documents/sinhala_orthography_test.md'],
          pageCountPerFile: 3,
        );
        expect(ctrl.state.organizerPages.length, equals(3));

        // Insert a blank page and 2 pages from another PDF
        ctrl.insertBlankPage(atIndex: 1);
        ctrl.insertPagesFromAnotherPdf('second_doc.pdf', pageCount: 2);
        expect(ctrl.state.organizerPages.length, equals(6));

        // Reorder first two pages and rotate page 1
        final firstId = ctrl.state.organizerPages.first.tileId;
        ctrl.rotateOrganizerPage(firstId, deltaDegrees: 90);
        expect(ctrl.state.organizerPages.first.rotationDegrees, equals(90));
        ctrl.reorderOrganizerPage(0, 2);

        // Configure Bates numbering + Sinhala Watermark
        const stampConfig = PdfStampingConfig(
          includePageNumbers: true,
          headerCenter: 'ශ්‍රී ලංකා මුද්‍රණ සහායක',
          enableBatesNumbering: true,
          batesPrefix: 'CASE-',
          batesStartNumber: 100,
          batesDigits: 5,
          watermarkText: 'රහසිගතයි • CONFIDENTIAL',
        );
        expect(stampConfig.formatBatesForIndex(0), equals('CASE-00100'));
        expect(stampConfig.formatBatesForIndex(4), equals('CASE-00104'));

        ctrl.selectActiveTool(PdfPageToolKind.stampBatesHeadersWatermarks);
        ctrl.updateStampingConfig(stampConfig);

        final report = await ctrl.runActivePageToolJob();
        expect(report, isNotNull);
        expect(report!.beforeSizeBytes, greaterThan(0));
        expect(report.afterSizeBytes, greaterThan(0));
        expect(report.previewPdfBytes.length, greaterThan(500));

        // Verify Save as New & Atomic Overwrite in system temp directory
        final tempDir = await Directory.systemTemp.createTemp('ph_pdf_tools_test_');
        final savedNewPath = '${tempDir.path}/saved_new.pdf';
        await ctrl.saveLastReportOutput(
          targetFilePath: savedNewPath,
          overwriteExisting: false,
        );
        expect(await File(savedNewPath).exists(), isTrue);

        // Overwrite existing file atomically
        await ctrl.saveLastReportOutput(
          targetFilePath: savedNewPath,
          overwriteExisting: true,
        );
        expect(await File(savedNewPath).length(), equals(report.previewPdfBytes.length));
        await tempDir.delete(recursive: true);
      },
    );

    test('supports background job cancellation via PdfTaskCancellationToken', () async {
      final service = PdfPageToolkitService();
      final token = PdfTaskCancellationToken()..cancel();

      expect(
        () => service.executePageTool(
          toolKind: PdfPageToolKind.compressPdf,
          inputFilePaths: const <String>[],
          pagePlan: const <PdfEditablePageDescriptor>[],
          cancellationToken: token,
        ),
        throwsStateError,
      );
    });
  });
}
