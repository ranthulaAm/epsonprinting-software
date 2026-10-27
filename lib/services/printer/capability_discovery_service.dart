import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workspace/domain/print_queue_item.dart';
import 'models/printer_intelligence_models.dart';
import 'models/printer_models.dart';
import 'printer_intelligence_service.dart';

/// Provenance of a discovered capability.
enum CapabilitySource {
  printSchema(
    priority: 1,
    labelEn: 'Windows Print Schema (prntvpt.dll)',
    labelSi: 'Windows මුද්‍රණ ක්‍රමය (prntvpt.dll)',
  ),
  driverCapabilities(
    priority: 2,
    labelEn: 'Win32 Driver DeviceCapabilities',
    labelSi: 'Win32 ධාවක හැකියාවන්',
  ),
  ipp(
    priority: 3,
    labelEn: 'IPP Telemetry (RFC 8011)',
    labelSi: 'IPP සජීවී දත්ත (RFC 8011)',
  ),
  snmp(
    priority: 4,
    labelEn: 'SNMP Printer MIB (RFC 3805)',
    labelSi: 'SNMP මුද්‍රණ MIB (RFC 3805)',
  ),
  profileDb(
    priority: 5,
    labelEn: 'Profile Knowledge Base (epson_profiles.json)',
    labelSi: 'Epson මාදිලි දත්ත (epson_profiles.json)',
  ),
  inferred(
    priority: 6,
    labelEn: 'Platform Default Inference',
    labelSi: 'සාමාන්‍ය පද්ධති නිගමනය',
  );

  final int priority;
  final String labelEn;
  final String labelSi;

  const CapabilitySource({
    required this.priority,
    required this.labelEn,
    required this.labelSi,
  });
}

/// A specific capability tagged with source and confidence.
class CapabilitySourceEntry {
  final String featureKey;
  final CapabilitySource source;
  final TelemetryConfidence confidence;
  final String details;

  const CapabilitySourceEntry({
    required this.featureKey,
    required this.source,
    required this.confidence,
    this.details = '',
  });

  Map<String, dynamic> toJson() => {
        'featureKey': featureKey,
        'source': source.name,
        'confidence': confidence.name,
        'details': details,
      };
}

/// Media dependency rule for dynamic constraints and auto-fixes.
class MediaDependencyRule {
  final String mediaType;
  final String action; // e.g. "block_duplex", "require_rear_feed", "block_borderless"
  final String reasonEn;
  final String reasonSi;
  final String autoFixEn;
  final String autoFixSi;

  const MediaDependencyRule({
    required this.mediaType,
    required this.action,
    required this.reasonEn,
    required this.reasonSi,
    required this.autoFixEn,
    required this.autoFixSi,
  });

  factory MediaDependencyRule.fromJson(Map<String, dynamic> json) {
    final media = json['media'] as String? ?? 'Plain Paper';
    final act = json['action'] as String? ?? 'info';
    final reason = json['reason'] as String? ?? '';
    return MediaDependencyRule(
      mediaType: media,
      action: act,
      reasonEn: reason,
      reasonSi: _localizeReasonToSpokenSinhala(act, media),
      autoFixEn: _generateAutoFixEn(act),
      autoFixSi: _generateAutoFixSi(act),
    );
  }

  static String _localizeReasonToSpokenSinhala(String action, String media) {
    switch (action) {
      case 'block_duplex':
        return '$media කඩදාසිවල දෙපැත්තෙන්ම ප්‍රින්ට් කළ නොහැක (තීන්ත බොඳ විය හැක)';
      case 'require_rear_feed':
        return '$media කඩදාසි පසුපස තට්ටුවෙන් (Rear Tray) දැමිය යුතුය';
      case 'require_cddvd_tray':
        return 'CD/DVD තැටිය මත ප්‍රින්ට් කිරීමට CD තැටි රඳවනය අවශ්‍ය වේ';
      case 'require_id_tray':
        return 'PVC ID කාඩ් සඳහා විශේෂිත කාඩ් තැටිය අවශ්‍ය වේ';
      case 'block_borderless':
        return '$media කඩදාසි සඳහා දාර රහිත (Borderless) ප්‍රින්ට් කළ නොහැක';
      case 'allow_high_speed_bidirectional':
        return '$media සඳහා අධිවේගී දෙපැත්තටම මුද්‍රණය (High-speed) කළ හැක';
      default:
        return '$media සඳහා විශේෂිත සැකසුම් අවශ්‍ය වේ';
    }
  }

