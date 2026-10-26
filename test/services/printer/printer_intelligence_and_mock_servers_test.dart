import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/services/printer/models/printer_intelligence_models.dart';
import 'package:print_helper/services/printer/models/printer_models.dart';
import 'package:print_helper/services/printer/printer_intelligence_service.dart';

/// Real local loopback Mock IPP (RFC 8011 HTTP server) + Mock SNMP (RFC 3805 UDP responder)
/// + Mock Epson Web Config server for deterministic verification of `PrinterIntelligenceService`.
class LocalMockPrinterServers {
  HttpServer? _httpServer;
  RawDatagramSocket? _snmpSocket;

  late Uint8List activeIppResponseBytes;
  late Map<String, Object> activeSnmpOidValues;
  String activeWebConfigHtml = '';

  int get httpPort => _httpServer!.port;
  int get snmpPort => _snmpSocket!.port;

  Future<void> start() async {
    _httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _httpServer!.listen((HttpRequest req) async {
      if (req.uri.path == '/ipp/print' && req.method == 'POST') {
        req.response.statusCode = 200;
        req.response.headers
            .set(HttpHeaders.contentTypeHeader, 'application/ipp');
        req.response.add(activeIppResponseBytes);
        await req.response.close();
      } else if (req.uri.path == '/PRESENTATION/HTML/TOP/PRTINFO.HTML') {
        req.response.statusCode = 200;
        req.response.headers
            .set(HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8');
        req.response.write(activeWebConfigHtml);
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });

    _snmpSocket =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    _snmpSocket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final dg = _snmpSocket?.receive();
        if (dg != null) {
          final responsePacket = _buildMockSnmpGetResponse(activeSnmpOidValues);
          _snmpSocket?.send(responsePacket, dg.address, dg.port);
        }
      }
    });
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    _snmpSocket?.close();
  }

  /// Encodes an RFC 8011 binary IPP `Get-Printer-Attributes` response (`0x0000` OK).
  static Uint8List buildMockIppResponse({
    required int printerStateEnum,
    required List<String> stateReasons,
    required List<String> markerNames,
    required List<int> markerLevels,
    required List<String> markerColors,
    required List<String> markerTypes,
    required List<int> markerLowLevels,
    required List<String> mediaSupported,
    required List<String> mediaReady,
    required List<String> mediaColDatabase,
    required List<String> mediaTypeSupported,
    required List<String> sidesSupported,
    required List<String> printColorModeSupported,
    required List<String> outputBinSupported,
    String? firmwareVersion,
    int? impressionsCompleted,
  }) {
    final b = BytesBuilder();
    // IPP 2.0, status-code = 0x0000 (successful-ok), request-id = 1
    b.add(const [0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]);
    // Operation-Attributes-Tag (0x01)
    b.addByte(0x01);
    _addStringAttr(b, 0x47, 'attributes-charset', 'utf-8');
    _addStringAttr(b, 0x48, 'attributes-natural-language', 'en');

    // Printer-Attributes-Tag (0x04)
    b.addByte(0x04);
    _addIntAttr(b, 0x23, 'printer-state', [printerStateEnum]);
    _addStringListAttr(b, 0x44, 'printer-state-reasons', stateReasons);
    _addStringListAttr(b, 0x41, 'marker-names', markerNames);
    _addIntAttr(b, 0x21, 'marker-levels', markerLevels);
    _addStringListAttr(b, 0x41, 'marker-colors', markerColors);
    _addStringListAttr(b, 0x44, 'marker-types', markerTypes);
    _addIntAttr(b, 0x21, 'marker-low-levels', markerLowLevels);
    _addStringListAttr(b, 0x44, 'media-supported', mediaSupported);
    _addStringListAttr(b, 0x44, 'media-ready', mediaReady);
    _addStringListAttr(b, 0x41, 'media-col-database', mediaColDatabase);
    _addStringListAttr(b, 0x44, 'media-type-supported', mediaTypeSupported);
    _addStringListAttr(b, 0x44, 'sides-supported', sidesSupported);
    _addStringListAttr(
        b, 0x44, 'print-color-mode-supported', printColorModeSupported);
    _addStringListAttr(b, 0x44, 'output-bin-supported', outputBinSupported);

    if (firmwareVersion != null) {
      _addStringAttr(
          b, 0x41, 'printer-firmware-string-version', firmwareVersion);
    }
    if (impressionsCompleted != null) {
      _addIntAttr(
          b, 0x21, 'printer-impressions-completed', [impressionsCompleted]);
    }

    // End-of-Attributes-Tag (0x03)
    b.addByte(0x03);
    return b.toBytes();
  }

  static void _addStringAttr(
      BytesBuilder b, int tag, String name, String val) {
    final nb = utf8.encode(name);
    final vb = utf8.encode(val);
    b.addByte(tag);
    b.add([(nb.length >> 8) & 0xFF, nb.length & 0xFF]);
    b.add(nb);
    b.add([(vb.length >> 8) & 0xFF, vb.length & 0xFF]);
    b.add(vb);
  }

  static void _addStringListAttr(
      BytesBuilder b, int tag, String name, List<String> vals) {
    if (vals.isEmpty) return;
    _addStringAttr(b, tag, name, vals.first);
    for (int i = 1; i < vals.length; i++) {
      _addStringAttr(b, tag, '', vals[i]);
    }
  }

  static void _addIntAttr(
      BytesBuilder b, int tag, String name, List<int> vals) {
    if (vals.isEmpty) return;
    for (int i = 0; i < vals.length; i++) {
      final nb = i == 0 ? utf8.encode(name) : const <int>[];
      final bd = ByteData(4)..setInt32(0, vals[i], Endian.big);
      b.addByte(tag);
      b.add([(nb.length >> 8) & 0xFF, nb.length & 0xFF]);
      b.add(nb);
      b.add(const [0x00, 0x04]);
      b.add(bd.buffer.asUint8List());
    }
  }

  static Uint8List _buildMockSnmpGetResponse(Map<String, Object> oidValues) {
    final varbinds = BytesBuilder();
    for (final entry in oidValues.entries) {
      final oidBytes = _encodeOid(entry.key);
      final valBytes = entry.value is int
          ? _encodeInt(entry.value as int)
          : _wrapTl(0x04, Uint8List.fromList(utf8.encode(entry.value.toString())));
      final seq = BytesBuilder()
        ..add(oidBytes)
        ..add(valBytes);
      varbinds.add(_wrapTl(0x30, seq.toBytes()));
    }
    final vbList = _wrapTl(0x30, varbinds.toBytes());
    final pduBody = BytesBuilder()
      ..add(_encodeInt(101))
      ..add(_encodeInt(0))
      ..add(_encodeInt(0))
      ..add(vbList);
    final getResponsePdu = _wrapTl(0xA2, pduBody.toBytes());
    final msgBody = BytesBuilder()
      ..add(_encodeInt(1))
      ..add(_wrapTl(0x04, Uint8List.fromList(utf8.encode('public'))))
      ..add(getResponsePdu);
    return _wrapTl(0x30, msgBody.toBytes());
  }

  static Uint8List _wrapTl(int tag, Uint8List val) {
    final b = BytesBuilder()..addByte(tag);
    if (val.length < 128) {
      b.addByte(val.length);
    } else if (val.length < 256) {
      b.addByte(0x81);
      b.addByte(val.length);
    } else {
      b.addByte(0x82);
      b.addByte((val.length >> 8) & 0xFF);
      b.addByte(val.length & 0xFF);
    }
    b.add(val);
    return b.toBytes();
  }

  static Uint8List _encodeInt(int val) {
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
    return _wrapTl(0x02, Uint8List.fromList(bytes));
  }

  static Uint8List _encodeOid(String oid) {
    final parts = oid.split('.').map(int.parse).toList();
    final out = <int>[parts[0] * 40 + parts[1]];
    for (int i = 2; i < parts.length; i++) {
      int sub = parts[i];
      if (sub < 128) {
        out.add(sub);
      } else {
        final tmp = <int>[sub & 0x7F];
        sub >>= 7;
        while (sub > 0) {
          tmp.insert(0, (sub & 0x7F) | 0x80);
          sub >>= 7;
        }
        out.addAll(tmp);
      }
    }
    return _wrapTl(0x06, Uint8List.fromList(out));
  }
}

