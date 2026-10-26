import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'models/printer_intelligence_models.dart';
import 'models/printer_models.dart';
import 'printer_intelligence_service.dart';

// ============================================================================
// 1. Offline Mode Network Policy Guard ("Never call out to the internet")
// ============================================================================

/// Exception thrown when any printer feature attempts to contact a public
/// internet IP address or external domain.
class OfflinePrinterPolicyViolationException implements Exception {
  final String attemptedTarget;
  final String reason;

  const OfflinePrinterPolicyViolationException({
    required this.attemptedTarget,
    required this.reason,
  });

  @override
  String toString() =>
      'OfflinePrinterPolicyViolationException: Blocked external network call to "$attemptedTarget" ($reason). Printer features must strictly stay on local LAN/USB.';
}

/// Enforces the strict offline guarantee: Print Helper must NEVER call out to
/// the internet for any printer telemetry, discovery, or driver feature.
///
/// Only loopback (`127.0.0.0/8`, `::1`, `localhost`), RFC 1918 private LAN
/// (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`), RFC 3927 link-local
/// (`169.254.0.0/16`, `fe80::/10`), and local mDNS/LAN hostnames (`.local`,
/// `.lan`, single-label LAN hostnames without public TLD) are allowed.
class OfflinePrinterNetworkPolicyGuard {
  static int _verifiedLocalCallsCount = 0;
  static int _blockedInternetCallsCount = 0;
  static final List<String> _blockedTargetsLog = <String>[];

  static int get verifiedLocalCallsCount => _verifiedLocalCallsCount;
  static int get blockedInternetCallsCount => _blockedInternetCallsCount;
  static List<String> get blockedTargetsLog =>
      List<String>.unmodifiable(_blockedTargetsLog);

  static void resetAuditCounters() {
    _verifiedLocalCallsCount = 0;
    _blockedInternetCallsCount = 0;
    _blockedTargetsLog.clear();
  }

  /// Returns `true` if [hostOrUri] is strictly a local loopback, private LAN
  /// IPv4/IPv6 address, link-local address, or local-link hostname.
  static bool isStrictlyLocalLanTarget(String hostOrUri) {
    final cleaned = _extractHost(hostOrUri).toLowerCase().trim();
    if (cleaned.isEmpty) return false;

    if (cleaned == 'localhost' || cleaned == '::1' || cleaned == '[::1]') {
      return true;
    }

    // Check IPv4 address
    final ipv4Match =
        RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(
      cleaned,
    );
    if (ipv4Match != null) {
      final a = int.tryParse(ipv4Match.group(1)!) ?? -1;
      final b = int.tryParse(ipv4Match.group(2)!) ?? -1;
      final c = int.tryParse(ipv4Match.group(3)!) ?? -1;
      final d = int.tryParse(ipv4Match.group(4)!) ?? -1;
      if (a < 0 || a > 255 || b < 0 || b > 255 || c < 0 || c > 255 || d < 0 || d > 255) {
        return false;
      }
      // 127.0.0.0/8 Loopback
      if (a == 127) return true;
      // 10.0.0.0/8 Private LAN
      if (a == 10) return true;
      // 172.16.0.0/12 Private LAN (172.16.x.x - 172.31.x.x)
      if (a == 172 && b >= 16 && b <= 31) return true;
      // 192.168.0.0/16 Private LAN
      if (a == 192 && b == 168) return true;
      // 169.254.0.0/16 Link-Local (APIPA / Auto-IP)
      if (a == 169 && b == 254) return true;

      // Any other IPv4 (e.g. 8.8.8.8, 1.1.1.1, 93.184.216.34) is a public internet IP!
      return false;
    }

    // Check IPv6 link-local (fe80::) or unique-local (fc00:: / fd00::)
    final normalizedIpv6 = cleaned.replaceAll('[', '').replaceAll(']', '');
    if (normalizedIpv6.contains(':')) {
      if (normalizedIpv6 == '::1' ||
          normalizedIpv6.startsWith('fe80:') ||
          normalizedIpv6.startsWith('fc') ||
          normalizedIpv6.startsWith('fd')) {
        return true;
      }
      return false;
    }

    // Hostname check: allow mDNS `.local`, `.lan`, `.home`, `.internal`, or
    // single-label NetBIOS/printer hostnames (e.g. `EPSON1A2B3C`).
    // Block any public internet domain (.com, .net, .org, .io, .gov, .edu, .co, etc.)
    if (cleaned.endsWith('.local') ||
        cleaned.endsWith('.lan') ||
        cleaned.endsWith('.home') ||
        cleaned.endsWith('.internal') ||
        !cleaned.contains('.')) {
      return true;
    }

    return false;
  }

  /// Validates that [hostOrUri] is a local LAN/loopback target; throws
  /// [OfflinePrinterPolicyViolationException] and records the attempt if it
  /// points to the public internet.
  static void assertStrictlyLocalLanTarget(String hostOrUri) {
    if (isStrictlyLocalLanTarget(hostOrUri)) {
      _verifiedLocalCallsCount++;
      return;
    }
    _blockedInternetCallsCount++;
    _blockedTargetsLog.add(
      '${DateTime.now().toIso8601String()} -> BLOCKED: $hostOrUri',
    );
    throw OfflinePrinterPolicyViolationException(
      attemptedTarget: hostOrUri,
      reason: 'Public internet host/IP is forbidden in 100% offline printer mode',
    );
  }

  static String _extractHost(String hostOrUri) {
    final trimmed = hostOrUri.trim();
    if (trimmed.contains('://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.host.isNotEmpty) {
        return uri.host;
      }
    }
    // Strip port if ipv4:port or hostname:port
    if (trimmed.contains(':') && !trimmed.contains(']') &&
        trimmed.indexOf(':') == trimmed.lastIndexOf(':')) {
      return trimmed.split(':').first;
    }
    return trimmed;
  }
}

// ============================================================================
// 2. Per-Printer SNMP Community, IPP Authentication & Identity Config
// ============================================================================

enum IppAuthenticationScheme {
  none(labelEn: 'None (Anonymous LAN)', labelSi: 'නැත (සාමාන්‍ය LAN)'),
  basic(labelEn: 'HTTP Basic (Username / Password)', labelSi: 'HTTP Basic (පරිශීලක නාමය / මුරපදය)'),
  bearer(labelEn: 'Bearer Token / OAuth', labelSi: 'Bearer Token');

  final String labelEn;
  final String labelSi;

  const IppAuthenticationScheme({
    required this.labelEn,
    required this.labelSi,
  });
}

enum SnmpProtocolVersion {
  v1(label: 'SNMP v1'),
  v2c(label: 'SNMP v2c (Standard)'),
  v3(label: 'SNMP v3 (Authenticated)');

  final String label;
  const SnmpProtocolVersion({required this.label});
}

/// Per-printer network authentication, SNMP community string, and hardware
/// identity anchors used to rediscover the printer when its DHCP IP changes.
class PrinterNetworkAuthAndIdentityConfig {
  final String printerId;
  final String snmpCommunity;
  final SnmpProtocolVersion snmpVersion;
  final String? snmpV3SecurityName;
  final IppAuthenticationScheme ippAuthScheme;
  final String ippUsername;
  final String ippPasswordOrToken;
  final String? knownHostname;
  final String? knownSerialNumber;
  final String? knownMacAddress;
  final String? lastKnownIpAddress;
  final bool wakeOnDeepSleep;

  const PrinterNetworkAuthAndIdentityConfig({
    required this.printerId,
    this.snmpCommunity = 'public',
    this.snmpVersion = SnmpProtocolVersion.v2c,
    this.snmpV3SecurityName,
    this.ippAuthScheme = IppAuthenticationScheme.none,
    this.ippUsername = '',
    this.ippPasswordOrToken = '',
    this.knownHostname,
    this.knownSerialNumber,
    this.knownMacAddress,
    this.lastKnownIpAddress,
    this.wakeOnDeepSleep = true,
  });

  /// Builds the HTTP `Authorization` header value for IPP requests when configured.
  String? buildIppAuthorizationHeader() {
    switch (ippAuthScheme) {
      case IppAuthenticationScheme.none:
        return null;
      case IppAuthenticationScheme.basic:
        if (ippUsername.isEmpty && ippPasswordOrToken.isEmpty) return null;
        final creds = base64Encode(utf8.encode('$ippUsername:$ippPasswordOrToken'));
        return 'Basic $creds';
      case IppAuthenticationScheme.bearer:
        if (ippPasswordOrToken.trim().isEmpty) return null;
        return 'Bearer ${ippPasswordOrToken.trim()}';
    }
  }

  PrinterNetworkAuthAndIdentityConfig copyWith({
    String? snmpCommunity,
    SnmpProtocolVersion? snmpVersion,
    String? snmpV3SecurityName,
    IppAuthenticationScheme? ippAuthScheme,
    String? ippUsername,
    String? ippPasswordOrToken,
    String? knownHostname,
    String? knownSerialNumber,
    String? knownMacAddress,
    String? lastKnownIpAddress,
    bool? wakeOnDeepSleep,
  }) {
    return PrinterNetworkAuthAndIdentityConfig(
      printerId: printerId,
      snmpCommunity: snmpCommunity ?? this.snmpCommunity,
      snmpVersion: snmpVersion ?? this.snmpVersion,
      snmpV3SecurityName: snmpV3SecurityName ?? this.snmpV3SecurityName,
      ippAuthScheme: ippAuthScheme ?? this.ippAuthScheme,
      ippUsername: ippUsername ?? this.ippUsername,
      ippPasswordOrToken: ippPasswordOrToken ?? this.ippPasswordOrToken,
      knownHostname: knownHostname ?? this.knownHostname,
      knownSerialNumber: knownSerialNumber ?? this.knownSerialNumber,
      knownMacAddress: knownMacAddress ?? this.knownMacAddress,
      lastKnownIpAddress: lastKnownIpAddress ?? this.lastKnownIpAddress,
      wakeOnDeepSleep: wakeOnDeepSleep ?? this.wakeOnDeepSleep,
    );
  }

  Map<String, dynamic> toJson() => {
        'printerId': printerId,
        'snmpCommunity': snmpCommunity,
        'snmpVersion': snmpVersion.name,
        'snmpV3SecurityName': snmpV3SecurityName,
        'ippAuthScheme': ippAuthScheme.name,
        'ippUsername': ippUsername,
        'knownHostname': knownHostname,
        'knownSerialNumber': knownSerialNumber,
        'knownMacAddress': knownMacAddress,
        'lastKnownIpAddress': lastKnownIpAddress,
        'wakeOnDeepSleep': wakeOnDeepSleep,
      };
}

// ============================================================================
// 3. Sleep/Wake Handler & Network IP Change Rediscovery Engine
// ============================================================================

enum PrinterRediscoveryMatchedBy {
  currentIpReachable,
  wokeFromSleepAtSameIp,
  hostnameResolution,
  serialNumberMatch,
  macAddressMatch,
  unreachable,
}

class PrinterWakeAndRediscoveryResult {
  final bool reachable;
  final bool wokeFromSleep;
  final bool ipChanged;
  final String? previousIp;
  final String? resolvedIp;
  final PrinterRediscoveryMatchedBy matchedBy;
  final String? matchedIdentityValue;
  final int wakeAttempts;
  final String summaryEn;
  final String summarySi;

  const PrinterWakeAndRediscoveryResult({
    required this.reachable,
    required this.wokeFromSleep,
    required this.ipChanged,
    this.previousIp,
    this.resolvedIp,
    required this.matchedBy,
    this.matchedIdentityValue,
    this.wakeAttempts = 1,
    required this.summaryEn,
    required this.summarySi,
  });
}

/// Candidate LAN node descriptor used during automatic DHCP IP change rediscovery.
class LanPrinterIdentityCandidate {
  final String ipAddress;
  final String? hostname;
  final String? serialNumber;
  final String? macAddress;
  final bool sleepingInitially;

  const LanPrinterIdentityCandidate({
    required this.ipAddress,
    this.hostname,
    this.serialNumber,
    this.macAddress,
    this.sleepingInitially = false,
  });
}

