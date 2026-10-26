import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../services/printer/capability_discovery_service.dart';
import '../../../services/printer/models/printer_intelligence_models.dart';
import 'print_queue_item.dart';
import 'resolution_system_models.dart';
import 'tone_and_ink_models.dart';

/// The 3 user-selectable print settings tiers.
enum PrintSettingsTier {
  basic(
    nameEn: 'Basic',
    nameSi: 'මූලික (Basic)',
    descEn: 'The essentials everyone needs: copies, color, duplex, paper size.',
    descSi: 'හැමෝටම අවශ්‍ය මූලික සැකසුම්: පිටපත්, පාට, දෙපැත්ත, කොළ ප්‍රමාණය.',
  ),
  standard(
    nameEn: 'Standard',
    nameSi: 'සාමාන්‍ය (Standard)',
    descEn: 'Everyday office printing: quality, tray, margins, N-up, watermarks.',
    descSi: 'කාර්යාලීය මුද්‍රණ සැකසුම්: ගුණාත්මකභාවය, තැටිය, මායිම්, පිටු කිහිපයක් එක කොළයකට.',
  ),
  professional(
    nameEn: 'Professional',
    nameSi: 'වෘත්තීය (Professional)',
    descEn: 'Color management, ICC, imposition, passport photos, CD/DVD, stamps, presets.',
    descSi: 'වෘත්තීය මට්ටමේ වර්ණ පාලනය, ICC, හැඳුනුම්පත් ඡායාරූප, CD/DVD, මුද්‍රා සහ පෙරසැකසුම්.',
  );

  final String nameEn;
  final String nameSi;
  final String descEn;
  final String descSi;

  const PrintSettingsTier({
    required this.nameEn,
    required this.nameSi,
    required this.descEn,
    required this.descSi,
  });
}

/// Professional Color Management mode.
enum ProColorManagementMode {
  appManaged,
  driverManaged,
  off,
}

/// ICC Rendering Intent.
enum IccRenderingIntent {
  perceptual,
  relativeColorimetric,
  saturation,
  absoluteColorimetric,
}

/// Advanced B&W Toning.
enum AdvancedBwTone {
  neutral,
  cool,
  warm,
  sepia,
}

/// Halftone screening method.
enum HalftoneScreening {
  standard,
  fineDither,
  diffusion,
}

/// Professional imposition / sheet arrangement.
enum ProImpositionMode {
  standard,
  nup,
  bookletSaddleStitch,
  stepAndRepeat,
  gangRun,
  posterTiling,
  banner,
}

/// Passport / ID photo layout presets.
enum PassportIdPreset {
  passport35x45, // Sri Lanka / UK / EU standard passport (35x45 mm)
  visa2x2, // US Visa / Square (2x2 inches / 51x51 mm)
  id30x40, // Standard ID Card Photo (30x40 mm)
  custom,
}

/// Roll Paper Auto-cut behavior.
enum RollAutoCutMode {
  normalCut,
  keepCut,
  banner,
}

/// Print Job Priority.
enum PrintJobPriority {
  normal,
  high,
  urgent,
}

/// Overlay Stamp Presets.
enum OverlayStampPreset {
  none,
  copy,
  paid,
  draft,
  confidential,
  sinhalaCopy, // පිටපත
  sinhalaPaid, // ගෙවන ලදී
  sinhalaDraft, // කෙටුම්පත
  custom,
}

/// Comprehensive, three-tier unified print settings.
class UnifiedPrintSettings {
  final PrintSettingsTier tier;

  // --- BASIC TIER ---
  final String printerName;
  final int copies;
  final String pageRange;
  final bool isColor;
  final DuplexMode duplex;
  final String paperSize;
  final PageOrientation orientation;
  final bool fitToPage;

  // --- STANDARD TIER ---
  final String mediaType;
  final PrintQualityMode quality;
  final bool collate;
  final bool reverseOrder;
  final PageSubset pageSubset;
  final String paperTray;
  final MarginPreset marginPreset;
  final double customMarginMm;
  final double customScalePercent;
  final int pagesPerSheet;
  final bool booklet;
  final bool isBorderless;
  final String watermarkText;
  final double watermarkOpacity;
  final String headerText;
  final String footerText;
  final bool showPageNumbers;
  final bool blackInkOnly;
  final bool inkSavingMode;
  final bool testPrintFirstPageOnly;

  // --- PROFESSIONAL TIER ---
  // 1. Color Management
  final ProColorManagementMode colorMode;
  final String iccProfile;
  final IccRenderingIntent renderingIntent;
  final bool blackPointCompensation;
  final bool softProofingEnabled;

  // 2. Advanced B&W
  final bool advancedBwEnabled;
  final AdvancedBwTone advancedBwTone;

  // 3. Resolution & Quality (PPI vs DPI)
  final int customDpi;
  final int hardwareDpi; // Driver DPI setting (e.g., 300, 600, 1200, 2400, 5760 dpi)
  final RenderDpiChoice renderDpi; // Rasterization DPI (Auto, 150, 300, 600, 1200)
  final ResamplingAlgorithm resampleFilter; // None, Bicubic, Lanczos
  final bool isUpscaledForPrint;
  final double upscaleMultiplier; // 1.0x, 2.0x, 4.0x
  final bool keepVectorGraphics; // Keep vector text/paths as vector wherever driver allows
  final double? currentEffectivePpi; // Computed effective PPI at printed size
  final List<ResamplingLogRecord> resamplingHistory;
  final HalftoneScreening halftoneScreening;
  final bool biDirectionalPrinting;

