import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:print_helper/features/printers/data/printer_preferences_persistence.dart';
import 'package:print_helper/features/printers/data/printer_repository.dart';
import 'package:print_helper/features/printers/presentation/printers_controller.dart';
import 'package:print_helper/features/workspace/domain/print_queue_item.dart';
import 'package:print_helper/services/printer/i_printer_service.dart';
import 'package:print_helper/services/printer/models/printer_models.dart';

class MockPrinterService extends Mock implements IPrinterService {}

class FakePrinterDevice extends Fake implements PrinterDevice {}

void main() {
  setUpAll(() {
    registerFallbackValue(NetworkPrintProtocol.raw9100);
    registerFallbackValue(FakePrinterDevice());
  });

  late Directory tempDir;
  late SqlitePrinterPreferencesPersistence persistence;
  late MockPrinterService mockService;
  late PrinterRepository repository;
  late PrintersController controller;

  const samplePrinters = [
    PrinterDevice(
      systemName: 'Canon Offline LAN',
      driverName: 'Canon Generic PCL6',
      portName: 'IP_192.168.1.99',
      ipAddress: '192.168.1.99',
      connectionType: PrinterConnectionType.network,
      status: PrinterStatusType.offline,
    ),
    PrinterDevice(
      systemName: 'Microsoft Print to PDF',
      driverName: 'Microsoft Print To PDF',
      portName: 'PORTPROMPT:',
      connectionType: PrinterConnectionType.virtual,
      status: PrinterStatusType.ready,
      isDefault: true,
    ),
    PrinterDevice(
      systemName: 'HP USB LaserJet',
      driverName: 'HP Universal PCL6',
      portName: 'USB001',
      connectionType: PrinterConnectionType.usb,
      status: PrinterStatusType.ready,
      capabilities: PrinterCapabilities(
        supportsColor: false,
        supportsDuplex: true,
        trays: [
          PaperTrayCapability(code: 7, name: 'Auto Select'),
          PaperTrayCapability(code: 1, name: 'Tray 1'),
          PaperTrayCapability(code: 2, name: 'Tray 2 (500-sheet)'),
        ],
        resolutions: [
          PrinterResolution(xdpi: 600, ydpi: 600),
          PrinterResolution(xdpi: 1200, ydpi: 1200),
        ],
      ),
    ),
  ];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('print_helper_printers_');
    persistence = SqlitePrinterPreferencesPersistence(
      overrideDbPath: p.join(tempDir.path, 'test_printers.sqlite'),
    );
    await persistence.init();

    mockService = MockPrinterService();
    when(() => mockService.listInstalledPrinters())
        .thenAnswer((_) async => samplePrinters);

    repository = PrinterRepository(
      printerService: mockService,
      persistence: persistence,
    );
    controller = PrintersController(repository: repository);
  });

  tearDown(() async {
    controller.dispose();
    persistence.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
      'Lists printers from spooler and sorts Default -> Ready -> Offline, then Favorites first',
      () async {
    await controller.refreshPrinters();

    expect(controller.state.printers.length, 3);
    // Default printer ("Microsoft Print to PDF") should be first initially
    expect(
      controller.state.printers[0].systemName,
      'Microsoft Print to PDF',
    );
    // Ready USB printer second, Offline LAN printer last
    expect(controller.state.printers[1].systemName, 'HP USB LaserJet');
    expect(controller.state.printers[2].systemName, 'Canon Offline LAN');

    // Verify per-printer capabilities on HP USB LaserJet
    final hpCaps = controller.state.printers[1].capabilities;
    expect(hpCaps.supportsDuplex, isTrue);
    expect(hpCaps.supportsColor, isFalse);
    expect(hpCaps.trays.length, 3);
    expect(hpCaps.maxResolution.xdpi, 1200);

    // Mark HP USB LaserJet as Favorite -> should move to index 0 ahead of Default
    await controller.toggleFavorite('HP USB LaserJet');
    expect(controller.state.printers.first.systemName, 'HP USB LaserJet');
    expect(controller.state.printers.first.isFavorite, isTrue);
  });

  test('Persists custom nicknames and last-used printer per file type',
      () async {
    await controller.refreshPrinters();

    await controller.updateNickname('HP USB LaserJet', 'Front Desk Laser');
    expect(
      controller.state.printers
          .firstWhere((p) => p.systemName == 'HP USB LaserJet')
          .displayName,
      'Front Desk Laser',
    );

    // Remember HP USB LaserJet for PDFs and Microsoft Print to PDF for Images
    await controller.rememberPrinterForFileType(
      PrintDocumentType.pdf,
      'HP USB LaserJet',
    );
    await controller.rememberPrinterForFileType(
      PrintDocumentType.image,
      'Microsoft Print to PDF',
    );

    expect(
      controller.preferredPrinterForFileType(PrintDocumentType.pdf)?.systemName,
      'HP USB LaserJet',
    );
    expect(
      controller
          .preferredPrinterForFileType(PrintDocumentType.image)
          ?.systemName,
      'Microsoft Print to PDF',
    );
  });

  test('Tests connection and adds network printer (RAW 9100 & IPP 631)',
      () async {
    when(
      () => mockService.testNetworkPrinterConnection(
        host: any(named: 'host'),
        port: any(named: 'port'),
        protocol: any(named: 'protocol'),
      ),
    ).thenAnswer(
      (_) async => const ConnectionTestResult(
        isSuccess: true,
        host: '192.168.1.120',
        port: 631,
        protocol: NetworkPrintProtocol.ipp631,
        latencyMs: 14,
        messageEn: 'Connected in 14ms',
        messageSi: 'මිලි-තත්පර 14 කින් සම්බන්ධ විය',
      ),
    );

    when(
      () => mockService.registerNetworkPrinter(
        host: '192.168.1.120',
        port: 631,
        protocol: NetworkPrintProtocol.ipp631,
        customName: 'Accounting IPP Printer',
      ),
    ).thenAnswer(
      (_) async => const PrinterDevice(
        systemName: 'Accounting IPP Printer',
        customNickname: 'Accounting IPP Printer',
        driverName: 'Generic / Network IPP',
        portName: 'http://192.168.1.120:631/ipp/print',
        connectionType: PrinterConnectionType.network,
        status: PrinterStatusType.ready,
        ipAddress: '192.168.1.120',
        networkPort: 631,
        networkProtocol: NetworkPrintProtocol.ipp631,
      ),
    );

    await controller.refreshPrinters();
    final testRes = await controller.testNetworkConnection(
      host: '192.168.1.120',
      port: 631,
      protocol: NetworkPrintProtocol.ipp631,
    );
    expect(testRes.isSuccess, isTrue);
    expect(testRes.latencyMs, 14);

    await controller.addNetworkPrinter(
      host: '192.168.1.120',
      port: 631,
      protocol: NetworkPrintProtocol.ipp631,
      nickname: 'Accounting IPP Printer',
    );

    expect(
      controller.state.printers
          .any((p) => p.systemName == 'Accounting IPP Printer'),
      isTrue,
    );
  });

  test('Streams LAN discovery progress and enforces user consent for subnet scan',
      () async {
    when(
      () => mockService.discoverLanPrinters(
        includeSubnetScan: true,
      ),
    ).thenAnswer((_) {
      return Stream.fromIterable([
        const LanDiscoveryProgress(
          phase: LanDiscoveryPhase.mdnsQuery,
          progress: 0.25,
          scannedHosts: 1,
          totalHosts: 254,
          discovered: [],
        ),
        const LanDiscoveryProgress(
          phase: LanDiscoveryPhase.completed,
          progress: 1.0,
          scannedHosts: 254,
          totalHosts: 254,
          discovered: [
            DiscoveredLanPrinter(
              ipAddress: '192.168.1.77',
              port: 9100,
              protocol: NetworkPrintProtocol.raw9100,
              discoveryMethod: 'LAN Subnet Scan',
              latencyMs: 9,
              deviceName: 'Brother HL-L2370DW',
            ),
          ],
        ),
      ]);
    });

    controller.setSubnetScanConsent(true);
    await controller.startLanDiscovery();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(controller.state.isDiscoveringLan, isFalse);
    expect(controller.state.discoveryProgress?.progress, 1.0);
    expect(controller.state.discoveryProgress?.discovered.length, 1);
    expect(
      controller.state.discoveryProgress?.discovered.first.ipAddress,
      '192.168.1.77',
    );
  });

  test('Runs plain-language health check in English and Sinhala', () async {
    await controller.refreshPrinters();
    final offlinePrinter = controller.state.printers
        .firstWhere((p) => p.systemName == 'Canon Offline LAN');

    when(() => mockService.runHealthCheck(any())).thenAnswer(
      (_) async => const PrinterHealthReport(
        printerName: 'Canon Offline LAN',
        severity: HealthSeverity.critical,
        headlineEn: 'Printer is offline: check power and network cable.',
        headlineSi:
            'මුද්‍රණ යන්ත්‍රය Offline තත්ත්වයේ පවතී: විදුලි සැපයුම සහ ජාල සම්බන්ධතාවය පරීක්ෂා කරන්න.',
        spoolerOk: true,
        portReachable: false,
        activeJobsCount: 0,
        steps: [
          TroubleshootingStep(
            titleEn: '1. Check Power & Network Cable',
            titleSi: '1. විදුලි බලය සහ LAN කේබලය පරීක්ෂා කරන්න',
            detailEn: 'Verify the Ethernet cable is plugged in.',
            detailSi: 'LAN කේබලය නිසි ලෙස සම්බන්ධ කර ඇත්දැයි බලන්න.',
          ),
        ],
      ),
    );

    final report = await controller.runHealthCheck(offlinePrinter);
    expect(report.severity, HealthSeverity.critical);
    expect(report.headline('en'), contains('Printer is offline'));
    expect(report.headline('si'), contains('Offline'));
    expect(report.steps, isNotEmpty);
  });
}