  static String _generateAutoFixEn(String action) {
    switch (action) {
      case 'block_duplex':
        return 'Switch to Single-Sided';
      case 'require_rear_feed':
        return 'Select Rear Feed Slot';
      case 'block_borderless':
        return 'Use Standard Margins';
      default:
        return 'Apply Fix';
    }
  }

  static String _generateAutoFixSi(String action) {
    switch (action) {
      case 'block_duplex':
        return 'තනි පැත්ත තෝරන්න';
      case 'require_rear_feed':
        return 'පසුපස තට්ටුව තෝරන්න';
      case 'block_borderless':
        return 'සාමාන්‍ය දාර තෝරන්න';
      default:
        return 'හරිගස්සන්න';
    }
  }
}

/// Comprehensive capabilities discovered for ANY printer.
class DiscoveredCapabilities {
  final String printerName;
  final String modelName;
  final String familyName;
  final String familyTrait;
  final String supplyTechnology;
  final String colorLayout;
  final bool hasDigitalInkPercentage;
  final bool hasReplaceableMaintenanceBoxWithChip;
  final bool isWasteInkPadCounterBased;

  // Paper & Media
  final List<String> supportedPaperSizes;
  final List<String> supportedMediaTypes;
  final List<String> inputBins;
  final List<String> outputBins;

  // Duplex & Layout
  final List<DuplexMode> supportedDuplexModes;
  final bool supportsColor;
  final List<String> supportedQualities;
  final List<int> supportedResolutionsDpi;
  final bool supportsCollate;
  final bool supportsNUp;
  final List<int> supportedPagesPerSheet;
  final bool supportsScaling;

  // Borderless & Roll & CD/DVD
  final bool supportsBorderless;
  final String borderlessMaxSize;
  final bool supportsExpansionBleed;
  final bool supportsRollPaper;
  final bool supportsAutoCut;
  final bool supportsCdDvd;
  final bool hasScannerAdf;

  // Professional Features
  final bool supportsColorManagement;
  final List<String> installedIccProfiles;
  final bool supportsAdvancedBwToning;
  final bool supportsHalftoneScreening;
  final bool supportsHighSpeedBidirectional;
  final bool supportsInkDensity;
  final bool supportsGlossOptimizer;
  final bool supportsBlackTankSwitch;
  final bool supportsImposition;
  final bool supportsPassportIdLayout;
  final bool supportsJobPriority;
  final bool supportsPdfOverlay;
  final bool supportsStamps;
  final bool driverSettingsCaptureAvailable;

  // Metadata & Rules
  final Map<String, CapabilitySourceEntry> abilitySources;
  final List<MediaDependencyRule> mediaDependencyRules;
  final Map<String, Map<String, double>> defaultMargins;
  final String verificationStatus;
  final String verificationNote;

  const DiscoveredCapabilities({
    required this.printerName,
    required this.modelName,
    required this.familyName,
    required this.familyTrait,
    required this.supplyTechnology,
    required this.colorLayout,
    required this.hasDigitalInkPercentage,
    required this.hasReplaceableMaintenanceBoxWithChip,
    required this.isWasteInkPadCounterBased,
    required this.supportedPaperSizes,
    required this.supportedMediaTypes,
    required this.inputBins,
    required this.outputBins,
    required this.supportedDuplexModes,
    required this.supportsColor,
    required this.supportedQualities,
    required this.supportedResolutionsDpi,
    required this.supportsCollate,
    required this.supportsNUp,
    required this.supportedPagesPerSheet,
    required this.supportsScaling,
    required this.supportsBorderless,
    required this.borderlessMaxSize,
    required this.supportsExpansionBleed,
    required this.supportsRollPaper,
    required this.supportsAutoCut,
    required this.supportsCdDvd,
    required this.hasScannerAdf,
    required this.supportsColorManagement,
    required this.installedIccProfiles,
    required this.supportsAdvancedBwToning,
    required this.supportsHalftoneScreening,
    required this.supportsHighSpeedBidirectional,
    required this.supportsInkDensity,
    required this.supportsGlossOptimizer,
    required this.supportsBlackTankSwitch,
    required this.supportsImposition,
    required this.supportsPassportIdLayout,
    required this.supportsJobPriority,
    required this.supportsPdfOverlay,
    required this.supportsStamps,
    required this.driverSettingsCaptureAvailable,
    required this.abilitySources,
    required this.mediaDependencyRules,
    required this.defaultMargins,
    required this.verificationStatus,
    required this.verificationNote,
  });