  // 4. Tone & Ink
  final ToneAndInkSettings toneAndInk;
  final int inkDensityPercent; // -50 to +50
  final String blackGeneration; // 'auto', 'minimum', 'medium', 'maximum'
  final bool glossOptimizer;
  final String blackTankSelection; // 'photoBlack', 'matteBlack'

  // 5. Layout & Imposition
  final ProImpositionMode impositionMode;
  final double nupGapMm;
  final double posterOverlapMm;
  final int posterTilesX;
  final int posterTilesY;
  final bool mirrorHorizontal;
  final bool flipVertical;
  final int rotateAngleDegrees;
  final double gutterBindingMarginMm;
  final double bleedMm;
  final bool cropMarks;
  final bool registrationMarks;
  final bool colorBars;
  final String slugText;

  // 6. Photo & ID Layouts
  final bool photoIdLayoutEnabled;
  final PassportIdPreset photoIdPreset;
  final double photoWidthMm;
  final double photoHeightMm;
  final double photoSpacingMm;
  final int photosCount;
  final int borderlessExpansionBleedStep; // 0=min, 1=mid, 2=max, 3=full
  final bool showDateNameLabel;
  final String photoLabelText;

  // 7. Special Media & Hardware Controls
  final bool rollPaperEnabled;
  final RollAutoCutMode rollAutoCut;
  final bool cdDvdPrintEnabled;
  final double cdInnerDiameterMm;
  final double cdOuterDiameterMm;
  final double customPaperWidthMm;
  final double customPaperLengthMm;

  // 8. Job Controls
  final PrintJobPriority jobPriority;
  final bool printToPdfFirst;
  final String jobTicketNotes;

  // 9. Overlays & Stamps
  final String? letterheadPdfPath;
  final OverlayStampPreset stampPreset;
  final String customStampText;
  final double stampOpacity;

  // 10. Presets & Shop Mode
  final String? activePresetName;
  final bool isStaffLocked;
  final String? staffLockPin;

  const UnifiedPrintSettings({
    this.tier = PrintSettingsTier.basic,
    this.printerName = '',
    this.copies = 1,
    this.pageRange = '',
    this.isColor = true,
    this.duplex = DuplexMode.none,
    this.paperSize = 'A4',
    this.orientation = PageOrientation.portrait,
    this.fitToPage = true,
    this.mediaType = 'Plain Paper',
    this.quality = PrintQualityMode.normal,
    this.collate = true,
    this.reverseOrder = false,
    this.pageSubset = PageSubset.all,
    this.paperTray = 'Auto Select',
    this.marginPreset = MarginPreset.normal,
    this.customMarginMm = 12.7,
    this.customScalePercent = 100.0,
    this.pagesPerSheet = 1,
    this.booklet = false,
    this.isBorderless = false,
    this.watermarkText = '',
    this.watermarkOpacity = 0.18,
    this.headerText = '',
    this.footerText = '',
    this.showPageNumbers = false,
    this.blackInkOnly = false,
    this.inkSavingMode = false,
    this.testPrintFirstPageOnly = false,
    this.colorMode = ProColorManagementMode.driverManaged,
    this.iccProfile = 'Driver Managed (Recommended)',
    this.renderingIntent = IccRenderingIntent.perceptual,
    this.blackPointCompensation = true,
    this.softProofingEnabled = false,
    this.advancedBwEnabled = false,
    this.advancedBwTone = AdvancedBwTone.neutral,
    this.customDpi = 600,
    this.hardwareDpi = 600,
    this.renderDpi = RenderDpiChoice.auto,
    this.resampleFilter = ResamplingAlgorithm.bicubic,
    this.isUpscaledForPrint = false,
    this.upscaleMultiplier = 1.0,
    this.keepVectorGraphics = true,
    this.currentEffectivePpi,
    this.resamplingHistory = const [],
    this.halftoneScreening = HalftoneScreening.standard,
    this.biDirectionalPrinting = true,
    this.toneAndInk = const ToneAndInkSettings(),
    this.inkDensityPercent = 0,
    this.blackGeneration = 'auto',
    this.glossOptimizer = false,
    this.blackTankSelection = 'photoBlack',
    this.impositionMode = ProImpositionMode.standard,
    this.nupGapMm = 4.0,
    this.posterOverlapMm = 15.0,
    this.posterTilesX = 2,
    this.posterTilesY = 2,
    this.mirrorHorizontal = false,
    this.flipVertical = false,
    this.rotateAngleDegrees = 0,
    this.gutterBindingMarginMm = 0.0,
    this.bleedMm = 3.0,
    this.cropMarks = false,
    this.registrationMarks = false,
    this.colorBars = false,
    this.slugText = '',
    this.photoIdLayoutEnabled = false,
    this.photoIdPreset = PassportIdPreset.passport35x45,
    this.photoWidthMm = 35.0,
    this.photoHeightMm = 45.0,
    this.photoSpacingMm = 3.0,
    this.photosCount = 8,
    this.borderlessExpansionBleedStep = 2,
    this.showDateNameLabel = false,
    this.photoLabelText = '',
    this.rollPaperEnabled = false,
    this.rollAutoCut = RollAutoCutMode.normalCut,
    this.cdDvdPrintEnabled = false,
    this.cdInnerDiameterMm = 18.0,
    this.cdOuterDiameterMm = 120.0,
    this.customPaperWidthMm = 210.0,
    this.customPaperLengthMm = 297.0,
    this.jobPriority = PrintJobPriority.normal,
    this.printToPdfFirst = false,
    this.jobTicketNotes = '',
    this.letterheadPdfPath,
    this.stampPreset = OverlayStampPreset.none,
    this.customStampText = '',
    this.stampOpacity = 0.4,
    this.activePresetName,
    this.isStaffLocked = false,
    this.staffLockPin,
  });

