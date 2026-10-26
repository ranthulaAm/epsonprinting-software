import 'package:flutter/material.dart';
import 'printer_models.dart';

/// Priority-ordered telemetry sources used by `PrinterIntelligenceService`.
///
/// Merge priority strictly follows:
/// 1. `ipp` (RFC 8011 / IPP Everywhere)
/// 2. `snmp` (RFC 3805 Printer MIB & RFC 2790 Host Resources MIB)
/// 3. `windowsSpooler` (Win32 `DeviceCapabilitiesW`, `DEVMODE`, `PRINTER_INFO_2`)
/// 4. `webConfigFallback` (Epson Web Config HTTP/HTTPS status page, strictly with user consent)
/// 5. `epsonProfileDb` (Static model metadata from `assets/data/epson_printer_profiles.json` for static capability bounds only; never used to guess live ink/tray state)
/// 6. `notReported` (Explicitly not reported by any queried source)
enum PrinterTelemetrySource {
  ipp(
    priority: 1,
    shortLabel: 'IPP (RFC 8011)',
    sinhalaLabel: 'IPP (RFC 8011)',
  ),
  snmp(
    priority: 2,
    shortLabel: 'SNMP MIB (RFC 3805)',
    sinhalaLabel: 'SNMP MIB (RFC 3805)',
  ),
  windowsSpooler(
    priority: 3,
    shortLabel: 'Windows Spooler (Win32)',
    sinhalaLabel: 'Windows මුද්‍රණ ධාවකය (Win32)',
  ),
  webConfigFallback(
    priority: 4,
    shortLabel: 'Printer Web Config (Consented)',
    sinhalaLabel: 'මුද්‍රණ වෙබ් පිටුව (අවසර ලත්)',
  ),
  epsonProfileDb(
    priority: 5,
    shortLabel: 'Epson Model Profile',
    sinhalaLabel: 'Epson මාදිලි දත්ත ගොනුව',
  ),
  notReported(
    priority: 99,
    shortLabel: 'Not reported',
    sinhalaLabel: 'වාර්තා නොකෙරේ',
  );

  final int priority;
  final String shortLabel;
  final String sinhalaLabel;

  const PrinterTelemetrySource({
    required this.priority,
    required this.shortLabel,
    required this.sinhalaLabel,
  });
}

/// Confidence flag attached to every field in `PrinterLiveIntelligence`.
enum TelemetryConfidence {
  high(
    labelEn: 'High (Live hardware telemetry)',
    labelSi: 'ඉහළ (සජීවී දෘඪාංග දත්ත)',
  ),
  medium(
    labelEn: 'Medium (Driver / MIB capability table)',
    labelSi: 'මධ්‍යම (ධාවක / MIB දත්ත)',
  ),
  low(
    labelEn: 'Low (Model family profile / Web fallback)',
    labelSi: 'අඩු (මාදිලි පැතිකඩ / වෙබ් පිටුව)',
  ),
  unreported(
    labelEn: 'Not reported by this printer',
    labelSi: 'මෙම මුද්‍රණ යන්ත්‍රය මගින් වාර්තා නොකෙරේ',
  );

  final String labelEn;
  final String labelSi;

  const TelemetryConfidence({
    required this.labelEn,
    required this.labelSi,
  });
}

/// Canonical constant used whenever a printer does not report a telemetry field.
const String kNotReportedByPrinterEn = 'Not reported by this printer';
const String kNotReportedByPrinterSi = 'මෙම මුද්‍රණ යන්ත්‍රය මගින් වාර්තා නොකෙරේ';

/// Wraps every printer telemetry attribute with its provenance (`source`),
/// `confidence` flag, and raw protocol key/OID.
///
/// If `isReported == false` or `value == null`, callers must display
/// `"Not reported by this printer"` and never invent or guess a value.
class SourcedPrinterField<T> {
  final T? value;
  final bool isReported;
  final PrinterTelemetrySource source;
  final TelemetryConfidence confidence;
  final String rawAttributeKey;
  final DateTime? observedAt;

  const SourcedPrinterField({
    required this.value,
    required this.isReported,
    required this.source,
    required this.confidence,
    required this.rawAttributeKey,
    this.observedAt,
  });