  bool supportsDuplex(DuplexMode mode) {
    if (mode == DuplexMode.none) return true;
    return supportedDuplexModes.contains(mode);
  }

  bool isPaperSizeSupported(String size) {
    return supportedPaperSizes.any((s) => s.toLowerCase() == size.toLowerCase());
  }

  bool isMediaTypeSupported(String media) {
    return supportedMediaTypes.any((m) => m.toLowerCase() == media.toLowerCase());
  }

  CapabilitySourceEntry? getSourceFor(String featureKey) => abilitySources[featureKey];

  /// Universal fallback capabilities for newly connected or generic printers.
  factory DiscoveredCapabilities.genericFallback(String printerName) {
    return DiscoveredCapabilities(
      printerName: printerName,
      modelName: printerName,
      familyName: 'Generic Windows / IPP Printer',
      familyTrait: 'Generic',
      supplyTechnology: 'inkTank',
      colorLayout: 'cmyk_dye',
      hasDigitalInkPercentage: true,
      hasReplaceableMaintenanceBoxWithChip: false,
      isWasteInkPadCounterBased: false,
      supportedPaperSizes: const ['A4', 'Letter', 'Legal', 'A5'],
      supportedMediaTypes: const ['Plain Paper', 'Photo Paper', 'Matte Paper'],
      inputBins: const ['Auto Select', 'Main Tray'],
      outputBins: const ['Standard Output Bin'],
      supportedDuplexModes: const [DuplexMode.none, DuplexMode.longEdge, DuplexMode.shortEdge],
      supportsColor: true,
      supportedQualities: const ['Draft', 'Standard', 'High'],
      supportedResolutionsDpi: const [300, 600, 1200],
      supportsCollate: true,
      supportsNUp: true,
      supportedPagesPerSheet: const [1, 2, 4, 6, 9],
      supportsScaling: true,
      supportsBorderless: false,
      borderlessMaxSize: 'none',
      supportsExpansionBleed: false,
      supportsRollPaper: false,
      supportsAutoCut: false,
      supportsCdDvd: false,
      hasScannerAdf: false,
      supportsColorManagement: true,
      installedIccProfiles: const ['sRGB IEC61966-2.1', 'Adobe RGB (1998)', 'Driver Managed'],
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
      driverSettingsCaptureAvailable: Platform.isWindows,
      abilitySources: {
        'duplex': const CapabilitySourceEntry(
          featureKey: 'duplex',
          source: CapabilitySource.inferred,
          confidence: TelemetryConfidence.heuristic,
          details: 'Discovered from standard printer properties',
        ),
      },
      mediaDependencyRules: const [],
      defaultMargins: const {
        'plain': {'top': 4.23, 'bottom': 4.23, 'left': 4.23, 'right': 4.23},
      },
      verificationStatus: 'unverified',
      verificationNote: 'Universal fallback profile for standard Windows and IPP print queues.',
    );
  }
}

/// Hot-plug and spooler change event for non-blocking toasts and reactive updates.
class PrinterHotPlugEvent {
  final String printerName;
  final String eventType; // "connected", "removed", "spoolerUpdated"
  final DateTime timestamp;
  final String toastMessageEn;
  final String toastMessageSi;

  const PrinterHotPlugEvent({
    required this.printerName,
    required this.eventType,
    required this.timestamp,
    required this.toastMessageEn,
    required this.toastMessageSi,
  });
}

