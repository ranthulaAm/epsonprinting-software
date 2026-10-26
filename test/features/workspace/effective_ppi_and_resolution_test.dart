import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/features/shop_mode/domain/shop_mode_models.dart';
import 'package:print_helper/features/workspace/domain/print_queue_item.dart';
import 'package:print_helper/features/workspace/domain/print_settings_models.dart';
import 'package:print_helper/features/workspace/domain/resolution_system_models.dart';

void main() {
  group('Resolution System: PPI vs DPI Math & Validation Tests', () {
    test('1. Full-bleed A4 photo (3508x2480 px, 0mm margins) yields >= 300 PPI (Crisp)', () {
      // 2480 x 3508 is standard A4 at 300 PPI (210 x 297 mm)
      final eval = EffectivePpiCalculator.evaluate(
        pixelWidth: 2480,
        pixelHeight: 3508,
        paperSize: 'A4',
        marginPreset: MarginPreset.none,
        scaleMode: PrintScaleMode.fitToPage,
      );

      expect(eval.effectivePpi, greaterThanOrEqualTo(299.0));
      expect(eval.rating, equals(PpiQualityRating.crisp));
      expect(eval.rating.minPpi, equals(300.0));
      expect(eval.explanationEn, contains('300 PPI'));
      expect(eval.explanationEn, contains('Photo-grade'));
      expect(eval.explanationSi, contains('ඉතා පැහැදිලිව'));
    });

    test('2. Low-res web image (800x600 px on A4 fit-to-page) yields ~69-70 PPI (Low/Pixelated)', () {
      final eval = EffectivePpiCalculator.evaluate(
        pixelWidth: 800,
        pixelHeight: 600,
        paperSize: 'A4',
        marginPreset: MarginPreset.normal, // 12.7mm margin
        scaleMode: PrintScaleMode.fitToPage,
      );

      // On A4 printable height ~271.6mm = 10.69 in. 600 px / 10.69 in = ~56-70 PPI
      expect(eval.effectivePpi, lessThan(150.0));
      expect(eval.rating, equals(PpiQualityRating.low));
      expect(eval.explanationEn, contains('May look soft or pixelated'));
      expect(eval.explanationSi, contains('මුද්‍රණය බොඳ විය හැක'));
    });

    test('3. Landscape orientation correctly swaps printable dimensions', () {
      final portraitEval = EffectivePpiCalculator.evaluate(
        pixelWidth: 1200,
        pixelHeight: 1800,
        paperSize: 'A4',
        orientation: PageOrientation.portrait,
        marginPreset: MarginPreset.none,
        scaleMode: PrintScaleMode.fitToPage,
      );

      final landscapeEval = EffectivePpiCalculator.evaluate(
        pixelWidth: 1800,
        pixelHeight: 1200,
        paperSize: 'A4',
        orientation: PageOrientation.landscape,
        marginPreset: MarginPreset.none,
        scaleMode: PrintScaleMode.fitToPage,
      );

      expect(landscapeEval.isRotated, isTrue);
      // Both should yield the same ~145-154 PPI range since aspect ratios match flipped paper
      expect((portraitEval.effectivePpi - landscapeEval.effectivePpi).abs(), lessThan(2.0));
    });

    test('4. Cropping reduces pixel dimensions and proportionately lowers effective PPI on same sheet', () {
      final fullEval = EffectivePpiCalculator.evaluate(
        pixelWidth: 2000,
        pixelHeight: 2000,
        paperSize: '4x6 in (10x15 cm)',
        marginPreset: MarginPreset.none,
        scaleMode: PrintScaleMode.fitToPage,
      );

      // Crop to half width and height (1000x1000 px)
      final croppedEval = EffectivePpiCalculator.evaluate(
        pixelWidth: 2000,
        pixelHeight: 2000,
        paperSize: '4x6 in (10x15 cm)',
        marginPreset: MarginPreset.none,
        scaleMode: PrintScaleMode.fitToPage,
        cropRectPixels: const Rect.fromLTWH(0, 0, 1000, 1000),
      );

      expect(croppedEval.isCropped, isTrue);
      expect(croppedEval.pixelWidth, equals(1000));
      expect(croppedEval.pixelHeight, equals(1000));
      expect(croppedEval.effectivePpi, closeTo(fullEval.effectivePpi / 2.0, 1.0));
    });

    test('5. Custom scaling scales effective PPI inversely (50% scale doubles PPI, 200% scale halves PPI)', () {
      final eval100 = EffectivePpiCalculator.evaluate(
        pixelWidth: 1500,
        pixelHeight: 1000,
        paperSize: 'A4',
        scaleMode: PrintScaleMode.customPercent,
        customScalePercent: 100.0,
      );

      final eval50 = EffectivePpiCalculator.evaluate(
        pixelWidth: 1500,
        pixelHeight: 1000,
        paperSize: 'A4',
        scaleMode: PrintScaleMode.customPercent,
        customScalePercent: 50.0,
      );

      final eval200 = EffectivePpiCalculator.evaluate(
        pixelWidth: 1500,
        pixelHeight: 1000,
        paperSize: 'A4',
        scaleMode: PrintScaleMode.customPercent,
        customScalePercent: 200.0,
      );

      expect(eval100.effectivePpi, closeTo(300.0, 0.5));
      // At 50% scale, printed size is halved, so PPI is doubled to 600
      expect(eval50.effectivePpi, closeTo(600.0, 1.0));
      // At 200% scale, printed size is doubled, so PPI is halved to 150
      expect(eval200.effectivePpi, closeTo(150.0, 1.0));
    });

    test('6. N-up page division reduces image cell size, increasing effective PPI', () {
      final oneUp = EffectivePpiCalculator.evaluate(
        pixelWidth: 1000,
        pixelHeight: 1400,
        paperSize: 'A4',
        pagesPerSheet: 1,
      );

      final fourUp = EffectivePpiCalculator.evaluate(
        pixelWidth: 1000,
        pixelHeight: 1400,
        paperSize: 'A4',
        pagesPerSheet: 4, // 2x2 grid, scale factor 0.5
      );

      expect(fourUp.nUpCount, equals(4));
      // In 4-up mode, the target area width/height is halved, doubling the PPI
      expect(fourUp.effectivePpi, closeTo(oneUp.effectivePpi * 2.0, 2.0));
    });

    test('7. PhotoPrintSizeSuggestion recommends 4x6 in for 1800x1200 px image (300 PPI)', () {
      // 1800x1200 px:
      // On 4x6 in: 1800/6 = 300 PPI, 1200/4 = 300 PPI -> Crisp!
      // On 8x10 in: 1800/10 = 180 PPI -> Acceptable only
      final suggestions = EffectivePpiCalculator.suggestBestSizes(1800, 1200);

      expect(suggestions, isNotEmpty);
      final photo4x6 = suggestions.firstWhere((s) => s.sizeName.contains('4x6'));
      expect(photo4x6.expectedPpi, closeTo(300.0, 1.0));
      expect(photo4x6.rating, equals(PpiQualityRating.crisp));
      expect(photo4x6.isRecommendedForSource, isTrue);

      final photo8x10 = suggestions.firstWhere((s) => s.sizeName.contains('8x10'));
      expect(photo8x10.expectedPpi, lessThan(200.0));
      expect(photo8x10.rating, equals(PpiQualityRating.acceptable));
      expect(photo8x10.isRecommendedForSource, isFalse);
    });

    test('8. Raster memory footprint estimation for 300, 600, and 1200 DPI on A4', () {
      const a4WidthInches = 210.0 / 25.4; // 8.2677 in
      const a4HeightInches = 297.0 / 25.4; // 11.6929 in

      final mem300 = EffectivePpiCalculator.estimateRasterMemoryMb(
        pageWInches: a4WidthInches,
        pageHInches: a4HeightInches,
        renderDpi: 300,
      );

      final mem600 = EffectivePpiCalculator.estimateRasterMemoryMb(
        pageWInches: a4WidthInches,
        pageHInches: a4HeightInches,
        renderDpi: 600,
      );

      final mem1200 = EffectivePpiCalculator.estimateRasterMemoryMb(
        pageWInches: a4WidthInches,
        pageHInches: a4HeightInches,
        renderDpi: 1200,
      );

      // Memory scales with square of DPI:
      // 300 DPI ~ 25-27 MB
      // 600 DPI ~ 100-108 MB
      // 1200 DPI ~ 410-430 MB
      expect(mem300, inInclusiveRange(24.0, 28.0));
      expect(mem600, inInclusiveRange(98.0, 112.0));
      expect(mem1200, inInclusiveRange(380.0, 420.0));
      expect(mem1200, closeTo(mem300 * 16.0, 5.0)); // 4x DPI = 16x memory
    });

    test('9. Printer hardware DPI options with speed/ink notes and media blocking', () {
      final draftPlain = PrinterDpiOptionInfo.forDpi(dpi: 360, mediaType: 'Plain Paper');
      expect(draftPlain.isSupportedOnCurrentMedia, isTrue);
      expect(draftPlain.labelEn, contains('Fast / Draft'));
      expect(draftPlain.speedAndInkNoteEn, contains('Fastest printing speed'));

      final draftGlossy = PrinterDpiOptionInfo.forDpi(dpi: 360, mediaType: 'Epson Premium Glossy');
      expect(draftGlossy.isSupportedOnCurrentMedia, isFalse);
      expect(draftGlossy.disabledReasonEn, contains('Draft mode is not recommended on glossy photo paper'));

      final photoPlain = PrinterDpiOptionInfo.forDpi(dpi: 2880, mediaType: 'Plain Paper');
      expect(photoPlain.isSupportedOnCurrentMedia, isFalse);
      expect(photoPlain.disabledReasonEn, contains('Plain paper cannot absorb 2400+ DPI'));

      final photoGlossy = PrinterDpiOptionInfo.forDpi(dpi: 2880, mediaType: 'Epson Ultra Glossy');
      expect(photoGlossy.isSupportedOnCurrentMedia, isTrue);
      expect(photoGlossy.labelEn, contains('Best / Photo Grade'));
    });

    test('10. SettingsCapabilityValidator resolution warnings and 1-click auto-fixes', () {
      // Test 10a: Low PPI warning with Lanczos upscale auto-fix
      const lowPpiSettings = UnifiedPrintSettings(
        currentEffectivePpi: 96.0,
        mediaType: 'Plain Paper',
        hardwareDpi: 600,
        renderDpi: RenderDpiChoice.auto,
      );

      final lowPpiIssues = SettingsCapabilityValidator.validate(lowPpiSettings);
      final ppiIssue = lowPpiIssues.firstWhere((i) => i.severity == CapabilityIssueSeverity.warning && i.titleEn.contains('Low Image Resolution'));
      expect(ppiIssue.autoFixActionId, equals('apply_lanczos_upscale_2x'));
      expect(ppiIssue.autoFixLabelEn, contains('Upscale with Lanczos (2x)'));
      expect(ppiIssue.autoFixLabelSi, contains('Lanczos (2x) මඟින් විශාල කරන්න'));

      // Test 10b: Plain paper 2400+ DPI droplet overload warning with switch to 600 DPI fix
      const plainOverloadSettings = UnifiedPrintSettings(
        mediaType: 'Plain Paper',
        hardwareDpi: 2880,
      );

      final overloadIssues = SettingsCapabilityValidator.validate(plainOverloadSettings);
      final overloadIssue = overloadIssues.firstWhere((i) => i.titleEn.contains('Droplet Overload'));
      expect(overloadIssue.autoFixActionId, equals('switch_to_600_dpi'));
      expect(overloadIssue.autoFixLabelEn, contains('Switch to 600 DPI Normal'));

      // Test 10c: 1200 Render DPI high memory warning with switch to auto fix
      const highMemSettings = UnifiedPrintSettings(
        renderDpi: RenderDpiChoice.dpi1200,
      );

      final memIssues = SettingsCapabilityValidator.validate(highMemSettings);
      final memIssue = memIssues.firstWhere((i) => i.titleEn.contains('High Raster Memory'));
      expect(memIssue.autoFixActionId, equals('switch_to_auto_render_dpi'));
      expect(memIssue.autoFixLabelEn, contains('Switch to Auto Render DPI'));
    });

    test('11. FilePrintSettings serialization preserves resolution and resampling options', () {
      const orig = FilePrintSettings(
        copies: 3,
        paperSize: 'Photo 4x6',
        targetDpi: 1440,
        resampleAlgorithm: 'lanczos',
        renderDpiChoice: 'dpi600',
      );

      final map = orig.toMap();
      expect(map['targetDpi'], equals(1440));
      expect(map['resampleAlgorithm'], equals('lanczos'));
      expect(map['renderDpiChoice'], equals('dpi600'));

      final restored = FilePrintSettings.fromMap(map);
      expect(restored.targetDpi, equals(1440));
      expect(restored.resampleAlgorithm, equals('lanczos'));
      expect(restored.renderDpiChoice, equals('dpi600'));
    });

    test('12. Shop File Pricing calculates resolution surcharge for 1440+ DPI photo mode', () {
      const breakdown = ShopFilePricingBreakdown(
        fileId: 'file_1',
        fileName: 'wedding_photo.jpg',
        pageCount: 1,
        copies: 2,
        isColor: true,
        isDoubleSided: false,
        paperSize: 'Photo 4x6',
        paperType: 'Glossy Photo Paper',
        basePricePerPage: 80.0,
        subtotal: 160.0,
        resolutionSurcharge: 25.0, // +25 LKR surcharge for 1440 DPI
        resolutionDpi: 1440,
      );

      expect(breakdown.totalWithSurcharge, equals(185.0));
      expect(breakdown.resolutionDpi, equals(1440));
    });
  });
}
