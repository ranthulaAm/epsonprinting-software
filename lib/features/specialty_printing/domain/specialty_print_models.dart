import 'dart:math' as math;

/// Types of specialty print modules available in Print Helper.
///
/// A module is unlocked and shown in the UI ONLY when the active printer
/// reports support via live capability discovery (Print Schema, IPP, SNMP)
/// or verified database profile.
enum SpecialtyModuleType {
  /// Direct CD / DVD / Blu-ray optical disc tray printing.
  cdDvdDisc,

  /// Dual-card or single-card CR80 PVC ID card tray printing.
  pvcIdCard,

  /// Passport and Visa photo sheet imposition with cut guides.
  passportPhotoSheet,

  /// Heavy rigid posterboard and thick media straight-through pass.
  rigidMedia,

  /// Roll paper with continuous length and auto-cutter management.
  rollCutter,

  /// Dye-sublimation heat transfer merchandise with mandatory auto-mirror.
  dyeSublimation,

  /// ColorWorks industrial roll and die-cut label printing.
  colorWorksLabel,

  /// Point-of-Sale / shop counter 80mm/58mm thermal receipt printing.
  shopReceipt,
}

// ============================================================================
// 1. CD / DVD / Blu-ray Disc Module Models
// ============================================================================

/// Disc media size profile.
enum DiscSizeProfile {
  /// Standard 12 cm optical disc (Outer 116-120mm, Inner 18-43mm).
  standard12cm,

  /// Mini 8 cm optical disc (Outer 80mm, Inner 18-43mm).
  mini8cm,

  /// Custom disc diameter configuration.
  custom,
}

/// Specifications for direct CD / DVD disc printing.
///
/// Diameters are measured strictly in millimeters (outer diameter and
/// inner diameter, NOT radii) to prevent confusion and match Epson driver specs.
class CdDvdSpec {
  /// Disc size profile.
  final DiscSizeProfile profile;

  /// Outer printable diameter in mm (Standard default: 116.0 mm, max: 120.0 mm).
  final double outerDiameterMm;

  /// Inner unprintable hub diameter in mm (Standard default: 43.0 mm; hub-printable: 18.0-20.0 mm).
  final double innerDiameterMm;

  /// Minimum allowed outer diameter for the active printer driver (e.g. 70.0 mm).
  final double minOuterDiameterMm;

  /// Maximum allowed outer diameter for the active printer driver (e.g. 120.0 mm).
  final double maxOuterDiameterMm;

  /// Minimum allowed inner diameter for the active printer driver (e.g. 18.0 mm).
  final double minInnerDiameterMm;

  /// Maximum allowed inner diameter for the active printer driver (e.g. 50.0 mm).
  final double maxInnerDiameterMm;

  /// Curved text string positioned along the circular perimeter.
  final String circularText;

  /// Radial position for circular text in mm from center (e.g. 45.0 mm).
  final double circularTextRadiusMm;

  /// Text font size in points.
  final double circularTextFontSize;

  /// Start angle for circular text in degrees (0 = top, 90 = right).
  final double circularTextStartAngleDeg;

  /// Path or identifier of background artwork.
  final String? backgroundArtworkPath;

  /// Whether the user has completed the mandatory plain-paper test print step.
  final bool paperTestPrintCompleted;

  /// Calibration offset in mm along X axis.
  final double offsetXmm;

  /// Calibration offset in mm along Y axis.
  final double offsetYmm;

  const CdDvdSpec({
    this.profile = DiscSizeProfile.standard12cm,
    this.outerDiameterMm = 116.0,
    this.innerDiameterMm = 43.0,
    this.minOuterDiameterMm = 70.0,
    this.maxOuterDiameterMm = 120.0,
    this.minInnerDiameterMm = 18.0,
    this.maxInnerDiameterMm = 50.0,
    this.circularText = '',
    this.circularTextRadiusMm = 45.0,
    this.circularTextFontSize = 14.0,
    this.circularTextStartAngleDeg = 0.0,
    this.backgroundArtworkPath,
    this.paperTestPrintCompleted = false,
    this.offsetXmm = 0.0,
    this.offsetYmm = 0.0,
  });