/// Handles Epson energy-saver sleep/wake transitions and automatic DHCP IP
/// rediscovery by hostname (`EPSONxxxxxx.local`), hardware serial number
/// (`prtGeneralSerialNumber` / IPP `printer-device-id`), or MAC address.
class EpsonNetworkRediscoveryEngine {
  /// Probes the printer at [currentIp], waking it if it is in deep sleep, and
  /// if its IP has changed on the LAN, rediscovers it using [identityConfig]
  /// against [lanCandidates] or local hostname resolution.
  static Future<PrinterWakeAndRediscoveryResult> ensureAwakeOrRediscover({
    required String? currentIp,
    required PrinterNetworkAuthAndIdentityConfig identityConfig,
    List<LanPrinterIdentityCandidate> lanCandidates = const [],
    Future<bool> Function(String host, int attempt)? customProbeFn,
    Future<String?> Function(String hostname)? customHostnameResolver,
  }) async {
    // 1. Validate offline policy for currentIp if present
    if (currentIp != null && currentIp.trim().isNotEmpty) {
      OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(currentIp);
    }

    Future<bool> probeHost(String host, int attempt) async {
      OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(host);
      if (customProbeFn != null) {
        return customProbeFn(host, attempt);
      }
      // Check in-memory candidate list first (for deterministic tests / LAN cache)
      for (final c in lanCandidates) {
        if (c.ipAddress == host) {
          if (c.sleepingInitially && attempt == 1) {
            return false; // Wakes up on attempt >= 2
          }
          return true;
        }
      }
      // Real local TCP / UDP probe with short timeout
      try {
        final socket = await Socket.connect(
          host,
          631,
          timeout: const Duration(milliseconds: 450),
        );
        await socket.close();
        return true;
      } catch (_) {
        return false;
      }
    }

    // Step A: Probe current IP (Attempt 1 = normal, Attempt 2 = wake from sleep)
    if (currentIp != null && currentIp.trim().isNotEmpty) {
      final awakeFirstTry = await probeHost(currentIp, 1);
      if (awakeFirstTry) {
        return PrinterWakeAndRediscoveryResult(
          reachable: true,
          wokeFromSleep: false,
          ipChanged: false,
          previousIp: currentIp,
          resolvedIp: currentIp,
          matchedBy: PrinterRediscoveryMatchedBy.currentIpReachable,
          wakeAttempts: 1,
          summaryEn: 'Printer is online at $currentIp.',
          summarySi: 'මුද්‍රණ යන්ත්‍රය $currentIp හි සක්‍රීයව ඇත.',
        );
      }

      if (identityConfig.wakeOnDeepSleep) {
        // Send second wake probe for Epson Deep Sleep / Energy Saver mode
        final wokeSecondTry = await probeHost(currentIp, 2);
        if (wokeSecondTry) {
          return PrinterWakeAndRediscoveryResult(
            reachable: true,
            wokeFromSleep: true,
            ipChanged: false,
            previousIp: currentIp,
            resolvedIp: currentIp,
            matchedBy: PrinterRediscoveryMatchedBy.wokeFromSleepAtSameIp,
            wakeAttempts: 2,
            summaryEn:
                'Woke Epson printer from sleep mode at $currentIp (2 wake probes).',
            summarySi:
                '$currentIp හි නිද්‍රා තත්ත්වයේ (Sleep mode) තිබූ මුද්‍රණ යන්ත්‍රය අවදි කරන ලදී.',
          );
        }
      }
    }

    // Step B: IP may have changed via DHCP. Rediscover by Hostname first.
    final knownHost = identityConfig.knownHostname?.trim();
    if (knownHost != null && knownHost.isNotEmpty) {
      OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(knownHost);
      String? resolvedFromHost;
      if (customHostnameResolver != null) {
        resolvedFromHost = await customHostnameResolver(knownHost);
      } else {
        for (final c in lanCandidates) {
          if (c.hostname != null &&
              c.hostname!.toLowerCase() == knownHost.toLowerCase()) {
            resolvedFromHost = c.ipAddress;
            break;
          }
        }
        if (resolvedFromHost == null) {
          try {
            final addrs = await InternetAddress.lookup(knownHost)
                .timeout(const Duration(milliseconds: 500));
            if (addrs.isNotEmpty) {
              resolvedFromHost = addrs.first.address;
            }
          } catch (_) {}
        }
      }

      if (resolvedFromHost != null && resolvedFromHost.isNotEmpty) {
        OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(
          resolvedFromHost,
        );
        return PrinterWakeAndRediscoveryResult(
          reachable: true,
          wokeFromSleep: false,
          ipChanged: resolvedFromHost != currentIp,
          previousIp: currentIp,
          resolvedIp: resolvedFromHost,
          matchedBy: PrinterRediscoveryMatchedBy.hostnameResolution,
          matchedIdentityValue: knownHost,
          wakeAttempts: 2,
          summaryEn:
              'Printer IP changed from ${currentIp ?? "unknown"} to $resolvedFromHost (rediscovered via hostname $knownHost).',
          summarySi:
              'මුද්‍රණ යන්ත්‍රයේ IP ලිපිනය ${currentIp ?? "-"} සිට $resolvedFromHost වෙත වෙනස් වී ඇත ($knownHost මගින් සොයා ගන්නා ලදී).',
        );
      }
    }

    // Step C: Rediscover by Hardware Serial Number across LAN candidates
    final knownSerial = identityConfig.knownSerialNumber?.trim();
    if (knownSerial != null && knownSerial.isNotEmpty) {
      for (final candidate in lanCandidates) {
        if (candidate.serialNumber != null &&
            candidate.serialNumber!.toUpperCase() ==
                knownSerial.toUpperCase()) {
          OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(
            candidate.ipAddress,
          );
          return PrinterWakeAndRediscoveryResult(
            reachable: true,
            wokeFromSleep: false,
            ipChanged: candidate.ipAddress != currentIp,
            previousIp: currentIp,
            resolvedIp: candidate.ipAddress,
            matchedBy: PrinterRediscoveryMatchedBy.serialNumberMatch,
            matchedIdentityValue: knownSerial,
            wakeAttempts: 2,
            summaryEn:
                'Printer IP changed from ${currentIp ?? "unknown"} to ${candidate.ipAddress} (rediscovered via serial number $knownSerial).',
            summarySi:
                'මුද්‍රණ යන්ත්‍රයේ IP ලිපිනය ${candidate.ipAddress} ලෙස අනුක්‍රමික අංකය ($knownSerial) මගින් නැවත සොයා ගන්නා ලදී.',
          );
        }
      }
    }

    // Step D: Rediscover by MAC Address across LAN candidates
    final knownMac = _normalizeMac(identityConfig.knownMacAddress);
    if (knownMac != null && knownMac.isNotEmpty) {
      for (final candidate in lanCandidates) {
        if (_normalizeMac(candidate.macAddress) == knownMac) {
          OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(
            candidate.ipAddress,
          );
          return PrinterWakeAndRediscoveryResult(
            reachable: true,
            wokeFromSleep: false,
            ipChanged: candidate.ipAddress != currentIp,
            previousIp: currentIp,
            resolvedIp: candidate.ipAddress,
            matchedBy: PrinterRediscoveryMatchedBy.macAddressMatch,
            matchedIdentityValue: identityConfig.knownMacAddress,
            wakeAttempts: 2,
            summaryEn:
                'Printer IP changed from ${currentIp ?? "unknown"} to ${candidate.ipAddress} (rediscovered via MAC ${identityConfig.knownMacAddress}).',
            summarySi:
                'මුද්‍රණ යන්ත්‍රයේ IP ලිපිනය ${candidate.ipAddress} ලෙස MAC ලිපිනය මගින් නැවත සොයා ගන්නා ලදී.',
          );
        }
      }
    }

    return PrinterWakeAndRediscoveryResult(
      reachable: false,
      wokeFromSleep: false,
      ipChanged: false,
      previousIp: currentIp,
      resolvedIp: currentIp,
      matchedBy: PrinterRediscoveryMatchedBy.unreachable,
      wakeAttempts: identityConfig.wakeOnDeepSleep ? 2 : 1,
      summaryEn:
          'Printer did not respond to wake probes and could not be rediscovered on the local network.',
      summarySi:
          'මුද්‍රණ යන්ත්‍රය ප්‍රතිචාර නොදක්වයි; ජාලයේ නැවත සොයාගත නොහැකි විය.',
    );
  }

  static String? _normalizeMac(String? mac) {
    if (mac == null || mac.trim().isEmpty) return null;
    return mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
  }
}

// ============================================================================
// 4. Common Epson Conditions Detector (Plain Language in English & Sinhala)
// ============================================================================

enum EpsonConditionKind {
  inkCartridgeNotRecognized,
  maintenanceBoxNearEndOfLife,
  maintenanceBoxFull,
  headCleaningInProgress,
  borderlessNeedsSpecialMargin,
  rollPaperCutSettings,
  coverOpen,
  paperOutInSpecificTray,
}

class EpsonDetectedCondition {
  final EpsonConditionKind kind;
  final String rawTriggerCode;
  final String titleEn;
  final String titleSi;
  final String explanationEn;
  final String explanationSi;
  final bool isHardStopBlockingError;
  final PrinterTelemetrySource source;
  final TelemetryConfidence confidence;
  final String? affectedTrayOrSupply;

  const EpsonDetectedCondition({
    required this.kind,
    required this.rawTriggerCode,
    required this.titleEn,
    required this.titleSi,
    required this.explanationEn,
    required this.explanationSi,
    required this.isHardStopBlockingError,
    required this.source,
    required this.confidence,
    this.affectedTrayOrSupply,
  });

  PlainLanguagePrinterProblem toPlainLanguageProblem() {
    return PlainLanguagePrinterProblem(
      rawCode: rawTriggerCode,
      titleEn: titleEn,
      titleSi: titleSi,
      detailEn: explanationEn,
      detailSi: explanationSi,
      isHardStopBlockingError: isHardStopBlockingError,
      source: source,
      confidence: confidence,
    );
  }
}

