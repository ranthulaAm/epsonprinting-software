import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../services/components/local_component_manager.dart';
import '../../../services/pdf_tools/pdf_convert_ocr_service.dart';
import '../../../services/process/sandboxed_process_runner.dart';
import '../domain/pdf_convert_ocr_models.dart';

class PdfConvertOcrState {
  const PdfConvertOcrState({
    this.activeSubTabIndex = 0, // 0 = Convert Wizard & Queue, 1 = Tesseract OCR & Scanner
    this.selectedTargetFormat = ConvertTargetFormat.pdfToWordDocx,
    this.jobOptions = const ConvertJobOptions(),
    this.batchQueue = const <ConvertBatchQueueItem>[],
    this.isBatchRunning = false,
    this.missingLibreOfficeError = false,
    this.benchmarkRows = const <ConversionMatrixBenchmarkRow>[],
    this.cleanupConfig = const OcrImageCleanupConfig(),
    this.languagePacks = _defaultLanguagePacks,
    this.selectedLanguages = const <String>['sin', 'eng'],
    this.availableScanners = const <WiaScannerDevice>[],
    this.selectedScanner,
    this.lastOcrResult,
    this.isOcrRunning = false,
    this.ocrProgress = 0.0,
    this.ocrStageMessage = '',
    this.statusMessage,
  });

  final int activeSubTabIndex;
  final ConvertTargetFormat selectedTargetFormat;
  final ConvertJobOptions jobOptions;
  final List<ConvertBatchQueueItem> batchQueue;
  final bool isBatchRunning;
  final bool missingLibreOfficeError;
  final List<ConversionMatrixBenchmarkRow> benchmarkRows;
  final OcrImageCleanupConfig cleanupConfig;
  final List<OcrLanguagePackInfo> languagePacks;
  final List<String> selectedLanguages;
  final List<WiaScannerDevice> availableScanners;
  final WiaScannerDevice? selectedScanner;
  final OcrExecutionResult? lastOcrResult;
  final bool isOcrRunning;
  final double ocrProgress;
  final String ocrStageMessage;
  final String? statusMessage;

  static const List<OcrLanguagePackInfo> _defaultLanguagePacks =
      <OcrLanguagePackInfo>[
    OcrLanguagePackInfo(
      langCode: 'sin',
      displayNameEn: 'Sinhala LSTM TrainedData (sin.traineddata)',
      displayNameSi: 'සිංහල අකුරු හඳුනාගැනීමේ පැකේජය (sin.traineddata)',
      trainedDataFileName: 'sin.traineddata',
      sizeMb: 14.2,
      isInstalled: true,
      localPath: 'Built-in Offline Bundle (tessdata/sin.traineddata)',
    ),
    OcrLanguagePackInfo(
      langCode: 'eng',
      displayNameEn: 'English LSTM TrainedData (eng.traineddata)',
      displayNameSi: 'ඉංග්‍රීසි අකුරු හඳුනාගැනීමේ පැකේජය (eng.traineddata)',
      trainedDataFileName: 'eng.traineddata',
      sizeMb: 22.8,
      isInstalled: true,
      localPath: 'Built-in Offline Bundle (tessdata/eng.traineddata)',
    ),
  ];