  /// Generates the plain-language summary in English.
  String generateSummaryEn() {
    final parts = <String>[];
    parts.add(paperSize);
    parts.add(mediaType);
    parts.add(isColor ? 'Color' : 'Black & White');
    parts.add(duplex == DuplexMode.none
        ? 'Single-sided'
        : (duplex == DuplexMode.longEdge ? 'Double-sided (long edge)' : 'Double-sided (short edge)'));
    parts.add(copies == 1 ? '1 copy' : '$copies copies');

    if (tier != PrintSettingsTier.basic) {
      if (isBorderless) parts.add('Borderless');
      if (quality != PrintQualityMode.normal) {
        parts.add(quality == PrintQualityMode.draft ? 'Draft' : 'High quality');
      }
      if (pagesPerSheet > 1) parts.add('$pagesPerSheet-up');
    }

    if (tier == PrintSettingsTier.professional) {
      parts.add('$hardwareDpi DPI');
      if (currentEffectivePpi != null) parts.add('${currentEffectivePpi!.round()} PPI');
      if (isUpscaledForPrint) parts.add('Upscaled ${upscaleMultiplier.toStringAsFixed(1)}x');
      if (advancedBwEnabled) parts.add('Advanced B&W (${advancedBwTone.name})');
      if (photoIdLayoutEnabled) parts.add('Passport Photo Sheet ($photosCount photos)');
      if (cdDvdPrintEnabled) parts.add('Direct CD/DVD Print');
      if (stampPreset != OverlayStampPreset.none) parts.add('Stamp overlay');
      if (toneAndInk.inkSaverEnabled) {
        parts.add('Ink Saver (~${toneAndInk.estimatedSavingsPercent.round()}% saved)');
      }
      if (toneAndInk.paperCompensation != PaperCompensationPreset.none) {
        parts.add(toneAndInk.paperCompensation.labelEn.split(' ')[0]);
      }
    }

    return parts.join(', ');
  }

  /// Generates the plain-language summary in Spoken Sinhala.
  String generateSummarySi() {
    final parts = <String>[];
    parts.add(paperSize);

    // Sinhala paper type
    final mediaSi = _mediaTypeToSinhala(mediaType);
    parts.add(mediaSi);

    // Color
    parts.add(isColor ? 'පාටින්' : 'කළු සුදු');

    // Duplex
    parts.add(duplex == DuplexMode.none ? 'තනි පැත්ත' : 'දෙපැත්තෙන්ම');

    // Copies
    parts.add('කොපි $copies');

    if (tier != PrintSettingsTier.basic) {
      if (isBorderless) parts.add('දාර රහිත (Borderless)');
      if (quality != PrintQualityMode.normal) {
        parts.add(quality == PrintQualityMode.draft ? 'ඉක්මන් (Draft)' : 'උසස් ගුණාත්මක');
      }
      if (pagesPerSheet > 1) parts.add('කොළයකට පිටු $pagesPerSheet');
    }

    if (tier == PrintSettingsTier.professional) {
      parts.add('$hardwareDpi DPI');
      if (currentEffectivePpi != null) parts.add('${currentEffectivePpi!.round()} PPI');
      if (isUpscaledForPrint) parts.add('විශාල කළ (${upscaleMultiplier.toStringAsFixed(1)}x)');
      if (advancedBwEnabled) parts.add('විශේෂ කළු-සුදු (${_bwToneToSinhala(advancedBwTone)})');
      if (photoIdLayoutEnabled) parts.add('පාස්පෝට් ෆොටෝ ($photosCount ක්)');
      if (cdDvdPrintEnabled) parts.add('CD/DVD තැටි මුද්‍රණය');
      if (stampPreset != OverlayStampPreset.none) parts.add('මුද්‍රා තැබීම');
      if (toneAndInk.inkSaverEnabled) {
        parts.add('තීන්ත ඉතිරිය (~${toneAndInk.estimatedSavingsPercent.round()}%)');
      }
      if (toneAndInk.paperCompensation != PaperCompensationPreset.none) {
        parts.add(toneAndInk.paperCompensation.labelSi.split(' ')[0]);
      }
    }

    return parts.join(', ');
  }