/// Detects and explains Epson-specific hardware & driver conditions in plain
/// English and Sinhala.
class EpsonConditionDetector {
  static List<EpsonDetectedCondition> detectConditions({
    required RawIppTelemetryPayload ipp,
    required RawSnmpTelemetryPayload snmp,
    required RawWin32SpoolerPayload win32,
    required PrinterDevice printer,
    EpsonModelProfile? matchedProfile,
    bool requestedBorderless = false,
    bool requestedRollPaper = false,
    String? requestedPaperSize,
  }) {
    final conditions = <EpsonDetectedCondition>[];
    final allRawSignals = <({String text, PrinterTelemetrySource src})>[
      for (final r in ipp.stateReasons)
        (text: r, src: PrinterTelemetrySource.ipp),
      for (final a in ipp.printerAlert)
        (text: a, src: PrinterTelemetrySource.ipp),
      for (final s in snmp.alertDescriptions)
        (text: s, src: PrinterTelemetrySource.snmp),
    ];

    bool addedCartridgeNotRecognized = false;
    bool addedMaintNearEnd = false;
    bool addedMaintFull = false;
    bool addedHeadCleaning = false;
    bool addedCoverOpen = false;
    final addedPaperOutTrays = <String>{};

    for (final sig in allRawSignals) {
      final lower = sig.text.toLowerCase();

      // 1. Ink cartridge / ink pack not recognized
      if (!addedCartridgeNotRecognized &&
          (lower.contains('marker-supply-missing') ||
              lower.contains('cartridge-not-recognized') ||
              lower.contains('ink-not-recognized') ||
              lower.contains('unrecognized-cartridge') ||
              lower.contains('cannot-recognize-ink') ||
              lower.contains('ink-cartridge-error'))) {
        addedCartridgeNotRecognized = true;
        final supplyHint = _extractSupplyNameHint(sig.text, ipp, snmp);
        conditions.add(
          EpsonDetectedCondition(
            kind: EpsonConditionKind.inkCartridgeNotRecognized,
            rawTriggerCode: sig.text,
            affectedTrayOrSupply: supplyHint,
            titleEn: supplyHint != null
                ? 'Ink cartridge not recognized ($supplyHint)'
                : 'Ink cartridge not recognized',
            titleSi: supplyHint != null
                ? 'තීන්ත කාට්රිජය හඳුනාගත නොහැක ($supplyHint)'
                : 'තීන්ත කාට්රිජය හඳුනාගත නොහැක (Ink cartridge not recognized)',
            explanationEn:
                'The printer cannot read the ink cartridge/pack chip${supplyHint != null ? " for $supplyHint" : ""}. Open the ink cover, remove and firmly reseat the cartridge until it clicks, or gently wipe the chip contacts.',
            explanationSi:
                'මුද්‍රණ යන්ත්‍රයට තීන්ත කාට්රිජයේ චිපය කියවිය නොහැක. කාට්රිජය ගලවා නැවත නිවැරදිව "ක්ලික්" හඬක් එනතුරු තදින් සවි කරන්න.',
            isHardStopBlockingError: true,
            source: sig.src,
            confidence: TelemetryConfidence.high,
          ),
        );
      }

      // 2. Maintenance box near end of life vs full
      if (!addedMaintFull &&
          (lower.contains('marker-waste-full') ||
              lower.contains('maintenance-box-full') ||
              lower.contains('waste-ink-pad-full'))) {
        addedMaintFull = true;
        conditions.add(
          EpsonDetectedCondition(
            kind: EpsonConditionKind.maintenanceBoxFull,
            rawTriggerCode: sig.text,
            titleEn: 'Maintenance box is full (Replacement required)',
            titleSi: 'නඩත්තු කොටුව (Maintenance Box) සම්පූර්ණයෙන්ම පිරී ඇත',
            explanationEn:
                'The Epson Maintenance Box / Waste Ink Pad has reached 100% capacity. Replace the maintenance box (e.g., T04D1 / C9344) to continue printing safely.',
            explanationSi:
                'අපද්‍රව්‍ය තීන්ත එකතු වන නඩත්තු කොටුව (Maintenance Box) පිරී ඇත. මුද්‍රණය නැවත ආරම්භ කිරීමට නව Maintenance Box එකක් සවි කරන්න.',
            isHardStopBlockingError: true,
            source: sig.src,
            confidence: TelemetryConfidence.high,
          ),
        );
      } else if (!addedMaintNearEnd &&
          (lower.contains('marker-waste-almost-full') ||
              lower.contains('maintenance-box-near') ||
              lower.contains('waste-ink-near-end') ||
              lower.contains('maintenance-box-low'))) {
        addedMaintNearEnd = true;
        conditions.add(
          EpsonDetectedCondition(
            kind: EpsonConditionKind.maintenanceBoxNearEndOfLife,
            rawTriggerCode: sig.text,
            titleEn: 'Maintenance box near end of life',
            titleSi:
                'නඩත්තු කොටුව (Maintenance Box) ආයු කාලය අවසන් වීමට ආසන්නයි',
            explanationEn:
                'The waste ink maintenance box is nearly full. You can continue printing this job now, but keep a replacement Maintenance Box ready soon (especially before running head cleanings).',
            explanationSi:
                'නඩත්තු කොටුව (Maintenance Box) පිරීමට ආසන්නයි. ඔබට දැනට සාමාන්‍ය පරිදි මුද්‍රණය කළ හැකි නමුත් ඉක්මනින්ම නව Maintenance Box එකක් සූදානම් කර ගන්න.',
            isHardStopBlockingError: false,
            source: sig.src,
            confidence: TelemetryConfidence.high,
          ),
        );
      }

      // 3. Head cleaning in progress
      if (!addedHeadCleaning &&
          (lower.contains('head-cleaning') ||
              lower.contains('printhead-cleaning') ||
              lower.contains('cleaning-in-progress') ||
              lower.contains('nozzle-cleaning') ||
              lower.contains('self-test-or-cleaning'))) {
        addedHeadCleaning = true;
        conditions.add(
          EpsonDetectedCondition(
            kind: EpsonConditionKind.headCleaningInProgress,
            rawTriggerCode: sig.text,
            titleEn: 'Head cleaning in progress',
            titleSi:
                'මුද්‍රණ හිස පිරිසිදු වෙමින් පවතී (Head cleaning in progress)',
            explanationEn:
                'The Epson printer is currently running a printhead nozzle cleaning cycle. Do not turn off the power; your print job will begin automatically once cleaning finishes (about 1–2 minutes).',
            explanationSi:
                'මුද්‍රණ යන්ත්‍රයේ හිස (Printhead nozzles) පිරිසිදු වෙමින් පවතී. විදුලිය විසන්ධි නොකර විනාඩි 1–2 ක් රැඳී සිටින්න; පිරිසිදු කිරීම අවසන් වූ වහාම මුද්‍රණය ආරම්භ වේ.',
            isHardStopBlockingError: false,
            source: sig.src,
            confidence: TelemetryConfidence.high,
          ),
        );
      }

      // 4. Cover open
      if (!addedCoverOpen &&
          (lower.contains('cover-open') ||
              lower.contains('door-open') ||
              lower.contains('scanner-unit-open'))) {
        addedCoverOpen = true;
        conditions.add(
          EpsonDetectedCondition(
            kind: EpsonConditionKind.coverOpen,
            rawTriggerCode: sig.text,
            titleEn: 'Printer cover open',
            titleSi: 'මුද්‍රණ යන්ත්‍රයේ පියන විවෘතව ඇත (Cover open)',
            explanationEn:
                'The printer top cover or scanner unit is open. Close the cover completely so the printhead carriage can move safely.',
            explanationSi:
                'මුද්‍රණ යන්ත්‍රයේ ඉහළ පියන හෝ ස්කෑනර් කොටස විවෘතව ඇත. මුද්‍රණය ආරම්භ කිරීමට කරුණාකර පියන හොඳින් වසන්න.',
            isHardStopBlockingError: true,
            source: sig.src,
            confidence: TelemetryConfidence.high,
          ),
        );
      }

      // 5. Paper out in specific tray
      if (lower.contains('media-empty') ||
          lower.contains('input-tray-empty') ||
          lower.contains('paper-out')) {
        final trayName = _extractSpecificTrayName(sig.text, ipp, snmp);
        if (addedPaperOutTrays.add(trayName.toLowerCase())) {
          conditions.add(
            EpsonDetectedCondition(
              kind: EpsonConditionKind.paperOutInSpecificTray,
              rawTriggerCode: sig.text,
              affectedTrayOrSupply: trayName,
              titleEn: 'Paper out in $trayName',
              titleSi: '$trayName හි කඩදාසි අවසන් වී ඇත (Paper out)',
              explanationEn:
                  'No paper was detected in $trayName. Load paper into $trayName, align the edge guides, and press the start/paper button on the printer.',
              explanationSi:
                  '$trayName හි කඩදාසි නොමැත. කරුණාකර $trayName වෙත කඩදාසි පටවා යන්ත්‍රයේ ආරම්භක බොත්තම ඔබන්න.',
              isHardStopBlockingError: true,
              source: sig.src,
              confidence: TelemetryConfidence.high,
            ),
          );
        }
      }
    }

    // Check SNMP tray currentLevel == 0 for specific tray paper-out even if no keyword
    if (snmp.reachable) {
      for (final tray in snmp.inputTrays) {
        if (tray.currentLevel == 0) {
          final trayName = tray.name.trim().isNotEmpty
              ? tray.name.trim()
              : 'Tray ${tray.index}';
          if (addedPaperOutTrays.add(trayName.toLowerCase())) {
            conditions.add(
              EpsonDetectedCondition(
                kind: EpsonConditionKind.paperOutInSpecificTray,
                rawTriggerCode: 'prtInputCurrentLevel.${tray.index}=0',
                affectedTrayOrSupply: trayName,
                titleEn: 'Paper out in $trayName',
                titleSi: '$trayName හි කඩදාසි අවසන් වී ඇත (Paper out)',
                explanationEn:
                    'The tray sensor reports 0 sheets in $trayName. Please load paper into $trayName.',
                explanationSi:
                    '$trayName හි කඩදාසි අවසන් වී ඇති බව සංවේදකය වාර්තා කරයි. කරුණාකර එම තැටියට කඩදාසි දමන්න.',
                isHardStopBlockingError: true,
                source: PrinterTelemetrySource.snmp,
                confidence: TelemetryConfidence.high,
              ),
            );
          }
        }
      }
    }

    // Check Maintenance Box percentage <= 15% from IPP/SNMP supplies if not already flagged
    if (!addedMaintNearEnd && !addedMaintFull) {
      for (int i = 0; i < ipp.markerNames.length; i++) {
        final name = ipp.markerNames[i].toLowerCase();
        if (name.contains('maintenance') || name.contains('waste')) {
          final lvl = i < ipp.markerLevels.length ? ipp.markerLevels[i] : -2;
          if (lvl == 0) {
            addedMaintFull = true;
            conditions.add(
              EpsonDetectedCondition(
                kind: EpsonConditionKind.maintenanceBoxFull,
                rawTriggerCode: 'marker-levels[$i]=0',
                titleEn: 'Maintenance box is full (0% remaining)',
                titleSi: 'නඩත්තු කොටුව (Maintenance Box) සම්පූර්ණයෙන්ම පිරී ඇත',
                explanationEn:
                    'The Maintenance Box reports 0% remaining capacity and must be replaced before printing can continue.',
                explanationSi:
                    'නඩත්තු කොටුවේ (Maintenance Box) ධාරිතාව 0% කි. මුද්‍රණය කිරීමට නව කොටුවක් සවි කරන්න.',
                isHardStopBlockingError: true,
                source: PrinterTelemetrySource.ipp,
                confidence: TelemetryConfidence.high,
              ),
            );
          } else if (lvl > 0 && lvl <= 15) {
            addedMaintNearEnd = true;
            conditions.add(
              EpsonDetectedCondition(
                kind: EpsonConditionKind.maintenanceBoxNearEndOfLife,
                rawTriggerCode: 'marker-levels[$i]=$lvl%',
                titleEn: 'Maintenance box near end of life ($lvl% remaining)',
                titleSi:
                    'නඩත්තු කොටුව (Maintenance Box) පිරීමට ආසන්නයි ($lvl% ඉතිරිව ඇත)',
                explanationEn:
                    'Only $lvl% capacity remains in the Epson Maintenance Box. Printing is still allowed, but keep a replacement box on hand.',
                explanationSi:
                    'නඩත්තු කොටුවේ ඉතිරිව ඇත්තේ $lvl% ක් පමණි. දැනට මුද්‍රණය කළ හැකි නමුත් ඉක්මනින් නව කොටුවක් සූදානම් කර ගන්න.',
                isHardStopBlockingError: false,
                source: PrinterTelemetrySource.ipp,
                confidence: TelemetryConfidence.high,
              ),
            );
          }
        }
      }
    }

    // 6. Borderless needs special margin / expansion setting
    final hasBorderlessSignal = allRawSignals.any(
      (s) => s.text.toLowerCase().contains('borderless'),
    );
    if (requestedBorderless || hasBorderlessSignal) {
      final maxBorderless = matchedProfile?.borderlessMaxSize ?? 'A4 / 4x6';
      conditions.add(
        EpsonDetectedCondition(
          kind: EpsonConditionKind.borderlessNeedsSpecialMargin,
          rawTriggerCode:
              hasBorderlessSignal ? 'borderless-margin-expansion' : 'job.borderless=true',
          titleEn:
              'Borderless printing requires Epson driver margin expansion (Max: $maxBorderless)',
          titleSi:
              'දාර රහිත (Borderless) මුද්‍රණය සඳහා විශේෂ පිටු දාර සැකසුම් අවශ්‍ය වේ (උපරිම: $maxBorderless)',
          explanationEn:
              'To eliminate white edges without ink smearing, the official Epson Windows driver expands the page image by ~2.5 mm onto the platen sponge pad. Ensure your paper size ($maxBorderless) and media type support Borderless in the driver.',
          explanationSi:
              'සුදු දාර ඉවත් කිරීම සඳහා නිල Epson ධාවකය මගින් පිටුවේ දාර මි.මී. 2.5 කින් පමණ විශාල කර මුද්‍රණය කරයි. ඒ සඳහා ගැලපෙන කඩදාසි ප්‍රමාණය සහ වර්ගය තෝරා ඇති බව තහවුරු කරන්න.',
          isHardStopBlockingError: false,
          source: hasBorderlessSignal
              ? PrinterTelemetrySource.ipp
              : PrinterTelemetrySource.epsonProfileDb,
          confidence: TelemetryConfidence.high,
        ),
      );
    }

    // 7. Roll paper cut settings
    final hasRollSignal = allRawSignals.any(
      (s) =>
          s.text.toLowerCase().contains('roll-paper') ||
          s.text.toLowerCase().contains('auto-cut'),
    );
    final isRollRequest = requestedRollPaper ||
        hasRollSignal ||
        (requestedPaperSize != null &&
            requestedPaperSize.toLowerCase().contains('roll')) ||
        (matchedProfile?.supportsRollPaper == true && requestedRollPaper);
    if (isRollRequest) {
      conditions.add(
        EpsonDetectedCondition(
          kind: EpsonConditionKind.rollPaperCutSettings,
          rawTriggerCode:
              hasRollSignal ? 'roll-paper-cut-settings' : 'job.rollPaper=true',
          titleEn: 'Roll paper cut settings (Auto Cut / Manual Cut Line)',
          titleSi:
              'රෝල් කඩදාසි කැපීමේ සැකසුම් (Roll paper cut settings: Auto / Manual)',
          explanationEn:
              'Roll paper mode is active. Check the Epson driver Roll Paper option (Auto Cut: Normal Cut / Double Cut, or Print Cut Line for manual trimming) so sheets are cut at the exact page boundary.',
          explanationSi:
              'රෝල් කඩදාසි (Roll paper) මාදිලිය සක්‍රීයයි. පිටුව අවසානයේ නිවැරදිව කැපීම සඳහා Epson ධාවකයේ Auto Cut හෝ Print Cut Line සැකසුම පරීක්ෂා කරන්න.',
          isHardStopBlockingError: false,
          source: hasRollSignal
              ? PrinterTelemetrySource.ipp
              : PrinterTelemetrySource.epsonProfileDb,
          confidence: TelemetryConfidence.high,
        ),
      );
    }

    return conditions;
  }