  /// Computes the printable ring surface area in square millimeters:
  ///
  /// $$\text{Area} = \pi \left(\left(\frac{D_{\text{outer}}}{2}\right)^2 - \left(\frac{D_{\text{inner}}}{2}\right)^2\right)$$
  double get printableAreaMm2 {
    final rOuter = outerDiameterMm / 2.0;
    final rInner = innerDiameterMm / 2.0;
    return math.pi * (rOuter * rOuter - rInner * rInner);
  }

  /// Validates whether a point $(x, y)$ in mm from disc center falls inside
  /// the printable doughnut ring mask.
  bool isPointWithinPrintableRing(double xMm, double yMm) {
    final dist = math.sqrt(xMm * xMm + yMm * yMm);
    final rOuter = outerDiameterMm / 2.0;
    final rInner = innerDiameterMm / 2.0;
    return dist >= rInner && dist <= rOuter;
  }

  CdDvdSpec copyWith({
    DiscSizeProfile? profile,
    double? outerDiameterMm,
    double? innerDiameterMm,
    double? minOuterDiameterMm,
    double? maxOuterDiameterMm,
    double? minInnerDiameterMm,
    double? maxInnerDiameterMm,
    String? circularText,
    double? circularTextRadiusMm,
    double? circularTextFontSize,
    double? circularTextStartAngleDeg,
    String? backgroundArtworkPath,
    bool? paperTestPrintCompleted,
    double? offsetXmm,
    double? offsetYmm,
  }) {
    return CdDvdSpec(
      profile: profile ?? this.profile,
      outerDiameterMm: outerDiameterMm ?? this.outerDiameterMm,
      innerDiameterMm: innerDiameterMm ?? this.innerDiameterMm,
      minOuterDiameterMm: minOuterDiameterMm ?? this.minOuterDiameterMm,
      maxOuterDiameterMm: maxOuterDiameterMm ?? this.maxOuterDiameterMm,
      minInnerDiameterMm: minInnerDiameterMm ?? this.minInnerDiameterMm,
      maxInnerDiameterMm: maxInnerDiameterMm ?? this.maxInnerDiameterMm,
      circularText: circularText ?? this.circularText,
      circularTextRadiusMm: circularTextRadiusMm ?? this.circularTextRadiusMm,
      circularTextFontSize: circularTextFontSize ?? this.circularTextFontSize,
      circularTextStartAngleDeg: circularTextStartAngleDeg ?? this.circularTextStartAngleDeg,
      backgroundArtworkPath: backgroundArtworkPath ?? this.backgroundArtworkPath,
      paperTestPrintCompleted: paperTestPrintCompleted ?? this.paperTestPrintCompleted,
      offsetXmm: offsetXmm ?? this.offsetXmm,
      offsetYmm: offsetYmm ?? this.offsetYmm,
    );
  }

  Map<String, dynamic> toJson() => {
    'profile': profile.name,
    'outerDiameterMm': outerDiameterMm,
    'innerDiameterMm': innerDiameterMm,
    'minOuterDiameterMm': minOuterDiameterMm,
    'maxOuterDiameterMm': maxOuterDiameterMm,
    'minInnerDiameterMm': minInnerDiameterMm,
    'maxInnerDiameterMm': maxInnerDiameterMm,
    'circularText': circularText,
    'circularTextRadiusMm': circularTextRadiusMm,
    'circularTextFontSize': circularTextFontSize,
    'circularTextStartAngleDeg': circularTextStartAngleDeg,
    'backgroundArtworkPath': backgroundArtworkPath,
    'paperTestPrintCompleted': paperTestPrintCompleted,
    'offsetXmm': offsetXmm,
    'offsetYmm': offsetYmm,
  };
}

// ============================================================================
// 2. PVC ID Card Module Models
// ============================================================================

/// Single card entry in a PVC ID card batch or tray slot.
class PvcCardData {
  final String cardId;
  final String fullName;
  final String roleOrTitle;
  final String? organization;
  final String? photoPath;
  final String? barcodeData;
  final String? qrCodePayload;
  final bool printBackSide;
  final String? backNotes;

