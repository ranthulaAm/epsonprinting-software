import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/services/printer/epson_robust_support_service.dart';
import 'package:print_helper/services/printer/models/printer_intelligence_models.dart';
import 'package:print_helper/services/printer/models/printer_models.dart';
import 'package:print_helper/services/printer/printer_intelligence_service.dart';

void main() {
  setUp(() {
    OfflinePrinterNetworkPolicyGuard.resetAuditCounters();
  });

  group('1. Sleep/Wake, Network IP Change Rediscovery & SNMP/IPP Auth', () {
    test('wakes sleeping Epson printer on second probe at same IP', () async {
      const config = PrinterNetworkAuthAndIdentityConfig(
        printerId: 'EPSON L3250 Series',
        wakeOnDeepSleep: true,
      );

      final result =
          await EpsonNetworkRediscoveryEngine.ensureAwakeOrRediscover(
        currentIp: '192.168.1.45',
        identityConfig: config,
        lanCandidates: const [
          LanPrinterIdentityCandidate(
            ipAddress: '192.168.1.45',
            sleepingInitially: true,
          ),
        ],
      );

      expect(result.reachable, isTrue);
      expect(result.wokeFromSleep, isTrue);
      expect(result.ipChanged, isFalse);
      expect(result.resolvedIp, '192.168.1.45');
      expect(
        result.matchedBy,
        PrinterRediscoveryMatchedBy.wokeFromSleepAtSameIp,
      );
      expect(result.wakeAttempts, 2);
    });

    test(
      'rediscovers printer after DHCP IP change by Hostname, Serial Number, and MAC Address',
      () async {
        // A. Rediscover by Hostname
        final byHostname =
            await EpsonNetworkRediscoveryEngine.ensureAwakeOrRediscover(
          currentIp: '192.168.1.45',
          identityConfig: const PrinterNetworkAuthAndIdentityConfig(
            printerId: 'Epson_1',
            knownHostname: 'EPSON1A2B3C.local',
          ),
          lanCandidates: const [
            LanPrinterIdentityCandidate(
              ipAddress: '192.168.1.92',
              hostname: 'EPSON1A2B3C.local',
            ),
          ],
          customProbeFn: (host, attempt) async => host == '192.168.1.92',
        );
        expect(byHostname.reachable, isTrue);
        expect(byHostname.ipChanged, isTrue);
        expect(byHostname.previousIp, '192.168.1.45');
        expect(byHostname.resolvedIp, '192.168.1.92');
        expect(
          byHostname.matchedBy,
          PrinterRediscoveryMatchedBy.hostnameResolution,
        );

        // B. Rediscover by Serial Number
        final bySerial =
            await EpsonNetworkRediscoveryEngine.ensureAwakeOrRediscover(
          currentIp: '192.168.1.45',
          identityConfig: const PrinterNetworkAuthAndIdentityConfig(
            printerId: 'Epson_2',
            knownSerialNumber: 'X8F9988776',
          ),
          lanCandidates: const [
            LanPrinterIdentityCandidate(
              ipAddress: '192.168.1.108',
              serialNumber: 'X8F9988776',
            ),
          ],
          customProbeFn: (host, attempt) async => host == '192.168.1.108',
        );
        expect(bySerial.reachable, isTrue);
        expect(bySerial.ipChanged, isTrue);
        expect(bySerial.resolvedIp, '192.168.1.108');
        expect(
          bySerial.matchedBy,
          PrinterRediscoveryMatchedBy.serialNumberMatch,
        );

        // C. Rediscover by MAC Address
        final byMac =
            await EpsonNetworkRediscoveryEngine.ensureAwakeOrRediscover(
          currentIp: '192.168.1.45',
          identityConfig: const PrinterNetworkAuthAndIdentityConfig(
            printerId: 'Epson_3',
            knownMacAddress: 'A4:EE:57:12:34:56',
          ),
          lanCandidates: const [
            LanPrinterIdentityCandidate(
              ipAddress: '192.168.1.144',
              macAddress: 'a4-ee-57-12-34-56',
            ),
          ],
          customProbeFn: (host, attempt) async => host == '192.168.1.144',
        );
        expect(byMac.reachable, isTrue);
        expect(byMac.ipChanged, isTrue);
        expect(byMac.resolvedIp, '192.168.1.144');
        expect(byMac.matchedBy, PrinterRediscoveryMatchedBy.macAddressMatch);
      },
    );

    test(
      'supports per-printer SNMP community string and IPP Basic / Bearer authentication headers',
      () {
        const basicAuth = PrinterNetworkAuthAndIdentityConfig(
          printerId: 'EPSON WF-4830',
          snmpCommunity: 'shop_private_ro',
          snmpVersion: SnmpProtocolVersion.v2c,
          ippAuthScheme: IppAuthenticationScheme.basic,
          ippUsername: 'admin',
          ippPasswordOrToken: 'epson123',
        );
        expect(basicAuth.snmpCommunity, 'shop_private_ro');
        expect(
          basicAuth.buildIppAuthorizationHeader(),
          'Basic ${base64Encode(utf8.encode("admin:epson123"))}',
        );

        const bearerAuth = PrinterNetworkAuthAndIdentityConfig(
          printerId: 'EPSON WF-4830',
          ippAuthScheme: IppAuthenticationScheme.bearer,
          ippPasswordOrToken: 'tok_live_987',
        );
        expect(bearerAuth.buildIppAuthorizationHeader(), 'Bearer tok_live_987');
      },
    );
  });

  group('2. Common Epson Conditions in Plain English and Sinhala', () {
    test(
      'detects all 7 common Epson conditions with both English and Sinhala explanations',
      () {
        const printer = PrinterDevice(
          systemName: 'EPSON L8050 Series',
          driverName: 'EPSON L8050 Series',
          portName: '192.168.1.75',
          connectionType: PrinterConnectionType.network,
          status: PrinterStatusType.error,
        );

        final conditions = EpsonConditionDetector.detectConditions(
          ipp: const RawIppTelemetryPayload(
            reachable: true,
            printerStateEnum: 5,
            stateReasons: [
              'cartridge-not-recognized-cyan',
              'marker-waste-almost-full',
              'printhead-cleaning-in-progress',
              'cover-open-error',
              'input-tray-empty-rear',
            ],
          ),
          snmp: const RawSnmpTelemetryPayload(
            reachable: true,
            inputTrays: [
              SnmpInputTrayRow(
                index: 1,
                name: 'Cassette 1 (Front Tray)',
                mediaName: 'A4',
                mediaType: 'stationery',
                maxCapacity: 250,
                currentLevel: 0,
              ),
            ],
          ),
          win32: RawWin32SpoolerPayload.empty,
          printer: printer,
          requestedBorderless: true,
          requestedRollPaper: true,
        );

        final kinds = conditions.map((c) => c.kind).toSet();
        expect(
          kinds,
          containsAll(<EpsonConditionKind>[
            EpsonConditionKind.inkCartridgeNotRecognized,
            EpsonConditionKind.maintenanceBoxNearEndOfLife,
            EpsonConditionKind.headCleaningInProgress,
            EpsonConditionKind.borderlessNeedsSpecialMargin,
            EpsonConditionKind.rollPaperCutSettings,
            EpsonConditionKind.coverOpen,
            EpsonConditionKind.paperOutInSpecificTray,
          ]),
        );

        // Verify bilingual strings (English + Sinhala) on every detected condition
        for (final c in conditions) {
          expect(c.titleEn.trim(), isNotEmpty);
          expect(c.titleSi.trim(), isNotEmpty);
          expect(c.explanationEn.trim(), isNotEmpty);
          expect(c.explanationSi.trim(), isNotEmpty);
        }

        // Verify specific tray names ('Rear Tray' and 'Cassette 1 (Front Tray)')
        final paperOutTrays = conditions
            .where((c) => c.kind == EpsonConditionKind.paperOutInSpecificTray)
            .map((c) => c.affectedTrayOrSupply)
            .toList();
        expect(paperOutTrays, contains('Rear Tray'));
        expect(paperOutTrays, contains('Cassette 1 (Front Tray)'));
      },
    );
  });

  group('3. Printer Limits & Maintenance Safety Guardrails', () {
    test(
      'blocks unverified raw control commands and requires explicit user request + confirmation for head cleaning',
      () {
        // 1. Block unverified raw ESC/P2 REMOTE1 packet
        final rawEscP2 = Uint8List.fromList(
          '\x1B(R\x08\x00\x00REMOTE1NP'.codeUnits,
        );
        expect(
          () => EpsonSafeMaintenanceGuard.assertNoUnverifiedRawControlCommand(
            rawEscP2,
          ),
          throwsA(isA<MaintenanceCommandSafetyException>()),
        );

        // 2. Block automatic / unconfirmed head cleaning
        expect(
          () => EpsonSafeMaintenanceGuard.validateMaintenanceRequest(
            command: SafeMaintenanceCommandType.standardHeadCleaning,
            userExplicitlyRequested: false,
            userConfirmedDialog: false,
            intelligence: null,
          ),
          throwsA(isA<MaintenanceCommandSafetyException>()),
        );

        // 3. Allow when user explicitly requests AND confirms
        final confirmed = EpsonSafeMaintenanceGuard.validateMaintenanceRequest(
          command: SafeMaintenanceCommandType.standardHeadCleaning,
          userExplicitlyRequested: true,
          userConfirmedDialog: true,
          intelligence: null,
        );
        expect(confirmed.allowed, isTrue);
      },
    );
  });

  group('4. Official Epson Windows Spooler DEVMODE Mapping & Verification', () {
    test(
      'maps all Print Helper job options to DEVMODEW and verifies each option changes the output bytes',
      () {
        final report = EpsonSpoolerDevModeMapper.mapAndVerifyOptions(
          printerDriverName: 'EPSON L8050 Series',
          options: const EpsonSpoolerJobOptions(
            paperSizeName: 'A4',
            isLandscape: true,
            copies: 4,
            collate: true,
            isColor: true,
            duplexModeCode: 2,
            qualityMode: EpsonDriverQualityMode.ultraPhoto,
            mediaTypeName: 'Photo Paper Glossy',
            paperSourceTrayName: 'Rear Tray',
            borderless: true,
            borderlessExpansionLevel: 3,
            rollPaperCutMode: EpsonRollPaperCutMode.autoDoubleCut,
          ),
        );

        expect(report.usesOfficialSpoolerDriver, isTrue);
        expect(report.fieldVerifications.length, 12);
        expect(report.allMappedOptionsVerified, isTrue);

        for (final entry in report.fieldVerifications) {
          expect(
            entry.verifiedChangedOutput,
            isTrue,
            reason:
                '${entry.optionName} (${entry.devModeFieldName}) must mutate DEVMODE output from ${entry.beforeRawValue} to ${entry.afterRawValue}',
          );
        }
      },
    );
  });

  group('5. Copy Printer Diagnostics & 6. Multi-Printer Test Matrix', () {
    test(
      'builds 5-row Epson & Non-Epson Test Matrix and generates full raw IPP/SNMP/DEVMODE diagnostic report',
      () async {
        final service = PrinterIntelligenceService();
        final matrix =
            await EpsonPrinterTestMatrixBuilder.buildStandardTestMatrix(service);

        expect(matrix.length, 5);

        // Row 1: Epson EcoTank L3250 over USB (no auto-duplex)
        final usbRow =
            matrix.firstWhere((r) => r.rowId == 'epson_l3250_usb');
        expect(usbRow.connectionType, PrinterConnectionType.usb);
        expect(usbRow.hasHardwareAutoDuplex, isFalse);
        expect(usbRow.levelsSummary, kNotReportedByPrinterEn);
        expect(usbRow.duplexSummary, contains('Manual 2-Sided Only'));

        // Row 2: Epson EcoTank L3250 over Network (no auto-duplex, IPP/SNMP)
        final netNoDuplexRow =
            matrix.firstWhere((r) => r.rowId == 'epson_l3250_network');
        expect(netNoDuplexRow.connectionType, PrinterConnectionType.network);
        expect(netNoDuplexRow.hasHardwareAutoDuplex, isFalse);
        expect(netNoDuplexRow.levelsSummary, contains('OK (no % sensor)'));

        // Row 3: Epson WorkForce Pro WF-4830 over Network (with Auto-Duplex)
        final netAutoDuplexRow = matrix.firstWhere(
          (r) => r.rowId == 'epson_wf4830_autoduplex_network',
        );
        expect(netAutoDuplexRow.hasHardwareAutoDuplex, isTrue);
        expect(netAutoDuplexRow.levelsSummary, contains('Black Ink: 84%'));
        expect(
          netAutoDuplexRow.levelsSummary,
          contains('Maintenance Box T04D1: 70%'),
        );
        expect(netAutoDuplexRow.duplexSummary, contains('Automatic 2-Sided'));
        expect(netAutoDuplexRow.traysSummary, contains('Cassette 1: A4'));

        // Row 5: Non-Epson HP LaserJet Pro MFP M428fdn
        final nonEpsonRow =
            matrix.firstWhere((r) => r.rowId == 'non_epson_hp_m428fdn');
        expect(nonEpsonRow.vendor, 'HP');
        expect(nonEpsonRow.levelsSummary, contains('46%'));

        // Generate "Copy printer diagnostics" report for WF-4830
        final diagText = PrinterDiagnosticsReportBuilder.buildDiagnosticsText(
          intelligence: netAutoDuplexRow.snapshot,
          rawIpp: const RawIppTelemetryPayload(
            reachable: true,
            printerStateEnum: 3,
            markerNames: ['Black Ink'],
            markerLevels: [84],
          ),
          rawSnmp: const RawSnmpTelemetryPayload(
            reachable: true,
            hrPrinterStatus: 3,
            prtMarkerLifeCount: 18940,
          ),
          devModeVerification: EpsonSpoolerDevModeMapper.mapAndVerifyOptions(
            printerDriverName: 'EPSON WF-4830 Series',
            options: const EpsonSpoolerJobOptions(),
          ),
        );

        expect(
          diagText,
          contains('=== PRINT HELPER — PRINTER DIAGNOSTICS REPORT ==='),
        );
        expect(diagText, contains('"rawIppData"'));
        expect(diagText, contains('"rawSnmpData"'));
        expect(diagText, contains('"spoolerDevModeVerification"'));
        expect(diagText, contains('"internetCallsPermitted": false'));

        service.dispose();
      },
    );
  });

  group('7. Strict Offline Mode Check (Never call out to the internet)', () {
    test(
      'permits loopback and private LAN targets while blocking all public internet IPs and external domains',
      () {
        // Allowed local/LAN targets
        expect(
          OfflinePrinterNetworkPolicyGuard.isStrictlyLocalLanTarget('127.0.0.1'),
          isTrue,
        );
        expect(
          OfflinePrinterNetworkPolicyGuard.isStrictlyLocalLanTarget(
            '192.168.1.50',
          ),
          isTrue,
        );
        expect(
          OfflinePrinterNetworkPolicyGuard.isStrictlyLocalLanTarget(
            '10.24.0.105',
          ),
          isTrue,
        );
        expect(
          OfflinePrinterNetworkPolicyGuard.isStrictlyLocalLanTarget(
            '172.20.10.4',
          ),
          isTrue,
        );
        expect(
          OfflinePrinterNetworkPolicyGuard.isStrictlyLocalLanTarget(
            '169.254.12.34',
          ),
          isTrue,
        );
        expect(
          OfflinePrinterNetworkPolicyGuard.isStrictlyLocalLanTarget(
            'EPSON1A2B3C.local',
          ),
          isTrue,
        );

        // Forbidden public internet IPs and domains
        for (final externalTarget in <String>[
          '8.8.8.8',
          '1.1.1.1',
          '93.184.216.34',
          '172.32.0.1',
          'https://epson.com/firmware',
          'printer-cloud.googleapis.com',
        ]) {
          expect(
            OfflinePrinterNetworkPolicyGuard.isStrictlyLocalLanTarget(
              externalTarget,
            ),
            isFalse,
            reason: 'Must reject external internet target: $externalTarget',
          );
          expect(
            () => OfflinePrinterNetworkPolicyGuard.assertStrictlyLocalLanTarget(
              externalTarget,
            ),
            throwsA(isA<OfflinePrinterPolicyViolationException>()),
          );
        }

        expect(
          OfflinePrinterNetworkPolicyGuard.blockedInternetCallsCount,
          6,
        );
        expect(
          OfflinePrinterNetworkPolicyGuard.blockedTargetsLog.length,
          6,
        );
      },
    );
  });
}
