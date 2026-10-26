import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/features/shop_mode/data/shop_mode_persistence_and_services.dart';
import 'package:print_helper/features/shop_mode/domain/shop_mode_models.dart';
import 'package:print_helper/features/workspace/domain/print_queue_item.dart';
import 'package:print_helper/features/workspace/domain/print_settings_models.dart';
import 'package:print_helper/features/workspace/domain/tone_and_ink_models.dart';
import 'package:print_helper/services/printer/capability_discovery_service.dart';

void main() {
  group('Tone & Ink Panel, Coverage Analyzer & Honest UI Tests', () {
    test('1. ToneAndInkSettings default values and hasActiveAdjustments state', () {
      const def = ToneAndInkSettings();
      expect(def.density, equals(0));
      expect(def.brightness, equals(0));
      expect(def.contrast, equals(0));
      expect(def.gamma, equals(1.0));
      expect(def.shadows, equals(0));
      expect(def.highlights, equals(0));
      expect(def.saturation, equals(0));
      expect(def.vibrance, equals(0));
      expect(def.blackLevel, equals(0));
      expect(def.textDarkness, equals(0));
      expect(def.textSharpening, equals(0));
      expect(def.photoSharpening, equals(0));
      expect(def.inkSaverEnabled, isFalse);
      expect(def.paperCompensation, equals(PaperCompensationPreset.none));
      expect(def.hasActiveAdjustments, isFalse);

      final adjusted = def.copyWith(density: 15, textDarkness: 20);
      expect(adjusted.hasActiveAdjustments, isTrue);

      final reset = adjusted.resetToDefault();
      expect(reset.hasActiveAdjustments, isFalse);
    });

    test('2. Paper compensation presets apply targeted media absorption curves', () {
      const def = ToneAndInkSettings();

      final plain = def.applyPaperCompensation(PaperCompensationPreset.plainPaper);
      expect(plain.paperCompensation, equals(PaperCompensationPreset.plainPaper));
      expect(plain.shadows, equals(8));
      expect(plain.density, equals(-6)); // Reduced to mitigate bleed
      expect(plain.textDarkness, equals(12));
      expect(plain.textSharpening, equals(15));

      final matte = def.applyPaperCompensation(PaperCompensationPreset.mattePaper);
      expect(matte.paperCompensation, equals(PaperCompensationPreset.mattePaper));
      expect(matte.blackLevel, equals(12));
      expect(matte.gamma, equals(1.08));

      final glossy = def.applyPaperCompensation(PaperCompensationPreset.glossyPhoto);
      expect(glossy.paperCompensation, equals(PaperCompensationPreset.glossyPhoto));
      expect(glossy.contrast, equals(10));
      expect(glossy.vibrance, equals(8));
      expect(glossy.saturation, equals(6));
    });

    test('3. Ink saver modes estimate realistic savings percentages', () {
      const def = ToneAndInkSettings();
      expect(def.estimatedSavingsPercent, equals(0.0));

      final light = def.copyWith(inkSaverEnabled: true, inkSaverLevel: InkSaverLevel.light);
      expect(light.estimatedSavingsPercent, equals(15.0));

      final balanced = def.copyWith(inkSaverEnabled: true, inkSaverLevel: InkSaverLevel.balanced);
      expect(balanced.estimatedSavingsPercent, equals(28.0));

      final aggressive = def.copyWith(inkSaverEnabled: true, inkSaverLevel: InkSaverLevel.aggressive);
      expect(aggressive.estimatedSavingsPercent, equals(42.0));

      // With text-only black enabled (+5%)
      final withTextOnly = balanced.copyWith(inkSaverTextOnlyBlack: true);
      expect(withTextOnly.estimatedSavingsPercent, equals(33.0));
    });

    test('4. Double adjustment detection flags conflict between driver and app', () {
      // Both driver and app adjustments active -> trigger warning
      final conflictSettings = UnifiedPrintSettings(
        toneAndInk: const ToneAndInkSettings(
          density: 15,
          contrast: 10,
          driverColorAdjustmentActive: true,
          appToneAdjustmentActive: true,
        ),
      );

      expect(conflictSettings.toneAndInk.isDoubleAdjustmentWarning, isTrue);

      final issues = SettingsCapabilityValidator.validate(conflictSettings);
      final doubleAdjIssue = issues.firstWhere((i) => i.settingKey == 'toneAndInk_doubleAdjustment');
      expect(doubleAdjIssue.messageEn, contains('Double color adjustment detected'));
      expect(doubleAdjIssue.autoFix, isNotNull);
      expect(doubleAdjIssue.autoFix!.labelEn, equals('Let Print Helper Manage Tone'));

      // Apply fix
      final fixed = doubleAdjIssue.autoFix!.applyFix(conflictSettings);
      expect(fixed.toneAndInk.isDoubleAdjustmentWarning, isFalse);
    });

    test('5. Plain paper heavy density bleed warning and auto-fix', () {
      final heavyPlain = UnifiedPrintSettings(
        mediaType: 'Plain Paper',
        toneAndInk: const ToneAndInkSettings(density: 35),
      );

      final issues = SettingsCapabilityValidator.validate(heavyPlain);
      final densityIssue = issues.firstWhere((i) => i.settingKey == 'toneAndInk_densityPlain');
      expect(densityIssue.messageEn, contains('causes paper cockling and ink bleed-through'));
      expect(densityIssue.autoFix!.labelEn, equals('Apply Plain Paper Compensation'));

      final fixed = densityIssue.autoFix!.applyFix(heavyPlain);
      expect(fixed.toneAndInk.paperCompensation, equals(PaperCompensationPreset.plainPaper));
      expect(fixed.toneAndInk.density, equals(-6));
    });

    test('6. InkCoverageAnalyzer computes exact CMYK percentages from RGB samples', () {
      // 1. Pure Black: R=0, G=0, B=0 -> K=100%, C=0, M=0, Y=0
      final blackBytes = [0, 0, 0];
      final covBlack = InkCoverageAnalyzer.analyzeRgbBuffer(blackBytes);
      expect(covBlack.blackPercent, equals(100.0));
      expect(covBlack.cyanPercent, equals(0.0));
      expect(covBlack.magentaPercent, equals(0.0));
      expect(covBlack.yellowPercent, equals(0.0));
      expect(covBlack.totalCoveragePercent, equals(100.0));

      // 2. Pure White: R=255, G=255, B=255 -> K=0%, C=0, M=0, Y=0
      final whiteBytes = [255, 255, 255];
      final covWhite = InkCoverageAnalyzer.analyzeRgbBuffer(whiteBytes);
      expect(covWhite.totalCoveragePercent, equals(0.0));

      // 3. Pure Cyan: R=0, G=255, B=255 -> C=100%, M=0, Y=0, K=0
      final cyanBytes = [0, 255, 255];
      final covCyan = InkCoverageAnalyzer.analyzeRgbBuffer(cyanBytes);
      expect(covCyan.cyanPercent, equals(100.0));
      expect(covCyan.magentaPercent, equals(0.0));

      // 4. Pure Magenta: R=255, G=0, B=255 -> M=100%, C=0, Y=0, K=0
      final magBytes = [255, 0, 255];
      final covMag = InkCoverageAnalyzer.analyzeRgbBuffer(magBytes);
      expect(covMag.magentaPercent, equals(100.0));

      // 5. Pure Yellow: R=255, G=255, B=0 -> Y=100%, C=0, M=0, K=0
      final yelBytes = [255, 255, 0];
      final covYel = InkCoverageAnalyzer.analyzeRgbBuffer(yelBytes);
      expect(covYel.yellowPercent, equals(100.0));
    });

    test('7. InkCoverageReport calculates ink volume and ink saver reductions', () {
      const coverage = CmykInkCoverage(
        cyanPercent: 4.0,
        magentaPercent: 3.5,
        yellowPercent: 5.0,
        blackPercent: 7.5,
      );
      expect(coverage.totalCoveragePercent, equals(20.0));
      expect(coverage.coverageTierEn, contains('Standard Office'));

      // 100 pages without saver
      final repStandard = InkCoverageReport.calculate(
        pageCount: 100,
        coverage: coverage,
        baseCostPerPage: 10.0,
        savingsPercent: 0.0,
      );
      // 20% coverage is 4x the 5% ISO baseline
      expect(repStandard.estimatedTotalMl, closeTo(18.0, 0.5));
      expect(repStandard.estimatedSavedLkr, equals(0.0));

      // 100 pages with Balanced Saver (~28% savings)
      final repSaver = InkCoverageReport.calculate(
        pageCount: 100,
        coverage: coverage,
        baseCostPerPage: 10.0,
        savingsPercent: 28.0,
      );
      expect(repSaver.estimatedTotalMl, closeTo(18.0 * (1.0 - 0.28), 0.5));
      expect(repSaver.estimatedSavingsPercent, equals(28.0));
      expect(repSaver.estimatedSavedLkr, greaterThan(0.0));
    });

    test('8. Serialization preserves tone settings and curve points in presets and jobs', () {
      const original = ToneAndInkSettings(
        density: -12,
        brightness: 8,
        contrast: 15,
        gamma: 1.15,
        shadows: -5,
        highlights: 10,
        saturation: 12,
        vibrance: 6,
        colorBalanceCyanRed: 4,
        colorBalanceMagentaGreen: -3,
        colorBalanceYellowBlue: 8,
        blackLevel: 6,
        textDarkness: 14,
        textSharpening: 25,
        photoSharpening: 20,
        inkSaverEnabled: true,
        inkSaverLevel: InkSaverLevel.balanced,
        inkSaverTextOnlyBlack: true,
        paperCompensation: PaperCompensationPreset.glossyPhoto,
        masterCurve: [ToneCurvePoint(0, 0), ToneCurvePoint(128, 140), ToneCurvePoint(255, 255)],
      );

      final map = original.toMap();
      final restored = ToneAndInkSettings.fromMap(map);

      expect(restored.density, equals(-12));
      expect(restored.gamma, equals(1.15));
      expect(restored.paperCompensation, equals(PaperCompensationPreset.glossyPhoto));
      expect(restored.inkSaverEnabled, isTrue);
      expect(restored.masterCurve.length, equals(3));
      expect(restored.masterCurve[1].output, equals(140));

      // Check FilePrintSettings wrapping
      final fileSettings = FilePrintSettings(
        copies: 2,
        toneAndInkMap: map,
      );
      final fileMap = fileSettings.toMap();
      expect(fileMap['toneAndInkMap'], isNotNull);
      final restoredFile = FilePrintSettings.fromMap(fileMap);
      expect(restoredFile.toneAndInkMap!['gamma'], equals(1.15));
    });

    test('9. Shop Mode price calculation reflects ink saver cost reduction', () {
      final service = ShopModePersistenceService();
      const costConfig = ShopSupplyCostConfig();

      final standardQueueItem = PrintQueueItem(
        id: 'item_standard',
        path: '/docs/doc1.pdf',
        fileName: 'doc1.pdf',
        pageCount: 10,
        fileSizeBytes: 1024 * 1024,
        addedAt: DateTime.now(),
        settings: const FilePrintSettings(
          copies: 1,
          isColor: true,
          paperSize: 'A4',
          mediaType: 'Plain Paper',
        ),
      );

      final saverQueueItem = PrintQueueItem(
        id: 'item_saver',
        path: '/docs/doc2.pdf',
        fileName: 'doc2.pdf',
        pageCount: 10,
        fileSizeBytes: 1024 * 1024,
        addedAt: DateTime.now(),
        settings: const FilePrintSettings(
          copies: 1,
          isColor: true,
          paperSize: 'A4',
          mediaType: 'Plain Paper',
          toneAndInkMap: {'inkSaverEnabled': true},
        ),
      );

      final estimateStd = service.calculateJobEstimate(
        files: [standardQueueItem],
        priceRules: ShopPriceRule.defaultRulesLkr,
        costConfig: costConfig,
      );

      final estimateSaver = service.calculateJobEstimate(
        files: [saverQueueItem],
        priceRules: ShopPriceRule.defaultRulesLkr,
        costConfig: costConfig,
      );

      // Ink saver reduces estimated ink cost by ~28%
      expect(estimateSaver.estimatedInkOrTonerCost, lessThan(estimateStd.estimatedInkOrTonerCost));
      expect(estimateSaver.lineItems.first.inkSaverSavings, greaterThan(0.0));
    });

    test('10. TestPatternGenerator honest advisory notice', () {
      expect(TestPatternGenerator.advisoryNoticeEn, contains('prints this test pattern as a normal document'));
      expect(TestPatternGenerator.advisoryNoticeEn, contains('never sends unverified raw maintenance commands'));
      expect(TestPatternGenerator.advisoryNoticeSi, contains('සාමාන්‍ය ලේඛනයක් ලෙස මුද්‍රණය කරයි'));
      expect(TestPatternGenerator.advisoryNoticeSi, contains('Epson ඩ්‍රයිවර් Maintenance'));
    });
  });
}