  factory SourcedPrinterField.reported({
    required T value,
    required PrinterTelemetrySource source,
    required TelemetryConfidence confidence,
    required String rawAttributeKey,
    DateTime? observedAt,
  }) {
    return SourcedPrinterField<T>(
      value: value,
      isReported: true,
      source: source,
      confidence: confidence,
      rawAttributeKey: rawAttributeKey,
      observedAt: observedAt ?? DateTime.now(),
    );
  }

  factory SourcedPrinterField.notReported([String rawAttributeKey = 'none']) {
    return SourcedPrinterField<T>(
      value: null,
      isReported: false,
      source: PrinterTelemetrySource.notReported,
      confidence: TelemetryConfidence.unreported,
      rawAttributeKey: rawAttributeKey,
      observedAt: null,
    );
  }

  /// Selects between `this` and [fallback] strictly by source priority.
  /// A reported field from a higher-priority source (`priority` number is smaller)
  /// always wins over a lower-priority source.
  SourcedPrinterField<T> mergeWith(SourcedPrinterField<T> fallback) {
    if (isReported && value != null) {
      if (!fallback.isReported || fallback.value == null) {
        return this;
      }
      return source.priority <= fallback.source.priority ? this : fallback;
    }
    return fallback;
  }

  String formatOrNotReported(
    String Function(T val) formatter, {
    bool isSinhala = false,
  }) {
    if (!isReported || value == null) {
      return isSinhala ? kNotReportedByPrinterSi : kNotReportedByPrinterEn;
    }
    return formatter(value as T);
  }
}

/// High-level printer state shown in the Status Header.
enum LivePrinterState {
  ready(
    labelEn: 'Ready',
    labelSi: 'සූදානම් (Ready)',
    color: Color(0xFF16A34A),
    icon: Icons.check_circle_rounded,
  ),
  printing(
    labelEn: 'Printing',
    labelSi: 'මුද්‍රණය වෙමින් පවතී (Printing)',
    color: Color(0xFF2563EB),
    icon: Icons.print_rounded,
  ),
  paused(
    labelEn: 'Paused',
    labelSi: 'තාවකාලිකව නවතා ඇත (Paused)',
    color: Color(0xFFD97706),
    icon: Icons.pause_circle_filled_rounded,
  ),
  offline(
    labelEn: 'Offline',
    labelSi: 'විසන්ධි වී ඇත (Offline)',
    color: Color(0xFF64748B),
    icon: Icons.cloud_off_rounded,
  ),
  error(
    labelEn: 'Attention Required',
    labelSi: 'දෝෂයකි / අවධානය යොමු කරන්න',
    color: Color(0xFFDC2626),
    icon: Icons.error_rounded,
  );

  final String labelEn;
  final String labelSi;
  final Color color;
  final IconData icon;

  const LivePrinterState({
    required this.labelEn,
    required this.labelSi,
    required this.color,
    required this.icon,
  });
}

/// Plain-language translation of an IPP `printer-state-reasons` keyword,
/// SNMP `prtAlertTable` entry, or Win32 `PRINTER_STATUS_*` flag.
class PlainLanguagePrinterProblem {
  final String rawCode;
  final String titleEn;
  final String titleSi;
  final String detailEn;
  final String detailSi;
  final bool isHardStopBlockingError;
  final PrinterTelemetrySource source;
  final TelemetryConfidence confidence;

  const PlainLanguagePrinterProblem({
    required this.rawCode,
    required this.titleEn,
    required this.titleSi,
    required this.detailEn,
    required this.detailSi,
    required this.isHardStopBlockingError,
    required this.source,
    required this.confidence,
  });
}

/// Type of supply marker reported by the printer.
enum SupplyTechnologyKind {
  ink(labelEn: 'Ink', labelSi: 'තීන්ත (Ink)'),
  toner(labelEn: 'Toner', labelSi: 'ටෝනර් (Toner)'),
  maintenanceBox(labelEn: 'Maintenance Box', labelSi: 'නඩත්තු කොටුව (Maintenance Box)'),
  wasteInkPad(labelEn: 'Waste Ink Pad', labelSi: 'අපද්‍රව්‍ය තීන්ත පෑඩය (Waste Ink Pad)');