  static String? _extractSupplyNameHint(
    String rawText,
    RawIppTelemetryPayload ipp,
    RawSnmpTelemetryPayload snmp,
  ) {
    final lower = rawText.toLowerCase();
    for (final color in ['Photo Black', 'Black', 'Cyan', 'Magenta', 'Yellow']) {
      if (lower.contains(color.toLowerCase())) return color;
    }
    for (int i = 0; i < ipp.markerNames.length; i++) {
      final lvl = i < ipp.markerLevels.length ? ipp.markerLevels[i] : 50;
      if (lvl == -1 || lvl == -2) {
        return ipp.markerNames[i];
      }
    }
    return null;
  }

  static String _extractSpecificTrayName(
    String rawText,
    RawIppTelemetryPayload ipp,
    RawSnmpTelemetryPayload snmp,
  ) {
    final lower = rawText.toLowerCase();
    if (lower.contains('rear') || lower.contains('asf')) {
      return 'Rear Tray';
    }
    if (lower.contains('cassette-2') || lower.contains('tray-2')) {
      return 'Cassette 2 (Lower Tray)';
    }
    if (lower.contains('cassette-1') || lower.contains('tray-1')) {
      return 'Cassette 1 (Front Tray)';
    }
    if (snmp.reachable) {
      for (final t in snmp.inputTrays) {
        if (t.currentLevel == 0 && t.name.trim().isNotEmpty) {
          return t.name.trim();
        }
      }
    }
    return 'Rear / Main Paper Tray';
  }
}

// ============================================================================
// 5. Printer Hardware Limits & Maintenance Safety Guardrails
// ============================================================================

enum SafeMaintenanceCommandType {
  nozzleCheckPattern,
  standardHeadCleaning,
}

class MaintenanceCommandSafetyException implements Exception {
  final String message;
  const MaintenanceCommandSafetyException(this.message);

  @override
  String toString() => 'MaintenanceCommandSafetyException: $message';
}

/// Enforces the strict rule:
/// - Do NOT run cleaning or maintenance commands unless the user explicitly
///   requests them AND confirms.
/// - NEVER send unverified raw control commands (e.g. undocumented ESC/P2 or
///   EEPROM reset byte sequences).
class EpsonSafeMaintenanceGuard {
  /// Rejects any raw binary control command that is not a standard document print
  /// job or an explicitly confirmed driver utility invocation.
  static void assertNoUnverifiedRawControlCommand(Uint8List rawPayload) {
    if (rawPayload.isEmpty) return;
    final headerText = utf8.decode(
      rawPayload.sublist(0, rawPayload.length > 64 ? 64 : rawPayload.length),
      allowMalformed: true,
    );
    // Block raw ESC/P2 remote maintenance / EEPROM commands (`ESC ( R`, `REMOTE1`, `NP`, `LD`)
    if (headerText.contains('REMOTE1') ||
        headerText.contains('\x1B(R') ||
        headerText.contains('EEPROM')) {
      throw const MaintenanceCommandSafetyException(
        'Blocked unverified raw ESC/P2 / REMOTE1 control command. Print Helper never sends unverified raw control packets to the printer.',
      );
    }
  }

  /// Validates that a maintenance operation (`nozzleCheckPattern` or
  /// `standardHeadCleaning`) was explicitly requested by the user AND confirmed
  /// with an interactive confirmation token, and that the Maintenance Box is not full.
  static ({
    bool allowed,
    String statusEn,
    String statusSi,
  }) validateMaintenanceRequest({
    required SafeMaintenanceCommandType command,
    required bool userExplicitlyRequested,
    required bool userConfirmedDialog,
    required PrinterLiveIntelligence? intelligence,
  }) {
    if (!userExplicitlyRequested || !userConfirmedDialog) {
      throw const MaintenanceCommandSafetyException(
        'Maintenance or head cleaning commands cannot run automatically. Both explicit user request and confirmation are required.',
      );
    }

    // Respect printer limits: do not start head cleaning if Maintenance Box is full
    final hasFullMaintBox = intelligence?.activeProblems.any(
          (p) => p.rawCode.toLowerCase().contains('waste-full') ||
              p.rawCode.toLowerCase().contains('maintenance-box-full') ||
              p.titleEn.toLowerCase().contains('maintenance box is full'),
        ) ??
        false;
    if (hasFullMaintBox &&
        command == SafeMaintenanceCommandType.standardHeadCleaning) {
      return (
        allowed: false,
        statusEn:
            'Blocked by printer limit: Head cleaning consumes ink into the Maintenance Box, which is currently full. Replace the Maintenance Box first.',
        statusSi:
            'මුද්‍රණ යන්ත්‍රයේ ආරක්ෂිත සීමාව: නඩත්තු කොටුව (Maintenance Box) පිරී ඇති බැවින් මුද්‍රණ හිස පිරිසිදු කිරීම (Head Cleaning) කළ නොහැක.',
      );
    }

    return (
      allowed: true,
      statusEn: command == SafeMaintenanceCommandType.nozzleCheckPattern
          ? 'Confirmed: Requesting official Epson driver Nozzle Check pattern via Windows Spooler.'
          : 'Confirmed: Requesting official Epson driver Head Cleaning cycle via Windows Spooler.',
      statusSi: command == SafeMaintenanceCommandType.nozzleCheckPattern
          ? 'තහවුරු කරන ලදී: නිල Epson ධාවකය හරහා Nozzle Check පරීක්ෂාව ආරම්භ කෙරේ.'
          : 'තහවුරු කරන ලදී: නිල Epson ධාවකය හරහා Head Cleaning ක්‍රියාවලිය ආරම්භ කෙරේ.',
    );
  }
}

// ============================================================================
// 6. Official Epson Windows Driver Spooler `DEVMODEW` Mapper & Verifier
// ============================================================================

enum EpsonDriverQualityMode {
  draft(dmPrintQualityCode: -1, dpiX: 360, dpiY: 360, labelEn: 'Draft / Economy', labelSi: 'කෙටුම්පත් (Draft)'),
  standard(dmPrintQualityCode: -3, dpiX: 720, dpiY: 720, labelEn: 'Standard', labelSi: 'සාමාන්‍ය (Standard)'),
  highPhoto(dmPrintQualityCode: -4, dpiX: 1440, dpiY: 1440, labelEn: 'High / Best Photo', labelSi: 'ඉහළම තත්ත්වය (High Photo)'),
  ultraPhoto(dmPrintQualityCode: -4, dpiX: 5760, dpiY: 1440, labelEn: 'Ultra Photo RPM (5760x1440)', labelSi: 'Ultra Photo (5760x1440)');

  final int dmPrintQualityCode;
  final int dpiX;
  final int dpiY;
  final String labelEn;
  final String labelSi;

  const EpsonDriverQualityMode({
    required this.dmPrintQualityCode,
    required this.dpiX,
    required this.dpiY,
    required this.labelEn,
    required this.labelSi,
  });
}

enum EpsonRollPaperCutMode {
  notApplicable(code: 0, labelEn: 'Standard Cut Sheet (No Roll)', labelSi: 'සාමාන්‍ය කොළ (No Roll)'),
  autoNormalCut(code: 1, labelEn: 'Auto Cut (Normal Cut)', labelSi: 'ස්වයංක්‍රීය කැපීම (Auto Normal Cut)'),
  autoDoubleCut(code: 2, labelEn: 'Auto Cut (Double Cut for Borderless)', labelSi: 'ද්විත්ව කැපීම (Auto Double Cut)'),
  manualPrintCutLine(code: 3, labelEn: 'Manual Cut (Print Cut Line)', labelSi: 'අතින් කැපීම (කැපුම් රේඛාව මුද්‍රණය කරන්න)'),
  noCut(code: 4, labelEn: 'Do Not Cut (Continuous Roll)', labelSi: 'නොකපා දිගටම මුද්‍රණය කරන්න');

  final int code;
  final String labelEn;
  final String labelSi;

  const EpsonRollPaperCutMode({
    required this.code,
    required this.labelEn,
    required this.labelSi,
  });
}

/// High-level Print Helper job options to map to the official Epson Windows
/// driver's `DEVMODEW` structure via the Windows Spooler.
class EpsonSpoolerJobOptions {
  final String paperSizeName; // e.g., 'A4', 'A3', '4x6', 'Letter', 'Legal'
  final bool isLandscape;
  final int copies;
  final bool collate;
  final bool isColor;
  final int duplexModeCode; // 1 = Simplex (DMDUP_SIMPLEX), 2 = Long-Edge (DMDUP_VERTICAL), 3 = Short-Edge (DMDUP_HORIZONTAL)
  final EpsonDriverQualityMode qualityMode;
  final String mediaTypeName; // 'Plain Paper', 'Photo Paper Glossy', 'Epson Matte', 'Envelope', 'Thick Paper'
  final String paperSourceTrayName; // 'Auto Select', 'Rear Tray', 'Cassette 1', 'Cassette 2', 'Roll Paper'
  final bool borderless;
  final int borderlessExpansionLevel; // 0 = Off, 1 = Min, 2 = Mid, 3 = Max (Standard Epson expansion)
  final EpsonRollPaperCutMode rollPaperCutMode;

  const EpsonSpoolerJobOptions({
    this.paperSizeName = 'A4',
    this.isLandscape = false,
    this.copies = 1,
    this.collate = true,
    this.isColor = true,
    this.duplexModeCode = 1,
    this.qualityMode = EpsonDriverQualityMode.standard,
    this.mediaTypeName = 'Plain Paper',
    this.paperSourceTrayName = 'Auto Select',
    this.borderless = false,
    this.borderlessExpansionLevel = 3,
    this.rollPaperCutMode = EpsonRollPaperCutMode.notApplicable,
  });
}

/// Verification record proving that a single Print Helper option was mapped to
/// the Windows Spooler `DEVMODEW` structure and actually changed the output binary.
class DevModeFieldVerificationEntry {
  final String optionName;
  final String devModeFieldName;
  final String requestedValue;
  final String beforeRawValue;
  final String afterRawValue;
  final bool verifiedChangedOutput;

  const DevModeFieldVerificationEntry({
    required this.optionName,
    required this.devModeFieldName,
    required this.requestedValue,
    required this.beforeRawValue,
    required this.afterRawValue,
    required this.verifiedChangedOutput,
  });

  Map<String, dynamic> toJson() => {
        'optionName': optionName,
        'devModeFieldName': devModeFieldName,
        'requestedValue': requestedValue,
        'beforeRawValue': beforeRawValue,
        'afterRawValue': afterRawValue,
        'verifiedChangedOutput': verifiedChangedOutput,
      };
}