void main() {
  late LocalMockPrinterServers mockServers;
  late PrinterIntelligenceService service;

  setUp(() async {
    mockServers = LocalMockPrinterServers();
    await mockServers.start();
    service = PrinterIntelligenceService(
      networkTimeout: const Duration(milliseconds: 1500),
    );
  });

  tearDown(() async {
    service.dispose();
    await mockServers.stop();
  });

  group('PrinterIntelligence Multi-Source Priority & Epson Profiles', () {
    test(
        'Epson EcoTank L3250: merges IPP (-3 bottle level = OK without guessing %) + SNMP page counter + Epson profile',
        () async {
      mockServers.activeIppResponseBytes =
          LocalMockPrinterServers.buildMockIppResponse(
        printerStateEnum: 3, // Idle / Ready
        stateReasons: const ['none'],
        markerNames: const [
          'Black Ink Bottle 003',
          'Cyan Ink Bottle 003',
          'Magenta Ink Bottle 003',
          'Yellow Ink Bottle 003',
        ],
        // RFC 8011 / RFC 3805 -3 means "some remaining / OK" without an exact %
        markerLevels: const [-3, -3, -3, -3],
        markerColors: const ['#000000', '#00FFFF', '#FF00FF', '#FFFF00'],
        markerTypes: const ['ink', 'ink', 'ink', 'ink'],
        markerLowLevels: const [15, 15, 15, 15],
        mediaSupported: const ['iso_a4_210x297mm', 'na_letter_8.5x11in', 'na_index-4x6_4x6in'],
        mediaReady: const ['iso_a4_210x297mm'],
        mediaColDatabase: const [
          '{media-source=rear;media-size-name=iso_a4_210x297mm;media-type=stationery}',
        ],
        mediaTypeSupported: const ['stationery', 'photographic-glossy'],
        sidesSupported: const ['one-sided'],
        printColorModeSupported: const ['color', 'monochrome'],
        outputBinSupported: const ['face-up'],
        firmwareVersion: '05.42.XF22M5',
      );

      mockServers.activeSnmpOidValues = {
        StandardPrinterMibOids.hrPrinterStatus: 3,
        StandardPrinterMibOids.prtMarkerLifeCount: 3842,
      };

      const printer = PrinterDevice(
        systemName: 'EPSON L3250 Series',
        driverName: 'EPSON L3250 Series',
        portName: 'IP_127.0.0.1',
        connectionType: PrinterConnectionType.network,
        status: PrinterStatusType.ready,
        ipAddress: '127.0.0.1',
      );

      final intel = await service.fetchIntelligence(
        printer,
        ippPort: mockServers.httpPort,
        snmpPort: mockServers.snmpPort,
      );

      expect(intel.matchedProfile?.familyId, 'epson_ecotank_consumer_usb_wifi');
      expect(intel.printerState.value, LivePrinterState.ready);
      expect(intel.printerState.source, PrinterTelemetrySource.ipp);

      // Verify EcoTank -3 level reports qualitative "OK" and never invents a percentage
      expect(intel.supplies.isReported, isTrue);
      final black = intel.supplies.value!.first;
      expect(black.levelPercent.isReported, isFalse);
      expect(
        black.levelPercent.formatOrNotReported((v) => '$v%'),
        kNotReportedByPrinterEn,
      );
      expect(black.qualitativeStatus.value, QualitativeSupplyStatus.ok);

      // Verify page counter came from SNMP (Priority 2) because IPP omitted impressions
      expect(intel.lifetimePageCount.value, 3842);
      expect(intel.lifetimePageCount.source, PrinterTelemetrySource.snmp);

      // Verify firmware came from IPP (Priority 1)
      expect(intel.firmwareVersion.value, '05.42.XF22M5');
      expect(intel.firmwareVersion.source, PrinterTelemetrySource.ipp);

      // Verify paper availability evaluation
      expect(intel.evaluatePaperSize('A4'), PaperAvailabilityState.loadedNow);
      expect(
        intel.evaluatePaperSize('Letter'),
        PaperAvailabilityState.supportedNotLoaded,
      );
      expect(intel.evaluatePaperSize('A3'), PaperAvailabilityState.notSupported);
    });

    test(
        'Epson WorkForce Pro WF-C5890: reports exact 0-100% ink + Maintenance Box, low Cyan warning, and Smart Print Validation "Fix it for me"',
        () async {
      mockServers.activeIppResponseBytes =
          LocalMockPrinterServers.buildMockIppResponse(
        printerStateEnum: 3,
        stateReasons: const ['marker-supply-low-warning'],
        markerNames: const [
          'Black Ink Pack',
          'Cyan Ink Pack',
          'Magenta Ink Pack',
          'Yellow Ink Pack',
          'Maintenance Box',
        ],
        markerLevels: const [82, 9, 64, 71, 78],
        markerColors: const [
          '#000000',
          '#00FFFF',
          '#FF00FF',
          '#FFFF00',
          '#64748B',
        ],
        markerTypes: const [
          'inkCartridge',
          'inkCartridge',
          'inkCartridge',
          'inkCartridge',
          'wasteInk',
        ],
        markerLowLevels: const [15, 15, 15, 15, 10],
        mediaSupported: const ['iso_a4_210x297mm', 'iso_a3_297x420mm', 'na_letter_8.5x11in'],
        mediaReady: const ['iso_a4_210x297mm'],
        mediaColDatabase: const [
          '{media-source=tray-1;media-size-name=iso_a4_210x297mm;media-type=stationery}',
        ],
        mediaTypeSupported: const ['stationery', 'photographic-glossy', 'envelope'],
        sidesSupported: const [
          'one-sided',
          'two-sided-long-edge',
          'two-sided-short-edge',
        ],
        printColorModeSupported: const ['color', 'monochrome'],
        outputBinSupported: const ['face-down'],
        impressionsCompleted: 14920,
      );

      mockServers.activeSnmpOidValues = {
        StandardPrinterMibOids.hrPrinterStatus: 3,
        '${StandardPrinterMibOids.prtMarkerSuppliesDescriptionPrefix}2':
            'Cyan Ink Pack',
        '${StandardPrinterMibOids.prtMarkerSuppliesMaxCapacityPrefix}2': 5000,
        '${StandardPrinterMibOids.prtMarkerSuppliesLevelPrefix}2': 450,
      };

      const printer = PrinterDevice(
        systemName: 'EPSON WF-C5890 Series',
        driverName: 'EPSON WF-C5890 Series',
        portName: 'IP_127.0.0.1',
        connectionType: PrinterConnectionType.network,
        status: PrinterStatusType.ready,
        ipAddress: '127.0.0.1',
      );

      final intel = await service.fetchIntelligence(
        printer,
        ippPort: mockServers.httpPort,
        snmpPort: mockServers.snmpPort,
      );

      expect(intel.matchedProfile?.familyId, 'epson_workforce_pro_rips');
      expect(intel.duplexSupport.value, DuplexSupportMode.automatic);

      final cyan = intel.supplies.value![1];
      expect(cyan.levelPercent.value, 9);
      expect(cyan.isLow, isTrue);
      // Estimated pages remaining calculated from SNMP maxCapacity (5000 * 9% = 450)
      expect(cyan.estimatedPagesRemaining.isReported, isTrue);
      expect(cyan.estimatedPagesRemaining.value, 450);

      // Maintenance box reported at 78%
      expect(
        intel.maintenanceBoxStatus.value,
        contains('78% remaining capacity'),
      );

      // Run Smart Print Validation with A3 (supported but not loaded) and Photo Paper (tray has Plain Paper)
      final validation = service.validatePrintJob(
        intelligence: intel,
        requestedPaperSize: 'A3',
        requestedMediaType: 'Photo Paper Glossy',
        requestedTwoSided: true,
        requestedColor: true,
        requestedBorderless: false,
      );

      // Low Cyan ink + A3 not loaded + Photo paper mismatch MUST NOT block printing
      expect(validation.hasHardBlockingPrinterFailure, isFalse);

      // Check that friendly messages and "Fix it for me" actions are generated
      expect(
        validation.checks.any((c) =>
            c.messageEn.contains('Double-sided is supported on this printer')),
        isTrue,
      );
      expect(
        validation.checks.any((c) =>
            c.messageEn.contains('A3 is supported but not currently loaded') &&
            c.autoFix?.targetPaperSize == 'A4'),
        isTrue,
      );
      expect(
        validation.checks.any((c) =>
            c.messageEn.contains('reports plain paper in the tray') &&
            c.autoFix?.targetMediaType == 'Plain Paper'),
        isTrue,
      );
      expect(
        validation.checks.any((c) =>
            c.messageEn.contains('Cyan Ink Pack (9%) is low; color prints may be affected.')),
        isTrue,
      );
    });

    test('Manual Duplex Assistant computes odd/even batches and keep-out rule',
        () {
      final plan5Pages = service.buildManualDuplexPlan(
        totalPages: 5,
        flipEdge: ManualDuplexFlipEdge.longEdge,
        reverseEvenOrderForRearFeed: true,
      );

      expect(plan5Pages.step1OddPages, [1, 3, 5]);
      expect(plan5Pages.step3EvenPages, [4, 2]);
      expect(plan5Pages.needsBlankLastSheetKeepOut, isTrue);
      expect(plan5Pages.trayGuidanceEn, contains('Page 5'));
    });

    test('Consented Epson Web Config fallback only runs when user consents',
        () async {
      mockServers.activeIppResponseBytes = Uint8List(0); // IPP unreachable
      mockServers.activeSnmpOidValues = {}; // SNMP empty
      mockServers.activeWebConfigHtml = '''
        <html><body>
          <table>
            <tr><td>Firmware Version</td><td><td>FA19N2</td></tr>
            <tr><td>Total Number of Pages</td><td>1280</td></tr>
            <tr><td>Maintenance Box</td><td>Available</td></tr>
          </table>
        </body></html>
      ''';

      const printer = PrinterDevice(
        systemName: 'EPSON L4260 Series',
        driverName: 'EPSON L4260 Series',
        portName: 'IP_127.0.0.1',
        connectionType: PrinterConnectionType.network,
        status: PrinterStatusType.ready,
        ipAddress: '127.0.0.1',
      );

      // Without consent: firmware & page counter must be "Not reported by this printer"
      final withoutConsent = await service.fetchIntelligence(
        printer,
        ippPort: mockServers.httpPort,
        snmpPort: mockServers.snmpPort,
        webConfigPort: mockServers.httpPort,
      );
      expect(withoutConsent.firmwareVersion.isReported, isFalse);
      expect(
        withoutConsent.firmwareVersion.formatOrNotReported((v) => v),
        kNotReportedByPrinterEn,
      );

      // Grant consent: Web Config fallback populates firmware, page counter, and maintenance box
      service.setWebConfigConsent(printer.systemName, true);
      final withConsent = await service.fetchIntelligence(
        printer,
        ippPort: mockServers.httpPort,
        snmpPort: mockServers.snmpPort,
        webConfigPort: mockServers.httpPort,
      );
      expect(withConsent.firmwareVersion.isReported, isTrue);
      expect(withConsent.firmwareVersion.value, 'FA19N2');
      expect(
        withConsent.firmwareVersion.source,
        PrinterTelemetrySource.webConfigFallback,
      );
      expect(withConsent.lifetimePageCount.value, 1280);
      expect(withConsent.maintenanceBoxStatus.value, 'Available');
    });
  });
}