  const PvcCardData({
    required this.cardId,
    required this.fullName,
    this.roleOrTitle = '',
    this.organization,
    this.photoPath,
    this.barcodeData,
    this.qrCodePayload,
    this.printBackSide = false,
    this.backNotes,
  });

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'fullName': fullName,
    'roleOrTitle': roleOrTitle,
    'organization': organization,
    'photoPath': photoPath,
    'barcodeData': barcodeData,
    'qrCodePayload': qrCodePayload,
    'printBackSide': printBackSide,
    'backNotes': backNotes,
  };
}

/// Specifications for printing ISO/IEC 7810 CR80 PVC ID cards.
class PvcIdCardSpec {
  /// ISO/IEC 7810 ID-1 standard width in mm.
  static const double cr80WidthMm = 85.60;

  /// ISO/IEC 7810 ID-1 standard height in mm.
  static const double cr80HeightMm = 53.98;

  /// Standard thickness in mm (30 mil).
  static const double cr80ThicknessMm = 0.76;

  /// Number of card slots supported by the physical tray (1 or 2).
  final int traySlotsCount;

  /// Whether aftermarket tray mode is enabled.
  final bool isAftermarketTray;

  /// User confirmation that cards are specially coated for inkjet ink.
  final bool inkjetCoatedConfirmed;

  /// X calibration alignment offset in mm (printer-specific).
  final double offsetXmm;

  /// Y calibration alignment offset in mm (printer-specific).
  final double offsetYmm;

  /// Active card in Slot 1 (top / front).
  final PvcCardData? slot1Card;

  /// Active card in Slot 2 (bottom / back, for dual-card trays like L8050/L18050).
  final PvcCardData? slot2Card;

  /// Batch queue of cards loaded from CSV or directory.
  final List<PvcCardData> batchQueue;

  const PvcIdCardSpec({
    this.traySlotsCount = 2,
    this.isAftermarketTray = false,
    this.inkjetCoatedConfirmed = false,
    this.offsetXmm = 0.0,
    this.offsetYmm = 0.0,
    this.slot1Card,
    this.slot2Card,
    this.batchQueue = const [],
  });

  PvcIdCardSpec copyWith({
    int? traySlotsCount,
    bool? isAftermarketTray,
    bool? inkjetCoatedConfirmed,
    double? offsetXmm,
    double? offsetYmm,
    PvcCardData? slot1Card,
    PvcCardData? slot2Card,
    List<PvcCardData>? batchQueue,
  }) {
    return PvcIdCardSpec(
      traySlotsCount: traySlotsCount ?? this.traySlotsCount,
      isAftermarketTray: isAftermarketTray ?? this.isAftermarketTray,
      inkjetCoatedConfirmed: inkjetCoatedConfirmed ?? this.inkjetCoatedConfirmed,
      offsetXmm: offsetXmm ?? this.offsetXmm,
      offsetYmm: offsetYmm ?? this.offsetYmm,
      slot1Card: slot1Card ?? this.slot1Card,
      slot2Card: slot2Card ?? this.slot2Card,
      batchQueue: batchQueue ?? this.batchQueue,
    );
  }

  Map<String, dynamic> toJson() => {
    'traySlotsCount': traySlotsCount,
    'isAftermarketTray': isAftermarketTray,
    'inkjetCoatedConfirmed': inkjetCoatedConfirmed,
    'offsetXmm': offsetXmm,
    'offsetYmm': offsetYmm,
    'slot1Card': slot1Card?.toJson(),
    'slot2Card': slot2Card?.toJson(),
    'batchQueueLength': batchQueue.length,
  };
}

// ============================================================================
// 3. Passport & ID Photo Sheets Models
// ============================================================================

/// Standard passport / visa photo dimension presets.
enum PassportStandardType {
  /// Standard Sri Lanka / UK / Schengen / Commonwealth 35 x 45 mm.
  sriLankaUk35x45,

  /// US Visa / India Visa / Diversity Visa 51 x 51 mm (2 x 2 inches).
  usVisa2x2in,

  /// 30 x 40 mm (Standard job application / student ID).
  standard30x40,

  /// 35 x 35 mm (China / Indian Passport).
  square35x35,

  /// Custom photo size.
  custom,
}

/// Target photo sheet paper format.
enum PhotoSheetPaperSize {
  /// Standard 4 x 6 inches (100 x 150 mm) photo paper.
  photo4x6,

  /// A4 document photo paper (210 x 297 mm).
  a4,

