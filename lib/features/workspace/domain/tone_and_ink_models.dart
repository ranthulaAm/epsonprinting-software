import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Provenance of the adjustment control (A: Driver vs B: App).
enum ToneAdjustmentSource {
  driver(
    labelEn: 'Printer setting',
    labelSi: 'ප්‍රින්ටර් සැකසුම',
    tooltipEn: 'Controlled directly by the printer hardware / Windows driver (Epson driver color adjustments, black ink only, quality modes).',
    tooltipSi: 'ප්‍රින්ටර් ඩ්‍රයිවර් මෘදුකාංගය මඟින් සෘජුවම පාලනය වන සැකසුමකි.',
    color: Color(0xFF0284C7), // Sky blue
    icon: Icons.print_outlined,
  ),
  app(
    labelEn: 'Print Helper adjustment',
    labelSi: 'Print Helper සැකසුම',
    tooltipEn: 'Applied by Print Helper to the page image before sending to the driver. Works uniformly on ANY printer.',
    tooltipSi: 'Print Helper මඟින් ප්‍රින්ටරයට යැවීමට පෙර පිටුවට යොදන සැකසුමකි. ඕනෑම ප්‍රින්ටරයක ක්‍රියා කරයි.',
    color: Color(0xFF0D9488), // Teal
    icon: Icons.tune_rounded,
  );

  final String labelEn;
  final String labelSi;
  final String tooltipEn;
  final String tooltipSi;
  final Color color;
  final IconData icon;

  const ToneAdjustmentSource({
    required this.labelEn,
    required this.labelSi,
    required this.tooltipEn,
    required this.tooltipSi,
    required this.color,
    required this.icon,
  });
}

/// Paper type compensation presets that adjust tones for specific physical paper absorption.
enum PaperCompensationPreset {
  none(
    labelEn: 'None (Standard)',
    labelSi: 'කිසිවක් නැත (සාමාන්‍ය)',
    descEn: 'No media curve compensation applied.',
    descSi: 'කඩදාසි අනුව වෙනස්කම් සිදු නොවේ.',
  ),
  plainPaper(
    labelEn: 'Plain Paper (Compensate Bleed)',
    labelSi: 'සාමාන්‍ය කඩදාසි (තීන්ත උරාගැනීම පාලනය)',
    descEn: 'Lifts midtones (+8) and sharpens text (+15) while reducing overall density (-6) to prevent ink cockling and feathering.',
    descSi: 'සාමාන්‍ය කොළවල තීන්ත බොඳ වීම සහ කොළ රැළි වැටීම වළකා අකුරු තියුණු කරයි.',
  ),
  mattePaper(
    labelEn: 'Matte Paper (Deepen Blacks)',
    labelSi: 'මැට් කඩදාසි (කළු වර්ණ තීව්‍ර කිරීම)',
    descEn: 'Deepens black level (+12), expands highlight range (+5), and sets gamma 1.08 to recover archival richness.',
    descSi: 'මැට් කොළවල කළු වර්ණය හොඳින් මතු කර ලේඛනවල පෙනුම වැඩි දියුණු කරයි.',
  ),
  glossyPhoto(
    labelEn: 'Glossy Photo (Dynamic Range)',
    labelSi: 'ග්ලොසි ෆොටෝ (උසස් වර්ණ පරාසය)',
    descEn: 'Boosts contrast (+10), vibrance (+8), and saturation (+6) to utilize glossy resin coat reflection.',
    descSi: 'ග්ලොසි ෆොටෝ කොළවල දිස්නයට ගැළපෙන පරිදි වර්ණ හා පැහැදිලි බව වැඩි කරයි.',
  );

  final String labelEn;
  final String labelSi;
  final String descEn;
  final String descSi;

  const PaperCompensationPreset({
    required this.labelEn,
    required this.labelSi,
    required this.descEn,
    required this.descSi,
  });
}

/// Ink saver aggressiveness levels with estimated savings percentages.
enum InkSaverLevel {
  light(
    labelEn: 'Light Saver (~15% ink saved - estimate)',
    labelSi: 'සැහැල්ලු ඉතිරිය (~15% තීන්ත ඉතිරි - ඇස්තමේන්තුව)',
    savingsPercent: 15.0,
    densityOffset: -8,
  ),
  balanced(
    labelEn: 'Balanced Saver (~28% ink saved - estimate)',
    labelSi: 'සමබර ඉතිරිය (~28% තීන්ත ඉතිරි - ඇස්තමේන්තුව)',
    savingsPercent: 28.0,
    densityOffset: -18,
  ),
  aggressive(
    labelEn: 'Aggressive Draft (~42% ink saved - estimate)',
    labelSi: 'උපරිම ඉතිරිය (~42% තීන්ත ඉතිරි - ඇස්තමේන්තුව)',
    savingsPercent: 42.0,
    densityOffset: -32,
  );

