import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'epson_robust_support_service.dart';
import 'models/printer_intelligence_models.dart';
import 'models/printer_models.dart';

final printerIntelligenceServiceProvider =
    Provider<PrinterIntelligenceService>((ref) {
  final service = PrinterIntelligenceService();
  ref.onDispose(service.dispose);
  return service;
});

typedef _WinspoolDeviceCapabilitiesNative = ffi.Int32 Function(
  ffi.Pointer<Utf16> pDevice,
  ffi.Pointer<Utf16> pPort,
  ffi.Uint16 fwCapability,
  ffi.Pointer<ffi.Void> pOutput,
  ffi.Pointer<ffi.Void> pDevMode,
);
typedef _WinspoolDeviceCapabilitiesDart = int Function(
  ffi.Pointer<Utf16> pDevice,
  ffi.Pointer<Utf16> pPort,
  int fwCapability,
  ffi.Pointer<ffi.Void> pOutput,
  ffi.Pointer<ffi.Void> pDevMode,
);

/// Requested IPP (RFC 8011 / IPP Everywhere) attributes in strict priority #1.
const List<String> kRequestedIppAttributes = <String>[
  'printer-state',
  'printer-state-reasons',
  'marker-names',
  'marker-levels',
  'marker-colors',
  'marker-types',
  'marker-low-levels',
  'media-supported',
  'media-ready',
  'media-col-database',
  'media-type-supported',
  'sides-supported',
  'print-color-mode-supported',
  'printer-resolution-supported',
  'output-bin-supported',
  'printer-alert',
  'printer-firmware-string-version',
  'printer-impressions-completed',
];

/// Standard SNMP Printer MIB (RFC 3805) and Host Resources MIB (RFC 2790) OIDs.
class StandardPrinterMibOids {
  static const String hrPrinterStatus = '1.3.6.1.2.1.25.3.5.1.1.1';
  static const String hrPrinterDetectedErrorState = '1.3.6.1.2.1.25.3.5.1.2.1';
  static const String prtMarkerLifeCount = '1.3.6.1.2.1.43.10.2.1.4.1.1';
  static const String prtMarkerSuppliesDescriptionPrefix =
      '1.3.6.1.2.1.43.11.1.1.6.1.';
  static const String prtMarkerSuppliesMaxCapacityPrefix =
      '1.3.6.1.2.1.43.11.1.1.8.1.';
  static const String prtMarkerSuppliesLevelPrefix =
      '1.3.6.1.2.1.43.11.1.1.9.1.';
  static const String prtInputNamePrefix = '1.3.6.1.2.1.43.8.2.1.18.1.';
  static const String prtInputMediaNamePrefix = '1.3.6.1.2.1.43.8.2.1.12.1.';
  static const String prtInputMediaTypePrefix = '1.3.6.1.2.1.43.8.2.1.19.1.';
  static const String prtInputMaxCapacityPrefix = '1.3.6.1.2.1.43.8.2.1.9.1.';
  static const String prtInputCurrentLevelPrefix = '1.3.6.1.2.1.43.8.2.1.10.1.';
  static const String prtAlertDescriptionPrefix = '1.3.6.1.2.1.43.18.1.1.8.1.';
}

/// Raw IPP telemetry payload returned by the background isolate.
class RawIppTelemetryPayload {
  final bool reachable;
  final int? printerStateEnum; // 3=idle, 4=processing, 5=stopped
  final List<String> stateReasons;
  final List<String> markerNames;
  final List<int> markerLevels;
  final List<String> markerColors;
  final List<String> markerTypes;
  final List<int> markerLowLevels;
  final List<String> mediaSupported;
  final List<String> mediaReady;
  final List<String> mediaColDatabase;
  final List<String> mediaTypeSupported;
  final List<String> sidesSupported;
  final List<String> printColorModeSupported;
  final List<String> printerResolutionSupported;
  final List<String> outputBinSupported;
  final List<String> printerAlert;
  final String? firmwareVersion;
  final int? impressionsCompleted;

  const RawIppTelemetryPayload({
    required this.reachable,
    this.printerStateEnum,
    this.stateReasons = const [],
    this.markerNames = const [],
    this.markerLevels = const [],
    this.markerColors = const [],
    this.markerTypes = const [],
    this.markerLowLevels = const [],
    this.mediaSupported = const [],
    this.mediaReady = const [],
    this.mediaColDatabase = const [],
    this.mediaTypeSupported = const [],
    this.sidesSupported = const [],
    this.printColorModeSupported = const [],
    this.printerResolutionSupported = const [],
    this.outputBinSupported = const [],
    this.printerAlert = const [],
    this.firmwareVersion,
    this.impressionsCompleted,
  });

  static const RawIppTelemetryPayload empty =
      RawIppTelemetryPayload(reachable: false);
}

/// Raw SNMP v1/v2c/v3 telemetry payload returned by the background isolate.
class RawSnmpTelemetryPayload {
  final bool reachable;
  final int? hrPrinterStatus; // 1=other, 2=unknown, 3=idle, 4=printing, 5=warmup
  final int? prtMarkerLifeCount;
  final List<SnmpSupplyRow> supplies;
  final List<SnmpInputTrayRow> inputTrays;
  final List<String> alertDescriptions;

  const RawSnmpTelemetryPayload({
    required this.reachable,
    this.hrPrinterStatus,
    this.prtMarkerLifeCount,
    this.supplies = const [],
    this.inputTrays = const [],
    this.alertDescriptions = const [],
  });

  static const RawSnmpTelemetryPayload empty =
      RawSnmpTelemetryPayload(reachable: false);
}

class SnmpSupplyRow {
  final int index;
  final String description;
  final int maxCapacity;
  final int level; // 0..maxCapacity, -1=other, -2=unknown, -3=some remaining

  const SnmpSupplyRow({
    required this.index,
    required this.description,
    required this.maxCapacity,
    required this.level,
  });
}

class SnmpInputTrayRow {
  final int index;
  final String name;
  final String mediaName;
  final String mediaType;
  final int maxCapacity;
  final int currentLevel;

  const SnmpInputTrayRow({
    required this.index,
    required this.name,
    required this.mediaName,
    required this.mediaType,
    required this.maxCapacity,
    required this.currentLevel,
  });
}

/// Raw Windows Spooler (`DeviceCapabilities` + `DEVMODE` + `PRINTER_INFO_2`) payload.
class RawWin32SpoolerPayload {
  final bool available;
  final int? statusFlags;
  final bool? supportsDuplex;
  final bool? supportsColor;
  final List<String> paperNames;
  final List<String> binNames;
  final List<String> mediaTypeNames;
  final int? landscapeOrientationDegrees;
  final String? defaultPaperName;
  final String? defaultMediaTypeName;
  final int? maxDpiX;
  final int? maxDpiY;

  const RawWin32SpoolerPayload({
    required this.available,
    this.statusFlags,
    this.supportsDuplex,
    this.supportsColor,
    this.paperNames = const [],
    this.binNames = const [],
    this.mediaTypeNames = const [],
    this.landscapeOrientationDegrees,
    this.defaultPaperName,
    this.defaultMediaTypeName,
    this.maxDpiX,
    this.maxDpiY,
  });

  static const RawWin32SpoolerPayload empty =
      RawWin32SpoolerPayload(available: false);
}

/// Raw Epson Web Config fallback payload (parsed defensively ONLY when user consented).
class RawWebConfigFallbackPayload {
  final bool reachable;
  final String? firmwareVersion;
  final String? maintenanceBoxStatus;
  final int? totalPagesPrinted;
  final Map<String, String> qualitativeSupplies; // e.g. {'Black': 'OK', 'Cyan': 'Low'}

  const RawWebConfigFallbackPayload({
    required this.reachable,
    this.firmwareVersion,
    this.maintenanceBoxStatus,
    this.totalPagesPrinted,
    this.qualitativeSupplies = const {},
  });

  static const RawWebConfigFallbackPayload empty =
      RawWebConfigFallbackPayload(reachable: false);
}

/// Multi-source live printer intelligence engine.
///
/// Queries IPP (Priority 1), SNMP v1/v2c/v3 (Priority 2), Windows Spooler APIs
/// (Priority 3), and consented Epson Web Config fallback (Priority 4).
/// Runs all network I/O in background isolates with strict timeouts, caches
/// results, and polls adaptively (`fastInterval` for the selected printer,
/// `slowInterval` for background printers).
class PrinterIntelligenceService {
  final Duration networkTimeout;
  final Duration fastPollInterval;
  final Duration slowPollInterval;

  List<EpsonModelProfile> _profiles = const [];
  final Map<String, PrinterLiveIntelligence> _cache = {};
  final Map<String, bool> _webConfigConsentByPrinter = {};
  final Map<String, PrinterNetworkAuthAndIdentityConfig> _authConfigsByPrinter =
      {};
  final Map<String, RawIppTelemetryPayload> _lastRawIppByPrinter = {};
  final Map<String, RawSnmpTelemetryPayload> _lastRawSnmpByPrinter = {};
  final Map<String, RawWin32SpoolerPayload> _lastRawWin32ByPrinter = {};
  final Map<String, PrinterWakeAndRediscoveryResult> _lastRediscoveryByPrinter =
      {};
  List<LanPrinterIdentityCandidate> _knownLanCandidates = const [];
  final StreamController<PrinterLiveIntelligence> _updatesController =
      StreamController<PrinterLiveIntelligence>.broadcast();

  Timer? _fastPollTimer;
  Timer? _slowPollTimer;
  PrinterDevice? _activePrinter;
  List<PrinterDevice> _backgroundPrinters = const [];

  PrinterIntelligenceService({
    this.networkTimeout = const Duration(milliseconds: 2200),
    this.fastPollInterval = const Duration(seconds: 8),
    this.slowPollInterval = const Duration(seconds: 45),
  });

  Stream<PrinterLiveIntelligence> get intelligenceStream =>
      _updatesController.stream;

  PrinterLiveIntelligence? getCached(String printerId) => _cache[printerId];

  /// List of printer names currently observed/cached.
  List<String> get observedPrinterNames => _cache.keys.toList();

  bool hasWebConfigConsent(String printerId) =>
      _webConfigConsentByPrinter[printerId] ?? false;

  void setWebConfigConsent(String printerId, bool consented) {
    _webConfigConsentByPrinter[printerId] = consented;
  }

  /// Gets or creates the per-printer SNMP community, IPP authentication, and
  /// hostname/serial/MAC identity config for [printerId].
  PrinterNetworkAuthAndIdentityConfig getAuthConfig(String printerId) {
    return _authConfigsByPrinter[printerId] ??
        PrinterNetworkAuthAndIdentityConfig(printerId: printerId);
  }

  void setAuthConfig(PrinterNetworkAuthAndIdentityConfig config) {
    _authConfigsByPrinter[config.printerId] = config;
  }

  void setKnownLanCandidatesForRediscovery(
      List<LanPrinterIdentityCandidate> candidates) {
    _knownLanCandidates = List<LanPrinterIdentityCandidate>.unmodifiable(
      candidates,
    );
  }

  PrinterWakeAndRediscoveryResult? getLastRediscoveryResult(String printerId) =>
      _lastRediscoveryByPrinter[printerId];

  RawIppTelemetryPayload? getLastRawIpp(String printerId) =>
      _lastRawIppByPrinter[printerId];

  RawSnmpTelemetryPayload? getLastRawSnmp(String printerId) =>
      _lastRawSnmpByPrinter[printerId];

  RawWin32SpoolerPayload? getLastRawWin32(String printerId) =>
      _lastRawWin32ByPrinter[printerId];

  /// Generates a complete support diagnostic report ("Copy printer diagnostics")
  /// containing raw IPP, raw SNMP, Win32 Spooler `DEVMODE` verification,
  /// rediscovery status, and offline mode audit logs.
  String buildDiagnosticsReportForPrinter(
    String printerId, {
    EpsonSpoolerJobOptions? jobOptions,
  }) {
    final intel = _cache[printerId];
    if (intel == null) {
      return '=== PRINT HELPER — PRINTER DIAGNOSTICS REPORT ===\n'
          'No cached telemetry snapshot for printer "$printerId" yet.\n'
          '=== END OF DIAGNOSTICS REPORT ===';
    }
    final devModeReport = EpsonSpoolerDevModeMapper.mapAndVerifyOptions(
      printerDriverName: intel.modelName,
      options: jobOptions ?? const EpsonSpoolerJobOptions(),
    );
    return PrinterDiagnosticsReportBuilder.buildDiagnosticsText(
      intelligence: intel,
      rawIpp: _lastRawIppByPrinter[printerId],
      rawSnmp: _lastRawSnmpByPrinter[printerId],
      rawWin32: _lastRawWin32ByPrinter[printerId],
      authConfig: getAuthConfig(printerId),
      lastRediscovery: _lastRediscoveryByPrinter[printerId],
      devModeVerification: devModeReport,
    );
  }

