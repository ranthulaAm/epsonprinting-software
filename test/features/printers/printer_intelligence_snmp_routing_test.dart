import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:antigravity_pdf_gear/features/printers/data/printer_intelligence_snmp_routing_service.dart';
import 'package:antigravity_pdf_gear/features/printers/domain/printer_routing_engine_models.dart';
import 'package:antigravity_pdf_gear/features/printers/domain/snmp_printer_mib_models.dart';

/// Mock SNMP/IPP server simulating live network responses across multiple test profiles.
class MockSnmpIppServer {
  final Map<String, dynamic> _responses = {};
  int networkDelayMs = 0;
  bool isDeviceOnline = true;

  void configureNormalEpsonL8050() {
    isDeviceOnline = true;
    networkDelayMs = 20;
    _responses['1.3.6.1.2.1.25.3.2.1.3.1'] = 'EPSON L8050 Series';
    _responses['1.3.6.1.2.1.43.5.1.1.17.1'] = 'X9KP019482';
    _responses['1.3.6.1.2.1.43.10.2.1.4.1.1'] = 4520; // 4,520 pages
    // Supplies table
    _responses['supplies'] = [
      {'desc': 'Black Ink Tank (057)', 'level': 65, 'max': 100, 'estimate': true},
      {'desc': 'Cyan Ink Tank (057)', 'level': 80, 'max': 100, 'estimate': true},
      {'desc': 'Magenta Ink Tank (057)', 'level': 75, 'max': 100, 'estimate': true},
      {'desc': 'Yellow Ink Tank (057)', 'level': 90, 'max': 100, 'estimate': true},
      {'desc': 'Light Cyan Ink Tank (057)', 'level': 50, 'max': 100, 'estimate': true},
      {'desc': 'Light Magenta Ink Tank (057)', 'level': 45, 'max': 100, 'estimate': true},
      {'desc': 'Maintenance Box (C9345)', 'level': 22, 'max': 100, 'estimate': false},
    ];
    _responses['alerts'] = [];
  }

  void configureSpecialNegativeValuesPrinter() {
    isDeviceOnline = true;
    networkDelayMs = 15;
    // Uses RFC 3805 negative codes
    _responses['supplies'] = [
      {'desc': 'Toner Cartridge Black', 'level': -1, 'max': 100, 'estimate': false}, // Other / Present
      {'desc': 'Toner Cartridge Cyan', 'level': -3, 'max': 100, 'estimate': false},  // Some remaining
      {'desc': 'Toner Cartridge Magenta', 'level': -2, 'max': 100, 'estimate': false}, // Unknown
      {'desc': 'Waste Toner Box', 'level': 10, 'max': -2, 'estimate': false}, // Capacity -2 (Unknown)
    ];
    _responses['alerts'] = [
      {'code': 8, 'desc': 'Paper Jam in Unit 1'},
    ];
  }

  void configureTruncatedMissingMibPrinter() {
    isDeviceOnline = true;
    networkDelayMs = 10;
    // Empty supplies and alerts
    _responses['supplies'] = [];
    _responses['alerts'] = [];
  }

  void configureSlowTimeoutPrinter() {
    isDeviceOnline = true;
    networkDelayMs = 3500; // Exceeds 1500ms timeout!
  }

  void configureOfflinePrinter() {
    isDeviceOnline = false;
  }

  Future<Map<String, dynamic>> queryTelemetry(String host, {int timeoutMs = 1500}) async {
    if (!isDeviceOnline) {
      throw TimeoutException('Host $host is unreachable (Socket Offline)');
    }
    if (networkDelayMs > timeoutMs) {
      await Future.delayed(Duration(milliseconds: timeoutMs));
      throw TimeoutException('SNMP request to $host timed out after ${timeoutMs}ms');
    }
    await Future.delayed(Duration(milliseconds: networkDelayMs));
    return Map<String, dynamic>.from(_responses);
  }
}