  /// 5 x 7 inches (127 x 178 mm) photo paper.
  photo5x7,
}

/// Crop marks / cutting guidelines style.
enum CropGuideStyle {
  solidLines,
  dashedLines,
  cornerMarksOnly,
  none,
}

/// Specifications for Passport & ID photo sheet imposition.
class PassportPhotoSheetSpec {
  final PassportStandardType standardType;
  final double photoWidthMm;
  final double photoHeightMm;
  final PhotoSheetPaperSize paperSize;
  final CropGuideStyle guideStyle;
  final double marginMm;
  final double spacingBetweenPhotosMm;
  final String? imageSourcePath;
  final int totalPhotosRequested;

  const PassportPhotoSheetSpec({
    this.standardType = PassportStandardType.sriLankaUk35x45,
    this.photoWidthMm = 35.0,
    this.photoHeightMm = 45.0,
    this.paperSize = PhotoSheetPaperSize.photo4x6,
    this.guideStyle = CropGuideStyle.dashedLines,
    this.marginMm = 5.0,
    this.spacingBetweenPhotosMm = 2.0,
    this.imageSourcePath,
    this.totalPhotosRequested = 8,
  });

  /// Sheet dimensions in millimeters based on selected target paper size.
  (double width, double height) get sheetDimensionsMm {
    switch (paperSize) {
      case PhotoSheetPaperSize.photo4x6:
        return (101.6, 152.4);
      case PhotoSheetPaperSize.photo5x7:
        return (127.0, 177.8);
      case PhotoSheetPaperSize.a4:
        return (210.0, 297.0);
    }
  }

  /// Calculates maximum possible photos fitting on the sheet:
  ///
  /// Returns (columns, rows, totalCapacity).
  (int cols, int rows, int capacity) calculateImpositionGrid() {
    final (sheetW, sheetH) = sheetDimensionsMm;
    final usableW = sheetW - (marginMm * 2.0);
    final usableH = sheetH - (marginMm * 2.0);

    if (usableW <= 0 || usableH <= 0) return (0, 0, 0);

    // Orientation 1: Portrait photos on portrait sheet
    final cols1 = ((usableW + spacingBetweenPhotosMm) / (photoWidthMm + spacingBetweenPhotosMm)).floor();
    final rows1 = ((usableH + spacingBetweenPhotosMm) / (photoHeightMm + spacingBetweenPhotosMm)).floor();
    final cap1 = (cols1 > 0 && rows1 > 0) ? (cols1 * rows1) : 0;

    // Orientation 2: Rotated 90 degrees
    final cols2 = ((usableW + spacingBetweenPhotosMm) / (photoHeightMm + spacingBetweenPhotosMm)).floor();
    final rows2 = ((usableH + spacingBetweenPhotosMm) / (photoWidthMm + spacingBetweenPhotosMm)).floor();
    final cap2 = (cols2 > 0 && rows2 > 0) ? (cols2 * rows2) : 0;

    if (cap2 > cap1) {
      return (cols2, rows2, cap2);
    }
    return (cols1, rows1, cap1);
  }

  PassportPhotoSheetSpec copyWith({
    PassportStandardType? standardType,
    double? photoWidthMm,
    double? photoHeightMm,
    PhotoSheetPaperSize? paperSize,
    CropGuideStyle? guideStyle,
    double? marginMm,
    double? spacingBetweenPhotosMm,
    String? imageSourcePath,
    int? totalPhotosRequested,
  }) {
    return PassportPhotoSheetSpec(
      standardType: standardType ?? this.standardType,
      photoWidthMm: photoWidthMm ?? this.photoWidthMm,
      photoHeightMm: photoHeightMm ?? this.photoHeightMm,
      paperSize: paperSize ?? this.paperSize,
      guideStyle: guideStyle ?? this.guideStyle,
      marginMm: marginMm ?? this.marginMm,
      spacingBetweenPhotosMm: spacingBetweenPhotosMm ?? this.spacingBetweenPhotosMm,
      imageSourcePath: imageSourcePath ?? this.imageSourcePath,
      totalPhotosRequested: totalPhotosRequested ?? this.totalPhotosRequested,
    );
  }

