import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:print_helper/features/presets/data/presets_persistence.dart';
import 'package:print_helper/features/queue/data/job_history_persistence.dart';
import 'package:print_helper/features/queue/domain/print_job_models.dart';
import 'package:print_helper/features/queue/presentation/job_queue_controller.dart';
import 'package:print_helper/features/workspace/domain/print_queue_item.dart';
import 'package:print_helper/services/file/local_file_service.dart';
import 'package:print_helper/services/notifications/desktop_notification_service.dart';
import 'package:print_helper/services/printer/i_printer_service.dart';
import 'package:print_helper/services/printer/models/printer_models.dart';

class MockPrinterService extends Mock implements IPrinterService {}

class FakePrintHelperJob extends Fake implements PrintHelperJob {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePrintHelperJob());
    registerFallbackValue(SpoolerJobCommand.cancel);
  });

  late Directory tempDir;
  late SqliteJobHistoryPersistence historyPersistence;
  late SqlitePresetsPersistence presetsPersistence;
  late LocalDesktopNotificationService notificationService;
  late LocalFileService fileService;
  late MockPrinterService mockPrinterService;
  late List<PrinterDevice> availablePrinters;
  late JobQueueController controller;

  PrintQueueItem makeSampleItem(String name, int pages, {int copies = 1}) {
    return PrintQueueItem(
      id: 'item_$name',
      filePath: p.join(tempDir.path, name),
      fileName: name,
      extension: 'pdf',
      documentType: PrintDocumentType.pdf,
      fileSizeBytes: 2048,
      pageCount: pages,
      addedAt: DateTime.now(),
      settings: FilePrintSettings(copies: copies),
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('print_helper_workflows_');
    historyPersistence = SqliteJobHistoryPersistence(
      overrideDbPath: p.join(tempDir.path, 'test_history.sqlite'),
    );
    await historyPersistence.init();

    presetsPersistence = SqlitePresetsPersistence(
      overrideDbPath: p.join(tempDir.path, 'test_presets.sqlite'),
    );
    await presetsPersistence.init();

    notificationService = LocalDesktopNotificationService();
    fileService = LocalFileService();
    mockPrinterService = MockPrinterService();

    availablePrinters = [
      const PrinterDevice(
        systemName: 'Branch_Printer_A',
        customNickname: 'Branch A LaserJet',
        driverName: 'HP PCL6',
        portName: 'IP_192.168.1.10',
        connectionType: PrinterConnectionType.network,
        status: PrinterStatusType.ready,
      ),
      const PrinterDevice(
        systemName: 'Branch_Printer_B',
        customNickname: 'Branch B LaserJet',
        driverName: 'HP PCL6',
        portName: 'IP_192.168.1.11',
        connectionType: PrinterConnectionType.network,
        status: PrinterStatusType.ready,
      ),
      const PrinterDevice(
        systemName: 'Offline_Printer_C',
        customNickname: 'Offline Office Printer',
        driverName: 'Canon UFR II',
        portName: 'IP_192.168.1.99',
        connectionType: PrinterConnectionType.network,
        status: PrinterStatusType.offline,
      ),
    ];

    when(
      () => mockPrinterService.submitPrintJob(
        job: any(named: 'job'),
        composedPdfBytes: any(named: 'composedPdfBytes'),
      ),
    ).thenAnswer(
      (_) async => const SpoolSubmissionResult(
        isSuccess: true,
        spoolerJobId: 101,
      ),
    );

    controller = JobQueueController(
      printerService: mockPrinterService,
      historyPersistence: historyPersistence,
      notificationService: notificationService,
      fileService: fileService,
      presetsPersistence: presetsPersistence,
      readAvailablePrinters: () => availablePrinters,
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    historyPersistence.dispose();
    presetsPersistence.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
      'Broadcast Mode: prints the same file to multiple branch printers at once',
      () async {
    final doc = makeSampleItem('policy_memo.pdf', 4);

    final jobs = await controller.enqueueBatch(
      items: [doc],
      primaryPrinterName: 'Branch_Printer_A',
      overrideMode: MultiPrinterRoutingMode.broadcastAll,
      overrideMultiPrinters: ['Branch_Printer_A', 'Branch_Printer_B'],
    );

    expect(jobs.length, 2);
    expect(
      controller.state.activeJobs.map((j) => j.targetPrinterSystemName).toSet(),
      {'Branch_Printer_A', 'Branch_Printer_B'},
    );
    expect(
      controller.state.activeJobs
          .every((j) => j.status == PrintJobStatus.completed),
      isTrue,
    );
    // Desktop notification emitted on completion
    expect(notificationService.recentNotifications, isNotEmpty);
  });

  test(
      'Load-Balance Mode: splits a batch across printers balancing page weight',
      () async {
    final items = [
      makeSampleItem('large_report.pdf', 10), // 10 pages -> Printer A (load=10)
      makeSampleItem('short_invoice_1.pdf', 4), // 4 pages -> Printer B (load=4)
      makeSampleItem('short_invoice_2.pdf', 5), // 5 pages -> Printer B (load=9)
      makeSampleItem('summary.pdf', 3), // 3 pages -> Printer B (load=9 <= 10)
    ];

    final jobs = await controller.enqueueBatch(
      items: items,
      primaryPrinterName: 'Branch_Printer_A',
      overrideMode: MultiPrinterRoutingMode.loadBalanceSplit,
      overrideMultiPrinters: ['Branch_Printer_A', 'Branch_Printer_B'],
    );

    expect(jobs.length, 4);
    expect(jobs[0].targetPrinterSystemName, 'Branch_Printer_A');
    expect(jobs[1].targetPrinterSystemName, 'Branch_Printer_B');
    expect(jobs[2].targetPrinterSystemName, 'Branch_Printer_B');
    expect(jobs[3].targetPrinterSystemName, 'Branch_Printer_B');
  });

  test(
      'Automatic Offline Fallback: detects offline printer, offers ready fallback, and completes after reroute',
      () async {
    final item = makeSampleItem('urgent_contract.pdf', 6);

    await controller.enqueueBatch(
      items: [item],
      primaryPrinterName: 'Offline_Printer_C',
    );

    final stuckJob = controller.state.activeJobs.first;
    expect(stuckJob.status, PrintJobStatus.awaitingFallback);
    expect(stuckJob.fallbackSuggestedPrinter, 'Branch_Printer_A');
    expect(controller.state.latestNotification?.isError, isTrue);

    // User clicks "Send to Branch A LaserJet"
    await controller.rerouteJobToFallbackPrinter(
      jobId: stuckJob.id,
      newPrinterSystemName: 'Branch_Printer_A',
    );

    final completedJob = controller.state.activeJobs.first;
    expect(completedJob.status, PrintJobStatus.completed);
    expect(completedJob.targetPrinterSystemName, 'Branch_Printer_A');
    expect(completedJob.pagesPrinted, 6);
  });

  test(
      'Print History: supports search, reprint button, and UTF-8 BOM CSV export',
      () async {
    await controller.enqueueBatch(
      items: [
        makeSampleItem('sinhala_receipt_01.pdf', 2),
        makeSampleItem('annual_budget_2026.pdf', 8),
      ],
      primaryPrinterName: 'Branch_Printer_A',
    );

    expect(controller.state.historyJobs.length, 2);

    // Search history
    await controller.setHistorySearchQuery('sinhala_receipt');
    expect(controller.state.historyJobs.length, 1);
    expect(
      controller.state.historyJobs.first.fileName,
      'sinhala_receipt_01.pdf',
    );

    // Export CSV
    final csvPath = p.join(tempDir.path, 'exported_history.csv');
    final csvFile = await controller.exportHistoryToCsvFile(csvPath);
    expect(await csvFile.exists(), isTrue);
    final rawBytes = await csvFile.readAsBytes();
    // Verify UTF-8 BOM
    expect(rawBytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    final csvText = utf8.decode(rawBytes.skip(3).toList());
    expect(csvText, contains('sinhala_receipt_01.pdf'));
    expect(csvText, contains('Branch A LaserJet'));

    // Reprint from history
    await controller.reprintFromHistory(controller.state.historyJobs.first);
    await controller.setHistorySearchQuery('');
    expect(controller.state.historyJobs.length, 3);
  });

  test(
      'Hot Folder Auto-Print: detects new file in watched folder and prints with chosen preset',
      () async {
    final hotDir = Directory(p.join(tempDir.path, 'hot_folder'));
    await hotDir.create(recursive: true);

    await controller.updateHotFolderConfig(
      HotFolderConfig(
        enabled: true,
        folderPath: hotDir.path,
        presetId: 'builtin_duplex_bw_draft',
        targetPrinterSystemName: 'Branch_Printer_B',
      ),
    );

    final droppedFile = File(p.join(hotDir.path, 'auto_incoming_note.txt'));
    await droppedFile.writeAsString(
      'ආයුබෝවන් — Automatically printed from Hot Folder!\nLine 2',
    );

    await controller.processHotFolderFile(droppedFile.path);

    final autoJob = controller.state.activeJobs.last;
    expect(autoJob.fileName, 'auto_incoming_note.txt');
    expect(autoJob.targetPrinterSystemName, 'Branch_Printer_B');
    // Verified that "Double-sided B&W draft" preset was applied automatically
    expect(autoJob.settings.duplex, DuplexMode.longEdge);
    expect(autoJob.settings.isColor, isFalse);
    expect(autoJob.settings.quality, PrintQualityMode.draft);
    expect(autoJob.status, PrintJobStatus.completed);
  });
}