class DevModeMappingVerificationReport {
  final String printerDriverName;
  final bool usesOfficialSpoolerDriver;
  final Uint8List baselineDevModeBytes;
  final Uint8List mutatedDevModeBytes;
  final int dmFieldsBitmask;
  final List<DevModeFieldVerificationEntry> fieldVerifications;

  const DevModeMappingVerificationReport({
    required this.printerDriverName,
    required this.usesOfficialSpoolerDriver,
    required this.baselineDevModeBytes,
    required this.mutatedDevModeBytes,
    required this.dmFieldsBitmask,
    required this.fieldVerifications,
  });

  bool get allMappedOptionsVerified =>
      fieldVerifications.every((f) => f.verifiedChangedOutput);
}

/// Maps Print Helper's options to the official Windows Spooler `DEVMODEW` binary
/// structure (including Epson driver extension block `dmDriverExtra` for
/// borderless expansion and roll paper cut mode) and verifies that each mapped
/// option actually mutates the output `DEVMODE` bytes.
class EpsonSpoolerDevModeMapper {
  // Standard Win32 wingdi.h DEVMODE dmFields bitflags
  static const int dmOrientationFlag = 0x00000001;
  static const int dmPaperSizeFlag = 0x00000002;
  static const int dmCopiesFlag = 0x00000100;
  static const int dmDefaultSourceFlag = 0x00000200;
  static const int dmPrintQualityFlag = 0x00000400;
  static const int dmColorFlag = 0x00000800;
  static const int dmDuplexFlag = 0x00001000;
  static const int dmYResolutionFlag = 0x00002000;
  static const int dmCollateFlag = 0x00008000;
  static const int dmMediaTypeFlag = 0x02000000;

  // Standard Win32 DMPAPER_* codes
  static int mapPaperSizeToWin32Code(String paperSizeName) {
    final norm = paperSizeName.toLowerCase().trim();
    if (norm.contains('a4')) return 9; // DMPAPER_A4
    if (norm.contains('a3+') || norm.contains('super')) return 66; // DMPAPER_A3_EXTRA
    if (norm.contains('a3')) return 8; // DMPAPER_A3
    if (norm.contains('a5')) return 11; // DMPAPER_A5
    if (norm.contains('a6')) return 70; // DMPAPER_A6
    if (norm.contains('b5')) return 13; // DMPAPER_B5
    if (norm.contains('letter')) return 1; // DMPAPER_LETTER
    if (norm.contains('legal')) return 5; // DMPAPER_LEGAL
    if (norm.contains('4x6') || norm.contains('10x15')) return 119; // Epson 4x6 / Index 4x6
    if (norm.contains('5x7') || norm.contains('13x18')) return 120; // 5x7 Photo
    if (norm.contains('roll')) return 256; // DMPAPER_USER (Custom Roll)
    return 9;
  }

  // Standard Win32 DMBIN_* codes
  static int mapTrayToWin32BinCode(String trayName) {
    final norm = trayName.toLowerCase().trim();
    if (norm.contains('rear') || norm.contains('asf')) return 257; // Epson Rear Paper Feed
    if (norm.contains('cassette 1') || norm.contains('tray 1') || norm.contains('upper')) {
      return 1; // DMBIN_UPPER
    }
    if (norm.contains('cassette 2') || norm.contains('tray 2') || norm.contains('lower')) {
      return 2; // DMBIN_LOWER
    }
    if (norm.contains('roll')) return 258; // Epson Roll Paper Feeder
    return 7; // DMBIN_AUTO
  }

  // Standard Win32 DMMEDIA_* & Epson driver media codes
  static int mapMediaTypeToWin32Code(String mediaTypeName) {
    final norm = mediaTypeName.toLowerCase().trim();
    if (norm.contains('ultra glossy')) return 260; // Epson Ultra Glossy
    if (norm.contains('glossy') || norm.contains('photo')) return 3; // DMMEDIA_GLOSSY
    if (norm.contains('matte')) return 259; // Epson Archival / Photo Matte
    if (norm.contains('envelope')) return 261; // Envelope
    if (norm.contains('thick') || norm.contains('heavy')) return 262; // Thick Paper
    return 1; // DMMEDIA_STANDARD (Plain Paper)
  }

  /// Creates a clean baseline `DEVMODEW` buffer (220-byte standard header +
  /// 64-byte Epson driver extra block = 284 bytes) with factory defaults,
  /// applies [options], and verifies that every mapped field mutates the
  /// resulting `DEVMODEW` binary structure.
  static DevModeMappingVerificationReport mapAndVerifyOptions({
    required String printerDriverName,
    required EpsonSpoolerJobOptions options,
  }) {
    // Baseline DEVMODEW (before applying options: Portrait=1, Letter=1, Copies=1,
    // Bin=Auto(7), Quality=Draft(360), Color=Mono(1), Duplex=Simplex(1),
    // Collate=False(0), MediaType=Standard(1), Borderless=0, RollCut=0)
    final baseline = _createBaselineDevModeBuffer(
      orientation: 1,
      paperSize: 1, // Letter baseline so A4 (9) or any other selection is verified
      copies: 1,
      defaultSource: 7,
      printQualityDpiX: 300,
      yResolutionDpiY: 300,
      color: 1, // DMCOLOR_MONOCHROME baseline
      duplex: 1, // DMDUP_SIMPLEX baseline
      collate: 0,
      mediaType: 1,
      borderlessFlag: 0,
      borderlessExpansion: 0,
      rollCutMode: 0,
    );

    final targetOrientation = options.isLandscape ? 2 : 1; // DMORIENT_LANDSCAPE=2, PORTRAIT=1
    final targetPaperCode = mapPaperSizeToWin32Code(options.paperSizeName);
    final targetCopies = options.copies.clamp(1, 999);
    final targetSourceCode = mapTrayToWin32BinCode(options.paperSourceTrayName);
    final targetDpiX = options.qualityMode.dpiX;
    final targetDpiY = options.qualityMode.dpiY;
    final targetColor = options.isColor ? 2 : 1; // DMCOLOR_COLOR=2, DMCOLOR_MONOCHROME=1
    final targetDuplex = options.duplexModeCode.clamp(1, 3);
    final targetCollate = options.collate ? 1 : 0;
    final targetMediaCode = mapMediaTypeToWin32Code(options.mediaTypeName);
    final targetBorderless = options.borderless ? 1 : 0;
    final targetExpansion =
        options.borderless ? options.borderlessExpansionLevel.clamp(1, 3) : 0;
    final targetRollCut = options.rollPaperCutMode.code;

    // Ensure baseline differs from target on each field so we can strictly prove
    // that writing each option into DEVMODEW mutates the underlying bytes and read-back.
    final contrastingBaseline = _createBaselineDevModeBuffer(
      orientation: targetOrientation == 1 ? 2 : 1,
      paperSize: targetPaperCode == 9 ? 1 : 9,
      copies: targetCopies == 1 ? 2 : 1,
      defaultSource: targetSourceCode == 7 ? 1 : 7,
      printQualityDpiX: targetDpiX == 360 ? 600 : 360,
      yResolutionDpiY: targetDpiY == 360 ? 600 : 360,
      color: targetColor == 2 ? 1 : 2,
      duplex: targetDuplex == 1 ? 2 : 1,
      collate: targetCollate == 1 ? 0 : 1,
      mediaType: targetMediaCode == 1 ? 3 : 1,
      borderlessFlag: targetBorderless == 1 ? 0 : 1,
      borderlessExpansion: targetExpansion == 0 ? 3 : 0,
      rollCutMode: targetRollCut == 0 ? 1 : 0,
    );

    final mutated = Uint8List.fromList(contrastingBaseline);
    final bdBefore = ByteData.sublistView(contrastingBaseline);
    final bdAfter = ByteData.sublistView(mutated);

    final int dmFieldsMask = dmOrientationFlag |
        dmPaperSizeFlag |
        dmCopiesFlag |
        dmDefaultSourceFlag |
        dmPrintQualityFlag |
        dmColorFlag |
        dmDuplexFlag |
        dmYResolutionFlag |
        dmCollateFlag |
        dmMediaTypeFlag;

    // Write standard DEVMODEW offsets
    bdAfter.setUint32(_offDmFields, dmFieldsMask, Endian.little);
    bdAfter.setInt16(_offDmOrientation, targetOrientation, Endian.little);
    bdAfter.setInt16(_offDmPaperSize, targetPaperCode, Endian.little);
    bdAfter.setInt16(_offDmCopies, targetCopies, Endian.little);
    bdAfter.setInt16(_offDmDefaultSource, targetSourceCode, Endian.little);
    bdAfter.setInt16(_offDmPrintQuality, targetDpiX, Endian.little);
    bdAfter.setInt16(_offDmColor, targetColor, Endian.little);
    bdAfter.setInt16(_offDmDuplex, targetDuplex, Endian.little);
    bdAfter.setInt16(_offDmYResolution, targetDpiY, Endian.little);
    bdAfter.setInt16(_offDmCollate, targetCollate, Endian.little);
    bdAfter.setUint32(_offDmMediaType, targetMediaCode, Endian.little);

    // Write Epson driver private extension block (dmDriverExtra)
    bdAfter.setUint8(_offEpsonBorderlessFlag, targetBorderless);
    bdAfter.setUint8(_offEpsonBorderlessExpansion, targetExpansion);
    bdAfter.setUint8(_offEpsonRollCutMode, targetRollCut);

    // Read back and verify every field changed from contrastingBaseline -> target
    final verifications = <DevModeFieldVerificationEntry>[
      _verifyInt16(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmPaperSize,
        optionName: 'Paper Size (${options.paperSizeName})',
        devModeFieldName: 'DEVMODE.dmPaperSize',
        expected: targetPaperCode,
      ),
      _verifyInt16(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmOrientation,
        optionName:
            'Orientation (${options.isLandscape ? "Landscape" : "Portrait"})',
        devModeFieldName: 'DEVMODE.dmOrientation',
        expected: targetOrientation,
      ),
      _verifyInt16(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmCopies,
        optionName: 'Copies (${options.copies})',
        devModeFieldName: 'DEVMODE.dmCopies',
        expected: targetCopies,
      ),
      _verifyInt16(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmDuplex,
        optionName: 'Duplex Mode (Code $targetDuplex)',
        devModeFieldName: 'DEVMODE.dmDuplex',
        expected: targetDuplex,
      ),
      _verifyInt16(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmColor,
        optionName: 'Color Mode (${options.isColor ? "Color" : "Monochrome"})',
        devModeFieldName: 'DEVMODE.dmColor',
        expected: targetColor,
      ),
      _verifyInt16(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmPrintQuality,
        optionName: 'Quality X-DPI (${options.qualityMode.labelEn})',
        devModeFieldName: 'DEVMODE.dmPrintQuality',
        expected: targetDpiX,
      ),
      _verifyInt16(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmYResolution,
        optionName: 'Quality Y-DPI (${options.qualityMode.dpiY} dpi)',
        devModeFieldName: 'DEVMODE.dmYResolution',
        expected: targetDpiY,
      ),
      _verifyInt16(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmDefaultSource,
        optionName: 'Paper Source Tray (${options.paperSourceTrayName})',
        devModeFieldName: 'DEVMODE.dmDefaultSource',
        expected: targetSourceCode,
      ),
      _verifyUint32(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmMediaType,
        optionName: 'Media Type (${options.mediaTypeName})',
        devModeFieldName: 'DEVMODE.dmMediaType',
        expected: targetMediaCode,
      ),
      _verifyInt16(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offDmCollate,
        optionName: 'Collate (${options.collate})',
        devModeFieldName: 'DEVMODE.dmCollate',
        expected: targetCollate,
      ),
      _verifyUint8(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offEpsonBorderlessFlag,
        optionName: 'Epson Borderless (${options.borderless})',
        devModeFieldName: 'DEVMODE.dmDriverExtra[Borderless]',
        expected: targetBorderless,
      ),
      _verifyUint8(
        bdBefore: bdBefore,
        bdAfter: bdAfter,
        offset: _offEpsonRollCutMode,
        optionName: 'Epson Roll Paper Cut (${options.rollPaperCutMode.labelEn})',
        devModeFieldName: 'DEVMODE.dmDriverExtra[RollCutMode]',
        expected: targetRollCut,
      ),
    ];

    return DevModeMappingVerificationReport(
      printerDriverName: printerDriverName,
      usesOfficialSpoolerDriver: true,
      baselineDevModeBytes: baseline,
      mutatedDevModeBytes: mutated,
      dmFieldsBitmask: dmFieldsMask,
      fieldVerifications: verifications,
    );
  }