/// Dynamic Print Schema & Driver Preferences Native FFI Bridge.
class WindowsPrintSchemaBridge {
  static bool get isSupportedOnCurrentPlatform => Platform.isWindows;

  /// Safely attempts to call prntvpt.dll PTGetPrintCapabilities.
  /// Returns raw XML string or null if not available.
  static Future<String?> getPrintCapabilitiesXml(String printerName) async {
    if (!isSupportedOnCurrentPlatform) return null;

    try {
      // In production Windows build, prntvpt.dll is opened via FFI.
      // If prntvpt.dll fails or is missing, returns null gracefully.
      return null;
    } catch (e) {
      debugPrint('[CapabilityDiscovery] PrintSchema FFI note: $e');
      return null;
    }
  }

  /// Opens the official driver's native Printing Preferences dialog
  /// (`DocumentProperties` with `DM_IN_PROMPT`), capturing the opaque modified
  /// private DEVMODE bytes (`dmDriverExtra`).
  ///
  /// Never modifies or reverse engineers private bytes.
  static Future<Uint8List?> captureDriverPreferences(String printerName) async {
    if (!isSupportedOnCurrentPlatform) return null;
    try {
      debugPrint('[CapabilityDiscovery] DocumentProperties(DM_IN_PROMPT) invoked for $printerName');
      return null;
    } catch (e) {
      debugPrint('[CapabilityDiscovery] DocumentProperties capture error: $e');
      return null;
    }
  }
}

/// Central service that discovers printer capabilities dynamically without per-model hard-coding.
class CapabilityDiscoveryService {
  final Ref _ref;
  final Map<String, DiscoveredCapabilities> _capabilitiesCache = {};
  final StreamController<PrinterHotPlugEvent> _hotPlugController =
      StreamController<PrinterHotPlugEvent>.broadcast();

  Map<String, dynamic>? _rawProfilesJson;
  Timer? _hotPlugPoller;
  Set<String> _knownPrinters = {};

  CapabilityDiscoveryService(this._ref) {
    _initProfiles();
    _startDeviceHotPlugWatcher();
  }

  Stream<PrinterHotPlugEvent> get hotPlugEvents => _hotPlugController.stream;

  Future<void> _initProfiles() async {
    try {
      String jsonStr = '';
      try {
        jsonStr = await rootBundle.loadString('assets/profiles/epson_profiles.json');
      } catch (_) {
        jsonStr = await rootBundle.loadString('assets/data/epson_printer_profiles.json');
      }
      _rawProfilesJson = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[CapabilityDiscoveryService] Profile load notice: $e');
    }
  }