  final String labelEn;
  final String labelSi;
  final double savingsPercent;
  final int densityOffset;

  const InkSaverLevel({
    required this.labelEn,
    required this.labelSi,
    required this.savingsPercent,
    required this.densityOffset,
  });
}

/// Control point on a per-channel tone curve (input 0-255 -> output 0-255).
class ToneCurvePoint {
  final int input;
  final int output;

  const ToneCurvePoint(this.input, this.output);

  Map<String, dynamic> toMap() => {'x': input, 'y': output};

  factory ToneCurvePoint.fromMap(Map<String, dynamic> map) {
    return ToneCurvePoint(
      (map['x'] as num?)?.toInt() ?? 0,
      (map['y'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Comprehensive Tone and Ink adjustments model.
class ToneAndInkSettings {
  // 1. Overall Density & Exposure
  final int density; // -100 to +100 (Overall ink deposit / lighter-darker)
  final int brightness; // -100 to +100
  final int contrast; // -100 to +100
  final double gamma; // 0.5 to 2.5 (1.0 = linear default)
  final int shadows; // -100 to +100 (shadow recovery / deepening)
  final int highlights; // -100 to +100 (highlight recovery / expansion)

  // 2. Color Balance & Saturation
  final int saturation; // -100 to +100
  final int vibrance; // -100 to +100 (protects skin tones while boosting muted colors)
  final int colorBalanceCyanRed; // -100 (Cyan) to +100 (Red)
  final int colorBalanceMagentaGreen; // -100 (Green) to +100 (Magenta)
  final int colorBalanceYellowBlue; // -100 (Yellow) to +100 (Blue)

  // 3. Black Level, Text Darkness & Sharpening
  final int blackLevel; // -100 to +100 (Sets deep black cutoff threshold)
  final int textDarkness; // -100 to +100 (Text thresholding: darker for crispness or lighter to save toner)
  final int textSharpening; // 0 to 100 (Edge unsharp mask on fonts/linework)
  final int photoSharpening; // 0 to 100 (Luminance detail sharpening)

  // 4. Ink / Toner Saver Mode
  final bool inkSaverEnabled;
  final InkSaverLevel inkSaverLevel;
  final bool inkSaverTextOnlyBlack; // Force colored text to 100% K black ink
  final bool lightenFillsOnly; // Lightens background tints while keeping text punchy

  // 5. Paper-Type Compensation Preset
  final PaperCompensationPreset paperCompensation;

  // 6. Double-Adjustment Prevention Flags
  final bool driverColorAdjustmentActive; // Reported by driver or capability layer
  final bool appToneAdjustmentActive; // Whether App-controlled adjustments are applied

  // 7. Preview & Pro Curves
  final bool compareWithOriginal; // Split before/after view
  final List<ToneCurvePoint> masterCurve;
  final List<ToneCurvePoint> redCyanCurve;
  final List<ToneCurvePoint> greenMagentaCurve;
  final List<ToneCurvePoint> blueYellowCurve;

  const ToneAndInkSettings({
    this.density = 0,
    this.brightness = 0,
    this.contrast = 0,
    this.gamma = 1.0,
    this.shadows = 0,
    this.highlights = 0,
    this.saturation = 0,
    this.vibrance = 0,
    this.colorBalanceCyanRed = 0,
    this.colorBalanceMagentaGreen = 0,
    this.colorBalanceYellowBlue = 0,
    this.blackLevel = 0,
    this.textDarkness = 0,
    this.textSharpening = 0,
    this.photoSharpening = 0,
    this.inkSaverEnabled = false,
    this.inkSaverLevel = InkSaverLevel.balanced,
    this.inkSaverTextOnlyBlack = false,
    this.lightenFillsOnly = true,
    this.paperCompensation = PaperCompensationPreset.none,
    this.driverColorAdjustmentActive = false,
    this.appToneAdjustmentActive = true,
    this.compareWithOriginal = false,
    this.masterCurve = const [ToneCurvePoint(0, 0), ToneCurvePoint(255, 255)],
    this.redCyanCurve = const [ToneCurvePoint(0, 0), ToneCurvePoint(255, 255)],
    this.greenMagentaCurve = const [ToneCurvePoint(0, 0), ToneCurvePoint(255, 255)],
    this.blueYellowCurve = const [ToneCurvePoint(0, 0), ToneCurvePoint(255, 255)],
  });

  /// True if any custom adjustment has been applied.
  bool get hasActiveAdjustments {
    return density != 0 ||
        brightness != 0 ||
        contrast != 0 ||
        (gamma - 1.0).abs() > 0.01 ||
        shadows != 0 ||
        highlights != 0 ||
        saturation != 0 ||
        vibrance != 0 ||
        colorBalanceCyanRed != 0 ||
        colorBalanceMagentaGreen != 0 ||
        colorBalanceYellowBlue != 0 ||
        blackLevel != 0 ||
        textDarkness != 0 ||
        textSharpening > 0 ||
        photoSharpening > 0 ||
        inkSaverEnabled ||
        paperCompensation != PaperCompensationPreset.none;
  }

  /// Detects potential double color management.
  bool get isDoubleAdjustmentWarning {
    return driverColorAdjustmentActive && appToneAdjustmentActive && hasActiveAdjustments;
  }

  /// Calculates estimated ink savings percentage.
  double get estimatedSavingsPercent {
    if (!inkSaverEnabled) return 0.0;
    double base = inkSaverLevel.savingsPercent;
    if (inkSaverTextOnlyBlack) base += 5.0;
    if (density < 0) base += (density.abs() * 0.15);
    return math.min(65.0, base);
  }

  /// Creates a copy with a selected paper compensation preset applied.
  ToneAndInkSettings applyPaperCompensation(PaperCompensationPreset preset) {
    switch (preset) {
      case PaperCompensationPreset.plainPaper:
        return copyWith(
          paperCompensation: preset,
          shadows: 8,
          highlights: -4,
          density: -6,
          textDarkness: 12,
          textSharpening: 15,
        );
      case PaperCompensationPreset.mattePaper:
        return copyWith(
          paperCompensation: preset,
          blackLevel: 12,
          highlights: 5,
          gamma: 1.08,
          contrast: 4,
          photoSharpening: 10,
        );
      case PaperCompensationPreset.glossyPhoto:
        return copyWith(
          paperCompensation: preset,
          contrast: 10,
          vibrance: 8,
          saturation: 6,
          blackLevel: 4,
          photoSharpening: 16,
        );
      case PaperCompensationPreset.none:
        return copyWith(
          paperCompensation: preset,
          shadows: 0,
          highlights: 0,
          density: 0,
          textDarkness: 0,
          blackLevel: 0,
          gamma: 1.0,
          contrast: 0,
          vibrance: 0,
          saturation: 0,
          textSharpening: 0,
          photoSharpening: 0,
        );
    }
  }

  ToneAndInkSettings resetToDefault() {
    return const ToneAndInkSettings();
  }

  ToneAndInkSettings copyWith({
    int? density,
    int? brightness,
    int? contrast,
    double? gamma,
    int? shadows,
    int? highlights,
    int? saturation,
    int? vibrance,
    int? colorBalanceCyanRed,
    int? colorBalanceMagentaGreen,
    int? colorBalanceYellowBlue,
    int? blackLevel,
    int? textDarkness,
    int? textSharpening,
    int? photoSharpening,
    bool? inkSaverEnabled,
    InkSaverLevel? inkSaverLevel,
    bool? inkSaverTextOnlyBlack,
    bool? lightenFillsOnly,
    PaperCompensationPreset? paperCompensation,
    bool? driverColorAdjustmentActive,
    bool? appToneAdjustmentActive,
    bool? compareWithOriginal,
    List<ToneCurvePoint>? masterCurve,
    List<ToneCurvePoint>? redCyanCurve,
    List<ToneCurvePoint>? greenMagentaCurve,
    List<ToneCurvePoint>? blueYellowCurve,
  }) {
    return ToneAndInkSettings(
      density: density ?? this.density,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      gamma: gamma ?? this.gamma,
      shadows: shadows ?? this.shadows,
      highlights: highlights ?? this.highlights,
      saturation: saturation ?? this.saturation,
      vibrance: vibrance ?? this.vibrance,
      colorBalanceCyanRed: colorBalanceCyanRed ?? this.colorBalanceCyanRed,
      colorBalanceMagentaGreen: colorBalanceMagentaGreen ?? this.colorBalanceMagentaGreen,
      colorBalanceYellowBlue: colorBalanceYellowBlue ?? this.colorBalanceYellowBlue,
      blackLevel: blackLevel ?? this.blackLevel,
      textDarkness: textDarkness ?? this.textDarkness,
      textSharpening: textSharpening ?? this.textSharpening,
      photoSharpening: photoSharpening ?? this.photoSharpening,
      inkSaverEnabled: inkSaverEnabled ?? this.inkSaverEnabled,
      inkSaverLevel: inkSaverLevel ?? this.inkSaverLevel,
      inkSaverTextOnlyBlack: inkSaverTextOnlyBlack ?? this.inkSaverTextOnlyBlack,
      lightenFillsOnly: lightenFillsOnly ?? this.lightenFillsOnly,
      paperCompensation: paperCompensation ?? this.paperCompensation,
      driverColorAdjustmentActive: driverColorAdjustmentActive ?? this.driverColorAdjustmentActive,
      appToneAdjustmentActive: appToneAdjustmentActive ?? this.appToneAdjustmentActive,
      compareWithOriginal: compareWithOriginal ?? this.compareWithOriginal,
      masterCurve: masterCurve ?? this.masterCurve,
      redCyanCurve: redCyanCurve ?? this.redCyanCurve,
      greenMagentaCurve: greenMagentaCurve ?? this.greenMagentaCurve,
      blueYellowCurve: blueYellowCurve ?? this.blueYellowCurve,
    );
  }

  Map<String, dynamic> toMap() => {
        'density': density,
        'brightness': brightness,
        'contrast': contrast,
        'gamma': gamma,
        'shadows': shadows,
        'highlights': highlights,
        'saturation': saturation,
        'vibrance': vibrance,
        'colorBalanceCyanRed': colorBalanceCyanRed,
        'colorBalanceMagentaGreen': colorBalanceMagentaGreen,
        'colorBalanceYellowBlue': colorBalanceYellowBlue,
        'blackLevel': blackLevel,
        'textDarkness': textDarkness,
        'textSharpening': textSharpening,
        'photoSharpening': photoSharpening,
        'inkSaverEnabled': inkSaverEnabled,
        'inkSaverLevel': inkSaverLevel.name,
        'inkSaverTextOnlyBlack': inkSaverTextOnlyBlack,
        'lightenFillsOnly': lightenFillsOnly,
        'paperCompensation': paperCompensation.name,
        'driverColorAdjustmentActive': driverColorAdjustmentActive,
        'appToneAdjustmentActive': appToneAdjustmentActive,
        'compareWithOriginal': compareWithOriginal,
        'masterCurve': masterCurve.map((p) => p.toMap()).toList(),
        'redCyanCurve': redCyanCurve.map((p) => p.toMap()).toList(),
        'greenMagentaCurve': greenMagentaCurve.map((p) => p.toMap()).toList(),
        'blueYellowCurve': blueYellowCurve.map((p) => p.toMap()).toList(),
      };

  factory ToneAndInkSettings.fromMap(Map<String, dynamic> map) {
    return ToneAndInkSettings(
      density: (map['density'] as num?)?.toInt() ?? 0,
      brightness: (map['brightness'] as num?)?.toInt() ?? 0,
      contrast: (map['contrast'] as num?)?.toInt() ?? 0,
      gamma: (map['gamma'] as num?)?.toDouble() ?? 1.0,
      shadows: (map['shadows'] as num?)?.toInt() ?? 0,
      highlights: (map['highlights'] as num?)?.toInt() ?? 0,
      saturation: (map['saturation'] as num?)?.toInt() ?? 0,
      vibrance: (map['vibrance'] as num?)?.toInt() ?? 0,
      colorBalanceCyanRed: (map['colorBalanceCyanRed'] as num?)?.toInt() ?? 0,
      colorBalanceMagentaGreen: (map['colorBalanceMagentaGreen'] as num?)?.toInt() ?? 0,
      colorBalanceYellowBlue: (map['colorBalanceYellowBlue'] as num?)?.toInt() ?? 0,
      blackLevel: (map['blackLevel'] as num?)?.toInt() ?? 0,
      textDarkness: (map['textDarkness'] as num?)?.toInt() ?? 0,
      textSharpening: (map['textSharpening'] as num?)?.toInt() ?? 0,
      photoSharpening: (map['photoSharpening'] as num?)?.toInt() ?? 0,
      inkSaverEnabled: map['inkSaverEnabled'] as bool? ?? false,
      inkSaverLevel: InkSaverLevel.values.firstWhere(
        (e) => e.name == map['inkSaverLevel'],
        orElse: () => InkSaverLevel.balanced,
      ),
      inkSaverTextOnlyBlack: map['inkSaverTextOnlyBlack'] as bool? ?? false,
      lightenFillsOnly: map['lightenFillsOnly'] as bool? ?? true,
      paperCompensation: PaperCompensationPreset.values.firstWhere(
        (e) => e.name == map['paperCompensation'],
        orElse: () => PaperCompensationPreset.none,
      ),
      driverColorAdjustmentActive: map['driverColorAdjustmentActive'] as bool? ?? false,
      appToneAdjustmentActive: map['appToneAdjustmentActive'] as bool? ?? true,
      compareWithOriginal: map['compareWithOriginal'] as bool? ?? false,
      masterCurve: (map['masterCurve'] as List<dynamic>?)
              ?.map((p) => ToneCurvePoint.fromMap(p as Map<String, dynamic>))
              .toList() ??
          const [ToneCurvePoint(0, 0), ToneCurvePoint(255, 255)],
      redCyanCurve: (map['redCyanCurve'] as List<dynamic>?)
              ?.map((p) => ToneCurvePoint.fromMap(p as Map<String, dynamic>))
              .toList() ??
          const [ToneCurvePoint(0, 0), ToneCurvePoint(255, 255)],
      greenMagentaCurve: (map['greenMagentaCurve'] as List<dynamic>?)
              ?.map((p) => ToneCurvePoint.fromMap(p as Map<String, dynamic>))
              .toList() ??
          const [ToneCurvePoint(0, 0), ToneCurvePoint(255, 255)],
      blueYellowCurve: (map['blueYellowCurve'] as List<dynamic>?)
              ?.map((p) => ToneCurvePoint.fromMap(p as Map<String, dynamic>))
              .toList() ??
          const [ToneCurvePoint(0, 0), ToneCurvePoint(255, 255)],
    );
  }
}

/// CMYK ink coverage evaluation per channel.
class CmykInkCoverage {
  final double cyanPercent;
  final double magentaPercent;
  final double yellowPercent;
  final double blackPercent;

  const CmykInkCoverage({
    required this.cyanPercent,
    required this.magentaPercent,
    required this.yellowPercent,
    required this.blackPercent,
  });

  double get totalCoveragePercent => cyanPercent + magentaPercent + yellowPercent + blackPercent;

  /// Qualitative coverage tier.
  String get coverageTierEn {
    if (totalCoveragePercent < 15.0) return 'Light / Text Only (< 15%)';
    if (totalCoveragePercent < 35.0) return 'Standard Office (15 - 35%)';
    if (totalCoveragePercent < 60.0) return 'High / Rich Graphics (36 - 60%)';
    return 'Heavy / Full Bleed Photo (> 60%)';
  }

  String get coverageTierSi {
    if (totalCoveragePercent < 15.0) return 'අවම / පෙළ පමණක් (< 15%)';
    if (totalCoveragePercent < 35.0) return 'සාමාන්‍ය කාර්යාලීය (15 - 35%)';
    if (totalCoveragePercent < 60.0) return 'වැඩි / ප්‍රස්ථාර සහිත (36 - 60%)';
    return 'අධික / සම්පූර්ණ ඡායාරූප (> 60%)';
  }

  Map<String, dynamic> toMap() => {
        'cyanPercent': cyanPercent,
        'magentaPercent': magentaPercent,
        'yellowPercent': yellowPercent,
        'blackPercent': blackPercent,
        'totalCoveragePercent': totalCoveragePercent,
      };
}

/// Comprehensive Ink Coverage Report feeding the Price Calculator & Cost Tracking.
class InkCoverageReport {
  final int pageCount;
  final CmykInkCoverage averageCoverage;
  final double estimatedTotalMl;
  final double estimatedCostLkr;
  final double estimatedSavingsPercent;
  final double estimatedSavedLkr;

  const InkCoverageReport({
    required this.pageCount,
    required this.averageCoverage,
    required this.estimatedTotalMl,
    required this.estimatedCostLkr,
    required this.estimatedSavingsPercent,
    required this.estimatedSavedLkr,
  });

  static InkCoverageReport calculate({
    required int pageCount,
    required CmykInkCoverage coverage,
    required double baseCostPerPage,
    double savingsPercent = 0.0,
  }) {
    // Baseline: standard ISO 5% coverage uses approx ~0.045 ml of ink per A4 sheet
    final coverageRatio = coverage.totalCoveragePercent / 5.0;
    final mlPerPage = 0.045 * (coverageRatio > 0 ? coverageRatio : 1.0);
    final totalMlRaw = mlPerPage * pageCount;
    final totalMl = savingsPercent > 0 ? totalMlRaw * (1.0 - (savingsPercent / 100.0)) : totalMlRaw;

    final baseJobCost = pageCount * baseCostPerPage * (coverageRatio.clamp(0.4, 3.5));
    final savedLkr = savingsPercent > 0 ? baseJobCost * (savingsPercent / 100.0) : 0.0;
    final finalCost = baseJobCost - savedLkr;

    return InkCoverageReport(
      pageCount: pageCount,
      averageCoverage: coverage,
      estimatedTotalMl: totalMl,
      estimatedCostLkr: finalCost,
      estimatedSavingsPercent: savingsPercent,
      estimatedSavedLkr: savedLkr,
    );
  }
}

/// Analyzer that converts RGB pixel samples to CMYK coverage percentages.
class InkCoverageAnalyzer {
  /// Converts an array of RGB/RGBA pixels to CMYK channel coverage percentages.
  static CmykInkCoverage analyzeRgbBuffer(List<int> bytes, {bool hasAlpha = false}) {
    if (bytes.isEmpty) {
      return const CmykInkCoverage(cyanPercent: 0, magentaPercent: 0, yellowPercent: 0, blackPercent: 0);
    }

    final step = hasAlpha ? 4 : 3;
    final pixelCount = bytes.length ~/ step;
    if (pixelCount == 0) {
      return const CmykInkCoverage(cyanPercent: 0, magentaPercent: 0, yellowPercent: 0, blackPercent: 0);
    }

    double sumC = 0.0;
    double sumM = 0.0;
    double sumY = 0.0;
    double sumK = 0.0;

    for (int i = 0; i < bytes.length; i += step) {
      final r = bytes[i] / 255.0;
      final g = bytes[i + 1] / 255.0;
      final b = bytes[i + 2] / 255.0;

      // RGB to CMYK Conversion
      final k = 1.0 - math.max(r, math.max(g, b));
      if (k >= 0.999) {
        // Pure black
        sumK += 1.0;
      } else {
        final c = (1.0 - r - k) / (1.0 - k);
        final m = (1.0 - g - k) / (1.0 - k);
        final y = (1.0 - b - k) / (1.0 - k);

        sumC += c;
        sumM += m;
        sumY += y;
        sumK += k;
      }
    }

    return CmykInkCoverage(
      cyanPercent: (sumC / pixelCount) * 100.0,
      magentaPercent: (sumM / pixelCount) * 100.0,
      yellowPercent: (sumY / pixelCount) * 100.0,
      blackPercent: (sumK / pixelCount) * 100.0,
    );
  }
}

/// Test pattern document generator metadata.
/// Renders gray ramps, color patches, and nozzle check visual alignment patterns
/// via NORMAL spooler document printing (Never sends raw device control commands!).
class TestPatternGenerator {
  static const String advisoryNoticeEn =
      'Print Helper prints this test pattern as a normal document. '
      'If you notice missing lines or gaps in the nozzle pattern, please run head cleaning '
      'from the printer LCD menu or the Epson driver Maintenance tab. '
      'Print Helper never sends unverified raw maintenance commands.';

  static const String advisoryNoticeSi =
      'Print Helper මෙම පරීක්ෂණ රටාව සාමාන්‍ය ලේඛනයක් ලෙස මුද්‍රණය කරයි. '
      'නොසල් රටාවේ රේඛා කැඩී ඇත්නම්, කරුණාකර ප්‍රින්ටරයේ මෙනුවෙන් හෝ Epson ඩ්‍රයිවර් Maintenance '
      'ටැබයෙන් Head Cleaning ක්‍රියාත්මක කරන්න. Print Helper විසින් කිසිවිටෙක අනුමත නොකළ raw විධාන නොයවයි.';
}