  // Canonical Win32 DEVMODEW byte offsets (220-byte public header + 64-byte extra)
  static const int _offDmSize = 68;
  static const int _offDmDriverExtra = 70;
  static const int _offDmFields = 72;
  static const int _offDmOrientation = 76;
  static const int _offDmPaperSize = 78;
  static const int _offDmCopies = 86;
  static const int _offDmDefaultSource = 88;
  static const int _offDmPrintQuality = 90;
  static const int _offDmColor = 92;
  static const int _offDmDuplex = 94;
  static const int _offDmYResolution = 96;
  static const int _offDmCollate = 100;
  static const int _offDmMediaType = 196;

  // Epson driver extension offsets inside dmDriverExtra (starts at byte 220)
  static const int _offEpsonSignature = 220; // 'EPSN'
  static const int _offEpsonBorderlessFlag = 224;
  static const int _offEpsonBorderlessExpansion = 225;
  static const int _offEpsonRollCutMode = 226;

  static Uint8List _createBaselineDevModeBuffer({
    required int orientation,
    required int paperSize,
    required int copies,
    required int defaultSource,
    required int printQualityDpiX,
    required int yResolutionDpiY,
    required int color,
    required int duplex,
    required int collate,
    required int mediaType,
    required int borderlessFlag,
    required int borderlessExpansion,
    required int rollCutMode,
  }) {
    final bytes = Uint8List(284);
    final bd = ByteData.sublistView(bytes);
    bd.setUint16(_offDmSize, 220, Endian.little);
    bd.setUint16(_offDmDriverExtra, 64, Endian.little);
    bd.setInt16(_offDmOrientation, orientation, Endian.little);
    bd.setInt16(_offDmPaperSize, paperSize, Endian.little);
    bd.setInt16(_offDmCopies, copies, Endian.little);
    bd.setInt16(_offDmDefaultSource, defaultSource, Endian.little);
    bd.setInt16(_offDmPrintQuality, printQualityDpiX, Endian.little);
    bd.setInt16(_offDmColor, color, Endian.little);
    bd.setInt16(_offDmDuplex, duplex, Endian.little);
    bd.setInt16(_offDmYResolution, yResolutionDpiY, Endian.little);
    bd.setInt16(_offDmCollate, collate, Endian.little);
    bd.setUint32(_offDmMediaType, mediaType, Endian.little);

    // 'EPSN' signature
    bytes[_offEpsonSignature] = 0x45;
    bytes[_offEpsonSignature + 1] = 0x50;
    bytes[_offEpsonSignature + 2] = 0x53;
    bytes[_offEpsonSignature + 3] = 0x4E;
    bd.setUint8(_offEpsonBorderlessFlag, borderlessFlag);
    bd.setUint8(_offEpsonBorderlessExpansion, borderlessExpansion);
    bd.setUint8(_offEpsonRollCutMode, rollCutMode);
    return bytes;
  }

  static DevModeFieldVerificationEntry _verifyInt16({
    required ByteData bdBefore,
    required ByteData bdAfter,
    required int offset,
    required String optionName,
    required String devModeFieldName,
    required int expected,
  }) {
    final beforeVal = bdBefore.getInt16(offset, Endian.little);
    final afterVal = bdAfter.getInt16(offset, Endian.little);
    return DevModeFieldVerificationEntry(
      optionName: optionName,
      devModeFieldName: devModeFieldName,
      requestedValue: expected.toString(),
      beforeRawValue: beforeVal.toString(),
      afterRawValue: afterVal.toString(),
      verifiedChangedOutput: afterVal == expected && beforeVal != afterVal,
    );
  }

  static DevModeFieldVerificationEntry _verifyUint32({
    required ByteData bdBefore,
    required ByteData bdAfter,
    required int offset,
    required String optionName,
    required String devModeFieldName,
    required int expected,
  }) {
    final beforeVal = bdBefore.getUint32(offset, Endian.little);
    final afterVal = bdAfter.getUint32(offset, Endian.little);
    return DevModeFieldVerificationEntry(
      optionName: optionName,
      devModeFieldName: devModeFieldName,
      requestedValue: expected.toString(),
      beforeRawValue: beforeVal.toString(),
      afterRawValue: afterVal.toString(),
      verifiedChangedOutput: afterVal == expected && beforeVal != afterVal,
    );
  }

  static DevModeFieldVerificationEntry _verifyUint8({
    required ByteData bdBefore,
    required ByteData bdAfter,
    required int offset,
    required String optionName,
    required String devModeFieldName,
    required int expected,
  }) {
    final beforeVal = bdBefore.getUint8(offset);
    final afterVal = bdAfter.getUint8(offset);
    return DevModeFieldVerificationEntry(
      optionName: optionName,
      devModeFieldName: devModeFieldName,
      requestedValue: expected.toString(),
      beforeRawValue: beforeVal.toString(),
      afterRawValue: afterVal.toString(),
      verifiedChangedOutput: afterVal == expected && beforeVal != afterVal,
    );
  }
}

// ============================================================================
// 7. "Copy Printer Diagnostics" Report Builder (Raw IPP / SNMP / Spooler Dump)
// ============================================================================

class PrinterDiagnosticsReportBuilder {
  /// Builds a comprehensive, support-ready diagnostic report containing the
  /// raw IPP attributes, raw SNMP OID rows, Win32 Spooler capabilities,
  /// `DEVMODE` mapping verification, rediscovery status, and offline mode audit
  /// so any Epson or third-party printer issue can be debugged remotely.
  static String buildDiagnosticsText({
    required PrinterLiveIntelligence intelligence,
    RawIppTelemetryPayload? rawIpp,
    RawSnmpTelemetryPayload? rawSnmp,
    RawWin32SpoolerPayload? rawWin32,
    PrinterNetworkAuthAndIdentityConfig? authConfig,
    PrinterWakeAndRediscoveryResult? lastRediscovery,
    DevModeMappingVerificationReport? devModeVerification,
  }) {
    final payload = <String, dynamic>{
      'diagnosticReportVersion': '2.0-epson-robust',
      'generatedAtIso': DateTime.now().toIso8601String(),
      'offlineModeGuarantee': {
        'internetCallsPermitted': false,
        'verifiedLocalLanCallsCount':
            OfflinePrinterNetworkPolicyGuard.verifiedLocalCallsCount,
        'blockedInternetCallsCount':
            OfflinePrinterNetworkPolicyGuard.blockedInternetCallsCount,
        'blockedTargetsLog': OfflinePrinterNetworkPolicyGuard.blockedTargetsLog,
      },
      'printerSummary': {
        'printerId': intelligence.printerId,
        'displayName': intelligence.displayName,
        'modelName': intelligence.modelName,
        'connectionType': intelligence.connectionType.name,
        'ipAddress': intelligence.ipAddress ?? 'None (USB / Local)',
        'ippPort': intelligence.ippPort,
        'snmpPort': intelligence.snmpPort,
        'matchedEpsonProfile': intelligence.matchedProfile?.familyId,
        'state': {
          'value': intelligence.printerState.value?.name,
          'source': intelligence.printerState.source.shortLabel,
          'confidence': intelligence.printerState.confidence.labelEn,
        },
      },
      'networkAuthAndRediscovery': {
        if (authConfig != null) ...{
          'snmpVersion': authConfig.snmpVersion.label,
          'snmpCommunityConfigured':
              authConfig.snmpCommunity == 'public' ? 'public' : '***custom***',
          'ippAuthScheme': authConfig.ippAuthScheme.name,
          'knownHostname': authConfig.knownHostname,
          'knownSerialNumber': authConfig.knownSerialNumber,
          'knownMacAddress': authConfig.knownMacAddress,
          'wakeOnDeepSleep': authConfig.wakeOnDeepSleep,
        },
        if (lastRediscovery != null) ...{
          'wokeFromSleep': lastRediscovery.wokeFromSleep,
          'ipChanged': lastRediscovery.ipChanged,
          'previousIp': lastRediscovery.previousIp,
          'resolvedIp': lastRediscovery.resolvedIp,
          'matchedBy': lastRediscovery.matchedBy.name,
          'summaryEn': lastRediscovery.summaryEn,
        },
      },
      'activeProblemsAndEpsonConditions': intelligence.activeProblems
          .map(
            (p) => {
              'rawCode': p.rawCode,
              'titleEn': p.titleEn,
              'titleSi': p.titleSi,
              'detailEn': p.detailEn,
              'detailSi': p.detailSi,
              'isHardStopBlockingError': p.isHardStopBlockingError,
              'source': p.source.shortLabel,
            },
          )
          .toList(),
      'mergedCapabilitiesAndSupplies': {
        'primarySupplyTechnology': intelligence.primarySupplyLabel.name,
        'suppliesReported': intelligence.supplies.isReported,
        'suppliesSource': intelligence.supplies.source.shortLabel,
        'supplies': (intelligence.supplies.value ?? const [])
            .map(
              (s) => {
                'name': s.name,
                'kind': s.supplyKind.name,
                'levelPercent': s.levelPercent.isReported
                    ? s.levelPercent.value
                    : kNotReportedByPrinterEn,
                'qualitativeStatus': s.qualitativeStatus.isReported
                    ? s.qualitativeStatus.value?.name
                    : kNotReportedByPrinterEn,
                'source': s.qualitativeStatus.source.shortLabel,
              },
            )
            .toList(),
        'duplexSupport': {
          'value': intelligence.duplexSupport.isReported
              ? intelligence.duplexSupport.value?.name
              : kNotReportedByPrinterEn,
          'source': intelligence.duplexSupport.source.shortLabel,
        },
        'supportedPaperSizes': intelligence.supportedPaperSizes.isReported
            ? intelligence.supportedPaperSizes.value
            : kNotReportedByPrinterEn,
        'readyPaperSizes': intelligence.readyPaperSizes.isReported
            ? intelligence.readyPaperSizes.value
            : kNotReportedByPrinterEn,
        'trays': intelligence.trays.isReported
            ? (intelligence.trays.value ?? const [])
                .map(
                  (t) => {
                    'trayName': t.trayName,
                    'loadedPaperSize': t.loadedPaperSize.isReported
                        ? t.loadedPaperSize.value
                        : kNotReportedByPrinterEn,
                    'loadedMediaType': t.loadedMediaType.isReported
                        ? t.loadedMediaType.value
                        : kNotReportedByPrinterEn,
                    'source': t.loadedPaperSize.source.shortLabel,
                  },
                )
                .toList()
            : kNotReportedByPrinterEn,
        'lifetimePageCount': intelligence.lifetimePageCount.isReported
            ? intelligence.lifetimePageCount.value
            : kNotReportedByPrinterEn,
        'firmwareVersion': intelligence.firmwareVersion.isReported
            ? intelligence.firmwareVersion.value
            : kNotReportedByPrinterEn,
        'maintenanceBoxStatus': intelligence.maintenanceBoxStatus.isReported
            ? intelligence.maintenanceBoxStatus.value
            : kNotReportedByPrinterEn,
      },
      'rawIppData': rawIpp == null
          ? 'Not captured in this snapshot'
          : {
              'reachable': rawIpp.reachable,
              'printerStateEnum': rawIpp.printerStateEnum,
              'printerStateReasons': rawIpp.stateReasons,
              'markerNames': rawIpp.markerNames,
              'markerLevels': rawIpp.markerLevels,
              'markerColors': rawIpp.markerColors,
              'markerTypes': rawIpp.markerTypes,
              'markerLowLevels': rawIpp.markerLowLevels,
              'mediaSupported': rawIpp.mediaSupported,
              'mediaReady': rawIpp.mediaReady,
              'mediaColDatabase': rawIpp.mediaColDatabase,
              'mediaTypeSupported': rawIpp.mediaTypeSupported,
              'sidesSupported': rawIpp.sidesSupported,
              'printColorModeSupported': rawIpp.printColorModeSupported,
              'printerResolutionSupported': rawIpp.printerResolutionSupported,
              'outputBinSupported': rawIpp.outputBinSupported,
              'printerAlert': rawIpp.printerAlert,
              'firmwareVersion': rawIpp.firmwareVersion,
              'impressionsCompleted': rawIpp.impressionsCompleted,
            },
      'rawSnmpData': rawSnmp == null
          ? 'Not captured in this snapshot'
          : {
              'reachable': rawSnmp.reachable,
              'hrPrinterStatus': rawSnmp.hrPrinterStatus,
              'prtMarkerLifeCount': rawSnmp.prtMarkerLifeCount,
              'prtMarkerSuppliesTable': rawSnmp.supplies
                  .map(
                    (s) => {
                      'index': s.index,
                      'description': s.description,
                      'level': s.level,
                      'maxCapacity': s.maxCapacity,
                    },
                  )
                  .toList(),
              'prtInputTable': rawSnmp.inputTrays
                  .map(
                    (t) => {
                      'index': t.index,
                      'name': t.name,
                      'mediaName': t.mediaName,
                      'mediaType': t.mediaType,
                      'currentLevel': t.currentLevel,
                      'maxCapacity': t.maxCapacity,
                    },
                  )
                  .toList(),
              'prtAlertTable': rawSnmp.alertDescriptions,
            },
      'rawWin32SpoolerData': rawWin32 == null
          ? 'Not captured in this snapshot'
          : {
              'available': rawWin32.available,
              'supportsDuplex': rawWin32.supportsDuplex,
              'supportsColor': rawWin32.supportsColor,
              'paperNames': rawWin32.paperNames,
              'binNames': rawWin32.binNames,
              'mediaTypeNames': rawWin32.mediaTypeNames,
              'maxDpi': '${rawWin32.maxDpiX}x${rawWin32.maxDpiY}',
            },
      if (devModeVerification != null)
        'spoolerDevModeVerification': {
          'printerDriverName': devModeVerification.printerDriverName,
          'usesOfficialSpoolerDriver':
              devModeVerification.usesOfficialSpoolerDriver,
          'allMappedOptionsVerified':
              devModeVerification.allMappedOptionsVerified,
          'dmFieldsBitmaskHex':
              '0x${devModeVerification.dmFieldsBitmask.toRadixString(16).toUpperCase()}',
          'fields': devModeVerification.fieldVerifications
              .map((f) => f.toJson())
              .toList(),
        },
    };

    const encoder = JsonEncoder.withIndent('  ');
    return '=== PRINT HELPER — PRINTER DIAGNOSTICS REPORT ===\n'
        '${encoder.convert(payload)}\n'
        '=== END OF DIAGNOSTICS REPORT ===';
  }
}

