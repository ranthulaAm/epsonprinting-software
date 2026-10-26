import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:print_helper/core/storage/queue_persistence.dart';
import 'package:print_helper/features/workspace/domain/print_queue_item.dart';
import 'package:print_helper/features/workspace/presentation/queue_controller.dart';
import 'package:print_helper/services/file/local_file_service.dart';

void main() {
  late Directory tempDir;
  late SqliteQueuePersistence persistence;
  late LocalFileService fileService;
  late QueueController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('print_helper_test_');
    persistence = SqliteQueuePersistence(
      overrideDbPath: p.join(tempDir.path, 'test_queue.sqlite'),
    );
    await persistence.init();
    fileService = LocalFileService();
    controller = QueueController(
      persistence: persistence,
      fileService: fileService,
      languageCode: 'en',
    );
  });

  tearDown(() async {
    persistence.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Validates supported files and rejects unsupported extensions gracefully',
      () async {
    final txtFile = File(p.join(tempDir.path, 'invoice_sinhala.txt'));
    await txtFile.writeAsString('ආයුබෝවන් - Print Helper Test Document\nLine 2');

    final badFile = File(p.join(tempDir.path, 'malware.exe'));
    await badFile.writeAsString('MZ...');

    await controller.initialize();
    await controller.addFilePaths([txtFile.path, badFile.path]);

    expect(controller.state.items.length, 1);
    expect(controller.state.items.first.fileName, 'invoice_sinhala.txt');
    expect(
      controller.state.items.first.documentType,
      PrintDocumentType.plainText,
    );
    expect(controller.state.latestErrorMessages.length, 1);
    expect(
      controller.state.latestErrorMessages.first,
      contains('malware.exe'),
    );
  });

  test('Rejects 0-byte or corrupted PDF files without crashing', () async {
    final corruptPdf = File(p.join(tempDir.path, 'broken.pdf'));
    await corruptPdf.writeAsString('NOT_A_VALID_PDF_HEADER');

    await controller.initialize();
    await controller.addFilePaths([corruptPdf.path]);

    expect(controller.state.items, isEmpty);
    expect(controller.state.latestErrorMessages, isNotEmpty);
    expect(
      controller.state.latestErrorMessages.first,
      contains('broken.pdf'),
    );
  });

  test('Persists queue order and per-file settings across restarts', () async {
    final fileA = File(p.join(tempDir.path, 'first.txt'));
    final fileB = File(p.join(tempDir.path, 'second.txt'));
    await fileA.writeAsString('First document content');
    await fileB.writeAsString('Second document content');

    await controller.initialize();
    await controller.addFilePaths([fileA.path, fileB.path]);
    expect(controller.state.items.length, 2);

    // Update settings on first item (3 copies, duplex longEdge)
    final firstId = controller.state.items.first.id;
    await controller.updateItemSettings(
      firstId,
      const FilePrintSettings(
        copies: 3,
        duplex: DuplexMode.longEdge,
        isColor: false,
      ),
    );

    // Reorder items (swap index 0 and 1)
    await controller.reorderItems(0, 2);
    expect(controller.state.items.first.fileName, 'second.txt');

    // Simulate app relaunch with a fresh QueueController reading from the same SQLite DB
    final relaunchedController = QueueController(
      persistence: persistence,
      fileService: fileService,
      languageCode: 'en',
    );
    await relaunchedController.initialize();

    expect(relaunchedController.state.items.length, 2);
    expect(relaunchedController.state.items[0].fileName, 'second.txt');
    expect(relaunchedController.state.items[1].fileName, 'first.txt');
    expect(relaunchedController.state.items[1].settings.copies, 3);
    expect(
      relaunchedController.state.items[1].settings.duplex,
      DuplexMode.longEdge,
    );
    expect(relaunchedController.state.items[1].settings.isColor, isFalse);
  });

  test('Handles "Open with Print Helper" CLI arguments on startup', () async {
    final cliFile = File(p.join(tempDir.path, 'explorer_opened.txt'));
    await cliFile.writeAsString('Opened directly from Windows Explorer');

    await controller.initialize(launchFileArgs: [cliFile.path]);

    expect(controller.state.items.length, 1);
    expect(controller.state.items.first.fileName, 'explorer_opened.txt');
  });
}