  static String _mediaTypeToSinhala(String media) {
    if (media.contains('Plain')) return 'සාමාන්‍ය කඩදාසි';
    if (media.contains('Glossy') || media.contains('Photo')) return 'ග්ලොසි ෆොටෝ කොළ';
    if (media.contains('Matte')) return 'මැට් කඩදාසි';
    if (media.contains('Envelope')) return 'ලියුම් කවර';
    if (media.contains('Card') || media.contains('Thick')) return 'ඝන කාඩ්බෝඩ්';
    return media;
  }

  static String _bwToneToSinhala(AdvancedBwTone tone) {
    switch (tone) {
      case AdvancedBwTone.neutral:
        return 'සාමාන්‍ය කළු-සුදු';
      case AdvancedBwTone.cool:
        return 'නිල් පැහැති කළු-සුදු';
      case AdvancedBwTone.warm:
        return 'උණුසුම් කළු-සුදු';
      case AdvancedBwTone.sepia:
        return 'සෙපියා (දුඹුරු)';
    }
  }

  UnifiedPrintSettings copyWith({
    PrintSettingsTier? tier,
    String? printerName,
    int? copies,
    String? pageRange,
    bool? isColor,
    DuplexMode? duplex,
    String? paperSize,
    PageOrientation? orientation,
    bool? fitToPage,
    String? mediaType,
    PrintQualityMode? quality,
    bool? collate,
    bool? reverseOrder,
    PageSubset? pageSubset,
    String? paperTray,
    MarginPreset? marginPreset,
    double? customMarginMm,
    double? customScalePercent,
    int? pagesPerSheet,
    bool? booklet,
    bool? isBorderless,
    String? watermarkText,
    double? watermarkOpacity,
    String? headerText,
    String? footerText,
    bool? showPageNumbers,
    bool? blackInkOnly,
    bool? inkSavingMode,
    bool? testPrintFirstPageOnly,
    ProColorManagementMode? colorMode,
    String? iccProfile,
    IccRenderingIntent? renderingIntent,
    bool? blackPointCompensation,
    bool? softProofingEnabled,
    bool? advancedBwEnabled,
    AdvancedBwTone? advancedBwTone,
    int? customDpi,
    int? hardwareDpi,
    RenderDpiChoice? renderDpi,
    ResamplingAlgorithm? resampleFilter,
    bool? isUpscaledForPrint,
    double? upscaleMultiplier,
    bool? keepVectorGraphics,
    double? currentEffectivePpi,
    List<ResamplingLogRecord>? resamplingHistory,
    HalftoneScreening? halftoneScreening,
    bool? biDirectionalPrinting,
    ToneAndInkSettings? toneAndInk,
    int? inkDensityPercent,
    String? blackGeneration,
    bool? glossOptimizer,
    String? blackTankSelection,
    ProImpositionMode? impositionMode,
    double? nupGapMm,
    double? posterOverlapMm,
    int? posterTilesX,
    int? posterTilesY,
    bool? mirrorHorizontal,
    bool? flipVertical,
    int? rotateAngleDegrees,
    double? gutterBindingMarginMm,
    double? bleedMm,
    bool? cropMarks,
    bool? registrationMarks,
    bool? colorBars,
    String? slugText,
    bool? photoIdLayoutEnabled,
    PassportIdPreset? photoIdPreset,
    double? photoWidthMm,
    double? photoHeightMm,
    double? photoSpacingMm,
    int? photosCount,
    int? borderlessExpansionBleedStep,
    bool? showDateNameLabel,
    String? photoLabelText,
    bool? rollPaperEnabled,
    RollAutoCutMode? rollAutoCut,
    bool? cdDvdPrintEnabled,
    double? cdInnerDiameterMm,
    double? cdOuterDiameterMm,
    double? customPaperWidthMm,
    double? customPaperLengthMm,
    PrintJobPriority? jobPriority,
    bool? printToPdfFirst,
    String? jobTicketNotes,
    String? letterheadPdfPath,
    OverlayStampPreset? stampPreset,
    String? customStampText,
    double? stampOpacity,
    String? activePresetName,
    bool? isStaffLocked,
    String? staffLockPin,
  }) {
    return UnifiedPrintSettings(
      tier: tier ?? this.tier,
      printerName: printerName ?? this.printerName,
      copies: copies ?? this.copies,
      pageRange: pageRange ?? this.pageRange,
      isColor: isColor ?? this.isColor,
      duplex: duplex ?? this.duplex,
      paperSize: paperSize ?? this.paperSize,
      orientation: orientation ?? this.orientation,
      fitToPage: fitToPage ?? this.fitToPage,
      mediaType: mediaType ?? this.mediaType,
      quality: quality ?? this.quality,
      collate: collate ?? this.collate,
      reverseOrder: reverseOrder ?? this.reverseOrder,
      pageSubset: pageSubset ?? this.pageSubset,
      paperTray: paperTray ?? this.paperTray,
      marginPreset: marginPreset ?? this.marginPreset,
      customMarginMm: customMarginMm ?? this.customMarginMm,
      customScalePercent: customScalePercent ?? this.customScalePercent,
      pagesPerSheet: pagesPerSheet ?? this.pagesPerSheet,
      booklet: booklet ?? this.booklet,
      isBorderless: isBorderless ?? this.isBorderless,
      watermarkText: watermarkText ?? this.watermarkText,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      blackInkOnly: blackInkOnly ?? this.blackInkOnly,
      inkSavingMode: inkSavingMode ?? this.inkSavingMode,
      testPrintFirstPageOnly: testPrintFirstPageOnly ?? this.testPrintFirstPageOnly,
      colorMode: colorMode ?? this.colorMode,
      iccProfile: iccProfile ?? this.iccProfile,
      renderingIntent: renderingIntent ?? this.renderingIntent,
      blackPointCompensation: blackPointCompensation ?? this.blackPointCompensation,
      softProofingEnabled: softProofingEnabled ?? this.softProofingEnabled,
      advancedBwEnabled: advancedBwEnabled ?? this.advancedBwEnabled,
      advancedBwTone: advancedBwTone ?? this.advancedBwTone,
      customDpi: customDpi ?? this.customDpi,
      hardwareDpi: hardwareDpi ?? this.hardwareDpi,
      renderDpi: renderDpi ?? this.renderDpi,
      resampleFilter: resampleFilter ?? this.resampleFilter,
      isUpscaledForPrint: isUpscaledForPrint ?? this.isUpscaledForPrint,
      upscaleMultiplier: upscaleMultiplier ?? this.upscaleMultiplier,
      keepVectorGraphics: keepVectorGraphics ?? this.keepVectorGraphics,
      currentEffectivePpi: currentEffectivePpi ?? this.currentEffectivePpi,
      resamplingHistory: resamplingHistory ?? this.resamplingHistory,
      halftoneScreening: halftoneScreening ?? this.halftoneScreening,
      biDirectionalPrinting: biDirectionalPrinting ?? this.biDirectionalPrinting,
      toneAndInk: toneAndInk ?? this.toneAndInk,
      inkDensityPercent: inkDensityPercent ?? this.inkDensityPercent,
      blackGeneration: blackGeneration ?? this.blackGeneration,
      glossOptimizer: glossOptimizer ?? this.glossOptimizer,
      blackTankSelection: blackTankSelection ?? this.blackTankSelection,
      impositionMode: impositionMode ?? this.impositionMode,
      nupGapMm: nupGapMm ?? this.nupGapMm,
      posterOverlapMm: posterOverlapMm ?? this.posterOverlapMm,
      posterTilesX: posterTilesX ?? this.posterTilesX,
      posterTilesY: posterTilesY ?? this.posterTilesY,
      mirrorHorizontal: mirrorHorizontal ?? this.mirrorHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      rotateAngleDegrees: rotateAngleDegrees ?? this.rotateAngleDegrees,
      gutterBindingMarginMm: gutterBindingMarginMm ?? this.gutterBindingMarginMm,
      bleedMm: bleedMm ?? this.bleedMm,
      cropMarks: cropMarks ?? this.cropMarks,
      registrationMarks: registrationMarks ?? this.registrationMarks,
      colorBars: colorBars ?? this.colorBars,
      slugText: slugText ?? this.slugText,
      photoIdLayoutEnabled: photoIdLayoutEnabled ?? this.photoIdLayoutEnabled,
      photoIdPreset: photoIdPreset ?? this.photoIdPreset,
      photoWidthMm: photoWidthMm ?? this.photoWidthMm,
      photoHeightMm: photoHeightMm ?? this.photoHeightMm,
      photoSpacingMm: photoSpacingMm ?? this.photoSpacingMm,
      photosCount: photosCount ?? this.photosCount,
      borderlessExpansionBleedStep: borderlessExpansionBleedStep ?? this.borderlessExpansionBleedStep,
      showDateNameLabel: showDateNameLabel ?? this.showDateNameLabel,
      photoLabelText: photoLabelText ?? this.photoLabelText,
      rollPaperEnabled: rollPaperEnabled ?? this.rollPaperEnabled,
      rollAutoCut: rollAutoCut ?? this.rollAutoCut,
      cdDvdPrintEnabled: cdDvdPrintEnabled ?? this.cdDvdPrintEnabled,
      cdInnerDiameterMm: cdInnerDiameterMm ?? this.cdInnerDiameterMm,
      cdOuterDiameterMm: cdOuterDiameterMm ?? this.cdOuterDiameterMm,
      customPaperWidthMm: customPaperWidthMm ?? this.customPaperWidthMm,
      customPaperLengthMm: customPaperLengthMm ?? this.customPaperLengthMm,
      jobPriority: jobPriority ?? this.jobPriority,
      printToPdfFirst: printToPdfFirst ?? this.printToPdfFirst,
      jobTicketNotes: jobTicketNotes ?? this.jobTicketNotes,
      letterheadPdfPath: letterheadPdfPath ?? this.letterheadPdfPath,
      stampPreset: stampPreset ?? this.stampPreset,
      customStampText: customStampText ?? this.customStampText,
      stampOpacity: stampOpacity ?? this.stampOpacity,
      activePresetName: activePresetName ?? this.activePresetName,
      isStaffLocked: isStaffLocked ?? this.isStaffLocked,
      staffLockPin: staffLockPin ?? this.staffLockPin,
    );
  }