  final String labelEn;
  final String labelSi;

  const SupplyTechnologyKind({
    required this.labelEn,
    required this.labelSi,
  });
}

/// Qualitative supply status when percentage is or isn't reported.
enum QualitativeSupplyStatus {
  ok(labelEn: 'OK', labelSi: 'හොඳ මට්ටමේ (OK)'),
  low(labelEn: 'Low', labelSi: 'අඩුයි (Low)'),
  empty(labelEn: 'Empty', labelSi: 'අවසන් වී ඇත (Empty)'),
  notReported(
    labelEn: kNotReportedByPrinterEn,
    labelSi: kNotReportedByPrinterSi,
  );

  final String labelEn;
  final String labelSi;

  const QualitativeSupplyStatus({
    required this.labelEn,
    required this.labelSi,
  });
}

/// Represents a single supply marker (Black, Cyan, Magenta, Yellow, Photo Black,
/// Maintenance Box, Waste Ink Pad).
class SupplyMarkerInfo {
  final String name;
  final String colorHex;
  final SupplyTechnologyKind supplyKind;

  /// Exact 0..100 percentage if reported by IPP `marker-levels` or SNMP
  /// `prtMarkerSuppliesLevel` (`>= 0`).
  /// `null` if the printer reports `-3` (some remaining / EcoTank bottle) or `-2` (unknown).
  final SourcedPrinterField<int> levelPercent;

  /// Qualitative state (`OK`, `Low`, `Empty`, `Not reported by this printer`).
  final SourcedPrinterField<QualitativeSupplyStatus> qualitativeStatus;

  /// Low threshold percentage from IPP `marker-low-levels` (typically 10-15%).
  final int lowThresholdPercent;

  /// Estimated pages remaining, populated ONLY when the printer reports both
  /// `prtMarkerSuppliesMaxCapacity` (in sheets/impressions or ISO yield) and a
  /// valid `0..100` level. Always labeled `"estimate"` in the UI.
  final SourcedPrinterField<int> estimatedPagesRemaining;

  const SupplyMarkerInfo({
    required this.name,
    required this.colorHex,
    required this.supplyKind,
    required this.levelPercent,
    required this.qualitativeStatus,
    this.lowThresholdPercent = 15,
    required this.estimatedPagesRemaining,
  });

  bool get isLow =>
      qualitativeStatus.value == QualitativeSupplyStatus.low ||
      (levelPercent.isReported &&
          levelPercent.value != null &&
          levelPercent.value! > 0 &&
          levelPercent.value! <= lowThresholdPercent);

  bool get isEmpty =>
      qualitativeStatus.value == QualitativeSupplyStatus.empty ||
      (levelPercent.isReported &&
          levelPercent.value != null &&
          levelPercent.value! <= 0);

  Color get displayColor {
    final cleaned = colorHex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final parsed = int.tryParse('FF$cleaned', radix: 16);
      if (parsed != null) return Color(parsed);
    }
    final lower = name.toLowerCase();
    if (lower.contains('cyan')) return const Color(0xFF06B6D4);
    if (lower.contains('magenta')) return const Color(0xFFEC4899);
    if (lower.contains('yellow')) return const Color(0xFFEAB308);
    if (lower.contains('photo black')) return const Color(0xFF334155);
    if (lower.contains('maintenance') || lower.contains('waste')) {
      return const Color(0xFF64748B);
    }
    return const Color(0xFF1E293B);
  }
}

/// Paper availability status for a paper size or tray.
enum PaperAvailabilityState {
  loadedNow(
    labelEn: 'Loaded now',
    labelSi: 'දැනට පටවා ඇත (Loaded now)',
    badgeColor: Color(0xFF16A34A),
  ),
  supportedNotLoaded(
    labelEn: 'Supported but not loaded',
    labelSi: 'සහාය දක්වයි, නමුත් දැනට පටවා නැත',
    badgeColor: Color(0xFFD97706),
  ),
  notSupported(
    labelEn: 'Not supported',
    labelSi: 'සහාය නොදක්වයි (Not supported)',
    badgeColor: Color(0xFFDC2626),
  ),
  notReported(
    labelEn: kNotReportedByPrinterEn,
    labelSi: kNotReportedByPrinterSi,
    badgeColor: Color(0xFF64748B),
  );

