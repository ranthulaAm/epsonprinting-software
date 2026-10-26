import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:print_helper/features/presets/data/presets_persistence.dart';
import 'package:print_helper/features/preview/domain/print_layout_engine.dart';
import 'package:print_helper/features/workspace/domain/print_queue_item.dart';
import 'package:print_helper/services/printer/models/printer_models.dart';
import 'package:print_helper/services/printer/win32_devmode_configurator.dart';

void main() {
  group('Page Range, Odd/Even & Reverse Order Engine', () {
    test('Parses "1-3, 5, 8-10", filters odd/even, and reverses order', () {
      final base = PrintLayoutEngine.parseEffectivePages(
        totalDocumentPages: 12,
        pageRangeExpr: '1-3, 5, 8-10',
        subset: PageSubset.all,
        reverseOrder: false,
      );
      expect(base, [1, 2, 3, 5, 8, 9, 10]);

      final oddOnly = PrintLayoutEngine.parseEffectivePages(
        totalDocumentPages: 12,
        pageRangeExpr: '1-3, 5, 8-10',
        subset: PageSubset.oddOnly,
        reverseOrder: false,
      );
      expect(oddOnly, [1, 3, 5, 9]);

      final evenReversed = PrintLayoutEngine.parseEffectivePages(
        totalDocumentPages: 12,
        pageRangeExpr: '1-3, 5, 8-10',
        subset: PageSubset.evenOnly,
        reverseOrder: true,
      );
      expect(evenReversed, [10, 8, 2]);
    });
  });

  group('Imposition Engine (N-Up, Booklet, Poster)', () {
    test('Computes 4-Up (4 pages per sheet) with Duplex sheet indexing', () {
      final sheets = PrintLayoutEngine.computePhysicalSheets(
        totalDocumentPages: 10,
        settings: const FilePrintSettings(
          layoutMode: SheetLayoutMode.nUp,
          pagesPerSheet: 4,
          duplex: DuplexMode.longEdge,
        ),
      );

      // 10 pages at 4-per-side = 3 sides (2 physical duplex sheets)
      expect(sheets.length, 3);
      expect(sheets[0].sheetIndex, 1);
      expect(sheets[0].isBackSide, isFalse);
      expect(
        sheets[0].slots.map((s) => s.sourcePageNumber).toList(),
        [1, 2, 3, 4],
      );

      expect(sheets[1].sheetIndex, 1);
      expect(sheets[1].isBackSide, isTrue);
      expect(
        sheets[1].slots.map((s) => s.sourcePageNumber).toList(),
        [5, 6, 7, 8],
      );

      expect(sheets[2].sheetIndex, 2);
      expect(sheets[2].isBackSide, isFalse);
      expect(
        sheets[2].slots.map((s) => s.sourcePageNumber).toList(),
        [9, 10, null, null],
      );
    });

    test('Computes Booklet saddle-stitch imposition padded to multiple of 4',
        () {
      // 3-page document padded to 4 pages -> 1 physical sheet (Front & Back spreads)
      final sheets = PrintLayoutEngine.computePhysicalSheets(
        totalDocumentPages: 3,
        settings: const FilePrintSettings(
          layoutMode: SheetLayoutMode.booklet,
        ),
      );

      expect(sheets.length, 2);
      // Front spread: [padded[3] = null (blank back cover), padded[0] = page 1 (front cover)]
      expect(
        sheets[0].slots.map((s) => s.sourcePageNumber).toList(),
        [null, 1],
      );
      // Back spread: [padded[1] = page 2, padded[2] = page 3]
      expect(
        sheets[1].slots.map((s) => s.sourcePageNumber).toList(),
        [2, 3],
      );
    });

    test('Computes Poster 3x3 tiling (9 sheets per source page)', () {
      final sheets = PrintLayoutEngine.computePhysicalSheets(
        totalDocumentPages: 1,
        settings: const FilePrintSettings(
          layoutMode: SheetLayoutMode.poster,
          posterGridSize: 3,
        ),
      );

      expect(sheets.length, 9);
      expect(sheets.first.slots.first.tileRow, 0);
      expect(sheets.first.slots.first.tileCol, 0);
      expect(sheets.last.slots.first.tileRow, 2);
      expect(sheets.last.slots.first.tileCol, 2);
    });
  });

  group('Real Printer vs Virtual PDF Printer (Duplex & Paper Size Verification)',
      () {
    const virtualPdfPrinter = PrinterDevice(
      systemName: 'Microsoft Print to PDF',
      driverName: 'Microsoft Print To PDF',
      portName: 'PORTPROMPT:',
      connectionType: PrinterConnectionType.virtual,
      status: PrinterStatusType.ready,
      capabilities: PrinterCapabilities(
        supportsColor: true,
        supportsDuplex: false,
        trays: [PaperTrayCapability(code: 7, name: 'Auto Select')],
      ),
    );

    const physicalDuplexLaser = PrinterDevice(
      systemName: 'HP LaserJet Pro MFP M428fdw',
      driverName: 'HP Universal Printing PCL 6',
      portName: 'USB001',
      connectionType: PrinterConnectionType.usb,
      status: PrinterStatusType.ready,
      capabilities: PrinterCapabilities(
        supportsColor: false, // Monochrome Laser
        supportsDuplex: true,
        paperSizes: [
          PaperSizeCapability(code: 9, name: 'A4', widthMm: 210, heightMm: 297),
          PaperSizeCapability(
            code: 1,
            name: 'Letter',
            widthMm: 215.9,
            heightMm: 279.4,
          ),
          PaperSizeCapability(
            code: 5,
            name: 'Legal',
            widthMm: 215.9,
            heightMm: 355.6,
          ),
        ],
        trays: [
          PaperTrayCapability(code: 7, name: 'Auto Select'),
          PaperTrayCapability(code: 1, name: 'Tray 1'),
          PaperTrayCapability(code: 2, name: 'Tray 2'),
        ],
      ),
    );

    test(
        'Virtual PDF printer disables Duplex, Tray & Media Type with explicit explanation',
        () {
      const requested = FilePrintSettings(
        duplex: DuplexMode.longEdge,
        paperSize: 'A4',
        isColor: true,
      );

      final eval = PrintLayoutEngine.evaluateCapabilityRestrictions(
        settings: requested,
        printer: virtualPdfPrinter,
      );

      expect(eval.duplexSupported, isFalse);
      expect(eval.traySelectionSupported, isFalse);
      expect(eval.mediaTypeSupported, isFalse);
      expect(eval.sanitizedSettings.duplex, DuplexMode.none);
      expect(eval.noticeFor('duplex', 'en'), contains('does not support'));
      expect(eval.noticeFor('duplex', 'si'), contains('සහය නොදක්වයි'));

      final devModeReport = Win32DevModeConfigurator.verifyAndApplyDevMode(
        printer: virtualPdfPrinter,
        settings: requested,
      );
      expect(devModeReport.duplexVerified, isFalse);
      expect(devModeReport.appliedDuplexCode, 1); // DMDUP_SIMPLEX
      expect(devModeReport.appliedPaperSizeCode, 9); // DMPAPER_A4
    });

    test(
        'Physical monochrome Duplex Laser accepts Duplex & Trays but disables Color with explanation',
        () {
      const requested = FilePrintSettings(
        duplex: DuplexMode.longEdge,
        paperSize: 'Legal',
        isColor: true,
        paperTray: 'Tray 2',
      );

      final eval = PrintLayoutEngine.evaluateCapabilityRestrictions(
        settings: requested,
        printer: physicalDuplexLaser,
      );

      expect(eval.duplexSupported, isTrue);
      expect(eval.colorSupported, isFalse);
      expect(eval.traySelectionSupported, isTrue);
      // Coerced to B&W since physical laser is monochrome
      expect(eval.sanitizedSettings.isColor, isFalse);
      expect(eval.sanitizedSettings.duplex, DuplexMode.longEdge);
      expect(eval.noticeFor('color', 'en'), contains('monochrome'));

      final devModeReport = Win32DevModeConfigurator.verifyAndApplyDevMode(
        printer: physicalDuplexLaser,
        settings: eval.sanitizedSettings,
      );
      expect(devModeReport.duplexVerified, isTrue);
      expect(devModeReport.appliedDuplexCode, 2); // DMDUP_VERTICAL (Long-Edge)
      expect(devModeReport.appliedPaperSizeCode, 5); // DMPAPER_LEGAL
    });
  });

  group('Presets SQLite Persistence', () {
    late Directory tempDir;
    late SqlitePresetsPersistence persistence;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('print_helper_presets_');
      persistence = SqlitePresetsPersistence(
        overrideDbPath: p.join(tempDir.path, 'test_presets.sqlite'),
      );
      await persistence.init();
    });

    tearDown(() async {
      persistence.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Includes "Double-sided B&W draft" built-in and saves custom presets',
        () async {
      final initial = await persistence.loadPresets();
      expect(
        initial.any((p) => p.name == 'Double-sided B&W draft'),
        isTrue,
      );

      final saved = await persistence.saveCustomPreset(
        name: 'Sinhala Booklet A4',
        description: 'A4 Landscape Booklet with Sinhala Header',
        settings: const FilePrintSettings(
          layoutMode: SheetLayoutMode.booklet,
          orientation: PageOrientation.landscape,
          duplex: DuplexMode.shortEdge,
          headerText: 'ශ්‍රී ලංකා නිල ප්‍රකාශනය',
          showPageNumbers: true,
        ),
      );

      final afterSave = await persistence.loadPresets();
      final match = afterSave.firstWhere((p) => p.id == saved.id);
      expect(match.name, 'Sinhala Booklet A4');
      expect(match.settings.layoutMode, SheetLayoutMode.booklet);
      expect(match.settings.headerText, 'ශ්‍රී ලංකා නිල ප්‍රකාශනය');

      await persistence.deletePreset(saved.id);
      final afterDelete = await persistence.loadPresets();
      expect(afterDelete.any((p) => p.id == saved.id), isFalse);
    });
  });
}
