import 'snmp_printer_mib_models.dart';

/// Connection interface through which printer communicates.
enum PrinterInterfaceType {
  usb,
  wifi,
  ethernet,
  virtual,
}

/// Operational state of a printer in the fleet dashboard.
enum FleetPrinterState {
  ready,
  printing,
  paused,
  paperOut,
  doorOpen,
  error,
  offline,
}

/// Full aggregated card telemetry for an individual printer in the fleet dashboard.
class DashboardPrinterCardData {
  final String id;
  final String name;
  final String modelName;
  final PrinterInterfaceType interfaceType;
  final String? ipAddress;
  final FleetPrinterState state;
  final int activeQueueLength;
  final List<ParsedSnmpSupplyEntry> inkChannels;
  final ParsedSnmpSupplyEntry? maintenanceBox;
  final String? loadedPaperSummary;
  final List<String> specialtyBadges;
  final double lowSupplyThresholdPct;
  final List<PrinterHardwareAlert> activeAlerts;
  final int totalLifePagesCount;

  const DashboardPrinterCardData({
    required this.id,
    required this.name,
    required this.modelName,
    required this.interfaceType,
    this.ipAddress,
    required this.state,
    this.activeQueueLength = 0,
    this.inkChannels = const [],
    this.maintenanceBox,
    this.loadedPaperSummary,
    this.specialtyBadges = const [],
    this.lowSupplyThresholdPct = 15.0,
    this.activeAlerts = const [],
    this.totalLifePagesCount = 0,
  });

  /// True if any ink channel or maintenance box is below threshold or in error.
  bool get hasLowSupplyAlert {
    for (final ink in inkChannels) {
      if (ink.statusType == SnmpSupplyStatusType.lowOrEmpty) return true;
      if (ink.calculatedPercentage != null &&
          ink.calculatedPercentage! <= lowSupplyThresholdPct) {
        return true;
      }
    }
    if (maintenanceBox != null) {
      if (maintenanceBox!.statusType == SnmpSupplyStatusType.lowOrEmpty) return true;
      // Maintenance box percentage is fullness: >= (100 - threshold) is full
      if (maintenanceBox!.calculatedPercentage != null &&
          maintenanceBox!.calculatedPercentage! >= (100.0 - lowSupplyThresholdPct)) {
        return true;
      }
    }
    return false;
  }

  /// Whether printer is physically capable of accepting standard jobs immediately.
  bool get isAvailableForJobs =>
      state == FleetPrinterState.ready || state == FleetPrinterState.printing;

  DashboardPrinterCardData copyWith({
    String? id,
    String? name,
    String? modelName,
    PrinterInterfaceType? interfaceType,
    String? ipAddress,
    FleetPrinterState? state,
    int? activeQueueLength,
    List<ParsedSnmpSupplyEntry>? inkChannels,
    ParsedSnmpSupplyEntry? maintenanceBox,
    String? loadedPaperSummary,
    List<String>? specialtyBadges,
    double? lowSupplyThresholdPct,
    List<PrinterHardwareAlert>? activeAlerts,
    int? totalLifePagesCount,
  }) {
    return DashboardPrinterCardData(
      id: id ?? this.id,
      name: name ?? this.name,
      modelName: modelName ?? this.modelName,
      interfaceType: interfaceType ?? this.interfaceType,
      ipAddress: ipAddress ?? this.ipAddress,
      state: state ?? this.state,
      activeQueueLength: activeQueueLength ?? this.activeQueueLength,
      inkChannels: inkChannels ?? this.inkChannels,
      maintenanceBox: maintenanceBox ?? this.maintenanceBox,
      loadedPaperSummary: loadedPaperSummary ?? this.loadedPaperSummary,
      specialtyBadges: specialtyBadges ?? this.specialtyBadges,
      lowSupplyThresholdPct: lowSupplyThresholdPct ?? this.lowSupplyThresholdPct,
      activeAlerts: activeAlerts ?? this.activeAlerts,
      totalLifePagesCount: totalLifePagesCount ?? this.totalLifePagesCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'modelName': modelName,
    'interfaceType': interfaceType.name,
    'ipAddress': ipAddress,
    'state': state.name,
    'activeQueueLength': activeQueueLength,
    'inkChannels': inkChannels.map((c) => c.toJson()).toList(),
    'maintenanceBox': maintenanceBox?.toJson(),
    'loadedPaperSummary': loadedPaperSummary,
    'specialtyBadges': specialtyBadges,
    'hasLowSupplyAlert': hasLowSupplyAlert,
    'activeAlerts': activeAlerts.map((a) => a.toJson()).toList(),
    'totalLifePagesCount': totalLifePagesCount,
  };
}

// ============================================================================
// Intelligent Job Routing Engine Models
// ============================================================================

/// Job type categorization for intelligent routing.
enum PrintJobClassification {
  documentTextMono,
  documentColor,
  photoBorderless,
  passportPhotoSheet,
  pvcIdCard,
  cdDvdDisc,
  rigidPosterboard,
  rollBanner,
  dyeSublimationTransfer,
  colorLabelRoll,
}

/// Incoming job parameters evaluated by the routing engine.
class JobRoutingRequest {
  final String jobId;
  final String documentTitle;
  final PrintJobClassification classification;
  final bool isColor;
  final int pageCount;
  final String paperSize; // 'A4', 'A3', '4x6', 'CR80', '12cmDisc', etc.
  final bool requiresBorderless;
  final bool requiresDuplex;
  final double mediaThicknessMm;
  final String? preferredPrinterId;