  Map<String, dynamic> toJson() => {
    'standardType': standardType.name,
    'photoWidthMm': photoWidthMm,
    'photoHeightMm': photoHeightMm,
    'paperSize': paperSize.name,
    'guideStyle': guideStyle.name,
    'marginMm': marginMm,
    'spacingBetweenPhotosMm': spacingBetweenPhotosMm,
    'imageSourcePath': imageSourcePath,
    'totalPhotosRequested': totalPhotosRequested,
  };
}

// ============================================================================
// 4. Rigid & Thick Media Module Models
// ============================================================================

/// Physical feed path for thick and rigid media.
enum RigidFeedPathType {
  /// Straight-through rear manual single-sheet feeder (e.g. L8180).
  rearStraightThrough,

  /// Front motorized posterboard slot (e.g. SureColor SC-P700/P900).
  frontStraightPosterboard,

  /// Standard rear vertical friction feed (up to 300 gsm / 0.3mm).
  rearVerticalStandard,
}

/// Specifications and guardrails for printing thick or rigid media.
class RigidMediaSpec {
  /// Selected paper thickness in mm (e.g. 1.3 mm, 1.5 mm, 0.5 mm).
  final double mediaThicknessMm;

  /// Selected paper grammage in gsm (e.g. 450 gsm, 300 gsm).
  final int mediaGrammageGsm;

  /// Maximum media thickness supported by the active printer in mm.
  final double printerMaxThicknessLimitMm;

  /// Recommended physical feed tray path.
  final RigidFeedPathType recommendedFeedPath;

  /// Platen gap elevation setting (Standard, Wide, Wider).
  final String platenGapSetting;

  const RigidMediaSpec({
    this.mediaThicknessMm = 0.8,
    this.mediaGrammageGsm = 350,
    this.printerMaxThicknessLimitMm = 1.3,
    this.recommendedFeedPath = RigidFeedPathType.rearStraightThrough,
    this.platenGapSetting = 'Wider',
  });

  /// Whether the selected media thickness exceeds the printer's confirmed physical limit.
  bool get exceedsPrinterLimit => mediaThicknessMm > printerMaxThicknessLimitMm;

  /// Difference by which thickness exceeds limit in mm.
  double get excessThicknessMm => exceedsPrinterLimit ? (mediaThicknessMm - printerMaxThicknessLimitMm) : 0.0;

  RigidMediaSpec copyWith({
    double? mediaThicknessMm,
    int? mediaGrammageGsm,
    double? printerMaxThicknessLimitMm,
    RigidFeedPathType? recommendedFeedPath,
    String? platenGapSetting,
  }) {
    return RigidMediaSpec(
      mediaThicknessMm: mediaThicknessMm ?? this.mediaThicknessMm,
      mediaGrammageGsm: mediaGrammageGsm ?? this.mediaGrammageGsm,
      printerMaxThicknessLimitMm: printerMaxThicknessLimitMm ?? this.printerMaxThicknessLimitMm,
      recommendedFeedPath: recommendedFeedPath ?? this.recommendedFeedPath,
      platenGapSetting: platenGapSetting ?? this.platenGapSetting,
    );
  }

  Map<String, dynamic> toJson() => {
    'mediaThicknessMm': mediaThicknessMm,
    'mediaGrammageGsm': mediaGrammageGsm,
    'printerMaxThicknessLimitMm': printerMaxThicknessLimitMm,
    'recommendedFeedPath': recommendedFeedPath.name,
    'platenGapSetting': platenGapSetting,
    'exceedsLimit': exceedsPrinterLimit,
  };
}

// ============================================================================
// 5. Roll Paper & Cutter Module Models
// ============================================================================

/// Automatic cutter action modes.
enum RollCutAction {
  /// Automatically cut paper immediately after each page.
  cutAfterPage,

  /// Cut paper only after the complete multi-page job finishes.
  cutAtJobEnd,

  /// Do not trigger auto-cutter; print a thin dashed cut-guide line across the roll.
  printCutGuideLineOnly,

  /// Manual cut with external razor / trim ruler.
  manualCut,
}

/// Specifications for roll media feeding and rotary cutting.
class RollPaperCutterSpec {
  /// Physical roll width in inches (e.g. 13", 17", 24", 36", 44") or mm.
  final double rollWidthInches;

  /// Roll width in millimeters.
  final double rollWidthMm;

