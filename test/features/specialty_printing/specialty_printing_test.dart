import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:print_helper/features/specialty_printing/data/specialty_printing_service.dart';
import 'package:print_helper/features/specialty_printing/domain/specialty_print_models.dart';

void main() {
  group('Specialty Printing Modules Test Suite', () {
    // ------------------------------------------------------------------------
    // 1. CD/DVD/Blu-ray Mask Geometry & Diameters
    // ------------------------------------------------------------------------
    test('1. CD/DVD mask geometry with known diameters (116mm outer, 43mm inner)', () {
      const outerD = 116.0;
      const innerD = 43.0;

      // Area formula: pi * ((116/2)^2 - (43/2)^2) = pi * (58^2 - 21.5^2)
      // = pi * (3364 - 462.25) = pi * 2901.75 ~= 9116.12 mm^2
      final area = SpecialtyPrintingService.calculateCdDvdPrintableAreaMm2(
        outerDiameterMm: outerD,
        innerDiameterMm: innerD,
      );
      expect(area, closeTo(9116.12, 0.1));

      // Test points relative to center (0, 0)
      // Point at (0, 0) is inside inner hub -> MUST BE FALSE
      expect(SpecialtyPrintingService.isPointInsideCdDvdRing(
        xMm: 0.0, yMm: 0.0, outerDiameterMm: outerD, innerDiameterMm: innerD), isFalse);

      // Point at r = 15mm (diameter 30mm) -> inside inner hub -> FALSE
      expect(SpecialtyPrintingService.isPointInsideCdDvdRing(
        xMm: 15.0, yMm: 0.0, outerDiameterMm: outerD, innerDiameterMm: innerD), isFalse);

      // Point at r = 21.5mm (exact inner boundary) -> TRUE
      expect(SpecialtyPrintingService.isPointInsideCdDvdRing(
        xMm: 21.5, yMm: 0.0, outerDiameterMm: outerD, innerDiameterMm: innerD), isTrue);

      // Point at r = 40mm (middle of ring) -> TRUE
      expect(SpecialtyPrintingService.isPointInsideCdDvdRing(
        xMm: 40.0, yMm: 0.0, outerDiameterMm: outerD, innerDiameterMm: innerD), isTrue);

      // Point at r = 58.0mm (exact outer boundary) -> TRUE
      expect(SpecialtyPrintingService.isPointInsideCdDvdRing(
        xMm: 0.0, yMm: 58.0, outerDiameterMm: outerD, innerDiameterMm: innerD), isTrue);

      // Point at r = 60.0mm (outside outer boundary) -> FALSE
      expect(SpecialtyPrintingService.isPointInsideCdDvdRing(
        xMm: 60.0, yMm: 0.0, outerDiameterMm: outerD, innerDiameterMm: innerD), isFalse);
    });

    test('2. Mini 8cm Disc mask geometry (80mm outer, 18mm inner)', () {
      const outerD = 80.0;
      const innerD = 18.0;

      // Area: pi * (40^2 - 9^2) = pi * (1600 - 81) = pi * 1519 ~= 4772.11 mm^2
      final area = SpecialtyPrintingService.calculateCdDvdPrintableAreaMm2(
        outerDiameterMm: outerD,
        innerDiameterMm: innerD,
      );
      expect(area, closeTo(4772.11, 0.1));

      // Point at r = 25mm -> TRUE
      expect(SpecialtyPrintingService.isPointInsideCdDvdRing(
        xMm: 25.0, yMm: 0.0, outerDiameterMm: outerD, innerDiameterMm: innerD), isTrue);

      // Point at r = 45mm -> outside 40mm radius -> FALSE
      expect(SpecialtyPrintingService.isPointInsideCdDvdRing(
        xMm: 45.0, yMm: 0.0, outerDiameterMm: outerD, innerDiameterMm: innerD), isFalse);
    });

    test('3. Circular text path calculation on disc perimeter', () {
      final path = SpecialtyPrintingService.calculateCircularTextPath(
        text: 'WEDDING 2026',
        radiusMm: 45.0,
        startAngleDeg: 0.0,
        charSpacingDeg: 5.0,
      );

      expect(path.length, equals(12));
      // First character 'W' at angle 0 deg -> x = 45.0, y = 0.0
      expect(path[0].char, equals('W'));
      expect(path[0].xMm, closeTo(45.0, 0.01));
      expect(path[0].yMm, closeTo(0.0, 0.01));
    });

    // ------------------------------------------------------------------------
    // 2. PVC ID Card Module
    // ------------------------------------------------------------------------
    test('4. CR80 standard card dimensions and dual-slot tray calibration', () {
      expect(SpecialtyPrintingService.isValidCr80Dimensions(85.60, 53.98), isTrue);
      expect(SpecialtyPrintingService.isValidCr80Dimensions(85.80, 54.10), isTrue); // within 0.5mm
      expect(SpecialtyPrintingService.isValidCr80Dimensions(90.0, 54.0), isFalse);

      // Test calibration offset of (+1.5mm, -0.5mm)
      final coords = SpecialtyPrintingService.calculateCardTrayLayoutCoordinates(
        offsetXmm: 1.5,
        offsetYmm: -0.5,
        trayLeftMarginMm: 15.0,
        trayTopMarginMm: 20.0,
        slotGapMm: 10.0,
      );

      expect(coords.slot1X, equals(16.5));
      expect(coords.slot1Y, equals(19.5));
      // Slot 2 Y = 20.0 + 53.98 + 10.0 - 0.5 = 83.48 mm
      expect(coords.slot2Y, closeTo(83.48, 0.01));
    });

    test('5. PVC CSV batch parser extracts valid employee records', () {
      const csv = '''ID,Name,Title,Org
EMP-001,Kasun Perera,Software Engineer,Colombo Tech
EMP-002,Nimali Silva,Graphic Designer,Creative Labs''';

      final cards = SpecialtyPrintingService.parsePvcCardBatchCsv(csv);
      expect(cards.length, equals(2));
      expect(cards[0].cardId, equals('EMP-001'));
      expect(cards[0].fullName, equals('Kasun Perera'));
      expect(cards[1].fullName, equals('Nimali Silva'));
    });

    // ------------------------------------------------------------------------
    // 3. Passport & ID Photo Sheets Imposition
    // ------------------------------------------------------------------------
    test('6. Passport photo imposition grid on 4x6" paper (35x45 mm)', () {
      // 4x6" sheet = 101.6 x 152.4 mm
      // Photo 35 x 45 mm, margin 5 mm, gap 2 mm
      final grid = SpecialtyPrintingService.calculatePassportImposition(
        photoWidthMm: 35.0,
        photoHeightMm: 45.0,
        sheetWidthMm: 101.6,
        sheetHeightMm: 152.4,
        minMarginMm: 5.0,
        gapBetweenPhotosMm: 2.0,
      );

      // Width: 101.6 - 10 = 91.6 mm. (91.6 + 2) / (35 + 2) = 2 columns
      // Height: 152.4 - 10 = 142.4 mm. (142.4 + 2) / (45 + 2) = 3 rows
      // Total fit: 2 * 3 = 6 photos (or rotated: 2 * 3 = 6 photos)
      expect(grid.totalFit, greaterThanOrEqualTo(6));
      expect(grid.leftMarginMm, greaterThan(0.0));
      expect(grid.topMarginMm, greaterThan(0.0));
    });

    test('7. Passport photo imposition on A4 paper (210 x 297 mm)', () {
      final grid = SpecialtyPrintingService.calculatePassportImposition(
        photoWidthMm: 35.0,
        photoHeightMm: 45.0,
        sheetWidthMm: 210.0,
        sheetHeightMm: 297.0,
        minMarginMm: 10.0,
        gapBetweenPhotosMm: 3.0,
      );

      // Usable: 190 x 277 mm
      // Normal: (190+3)/(35+3) = 5 cols; (277+3)/(45+3) = 5 rows -> 25 photos
      // Rotated: (190+3)/(45+3) = 4 cols; (277+3)/(35+3) = 7 rows -> 28 photos
      // Rotated should yield 28 photos!
      expect(grid.totalFit, greaterThanOrEqualTo(25));
    });

    // ------------------------------------------------------------------------
    // 4. Rigid Media Thickness Limit Guardrails
    // ------------------------------------------------------------------------
    test('8. Rigid media thickness validation blocks excessive thickness', () {
      // Safe thickness (0.8mm on 1.3mm limit)
      final safeResult = SpecialtyPrintingService.validateRigidMediaThickness(
        mediaThicknessMm: 0.8,
        printerMaxLimitMm: 1.3,
      );
      expect(safeResult.isAllowed, isTrue);
      expect(safeResult.excessThicknessMm, equals(0.0));

      // Excessive thickness (1.8mm on 1.3mm limit) -> BLOCKED
      final blockedResult = SpecialtyPrintingService.validateRigidMediaThickness(
        mediaThicknessMm: 1.8,
        printerMaxLimitMm: 1.3,
      );
      expect(blockedResult.isAllowed, isFalse);
      expect(blockedResult.excessThicknessMm, closeTo(0.5, 0.01));
      expect(blockedResult.messageEn, contains('exceeds printer hardware limit'));
      expect(blockedResult.messageSi, contains('ප්‍රින්ටරයේ උපරිම සීමාවට වඩා වැඩිය'));
    });

    // ------------------------------------------------------------------------
    // 5. Dye-Sublimation Mirror Geometry
    // ------------------------------------------------------------------------
    test('9. Dye-sublimation coordinates horizontal mirror flip', () {
      // Mug wrap template 200 mm wide
      // Point at x = 20 mm, y = 50 mm
      final mirror = SpecialtyPrintingService.calculateSublimationMirrorCoordinate(
        x: 20.0,
        y: 50.0,
        itemWidthMm: 200.0,
      );

      // x' = 200 - 20 = 180 mm, y' = 50 mm
      expect(mirror.mirroredX, equals(180.0));
      expect(mirror.mirroredY, equals(50.0));
    });

    // ------------------------------------------------------------------------
    // 6. Shop Counter POS Receipt Formatting
    // ------------------------------------------------------------------------
    test('10. Thermal POS receipt string and ESC/POS command generation', () {
      final spec = ShopReceiptSpec(
        paperWidth: ReceiptPaperWidth.width80mm,
        timestamp: DateTime(2026, 10, 27, 2, 30),
        invoiceNumber: 'INV-0982',
        cashierName: 'Sunil',
        customerName: 'Kamal',
        lineItems: [
          {'description': 'A4 B&W Copies', 'quantity': 20, 'price': 300.0},
          {'description': 'A4 Color Glossy', 'quantity': 2, 'price': 150.0},
        ],
        subtotal: 450.0,
        discountAmount: 45.0,
        taxAmount: 0.0,
        grandTotal: 405.0,
        paymentMethod: 'Cash',
        autoCutPaper: true,
      );

      final text = SpecialtyPrintingService.formatShopCounterReceipt(spec);
      expect(text, contains('PRINT HELPER COMMERCIAL COPY CENTER'));
      expect(text, contains('INVOICE: INV-0982'));
      expect(text, contains('A4 B&W Copies x20'));
      expect(text, contains('Rs. 405.00'));

      final bytes = SpecialtyPrintingService.generateEscPosReceiptBytes(spec);
      expect(bytes.length, greaterThan(100));
      // First two bytes: ESC @ (0x1B, 0x40)
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));
      // Last three bytes: GS V 0 (0x1D, 0x56, 0x00) for paper cut
      expect(bytes[bytes.length - 3], equals(0x1D));
      expect(bytes[bytes.length - 2], equals(0x56));
      expect(bytes[bytes.length - 1], equals(0x00));
    });

    // ------------------------------------------------------------------------
    // 7. Capability Gating (Module Unlock Only When Supported)
    // ------------------------------------------------------------------------
    test('11. Capability Gate unlocks modules ONLY when printer supports them', () {
      // Epson L3250 (Basic A4 tank, no CD/DVD, no PVC tray, no roll, standard 0.3mm)
      final l3250Modules = SpecialtyCapabilityGate.evaluateSupportedModules(
        printerName: 'EPSON L3250 Series',
        supportsCdDvdDirect: false,
        supportsPvcCardTray: false,
        supportsRollCutter: false,
        supportsSublimation: false,
        supportsLabelMedia: false,
        supportsPosReceipt: false,
        maxThicknessLimitMm: 0.3,
      );
      expect(l3250Modules.contains(SpecialtyModuleType.passportPhotoSheet), isTrue);
      expect(l3250Modules.contains(SpecialtyModuleType.cdDvdDisc), isFalse);
      expect(l3250Modules.contains(SpecialtyModuleType.pvcIdCard), isFalse);
      expect(l3250Modules.contains(SpecialtyModuleType.rigidMedia), isFalse);

      // Epson L8050 (Photo tank with CD/DVD and PVC ID card tray)
      final l8050Modules = SpecialtyCapabilityGate.evaluateSupportedModules(
        printerName: 'EPSON L8050 Series',
        supportsCdDvdDirect: true,
        supportsPvcCardTray: true,
        supportsRollCutter: false,
        supportsSublimation: false,
        supportsLabelMedia: false,
        supportsPosReceipt: false,
        maxThicknessLimitMm: 0.3,
      );
      expect(l8050Modules.contains(SpecialtyModuleType.cdDvdDisc), isTrue);
      expect(l8050Modules.contains(SpecialtyModuleType.pvcIdCard), isTrue);
      expect(l8050Modules.contains(SpecialtyModuleType.rollCutter), isFalse);

      // Epson L8180 (A3+ Photo tank with CD/DVD and 1.3mm rigid posterboard path)
      final l8180Modules = SpecialtyCapabilityGate.evaluateSupportedModules(
        printerName: 'EPSON L8180 Series',
        supportsCdDvdDirect: true,
        supportsPvcCardTray: false,
        supportsRollCutter: false,
        supportsSublimation: false,
        supportsLabelMedia: false,
        supportsPosReceipt: false,
        maxThicknessLimitMm: 1.3,
      );
      expect(l8180Modules.contains(SpecialtyModuleType.cdDvdDisc), isTrue);
      expect(l8180Modules.contains(SpecialtyModuleType.rigidMedia), isTrue);
      expect(l8180Modules.contains(SpecialtyModuleType.rollCutter), isFalse);

      // Epson SC-F100 (Dye Sublimation transfer)
      final scF100Modules = SpecialtyCapabilityGate.evaluateSupportedModules(
        printerName: 'EPSON SC-F100 Series',
        supportsCdDvdDirect: false,
        supportsPvcCardTray: false,
        supportsRollCutter: false,
        supportsSublimation: true,
        supportsLabelMedia: false,
        supportsPosReceipt: false,
        maxThicknessLimitMm: 0.3,
      );
      expect(scF100Modules.contains(SpecialtyModuleType.dyeSublimation), isTrue);

      // Epson TM-T88VI (POS Thermal receipt printer)
      final tmT88Modules = SpecialtyCapabilityGate.evaluateSupportedModules(
        printerName: 'EPSON TM-T88VI',
        supportsCdDvdDirect: false,
        supportsPvcCardTray: false,
        supportsRollCutter: false,
        supportsSublimation: false,
        supportsLabelMedia: false,
        supportsPosReceipt: true,
        maxThicknessLimitMm: 0.1,
      );
      expect(tmT88Modules.contains(SpecialtyModuleType.shopReceipt), isTrue);
      expect(tmT88Modules.contains(SpecialtyModuleType.cdDvdDisc), isFalse);
    });
  });
}