void main() {
  group('Printer Intelligence SNMP & Routing Test Suite', () {
    late MockSnmpIppServer mockServer;

    setUp(() {
      mockServer = MockSnmpIppServer();
    });

    // ------------------------------------------------------------------------
    // 1. Normal SNMP Supplies & Table Walking
    // ------------------------------------------------------------------------
    test('1. Parses normal SNMP supply levels and flags estimates', () {
      mockServer.configureNormalEpsonL8050();
      final rows = (mockServer._responses['supplies'] as List);

      final black = PrinterIntelligenceSnmpRoutingService.parseSnmpSupplyRow(
        index: 1,
        description: rows[0]['desc'],
        rawLevel: rows[0]['level'],
        rawMaxCapacity: rows[0]['max'],
        isKnownEstimateModel: rows[0]['estimate'],
      );

      expect(black.statusType, equals(SnmpSupplyStatusType.percentage));
      expect(black.calculatedPercentage, equals(65.0));
      expect(black.isEstimate, isTrue);
      expect(black.getDisplayString(isSinhala: false), equals('65% (estimate)'));
      expect(black.getDisplayString(isSinhala: true), equals('65% (ඇස්තමේන්තුව)'));

      // Check Maintenance Box row
      final maintBox = PrinterIntelligenceSnmpRoutingService.parseSnmpSupplyRow(
        index: 7,
        description: rows[6]['desc'],
        rawLevel: rows[6]['level'],
        rawMaxCapacity: rows[6]['max'],
        isKnownEstimateModel: rows[6]['estimate'],
      );
      expect(maintBox.isMaintenanceBox, isTrue);
      expect(maintBox.calculatedPercentage, equals(22.0));
      expect(maintBox.isEstimate, isFalse);
    });

    // ------------------------------------------------------------------------
    // 2. RFC 3805 Negative Special Values Handling
    // ------------------------------------------------------------------------
    test('2. Handles negative special values (-1, -2, -3, capacity -2) without calculating negative percentages', () {
      mockServer.configureSpecialNegativeValuesPrinter();
      final rows = (mockServer._responses['supplies'] as List);

      // Level -1: "Other" -> Present / OK
      final blackOther = PrinterIntelligenceSnmpRoutingService.parseSnmpSupplyRow(
        index: 1,
        description: rows[0]['desc'],
        rawLevel: rows[0]['level'],
        rawMaxCapacity: rows[0]['max'],
      );
      expect(blackOther.statusType, equals(SnmpSupplyStatusType.presentOk));
      expect(blackOther.calculatedPercentage, isNull);
      expect(blackOther.getDisplayString(isSinhala: false), equals('OK'));
      expect(blackOther.getDisplayString(isSinhala: true), equals('ප්‍රමාණවත් (OK)'));

      // Level -3: "Some remaining" -> Some Remaining (OK)
      final cyanSome = PrinterIntelligenceSnmpRoutingService.parseSnmpSupplyRow(
        index: 2,
        description: rows[1]['desc'],
        rawLevel: rows[1]['level'],
        rawMaxCapacity: rows[1]['max'],
      );
      expect(cyanSome.statusType, equals(SnmpSupplyStatusType.someRemaining));
      expect(cyanSome.calculatedPercentage, isNull);
      expect(cyanSome.getDisplayString(isSinhala: false), equals('Some Remaining (OK)'));

      // Level -2: "Unknown" -> Not reported
      final magUnknown = PrinterIntelligenceSnmpRoutingService.parseSnmpSupplyRow(
        index: 3,
        description: rows[2]['desc'],
        rawLevel: rows[2]['level'],
        rawMaxCapacity: rows[2]['max'],
      );
      expect(magUnknown.statusType, equals(SnmpSupplyStatusType.notReported));
      expect(magUnknown.calculatedPercentage, isNull);
      expect(magUnknown.getDisplayString(isSinhala: false), equals('Not reported'));
      expect(magUnknown.getDisplayString(isSinhala: true), equals('වාර්තා නොවේ'));

      // Capacity -2: "Unknown Capacity" with positive level
      final wasteBox = PrinterIntelligenceSnmpRoutingService.parseSnmpSupplyRow(
        index: 4,
        description: rows[3]['desc'],
        rawLevel: rows[3]['level'],
        rawMaxCapacity: rows[3]['max'],
      );
      expect(wasteBox.statusType, equals(SnmpSupplyStatusType.someRemaining));
      expect(wasteBox.calculatedPercentage, isNull); // Never compute division by negative!
    });

    // ------------------------------------------------------------------------
    // 3. Hardware Alerts in Plain Language
    // ------------------------------------------------------------------------
    test('3. Translates RFC 3805 prtAlertTable entries to plain English and Sinhala', () {
      final alertJam = PrinterHardwareAlert.fromPrtAlert(code: 8, rawDesc: 'Paper Jam in Tray 1');
      expect(alertJam.isCritical, isTrue);
      expect(alertJam.messageEn, contains('Paper Jam: Clear path and press Resume'));
      expect(alertJam.messageSi, contains('කඩදාසිය හිරවී ඇත'));

      final alertCover = PrinterHardwareAlert.fromPrtAlert(code: 5, rawDesc: 'Scanner Door Open');
      expect(alertCover.messageEn, contains('Cover Open: Close printer front/scanner cover'));
      expect(alertCover.messageSi, contains('පියන ඇරී ඇත'));
    });

    // ------------------------------------------------------------------------
    // 4. Timeouts & Offline Failure Handling
    // ------------------------------------------------------------------------
    test('4. Handles slow timeout and offline printers safely without freezing', () async {
      mockServer.configureSlowTimeoutPrinter();
      expect(
        () => mockServer.queryTelemetry('192.168.1.150', timeoutMs: 50),
        throwsA(isA<TimeoutException>()),
      );

      mockServer.configureOfflinePrinter();
      expect(
        () => mockServer.queryTelemetry('192.168.1.151', timeoutMs: 50),
        throwsA(isA<TimeoutException>()),
      );
    });

    // ------------------------------------------------------------------------
    // 5. Specialty Job Routing Rules
    // ------------------------------------------------------------------------
    test('5. Routes specialty jobs exclusively to hardware-capable printers', () {
      final fleet = [
        const DashboardPrinterCardData(
          id: 'p1',
          name: 'Epson L3250 Document',
          modelName: 'L3250',
          interfaceType: PrinterInterfaceType.wifi,
          state: FleetPrinterState.ready,
          specialtyBadges: ['Duplex'],
        ),
        const DashboardPrinterCardData(
          id: 'p2',
          name: 'Epson L8050 Photo & Badge',
          modelName: 'L8050',
          interfaceType: PrinterInterfaceType.wifi,
          state: FleetPrinterState.ready,
          specialtyBadges: ['CD/DVD', 'ID Card', 'Borderless'],
        ),
        const DashboardPrinterCardData(
          id: 'p3',
          name: 'Epson SC-F100 Sublimation',
          modelName: 'SC-F100',
          interfaceType: PrinterInterfaceType.usb,
          state: FleetPrinterState.ready,
          specialtyBadges: ['Sublimation'],
        ),
      ];

      // CR80 PVC ID Card job -> MUST route to p2 (L8050)
      final pvcJob = const JobRoutingRequest(
        jobId: 'j-01',
        documentTitle: 'Staff ID Badges',
        classification: PrintJobClassification.pvcIdCard,
        isColor: true,
        pageCount: 2,
      );
      final rPvc = PrinterIntelligenceSnmpRoutingService.evaluateJobRouting(job: pvcJob, fleet: fleet);
      expect(rPvc.selectedPrinterId, equals('p2'));
      expect(rPvc.rationaleSentenceEn, contains('supports CR80 PVC ID Card Tray'));

      // Dye-Sublimation Mug job -> MUST route to p3 (SC-F100)
      final subJob = const JobRoutingRequest(
        jobId: 'j-02',
        documentTitle: '11oz Mug Wrap',
        classification: PrintJobClassification.dyeSublimationTransfer,
        isColor: true,
        pageCount: 1,
      );
      final rSub = PrinterIntelligenceSnmpRoutingService.evaluateJobRouting(job: subJob, fleet: fleet);
      expect(rSub.selectedPrinterId, equals('p3'));
      expect(rSub.rationaleSentenceEn, contains('supports Dye-Sublimation Transfer & Auto-Mirror'));
    });

    // ------------------------------------------------------------------------
    // 6. Failover & Confirmation When Preferred Printer Is Offline / Low
    // ------------------------------------------------------------------------
    test('6. Proposes failover with confirmation when preferred printer is offline', () {
      final fleet = [
        const DashboardPrinterCardData(
          id: 'p1',
          name: 'Epson L8050 Main',
          modelName: 'L8050',
          interfaceType: PrinterInterfaceType.wifi,
          state: FleetPrinterState.offline, // Target is OFFLINE
          specialtyBadges: ['CD/DVD', 'ID Card'],
        ),
        const DashboardPrinterCardData(
          id: 'p2',
          name: 'Epson L18050 Backup',
          modelName: 'L18050',
          interfaceType: PrinterInterfaceType.wifi,
          state: FleetPrinterState.ready, // Backup is READY
          specialtyBadges: ['CD/DVD', 'ID Card'],
        ),
      ];

      final cdJob = const JobRoutingRequest(
        jobId: 'j-03',
        documentTitle: 'Wedding Disc Label',
        classification: PrintJobClassification.cdDvdDisc,
        isColor: true,
        pageCount: 1,
        preferredPrinterId: 'p1',
      );

      final result = PrinterIntelligenceSnmpRoutingService.evaluateJobRouting(job: cdJob, fleet: fleet);

      expect(result.wasReroutedFromPreferred, isTrue);
      expect(result.selectedPrinterId, equals('p2'));
      expect(result.requiresOperatorConfirmation, isTrue);
      expect(result.rationaleSentenceEn, contains('because preferred printer Epson L8050 Main is offline'));
      expect(result.rationaleSentenceSi, contains('මූලික ප්‍රින්ටරය (Epson L8050 Main) විසන්ධි වී ඇත බැවින්'));
    });

    // ------------------------------------------------------------------------
    // 7. Subnet Scan Permission Guardrail
    // ------------------------------------------------------------------------
    test('7. Subnet Scan Permission Guard requires explicit operator consent', () {
      SubnetScanPermissionManager.revokeConsent();
      expect(SubnetScanPermissionManager.isConsentGiven, isFalse);

      SubnetScanPermissionManager.grantConsent('192.168.1.0/24');
      expect(SubnetScanPermissionManager.isConsentGiven, isTrue);
      expect(SubnetScanPermissionManager.authorizedSubnetCidr, equals('192.168.1.0/24'));
    });
  });
}