  /// Converts to legacy `FilePrintSettings` for backward compatibility with existing print drivers.
  FilePrintSettings toFilePrintSettings() {
    return FilePrintSettings(
      copies: copies,
      collate: collate,
      pageRange: pageRange,
      pageSubset: pageSubset,
      reverseOrder: reverseOrder,
      duplex: duplex,
      orientation: orientation,
      paperSize: paperSize,
      customWidthMm: customPaperWidthMm,
      customHeightMm: customPaperLengthMm,
      scaleMode: fitToPage ? PrintScaleMode.fitToPage : PrintScaleMode.customPercent,
      customScalePercent: customScalePercent,
      marginPreset: isBorderless ? MarginPreset.none : marginPreset,
      customMarginMm: customMarginMm,
      centerHorizontally: true,
      centerVertically: true,
      isColor: isColor,
      quality: quality,
      paperTray: paperTray,
      mediaType: mediaType,
      layoutMode: booklet
          ? SheetLayoutMode.booklet
          : (pagesPerSheet > 1 ? SheetLayoutMode.nUp : SheetLayoutMode.standard),
      pagesPerSheet: pagesPerSheet,
      mirrorHorizontal: mirrorHorizontal,
      flipVertical: flipVertical,
      watermarkText: watermarkText,
      watermarkOpacity: watermarkOpacity,
      headerText: headerText,
      footerText: footerText,
      showPageNumbers: showPageNumbers,
      scaleFitToPage: fitToPage,
      targetDpi: hardwareDpi,
      resampleAlgorithm: resampleFilter.name,
      renderDpiChoice: renderDpi.name,
      toneAndInkMap: toneAndInk.toMap(),
    );
  }
}