  final String labelEn;
  final String labelSi;
  final Color badgeColor;

  const PaperAvailabilityState({
    required this.labelEn,
    required this.labelSi,
    required this.badgeColor,
  });
}

/// Per-tray status from IPP `media-col-database`/`media-ready` or SNMP `prtInputTable`.
class PrinterTrayStatusInfo {
  final String trayId;
  final String trayName;
  final SourcedPrinterField<String> loadedPaperSize;
  final SourcedPrinterField<String> loadedMediaType;
  final SourcedPrinterField<int> currentSheets;
  final SourcedPrinterField<int> maxCapacitySheets;
  final PaperAvailabilityState availability;

  const PrinterTrayStatusInfo({
    required this.trayId,
    required this.trayName,
    required this.loadedPaperSize,
    required this.loadedMediaType,
    required this.currentSheets,
    required this.maxCapacitySheets,
    required this.availability,
  });
}

/// Duplex capability classification.
enum DuplexSupportMode {
  automatic(
    labelEn: 'Automatic 2-Sided',
    labelSi: 'ස්වයංක්‍රීය දෙපස මුද්‍රණය (Automatic)',
  ),
  manualOnly(
    labelEn: 'Manual 2-Sided Only (Flip Assistant)',
    labelSi: 'අතින් පිටු පෙරළා දෙපස මුද්‍රණය (Manual)',
  ),
  none(
    labelEn: 'Single-Sided Only',
    labelSi: 'එක් පසෙක පමණයි (None)',
  );

  final String labelEn;
  final String labelSi;

  const DuplexSupportMode({
    required this.labelEn,
    required this.labelSi,
  });
}

/// Updatable Epson or Generic model profile entry loaded from
/// `assets/data/epson_printer_profiles.json`.
class EpsonModelProfile {
  final String familyId;
  final String manufacturer;
  final String familyName;
  final List<String> modelPatterns;
  final String supplyTechnology; // inkTank, inkCartridge, inkPack, toner, autoDetect
  final List<String> expectedMarkers;
  final bool supportsExactInkPercentage;
  final bool supportsMaintenanceBoxPercentage;
  final String autoDuplexDefault; // automatic, manualOnly, autoDetect
  final bool supportsBorderless;
  final String borderlessMaxSize;
  final bool supportsRollPaper;
  final bool supportsCdDvdPrint;
  final String maxOpticalDpi;
  final List<String> supportedPaperSizes;
  final List<String> supportedMediaTypes;
  final List<String> trays;
  final List<String> quirks;

  const EpsonModelProfile({
    required this.familyId,
    required this.manufacturer,
    required this.familyName,
    required this.modelPatterns,
    required this.supplyTechnology,
    required this.expectedMarkers,
    required this.supportsExactInkPercentage,
    required this.supportsMaintenanceBoxPercentage,
    required this.autoDuplexDefault,
    required this.supportsBorderless,
    required this.borderlessMaxSize,
    required this.supportsRollPaper,
    required this.supportsCdDvdPrint,
    required this.maxOpticalDpi,
    required this.supportedPaperSizes,
    required this.supportedMediaTypes,
    required this.trays,
    required this.quirks,
  });