  /// Cut action mode.
  final RollCutAction cutAction;

  /// Whether full-bleed borderless roll printing is active.
  final bool borderlessOnRoll;

  /// Length of print job along roll in mm.
  final double bannerLengthMm;

  /// Maximum banner print length supported by driver in mm (e.g. 18,000 mm = 18m).
  final double maxBannerLengthLimitMm;

  const RollPaperCutterSpec({
    this.rollWidthInches = 24.0,
    this.rollWidthMm = 610.0,
    this.cutAction = RollCutAction.cutAfterPage,
    this.borderlessOnRoll = false,
    this.bannerLengthMm = 1200.0,
    this.maxBannerLengthLimitMm = 18000.0,
  });

  bool get exceedsMaxBannerLength => bannerLengthMm > maxBannerLengthLimitMm;

  RollPaperCutterSpec copyWith({
    double? rollWidthInches,
    double? rollWidthMm,
    RollCutAction? cutAction,
    bool? borderlessOnRoll,
    double? bannerLengthMm,
    double? maxBannerLengthLimitMm,
  }) {
    return RollPaperCutterSpec(
      rollWidthInches: rollWidthInches ?? this.rollWidthInches,
      rollWidthMm: rollWidthMm ?? this.rollWidthMm,
      cutAction: cutAction ?? this.cutAction,
      borderlessOnRoll: borderlessOnRoll ?? this.borderlessOnRoll,
      bannerLengthMm: bannerLengthMm ?? this.bannerLengthMm,
      maxBannerLengthLimitMm: maxBannerLengthLimitMm ?? this.maxBannerLengthLimitMm,
    );
  }

  Map<String, dynamic> toJson() => {
    'rollWidthInches': rollWidthInches,
    'rollWidthMm': rollWidthMm,
    'cutAction': cutAction.name,
    'borderlessOnRoll': borderlessOnRoll,
    'bannerLengthMm': bannerLengthMm,
    'maxBannerLengthLimitMm': maxBannerLengthLimitMm,
  };
}

// ============================================================================
// 6. Dye-Sublimation Merchandise Module Models
// ============================================================================

/// Merchandise template profiles for sublimation heat transfer.
enum SublimationItemType {
  /// Standard 11oz ceramic mug wrap (200 x 95 mm).
  mug11oz,

  /// Large 15oz ceramic mug wrap (220 x 105 mm).
  mug15oz,

  /// T-Shirt Chest / Back (A4 / A3 portrait).
  tshirtA4,

  /// Lanyard ribbon continuous repeat (900 x 20 mm).
  lanyardRepeat,

  /// Rectangular mousepad (230 x 190 mm).
  mousepad,

  /// Custom heat-press sublimation product.
  customMerchandise,
}

/// Specifications for dye-sublimation heat press transfer printing.
class DyeSublimationSpec {
  final SublimationItemType itemType;

  /// Physical template width in mm.
  final double templateWidthMm;

  /// Physical template height in mm.
  final double templateHeightMm;

  /// Mandatory horizontal mirror / flip (MUST be true for sublimation transfer).
  final bool autoMirrorEnabled;

  /// Bleed allowance in mm for heat press alignment (typically 2-3 mm).
  final double bleedMm;

  /// Color profile preset for transfer (e.g. "Epson DS Transfer General Purpose").
  final String transferColorProfile;

  const DyeSublimationSpec({
    this.itemType = SublimationItemType.mug11oz,
    this.templateWidthMm = 200.0,
    this.templateHeightMm = 95.0,
    this.autoMirrorEnabled = true,
    this.bleedMm = 3.0,
    this.transferColorProfile = 'Epson DS Transfer Multi-Use',
  });

  DyeSublimationSpec copyWith({
    SublimationItemType? itemType,
    double? templateWidthMm,
    double? templateHeightMm,
    bool? autoMirrorEnabled,
    double? bleedMm,
    String? transferColorProfile,
  }) {
    return DyeSublimationSpec(
      itemType: itemType ?? this.itemType,
      templateWidthMm: templateWidthMm ?? this.templateWidthMm,
      templateHeightMm: templateHeightMm ?? this.templateHeightMm,
      autoMirrorEnabled: autoMirrorEnabled ?? this.autoMirrorEnabled,
      bleedMm: bleedMm ?? this.bleedMm,
      transferColorProfile: transferColorProfile ?? this.transferColorProfile,
    );
  }