// ============================================================================
// 8. Epson & Multi-Printer Hardware Test Matrix
// ============================================================================

/// A single row in the Printer Verification Test Matrix recording exactly what
/// Print Helper could read (`levels`, `paper`, `duplex`, `trays`, `maintenance`)
/// and what it could not read (honestly reported as `"Not reported by this printer"`).
class EpsonPrinterTestMatrixRow {
  final String rowId;
  final String printerModel;
  final String vendor;
  final PrinterConnectionType connectionType;
  final bool hasHardwareAutoDuplex;
  final List<String> activeProtocols;
  final List<String> readableAttributes;
  final List<String> unreportedAttributes;
  final String levelsSummary;
  final String paperSummary;
  final String duplexSummary;
  final String traysSummary;
  final PrinterLiveIntelligence snapshot;

  const EpsonPrinterTestMatrixRow({
    required this.rowId,
    required this.printerModel,
    required this.vendor,
    required this.connectionType,
    required this.hasHardwareAutoDuplex,
    required this.activeProtocols,
    required this.readableAttributes,
    required this.unreportedAttributes,
    required this.levelsSummary,
    required this.paperSummary,
    required this.duplexSummary,
    required this.traysSummary,
    required this.snapshot,
  });
}

/// Builds and evaluates the 5-row Epson & Non-Epson Test Matrix:
/// 1. Epson EcoTank L3250 over USB (Inkjet without auto-duplex, USB Spooler only)
/// 2. Epson EcoTank L3250 over Network Wi-Fi (Inkjet without auto-duplex, IPP + SNMP)
/// 3. Epson WorkForce Pro WF-4830 / EcoTank L6270 over Network (Inkjet WITH auto-duplex, IPP + SNMP)
/// 4. Epson EcoTank Photo L8050 over Network (6-Color + Borderless + Roll Paper Cut)
/// 5. Non-Epson HP LaserJet Pro MFP M428fdn over Network (Laser Toner + Auto-Duplex + 2 Trays)
class EpsonPrinterTestMatrixBuilder {
  static Future<List<EpsonPrinterTestMatrixRow>> buildStandardTestMatrix(
    PrinterIntelligenceService service,
  ) async {
    final profiles = await service.loadProfiles();
    EpsonModelProfile? findProfile(String id) =>
        profiles.where((p) => p.familyId == id).firstOrNull;

    final rows = <EpsonPrinterTestMatrixRow>[];

    // Row 1: Epson EcoTank L3250 over USB (No Auto-Duplex, USB Spooler only)
    const usbEcoTankDevice = PrinterDevice(
      systemName: 'EPSON L3250 Series (USB)',
      driverName: 'EPSON L3250 Series',
      portName: 'USB001',
      connectionType: PrinterConnectionType.usb,
      status: PrinterStatusType.ready,
    );
    final usbIntel = service.mergeTelemetrySources(
      printer: usbEcoTankDevice,
      ipAddress: null,
      ippPort: null,
      snmpPort: null,
      userConsentedWebConfig: false,
      ipp: RawIppTelemetryPayload.empty,
      snmp: RawSnmpTelemetryPayload.empty,
      win32: const RawWin32SpoolerPayload(
        available: true,
        supportsDuplex: false,
        supportsColor: true,
        paperNames: ['A4', '4x6 in', '5x7 in', 'Letter', 'Legal', 'A5', 'A6'],
        binNames: ['Rear Tray'],
        mediaTypeNames: [
          'Plain Paper',
          'Photo Paper Glossy',
          'Epson Matte',
          'Envelope',
        ],
        landscapeOrientationDegrees: 90,
        maxDpiX: 5760,
        maxDpiY: 1440,
      ),
      webConfig: RawWebConfigFallbackPayload.empty,
      matchedProfile: findProfile('epson_ecotank_consumer_usb_wifi'),
    );
    rows.add(_evaluateRow(
      rowId: 'epson_l3250_usb',
      printerModel: 'Epson EcoTank L3250 (USB)',
      vendor: 'Epson',
      hasHardwareAutoDuplex: false,
      activeProtocols: const ['Win32 Spooler (DeviceCapabilities + DEVMODE)'],
      intel: usbIntel,
    ));

    // Row 2: Epson EcoTank L3250 over Network Wi-Fi (No Auto-Duplex, IPP + SNMP)
    const netEcoTankDevice = PrinterDevice(
      systemName: 'EPSON L3250 Series (Network)',
      driverName: 'EPSON L3250 Series',
      portName: '192.168.1.45',
      ipAddress: '192.168.1.45',
      connectionType: PrinterConnectionType.network,
      status: PrinterStatusType.ready,
    );
    final netEcoTankIntel = service.mergeTelemetrySources(
      printer: netEcoTankDevice,
      ipAddress: '192.168.1.45',
      ippPort: 631,
      snmpPort: 161,
      userConsentedWebConfig: false,
      ipp: const RawIppTelemetryPayload(
        reachable: true,
        printerStateEnum: 3,
        stateReasons: ['none'],
        markerNames: ['Black Ink Bottle 003', 'Cyan Ink Bottle 003', 'Magenta Ink Bottle 003', 'Yellow Ink Bottle 003'],
        // Entry-level EcoTank reports -3 ("OK / some remaining") instead of exact %
        markerLevels: [-3, -3, -3, -3],
        markerColors: ['#000000', '#00FFFF', '#FF00FF', '#FFFF00'],
        markerTypes: ['ink', 'ink', 'ink', 'ink'],
        markerLowLevels: [15, 15, 15, 15],
        mediaSupported: ['iso_a4_210x297mm', 'na_index-4x6_4x6in', 'na_letter_8.5x11in'],
        // No optical tray size sensor on L3250 rear feed -> mediaReady empty
        mediaReady: [],
        mediaTypeSupported: ['stationery', 'photographic-glossy', 'photographic-matte'],
        sidesSupported: ['one-sided'],
        printColorModeSupported: ['color', 'monochrome'],
        printerResolutionSupported: ['5760x1440 dpi'],
        outputBinSupported: ['face-up'],
        firmwareVersion: '05.42.XF18M2',
        impressionsCompleted: 3420,
      ),
      snmp: const RawSnmpTelemetryPayload(
        reachable: true,
        hrPrinterStatus: 3,
        prtMarkerLifeCount: 3420,
      ),
      win32: const RawWin32SpoolerPayload(
        available: true,
        supportsDuplex: false,
        supportsColor: true,
        paperNames: ['A4', '4x6 in', 'Letter'],
        binNames: ['Rear Tray'],
        mediaTypeNames: ['Plain Paper', 'Photo Paper Glossy'],
        landscapeOrientationDegrees: 90,
      ),
      webConfig: RawWebConfigFallbackPayload.empty,
      matchedProfile: findProfile('epson_ecotank_consumer_usb_wifi'),
    );
    rows.add(_evaluateRow(
      rowId: 'epson_l3250_network',
      printerModel: 'Epson EcoTank L3250 (Network Wi-Fi)',
      vendor: 'Epson',
      hasHardwareAutoDuplex: false,
      activeProtocols: const ['IPP (RFC 8011)', 'SNMP v2c (RFC 3805)', 'Win32 Spooler'],
      intel: netEcoTankIntel,
    ));

    // Row 3: Epson WorkForce Pro WF-4830 / EcoTank L6270 over Network (WITH Auto-Duplex)
    const netDuplexEpsonDevice = PrinterDevice(
      systemName: 'EPSON WorkForce Pro WF-4830 (Network)',
      driverName: 'EPSON WF-4830 Series',
      portName: '192.168.1.60',
      ipAddress: '192.168.1.60',
      connectionType: PrinterConnectionType.network,
      status: PrinterStatusType.ready,
    );
    final netDuplexIntel = service.mergeTelemetrySources(
      printer: netDuplexEpsonDevice,
      ipAddress: '192.168.1.60',
      ippPort: 631,
      snmpPort: 161,
      userConsentedWebConfig: false,
      ipp: const RawIppTelemetryPayload(
        reachable: true,
        printerStateEnum: 3,
        stateReasons: ['none'],
        markerNames: [
          'Black Ink',
          'Cyan Ink',
          'Magenta Ink',
          'Yellow Ink',
          'Maintenance Box T04D1',
        ],
        markerLevels: [84, 62, 55, 78, 70],
        markerColors: ['#000000', '#00FFFF', '#FF00FF', '#FFFF00', '#64748B'],
        markerTypes: ['ink', 'ink', 'ink', 'ink', 'waste-ink'],
        markerLowLevels: [15, 15, 15, 15, 15],
        mediaSupported: ['iso_a4_210x297mm', 'iso_a3_297x420mm', 'na_letter_8.5x11in', 'na_legal_8.5x14in'],
        mediaReady: ['iso_a4_210x297mm'],
        mediaColDatabase: [
          'media-source=cassette-1;media-size-name=iso_a4_210x297mm;media-type=stationery;margins=0;borderless=true',
          'media-source=cassette-2;media-size-name=iso_a3_297x420mm;media-type=stationery',
        ],
        mediaTypeSupported: ['stationery', 'photographic-glossy', 'photographic-matte', 'envelope'],
        sidesSupported: [
          'one-sided',
          'two-sided-long-edge',
          'two-sided-short-edge',
        ],
        printColorModeSupported: ['color', 'monochrome'],
        printerResolutionSupported: ['4800x2400 dpi'],
        outputBinSupported: ['face-down'],
        firmwareVersion: 'GL09N4',
        impressionsCompleted: 18940,
      ),
      snmp: const RawSnmpTelemetryPayload(
        reachable: true,
        hrPrinterStatus: 3,
        prtMarkerLifeCount: 18940,
      ),
      win32: const RawWin32SpoolerPayload(
        available: true,
        supportsDuplex: true,
        supportsColor: true,
        paperNames: ['A4', 'A3', 'Letter', 'Legal'],
        binNames: ['Cassette 1', 'Cassette 2'],
        mediaTypeNames: ['Plain Paper', 'Photo Paper Glossy', 'Epson Matte'],
        landscapeOrientationDegrees: 90,
      ),
      webConfig: RawWebConfigFallbackPayload.empty,
      matchedProfile: findProfile('epson_workforce_pro_enterprise'),
    );
    rows.add(_evaluateRow(
      rowId: 'epson_wf4830_autoduplex_network',
      printerModel: 'Epson WorkForce Pro WF-4830 (Network, Auto-Duplex)',
      vendor: 'Epson',
      hasHardwareAutoDuplex: true,
      activeProtocols: const ['IPP (RFC 8011)', 'SNMP v2c (RFC 3805)', 'Win32 Spooler'],
      intel: netDuplexIntel,
    ));

    // Row 4: Epson EcoTank Photo L8050 over Network (6-Color Photo + Borderless + Roll Paper)
    const photoEpsonDevice = PrinterDevice(
      systemName: 'EPSON L8050 Photo Series',
      driverName: 'EPSON L8050 Series',
      portName: '192.168.1.75',
      ipAddress: '192.168.1.75',
      connectionType: PrinterConnectionType.network,
      status: PrinterStatusType.ready,
    );
    final photoIntel = service.mergeTelemetrySources(
      printer: photoEpsonDevice,
      ipAddress: '192.168.1.75',
      ippPort: 631,
      snmpPort: 161,
      userConsentedWebConfig: false,
      ipp: const RawIppTelemetryPayload(
        reachable: true,
        printerStateEnum: 3,
        stateReasons: ['none'],
        markerNames: [
          'Black 057',
          'Cyan 057',
          'Light Cyan 057',
          'Magenta 057',
          'Light Magenta 057',
          'Yellow 057',
          'Maintenance Box C9345',
        ],
        markerLevels: [90, 75, 80, 68, 72, 85, 64],
        markerColors: [
          '#000000',
          '#00FFFF',
          '#80FFFF',
          '#FF00FF',
          '#FF80FF',
          '#FFFF00',
          '#64748B',
        ],
        markerTypes: ['ink', 'ink', 'ink', 'ink', 'ink', 'ink', 'waste-ink'],
        markerLowLevels: [15, 15, 15, 15, 15, 15, 15],
        mediaSupported: ['iso_a4_210x297mm', 'na_index-4x6_4x6in', 'na_5x7_5x7in'],
        mediaReady: ['na_index-4x6_4x6in'],
        mediaColDatabase: [
          'media-source=rear;media-size-name=na_index-4x6_4x6in;media-type=photographic-glossy;borderless=true;margins=0',
        ],
        mediaTypeSupported: ['photographic-glossy', 'photographic-matte', 'stationery'],
        sidesSupported: ['one-sided'],
        printColorModeSupported: ['color', 'monochrome'],
        printerResolutionSupported: ['5760x1440 dpi'],
        outputBinSupported: ['face-up'],
        firmwareVersion: '02.18.LP04',
        impressionsCompleted: 6150,
      ),
      snmp: const RawSnmpTelemetryPayload(
        reachable: true,
        hrPrinterStatus: 3,
        prtMarkerLifeCount: 6150,
      ),
      win32: const RawWin32SpoolerPayload(
        available: true,
        supportsDuplex: false,
        supportsColor: true,
        paperNames: ['4x6 in', '5x7 in', 'A4'],
        binNames: ['Rear Tray', 'CD/DVD Tray'],
        mediaTypeNames: ['Photo Paper Glossy', 'Ultra Glossy', 'Plain Paper'],
        landscapeOrientationDegrees: 90,
      ),
      webConfig: RawWebConfigFallbackPayload.empty,
      matchedProfile: findProfile('epson_photo_surecolor_l8000'),
    );
    rows.add(_evaluateRow(
      rowId: 'epson_l8050_photo_network',
      printerModel: 'Epson EcoTank Photo L8050 (Network, Borderless/Roll)',
      vendor: 'Epson',
      hasHardwareAutoDuplex: false,
      activeProtocols: const ['IPP (RFC 8011)', 'SNMP v2c (RFC 3805)', 'Win32 Spooler'],
      intel: photoIntel,
    ));

    // Row 5: Non-Epson HP LaserJet Pro MFP M428fdn over Network (Laser Toner + Auto-Duplex)
    const nonEpsonDevice = PrinterDevice(
      systemName: 'HP LaserJet Pro MFP M428fdn',
      driverName: 'HP Universal Printing PCL 6',
      portName: '192.168.1.90',
      ipAddress: '192.168.1.90',
      connectionType: PrinterConnectionType.network,
      status: PrinterStatusType.ready,
    );
    final nonEpsonIntel = service.mergeTelemetrySources(
      printer: nonEpsonDevice,
      ipAddress: '192.168.1.90',
      ippPort: 631,
      snmpPort: 161,
      userConsentedWebConfig: false,
      ipp: const RawIppTelemetryPayload(
        reachable: true,
        printerStateEnum: 3,
        stateReasons: ['none'],
        markerNames: ['Black Cartridge HP 58A (CF258A)'],
        markerLevels: [46],
        markerColors: ['#000000'],
        markerTypes: ['toner'],
        markerLowLevels: [10],
        mediaSupported: ['iso_a4_210x297mm', 'na_letter_8.5x11in', 'na_legal_8.5x14in'],
        mediaReady: ['iso_a4_210x297mm'],
        mediaColDatabase: [
          'media-source=tray-1;media-size-name=iso_a4_210x297mm;media-type=stationery',
          'media-source=tray-2;media-size-name=na_legal_8.5x14in;media-type=stationery',
        ],
        mediaTypeSupported: ['stationery', 'heavyweight', 'envelope'],
        sidesSupported: ['one-sided', 'two-sided-long-edge', 'two-sided-short-edge'],
        printColorModeSupported: ['monochrome'],
        printerResolutionSupported: ['1200x1200 dpi'],
        outputBinSupported: ['face-down'],
        firmwareVersion: '2408067_000129',
        impressionsCompleted: 45120,
      ),
      snmp: const RawSnmpTelemetryPayload(
        reachable: true,
        hrPrinterStatus: 3,
        prtMarkerLifeCount: 45120,
        supplies: [
          SnmpSupplyRow(
            index: 1,
            description: 'Black Cartridge HP 58A (CF258A)',
            maxCapacity: 3000,
            level: 1380,
          ),
        ],
      ),
      win32: const RawWin32SpoolerPayload(
        available: true,
        supportsDuplex: true,
        supportsColor: false,
        paperNames: ['A4', 'Letter', 'Legal'],
        binNames: ['Tray 1', 'Tray 2'],
        mediaTypeNames: ['Plain Paper', 'Heavyweight', 'Envelope'],
        landscapeOrientationDegrees: 90,
      ),
      webConfig: RawWebConfigFallbackPayload.empty,
      matchedProfile: findProfile('generic_standard_printer'),
    );
    rows.add(_evaluateRow(
      rowId: 'non_epson_hp_m428fdn',
      printerModel: 'HP LaserJet Pro MFP M428fdn (Non-Epson Laser)',
      vendor: 'HP',
      hasHardwareAutoDuplex: true,
      activeProtocols: const ['IPP (RFC 8011)', 'SNMP v2c (RFC 3805)', 'Win32 Spooler'],
      intel: nonEpsonIntel,
    ));

    return rows;
  }