/// Action to automatically fix a media dependency or capability conflict.
class SettingsAutoFixAction {
  final String labelEn;
  final String labelSi;
  final String descriptionEn;
  final String descriptionSi;
  final UnifiedPrintSettings Function(UnifiedPrintSettings current) applyFix;

  const SettingsAutoFixAction({
    required this.labelEn,
    required this.labelSi,
    required this.descriptionEn,
    required this.descriptionSi,
    required this.applyFix,
  });
}

/// Dynamic validation issue found against printer capabilities.
class SettingsValidationIssue {
  final String settingKey;
  final String messageEn;
  final String messageSi;
  final bool isBlocking;
  final SettingsAutoFixAction? autoFix;

  const SettingsValidationIssue({
    required this.settingKey,
    required this.messageEn,
    required this.messageSi,
    this.isBlocking = false,
    this.autoFix,
  });
}

/// Validator evaluating settings against discovered capabilities with auto-fixes.
class SettingsCapabilityValidator {
  static List<SettingsValidationIssue> validate({
    required UnifiedPrintSettings settings,
    required DiscoveredCapabilities capabilities,
  }) {
    final issues = <SettingsValidationIssue>[];

    // 1. Media Type & Duplex Conflict (Photo media cannot be auto-duplexed)
    if (settings.duplex != DuplexMode.none) {
      final isPhoto = settings.mediaType.contains('Glossy') ||
          settings.mediaType.contains('Photo') ||
          settings.mediaType.contains('Velvet');
      if (isPhoto) {
        issues.add(
          SettingsValidationIssue(
            settingKey: 'duplex',
            messageEn: '${settings.mediaType} does not support double-sided printing.',
            messageSi: '${settings.mediaType} සඳහා දෙපැත්තෙන්ම මුද්‍රණය කළ නොහැක (තීන්ත බොඳ විය හැක).',
            isBlocking: false,
            autoFix: SettingsAutoFixAction(
              labelEn: 'Switch to Single-Sided',
              labelSi: 'තනි පැත්ත තෝරන්න',
              descriptionEn: 'Disable 2-sided printing for photo media.',
              descriptionSi: 'ෆොටෝ කොළ සඳහා තනි පැත්ත මුද්‍රණය සකසන්න.',
              applyFix: (s) => s.copyWith(duplex: DuplexMode.none),
            ),
          ),
        );
      } else if (!capabilities.supportsDuplex(settings.duplex)) {
        // Printer does not have hardware auto-duplex
        issues.add(
          SettingsValidationIssue(
            settingKey: 'duplex',
            messageEn: '${capabilities.modelName} does not have automatic duplex hardware.',
            messageSi: '${capabilities.modelName} හි ස්වයංක්‍රීය දෙපැත්ත මුද්‍රණ දෘඪාංග නොමැත.',
            isBlocking: false,
            autoFix: SettingsAutoFixAction(
              labelEn: 'Use Manual Duplex Assistant',
              labelSi: 'අත්පොත දෙපැත්ත සහායකය',
              descriptionEn: 'Print Helper will guide you through flipping sheets.',
              descriptionSi: 'කොළ හරවන ආකාරය පියවරෙන් පියවර පෙන්වයි.',
              applyFix: (s) => s.copyWith(duplex: DuplexMode.none),
            ),
          ),
        );
      }
    }

    // 2. Borderless & Media Type (Envelope or plain paper limitations)
    if (settings.isBorderless) {
      if (settings.mediaType.contains('Envelope')) {
        issues.add(
          SettingsValidationIssue(
            settingKey: 'borderless',
            messageEn: 'Borderless is not supported on envelopes.',
            messageSi: 'ලියුම් කවර සඳහා දාර රහිත (Borderless) මුද්‍රණය කළ නොහැක.',
            isBlocking: true,
            autoFix: SettingsAutoFixAction(
              labelEn: 'Turn Off Borderless',
              labelSi: 'දාර රහිත ඉවත් කරන්න',
              descriptionEn: 'Use standard margins for envelopes.',
              descriptionSi: 'සාමාන්‍ය දාර සහිතව සකසන්න.',
              applyFix: (s) => s.copyWith(isBorderless: false, marginPreset: MarginPreset.normal),
            ),
          ),
        );
      } else if (!capabilities.supportsBorderless) {
        issues.add(
          SettingsValidationIssue(
            settingKey: 'borderless',
            messageEn: 'This printer does not support borderless printing.',
            messageSi: 'මෙම ප්‍රින්ටරයේ දාර රහිත (Borderless) පහසුකම නොමැත.',
            isBlocking: true,
            autoFix: SettingsAutoFixAction(
              labelEn: 'Use Standard Margins',
              labelSi: 'සාමාන්‍ය දාර තෝරන්න',
              descriptionEn: 'Apply 3mm printer margins.',
              descriptionSi: 'සාමාන්‍ය දාර යොදන්න.',
              applyFix: (s) => s.copyWith(isBorderless: false, marginPreset: MarginPreset.normal),
            ),
          ),
        );
      }
    }

    // 3. Thick cardstock & Cassette tray
    if (settings.mediaType.contains('Thick') || settings.mediaType.contains('Cardstock')) {
      if (capabilities.inputBins.any((b) => b.contains('Rear') || b.contains('Bypass')) &&
          !settings.paperTray.contains('Rear') &&
          !settings.paperTray.contains('Bypass')) {
        issues.add(
          SettingsValidationIssue(
            settingKey: 'paperTray',
            messageEn: 'Thick media requires the Rear Bypass tray to avoid jams.',
            messageSi: 'ඝන කාඩ්පත් හිරවීම වැළැක්වීමට පසුපස තට්ටුව (Rear Tray) තෝරන්න.',
            isBlocking: false,
            autoFix: SettingsAutoFixAction(
              labelEn: 'Select Rear Tray',
              labelSi: 'පසුපස තට්ටුව තෝරන්න',
              descriptionEn: 'Route feed path through rear specialty slot.',
              descriptionSi: 'පසුපස විශේෂිත තට්ටුව තෝරන්න.',
              applyFix: (s) {
                final rear = capabilities.inputBins.firstWhere(
                  (b) => b.contains('Rear') || b.contains('Bypass'),
                  orElse: () => 'Auto Select',
                );
                return s.copyWith(paperTray: rear);
              },
            ),
          ),
        );
      }
    }

    // 4. Color vs Mono mismatch
    if (settings.isColor && !capabilities.supportsColor) {
      issues.add(
        SettingsValidationIssue(
          settingKey: 'isColor',
          messageEn: '${capabilities.modelName} is a monochrome printer.',
          messageSi: '${capabilities.modelName} කළු-සුදු ප්‍රින්ටරයකි.',
          isBlocking: false,
          autoFix: SettingsAutoFixAction(
            labelEn: 'Switch to Black & White',
            labelSi: 'කළු සුදු තෝරන්න',
            descriptionEn: 'Print in grayscale mode.',
            descriptionSi: 'කළු සුදු ක්‍රමයට මාරු කරන්න.',
            applyFix: (s) => s.copyWith(isColor: false),
          ),
        ),
      );
    }

    // 5. CD/DVD Print Tray Requirement
    if (settings.cdDvdPrintEnabled && !capabilities.supportsCdDvd) {
      issues.add(
        SettingsValidationIssue(
          settingKey: 'cdDvdPrintEnabled',
          messageEn: 'Direct CD/DVD printing is not supported on this model.',
          messageSi: 'මෙම මාදිලියේ CD/DVD තැටි මුද්‍රණ පහසුකම නොමැත.',
          isBlocking: true,
          autoFix: SettingsAutoFixAction(
            labelEn: 'Disable CD/DVD Print',
            labelSi: 'CD/DVD ඉවත් කරන්න',
            descriptionEn: 'Switch back to standard paper printing.',
            descriptionSi: 'සාමාන්‍ය කඩදාසි මුද්‍රණයට මාරු වන්න.',
            applyFix: (s) => s.copyWith(cdDvdPrintEnabled: false),
          ),
        ),
      );
    }

    // 6. Effective PPI Low Resolution Check
    if (settings.currentEffectivePpi != null && settings.currentEffectivePpi! < 150.0) {
      final ppiVal = settings.currentEffectivePpi!.round();
      issues.add(
        SettingsValidationIssue(
          settingKey: 'effectivePpi',
          messageEn: 'This photo will print at $ppiVal PPI on ${settings.paperSize} and may look soft or pixelated.',
          messageSi: 'මෙම ඡායාරූපය ${settings.paperSize} කොළයේ මුද්‍රණය වන්නේ $ppiVal PPI අගයකින් බැවින් බොඳ වී පෙනිය හැක.',
          isBlocking: false,
          autoFix: SettingsAutoFixAction(
            labelEn: 'Upscale with Lanczos (2x)',
            labelSi: 'Lanczos (2x) මඟින් විශාල කරන්න',
            descriptionEn: 'High-fidelity windowed sinc resampling to increase printed pixels.',
            descriptionSi: 'Lanczos-3 ක්‍රමයෙන් පික්සල් වැඩි කර පැහැදිලි බව රැකගන්න.',
            applyFix: (s) => s.copyWith(
              isUpscaledForPrint: true,
              upscaleMultiplier: 2.0,
              resampleFilter: ResamplingAlgorithm.lanczos,
            ),
          ),
        ),
      );
    }

    // 7. Media Type vs Hardware DPI Droplet Volume Check
    if (settings.hardwareDpi >= 2400 && settings.mediaType.toLowerCase().contains('plain')) {
      issues.add(
        SettingsValidationIssue(
          settingKey: 'hardwareDpi',
          messageEn: 'Plain paper cannot absorb ${settings.hardwareDpi} DPI droplet volume without cockling/bleeding.',
          messageSi: 'සාමාන්‍ය කඩදාසිවලට ${settings.hardwareDpi} DPI තීන්ත ප්‍රමාණය උරාගත නොහැකි බැවින් තීන්ත බොඳ විය හැක.',
          isBlocking: false,
          autoFix: SettingsAutoFixAction(
            labelEn: 'Switch to 600 DPI Normal',
            labelSi: '600 DPI සාමාන්‍ය තෝරන්න',
            descriptionEn: 'Use balanced 600 DPI suitable for plain paper.',
            descriptionSi: 'සාමාන්‍ය කඩදාසි සඳහා 600 DPI යොදන්න.',
            applyFix: (s) => s.copyWith(hardwareDpi: 600),
          ),
        ),
      );
    }

    // 8. Large Render DPI Memory Warning
    if (settings.renderDpi == RenderDpiChoice.dpi1200) {
      issues.add(
        SettingsValidationIssue(
          settingKey: 'renderDpi',
          messageEn: '1200 Render DPI consumes ~420 MB RAM per page. Vector text will be preserved where driver allows.',
          messageSi: '1200 Render DPI මඟින් එක් පිටුවකට ~420 MB මතකයක් වැයවේ. අකුරු vector ලෙසම සුරැකේ.',
          isBlocking: false,
          autoFix: SettingsAutoFixAction(
            labelEn: 'Switch to Auto Render DPI',
            labelSi: 'ස්වයංක්‍රීය Render DPI තෝරන්න',
            descriptionEn: 'Use dynamic rasterization DPI based on printer hardware.',
            descriptionSi: 'ප්‍රින්ටරයට ගැලපෙන පරිදි ස්වයංක්‍රීයව සකසන්න.',
            applyFix: (s) => s.copyWith(renderDpi: RenderDpiChoice.auto),
          ),
        ),
      );
    }

    // 9. Tone & Ink: Double Adjustment Warning
    if (settings.toneAndInk.isDoubleAdjustmentWarning) {
      issues.add(
        SettingsValidationIssue(
          settingKey: 'toneAndInk_doubleAdjustment',
          messageEn: 'Double color adjustment detected: Both printer driver color adjustment and Print Helper tone controls are active.',
          messageSi: 'ප්‍රින්ටර් ඩ්‍රයිවර් සහ Print Helper යන දෙකෙන්ම එකවර වර්ණ වෙනස් කිරීම් සිදු වේ. මෙය වර්ණ අපැහැදිලි වීමට හේතු විය හැක.',
          isBlocking: false,
          autoFix: SettingsAutoFixAction(
            labelEn: 'Let Print Helper Manage Tone',
            labelSi: 'Print Helper ට භාර දෙන්න',
            descriptionEn: 'Disable driver color adjustments to avoid double manipulation.',
            descriptionSi: 'ඩ්‍රයිවර් වර්ණ සැකසුම් අක්‍රිය කර Print Helper පමණක් යොදන්න.',
            applyFix: (s) => s.copyWith(
              toneAndInk: s.toneAndInk.copyWith(driverColorAdjustmentActive: false),
            ),
          ),
        ),
      );
    }

    // 10. Tone & Ink: Heavy Plain Paper Density Bleed Warning
    if (settings.mediaType.toLowerCase().contains('plain') && settings.toneAndInk.density > 20) {
      issues.add(
        SettingsValidationIssue(
          settingKey: 'toneAndInk_densityPlain',
          messageEn: 'High ink density (+${settings.toneAndInk.density}) on Plain Paper causes paper cockling and ink bleed-through.',
          messageSi: 'සාමාන්‍ය කඩදාසිවලට අධික තීන්ත ඝනත්වය (+${settings.toneAndInk.density}) නිසා කොළ රැළි වැටී තීන්ත පිටුපසට කාන්දු විය හැක.',
          isBlocking: false,
          autoFix: SettingsAutoFixAction(
            labelEn: 'Apply Plain Paper Compensation',
            labelSi: 'සාමාන්‍ය කොළ පාලනය යොදන්න',
            descriptionEn: 'Apply optimized midtone lift and text sharpness to reduce ink deposit.',
            descriptionSi: 'තීන්ත පාලනය කර අකුරු තියුණු කරන පෙරසැකසුම යොදන්න.',
            applyFix: (s) => s.copyWith(
              toneAndInk: s.toneAndInk.applyPaperCompensation(PaperCompensationPreset.plainPaper),
            ),
          ),
        ),
      );
    }

    return issues;
  }
}