  Map<String, dynamic> toJson() => {
    'itemType': itemType.name,
    'templateWidthMm': templateWidthMm,
    'templateHeightMm': templateHeightMm,
    'autoMirrorEnabled': autoMirrorEnabled,
    'bleedMm': bleedMm,
    'transferColorProfile': transferColorProfile,
  };
}

// ============================================================================
// 7. ColorWorks Label Module Models
// ============================================================================

/// Form factor and die-cut shape of label media.
enum LabelFormFactor {
  /// Die-cut rectangular labels with rounded corners and gap.
  dieCutRectangle,

  /// Continuous roll label media (cut to arbitrary length).
  continuousRoll,

  /// Circular / oval die-cut badge labels.
  circularBadge,

  /// GHS chemical hazard warning labels with red diamond borders.
  ghsChemicalHazard,
}

/// Dispense and handling mode for label printers.
enum LabelDispenseMode {
  /// Cut after each label or job using built-in rotary cutter.
  autoCutter,

  /// Automatic peeler mechanism (peels liner backing for instant application).
  peeler,

  /// Continuous tear-off bar.
  tearOff,
}

/// Specifications for industrial color label printing.
class ColorWorksLabelSpec {
  final LabelFormFactor formFactor;
  final double labelWidthMm;
  final double labelHeightMm;
  final double gapBetweenLabelsMm;
  final LabelDispenseMode dispenseMode;
  final String barcodeData;
  final String barcodeSymbology; // 'Code128', 'QR_Code', 'EAN13', 'Datamatrix'
  final bool waterProofGhsCompliance;

  const ColorWorksLabelSpec({
    this.formFactor = LabelFormFactor.dieCutRectangle,
    this.labelWidthMm = 101.6, // 4 inches
    this.labelHeightMm = 76.2,  // 3 inches
    this.gapBetweenLabelsMm = 3.0,
    this.dispenseMode = LabelDispenseMode.autoCutter,
    this.barcodeData = 'LBL-0094821',
    this.barcodeSymbology = 'Code128',
    this.waterProofGhsCompliance = true,
  });

  ColorWorksLabelSpec copyWith({
    LabelFormFactor? formFactor,
    double? labelWidthMm,
    double? labelHeightMm,
    double? gapBetweenLabelsMm,
    LabelDispenseMode? dispenseMode,
    String? barcodeData,
    String? barcodeSymbology,
    bool? waterProofGhsCompliance,
  }) {
    return ColorWorksLabelSpec(
      formFactor: formFactor ?? this.formFactor,
      labelWidthMm: labelWidthMm ?? this.labelWidthMm,
      labelHeightMm: labelHeightMm ?? this.labelHeightMm,
      gapBetweenLabelsMm: gapBetweenLabelsMm ?? this.gapBetweenLabelsMm,
      dispenseMode: dispenseMode ?? this.dispenseMode,
      barcodeData: barcodeData ?? this.barcodeData,
      barcodeSymbology: barcodeSymbology ?? this.barcodeSymbology,
      waterProofGhsCompliance: waterProofGhsCompliance ?? this.waterProofGhsCompliance,
    );
  }

  Map<String, dynamic> toJson() => {
    'formFactor': formFactor.name,
    'labelWidthMm': labelWidthMm,
    'labelHeightMm': labelHeightMm,
    'gapBetweenLabelsMm': gapBetweenLabelsMm,
    'dispenseMode': dispenseMode.name,
    'barcodeData': barcodeData,
    'barcodeSymbology': barcodeSymbology,
    'waterProofGhsCompliance': waterProofGhsCompliance,
  };
}

// ============================================================================
// 8. TM-Series POS Thermal Receipt Module Models
// ============================================================================

/// Width standard for thermal POS receipt printers.
enum ReceiptPaperWidth {
  /// Standard 80 mm thermal paper (typically 42 or 48 characters per line).
  width80mm,

  /// Compact 58 mm thermal paper (typically 32 characters per line).
  width58mm,
}