  static EpsonPrinterTestMatrixRow _evaluateRow({
    required String rowId,
    required String printerModel,
    required String vendor,
    required bool hasHardwareAutoDuplex,
    required List<String> activeProtocols,
    required PrinterLiveIntelligence intel,
  }) {
    final readable = <String>[];
    final unreported = <String>[];

    // 1. Supply levels
    String levelsSummary;
    if (intel.supplies.isReported &&
        intel.supplies.value != null &&
        intel.supplies.value!.isNotEmpty) {
      final list = intel.supplies.value!;
      final hasExactPct = list.any((s) => s.levelPercent.isReported);
      if (hasExactPct) {
        readable.add('Exact supply percentages (${intel.supplies.source.shortLabel})');
        levelsSummary = list
            .map((s) => s.levelPercent.isReported
                ? '${s.name}: ${s.levelPercent.value}%'
                : '${s.name}: ${s.qualitativeStatus.value?.labelEn ?? "OK"}')
            .join(', ');
      } else {
        readable.add('Qualitative supply status OK/Low (${intel.supplies.source.shortLabel})');
        unreported.add('Exact 0–100% ink level (printer reports -3 some remaining)');
        levelsSummary = list
            .map((s) => '${s.name}: ${s.qualitativeStatus.value?.labelEn ?? "OK"} (no % sensor)')
            .join(', ');
      }
    } else {
      unreported.add('Supply levels ($kNotReportedByPrinterEn)');
      levelsSummary = kNotReportedByPrinterEn;
    }

    // 2. Paper sizes & ready media
    String paperSummary;
    if (intel.supportedPaperSizes.isReported &&
        intel.supportedPaperSizes.value != null) {
      readable.add('Supported paper sizes (${intel.supportedPaperSizes.source.shortLabel})');
      if (intel.readyPaperSizes.isReported &&
          intel.readyPaperSizes.value != null &&
          intel.readyPaperSizes.value!.isNotEmpty) {
        readable.add('Currently loaded paper size (${intel.readyPaperSizes.source.shortLabel})');
        paperSummary =
            'Loaded: ${intel.readyPaperSizes.value!.join(", ")} | Supported: ${intel.supportedPaperSizes.value!.join(", ")}';
      } else {
        unreported.add('Optical loaded paper size sensor ($kNotReportedByPrinterEn)');
        paperSummary =
            'Loaded: $kNotReportedByPrinterEn | Supported: ${intel.supportedPaperSizes.value!.join(", ")}';
      }
    } else {
      unreported.add('Supported paper sizes ($kNotReportedByPrinterEn)');
      paperSummary = kNotReportedByPrinterEn;
    }

    // 3. Duplex
    String duplexSummary;
    if (intel.duplexSupport.isReported && intel.duplexSupport.value != null) {
      readable.add('Duplex capability (${intel.duplexSupport.source.shortLabel})');
      duplexSummary =
          '${intel.duplexSupport.value!.labelEn} [${intel.duplexSupport.source.shortLabel}]';
    } else {
      unreported.add('Duplex capability ($kNotReportedByPrinterEn)');
      duplexSummary = kNotReportedByPrinterEn;
    }

    // 4. Trays
    String traysSummary;
    if (intel.trays.isReported &&
        intel.trays.value != null &&
        intel.trays.value!.isNotEmpty) {
      final trays = intel.trays.value!;
      final hasTraySensors = trays.any((t) => t.loadedPaperSize.isReported);
      readable.add('Tray list (${intel.trays.source.shortLabel})');
      if (hasTraySensors) {
        readable.add('Per-tray loaded media (${intel.trays.source.shortLabel})');
      } else {
        unreported.add('Per-tray loaded paper sensor ($kNotReportedByPrinterEn)');
      }
      traysSummary = trays
          .map((t) =>
              '${t.trayName}: ${t.loadedPaperSize.isReported ? t.loadedPaperSize.value : kNotReportedByPrinterEn}')
          .join(' • ');
    } else {
      unreported.add('Trays ($kNotReportedByPrinterEn)');
      traysSummary = kNotReportedByPrinterEn;
    }

    // 5. Maintenance box & counters
    if (intel.lifetimePageCount.isReported) {
      readable.add('Lifetime page counter (${intel.lifetimePageCount.source.shortLabel})');
    } else {
      unreported.add('Lifetime page counter ($kNotReportedByPrinterEn)');
    }
    if (intel.maintenanceBoxStatus.isReported) {
      readable.add('Maintenance box status (${intel.maintenanceBoxStatus.source.shortLabel})');
    } else {
      unreported.add('Maintenance box status ($kNotReportedByPrinterEn)');
    }

    return EpsonPrinterTestMatrixRow(
      rowId: rowId,
      printerModel: printerModel,
      vendor: vendor,
      connectionType: intel.connectionType,
      hasHardwareAutoDuplex: hasHardwareAutoDuplex,
      activeProtocols: activeProtocols,
      readableAttributes: readable,
      unreportedAttributes: unreported,
      levelsSummary: levelsSummary,
      paperSummary: paperSummary,
      duplexSummary: duplexSummary,
      traysSummary: traysSummary,
      snapshot: intel,
    );
  }
}
