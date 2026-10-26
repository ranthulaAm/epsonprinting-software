import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/features/workspace/domain/print_queue_item.dart';
import 'package:print_helper/features/workspace/domain/print_settings_models.dart';
import 'package:print_helper/services/printer/capability_discovery_service.dart';

void main() {
  group('Print Helper Three-Tier Print Settings & CapabilityDiscovery Tests', () {
    test('assets/profiles/epson_profiles.json is valid and covers all families', () {
      final file = File('assets/profiles/epson_profiles.json');
      expect(file.existsSync(), isTrue, reason: 'Profile file must exist');

      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      expect(json['schemaVersion'], isNotNull);
      expect(json['families'], isA<List>());

      final families = json['families'] as List<dynamic>;
      expect(families.length, greaterThanOrEqualTo(8));

      final requiredTraits = [
        'EcoTank',
        'WorkForce',
        'WorkForce Pro',
        'WorkForce Enterprise AM-C',
        'Expression',
        'Stylus Photo',
        'SureColor',
        'laser AL-M/AL-C',
      ];

      for (final trait in requiredTraits) {
        final found = families.any((f) => (f as Map<String, dynamic>)['familyTrait'] == trait);
        expect(found, isTrue, reason: 'Family trait $trait must be defined in epson_profiles.json');
      }

      for (final f in families) {
        final fam = f as Map<String, dynamic>;
        expect(fam['familyId'], isNotNull);
        expect(fam['familyName'], isNotNull);
        expect(fam['supplyTechnology'], isNotNull);
        expect(fam['colorLayout'], isNotNull);
        expect(fam['verificationStatus'], isIn(['verified', 'unverified']));
        expect(fam['supportedPaperSizes'], isNotEmpty);
        expect(fam['supportedMediaTypes'], isNotEmpty);
      }
    });

    test('UnifiedPrintSettings plain-language summary in English and Spoken Sinhala', () {
      const basicSettings = UnifiedPrintSettings(
        tier: PrintSettingsTier.basic,
        paperSize: 'A4',
        mediaType: 'Plain Paper',
        isColor: false,
        duplex: DuplexMode.longEdge,
        copies: 2,
      );

      final summaryEn = basicSettings.generateSummaryEn();
      expect(summaryEn, contains('A4'));
      expect(summaryEn, contains('Plain Paper'));
      expect(summaryEn, contains('Black & White'));
      expect(summaryEn, contains('Double-sided (long edge)'));
      expect(summaryEn, contains('2 copies'));

      final summarySi = basicSettings.generateSummarySi();
      expect(summarySi, contains('A4'));
      expect(summarySi, contains('සාමාන්‍ය කඩදාසි'));
      expect(summarySi, contains('කළු සුදු'));
      expect(summarySi, contains('දෙපැත්තෙන්ම'));
      expect(summarySi, contains('කොපි 2'));
    });

    test('Media-first dependency validator detects Photo Paper + Duplex conflict and auto-fixes', () {
      final caps = DiscoveredCapabilities.genericFallback('Epson EcoTank L3250');
      const conflictedSettings = UnifiedPrintSettings(
        mediaType: 'Epson Premium Glossy',
        duplex: DuplexMode.longEdge,
      );

      final issues = SettingsCapabilityValidator.validate(
        settings: conflictedSettings,
        capabilities: caps,
      );

      expect(issues, isNotEmpty);
      final duplexIssue = issues.firstWhere((i) => i.settingKey == 'duplex');
      expect(duplexIssue.messageEn, contains('does not support double-sided printing'));
      expect(duplexIssue.autoFix, isNotNull);

      // Execute auto-fix
      final fixed = duplexIssue.autoFix!.applyFix(conflictedSettings);
      expect(fixed.duplex, equals(DuplexMode.none));

      // Revalidate
      final postFixIssues = SettingsCapabilityValidator.validate(
        settings: fixed,
        capabilities: caps,
      );
      final remainingDuplexIssues = postFixIssues.where((i) => i.settingKey == 'duplex').toList();
      expect(remainingDuplexIssues, isEmpty);
    });

    test('Media-first validator detects Borderless conflict on non-borderless printers', () {
      final monoLaserCaps = DiscoveredCapabilities(
        printerName: 'HP LaserJet Pro M404dn',
        modelName: 'HP LaserJet Pro M404dn',
        familyName: 'HP LaserJet Mono',
        familyTrait: 'Laser Mono',
        supplyTechnology: 'toner',
        colorLayout: 'mono',
        hasDigitalInkPercentage: true,
        hasReplaceableMaintenanceBoxWithChip: false,
        isWasteInkPadCounterBased: false,
        supportedPaperSizes: const ['A4', 'Letter'],
        supportedMediaTypes: const ['Plain Paper'],
        inputBins: const ['Tray 1'],
        outputBins: const ['Standard Bin'],
        supportedDuplexModes: const [DuplexMode.none, DuplexMode.longEdge],
        supportsColor: false,
        supportedQualities: const ['Standard'],
        supportedResolutionsDpi: const [600, 1200],
        supportsCollate: true,
        supportsNUp: true,
        supportedPagesPerSheet: const [1, 2, 4],
        supportsScaling: true,
        supportsBorderless: false, // Laser does not support borderless
        borderlessMaxSize: 'none',
        supportsExpansionBleed: false,
        supportsRollPaper: false,
        supportsAutoCut: false,
        supportsCdDvd: false,
        hasScannerAdf: false,
        supportsColorManagement: false,
        installedIccProfiles: const [],
        supportsAdvancedBwToning: false,
        supportsHalftoneScreening: false,
        supportsHighSpeedBidirectional: true,
        supportsInkDensity: false,
        supportsGlossOptimizer: false,
        supportsBlackTankSwitch: false,
        supportsImposition: true,
        supportsPassportIdLayout: false,
        supportsJobPriority: true,
        supportsPdfOverlay: true,
        supportsStamps: true,
        driverSettingsCaptureAvailable: false,
        abilitySources: const {},
        mediaDependencyRules: const [],
        defaultMargins: const {},
        verificationStatus: 'verified',
        verificationNote: 'Verified HP LaserJet specs',
      );

      const borderlessSettings = UnifiedPrintSettings(
        isBorderless: true,
      );

      final issues = SettingsCapabilityValidator.validate(
        settings: borderlessSettings,
        capabilities: monoLaserCaps,
      );

      final borderlessIssue = issues.firstWhere((i) => i.settingKey == 'borderless');
      expect(borderlessIssue.isBlocking, isTrue);
      expect(borderlessIssue.autoFix, isNotNull);

      final fixed = borderlessIssue.autoFix!.applyFix(borderlessSettings);
      expect(fixed.isBorderless, isFalse);
    });

    test('Auto-duplex fallback for printers with manual duplex assistant only (Epson L3250)', () {
      final l3250Caps = DiscoveredCapabilities(
        printerName: 'Epson EcoTank L3250',
        modelName: 'Epson EcoTank L3250',
        familyName: 'Epson EcoTank L Consumer',
        familyTrait: 'EcoTank',
        supplyTechnology: 'inkTank',
        colorLayout: 'cmyk_dye',
        hasDigitalInkPercentage: false,
        hasReplaceableMaintenanceBoxWithChip: false,
        isWasteInkPadCounterBased: true,
        supportedPaperSizes: const ['A4', 'Letter', 'Photo 4x6'],
        supportedMediaTypes: const ['Plain Paper', 'Epson Matte', 'Epson Premium Glossy'],
        inputBins: const ['Rear Feed Slot'],
        outputBins: const ['Standard Output Tray'],
        supportedDuplexModes: const [DuplexMode.none], // Manual duplex assistant only
        supportsColor: true,
        supportedQualities: const ['Draft', 'Standard', 'High'],
        supportedResolutionsDpi: const [300, 600, 1200, 5760],
        supportsCollate: true,
        supportsNUp: true,
        supportedPagesPerSheet: const [1, 2, 4, 6, 9],
        supportsScaling: true,
        supportsBorderless: true,
        borderlessMaxSize: 'A4',
        supportsExpansionBleed: true,
        supportsRollPaper: false,
        supportsAutoCut: false,
        supportsCdDvd: false,
        hasScannerAdf: false,
        supportsColorManagement: true,
        installedIccProfiles: const ['Driver Managed', 'sRGB'],
        supportsAdvancedBwToning: false,
        supportsHalftoneScreening: false,
        supportsHighSpeedBidirectional: true,
        supportsInkDensity: true,
        supportsGlossOptimizer: false,
        supportsBlackTankSwitch: false,
        supportsImposition: true,
        supportsPassportIdLayout: true,
        supportsJobPriority: true,
        supportsPdfOverlay: true,
        supportsStamps: true,
        driverSettingsCaptureAvailable: true,
        abilitySources: const {},
        mediaDependencyRules: const [],
        defaultMargins: const {},
        verificationStatus: 'verified',
        verificationNote: 'Verified against Epson L3250 ESC/P-R specs',
      );

      const duplexOnPlainPaper = UnifiedPrintSettings(
        mediaType: 'Plain Paper',
        duplex: DuplexMode.longEdge,
      );

      final issues = SettingsCapabilityValidator.validate(
        settings: duplexOnPlainPaper,
        capabilities: l3250Caps,
      );

      final duplexIssue = issues.firstWhere((i) => i.settingKey == 'duplex');
      expect(duplexIssue.messageEn, contains('does not have automatic duplex hardware'));
      expect(duplexIssue.autoFix, isNotNull);
      expect(duplexIssue.autoFix!.labelEn, equals('Use Manual Duplex Assistant'));
    });
  });
}