  /// Loads `assets/data/epson_printer_profiles.json` from the local filesystem first
  /// (so users/admins can update it without recompiling) or falls back to `rootBundle`.
  Future<List<EpsonModelProfile>> loadProfiles({String? customJsonPath}) async {
    if (_profiles.isNotEmpty && customJsonPath == null) {
      return _profiles;
    }

    String? rawJson;
    final candidatePaths = <String>[
      if (customJsonPath != null) customJsonPath,
      'assets/data/epson_printer_profiles.json',
    ];

    for (final path in candidatePaths) {
      final file = File(path);
      if (await file.exists()) {
        rawJson = await file.readAsString();
        break;
      }
    }

    if (rawJson == null) {
      try {
        rawJson = await rootBundle
            .loadString('assets/data/epson_printer_profiles.json');
      } catch (_) {
        rawJson = null;
      }
    }

    if (rawJson != null && rawJson.isNotEmpty) {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final list = decoded['profiles'] as List<dynamic>? ?? const [];
      _profiles = list
          .map((e) => EpsonModelProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return _profiles;
  }

  /// Matches a printer model/manufacturer string against loaded Epson & generic profiles.
  Future<EpsonModelProfile?> matchProfileForModel(String modelOrName) async {
    final profiles = await loadProfiles();
    final upper = modelOrName.toUpperCase();

    for (final profile in profiles) {
      if (profile.familyId == 'generic_standard_printer') continue;
      for (final pattern in profile.modelPatterns) {
        if (upper.contains(pattern.toUpperCase())) {
          return profile;
        }
      }
    }

    if (upper.contains('EPSON')) {
      // Default Epson fallback if specific model number isn't listed yet
      for (final profile in profiles) {
        if (profile.familyId == 'epson_ecotank_consumer_usb_wifi') {
          return profile;
        }
      }
    }

    for (final profile in profiles) {
      if (profile.familyId == 'generic_standard_printer') {
        return profile;
      }
    }
    return null;
  }

  /// Configures adaptive background polling:
  /// - Fast polling (`8s` default) while `selectedPrinter` is active
  /// - Slow polling (`45s` default) for other discovered printers
  void updateAdaptivePollingTargets({
    required PrinterDevice? selectedPrinter,
    List<PrinterDevice> allPrinters = const [],
  }) {
    _activePrinter = selectedPrinter;
    _backgroundPrinters = allPrinters
        .where((p) =>
            selectedPrinter == null || p.systemName != selectedPrinter.systemName)
        .toList();

    _fastPollTimer?.cancel();
    _slowPollTimer?.cancel();

    if (_activePrinter != null) {
      // Trigger immediate non-blocking refresh for the selected printer
      unawaited(fetchIntelligence(_activePrinter!));
      _fastPollTimer = Timer.periodic(fastPollInterval, (_) {
        final target = _activePrinter;
        if (target != null) {
          unawaited(fetchIntelligence(target));
        }
      });
    }

    if (_backgroundPrinters.isNotEmpty) {
      _slowPollTimer = Timer.periodic(slowPollInterval, (_) {
        for (final bg in _backgroundPrinters) {
          unawaited(fetchIntelligence(bg));
        }
      });
    }
  }

  /// Queries all available sources in parallel/sequence without blocking the UI thread,
  /// merges them in strict priority order (`IPP > SNMP > Win32 Spooler > Web Config`),
  /// caches the result, and emits it on [intelligenceStream].
  Future<PrinterLiveIntelligence> fetchIntelligence(
    PrinterDevice printer, {
    int ippPort = 631,
    int snmpPort = 161,
    int? webConfigPort,
    String? snmpCommunity,
    RawWin32SpoolerPayload? overrideWin32Payload,
  }) async {
    final matchedProfile =
        await matchProfileForModel('${printer.driverName} ${printer.displayName}');
    final authConfig = getAuthConfig(printer.systemName);
    final effectiveCommunity = snmpCommunity ?? authConfig.snmpCommunity;
    final authHeader = authConfig.buildIppAuthorizationHeader();
    String? ip = printer.ipAddress ?? _extractHostOrIp(printer.portName);
    final consentedWeb = hasWebConfigConsent(printer.systemName);

    Future<RawIppTelemetryPayload> ippFuture =
        Future.value(RawIppTelemetryPayload.empty);
    Future<RawSnmpTelemetryPayload> snmpFuture =
        Future.value(RawSnmpTelemetryPayload.empty);
    Future<RawWebConfigFallbackPayload> webFuture =
        Future.value(RawWebConfigFallbackPayload.empty);

    if (ip != null && ip.isNotEmpty) {
      // Strictly enforce offline local/LAN network policy before any socket call
      OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(ip);

      // If known LAN candidates or hostname/serial/MAC anchors exist, handle
      // sleep/wake and DHCP IP change rediscovery
      if (_knownLanCandidates.isNotEmpty ||
          authConfig.knownHostname != null ||
          authConfig.knownSerialNumber != null ||
          authConfig.knownMacAddress != null) {
        final rediscovery =
            await EpsonNetworkRediscoveryEngine.ensureAwakeOrRediscover(
          currentIp: ip,
          identityConfig: authConfig,
          lanCandidates: _knownLanCandidates,
        );
        _lastRediscoveryByPrinter[printer.systemName] = rediscovery;
        if (rediscovery.resolvedIp != null &&
            rediscovery.resolvedIp!.isNotEmpty) {
          ip = rediscovery.resolvedIp;
        }
      }

      ippFuture = collectIppInIsolate(
        host: ip!,
        port: ippPort,
        timeout: networkTimeout,
        authorizationHeader: authHeader,
      );
      snmpFuture = collectSnmpInIsolate(
        host: ip,
        port: snmpPort,
        community: effectiveCommunity,
        timeout: networkTimeout,
      );
      if (consentedWeb) {
        webFuture = collectWebConfigInIsolate(
          host: ip,
          port: webConfigPort ?? 80,
          timeout: networkTimeout,
        );
      }
    }

    final win32Payload = overrideWin32Payload ??
        (Platform.isWindows
            ? collectWin32SpoolerCapabilities(printer.systemName)
            : _buildWin32FallbackFromPrinterDevice(printer));

    final results = await Future.wait<Object>([
      ippFuture,
      snmpFuture,
      webFuture,
    ]);

    final ippPayload = results[0] as RawIppTelemetryPayload;
    final snmpPayload = results[1] as RawSnmpTelemetryPayload;
    final webPayload = results[2] as RawWebConfigFallbackPayload;

    _lastRawIppByPrinter[printer.systemName] = ippPayload;
    _lastRawSnmpByPrinter[printer.systemName] = snmpPayload;
    _lastRawWin32ByPrinter[printer.systemName] = win32Payload;

    final merged = mergeTelemetrySources(
      printer: printer,
      ipAddress: ip,
      ippPort: ip != null ? ippPort : null,
      snmpPort: ip != null ? snmpPort : null,
      userConsentedWebConfig: consentedWeb,
      ipp: ippPayload,
      snmp: snmpPayload,
      win32: win32Payload,
      webConfig: webPayload,
      matchedProfile: matchedProfile,
    );

    _cache[printer.systemName] = merged;
    if (!_updatesController.isClosed) {
      _updatesController.add(merged);
    }
    return merged;
  }

  /// Merges the 4 telemetry sources in strict priority order:
  /// `1. IPP` -> `2. SNMP` -> `3. Win32 Spooler` -> `4. Web Config (Consented)`
  /// and enriches static model bounds with `EpsonModelProfile` without ever
  /// guessing live unreported attributes.
  PrinterLiveIntelligence mergeTelemetrySources({
    required PrinterDevice printer,
    required String? ipAddress,
    required int? ippPort,
    required int? snmpPort,
    required bool userConsentedWebConfig,
    required RawIppTelemetryPayload ipp,
    required RawSnmpTelemetryPayload snmp,
    required RawWin32SpoolerPayload win32,
    required RawWebConfigFallbackPayload webConfig,
    required EpsonModelProfile? matchedProfile,
  }) {
    final now = DateTime.now();

    // -------------------------------------------------------------------------
    // 1. Printer State & Plain-Language Problems
    // -------------------------------------------------------------------------
    final ippState = _mapIppState(ipp, now);
    final snmpState = _mapSnmpState(snmp, now);
    final win32State = _mapWin32State(win32, printer, now);
    final mergedState = ippState.mergeWith(snmpState).mergeWith(win32State);

    final ippReasons = ipp.reachable && ipp.stateReasons.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: ipp.stateReasons,
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'printer-state-reasons',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported(
            'printer-state-reasons');

    final snmpReasons = snmp.reachable && snmp.alertDescriptions.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: snmp.alertDescriptions,
            source: PrinterTelemetrySource.snmp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'prtAlertDescription',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('prtAlertDescription');

    final mergedReasons = ippReasons.mergeWith(snmpReasons);
    final baseProblems = _translateProblemsToPlainLanguage(
      ipp: ipp,
      snmp: snmp,
      win32: win32,
      printer: printer,
    );
    final epsonDetectedConditions = EpsonConditionDetector.detectConditions(
      ipp: ipp,
      snmp: snmp,
      win32: win32,
      printer: printer,
      matchedProfile: matchedProfile,
    );
    final activeProblems = <PlainLanguagePrinterProblem>[...baseProblems];
    final existingRawCodes =
        activeProblems.map((p) => p.rawCode.toLowerCase()).toSet();
    for (final cond in epsonDetectedConditions) {
      final problem = cond.toPlainLanguageProblem();
      if (existingRawCodes.add(problem.rawCode.toLowerCase())) {
        activeProblems.add(problem);
      }
    }

    // Elevate state to error if any hard-stop problem is active
    final effectiveState = activeProblems.any((p) => p.isHardStopBlockingError)
        ? SourcedPrinterField<LivePrinterState>.reported(
            value: LivePrinterState.error,
            source: mergedReasons.isReported
                ? mergedReasons.source
                : mergedState.source,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'printer-state-reasons',
            observedAt: now,
          )
        : mergedState;

    // -------------------------------------------------------------------------
    // 2. Supply Levels (IPP -> SNMP -> Consented Web Config; NEVER guessed)
    // -------------------------------------------------------------------------
    final primarySupplyKind = matchedProfile?.primarySupplyKind ??
        _inferSupplyKindFromMarkers(ipp.markerTypes, snmp.supplies);

    final ippSupplies = _buildIppSupplies(
      ipp: ipp,
      snmp: snmp,
      primaryKind: primarySupplyKind,
      now: now,
    );
    final snmpSupplies = _buildSnmpSupplies(
      snmp: snmp,
      primaryKind: primarySupplyKind,
      now: now,
    );
    final webSupplies = _buildWebConfigSupplies(
      web: webConfig,
      consented: userConsentedWebConfig,
      primaryKind: primarySupplyKind,
      now: now,
    );

    final mergedSupplies =
        ippSupplies.mergeWith(snmpSupplies).mergeWith(webSupplies);

    // -------------------------------------------------------------------------
    // 3. Paper Sizes, Media Types & Trays
    // -------------------------------------------------------------------------
    final ippPaperSizes = ipp.reachable && ipp.mediaSupported.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: ipp.mediaSupported.map(_humanizeMediaName).toSet().toList(),
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'media-supported',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('media-supported');

    final win32PaperSizes = win32.available && win32.paperNames.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: win32.paperNames,
            source: PrinterTelemetrySource.windowsSpooler,
            confidence: TelemetryConfidence.medium,
            rawAttributeKey: 'DC_PAPERNAMES',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('DC_PAPERNAMES');

    final profilePaperSizes = matchedProfile != null &&
            matchedProfile.supportedPaperSizes.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: matchedProfile.supportedPaperSizes,
            source: PrinterTelemetrySource.epsonProfileDb,
            confidence: TelemetryConfidence.low,
            rawAttributeKey: 'epson_profile.supportedPaperSizes',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('supportedPaperSizes');

    final mergedSupportedPaperSizes = ippPaperSizes
        .mergeWith(win32PaperSizes)
        .mergeWith(profilePaperSizes);

    final ippReadyPaper = ipp.reachable && ipp.mediaReady.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: ipp.mediaReady.map(_humanizeMediaName).toList(),
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'media-ready',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('media-ready');

    final snmpReadyPaper = snmp.reachable &&
            snmp.inputTrays.any((t) => t.mediaName.trim().isNotEmpty)
        ? SourcedPrinterField<List<String>>.reported(
            value: snmp.inputTrays
                .where((t) => t.mediaName.trim().isNotEmpty)
                .map((t) => _humanizeMediaName(t.mediaName))
                .toList(),
            source: PrinterTelemetrySource.snmp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'prtInputMediaName',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('prtInputMediaName');

    final mergedReadyPaper = ippReadyPaper.mergeWith(snmpReadyPaper);

    final ippMediaTypes = ipp.reachable && ipp.mediaTypeSupported.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: ipp.mediaTypeSupported.map(_humanizeMediaType).toList(),
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'media-type-supported',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('media-type-supported');

    final win32MediaTypes = win32.available && win32.mediaTypeNames.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: win32.mediaTypeNames,
            source: PrinterTelemetrySource.windowsSpooler,
            confidence: TelemetryConfidence.medium,
            rawAttributeKey: 'DC_MEDIATYPENAMES',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('DC_MEDIATYPENAMES');

    final profileMediaTypes = matchedProfile != null &&
            matchedProfile.supportedMediaTypes.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: matchedProfile.supportedMediaTypes,
            source: PrinterTelemetrySource.epsonProfileDb,
            confidence: TelemetryConfidence.low,
            rawAttributeKey: 'epson_profile.supportedMediaTypes',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('supportedMediaTypes');

    final mergedMediaTypes = ippMediaTypes
        .mergeWith(win32MediaTypes)
        .mergeWith(profileMediaTypes);

    final mergedTrays = _mergeTrays(
      ipp: ipp,
      snmp: snmp,
      win32: win32,
      now: now,
    );

    // -------------------------------------------------------------------------
    // 4. Capabilities Badges
    // -------------------------------------------------------------------------
    final ippDuplex = ipp.reachable && ipp.sidesSupported.isNotEmpty
        ? SourcedPrinterField<DuplexSupportMode>.reported(
            value: ipp.sidesSupported.any((s) => s.contains('two-sided'))
                ? DuplexSupportMode.automatic
                : DuplexSupportMode.manualOnly,
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'sides-supported',
            observedAt: now,
          )
        : SourcedPrinterField<DuplexSupportMode>.notReported('sides-supported');

    final win32Duplex = win32.available && win32.supportsDuplex != null
        ? SourcedPrinterField<DuplexSupportMode>.reported(
            value: win32.supportsDuplex!
                ? DuplexSupportMode.automatic
                : DuplexSupportMode.manualOnly,
            source: PrinterTelemetrySource.windowsSpooler,
            confidence: TelemetryConfidence.medium,
            rawAttributeKey: 'DC_DUPLEX',
            observedAt: now,
          )
        : SourcedPrinterField<DuplexSupportMode>.notReported('DC_DUPLEX');

    final profileDuplex = matchedProfile != null &&
            matchedProfile.autoDuplexDefault != 'autoDetect'
        ? SourcedPrinterField<DuplexSupportMode>.reported(
            value: matchedProfile.autoDuplexDefault == 'automatic'
                ? DuplexSupportMode.automatic
                : DuplexSupportMode.manualOnly,
            source: PrinterTelemetrySource.epsonProfileDb,
            confidence: TelemetryConfidence.low,
            rawAttributeKey: 'epson_profile.autoDuplexDefault',
            observedAt: now,
          )
        : SourcedPrinterField<DuplexSupportMode>.notReported('autoDuplex');

    final mergedDuplex =
        ippDuplex.mergeWith(win32Duplex).mergeWith(profileDuplex);

    final ippColor = ipp.reachable && ipp.printColorModeSupported.isNotEmpty
        ? SourcedPrinterField<bool>.reported(
            value: ipp.printColorModeSupported
                .any((m) => m.toLowerCase().contains('color')),
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'print-color-mode-supported',
            observedAt: now,
          )
        : SourcedPrinterField<bool>.notReported('print-color-mode-supported');

    final win32Color = win32.available && win32.supportsColor != null
        ? SourcedPrinterField<bool>.reported(
            value: win32.supportsColor!,
            source: PrinterTelemetrySource.windowsSpooler,
            confidence: TelemetryConfidence.medium,
            rawAttributeKey: 'DC_COLORDEVICE',
            observedAt: now,
          )
        : SourcedPrinterField<bool>.notReported('DC_COLORDEVICE');

    final mergedColor = ippColor.mergeWith(win32Color);

    final ippBorderless = ipp.reachable && ipp.mediaColDatabase.isNotEmpty
        ? SourcedPrinterField<bool>.reported(
            value: ipp.mediaColDatabase.any((entry) =>
                entry.contains('borderless') || entry.contains('margins=0')),
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'media-col-database',
            observedAt: now,
          )
        : SourcedPrinterField<bool>.notReported('media-col-database');

    final profileBorderless = matchedProfile != null
        ? SourcedPrinterField<bool>.reported(
            value: matchedProfile.supportsBorderless,
            source: PrinterTelemetrySource.epsonProfileDb,
            confidence: TelemetryConfidence.low,
            rawAttributeKey: 'epson_profile.supportsBorderless',
            observedAt: now,
          )
        : SourcedPrinterField<bool>.notReported('supportsBorderless');

    final mergedBorderless = ippBorderless.mergeWith(profileBorderless);

    final ippResolution =
        ipp.reachable && ipp.printerResolutionSupported.isNotEmpty
            ? SourcedPrinterField<String>.reported(
                value: ipp.printerResolutionSupported.last,
                source: PrinterTelemetrySource.ipp,
                confidence: TelemetryConfidence.high,
                rawAttributeKey: 'printer-resolution-supported',
                observedAt: now,
              )
            : SourcedPrinterField<String>.notReported(
                'printer-resolution-supported');

    final win32Resolution =
        win32.available && win32.maxDpiX != null && win32.maxDpiY != null
            ? SourcedPrinterField<String>.reported(
                value: '${win32.maxDpiX}x${win32.maxDpiY} dpi',
                source: PrinterTelemetrySource.windowsSpooler,
                confidence: TelemetryConfidence.medium,
                rawAttributeKey: 'DEVMODE.dmPrintQuality',
                observedAt: now,
              )
            : SourcedPrinterField<String>.notReported('DEVMODE.dmPrintQuality');

    final profileResolution = matchedProfile != null
        ? SourcedPrinterField<String>.reported(
            value: '${matchedProfile.maxOpticalDpi} dpi',
            source: PrinterTelemetrySource.epsonProfileDb,
            confidence: TelemetryConfidence.low,
            rawAttributeKey: 'epson_profile.maxOpticalDpi',
            observedAt: now,
          )
        : SourcedPrinterField<String>.notReported('maxOpticalDpi');

    final mergedResolution = ippResolution
        .mergeWith(win32Resolution)
        .mergeWith(profileResolution);

    final win32Orientations =
        win32.available && win32.landscapeOrientationDegrees != null
            ? SourcedPrinterField<List<String>>.reported(
                value: win32.landscapeOrientationDegrees! > 0
                    ? const ['Portrait', 'Landscape']
                    : const ['Portrait'],
                source: PrinterTelemetrySource.windowsSpooler,
                confidence: TelemetryConfidence.medium,
                rawAttributeKey: 'DC_ORIENTATION',
                observedAt: now,
              )
            : SourcedPrinterField<List<String>>.notReported('DC_ORIENTATION');

    final ippOutputBins = ipp.reachable && ipp.outputBinSupported.isNotEmpty
        ? SourcedPrinterField<List<String>>.reported(
            value: ipp.outputBinSupported,
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'output-bin-supported',
            observedAt: now,
          )
        : SourcedPrinterField<List<String>>.notReported('output-bin-supported');

    // -------------------------------------------------------------------------
    // 5. Maintenance Info (Page Counters, Firmware Version, Maintenance Box)
    // -------------------------------------------------------------------------
    final ippPageCount = ipp.reachable && ipp.impressionsCompleted != null
        ? SourcedPrinterField<int>.reported(
            value: ipp.impressionsCompleted!,
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'printer-impressions-completed',
            observedAt: now,
          )
        : SourcedPrinterField<int>.notReported('printer-impressions-completed');

    final snmpPageCount = snmp.reachable && snmp.prtMarkerLifeCount != null
        ? SourcedPrinterField<int>.reported(
            value: snmp.prtMarkerLifeCount!,
            source: PrinterTelemetrySource.snmp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'prtMarkerLifeCount',
            observedAt: now,
          )
        : SourcedPrinterField<int>.notReported('prtMarkerLifeCount');

    final webPageCount = userConsentedWebConfig &&
            webConfig.reachable &&
            webConfig.totalPagesPrinted != null
        ? SourcedPrinterField<int>.reported(
            value: webConfig.totalPagesPrinted!,
            source: PrinterTelemetrySource.webConfigFallback,
            confidence: TelemetryConfidence.low,
            rawAttributeKey: 'web_config.total_pages',
            observedAt: now,
          )
        : SourcedPrinterField<int>.notReported('web_config.total_pages');

    final mergedPageCount =
        ippPageCount.mergeWith(snmpPageCount).mergeWith(webPageCount);

    final ippFirmware = ipp.reachable &&
            ipp.firmwareVersion != null &&
            ipp.firmwareVersion!.trim().isNotEmpty
        ? SourcedPrinterField<String>.reported(
            value: ipp.firmwareVersion!.trim(),
            source: PrinterTelemetrySource.ipp,
            confidence: TelemetryConfidence.high,
            rawAttributeKey: 'printer-firmware-string-version',
            observedAt: now,
          )
        : SourcedPrinterField<String>.notReported(
            'printer-firmware-string-version');

    final webFirmware = userConsentedWebConfig &&
            webConfig.reachable &&
            webConfig.firmwareVersion != null &&
            webConfig.firmwareVersion!.trim().isNotEmpty
        ? SourcedPrinterField<String>.reported(
            value: webConfig.firmwareVersion!.trim(),
            source: PrinterTelemetrySource.webConfigFallback,
            confidence: TelemetryConfidence.low,
            rawAttributeKey: 'web_config.firmware',
            observedAt: now,
          )
        : SourcedPrinterField<String>.notReported('web_config.firmware');

    final mergedFirmware = ippFirmware.mergeWith(webFirmware);

    final maintenanceStatus = _extractMaintenanceBoxStatus(
      suppliesField: mergedSupplies,
      webConfig: webConfig,
      consentedWeb: userConsentedWebConfig,
      now: now,
    );

    return PrinterLiveIntelligence(
      printerId: printer.systemName,
      displayName: printer.displayName,
      modelName: printer.driverName.isNotEmpty
          ? printer.driverName
          : printer.displayName,
      connectionType: printer.connectionType,
      ipAddress: ipAddress,
      ippPort: ippPort,
      snmpPort: snmpPort,
      fetchedAt: now,
      userConsentedWebConfig: userConsentedWebConfig,
      printerState: effectiveState,
      rawStateReasons: mergedReasons,
      activeProblems: activeProblems,
      primarySupplyLabel: primarySupplyKind,
      supplies: mergedSupplies,
      supportedPaperSizes: mergedSupportedPaperSizes,
      readyPaperSizes: mergedReadyPaper,
      supportedMediaTypes: mergedMediaTypes,
      trays: mergedTrays,
      duplexSupport: mergedDuplex,
      supportsColor: mergedColor,
      supportsBorderless: mergedBorderless,
      maxResolutionDpi: mergedResolution,
      supportedOrientations: win32Orientations,
      supportedOutputBins: ippOutputBins,
      lifetimePageCount: mergedPageCount,
      firmwareVersion: mergedFirmware,
      maintenanceBoxStatus: maintenanceStatus,
      matchedProfile: matchedProfile,
    );
  }

  // ===========================================================================
  // Smart Pre-Print Validation & "Fix it for me"
  // ===========================================================================

  /// Validates the user's selected print job settings against the printer's real
  /// reported capabilities and live state.
  ///
  /// Produces friendly checks, disabled option reasons, and one-click
  /// `"Fix it for me"` actions. Never blocks printing for low supplies or
  /// non-fatal warnings.
  SmartPrintValidationReport validatePrintJob({
    required PrinterLiveIntelligence intelligence,
    required String requestedPaperSize,
    required String requestedMediaType,
    required bool requestedTwoSided,
    required bool requestedColor,
    required bool requestedBorderless,
  }) {
    final checks = <SmartPrintValidationCheck>[];
    final disabledOptions = <String, DisabledPrintOptionReason>{};
    bool requiresManualDuplex = false;

    // 1. Hardware hard-stop errors (Paper jam, cover open, offline, empty tray)
    for (final problem in intelligence.activeProblems) {
      checks.add(
        SmartPrintValidationCheck(
          id: 'problem_${problem.rawCode}',
          severity: problem.isHardStopBlockingError
              ? SmartValidationSeverity.hardwareStopError
              : SmartValidationSeverity.warningNonBlocking,
          messageEn: '${problem.titleEn} — ${problem.detailEn}',
          messageSi: '${problem.titleSi} — ${problem.detailSi}',
          source: problem.source,
          confidence: problem.confidence,
          blocksSubmission: problem.isHardStopBlockingError,
        ),
      );
    }

    // 2. Double-sided (Duplex) validation
    if (intelligence.duplexSupport.isReported &&
        intelligence.duplexSupport.value != null) {
      final mode = intelligence.duplexSupport.value!;
      if (mode == DuplexSupportMode.automatic) {
        if (requestedTwoSided) {
          checks.add(
            SmartPrintValidationCheck(
              id: 'duplex_supported',
              severity: SmartValidationSeverity.readyPass,
              messageEn: 'Double-sided is supported on this printer.',
              messageSi:
                  'මෙම මුද්‍රණ යන්ත්‍රය ස්වයංක්‍රීය දෙපස මුද්‍රණයට සහාය දක්වයි.',
              source: intelligence.duplexSupport.source,
              confidence: intelligence.duplexSupport.confidence,
            ),
          );
        }
      } else {
        disabledOptions['autoDuplex'] = const DisabledPrintOptionReason(
          optionKey: 'autoDuplex',
          reasonEn:
              'Automatic 2-sided unit not installed; use Manual Duplex Assistant.',
          reasonSi:
              'ස්වයංක්‍රීය දෙපස මුද්‍රණ ඒකකයක් නොමැත; අතින් පිටු පෙරළීමේ සහායකය භාවිතා කරන්න.',
        );
        if (requestedTwoSided) {
          requiresManualDuplex = true;
          checks.add(
            SmartPrintValidationCheck(
              id: 'duplex_manual_assistant',
              severity: SmartValidationSeverity.infoGuidance,
              messageEn:
                  'This printer does not support automatic double-sided. Print Helper can print odd pages, then guide you to flip and print even pages.',
              messageSi:
                  'මෙම මුද්‍රණ යන්ත්‍රය ස්වයංක්‍රීය දෙපස මුද්‍රණයට සහාය නොදක්වයි. Print Helper මගින් පළමුව ඔත්තේ පිටු මුද්‍රණය කර, පිටු පෙරළා ඉරට්ටේ පිටු මුද්‍රණය කිරීමට ඔබට මග පෙන්විය හැක.',
              source: intelligence.duplexSupport.source,
              confidence: intelligence.duplexSupport.confidence,
              autoFix: const SmartPrintValidationFix(
                actionKind: SmartFixActionKind.switchToManualDuplexAssistant,
                buttonLabelEn: 'Fix it for me (Use Manual Duplex Assistant)',
                buttonLabelSi: 'මට එය නිවැරදි කර දෙන්න (අතින් දෙපස මුද්‍රණය)',
              ),
            ),
          );
        }
      }
    }

    // 3. Paper size & Tray validation
    final paperEval = intelligence.evaluatePaperSize(requestedPaperSize);
    final loadedTray = _findTrayWithPaper(intelligence, requestedPaperSize);
    final anyLoadedPaper = _findFirstLoadedPaperSize(intelligence);

    if (paperEval == PaperAvailabilityState.loadedNow) {
      final trayLabel = loadedTray?.trayName ?? 'Tray 1';
      checks.add(
        SmartPrintValidationCheck(
          id: 'paper_loaded_ok',
          severity: SmartValidationSeverity.readyPass,
          messageEn: '$requestedPaperSize is loaded in $trayLabel.',
          messageSi: '$trayLabel හි $requestedPaperSize කඩදාසි පටවා ඇත.',
          source: loadedTray?.loadedPaperSize.source ??
              intelligence.readyPaperSizes.source,
          confidence: loadedTray?.loadedPaperSize.confidence ??
              intelligence.readyPaperSizes.confidence,
        ),
      );
    } else if (paperEval == PaperAvailabilityState.supportedNotLoaded) {
      checks.add(
        SmartPrintValidationCheck(
          id: 'paper_supported_not_loaded',
          severity: SmartValidationSeverity.warningNonBlocking,
          messageEn:
              '$requestedPaperSize is supported but not currently loaded. Please load $requestedPaperSize paper${anyLoadedPaper != null ? ", or switch to $anyLoadedPaper" : ""}.',
          messageSi:
              '$requestedPaperSize සහාය දක්වයි, නමුත් දැනට පටවා නැත. කරුණාකර $requestedPaperSize කඩදාසි පටවන්න.',
          source: intelligence.supportedPaperSizes.source,
          confidence: intelligence.supportedPaperSizes.confidence,
          autoFix: anyLoadedPaper != null
              ? SmartPrintValidationFix(
                  actionKind: SmartFixActionKind.switchPaperSizeToLoaded,
                  buttonLabelEn: 'Fix it for me (Switch to $anyLoadedPaper)',
                  buttonLabelSi:
                      'මට එය නිවැරදි කර දෙන්න ($anyLoadedPaper වෙත මාරු වන්න)',
                  targetPaperSize: anyLoadedPaper,
                )
              : null,
        ),
      );
    } else if (paperEval == PaperAvailabilityState.notSupported) {
      final fallbackSize = anyLoadedPaper ??
          (intelligence.supportedPaperSizes.value?.isNotEmpty == true
              ? intelligence.supportedPaperSizes.value!.first
              : 'A4');
      disabledOptions['paperSize:$requestedPaperSize'] =
          DisabledPrintOptionReason(
        optionKey: 'paperSize:$requestedPaperSize',
        reasonEn: '$requestedPaperSize is not supported by this printer.',
        reasonSi: '$requestedPaperSize මෙම මුද්‍රණ යන්ත්‍රය මගින් සහාය නොදක්වයි.',
      );
      checks.add(
        SmartPrintValidationCheck(
          id: 'paper_not_supported',
          severity: SmartValidationSeverity.warningNonBlocking,
          messageEn:
              '$requestedPaperSize is not supported by this printer. Switch to $fallbackSize.',
          messageSi:
              '$requestedPaperSize මෙම මුද්‍රණ යන්ත්‍රය මගින් සහාය නොදක්වයි. $fallbackSize වෙත මාරු වන්න.',
          source: intelligence.supportedPaperSizes.source,
          confidence: intelligence.supportedPaperSizes.confidence,
          autoFix: SmartPrintValidationFix(
            actionKind: SmartFixActionKind.switchPaperSizeToLoaded,
            buttonLabelEn: 'Fix it for me (Use $fallbackSize)',
            buttonLabelSi: 'මට එය නිවැරදි කර දෙන්න ($fallbackSize භාවිතා කරන්න)',
            targetPaperSize: fallbackSize,
          ),
        ),
      );
    }

    // 4. Media Type mismatch validation (e.g. Photo paper selected, plain paper in tray)
    final reportedTrayMedia = _findFirstLoadedMediaType(intelligence);
    if (reportedTrayMedia != null &&
        !_mediaTypesMatch(requestedMediaType, reportedTrayMedia)) {
      checks.add(
        SmartPrintValidationCheck(
          id: 'media_type_mismatch',
          severity: SmartValidationSeverity.warningNonBlocking,
          messageEn:
              '$requestedMediaType selected, but the printer reports ${reportedTrayMedia.toLowerCase()} in the tray.',
          messageSi:
              '$requestedMediaType තෝරා ඇත, නමුත් මුද්‍රණ තැටියේ ${reportedTrayMedia} ඇති බව වාර්තා වේ.',
          source: PrinterTelemetrySource.ipp,
          confidence: TelemetryConfidence.high,
          autoFix: SmartPrintValidationFix(
            actionKind: SmartFixActionKind.switchMediaTypeToLoadedTray,
            buttonLabelEn: 'Fix it for me (Switch to $reportedTrayMedia)',
            buttonLabelSi:
                'මට එය නිවැරදි කර දෙන්න ($reportedTrayMedia වෙත මාරු වන්න)',
            targetMediaType: reportedTrayMedia,
          ),
        ),
      );
    }

    // 5. Color capability check
    if (intelligence.supportsColor.isReported &&
        intelligence.supportsColor.value == false) {
      disabledOptions['color'] = const DisabledPrintOptionReason(
        optionKey: 'color',
        reasonEn: 'Monochrome printer (Black & White only).',
        reasonSi: 'කළු-සුදු මුද්‍රණ යන්ත්‍රයක් පමණි.',
      );
      if (requestedColor) {
        checks.add(
          SmartPrintValidationCheck(
            id: 'mono_only_printer',
            severity: SmartValidationSeverity.warningNonBlocking,
            messageEn:
                'Color mode is selected, but this printer only supports Black & White.',
            messageSi:
                'වර්ණ මුද්‍රණය තෝරා ඇත, නමුත් මෙම යන්ත්‍රය කළු-සුදු මුද්‍රණයට පමණක් සහාය දක්වයි.',
            source: intelligence.supportsColor.source,
            confidence: intelligence.supportsColor.confidence,
            autoFix: const SmartPrintValidationFix(
              actionKind: SmartFixActionKind.switchColorToGrayscale,
              buttonLabelEn: 'Fix it for me (Switch to Black & White)',
              buttonLabelSi: 'මට එය නිවැරදි කර දෙන්න (කළු-සුදු වෙත මාරු වන්න)',
            ),
          ),
        );
      }
    }

    // 6. Borderless capability check
    if (intelligence.supportsBorderless.isReported &&
        intelligence.supportsBorderless.value == false) {
      disabledOptions['borderless'] = const DisabledPrintOptionReason(
        optionKey: 'borderless',
        reasonEn: 'Borderless printing is not supported on this model.',
        reasonSi: 'මෙම මාදිලිය දාර රහිත (Borderless) මුද්‍රණයට සහාය නොදක්වයි.',
      );
      if (requestedBorderless) {
        checks.add(
          SmartPrintValidationCheck(
            id: 'borderless_not_supported',
            severity: SmartValidationSeverity.warningNonBlocking,
            messageEn:
                'Borderless printing is selected, but this printer requires standard page margins.',
            messageSi:
                'දාර රහිත මුද්‍රණය තෝරා ඇත, නමුත් මෙම මුද්‍රණ යන්ත්‍රයට සාමාන්‍ය පිටු දාර අවශ්‍ය වේ.',
            source: intelligence.supportsBorderless.source,
            confidence: intelligence.supportsBorderless.confidence,
            autoFix: const SmartPrintValidationFix(
              actionKind: SmartFixActionKind.disableBorderless,
              buttonLabelEn: 'Fix it for me (Use Standard Margins)',
              buttonLabelSi: 'මට එය නිවැරදි කර දෙන්න (සාමාන්‍ය දාර භාවිතා කරන්න)',
            ),
          ),
        );
      }
    }

    // 7. Low ink / toner checks (WARN ONLY, NEVER BLOCK)
    if (intelligence.supplies.isReported &&
        intelligence.supplies.value != null) {
      for (final marker in intelligence.supplies.value!) {
        if (marker.isLow || marker.isEmpty) {
          final isColorMarker = marker.name.toLowerCase().contains('cyan') ||
              marker.name.toLowerCase().contains('magenta') ||
              marker.name.toLowerCase().contains('yellow');
          final kindWord =
              marker.supplyKind == SupplyTechnologyKind.toner ? 'toner' : 'ink';
          final pctSuffix =
              marker.levelPercent.isReported && marker.levelPercent.value != null
                  ? ' (${marker.levelPercent.value}%)'
                  : '';

          checks.add(
            SmartPrintValidationCheck(
              id: 'supply_low_${marker.name}',
              severity: SmartValidationSeverity.warningNonBlocking,
              messageEn: isColorMarker
                  ? '${marker.name}$pctSuffix is low; color prints may be affected.'
                  : '${marker.name} $kindWord$pctSuffix is low; print quality may be affected.',
              messageSi:
                  '${marker.name}$pctSuffix අඩු මට්ටමක පවතී; මුද්‍රණ තත්ත්වයට බලපෑම් ඇති විය හැක.',
              source: marker.qualitativeStatus.source,
              confidence: marker.qualitativeStatus.confidence,
              blocksSubmission: false, // Explicitly never block on low ink
              autoFix: isColorMarker && requestedColor
                  ? const SmartPrintValidationFix(
                      actionKind: SmartFixActionKind.switchColorToGrayscale,
                      buttonLabelEn: 'Fix it for me (Print in Black & White)',
                      buttonLabelSi:
                          'මට එය නිවැරදි කර දෙන්න (කළු-සුදු මුද්‍රණය කරන්න)',
                    )
                  : null,
            ),
          );
        }
      }
    }

    return SmartPrintValidationReport(
      checks: checks,
      disabledOptions: disabledOptions,
      requiresManualDuplexAssistant: requiresManualDuplex,
    );
  }

  /// Builds the 3-step Manual Duplex Assistant plan for printers without
  /// automatic 2-sided hardware.
  ManualDuplexAssistantPlan buildManualDuplexPlan({
    required int totalPages,
    ManualDuplexFlipEdge flipEdge = ManualDuplexFlipEdge.longEdge,
    bool reverseEvenOrderForRearFeed = true,
  }) {
    final safeTotal = totalPages < 1 ? 1 : totalPages;
    final oddPages = <int>[];
    final evenPages = <int>[];

    for (int p = 1; p <= safeTotal; p++) {
      if (p.isOdd) {
        oddPages.add(p);
      } else {
        evenPages.add(p);
      }
    }

    final orderedEven = reverseEvenOrderForRearFeed
        ? evenPages.reversed.toList()
        : evenPages;

    return ManualDuplexAssistantPlan(
      totalDocumentPages: safeTotal,
      step1OddPages: oddPages,
      step3EvenPages: orderedEven,
      needsBlankLastSheetKeepOut: safeTotal.isOdd && safeTotal > 1,
      flipEdge: flipEdge,
      trayGuidanceEn: safeTotal.isOdd && safeTotal > 1
          ? 'Note: Because your document has an odd number of pages ($safeTotal), leave the last printed sheet (Page $safeTotal) in the output tray before flipping the rest of the stack.'
          : 'Take all printed sheets from the output tray, keep them together in order, and follow the flip direction shown below.',
      trayGuidanceSi: safeTotal.isOdd && safeTotal > 1
          ? 'සටහන: ඔබගේ ලේඛනයේ ඔත්තේ පිටු ගණනක් ($safeTotal) ඇති බැවින්, අවසාන කොළය (පිටුව $safeTotal) ඉවත් කර ඉතිරි කොළ මිටිය පමණක් පෙරළා නැවත තැටියට දමන්න.'
          : 'පිටතට පැමිණි සියලුම මුද්‍රිත කොළ පිළිවෙලට ගෙන පහත දැක්වෙන දිශාවට පෙරළා නැවත තැටියට දමන්න.',
    );
  }

  void dispose() {
    _fastPollTimer?.cancel();
    _slowPollTimer?.cancel();
    _updatesController.close();
  }

  // ===========================================================================
  // Isolate Collectors (Priority 1 IPP, Priority 2 SNMP, Priority 4 Web Config)
  // ===========================================================================

  /// Executes binary IPP `Get-Printer-Attributes` (RFC 8011) inside a background
  /// isolate with a strict timeout so a slow/offline printer never blocks the UI.
  static Future<RawIppTelemetryPayload> collectIppInIsolate({
    required String host,
    required int port,
    required Duration timeout,
    String? authorizationHeader,
  }) async {
    OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(host);
    try {
      return await Isolate.run(
        () => _executeIppGetPrinterAttributes(
          host,
          port,
          timeout,
          authorizationHeader,
        ),
      ).timeout(timeout + const Duration(milliseconds: 300));
    } catch (_) {
      return RawIppTelemetryPayload.empty;
    }
  }

  /// Executes UDP SNMP `GetRequest` (RFC 3805 Printer MIB + HR-MIB) inside a
  /// background isolate with a strict timeout.
  static Future<RawSnmpTelemetryPayload> collectSnmpInIsolate({
    required String host,
    required int port,
    required String community,
    required Duration timeout,
  }) async {
    OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(host);
    try {
      return await Isolate.run(
        () => _executeSnmpPrinterMibQuery(host, port, community, timeout),
      ).timeout(timeout + const Duration(milliseconds: 300));
    } catch (_) {
      return RawSnmpTelemetryPayload.empty;
    }
  }

  /// Executes defensive Epson Web Config parsing inside a background isolate,
  /// ONLY invoked when the user has explicitly granted consent.
  static Future<RawWebConfigFallbackPayload> collectWebConfigInIsolate({
    required String host,
    required int port,
    required Duration timeout,
  }) async {
    OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(host);
    try {
      return await Isolate.run(
        () => _executeWebConfigFallbackFetch(host, port, timeout),
      ).timeout(timeout + const Duration(milliseconds: 300));
    } catch (_) {
      return RawWebConfigFallbackPayload.empty;
    }
  }

  // ===========================================================================
  // Binary IPP (RFC 8011) Encoder & Parser
  // ===========================================================================

  /// Builds a standards-compliant RFC 8011 IPP 2.0 `Get-Printer-Attributes`
  /// (`0x000B`) binary request packet.
  static Uint8List buildIppGetPrinterAttributesPacket({
    required String printerUri,
    int requestId = 1,
    List<String> requestedAttributes = kRequestedIppAttributes,
  }) {
    final builder = BytesBuilder();
    // Version 2.0
    builder.addByte(0x02);
    builder.addByte(0x00);
    // Operation-Id: Get-Printer-Attributes (0x000B)
    builder.addByte(0x00);
    builder.addByte(0x0B);
    // Request-Id (4 bytes big-endian)
    builder.add(_uint32BigEndian(requestId));

    // Operation-Attributes-Tag (0x01)
    builder.addByte(0x01);

    // attributes-charset (tag 0x47 = charset)
    _writeIppAttribute(builder, 0x47, 'attributes-charset', 'utf-8');
    // attributes-natural-language (tag 0x48 = naturalLanguage)
    _writeIppAttribute(builder, 0x48, 'attributes-natural-language', 'en');
    // printer-uri (tag 0x45 = uri)
    _writeIppAttribute(builder, 0x45, 'printer-uri', printerUri);

    // requested-attributes (1setOf keyword, tag 0x44)
    if (requestedAttributes.isNotEmpty) {
      _writeIppAttribute(
          builder, 0x44, 'requested-attributes', requestedAttributes.first);
      for (int i = 1; i < requestedAttributes.length; i++) {
        // Additional value in 1setOf has name-length = 0
        _writeIppAttribute(builder, 0x44, '', requestedAttributes[i]);
      }
    }

    // End-of-Attributes-Tag (0x03)
    builder.addByte(0x03);
    return builder.toBytes();
  }

  static void _writeIppAttribute(
    BytesBuilder builder,
    int valueTag,
    String name,
    String value,
  ) {
    final nameBytes = utf8.encode(name);
    final valBytes = utf8.encode(value);
    builder.addByte(valueTag);
    builder.add(_uint16BigEndian(nameBytes.length));
    builder.add(nameBytes);
    builder.add(_uint16BigEndian(valBytes.length));
    builder.add(valBytes);
  }

  /// Parses an RFC 8011 binary IPP response into [RawIppTelemetryPayload].
  static RawIppTelemetryPayload parseIppGetPrinterAttributesResponse(
      Uint8List bytes) {
    if (bytes.length < 9) {
      return RawIppTelemetryPayload.empty;
    }

    final statusCode = (bytes[2] << 8) | bytes[3];
    // IPP successful-ok is 0x0000 .. 0x00FF
    if (statusCode > 0x00FF) {
      return RawIppTelemetryPayload.empty;
    }

    int offset = 8;
    String currentAttrName = '';
    final stringLists = <String, List<String>>{};
    final intLists = <String, List<int>>{};

    while (offset < bytes.length) {
      final tag = bytes[offset++];
      if (tag == 0x03) {
        // end-of-attributes-tag
        break;
      }
      if (tag <= 0x0F) {
        // Delimiter tag (operation-attributes-tag 0x01, printer-attributes-tag 0x04, etc.)
        continue;
      }

      if (offset + 2 > bytes.length) break;
      final nameLen = (bytes[offset] << 8) | bytes[offset + 1];
      offset += 2;
      if (offset + nameLen > bytes.length) break;
      if (nameLen > 0) {
        currentAttrName =
            utf8.decode(bytes.sublist(offset, offset + nameLen), allowMalformed: true);
      }
      offset += nameLen;

      if (offset + 2 > bytes.length) break;
      final valLen = (bytes[offset] << 8) | bytes[offset + 1];
      offset += 2;
      if (offset + valLen > bytes.length) break;
      final valBytes = bytes.sublist(offset, offset + valLen);
      offset += valLen;

      if (currentAttrName.isEmpty) continue;

      // Integer (0x21) or Enum (0x23)
      if ((tag == 0x21 || tag == 0x23) && valBytes.length == 4) {
        final bd = ByteData.sublistView(valBytes);
        final intVal = bd.getInt32(0, Endian.big);
        intLists.putIfAbsent(currentAttrName, () => <int>[]).add(intVal);
      } else if (tag == 0x32 && valBytes.length == 9) {
        // Resolution tag (0x32): 4B cross-feed, 4B feed, 1B unit (3=dpi, 4=dpcm)
        final bd = ByteData.sublistView(valBytes);
        final xRes = bd.getInt32(0, Endian.big);
        final yRes = bd.getInt32(4, Endian.big);
        final unit = valBytes[8] == 3 ? 'dpi' : 'dpcm';
        stringLists
            .putIfAbsent(currentAttrName, () => <String>[])
            .add('${xRes}x$yRes $unit');
      } else {
        final strVal = utf8.decode(valBytes, allowMalformed: true).trim();
        if (strVal.isNotEmpty) {
          stringLists
              .putIfAbsent(currentAttrName, () => <String>[])
              .add(strVal);
        }
      }
    }

    final stateList = intLists['printer-state'];
    final impressionsList = intLists['printer-impressions-completed'];
    final fwList = stringLists['printer-firmware-string-version'];

    return RawIppTelemetryPayload(
      reachable: true,
      printerStateEnum:
          stateList != null && stateList.isNotEmpty ? stateList.first : null,
      stateReasons: stringLists['printer-state-reasons'] ?? const [],
      markerNames: stringLists['marker-names'] ?? const [],
      markerLevels: intLists['marker-levels'] ?? const [],
      markerColors: stringLists['marker-colors'] ?? const [],
      markerTypes: stringLists['marker-types'] ?? const [],
      markerLowLevels: intLists['marker-low-levels'] ?? const [],
      mediaSupported: stringLists['media-supported'] ?? const [],
      mediaReady: stringLists['media-ready'] ?? const [],
      mediaColDatabase: stringLists['media-col-database'] ?? const [],
      mediaTypeSupported: stringLists['media-type-supported'] ?? const [],
      sidesSupported: stringLists['sides-supported'] ?? const [],
      printColorModeSupported:
          stringLists['print-color-mode-supported'] ?? const [],
      printerResolutionSupported:
          stringLists['printer-resolution-supported'] ?? const [],
      outputBinSupported: stringLists['output-bin-supported'] ?? const [],
      printerAlert: stringLists['printer-alert'] ?? const [],
      firmwareVersion: fwList != null && fwList.isNotEmpty ? fwList.first : null,
      impressionsCompleted: impressionsList != null && impressionsList.isNotEmpty
          ? impressionsList.first
          : null,
    );
  }

  static Future<RawIppTelemetryPayload> _executeIppGetPrinterAttributes(
    String host,
    int port,
    Duration timeout, [
    String? authorizationHeader,
  ]) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final uri = Uri.parse('http://$host:$port/ipp/print');
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers
          .set(HttpHeaders.contentTypeHeader, 'application/ipp');
      if (authorizationHeader != null && authorizationHeader.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, authorizationHeader);
      }
      final packet = buildIppGetPrinterAttributesPacket(
        printerUri: 'ipp://$host:$port/ipp/print',
      );
      request.contentLength = packet.length;
      request.add(packet);

      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        return RawIppTelemetryPayload.empty;
      }
      final builder = BytesBuilder();
      await for (final chunk in response.timeout(timeout)) {
        builder.add(chunk);
      }
      return parseIppGetPrinterAttributesResponse(builder.toBytes());
    } catch (_) {
      return RawIppTelemetryPayload.empty;
    } finally {
      client.close(force: true);
    }
  }

  // ===========================================================================
  // SNMP v1/v2c (RFC 3805 Printer MIB) ASN.1 BER Packet Builder & Parser
  // ===========================================================================

  /// Builds a lightweight ASN.1 BER SNMP v2c `GetRequest` (`0xA0`) packet for a
  /// list of dotted OID strings.
  static Uint8List buildSnmpGetRequestPacket({
    required List<String> oids,
    String community = 'public',
    int requestId = 101,
  }) {
    final varbinds = BytesBuilder();
    for (final oid in oids) {
      final oidBytes = _encodeBerOid(oid);
      final nullValue = Uint8List.fromList([0x05, 0x00]); // NULL
      final seqContent = BytesBuilder()
        ..add(oidBytes)
        ..add(nullValue);
      varbinds.add(_wrapBerTl(0x30, seqContent.toBytes()));
    }
    final varbindList = _wrapBerTl(0x30, varbinds.toBytes());

    final pduBody = BytesBuilder()
      ..add(_encodeBerInt(requestId)) // request-id
      ..add(_encodeBerInt(0)) // error-status = 0
      ..add(_encodeBerInt(0)) // error-index = 0
      ..add(varbindList);

    final getRequestPdu = _wrapBerTl(0xA0, pduBody.toBytes());
    final commBytes = utf8.encode(community);
    final messageBody = BytesBuilder()
      ..add(_encodeBerInt(1)) // version = 1 (SNMPv2c)
      ..add(_wrapBerTl(0x04, Uint8List.fromList(commBytes)))
      ..add(getRequestPdu);

    return _wrapBerTl(0x30, messageBody.toBytes());
  }

  /// Parses an ASN.1 BER SNMP `GetResponse` (`0xA2`) packet into a map of
  /// `OID -> Object` (`int` or `String`).
  static Map<String, Object> parseSnmpGetResponsePacket(Uint8List packet) {
    final result = <String, Object>{};
    if (packet.length < 10 || packet[0] != 0x30) {
      return result;
    }

    try {
      int idx = 0;
      final topSeq = _readBerTl(packet, idx);
      idx = topSeq.valueOffset;

      // Skip version
      final ver = _readBerTl(packet, idx);
      idx = ver.valueOffset + ver.length;

      // Skip community
      final comm = _readBerTl(packet, idx);
      idx = comm.valueOffset + comm.length;

      // Read GetResponse PDU (0xA2)
      final pdu = _readBerTl(packet, idx);
      if (pdu.tag != 0xA2) return result;
      idx = pdu.valueOffset;

      // Skip request-id, error-status, error-index
      for (int i = 0; i < 3; i++) {
        final field = _readBerTl(packet, idx);
        idx = field.valueOffset + field.length;
      }

      // Varbind list (0x30)
      final vbList = _readBerTl(packet, idx);
      idx = vbList.valueOffset;
      final vbEnd = vbList.valueOffset + vbList.length;

      while (idx < vbEnd && idx < packet.length) {
        final vb = _readBerTl(packet, idx);
        int inner = vb.valueOffset;
        final oidField = _readBerTl(packet, inner);
        final oidStr = _decodeBerOid(
          packet.sublist(
              oidField.valueOffset, oidField.valueOffset + oidField.length),
        );
        inner = oidField.valueOffset + oidField.length;

        final valField = _readBerTl(packet, inner);
        final valBytes = packet.sublist(
            valField.valueOffset, valField.valueOffset + valField.length);

        if (valField.tag == 0x02 ||
            valField.tag == 0x41 ||
            valField.tag == 0x42) {
          // INTEGER, Counter32, Gauge32
          result[oidStr] = _decodeBerSignedInt(valBytes);
        } else if (valField.tag == 0x04) {
          // OCTET STRING
          result[oidStr] =
              utf8.decode(valBytes, allowMalformed: true).trim();
        }
        idx = vb.valueOffset + vb.length;
      }
    } catch (_) {
      return result;
    }

    return result;
  }

  static Future<RawSnmpTelemetryPayload> _executeSnmpPrinterMibQuery(
    String host,
    int port,
    String community,
    Duration timeout,
  ) async {
    RawDatagramSocket? socket;
    try {
      final addresses = await InternetAddress.lookup(host).timeout(timeout);
      if (addresses.isEmpty) return RawSnmpTelemetryPayload.empty;
      final targetAddr = addresses.first;

      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final oidsToQuery = <String>[
        StandardPrinterMibOids.hrPrinterStatus,
        StandardPrinterMibOids.prtMarkerLifeCount,
        for (int i = 1; i <= 5; i++) ...[
          '${StandardPrinterMibOids.prtMarkerSuppliesDescriptionPrefix}$i',
          '${StandardPrinterMibOids.prtMarkerSuppliesMaxCapacityPrefix}$i',
          '${StandardPrinterMibOids.prtMarkerSuppliesLevelPrefix}$i',
        ],
        for (int i = 1; i <= 2; i++) ...[
          '${StandardPrinterMibOids.prtInputNamePrefix}$i',
          '${StandardPrinterMibOids.prtInputMediaNamePrefix}$i',
          '${StandardPrinterMibOids.prtInputMediaTypePrefix}$i',
          '${StandardPrinterMibOids.prtInputMaxCapacityPrefix}$i',
          '${StandardPrinterMibOids.prtInputCurrentLevelPrefix}$i',
        ],
        '${StandardPrinterMibOids.prtAlertDescriptionPrefix}1',
      ];

      final completer = Completer<Uint8List?>();
      final sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && !completer.isCompleted) {
            completer.complete(dg.data);
          }
        }
      });

      final reqPacket = buildSnmpGetRequestPacket(
        oids: oidsToQuery,
        community: community,
      );
      socket.send(reqPacket, targetAddr, port);

      final responseBytes = await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
      await sub.cancel();

      if (responseBytes == null) {
        return RawSnmpTelemetryPayload.empty;
      }

      final map = parseSnmpGetResponsePacket(responseBytes);
      if (map.isEmpty) {
        return RawSnmpTelemetryPayload.empty;
      }

      final supplies = <SnmpSupplyRow>[];
      for (int i = 1; i <= 5; i++) {
        final desc =
            map['${StandardPrinterMibOids.prtMarkerSuppliesDescriptionPrefix}$i']
                as String?;
        final maxCap =
            map['${StandardPrinterMibOids.prtMarkerSuppliesMaxCapacityPrefix}$i']
                as int?;
        final level =
            map['${StandardPrinterMibOids.prtMarkerSuppliesLevelPrefix}$i']
                as int?;
        if (desc != null && desc.isNotEmpty) {
          supplies.add(
            SnmpSupplyRow(
              index: i,
              description: desc,
              maxCapacity: maxCap ?? 100,
              level: level ?? -2,
            ),
          );
        }
      }

      final trays = <SnmpInputTrayRow>[];
      for (int i = 1; i <= 2; i++) {
        final name =
            map['${StandardPrinterMibOids.prtInputNamePrefix}$i'] as String?;
        final mediaName =
            map['${StandardPrinterMibOids.prtInputMediaNamePrefix}$i']
                as String?;
        final mediaType =
            map['${StandardPrinterMibOids.prtInputMediaTypePrefix}$i']
                as String?;
        final maxCap =
            map['${StandardPrinterMibOids.prtInputMaxCapacityPrefix}$i']
                as int?;
        final curLevel =
            map['${StandardPrinterMibOids.prtInputCurrentLevelPrefix}$i']
                as int?;
        if ((name != null && name.isNotEmpty) ||
            (mediaName != null && mediaName.isNotEmpty)) {
          trays.add(
            SnmpInputTrayRow(
              index: i,
              name: name ?? 'Tray $i',
              mediaName: mediaName ?? '',
              mediaType: mediaType ?? '',
              maxCapacity: maxCap ?? -2,
              currentLevel: curLevel ?? -2,
            ),
          );
        }
      }

      final alerts = <String>[];
      final alert1 =
          map['${StandardPrinterMibOids.prtAlertDescriptionPrefix}1']
              as String?;
      if (alert1 != null && alert1.isNotEmpty) {
        alerts.add(alert1);
      }

      return RawSnmpTelemetryPayload(
        reachable: true,
        hrPrinterStatus: map[StandardPrinterMibOids.hrPrinterStatus] as int?,
        prtMarkerLifeCount:
            map[StandardPrinterMibOids.prtMarkerLifeCount] as int?,
        supplies: supplies,
        inputTrays: trays,
        alertDescriptions: alerts,
      );
    } catch (_) {
      return RawSnmpTelemetryPayload.empty;
    } finally {
      socket?.close();
    }
  }

  // ===========================================================================
  // Priority 3: Windows Spooler APIs via Win32 FFI (`DeviceCapabilitiesW`)
  // ===========================================================================

  /// Queries Windows Spooler `DeviceCapabilitiesW` (`DC_DUPLEX`, `DC_PAPERS`,
  /// `DC_PAPERNAMES`, `DC_BINS`, `DC_BINNAMES`, `DC_MEDIATYPES`,
  /// `DC_MEDIATYPENAMES`, `DC_ORIENTATION`, `DC_COLORDEVICE`) when running on
  /// Windows.
  static RawWin32SpoolerPayload collectWin32SpoolerCapabilities(
      String printerSystemName) {
    if (!Platform.isWindows) {
      return RawWin32SpoolerPayload.empty;
    }

    return using((arena) {
      try {
        final winspool = ffi.DynamicLibrary.open('winspool.drv');
        final deviceCapabilities = winspool.lookupFunction<
            _WinspoolDeviceCapabilitiesNative,
            _WinspoolDeviceCapabilitiesDart>('DeviceCapabilitiesW');

        final pPrinterName = printerSystemName.toNativeUtf16(allocator: arena);
        final pPort = ''.toNativeUtf16(allocator: arena);

        // Win32 DeviceCapabilitiesW constants (wingdi.h)
        const int dcDuplex = 7;
        const int dcOrientation = 17;
        const int dcPaperNames = 16;
        const int dcBinNames = 12;
        const int dcMediaTypeNames = 34;
        const int dcColorDevice = 32;

        final duplexRes = deviceCapabilities(
            pPrinterName, pPort, dcDuplex, ffi.nullptr, ffi.nullptr);
        final orientRes = deviceCapabilities(
            pPrinterName, pPort, dcOrientation, ffi.nullptr, ffi.nullptr);
        final colorRes = deviceCapabilities(
            pPrinterName, pPort, dcColorDevice, ffi.nullptr, ffi.nullptr);

        // Paper names (each entry is 64 UTF-16 chars)
        final paperNames = <String>[];
        final paperCount = deviceCapabilities(
            pPrinterName, pPort, dcPaperNames, ffi.nullptr, ffi.nullptr);
        if (paperCount > 0 && paperCount < 512) {
          final buf = arena<ffi.Uint16>(paperCount * 64);
          final copied = deviceCapabilities(
              pPrinterName, pPort, dcPaperNames, buf.cast(), ffi.nullptr);
          for (int i = 0; i < copied; i++) {
            final ptr = (buf + (i * 64)).cast<Utf16>();
            final name = ptr.toDartString().trim();
            if (name.isNotEmpty) paperNames.add(name);
          }
        }

        // Bin / tray names (each entry is 24 UTF-16 chars)
        final binNames = <String>[];
        final binCount = deviceCapabilities(
            pPrinterName, pPort, dcBinNames, ffi.nullptr, ffi.nullptr);
        if (binCount > 0 && binCount < 128) {
          final buf = arena<ffi.Uint16>(binCount * 24);
          final copied = deviceCapabilities(
              pPrinterName, pPort, dcBinNames, buf.cast(), ffi.nullptr);
          for (int i = 0; i < copied; i++) {
            final ptr = (buf + (i * 24)).cast<Utf16>();
            final name = ptr.toDartString().trim();
            if (name.isNotEmpty) binNames.add(name);
          }
        }

        // Media type names (each entry is 64 UTF-16 chars)
        final mediaNames = <String>[];
        final mediaCount = deviceCapabilities(
            pPrinterName, pPort, dcMediaTypeNames, ffi.nullptr, ffi.nullptr);
        if (mediaCount > 0 && mediaCount < 256) {
          final buf = arena<ffi.Uint16>(mediaCount * 64);
          final copied = deviceCapabilities(
              pPrinterName, pPort, dcMediaTypeNames, buf.cast(), ffi.nullptr);
          for (int i = 0; i < copied; i++) {
            final ptr = (buf + (i * 64)).cast<Utf16>();
            final name = ptr.toDartString().trim();
            if (name.isNotEmpty) mediaNames.add(name);
          }
        }

        return RawWin32SpoolerPayload(
          available: true,
          supportsDuplex: duplexRes >= 0 ? (duplexRes == 1) : null,
          supportsColor: colorRes >= 0 ? (colorRes == 1) : null,
          landscapeOrientationDegrees: orientRes >= 0 ? orientRes : null,
          paperNames: paperNames,
          binNames: binNames,
          mediaTypeNames: mediaNames,
        );
      } catch (_) {
        return RawWin32SpoolerPayload.empty;
      }
    });
  }

  static RawWin32SpoolerPayload _buildWin32FallbackFromPrinterDevice(
      PrinterDevice printer) {
    final cap = printer.capabilities;
    final paperNames = cap.paperSizes.map((p) => p.name).toList();
    final binNames = cap.trays.map((t) => t.name).toList();
    return RawWin32SpoolerPayload(
      available: true,
      supportsDuplex: cap.supportsDuplex,
      supportsColor: cap.supportsColor,
      paperNames: paperNames,
      binNames: binNames,
      mediaTypeNames: const ['Plain Paper', 'Photo Paper', 'Thick Paper'],
      landscapeOrientationDegrees: 90,
      defaultPaperName: paperNames.isNotEmpty ? paperNames.first : 'A4',
      maxDpiX: cap.maxResolution.xdpi,
      maxDpiY: cap.maxResolution.ydpi,
    );
  }

  // ===========================================================================
  // Priority 4: Consented Epson Web Config Fallback Parser
  // ===========================================================================

  static Future<RawWebConfigFallbackPayload> _executeWebConfigFallbackFetch(
    String host,
    int port,
    Duration timeout,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..badCertificateCallback = (_, __, ___) => true;
    try {
      final uri =
          Uri.parse('http://$host:$port/PRESENTATION/HTML/TOP/PRTINFO.HTML');
      final req = await client.getUrl(uri).timeout(timeout);
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode != 200) {
        return RawWebConfigFallbackPayload.empty;
      }
      final body = await resp.transform(utf8.decoder).join().timeout(timeout);
      return parseEpsonWebConfigHtmlDefensively(body);
    } catch (_) {
      return RawWebConfigFallbackPayload.empty;
    } finally {
      client.close(force: true);
    }
  }

  /// Defensively extracts Firmware Version, Total Pages, and Maintenance Box status
  /// from an Epson Web Config HTML snippet without guessing missing fields.
  static RawWebConfigFallbackPayload parseEpsonWebConfigHtmlDefensively(
      String html) {
    if (html.trim().isEmpty) return RawWebConfigFallbackPayload.empty;

    String? fw;
    final fwMatch = RegExp(
      r'Firmware(?:\s+Version)?\s*[:<\/td>\s]*([A-Z0-9._-]{4,20})',
      caseSensitive: false,
    ).firstMatch(html);
    if (fwMatch != null) {
      fw = fwMatch.group(1);
    }

    int? totalPages;
    final pageMatch = RegExp(
      r'Total\s+Number\s+of\s+Pages\s*[:<\/td>\s]*(\d+)',
      caseSensitive: false,
    ).firstMatch(html);
    if (pageMatch != null) {
      totalPages = int.tryParse(pageMatch.group(1) ?? '');
    }

    String? maintStatus;
    final maintMatch = RegExp(
      r'Maintenance\s+Box\s*[:<\/td>\s]*(Available|OK|Near\s+Full|Full|\d+%)',
      caseSensitive: false,
    ).firstMatch(html);
    if (maintMatch != null) {
      maintStatus = maintMatch.group(1);
    }

    return RawWebConfigFallbackPayload(
      reachable: fw != null || totalPages != null || maintStatus != null,
      firmwareVersion: fw,
      totalPagesPrinted: totalPages,
      maintenanceBoxStatus: maintStatus,
    );
  }

  // ===========================================================================
  // Internal Mapping & Normalization Helpers
  // ===========================================================================

  static String? _extractHostOrIp(String portName) {
    final ipv4Match =
        RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})').firstMatch(portName);
    if (ipv4Match != null) {
      return ipv4Match.group(1);
    }
    if (portName.toLowerCase().contains('localhost')) {
      return '127.0.0.1';
    }
    return null;
  }

  static SourcedPrinterField<LivePrinterState> _mapIppState(
    RawIppTelemetryPayload ipp,
    DateTime now,
  ) {
    if (!ipp.reachable || ipp.printerStateEnum == null) {
      return SourcedPrinterField<LivePrinterState>.notReported('printer-state');
    }
    final state = switch (ipp.printerStateEnum) {
      3 => LivePrinterState.ready,
      4 => LivePrinterState.printing,
      5 => ipp.stateReasons.any((r) => r.contains('paused'))
          ? LivePrinterState.paused
          : LivePrinterState.error,
      _ => LivePrinterState.ready,
    };
    return SourcedPrinterField<LivePrinterState>.reported(
      value: state,
      source: PrinterTelemetrySource.ipp,
      confidence: TelemetryConfidence.high,
      rawAttributeKey: 'printer-state',
      observedAt: now,
    );
  }

  static SourcedPrinterField<LivePrinterState> _mapSnmpState(
    RawSnmpTelemetryPayload snmp,
    DateTime now,
  ) {
    if (!snmp.reachable || snmp.hrPrinterStatus == null) {
      return SourcedPrinterField<LivePrinterState>.notReported(
          'hrPrinterStatus');
    }
    final state = switch (snmp.hrPrinterStatus) {
      3 => LivePrinterState.ready,
      4 => LivePrinterState.printing,
      5 => LivePrinterState.ready,
      _ => LivePrinterState.ready,
    };
    return SourcedPrinterField<LivePrinterState>.reported(
      value: state,
      source: PrinterTelemetrySource.snmp,
      confidence: TelemetryConfidence.high,
      rawAttributeKey: 'hrPrinterStatus',
      observedAt: now,
    );
  }

  static SourcedPrinterField<LivePrinterState> _mapWin32State(
    RawWin32SpoolerPayload win32,
    PrinterDevice printer,
    DateTime now,
  ) {
    final mapped = switch (printer.status) {
      PrinterStatusType.ready => LivePrinterState.ready,
      PrinterStatusType.busy => LivePrinterState.printing,
      PrinterStatusType.paused => LivePrinterState.paused,
      PrinterStatusType.offline => LivePrinterState.offline,
      PrinterStatusType.outOfPaper ||
      PrinterStatusType.paperJam ||
      PrinterStatusType.doorOpen ||
      PrinterStatusType.error =>
        LivePrinterState.error,
      PrinterStatusType.tonerLow => LivePrinterState.ready,
    };
    return SourcedPrinterField<LivePrinterState>.reported(
      value: mapped,
      source: PrinterTelemetrySource.windowsSpooler,
      confidence: TelemetryConfidence.medium,
      rawAttributeKey: 'PRINTER_INFO_2.Status',
      observedAt: now,
    );
  }

  /// Translates IPP `printer-state-reasons` keywords (RFC 8011) and SNMP alerts
  /// into plain-language problems for the Status Header.
  static List<PlainLanguagePrinterProblem> _translateProblemsToPlainLanguage({
    required RawIppTelemetryPayload ipp,
    required RawSnmpTelemetryPayload snmp,
    required RawWin32SpoolerPayload win32,
    required PrinterDevice printer,
  }) {
    final problems = <PlainLanguagePrinterProblem>[];
    final seenCodes = <String>{};

    for (final rawReason in ipp.stateReasons) {
      final cleaned = rawReason
          .replaceAll('-error', '')
          .replaceAll('-warning', '')
          .replaceAll('-report', '')
          .trim()
          .toLowerCase();
      if (cleaned.isEmpty || cleaned == 'none') continue;
      if (!seenCodes.add(cleaned)) continue;

      switch (cleaned) {
        case 'media-jam':
          problems.add(
            const PlainLanguagePrinterProblem(
              rawCode: 'media-jam',
              titleEn: 'Paper jam in tray',
              titleSi: 'කඩදාසි තැටියේ කොළයක් සිරවී ඇත (Paper jam)',
              detailEn:
                  'Open the rear cover or paper cassette, gently remove the jammed sheet, and press Resume on the printer.',
              detailSi:
                  'පසුපස පියන හෝ කඩදාසි තැටිය විවෘත කර සිරවී ඇති කොළය ප්‍රවේශමෙන් ඉවත් කරන්න.',
              isHardStopBlockingError: true,
              source: PrinterTelemetrySource.ipp,
              confidence: TelemetryConfidence.high,
            ),
          );
        case 'cover-open':
        case 'door-open':
        case 'interlock-open':
          problems.add(
            PlainLanguagePrinterProblem(
              rawCode: cleaned,
              titleEn: 'Cover open',
              titleSi: 'මුද්‍රණ යන්ත්‍රයේ පියන විවෘතව ඇත (Cover open)',
              detailEn:
                  'Close the printer scanner unit or top cover completely before printing.',
              detailSi:
                  'මුද්‍රණය කිරීමට පෙර මුද්‍රණ යන්ත්‍රයේ ඉහළ පියන සම්පූර්ණයෙන්ම වසන්න.',
              isHardStopBlockingError: true,
              source: PrinterTelemetrySource.ipp,
              confidence: TelemetryConfidence.high,
            ),
          );
        case 'media-empty':
        case 'media-needed':
          problems.add(
            PlainLanguagePrinterProblem(
              rawCode: cleaned,
              titleEn: 'Out of paper',
              titleSi: 'කඩදාසි අවසන් වී ඇත (Out of paper)',
              detailEn:
                  'Load paper into the active input tray and confirm the paper size on the printer.',
              detailSi:
                  'කඩදාසි තැටියට කොළ ඇතුළු කර ප්‍රමාණය තහවුරු කරන්න.',
              isHardStopBlockingError: true,
              source: PrinterTelemetrySource.ipp,
              confidence: TelemetryConfidence.high,
            ),
          );
        case 'marker-supply-low':
        case 'toner-low':
          final lowNames = _findLowSupplyNamesFromIpp(ipp);
          final suffix = lowNames.isNotEmpty ? ': ${lowNames.join(", ")}' : '';
          problems.add(
            PlainLanguagePrinterProblem(
              rawCode: cleaned,
              titleEn: 'Ink low$suffix',
              titleSi: 'තීන්ත මට්ටම අඩුයි$suffix',
              detailEn:
                  'You can continue printing normally; keep a replacement supply ready if streaks appear.',
              detailSi:
                  'ඔබට සාමාන්‍ය පරිදි මුද්‍රණය කළ හැක; තීන්ත අඩු වුවද මුද්‍රණය අවහිර නොවේ.',
              isHardStopBlockingError: false, // Never block on low ink
              source: PrinterTelemetrySource.ipp,
              confidence: TelemetryConfidence.high,
            ),
          );
        case 'marker-supply-empty':
        case 'toner-empty':
          final emptyNames = _findEmptySupplyNamesFromIpp(ipp);
          final suffix =
              emptyNames.isNotEmpty ? ': ${emptyNames.join(", ")}' : '';
          problems.add(
            PlainLanguagePrinterProblem(
              rawCode: cleaned,
              titleEn: 'Supply empty$suffix',
              titleSi: 'තීන්ත / ටෝනර් අවසන් වී ඇත$suffix',
              detailEn:
                  'Refill the ink tank or replace the cartridge if the printer pauses the job.',
              detailSi: 'තීන්ත ටැංකිය පුරවන්න හෝ කාට්රිජය මාරු කරන්න.',
              isHardStopBlockingError: false,
              source: PrinterTelemetrySource.ipp,
              confidence: TelemetryConfidence.high,
            ),
          );
        case 'marker-waste-almost-full':
          problems.add(
            const PlainLanguagePrinterProblem(
              rawCode: 'marker-waste-almost-full',
              titleEn: 'Maintenance box near full',
              titleSi: 'නඩත්තු කොටුව (Maintenance Box) පිරීමට ආසන්නයි',
              detailEn:
                  'Printing can continue, but a replacement Maintenance Box will be needed soon.',
              detailSi:
                  'මුද්‍රණය දිගටම කළ හැක, නමුත් ඉක්මනින් නව නඩත්තු කොටුවක් අවශ්‍ය වේ.',
              isHardStopBlockingError: false,
              source: PrinterTelemetrySource.ipp,
              confidence: TelemetryConfidence.high,
            ),
          );
        case 'marker-waste-full':
          problems.add(
            const PlainLanguagePrinterProblem(
              rawCode: 'marker-waste-full',
              titleEn: 'Maintenance box full',
              titleSi: 'නඩත්තු කොටුව (Maintenance Box) සම්පූර්ණයෙන්ම පිරී ඇත',
              detailEn:
                  'Replace the Maintenance Box / Waste Ink Pad to resume printing.',
              detailSi:
                  'මුද්‍රණය නැවත ආරම්භ කිරීමට නඩත්තු කොටුව මාරු කරන්න.',
              isHardStopBlockingError: true,
              source: PrinterTelemetrySource.ipp,
              confidence: TelemetryConfidence.high,
            ),
          );
      }
    }

    // Fallback to SNMP alerts if IPP did not report state reasons
    if (problems.isEmpty && snmp.reachable) {
      for (final alert in snmp.alertDescriptions) {
        final lower = alert.toLowerCase();
        if (lower.contains('jam')) {
          problems.add(
            PlainLanguagePrinterProblem(
              rawCode: 'snmp_jam',
              titleEn: 'Paper jam reported ($alert)',
              titleSi: 'කොළයක් සිරවී ඇත ($alert)',
              detailEn: 'Clear the jammed paper from the printer path.',
              detailSi: 'මුද්‍රණ යන්ත්‍රයේ සිරවී ඇති කොළය ඉවත් කරන්න.',
              isHardStopBlockingError: true,
              source: PrinterTelemetrySource.snmp,
              confidence: TelemetryConfidence.high,
            ),
          );
        } else if (lower.contains('cover') || lower.contains('door')) {
          problems.add(
            PlainLanguagePrinterProblem(
              rawCode: 'snmp_cover_open',
              titleEn: 'Cover open ($alert)',
              titleSi: 'පියන විවෘතව ඇත ($alert)',
              detailEn: 'Close the printer cover completely.',
              detailSi: 'මුද්‍රණ යන්ත්‍රයේ පියන හොඳින් වසන්න.',
              isHardStopBlockingError: true,
              source: PrinterTelemetrySource.snmp,
              confidence: TelemetryConfidence.high,
            ),
          );
        }
      }
    }

    // Fallback to Win32 health status if offline
    if (printer.status == PrinterStatusType.offline &&
        !ipp.reachable &&
        !snmp.reachable) {
      problems.add(
        const PlainLanguagePrinterProblem(
          rawCode: 'win32_offline',
          titleEn: 'Printer is offline',
          titleSi: 'මුද්‍රණ යන්ත්‍රය විසන්ධි වී ඇත (Offline)',
          detailEn:
              'Check that the printer power is turned on and the USB cable or Wi-Fi network is connected.',
          detailSi:
              'මුද්‍රණ යන්ත්‍රය ක්‍රියාත්මක කර ඇති බවත් USB හෝ Wi-Fi සම්බන්ධතාවය නිවැරදි බවත් පරීක්ෂා කරන්න.',
          isHardStopBlockingError: true,
          source: PrinterTelemetrySource.windowsSpooler,
          confidence: TelemetryConfidence.medium,
        ),
      );
    }

    return problems;
  }

  static List<String> _findLowSupplyNamesFromIpp(RawIppTelemetryPayload ipp) {
    final names = <String>[];
    for (int i = 0; i < ipp.markerNames.length; i++) {
      final level = i < ipp.markerLevels.length ? ipp.markerLevels[i] : -2;
      final low = i < ipp.markerLowLevels.length ? ipp.markerLowLevels[i] : 15;
      if (level > 0 && level <= low) {
        names.add(ipp.markerNames[i]);
      }
    }
    return names;
  }

  static List<String> _findEmptySupplyNamesFromIpp(RawIppTelemetryPayload ipp) {
    final names = <String>[];
    for (int i = 0; i < ipp.markerNames.length; i++) {
      final level = i < ipp.markerLevels.length ? ipp.markerLevels[i] : -2;
      if (level == 0) {
        names.add(ipp.markerNames[i]);
      }
    }
    return names;
  }

  static SupplyTechnologyKind _inferSupplyKindFromMarkers(
    List<String> ippTypes,
    List<SnmpSupplyRow> snmpSupplies,
  ) {
    if (ippTypes.any((t) => t.toLowerCase().contains('toner')) ||
        snmpSupplies
            .any((s) => s.description.toLowerCase().contains('toner'))) {
      return SupplyTechnologyKind.toner;
    }
    return SupplyTechnologyKind.ink;
  }

  static SourcedPrinterField<List<SupplyMarkerInfo>> _buildIppSupplies({
    required RawIppTelemetryPayload ipp,
    required RawSnmpTelemetryPayload snmp,
    required SupplyTechnologyKind primaryKind,
    required DateTime now,
  }) {
    if (!ipp.reachable || ipp.markerNames.isEmpty) {
      return SourcedPrinterField<List<SupplyMarkerInfo>>.notReported(
          'marker-names');
    }

    final markers = <SupplyMarkerInfo>[];
    final hasLowReason = ipp.stateReasons
        .any((r) => r.toLowerCase().contains('marker-supply-low'));

    for (int i = 0; i < ipp.markerNames.length; i++) {
      final name = ipp.markerNames[i];
      final rawLevel = i < ipp.markerLevels.length ? ipp.markerLevels[i] : -2;
      final colorHex =
          i < ipp.markerColors.length ? ipp.markerColors[i] : '#1E293B';
      final rawType = i < ipp.markerTypes.length ? ipp.markerTypes[i] : '';
      final lowThreshold =
          i < ipp.markerLowLevels.length ? ipp.markerLowLevels[i] : 15;

      final kind = _classifyMarkerSupplyKind(name, rawType, primaryKind);

      // RFC 8011 / RFC 3805 semantics:
      // 0..100 -> exact percentage
      // -3 -> some remaining (OK, common on Epson EcoTank bottles)
      // -2 -> unknown ("Not reported by this printer")
      final SourcedPrinterField<int> levelField;
      final SourcedPrinterField<QualitativeSupplyStatus> qualField;

      if (rawLevel >= 0 && rawLevel <= 100) {
        levelField = SourcedPrinterField<int>.reported(
          value: rawLevel,
          source: PrinterTelemetrySource.ipp,
          confidence: TelemetryConfidence.high,
          rawAttributeKey: 'marker-levels[$i]',
          observedAt: now,
        );
        final qual = rawLevel == 0
            ? QualitativeSupplyStatus.empty
            : (rawLevel <= lowThreshold
                ? QualitativeSupplyStatus.low
                : QualitativeSupplyStatus.ok);
        qualField = SourcedPrinterField<QualitativeSupplyStatus>.reported(
          value: qual,
          source: PrinterTelemetrySource.ipp,
          confidence: TelemetryConfidence.high,
          rawAttributeKey: 'marker-levels[$i]',
          observedAt: now,
        );
      } else if (rawLevel == -3) {
        // Level is explicitly reported as "OK / Some remaining" without %
        levelField = SourcedPrinterField<int>.notReported('marker-levels[$i]');
        qualField = SourcedPrinterField<QualitativeSupplyStatus>.reported(
          value: hasLowReason
              ? QualitativeSupplyStatus.low
              : QualitativeSupplyStatus.ok,
          source: PrinterTelemetrySource.ipp,
          confidence: TelemetryConfidence.medium,
          rawAttributeKey: 'marker-levels[$i]=-3',
          observedAt: now,
        );
      } else {
        levelField = SourcedPrinterField<int>.notReported('marker-levels[$i]');
        qualField =
            SourcedPrinterField<QualitativeSupplyStatus>.notReported(
                'marker-levels[$i]');
      }

      // Estimated pages remaining ONLY if SNMP reports a real sheet/yield maxCapacity > 100
      SourcedPrinterField<int> estPages =
          SourcedPrinterField<int>.notReported('prtMarkerSuppliesMaxCapacity');
      if (rawLevel >= 0 && rawLevel <= 100 && snmp.reachable) {
        final snmpMatch = snmp.supplies
            .where((s) =>
                s.description.toLowerCase().contains(name.toLowerCase()) ||
                s.index == i + 1)
            .firstOrNull;
        if (snmpMatch != null && snmpMatch.maxCapacity > 100) {
          final est = ((snmpMatch.maxCapacity * rawLevel) / 100.0).round();
          estPages = SourcedPrinterField<int>.reported(
            value: est,
            source: PrinterTelemetrySource.snmp,
            confidence: TelemetryConfidence.low,
            rawAttributeKey:
                'prtMarkerSuppliesMaxCapacity*marker-levels (estimate)',
            observedAt: now,
          );
        }
      }

      markers.add(
        SupplyMarkerInfo(
          name: name,
          colorHex: colorHex,
          supplyKind: kind,
          levelPercent: levelField,
          qualitativeStatus: qualField,
          lowThresholdPercent: lowThreshold,
          estimatedPagesRemaining: estPages,
        ),
      );
    }

    return SourcedPrinterField<List<SupplyMarkerInfo>>.reported(
      value: markers,
      source: PrinterTelemetrySource.ipp,
      confidence: TelemetryConfidence.high,
      rawAttributeKey: 'marker-names/marker-levels',
      observedAt: now,
    );
  }

  static SourcedPrinterField<List<SupplyMarkerInfo>> _buildSnmpSupplies({
    required RawSnmpTelemetryPayload snmp,
    required SupplyTechnologyKind primaryKind,
    required DateTime now,
  }) {
    if (!snmp.reachable || snmp.supplies.isEmpty) {
      return SourcedPrinterField<List<SupplyMarkerInfo>>.notReported(
          'prtMarkerSuppliesTable');
    }

    final markers = <SupplyMarkerInfo>[];
    for (final row in snmp.supplies) {
      final kind =
          _classifyMarkerSupplyKind(row.description, '', primaryKind);
      SourcedPrinterField<int> levelField =
          SourcedPrinterField<int>.notReported('prtMarkerSuppliesLevel');
      SourcedPrinterField<QualitativeSupplyStatus> qualField =
          SourcedPrinterField<QualitativeSupplyStatus>.notReported(
              'prtMarkerSuppliesLevel');
      SourcedPrinterField<int> estPages =
          SourcedPrinterField<int>.notReported('prtMarkerSuppliesMaxCapacity');

      if (row.level >= 0 && row.maxCapacity > 0) {
        final pct = ((row.level / row.maxCapacity) * 100.0).clamp(0, 100).round();
        levelField = SourcedPrinterField<int>.reported(
          value: pct,
          source: PrinterTelemetrySource.snmp,
          confidence: TelemetryConfidence.high,
          rawAttributeKey: 'prtMarkerSuppliesLevel.${row.index}',
          observedAt: now,
        );
        qualField = SourcedPrinterField<QualitativeSupplyStatus>.reported(
          value: pct == 0
              ? QualitativeSupplyStatus.empty
              : (pct <= 15
                  ? QualitativeSupplyStatus.low
                  : QualitativeSupplyStatus.ok),
          source: PrinterTelemetrySource.snmp,
          confidence: TelemetryConfidence.high,
          rawAttributeKey: 'prtMarkerSuppliesLevel.${row.index}',
          observedAt: now,
        );
        if (row.maxCapacity > 100) {
          estPages = SourcedPrinterField<int>.reported(
            value: row.level,
            source: PrinterTelemetrySource.snmp,
            confidence: TelemetryConfidence.low,
            rawAttributeKey: 'prtMarkerSuppliesLevel (estimate)',
            observedAt: now,
          );
        }
      } else if (row.level == -3) {
        qualField = SourcedPrinterField<QualitativeSupplyStatus>.reported(
          value: QualitativeSupplyStatus.ok,
          source: PrinterTelemetrySource.snmp,
          confidence: TelemetryConfidence.medium,
          rawAttributeKey: 'prtMarkerSuppliesLevel.${row.index}=-3',
          observedAt: now,
        );
      }

      markers.add(
        SupplyMarkerInfo(
          name: row.description,
          colorHex: '',
          supplyKind: kind,
          levelPercent: levelField,
          qualitativeStatus: qualField,
          estimatedPagesRemaining: estPages,
        ),
      );
    }

    return SourcedPrinterField<List<SupplyMarkerInfo>>.reported(
      value: markers,
      source: PrinterTelemetrySource.snmp,
      confidence: TelemetryConfidence.high,
      rawAttributeKey: 'prtMarkerSuppliesTable',
      observedAt: now,
    );
  }

  static SourcedPrinterField<List<SupplyMarkerInfo>> _buildWebConfigSupplies({
    required RawWebConfigFallbackPayload web,
    required bool consented,
    required SupplyTechnologyKind primaryKind,
    required DateTime now,
  }) {
    if (!consented || !web.reachable || web.qualitativeSupplies.isEmpty) {
      return SourcedPrinterField<List<SupplyMarkerInfo>>.notReported(
          'web_config.supplies');
    }
    final list = <SupplyMarkerInfo>[];
    for (final entry in web.qualitativeSupplies.entries) {
      final lower = entry.value.toLowerCase();
      final qual = lower.contains('empty')
          ? QualitativeSupplyStatus.empty
          : (lower.contains('low')
              ? QualitativeSupplyStatus.low
              : QualitativeSupplyStatus.ok);
      list.add(
        SupplyMarkerInfo(
          name: entry.key,
          colorHex: '',
          supplyKind: primaryKind,
          levelPercent:
              SourcedPrinterField<int>.notReported('web_config.level'),
          qualitativeStatus:
              SourcedPrinterField<QualitativeSupplyStatus>.reported(
            value: qual,
            source: PrinterTelemetrySource.webConfigFallback,
            confidence: TelemetryConfidence.low,
            rawAttributeKey: 'web_config.${entry.key}',
            observedAt: now,
          ),
          estimatedPagesRemaining:
              SourcedPrinterField<int>.notReported('web_config.pages'),
        ),
      );
    }
    return SourcedPrinterField<List<SupplyMarkerInfo>>.reported(
      value: list,
      source: PrinterTelemetrySource.webConfigFallback,
      confidence: TelemetryConfidence.low,
      rawAttributeKey: 'web_config.supplies',
      observedAt: now,
    );
  }

  static SupplyTechnologyKind _classifyMarkerSupplyKind(
    String name,
    String rawType,
    SupplyTechnologyKind fallback,
  ) {
    final lowerName = name.toLowerCase();
    final lowerType = rawType.toLowerCase();
    if (lowerName.contains('maintenance')) {
      return SupplyTechnologyKind.maintenanceBox;
    }
    if (lowerName.contains('waste') || lowerType.contains('waste')) {
      return SupplyTechnologyKind.wasteInkPad;
    }
    if (lowerName.contains('toner') || lowerType.contains('toner')) {
      return SupplyTechnologyKind.toner;
    }
    return fallback;
  }

  static SourcedPrinterField<List<PrinterTrayStatusInfo>> _mergeTrays({
    required RawIppTelemetryPayload ipp,
    required RawSnmpTelemetryPayload snmp,
    required RawWin32SpoolerPayload win32,
    required DateTime now,
  }) {
    // 1. IPP media-col-database / media-ready
    if (ipp.reachable &&
        (ipp.mediaColDatabase.isNotEmpty || ipp.mediaReady.isNotEmpty)) {
      final trays = <PrinterTrayStatusInfo>[];
      if (ipp.mediaColDatabase.isNotEmpty) {
        for (int i = 0; i < ipp.mediaColDatabase.length; i++) {
          final rawEntry = ipp.mediaColDatabase[i];
          final trayName =
              _extractKeyVal(rawEntry, 'media-source') ?? 'Tray ${i + 1}';
          final size = _extractKeyVal(rawEntry, 'media-size-name') ??
              (i < ipp.mediaReady.length ? ipp.mediaReady[i] : null);
          final type = _extractKeyVal(rawEntry, 'media-type');

          trays.add(
            PrinterTrayStatusInfo(
              trayId: 'ipp_tray_$i',
              trayName: _humanizeTrayName(trayName),
              loadedPaperSize: size != null && size.isNotEmpty
                  ? SourcedPrinterField<String>.reported(
                      value: _humanizeMediaName(size),
                      source: PrinterTelemetrySource.ipp,
                      confidence: TelemetryConfidence.high,
                      rawAttributeKey: 'media-col-database[$i].media-size-name',
                      observedAt: now,
                    )
                  : SourcedPrinterField<String>.notReported(
                      'media-col-database[$i].media-size-name'),
              loadedMediaType: type != null && type.isNotEmpty
                  ? SourcedPrinterField<String>.reported(
                      value: _humanizeMediaType(type),
                      source: PrinterTelemetrySource.ipp,
                      confidence: TelemetryConfidence.high,
                      rawAttributeKey: 'media-col-database[$i].media-type',
                      observedAt: now,
                    )
                  : SourcedPrinterField<String>.notReported(
                      'media-col-database[$i].media-type'),
              currentSheets:
                  SourcedPrinterField<int>.notReported('currentSheets'),
              maxCapacitySheets:
                  SourcedPrinterField<int>.notReported('maxCapacitySheets'),
              availability: size != null && size.isNotEmpty
                  ? PaperAvailabilityState.loadedNow
                  : PaperAvailabilityState.notReported,
            ),
          );
        }
      } else {
        for (int i = 0; i < ipp.mediaReady.length; i++) {
          trays.add(
            PrinterTrayStatusInfo(
              trayId: 'ipp_ready_$i',
              trayName: 'Tray ${i + 1}',
              loadedPaperSize: SourcedPrinterField<String>.reported(
                value: _humanizeMediaName(ipp.mediaReady[i]),
                source: PrinterTelemetrySource.ipp,
                confidence: TelemetryConfidence.high,
                rawAttributeKey: 'media-ready[$i]',
                observedAt: now,
              ),
              loadedMediaType:
                  ipp.mediaTypeSupported.isNotEmpty
                      ? SourcedPrinterField<String>.reported(
                          value: _humanizeMediaType(
                              ipp.mediaTypeSupported.first),
                          source: PrinterTelemetrySource.ipp,
                          confidence: TelemetryConfidence.medium,
                          rawAttributeKey: 'media-type-supported[0]',
                          observedAt: now,
                        )
                      : SourcedPrinterField<String>.notReported('media-type'),
              currentSheets:
                  SourcedPrinterField<int>.notReported('currentSheets'),
              maxCapacitySheets:
                  SourcedPrinterField<int>.notReported('maxCapacitySheets'),
              availability: PaperAvailabilityState.loadedNow,
            ),
          );
        }
      }

      return SourcedPrinterField<List<PrinterTrayStatusInfo>>.reported(
        value: trays,
        source: PrinterTelemetrySource.ipp,
        confidence: TelemetryConfidence.high,
        rawAttributeKey: 'media-col-database/media-ready',
        observedAt: now,
      );
    }

    // 2. SNMP prtInputTable
    if (snmp.reachable && snmp.inputTrays.isNotEmpty) {
      final trays = snmp.inputTrays.map((row) {
        final hasSize = row.mediaName.trim().isNotEmpty;
        final hasType = row.mediaType.trim().isNotEmpty;
        return PrinterTrayStatusInfo(
          trayId: 'snmp_tray_${row.index}',
          trayName: _humanizeTrayName(row.name),
          loadedPaperSize: hasSize
              ? SourcedPrinterField<String>.reported(
                  value: _humanizeMediaName(row.mediaName),
                  source: PrinterTelemetrySource.snmp,
                  confidence: TelemetryConfidence.high,
                  rawAttributeKey: 'prtInputMediaName.${row.index}',
                  observedAt: now,
                )
              : SourcedPrinterField<String>.notReported(
                  'prtInputMediaName.${row.index}'),
          loadedMediaType: hasType
              ? SourcedPrinterField<String>.reported(
                  value: _humanizeMediaType(row.mediaType),
                  source: PrinterTelemetrySource.snmp,
                  confidence: TelemetryConfidence.high,
                  rawAttributeKey: 'prtInputMediaType.${row.index}',
                  observedAt: now,
                )
              : SourcedPrinterField<String>.notReported(
                  'prtInputMediaType.${row.index}'),
          currentSheets: row.currentLevel >= 0
              ? SourcedPrinterField<int>.reported(
                  value: row.currentLevel,
                  source: PrinterTelemetrySource.snmp,
                  confidence: TelemetryConfidence.high,
                  rawAttributeKey: 'prtInputCurrentLevel.${row.index}',
                  observedAt: now,
                )
              : SourcedPrinterField<int>.notReported('prtInputCurrentLevel'),
          maxCapacitySheets: row.maxCapacity > 0
              ? SourcedPrinterField<int>.reported(
                  value: row.maxCapacity,
                  source: PrinterTelemetrySource.snmp,
                  confidence: TelemetryConfidence.high,
                  rawAttributeKey: 'prtInputMaxCapacity.${row.index}',
                  observedAt: now,
                )
              : SourcedPrinterField<int>.notReported('prtInputMaxCapacity'),
          availability: hasSize
              ? PaperAvailabilityState.loadedNow
              : PaperAvailabilityState.notReported,
        );
      }).toList();

      return SourcedPrinterField<List<PrinterTrayStatusInfo>>.reported(
        value: trays,
        source: PrinterTelemetrySource.snmp,
        confidence: TelemetryConfidence.high,
        rawAttributeKey: 'prtInputTable',
        observedAt: now,
      );
    }

    // 3. Win32 Spooler DC_BINNAMES (Note: Win32 knows bin names, NOT live optical paper sensors)
    if (win32.available && win32.binNames.isNotEmpty) {
      final trays = win32.binNames.asMap().entries.map((entry) {
        return PrinterTrayStatusInfo(
          trayId: 'win32_bin_${entry.key}',
          trayName: entry.value,
          loadedPaperSize:
              SourcedPrinterField<String>.notReported('DC_BINNAMES.loadedSize'),
          loadedMediaType:
              SourcedPrinterField<String>.notReported('DC_BINNAMES.mediaType'),
          currentSheets:
              SourcedPrinterField<int>.notReported('DC_BINNAMES.sheets'),
          maxCapacitySheets:
              SourcedPrinterField<int>.notReported('DC_BINNAMES.capacity'),
          availability: PaperAvailabilityState.notReported,
        );
      }).toList();

      return SourcedPrinterField<List<PrinterTrayStatusInfo>>.reported(
        value: trays,
        source: PrinterTelemetrySource.windowsSpooler,
        confidence: TelemetryConfidence.medium,
        rawAttributeKey: 'DC_BINNAMES',
        observedAt: now,
      );
    }

    return SourcedPrinterField<List<PrinterTrayStatusInfo>>.notReported(
        'trays');
  }

  static SourcedPrinterField<String> _extractMaintenanceBoxStatus({
    required SourcedPrinterField<List<SupplyMarkerInfo>> suppliesField,
    required RawWebConfigFallbackPayload webConfig,
    required bool consentedWeb,
    required DateTime now,
  }) {
    if (suppliesField.isReported && suppliesField.value != null) {
      for (final m in suppliesField.value!) {
        if (m.supplyKind == SupplyTechnologyKind.maintenanceBox ||
            m.supplyKind == SupplyTechnologyKind.wasteInkPad) {
          if (m.levelPercent.isReported && m.levelPercent.value != null) {
            return SourcedPrinterField<String>.reported(
              value: '${m.levelPercent.value}% remaining capacity (${m.name})',
              source: m.levelPercent.source,
              confidence: m.levelPercent.confidence,
              rawAttributeKey: m.levelPercent.rawAttributeKey,
              observedAt: now,
            );
          }
          if (m.qualitativeStatus.isReported &&
              m.qualitativeStatus.value != null) {
            return SourcedPrinterField<String>.reported(
              value: '${m.qualitativeStatus.value!.labelEn} (${m.name})',
              source: m.qualitativeStatus.source,
              confidence: m.qualitativeStatus.confidence,
              rawAttributeKey: m.qualitativeStatus.rawAttributeKey,
              observedAt: now,
            );
          }
        }
      }
    }

    if (consentedWeb &&
        webConfig.reachable &&
        webConfig.maintenanceBoxStatus != null) {
      return SourcedPrinterField<String>.reported(
        value: webConfig.maintenanceBoxStatus!,
        source: PrinterTelemetrySource.webConfigFallback,
        confidence: TelemetryConfidence.low,
        rawAttributeKey: 'web_config.maintenance_box',
        observedAt: now,
      );
    }

    return SourcedPrinterField<String>.notReported('maintenance-box-status');
  }

  static PrinterTrayStatusInfo? _findTrayWithPaper(
    PrinterLiveIntelligence intel,
    String requestedSize,
  ) {
    if (!intel.trays.isReported || intel.trays.value == null) return null;
    final reqLower = requestedSize.toLowerCase().trim();
    for (final tray in intel.trays.value!) {
      final loaded = tray.loadedPaperSize.value?.toLowerCase().trim();
      if (loaded != null && loaded == reqLower) {
        return tray;
      }
    }
    return null;
  }

  static String? _findFirstLoadedPaperSize(PrinterLiveIntelligence intel) {
    if (intel.trays.isReported && intel.trays.value != null) {
      for (final tray in intel.trays.value!) {
        if (tray.loadedPaperSize.isReported &&
            tray.loadedPaperSize.value != null) {
          return tray.loadedPaperSize.value;
        }
      }
    }
    if (intel.readyPaperSizes.isReported &&
        intel.readyPaperSizes.value != null &&
        intel.readyPaperSizes.value!.isNotEmpty) {
      return intel.readyPaperSizes.value!.first;
    }
    return null;
  }

  static String? _findFirstLoadedMediaType(PrinterLiveIntelligence intel) {
    if (intel.trays.isReported && intel.trays.value != null) {
      for (final tray in intel.trays.value!) {
        if (tray.loadedMediaType.isReported &&
            tray.loadedMediaType.value != null) {
          return tray.loadedMediaType.value;
        }
      }
    }
    return null;
  }

  static bool _mediaTypesMatch(String a, String b) {
    final na = a.toLowerCase().trim();
    final nb = b.toLowerCase().trim();
    if (na == nb) return true;
    if (na.contains('plain') && nb.contains('plain')) return true;
    if (na.contains('photo') && (nb.contains('photo') || nb.contains('glossy'))) {
      return true;
    }
    return false;
  }

  static String? _extractKeyVal(String source, String key) {
    final match = RegExp('$key=([^;,}]+)').firstMatch(source);
    return match?.group(1)?.trim();
  }

  static String _humanizeMediaName(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('iso_a4') || lower == 'a4') return 'A4';
    if (lower.contains('iso_a3') || lower == 'a3') return 'A3';
    if (lower.contains('a3+') || lower.contains('super_b')) return 'A3+';
    if (lower.contains('iso_a5') || lower == 'a5') return 'A5';
    if (lower.contains('iso_a6') || lower == 'a6') return 'A6';
    if (lower.contains('jis_b5') || lower == 'b5') return 'B5';
    if (lower.contains('na_letter') || lower == 'letter') return 'Letter';
    if (lower.contains('na_legal') || lower == 'legal') return 'Legal';
    if (lower.contains('4x6') || lower.contains('10x15')) {
      return '4x6 in (10x15 cm)';
    }
    if (lower.contains('5x7') || lower.contains('13x18')) {
      return '5x7 in (13x18 cm)';
    }
    return raw;
  }

  static String _humanizeMediaType(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower == 'stationery' || lower.contains('plain')) return 'Plain Paper';
    if (lower.contains('photographic-glossy') || lower.contains('glossy')) {
      return 'Photo Paper Glossy';
    }
    if (lower.contains('photographic-matte') || lower.contains('matte')) {
      return 'Epson Matte';
    }
    if (lower.contains('envelope')) return 'Envelope';
    if (lower.contains('heavyweight') || lower.contains('thick')) {
      return 'Thick Paper';
    }
    return raw;
  }

  static String _humanizeTrayName(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower == 'main' || lower == 'tray-1' || lower == 'cassette-1') {
      return 'Tray 1';
    }
    if (lower == 'tray-2' || lower == 'cassette-2') return 'Tray 2';
    if (lower == 'rear' || lower == 'alternate' || lower == 'by-pass-tray') {
      return 'Rear Tray';
    }
    return raw;
  }

  // ===========================================================================
  // Low-Level Binary & BER Encoding Helpers
  // ===========================================================================

  static Uint8List _uint16BigEndian(int value) {
    return Uint8List.fromList([(value >> 8) & 0xFF, value & 0xFF]);
  }

  static Uint8List _uint32BigEndian(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  static Uint8List _wrapBerTl(int tag, Uint8List value) {
    final builder = BytesBuilder()..addByte(tag);
    final len = value.length;
    if (len < 128) {
      builder.addByte(len);
    } else if (len < 256) {
      builder.addByte(0x81);
      builder.addByte(len);
    } else {
      builder.addByte(0x82);
      builder.addByte((len >> 8) & 0xFF);
      builder.addByte(len & 0xFF);
    }
    builder.add(value);
    return builder.toBytes();
  }

  static Uint8List _encodeBerInt(int val) {
    if (val >= -128 && val <= 127) {
      return Uint8List.fromList([0x02, 0x01, val & 0xFF]);
    }
    final bytes = <int>[];
    int temp = val;
    while (temp != 0 && temp != -1) {
      bytes.insert(0, temp & 0xFF);
      temp >>= 8;
    }
    if (bytes.isEmpty) bytes.add(0);
    if (val > 0 && (bytes.first & 0x80) != 0) {
      bytes.insert(0, 0x00);
    } else if (val < 0 && (bytes.first & 0x80) == 0) {
      bytes.insert(0, 0xFF);
    }
    return _wrapBerTl(0x02, Uint8List.fromList(bytes));
  }

  static int _decodeBerSignedInt(Uint8List bytes) {
    if (bytes.isEmpty) return 0;
    int result = (bytes[0] & 0x80) != 0 ? -1 : 0;
    for (final b in bytes) {
      result = (result << 8) | (b & 0xFF);
    }
    return result;
  }

  static Uint8List _encodeBerOid(String oid) {
    final parts =
        oid.split('.').where((s) => s.isNotEmpty).map(int.parse).toList();
    if (parts.length < 2) {
      return Uint8List.fromList([0x06, 0x01, 0x00]);
    }
    final encoded = <int>[parts[0] * 40 + parts[1]];
    for (int i = 2; i < parts.length; i++) {
      int sub = parts[i];
      if (sub < 128) {
        encoded.add(sub);
      } else {
        final temp = <int>[sub & 0x7F];
        sub >>= 7;
        while (sub > 0) {
          temp.insert(0, (sub & 0x7F) | 0x80);
          sub >>= 7;
        }
        encoded.addAll(temp);
      }
    }
    return _wrapBerTl(0x06, Uint8List.fromList(encoded));
  }

  static String _decodeBerOid(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final first = bytes[0];
    final parts = <int>[first ~/ 40, first % 40];
    int current = 0;
    for (int i = 1; i < bytes.length; i++) {
      final b = bytes[i];
      current = (current << 7) | (b & 0x7F);
      if ((b & 0x80) == 0) {
        parts.add(current);
        current = 0;
      }
    }
    return parts.join('.');
  }

  static _BerTl _readBerTl(Uint8List buf, int offset) {
    final tag = buf[offset];
    int pos = offset + 1;
    final lenByte = buf[pos++];
    int length = 0;
    if ((lenByte & 0x80) == 0) {
      length = lenByte;
    } else {
      final count = lenByte & 0x7F;
      for (int i = 0; i < count; i++) {
        length = (length << 8) | buf[pos++];
      }
    }
    return _BerTl(tag: tag, length: length, valueOffset: pos);
  }
}

class _BerTl {
  final int tag;
  final int length;
  final int valueOffset;

  const _BerTl({
    required this.tag,
    required this.length,
    required this.valueOffset,
  });
}