  factory EpsonModelProfile.fromJson(Map<String, dynamic> json) {
    return EpsonModelProfile(
      familyId: json['familyId'] as String? ?? 'unknown',
      manufacturer: json['manufacturer'] as String? ?? 'Generic',
      familyName: json['familyName'] as String? ?? 'Generic Printer',
      modelPatterns:
          (json['modelPatterns'] as List<dynamic>? ?? const []).cast<String>(),
      supplyTechnology: json['supplyTechnology'] as String? ?? 'autoDetect',
      expectedMarkers:
          (json['expectedMarkers'] as List<dynamic>? ?? const []).cast<String>(),
      supportsExactInkPercentage:
          json['supportsExactInkPercentage'] as bool? ?? true,
      supportsMaintenanceBoxPercentage:
          json['supportsMaintenanceBoxPercentage'] as bool? ?? false,
      autoDuplexDefault: json['autoDuplexDefault'] as String? ?? 'autoDetect',
      supportsBorderless: json['supportsBorderless'] as bool? ?? false,
      borderlessMaxSize: json['borderlessMaxSize'] as String? ?? 'None',
      supportsRollPaper: json['supportsRollPaper'] as bool? ?? false,
      supportsCdDvdPrint: json['supportsCdDvdPrint'] as bool? ?? false,
      maxOpticalDpi: json['maxOpticalDpi'] as String? ?? '600x600',
      supportedPaperSizes:
          (json['supportedPaperSizes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      supportedMediaTypes:
          (json['supportedMediaTypes'] as List<dynamic>? ?? const [])
              .cast<String>(),
      trays: (json['trays'] as List<dynamic>? ?? const []).cast<String>(),
      quirks: (json['quirks'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  bool get isEpson => manufacturer.toLowerCase() == 'epson';

  SupplyTechnologyKind get primarySupplyKind {
    if (supplyTechnology == 'toner') {
      return SupplyTechnologyKind.toner;
    }
    return SupplyTechnologyKind.ink;
  }
}

/// Complete merged live intelligence snapshot for a printer.
class PrinterLiveIntelligence {
  final String printerId;
  final String displayName;
  final String modelName;
  final PrinterConnectionType connectionType;
  final String? ipAddress;
  final int? ippPort;
  final int? snmpPort;
  final DateTime fetchedAt;
  final bool userConsentedWebConfig;

  // 1. Status Header & Plain-Language Problems
  final SourcedPrinterField<LivePrinterState> printerState;
  final SourcedPrinterField<List<String>> rawStateReasons;
  final List<PlainLanguagePrinterProblem> activeProblems;

  // 2. Supply Levels
  final SupplyTechnologyKind primarySupplyLabel;
  final SourcedPrinterField<List<SupplyMarkerInfo>> supplies;

  // 3. Paper & Trays
  final SourcedPrinterField<List<String>> supportedPaperSizes;
  final SourcedPrinterField<List<String>> readyPaperSizes;
  final SourcedPrinterField<List<String>> supportedMediaTypes;
  final SourcedPrinterField<List<PrinterTrayStatusInfo>> trays;

  // 4. Capabilities Badges
  final SourcedPrinterField<DuplexSupportMode> duplexSupport;
  final SourcedPrinterField<bool> supportsColor;
  final SourcedPrinterField<bool> supportsBorderless;
  final SourcedPrinterField<String> maxResolutionDpi;
  final SourcedPrinterField<List<String>> supportedOrientations;
  final SourcedPrinterField<List<String>> supportedOutputBins;

  // 5. Maintenance Info
  final SourcedPrinterField<int> lifetimePageCount;
  final SourcedPrinterField<String> firmwareVersion;
  final SourcedPrinterField<String> maintenanceBoxStatus;

  // 6. Matched Epson / Vendor Profile
  final EpsonModelProfile? matchedProfile;

  const PrinterLiveIntelligence({
    required this.printerId,
    required this.displayName,
    required this.modelName,
    required this.connectionType,
    this.ipAddress,
    this.ippPort,
    this.snmpPort,
    required this.fetchedAt,
    this.userConsentedWebConfig = false,
    required this.printerState,
    required this.rawStateReasons,
    required this.activeProblems,
    required this.primarySupplyLabel,
    required this.supplies,
    required this.supportedPaperSizes,
    required this.readyPaperSizes,
    required this.supportedMediaTypes,
    required this.trays,
    required this.duplexSupport,
    required this.supportsColor,
    required this.supportsBorderless,
    required this.maxResolutionDpi,
    required this.supportedOrientations,
    required this.supportedOutputBins,
    required this.lifetimePageCount,
    required this.firmwareVersion,
    required this.maintenanceBoxStatus,
    this.matchedProfile,
  });

  /// Evaluates whether a given paper size (e.g. `"A4"`, `"A3"`, `"Letter"`) is
  /// `"Loaded now"`, `"Supported but not loaded"`, `"Not supported"`, or `"Not reported"`.
  PaperAvailabilityState evaluatePaperSize(String requestedSize) {
    final normReq = _normalizeMediaToken(requestedSize);

    // Check loaded trays first
    if (trays.isReported && trays.value != null) {
      for (final tray in trays.value!) {
        if (tray.loadedPaperSize.isReported &&
            tray.loadedPaperSize.value != null &&
            _normalizeMediaToken(tray.loadedPaperSize.value!) == normReq) {
          return PaperAvailabilityState.loadedNow;
        }
      }
    }

    // Check IPP media-ready
    if (readyPaperSizes.isReported && readyPaperSizes.value != null) {
      final isReady = readyPaperSizes.value!
          .any((s) => _normalizeMediaToken(s) == normReq);
      if (isReady) {
        return PaperAvailabilityState.loadedNow;
      }
    }

    // Check supportedPaperSizes
    if (supportedPaperSizes.isReported && supportedPaperSizes.value != null) {
      final isSupported = supportedPaperSizes.value!
          .any((s) => _normalizeMediaToken(s) == normReq);
      if (isSupported) {
        // If the printer reported ready sizes/trays and it wasn't among them,
        // it is "Supported but not loaded". If the printer has no tray sensors,
        // it is still supported.
        return PaperAvailabilityState.supportedNotLoaded;
      }
      return PaperAvailabilityState.notSupported;
    }

    return PaperAvailabilityState.notReported;
  }

  static String _normalizeMediaToken(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('iso_a4') || lower == 'a4' || lower.startsWith('a4 ')) {
      return 'a4';
    }
    if (lower.contains('iso_a3') || lower == 'a3' || lower.startsWith('a3 ')) {
      return 'a3';
    }
    if (lower.contains('a3+') || lower.contains('super_b')) {
      return 'a3+';
    }
    if (lower.contains('iso_a5') || lower == 'a5' || lower.startsWith('a5 ')) {
      return 'a5';
    }
    if (lower.contains('na_letter') || lower.contains('letter')) {
      return 'letter';
    }
    if (lower.contains('na_legal') || lower.contains('legal')) {
      return 'legal';
    }
    if (lower.contains('4x6') ||
        lower.contains('10x15') ||
        lower.contains('na_index-4x6')) {
      return '4x6';
    }
    if (lower.contains('5x7') || lower.contains('13x18')) {
      return '5x7';
    }
    return lower;
  }
}

/// Severity of a smart pre-print validation check.
enum SmartValidationSeverity {
  readyPass(
    color: Color(0xFF16A34A),
    icon: Icons.check_circle_outline_rounded,
  ),
  infoGuidance(
    color: Color(0xFF2563EB),
    icon: Icons.info_outline_rounded,
  ),
  warningNonBlocking(
    color: Color(0xFFD97706),
    icon: Icons.warning_amber_rounded,
  ),
  hardwareStopError(
    color: Color(0xFFDC2626),
    icon: Icons.error_outline_rounded,
  );

  final Color color;
  final IconData icon;

  const SmartValidationSeverity({
    required this.color,
    required this.icon,
  });
}

/// Automatic one-click fix action offered by Smart Print Validation ("Fix it for me").
enum SmartFixActionKind {
  switchToManualDuplexAssistant,
  switchPaperSizeToLoaded,
  switchMediaTypeToLoadedTray,
  switchColorToGrayscale,
  disableBorderless,
}

class SmartPrintValidationFix {
  final SmartFixActionKind actionKind;
  final String buttonLabelEn;
  final String buttonLabelSi;
  final String? targetPaperSize;
  final String? targetMediaType;

  const SmartPrintValidationFix({
    required this.actionKind,
    required this.buttonLabelEn,
    required this.buttonLabelSi,
    this.targetPaperSize,
    this.targetMediaType,
  });
}

/// Individual check item produced by Smart Print Validation before printing.
class SmartPrintValidationCheck {
  final String id;
  final SmartValidationSeverity severity;
  final String messageEn;
  final String messageSi;
  final PrinterTelemetrySource source;
  final TelemetryConfidence confidence;
  final SmartPrintValidationFix? autoFix;
  final bool blocksSubmission;

  const SmartPrintValidationCheck({
    required this.id,
    required this.severity,
    required this.messageEn,
    required this.messageSi,
    required this.source,
    required this.confidence,
    this.autoFix,
    this.blocksSubmission = false,
  });
}

/// Disabled option explanation for UI controls when a printer explicitly does not
/// support a capability.
class DisabledPrintOptionReason {
  final String optionKey; // e.g., 'autoDuplex', 'color', 'borderless', 'paperSize:A3'
  final String reasonEn;
  final String reasonSi;

  const DisabledPrintOptionReason({
    required this.optionKey,
    required this.reasonEn,
    required this.reasonSi,
  });
}

/// Full report returned by `PrinterIntelligenceService.validatePrintJob(...)`.
class SmartPrintValidationReport {
  final List<SmartPrintValidationCheck> checks;
  final Map<String, DisabledPrintOptionReason> disabledOptions;
  final bool requiresManualDuplexAssistant;

  const SmartPrintValidationReport({
    required this.checks,
    required this.disabledOptions,
    required this.requiresManualDuplexAssistant,
  });

  /// Per user requirements: warn when supplies or trays mismatch, and BLOCK
  /// nothing unless the printer hardware itself is in a hard-stop failure state.
  bool get hasHardBlockingPrinterFailure =>
      checks.any((c) => c.blocksSubmission);

  List<SmartPrintValidationCheck> get fixableChecks =>
      checks.where((c) => c.autoFix != null).toList();
}

/// Binding edge for Manual Duplex Assistant.
enum ManualDuplexFlipEdge {
  longEdge(
    labelEn: 'Long-Edge Binding (Standard Book Flip)',
    labelSi: 'දිගු දාරය දිගේ පෙරළන්න (Long-Edge)',
    instructionEn:
        'Keep the printed stack in the same orientation, flip it over from left to right (like turning a book page), and re-insert into the feed tray.',
    instructionSi:
        'මුද්‍රිත කොළ මිටිය පොතක පිටුවක් පෙරළන ආකාරයට වමේ සිට දකුණට පෙරළා නැවත කඩදාසි තැටියට ඇතුළු කරන්න.',
  ),
  shortEdge(
    labelEn: 'Short-Edge Binding (Calendar / Notepad Flip)',
    labelSi: 'කෙටි දාරය දිගේ පෙරළන්න (Short-Edge)',
    instructionEn:
        'Flip the printed stack end-over-end from top to bottom (like a wall calendar), and re-insert into the feed tray.',
    instructionSi:
        'මුද්‍රිත කොළ මිටිය දින දර්ශනයක් පෙරළන ආකාරයට ඉහළ සිට පහළට පෙරළා නැවත කඩදාසි තැටියට ඇතුළු කරන්න.',
  );

  final String labelEn;
  final String labelSi;
  final String instructionEn;
  final String instructionSi;

  const ManualDuplexFlipEdge({
    required this.labelEn,
    required this.labelSi,
    required this.instructionEn,
    required this.instructionSi,
  });
}

/// Step-by-step plan for the Manual Duplex Assistant when a printer does not
/// have an automatic duplex unit (e.g. Epson EcoTank L3210 / L3250).
class ManualDuplexAssistantPlan {
  final int totalDocumentPages;
  final List<int> step1OddPages;
  final List<int> step3EvenPages;
  final bool needsBlankLastSheetKeepOut;
  final ManualDuplexFlipEdge flipEdge;
  final String trayGuidanceEn;
  final String trayGuidanceSi;

  const ManualDuplexAssistantPlan({
    required this.totalDocumentPages,
    required this.step1OddPages,
    required this.step3EvenPages,
    required this.needsBlankLastSheetKeepOut,
    required this.flipEdge,
    required this.trayGuidanceEn,
    required this.trayGuidanceSi,
  });

  String get oddPagesRangeText => step1OddPages.join(', ');
  String get evenPagesRangeText => step3EvenPages.join(', ');
}