  const JobRoutingRequest({
    required this.jobId,
    required this.documentTitle,
    required this.classification,
    required this.isColor,
    required this.pageCount,
    this.paperSize = 'A4',
    this.requiresBorderless = false,
    this.requiresDuplex = false,
    this.mediaThicknessMm = 0.1,
    this.preferredPrinterId,
  });
}

/// Result of evaluating an incoming job against fleet printers.
class RoutingDecisionResult {
  final String selectedPrinterId;
  final String selectedPrinterName;
  final bool wasReroutedFromPreferred;
  final String? originalPreferredPrinterId;
  final String rationaleSentenceEn;
  final String rationaleSentenceSi;
  final bool requiresOperatorConfirmation;
  final String? confirmationPromptEn;
  final String? confirmationPromptSi;

  const RoutingDecisionResult({
    required this.selectedPrinterId,
    required this.selectedPrinterName,
    this.wasReroutedFromPreferred = false,
    this.originalPreferredPrinterId,
    required this.rationaleSentenceEn,
    required this.rationaleSentenceSi,
    this.requiresOperatorConfirmation = false,
    this.confirmationPromptEn,
    this.confirmationPromptSi,
  });

  Map<String, dynamic> toJson() => {
    'selectedPrinterId': selectedPrinterId,
    'selectedPrinterName': selectedPrinterName,
    'wasRerouted': wasReroutedFromPreferred,
    'originalPreferredPrinterId': originalPreferredPrinterId,
    'rationaleEn': rationaleSentenceEn,
    'rationaleSi': rationaleSentenceSi,
    'requiresConfirmation': requiresOperatorConfirmation,
    'confirmationPromptEn': confirmationPromptEn,
    'confirmationPromptSi': confirmationPromptSi,
  };
}

/// Configurable, editable routing rule with priority.
class FleetRoutingRule {
  final String id;
  final String name;
  final bool isEnabled;
  final int priority; // 1 = highest
  final bool Function(JobRoutingRequest job, DashboardPrinterCardData printer) matcher;
  final String rationaleTemplateEn;
  final String rationaleTemplateSi;

  const FleetRoutingRule({
    required this.id,
    required this.name,
    this.isEnabled = true,
    required this.priority,
    required this.matcher,
    required this.rationaleTemplateEn,
    required this.rationaleTemplateSi,
  });
}

/// Permission guard for Subnet IP Scans.
class SubnetScanPermissionManager {
  static bool _operatorConsentGiven = false;
  static String? _authorizedSubnetCidr;

  static bool get isConsentGiven => _operatorConsentGiven;
  static String? get authorizedSubnetCidr => _authorizedSubnetCidr;

  static void grantConsent(String subnetCidr) {
    _operatorConsentGiven = true;
    _authorizedSubnetCidr = subnetCidr;
  }

  static void revokeConsent() {
    _operatorConsentGiven = false;
    _authorizedSubnetCidr = null;
  }
}