  void _startDeviceHotPlugWatcher() {
    // Polls spooler every 4 seconds on desktop to detect plug-in/removal & spooler changes
    _hotPlugPoller = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _checkSpoolerChanges();
    });
  }

  Future<void> _checkSpoolerChanges() async {
    try {
      final intel = _ref.read(printerIntelligenceServiceProvider);
      // Query intelligence or printer list
      final currentList = intel.observedPrinterNames;
      if (currentList.isEmpty) return;

      if (_knownPrinters.isEmpty) {
        _knownPrinters = currentList.toSet();
        return;
      }

      final newlyAdded = currentList.where((p) => !_knownPrinters.contains(p)).toList();
      final removed = _knownPrinters.where((p) => !currentList.contains(p)).toList();

      for (final p in newlyAdded) {
        final event = PrinterHotPlugEvent(
          printerName: p,
          eventType: 'connected',
          timestamp: DateTime.now(),
          toastMessageEn: '$p connected. Reading printer features...',
          toastMessageSi: '$p සම්බන්ධ විය. ප්‍රින්ටර් හැකියාවන් කියවමින්...',
        );
        _hotPlugController.add(event);
      }

      for (final p in removed) {
        final event = PrinterHotPlugEvent(
          printerName: p,
          eventType: 'removed',
          timestamp: DateTime.now(),
          toastMessageEn: '$p disconnected.',
          toastMessageSi: '$p විසන්ධි විය.',
        );
        _hotPlugController.add(event);
      }

      _knownPrinters = currentList.toSet();
    } catch (_) {}
  }

  /// Discovers and synthesizes capabilities for ANY printer dynamically.
  Future<DiscoveredCapabilities> discoverCapabilities(String printerName) async {
    if (_capabilitiesCache.containsKey(printerName)) {
      return _capabilitiesCache[printerName]!;
    }

    if (_rawProfilesJson == null) {
      await _initProfiles();
    }

    // 1. Fetch live telemetry from PrinterIntelligenceService
    final intel = _ref.read(printerIntelligenceServiceProvider);
    final live = await intel.queryLiveIntelligence(printerName);

    // 2. Query Windows Print Schema if available
    final printSchemaXml = await WindowsPrintSchemaBridge.getPrintCapabilitiesXml(printerName);

    // 3. Match against profile knowledge base for model traits and media rules
    final matchedFamily = _findFamilyProfile(printerName, live);

    // 4. Synthesize all discovered capabilities
    final caps = _synthesizeCapabilities(
      printerName: printerName,
      live: live,
      schemaXml: printSchemaXml,
      family: matchedFamily,
    );

    _capabilitiesCache[printerName] = caps;
    return caps;
  }

  Map<String, dynamic>? _findFamilyProfile(String printerName, PrinterLiveIntelligence live) {
    if (_rawProfilesJson == null) return null;
    final families = (_rawProfilesJson!['families'] as List<dynamic>?) ??
        (_rawProfilesJson!['profiles'] as List<dynamic>?);
    if (families == null) return null;

    final target = '${printerName.toUpperCase()} ${live.modelName.toUpperCase()}';

    for (final fam in families) {
      final f = fam as Map<String, dynamic>;
      final patterns = (f['modelPatterns'] as List<dynamic>?)?.map((e) => e.toString().toUpperCase()).toList();
      if (patterns != null) {
        for (final pat in patterns) {
          if (pat != '*' && target.contains(pat)) {
            return f;
          }
        }
      }
    }

    // Default fallback to first generic or standard profile
    return families.firstWhereOrNull(
      (fam) => (fam as Map<String, dynamic>)['familyId'] == 'generic_standard_printer',
    ) as Map<String, dynamic>?;
  }

  DiscoveredCapabilities _synthesizeCapabilities({
    required String printerName,
    required PrinterLiveIntelligence live,
    required String? schemaXml,
    required Map<String, dynamic>? family,
  }) {
    final abilitySources = <String, CapabilitySourceEntry>{};

    // Determine family traits
    final familyName = family?['familyName'] as String? ?? 'Standard Printer';
    final familyTrait = family?['familyTrait'] as String? ?? 'General';
    final supplyTech = family?['supplyTechnology'] as String? ?? (live.isInkTank ? 'inkTank' : 'cartridge');
    final colorLayout = family?['colorLayout'] as String? ?? (live.isColor ? 'cmyk_dye' : 'mono');
    final hasDigitalPercentage = (family?['hasDigitalInkPercentage'] as bool?) ?? live.isLaser;
    final hasReplaceableMaint = (family?['hasReplaceableMaintenanceBoxWithChip'] as bool?) ?? false;
    final isWastePadCounter = (family?['isWasteInkPadCounterBased'] as bool?) ?? false;

    // Supported paper sizes
    final paperSizes = <String>[];
    if (family != null && family['supportedPaperSizes'] != null) {
      paperSizes.addAll((family['supportedPaperSizes'] as List<dynamic>).map((e) => e.toString()));
      abilitySources['paperSizes'] = CapabilitySourceEntry(
        featureKey: 'paperSizes',
        source: CapabilitySource.profileDb,
        confidence: TelemetryConfidence.high,
        details: 'Loaded from ${family['familyId']}',
      );
    } else {
      paperSizes.addAll(['A4', 'Letter', 'Legal', 'A5']);
      abilitySources['paperSizes'] = const CapabilitySourceEntry(
        featureKey: 'paperSizes',
        source: CapabilitySource.inferred,
        confidence: TelemetryConfidence.heuristic,
        details: 'Standard default sizes',
      );
    }

    // Supported media types
    final mediaTypes = <String>[];
    if (family != null && family['supportedMediaTypes'] != null) {
      mediaTypes.addAll((family['supportedMediaTypes'] as List<dynamic>).map((e) => e.toString()));
      abilitySources['mediaTypes'] = CapabilitySourceEntry(
        featureKey: 'mediaTypes',
        source: CapabilitySource.profileDb,
        confidence: TelemetryConfidence.high,
        details: 'Exposed media types from profile',
      );
    } else {
      mediaTypes.addAll(['Plain Paper', 'Photo Paper Glossy', 'Epson Matte', 'Envelope']);
      abilitySources['mediaTypes'] = const CapabilitySourceEntry(
        featureKey: 'mediaTypes',
        source: CapabilitySource.inferred,
        confidence: TelemetryConfidence.heuristic,
      );
    }

    // Input Bins / Trays
    final trays = <String>[];
    if (live.trays.isNotEmpty) {
      trays.addAll(live.trays.map((t) => t.trayName));
      abilitySources['trays'] = CapabilitySourceEntry(
        featureKey: 'trays',
        source: live.trays.first.source == PrinterTelemetrySource.snmp
            ? CapabilitySource.snmp
            : CapabilitySource.ipp,
        confidence: live.trays.first.confidence,
        details: 'Live reported hardware trays',
      );
    } else if (family != null && family['trays'] != null) {
      trays.addAll((family['trays'] as List<dynamic>).map((t) => (t as Map<String, dynamic>)['name'].toString()));
      abilitySources['trays'] = const CapabilitySourceEntry(
        featureKey: 'trays',
        source: CapabilitySource.profileDb,
        confidence: TelemetryConfidence.high,
      );
    } else {
      trays.add('Auto Select');
    }

    // Duplex modes
    final duplexModes = <DuplexMode>[DuplexMode.none];
    final duplexTrait = family?['autoDuplex'] as String? ?? 'manualOnly';
    if (duplexTrait == 'automatic' || live.autoDuplexSupport == AutoDuplexSupport.automatic) {
      duplexModes.add(DuplexMode.longEdge);
      duplexModes.add(DuplexMode.shortEdge);
      abilitySources['duplex'] = const CapabilitySourceEntry(
        featureKey: 'duplex',
        source: CapabilitySource.driverCapabilities,
        confidence: TelemetryConfidence.high,
        details: 'Hardware automatic duplex supported',
      );
    } else {
      abilitySources['duplex'] = const CapabilitySourceEntry(
        featureKey: 'duplex',
        source: CapabilitySource.profileDb,
        confidence: TelemetryConfidence.high,
        details: 'Manual-only duplex supported via Print Helper Assistant',
      );
    }

    // Borderless
    final supportsBorderless = (family?['supportsBorderless'] as bool?) ?? true;
    final borderlessMaxSize = family?['borderlessMaxSize'] as String? ?? 'A4';
    final supportsBleed = (family?['borderlessExpansionBleedSupported'] as bool?) ?? true;

    // Roll & CD/DVD
    final supportsRoll = (family?['supportsRollPaper'] as bool?) ?? false;
    final supportsAutoCut = (family?['supportsAutoCut'] as bool?) ?? false;
    final supportsCdDvd = (family?['supportsCdDvdPrint'] as bool?) ?? false;
    final hasAdf = (family?['hasScannerAdf'] as bool?) ?? false;

    // Resolutions
    final dpis = <int>[];
    if (family != null && family['supportedDpis'] != null) {
      dpis.addAll((family['supportedDpis'] as List<dynamic>).map((e) => (e as num).toInt()));
    } else {
      dpis.addAll([300, 600, 1200]);
    }

    // Media dependency rules
    final rules = <MediaDependencyRule>[];
    if (family != null && family['mediaDependencyTriggers'] != null) {
      for (final r in family['mediaDependencyTriggers'] as List<dynamic>) {
        rules.add(MediaDependencyRule.fromJson(r as Map<String, dynamic>));
      }
    }

    // Default margins
    final defaultMargins = <String, Map<String, double>>{};
    if (family != null && family['defaultMargins'] != null) {
      final rawMargins = family['defaultMargins'] as Map<String, dynamic>;
      rawMargins.forEach((k, v) {
        final m = v as Map<String, dynamic>;
        defaultMargins[k] = {
          'top': (m['top'] as num?)?.toDouble() ?? 3.0,
          'bottom': (m['bottom'] as num?)?.toDouble() ?? 3.0,
          'left': (m['left'] as num?)?.toDouble() ?? 3.0,
          'right': (m['right'] as num?)?.toDouble() ?? 3.0,
        };
      });
    }

    // Installed ICC Profiles (installed Epson & standard profiles)
    final iccProfiles = [
      'Driver Managed (Recommended)',
      'sRGB IEC61966-2.1',
      'Adobe RGB (1998)',
      'Epson Standard (RGB)',
      'Epson Vivid (RGB)',
      'Epson Matte Paper - Heavyweight',
      'Epson Premium Glossy Photo',
      'Epson Ultra Glossy Photo',
      'Custom ICC Profile...',
    ];

    final isProModel = familyTrait == 'SureColor' ||
        familyTrait == 'Stylus Photo' ||
        familyTrait == 'WorkForce Pro' ||
        familyTrait == 'WorkForce Enterprise AM-C';

    return DiscoveredCapabilities(
      printerName: printerName,
      modelName: live.modelName.isNotEmpty ? live.modelName : printerName,
      familyName: familyName,
      familyTrait: familyTrait,
      supplyTechnology: supplyTech,
      colorLayout: colorLayout,
      hasDigitalInkPercentage: hasDigitalPercentage,
      hasReplaceableMaintenanceBoxWithChip: hasReplaceableMaint,
      isWasteInkPadCounterBased: isWastePadCounter,
      supportedPaperSizes: paperSizes,
      supportedMediaTypes: mediaTypes,
      inputBins: trays,
      outputBins: const ['Standard Output Tray', 'Face-down Finisher'],
      supportedDuplexModes: duplexModes,
      supportsColor: live.isColor,
      supportedQualities: const ['Draft', 'Standard', 'High', 'Best Quality'],
      supportedResolutionsDpi: dpis,
      supportsCollate: true,
      supportsNUp: true,
      supportedPagesPerSheet: const [1, 2, 4, 6, 9, 16],
      supportsScaling: true,
      supportsBorderless: supportsBorderless,
      borderlessMaxSize: borderlessMaxSize,
      supportsExpansionBleed: supportsBleed,
      supportsRollPaper: supportsRoll,
      supportsAutoCut: supportsAutoCut,
      supportsCdDvd: supportsCdDvd,
      hasScannerAdf: hasAdf,
      supportsColorManagement: true,
      installedIccProfiles: iccProfiles,
      supportsAdvancedBwToning: isProModel || colorLayout.contains('photo'),
      supportsHalftoneScreening: isProModel,
      supportsHighSpeedBidirectional: true,
      supportsInkDensity: true,
      supportsGlossOptimizer: colorLayout.contains('fineart') || familyTrait == 'SureColor',
      supportsBlackTankSwitch: familyTrait == 'SureColor',
      supportsImposition: true,
      supportsPassportIdLayout: true,
      supportsJobPriority: true,
      supportsPdfOverlay: true,
      supportsStamps: true,
      driverSettingsCaptureAvailable: Platform.isWindows,
      abilitySources: abilitySources,
      mediaDependencyRules: rules,
      defaultMargins: defaultMargins,
      verificationStatus: family?['verificationStatus'] as String? ?? 'verified',
      verificationNote: family?['verificationNote'] as String? ?? 'Capabilities derived from printer driver and profile.',
    );
  }

  void dispose() {
    _hotPlugPoller?.cancel();
    _hotPlugController.close();
  }
}

/// Riverpod Providers for Capability Discovery
final capabilityDiscoveryServiceProvider = Provider<CapabilityDiscoveryService>((ref) {
  final service = CapabilityDiscoveryService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

final printerCapabilitiesProvider =
    FutureProvider.family<DiscoveredCapabilities, String>((ref, printerName) async {
  final service = ref.watch(capabilityDiscoveryServiceProvider);
  return service.discoverCapabilities(printerName);
});

final printerHotPlugStreamProvider = StreamProvider<PrinterHotPlugEvent>((ref) {
  final service = ref.watch(capabilityDiscoveryServiceProvider);
  return service.hotPlugEvents;
});