/// Specifications for shop counter receipt printing on TM-series printers.
class ShopReceiptSpec {
  final ReceiptPaperWidth paperWidth;
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String invoiceNumber;
  final DateTime timestamp;
  final String cashierName;
  final String customerName;
  final List<Map<String, dynamic>> lineItems;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double grandTotal;
  final String paymentMethod;
  final String? qrCodePayload;
  final bool autoCutPaper;
  final bool openCashDrawer;

  const ShopReceiptSpec({
    this.paperWidth = ReceiptPaperWidth.width80mm,
    this.shopName = 'Print Helper Commercial Copy Center',
    this.shopAddress = '142 High Level Road, Nugegoda, Sri Lanka',
    this.shopPhone = '+94 11 282 5590',
    this.invoiceNumber = 'INV-2026-1049',
    required this.timestamp,
    this.cashierName = 'Operator 01',
    this.customerName = 'Walk-in Customer',
    this.lineItems = const [],
    this.subtotal = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.grandTotal = 0.0,
    this.paymentMethod = 'Cash',
    this.qrCodePayload,
    this.autoCutPaper = true,
    this.openCashDrawer = false,
  });

  /// Maximum column character width based on paper size.
  int get columnsCount => paperWidth == ReceiptPaperWidth.width80mm ? 48 : 32;

  ShopReceiptSpec copyWith({
    ReceiptPaperWidth? paperWidth,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? invoiceNumber,
    DateTime? timestamp,
    String? cashierName,
    String? customerName,
    List<Map<String, dynamic>>? lineItems,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    double? grandTotal,
    String? paymentMethod,
    String? qrCodePayload,
    bool? autoCutPaper,
    bool? openCashDrawer,
  }) {
    return ShopReceiptSpec(
      paperWidth: paperWidth ?? this.paperWidth,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopPhone: shopPhone ?? this.shopPhone,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      timestamp: timestamp ?? this.timestamp,
      cashierName: cashierName ?? this.cashierName,
      customerName: customerName ?? this.customerName,
      lineItems: lineItems ?? this.lineItems,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      qrCodePayload: qrCodePayload ?? this.qrCodePayload,
      autoCutPaper: autoCutPaper ?? this.autoCutPaper,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
    );
  }

  Map<String, dynamic> toJson() => {
    'paperWidth': paperWidth.name,
    'shopName': shopName,
    'invoiceNumber': invoiceNumber,
    'timestamp': timestamp.toIso8601String(),
    'grandTotal': grandTotal,
    'autoCutPaper': autoCutPaper,
  };
}

// ============================================================================
// 9. Hardware Support & Gating Rules
// ============================================================================

/// Evaluates whether a printer model supports specific specialty modules.
///
/// Priority rule: Live hardware detection (Print Schema, IPP, SNMP) ALWAYS
/// overrides database entries.
class SpecialtyCapabilityGate {
  /// Evaluates which specialty modules are permitted for a given printer.
  static Set<SpecialtyModuleType> evaluateSupportedModules({
    required String printerName,
    required bool supportsCdDvdDirect,
    required bool supportsPvcCardTray,
    required bool supportsRollCutter,
    required bool supportsSublimation,
    required bool supportsLabelMedia,
    required bool supportsPosReceipt,
    required double maxThicknessLimitMm,
  }) {
    final modules = <SpecialtyModuleType>{};

    // Passport sheets work on any printer that can print A4 or 4x6 photo paper
    modules.add(SpecialtyModuleType.passportPhotoSheet);

    if (supportsCdDvdDirect) {
      modules.add(SpecialtyModuleType.cdDvdDisc);
    }

    if (supportsPvcCardTray) {
      modules.add(SpecialtyModuleType.pvcIdCard);
    }

    if (supportsRollCutter) {
      modules.add(SpecialtyModuleType.rollCutter);
    }

    if (supportsSublimation) {
      modules.add(SpecialtyModuleType.dyeSublimation);
    }

    if (supportsLabelMedia) {
      modules.add(SpecialtyModuleType.colorWorksLabel);
    }

    if (supportsPosReceipt) {
      modules.add(SpecialtyModuleType.shopReceipt);
    }

    // Rigid media path is unlocked if printer can handle >= 0.6 mm
    if (maxThicknessLimitMm >= 0.6) {
      modules.add(SpecialtyModuleType.rigidMedia);
    }

    return modules;
  }
}