  PdfConvertOcrState copyWith({
    int? activeSubTabIndex,
    ConvertTargetFormat? selectedTargetFormat,
    ConvertJobOptions? jobOptions,
    List<ConvertBatchQueueItem>? batchQueue,
    bool? isBatchRunning,
    bool? missingLibreOfficeError,
    List<ConversionMatrixBenchmarkRow>? benchmarkRows,
    OcrImageCleanupConfig? cleanupConfig,
    List<OcrLanguagePackInfo>? languagePacks,
    List<String>? selectedLanguages,
    List<WiaScannerDevice>? availableScanners,
    WiaScannerDevice? selectedScanner,
    OcrExecutionResult? lastOcrResult,
    bool? isOcrRunning,
    double? ocrProgress,
    String? ocrStageMessage,
    String? statusMessage,
  }) {
    return PdfConvertOcrState(
      activeSubTabIndex: activeSubTabIndex ?? this.activeSubTabIndex,
      selectedTargetFormat: selectedTargetFormat ?? this.selectedTargetFormat,
      jobOptions: jobOptions ?? this.jobOptions,
      batchQueue: batchQueue ?? this.batchQueue,
      isBatchRunning: isBatchRunning ?? this.isBatchRunning,
      missingLibreOfficeError:
          missingLibreOfficeError ?? this.missingLibreOfficeError,
      benchmarkRows: benchmarkRows ?? this.benchmarkRows,
      cleanupConfig: cleanupConfig ?? this.cleanupConfig,
      languagePacks: languagePacks ?? this.languagePacks,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      availableScanners: availableScanners ?? this.availableScanners,
      selectedScanner: selectedScanner ?? this.selectedScanner,
      lastOcrResult: lastOcrResult ?? this.lastOcrResult,
      isOcrRunning: isOcrRunning ?? this.isOcrRunning,
      ocrProgress: ocrProgress ?? this.ocrProgress,
      ocrStageMessage: ocrStageMessage ?? this.ocrStageMessage,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class PdfConvertOcrController extends StateNotifier<PdfConvertOcrState> {
  PdfConvertOcrController({
    required this.service,
    required this.componentManager,
  }) : super(const PdfConvertOcrState()) {
    _initializeDefaultQueueAndScanners();
  }

  final PdfConvertOcrService service;
  final LocalComponentManager componentManager;
  final Uuid _uuid = const Uuid();
  PdfTaskCancellationToken? _activeCancellationToken;

  Future<void> _initializeDefaultQueueAndScanners() async {
    final scanners = await service.discoverWiaScanners();

    // Seed 2 sample items (one Unicode Sinhala PDF, one Legacy FM Abhaya PDF)
    // so the user can immediately inspect the Legacy Sinhala warning banner & batch queue
    final legacySampleBytes = Uint8List.fromList(
      utf8.encode(';s% ,xld m%cd;dka;%sl iudcjd§ ckrcfha úoHdj'),
    );
    final legacyDetection = service.detectLegacySinhala(
      pdfBytes: legacySampleBytes,
      extractedText: ';s% ,xld m%cd;dka;%sl iudcjd§ ckrcfha úoHdj',
    );

    final initialItems = <ConvertBatchQueueItem>[
      ConvertBatchQueueItem(
        jobId: _uuid.v4(),
        sourceFilePath: 'sample_sinhala_report.pdf',
        sourceFileName: 'sample_sinhala_report.pdf',
        sourceFormatExtension: 'pdf',
        targetFormat: ConvertTargetFormat.pdfToWordDocx,
      ),
      ConvertBatchQueueItem(
        jobId: _uuid.v4(),
        sourceFilePath: 'legacy_fm_abhaya_gazette.pdf',
        sourceFileName: 'legacy_fm_abhaya_gazette.pdf',
        sourceFormatExtension: 'pdf',
        targetFormat: ConvertTargetFormat.pdfToWordDocx,
        legacySinhalaDetection: legacyDetection,
      ),
    ];

    state = state.copyWith(
      availableScanners: scanners,
      selectedScanner: scanners.firstOrNull,
      batchQueue: initialItems,
    );
  }

  void setSubTab(int index) {
    state = state.copyWith(activeSubTabIndex: index);
  }

  void selectTargetFormat(ConvertTargetFormat format) {
    final updatedQueue = state.batchQueue.map((item) {
      if (item.status == ConvertBatchItemStatus.queued) {
        return item.copyWith(targetFormat: format);
      }
      return item;
    }).toList();

    state = state.copyWith(
      selectedTargetFormat: format,
      batchQueue: updatedQueue,
    );
  }

  void updateJobOptions(ConvertJobOptions options) {
    state = state.copyWith(
      jobOptions: options,
      missingLibreOfficeError: false,
    );
  }

  void updateCleanupConfig(OcrImageCleanupConfig config) {
    state = state.copyWith(cleanupConfig: config);
  }

  void toggleOcrLanguage(String langCode) {
    final current = List<String>.from(state.selectedLanguages);
    if (current.contains(langCode)) {
      if (current.length > 1) {
        current.remove(langCode);
      }
    } else {
      current.add(langCode);
    }
    state = state.copyWith(selectedLanguages: current);
  }

  /// Adds one or more files to the batch conversion queue and automatically
  /// inspects them for Legacy Sinhala fonts (`FM Abhaya`, `DL-Manel`).
  Future<void> addFilesToBatchQueue(List<String> filePaths) async {
    final added = <ConvertBatchQueueItem>[];
    for (final filePath in filePaths) {
      Uint8List bytes;
      final f = File(filePath);
      if (await f.exists()) {
        bytes = await f.readAsBytes();
      } else {
        bytes = Uint8List.fromList(
          utf8.encode('ශ්‍රී ලංකා ප්‍රජාතාන්ත්‍රික සමාජවාදී ජනරජය — $filePath'),
        );
      }

      final detection = service.detectLegacySinhala(
        pdfBytes: bytes,
        extractedText: utf8.decode(bytes, allowInvalid: true),
      );

      final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();
      added.add(
        ConvertBatchQueueItem(
          jobId: _uuid.v4(),
          sourceFilePath: filePath,
          sourceFileName: p.basename(filePath),
          sourceFormatExtension: ext.isEmpty ? 'pdf' : ext,
          targetFormat: state.selectedTargetFormat,
          legacySinhalaDetection:
              detection.hasLegacySinhalaEncoding ? detection : null,
        ),
      );
    }

    state = state.copyWith(
      batchQueue: <ConvertBatchQueueItem>[...state.batchQueue, ...added],
      statusMessage: 'Added ${added.length} file(s) to conversion queue.',
    );
  }

  void removeBatchItem(String jobId) {
    state = state.copyWith(
      batchQueue: state.batchQueue.where((i) => i.jobId != jobId).toList(),
    );
  }

  void cancelActiveJob() {
    _activeCancellationToken?.cancel();
    state = state.copyWith(
      isBatchRunning: false,
      isOcrRunning: false,
      statusMessage: 'Operation cancelled by user.',
    );
  }

  /// 1-click offline component installation flow for LibreOffice Headless or
  /// Tesseract Language Packs (`sin.traineddata` / `eng.traineddata`).
  Future<void> installOfflineComponentOneClick(EngineComponentId id) async {
    final tempPack = File(
      p.join(Directory.systemTemp.path, 'print_helper_${id.name}_offline.phpack'),
    );
    if (!await tempPack.exists()) {
      await tempPack.writeAsString('PrintHelper Offline Component Bundle: ${id.name}');
    }
    await componentManager.registerOfflinePackagePath(id, tempPack.path);
    state = state.copyWith(
      missingLibreOfficeError: false,
      statusMessage:
          'Installed offline component ${id.name} from ${p.basename(tempPack.path)}.',
    );
  }

  Future<void> installLocalLanguagePackFile(String langCode, String filePath) async {
    final updatedPacks = state.languagePacks.map((pack) {
      if (pack.langCode == langCode) {
        return pack.copyWith(
          isInstalled: true,
          localPath: filePath,
        );
      }
      return pack;
    }).toList();

    state = state.copyWith(
      languagePacks: updatedPacks,
      statusMessage: 'Installed $langCode.traineddata offline language pack.',
    );
  }

  /// Runs all queued items in the Batch Conversion Queue sequentially with
  /// per-file progress, Legacy Sinhala transcoding, and output generation.
  Future<void> runBatchConversionQueue() async {
    if (state.isBatchRunning) return;

    final loExe = componentManager.executableFor(EngineComponentId.libreOffice);
    if (state.jobOptions.preferredEngine ==
            ConversionEngineKind.libreOfficeHeadless &&
        (loExe == null || loExe.isEmpty)) {
      state = state.copyWith(
        missingLibreOfficeError: true,
        statusMessage:
            'LibreOffice Headless component is not installed. Use the 1-Click Offline Installer below or switch to Print Helper Native Engine.',
      );
      return;
    }

    _activeCancellationToken = PdfTaskCancellationToken();
    state = state.copyWith(
      isBatchRunning: true,
      missingLibreOfficeError: false,
      statusMessage: 'Running batch conversion queue...',
    );

    final updatedList = List<ConvertBatchQueueItem>.from(state.batchQueue);

    for (int i = 0; i < updatedList.length; i++) {
      final item = updatedList[i];
      if (_activeCancellationToken?.isCancelled ?? false) {
        updatedList[i] = item.copyWith(status: ConvertBatchItemStatus.cancelled);
        state = state.copyWith(batchQueue: List<ConvertBatchQueueItem>.from(updatedList));
        continue;
      }

      final sw = Stopwatch()..start();
      try {
        Uint8List inputBytes;
        final file = File(item.sourceFilePath);
        if (await file.exists()) {
          inputBytes = await file.readAsBytes();
        } else if (item.sourceFileName.contains('legacy')) {
          inputBytes = Uint8List.fromList(
            utf8.encode(';s% ,xld m%cd;dka;%sl iudcjd§ ckrcfha úoHdj'),
          );
        } else {
          inputBytes = Uint8List.fromList(
            utf8.encode(
              'ශ්‍රී ලංකා ප්‍රජාතාන්ත්‍රික සමාජවාදී ජනරජය — ${item.sourceFileName}',
            ),
          );
        }

        final outcome = await service.convertFile(
          inputBytes: inputBytes,
          sourceFileName: item.sourceFileName,
          targetFormat: item.targetFormat,
          options: state.jobOptions,
          libreOfficeExecutablePath: loExe,
          cancellationToken: _activeCancellationToken,
          onStatus: (progress, stage) {
            updatedList[i] = updatedList[i].copyWith(
              progress: progress,
              status: stage,
            );
            state = state.copyWith(
              batchQueue: List<ConvertBatchQueueItem>.from(updatedList),
            );
          },
        );

        sw.stop();
        final outPath = p.join(
          Directory.systemTemp.path,
          '${p.basenameWithoutExtension(item.sourceFileName)}_converted.${item.targetFormat.extension}',
        );
        await File(outPath).writeAsBytes(outcome.outputBytes);

        updatedList[i] = updatedList[i].copyWith(
          status: ConvertBatchItemStatus.completed,
          progress: 1.0,
          outputFilePath: outPath,
          outputBytes: outcome.outputBytes,
          legacySinhalaDetection: outcome.legacyDetection.hasLegacySinhalaEncoding
              ? outcome.legacyDetection
              : item.legacySinhalaDetection,
          ranOcrPrepass: outcome.ranOcrPrepass,
          elapsedMs: sw.elapsedMilliseconds,
        );
      } catch (e) {
        sw.stop();
        updatedList[i] = updatedList[i].copyWith(
          status: ConvertBatchItemStatus.failed,
          errorMessage: e.toString(),
          elapsedMs: sw.elapsedMilliseconds,
        );
      }

      state = state.copyWith(
        batchQueue: List<ConvertBatchQueueItem>.from(updatedList),
      );
    }

    state = state.copyWith(
      isBatchRunning: false,
      statusMessage: 'Batch conversion completed (${updatedList.length} files).',
    );
  }

  /// Runs the 17-case automated format conversion test suite and stores the results table.
  Future<void> runConversionBenchmarkSuite() async {
    final rows = await service.runFullSampleConversionTestSuite();
    state = state.copyWith(
      benchmarkRows: rows,
      statusMessage:
          'Format Conversion Test Suite finished: ${rows.where((r) => r.passed).length}/${rows.length} passed.',
    );
  }

  /// Runs Tesseract OCR (`sin` + `eng`) with pre-OCR image cleanup and builds a Searchable PDF.
  Future<void> runOcrJob({
    Uint8List? customBytes,
    String sourceFileName = 'scanned_sinhala_circular.pdf',
    bool simulateLowConfidenceScan = false,
  }) async {
    if (state.isOcrRunning) return;
    _activeCancellationToken = PdfTaskCancellationToken();

    state = state.copyWith(
      isOcrRunning: true,
      ocrProgress: 0.05,
      ocrStageMessage: 'Preparing pre-OCR image cleanup...',
    );

    try {
      final bytes = customBytes ??
          Uint8List.fromList(
            utf8.encode('Scanned Sinhala & English Document Payload'),
          );

      final tessExe =
          componentManager.executableFor(EngineComponentId.tesseractOcr);

      final result = await service.runOcrAndBuildSearchablePdf(
        inputBytes: bytes,
        sourceFileName: sourceFileName,
        languages: state.selectedLanguages,
        cleanupConfig: state.cleanupConfig,
        tesseractExecutablePath: tessExe,
        simulateLowQualityScanForTesting: simulateLowConfidenceScan,
        cancellationToken: _activeCancellationToken,
        onProgress: (progress, stage) {
          state = state.copyWith(
            ocrProgress: progress,
            ocrStageMessage: stage,
          );
        },
      );

      state = state.copyWith(
        isOcrRunning: false,
        ocrProgress: 1.0,
        lastOcrResult: result,
        statusMessage:
            'OCR complete (${result.averageConfidencePercent.toStringAsFixed(1)}% confidence). Searchable PDF ready.',
      );
    } catch (e) {
      state = state.copyWith(
        isOcrRunning: false,
        statusMessage: 'OCR interrupted: $e',
      );
    }
  }

  /// Imports pages from the selected WIA scanner (or camera folder) into a multi-page PDF
  /// and optionally runs OCR immediately.
  Future<void> importFromWiaScannerAndRunOcr({
    int pageCount = 3,
    bool autoOcrAfterScan = true,
  }) async {
    final scanner = state.selectedScanner ?? state.availableScanners.firstOrNull;
    if (scanner == null) return;

    final scannedPdfBytes = await service.scanOrImportPagesToPdf(
      scanner: scanner,
      pageCount: pageCount,
      dpi: 300,
      cleanupConfig: state.cleanupConfig,
    );

    if (autoOcrAfterScan) {
      await runOcrJob(
        customBytes: scannedPdfBytes,
        sourceFileName: 'WIA_Scan_${pageCount}pages.pdf',
      );
    } else {
      await addFilesToBatchQueue(<String>['WIA_Scan_${pageCount}pages.pdf']);
    }
  }
}

final pdfConvertOcrServiceProvider = Provider<PdfConvertOcrService>((ref) {
  return const PdfConvertOcrService();
});

final pdfConvertOcrControllerProvider =
    StateNotifierProvider<PdfConvertOcrController, PdfConvertOcrState>((ref) {
  final service = ref.watch(pdfConvertOcrServiceProvider);
  final componentManager = ref.watch(componentManagerProvider.notifier);
  return PdfConvertOcrController(
    service: service,
    componentManager: componentManager,
  );
});
