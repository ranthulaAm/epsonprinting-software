import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/file/i_file_service.dart';
import '../../../services/file/local_file_service.dart';
import '../../../services/notifications/desktop_notification_service.dart';
import '../../../services/printer/i_printer_service.dart';
import '../../../services/printer/models/printer_models.dart';
import '../../../services/printer/win32_printer_service.dart';
import '../../presets/data/presets_persistence.dart';
import '../../preview/domain/print_layout_engine.dart';
import '../../printers/presentation/printers_controller.dart';
import '../../workspace/domain/print_queue_item.dart';
import '../data/job_history_persistence.dart';
import '../domain/print_job_models.dart';

class JobQueueState {
  const JobQueueState({
    this.activeJobs = const [],
    this.historyJobs = const [],
    this.spoolerJobsByPrinter = const {},
    this.routingMode = MultiPrinterRoutingMode.singlePrinter,
    this.selectedMultiPrinterNames = const [],
    this.isBatchPaused = false,
    this.isProcessingQueue = false,
    this.historySearchQuery = '',
    this.retentionPolicy = HistoryRetentionPolicy.keepAll,
    this.hotFolderConfig = const HotFolderConfig(),
    this.hotFolderProcessedFiles = const {},
    this.latestNotification,
  });

  final List<PrintHelperJob> activeJobs;
  final List<PrintHelperJob> historyJobs;
  final Map<String, List<SpoolerJobInfo>> spoolerJobsByPrinter;
  final MultiPrinterRoutingMode routingMode;
  final List<String> selectedMultiPrinterNames;
  final bool isBatchPaused;
  final bool isProcessingQueue;
  final String historySearchQuery;
  final HistoryRetentionPolicy retentionPolicy;
  final HotFolderConfig hotFolderConfig;
  final Set<String> hotFolderProcessedFiles;
  final AppDesktopNotification? latestNotification;

  List<PrintHelperJob> get jobsAwaitingFallback => activeJobs
      .where((j) => j.status == PrintJobStatus.awaitingFallback)
      .toList();

  int get runningOrQueuedCount => activeJobs
      .where(
        (j) =>
            j.status == PrintJobStatus.queued ||
            j.status == PrintJobStatus.spooling ||
            j.status == PrintJobStatus.printing ||
            j.status == PrintJobStatus.awaitingFallback,
      )
      .length;

  JobQueueState copyWith({
    List<PrintHelperJob>? activeJobs,
    List<PrintHelperJob>? historyJobs,
    Map<String, List<SpoolerJobInfo>>? spoolerJobsByPrinter,
    MultiPrinterRoutingMode? routingMode,
    List<String>? selectedMultiPrinterNames,
    bool? isBatchPaused,
    bool? isProcessingQueue,
    String? historySearchQuery,
    HistoryRetentionPolicy? retentionPolicy,
    HotFolderConfig? hotFolderConfig,
    Set<String>? hotFolderProcessedFiles,
    AppDesktopNotification? latestNotification,
    bool clearLatestNotification = false,
  }) {
    return JobQueueState(
      activeJobs: activeJobs ?? this.activeJobs,
      historyJobs: historyJobs ?? this.historyJobs,
      spoolerJobsByPrinter: spoolerJobsByPrinter ?? this.spoolerJobsByPrinter,
      routingMode: routingMode ?? this.routingMode,
      selectedMultiPrinterNames:
          selectedMultiPrinterNames ?? this.selectedMultiPrinterNames,
      isBatchPaused: isBatchPaused ?? this.isBatchPaused,
      isProcessingQueue: isProcessingQueue ?? this.isProcessingQueue,
      historySearchQuery: historySearchQuery ?? this.historySearchQuery,
      retentionPolicy: retentionPolicy ?? this.retentionPolicy,
      hotFolderConfig: hotFolderConfig ?? this.hotFolderConfig,
      hotFolderProcessedFiles:
          hotFolderProcessedFiles ?? this.hotFolderProcessedFiles,
      latestNotification: clearLatestNotification
          ? null
          : (latestNotification ?? this.latestNotification),
    );
  }
}

final jobQueueControllerProvider =
    StateNotifierProvider<JobQueueController, JobQueueState>((ref) {
  final printerService = ref.watch(printerServiceProvider);
  final historyPersistence = ref.watch(jobHistoryPersistenceProvider);
  final notificationService = ref.watch(desktopNotificationServiceProvider);
  final fileService = ref.watch(fileServiceProvider);
  final presetsPersistence = ref.watch(presetsPersistenceProvider);

  final controller = JobQueueController(
    printerService: printerService,
    historyPersistence: historyPersistence,
    notificationService: notificationService,
    fileService: fileService,
    presetsPersistence: presetsPersistence,
    readAvailablePrinters: () => ref.read(printersControllerProvider).printers,
  );
  controller.initialize();
  return controller;
});

class JobQueueController extends StateNotifier<JobQueueState> {
  JobQueueController({
    required IPrinterService printerService,
    required IJobHistoryPersistence historyPersistence,
    required IDesktopNotificationService notificationService,
    required IFileService fileService,
    required IPresetsPersistence presetsPersistence,
    required List<PrinterDevice> Function() readAvailablePrinters,
  })  : _printerService = printerService,
        _historyPersistence = historyPersistence,
        _notificationService = notificationService,
        _fileService = fileService,
        _presetsPersistence = presetsPersistence,
        _readAvailablePrinters = readAvailablePrinters,
        super(const JobQueueState());

  final IPrinterService _printerService;
  final IJobHistoryPersistence _historyPersistence;
  final IDesktopNotificationService _notificationService;
  final IFileService _fileService;
  final IPresetsPersistence _presetsPersistence;
  final List<PrinterDevice> Function() _readAvailablePrinters;

  static const _uuid = Uuid();
  StreamSubscription<FileSystemEvent>? _hotFolderSub;

  Future<void> initialize() async {
    await _historyPersistence.init();
    final policy = await _historyPersistence.loadRetentionPolicy();
    await _historyPersistence.applyRetentionPolicy(policy);
    final history = await _historyPersistence.loadHistory();
    final hotConfig = await _historyPersistence.loadHotFolderConfig();

    state = state.copyWith(
      retentionPolicy: policy,
      historyJobs: history,
      hotFolderConfig: hotConfig,
    );

    if (hotConfig.enabled && hotConfig.folderPath.isNotEmpty) {
      await _startWatchingHotFolder(hotConfig.folderPath);
    }
  }

  void setRoutingMode(MultiPrinterRoutingMode mode) {
    state = state.copyWith(routingMode: mode);
  }

  void toggleMultiPrinterSelection(String systemName) {
    final current = List<String>.from(state.selectedMultiPrinterNames);
    if (current.contains(systemName)) {
      current.remove(systemName);
    } else {
      current.add(systemName);
    }
    state = state.copyWith(selectedMultiPrinterNames: current);
  }

  void dismissLatestNotification() {
    state = state.copyWith(clearLatestNotification: true);
  }

  /// Enqueues a batch of `PrintQueueItem`s using the selected routing mode:
  /// - `singlePrinter`: sends all items to [primaryPrinterName]
  /// - `broadcastAll`: sends every item to all [targetPrinterNames] simultaneously
  /// - `loadBalanceSplit`: splits the batch across [targetPrinterNames] balancing page load
  Future<List<PrintHelperJob>> enqueueBatch({
    required List<PrintQueueItem> items,
    required String primaryPrinterName,
    MultiPrinterRoutingMode? overrideMode,
    List<String>? overrideMultiPrinters,
  }) async {
    if (items.isEmpty) return const [];

    final mode = overrideMode ?? state.routingMode;
    final availablePrinters = _readAvailablePrinters();
    final multiTargets =
        (overrideMultiPrinters ?? state.selectedMultiPrinterNames)
            .where((name) => name.trim().isNotEmpty)
            .toList();

    final effectiveTargets =
        (mode != MultiPrinterRoutingMode.singlePrinter &&
                multiTargets.isNotEmpty)
            ? multiTargets
            : [primaryPrinterName];

    final batchId = _uuid.v4();
    final createdJobs = <PrintHelperJob>[];

    String displayNameFor(String sysName) {
      final match = availablePrinters
          .where((p) => p.systemName == sysName)
          .firstOrNull;
      return match?.displayName ?? sysName;
    }

    if (mode == MultiPrinterRoutingMode.singlePrinter) {
      for (final item in items) {
        createdJobs.add(
          _createJobFromItem(
            item: item,
            batchId: batchId,
            printerSysName: primaryPrinterName,
            printerDisplayName: displayNameFor(primaryPrinterName),
          ),
        );
      }
    } else if (mode == MultiPrinterRoutingMode.broadcastAll) {
      // Broadcast: each file is sent to every selected printer
      for (final item in items) {
        for (final targetSysName in effectiveTargets) {
          createdJobs.add(
            _createJobFromItem(
              item: item,
              batchId: batchId,
              printerSysName: targetSysName,
              printerDisplayName: displayNameFor(targetSysName),
            ),
          );
        }
      }
    } else if (mode == MultiPrinterRoutingMode.loadBalanceSplit) {
      // Page-weighted Load Balancing: assign each file in the batch to the
      // printer with the lowest cumulative assigned page count
      final assignedPagesByPrinter = <String, int>{
        for (final pName in effectiveTargets) pName: 0,
      };

      for (final item in items) {
        final chosenPrinter = assignedPagesByPrinter.entries
            .reduce((a, b) => a.value <= b.value ? a : b)
            .key;
        final itemTotalPages = item.pageCount * item.settings.copies;
        assignedPagesByPrinter[chosenPrinter] =
            (assignedPagesByPrinter[chosenPrinter] ?? 0) + itemTotalPages;

        createdJobs.add(
          _createJobFromItem(
            item: item,
            batchId: batchId,
            printerSysName: chosenPrinter,
            printerDisplayName: displayNameFor(chosenPrinter),
          ),
        );
      }
    }

    state = state.copyWith(
      activeJobs: [...state.activeJobs, ...createdJobs],
    );

    await _processQueueLoop();
    return createdJobs;
  }

  PrintHelperJob _createJobFromItem({
    required PrintQueueItem item,
    required String batchId,
    required String printerSysName,
    required String printerDisplayName,
  }) {
    return PrintHelperJob(
      id: _uuid.v4(),
      batchId: batchId,
      filePath: item.filePath,
      fileName: item.fileName,
      documentType: item.documentType,
      totalPages: item.pageCount,
      pagesPrinted: 0,
      targetPrinterSystemName: printerSysName,
      targetPrinterDisplayName: printerDisplayName,
      settings: item.settings,
      status: PrintJobStatus.queued,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _processQueueLoop() async {
    if (state.isProcessingQueue || state.isBatchPaused) return;
    state = state.copyWith(isProcessingQueue: true);

    try {
      while (!state.isBatchPaused) {
        final nextJob = state.activeJobs
            .where((j) => j.status == PrintJobStatus.queued)
            .firstOrNull;
        if (nextJob == null) break;

        await _executeSingleJob(nextJob);
      }
    } finally {
      state = state.copyWith(isProcessingQueue: false);
    }
  }

  Future<void> _executeSingleJob(PrintHelperJob job) async {
    final printers = _readAvailablePrinters();
    final targetDevice = printers
        .where((p) => p.systemName == job.targetPrinterSystemName)
        .firstOrNull;

    // 1. Pre-flight check: is the target printer known to be offline?
    if (targetDevice != null &&
        targetDevice.status == PrinterStatusType.offline) {
      await _transitionJobToOfflineFallback(job, printers);
      return;
    }

    // 2. Mark as Spooling
    _updateActiveJob(
      job.id,
      (j) => j.copyWith(
        status: PrintJobStatus.spooling,
        clearError: true,
      ),
    );

    try {
      final queueItem = PrintQueueItem(
        id: job.id,
        filePath: job.filePath,
        fileName: job.fileName,
        extension: p.extension(job.fileName).replaceFirst('.', ''),
        documentType: job.documentType,
        fileSizeBytes: 1024,
        pageCount: job.totalPages,
        addedAt: job.createdAt,
        settings: job.settings,
      );

      final composedPdfBytes = await PrintLayoutEngine.generateComposedPdfBytes(
        item: queueItem,
        settings: job.settings,
      );

      // Check if user paused or canceled while PDF was composing
      final refreshed =
          state.activeJobs.where((j) => j.id == job.id).firstOrNull;
      if (refreshed == null ||
          refreshed.status == PrintJobStatus.paused ||
          refreshed.status == PrintJobStatus.canceled) {
        return;
      }

      // 3. Submit to Printer Service (with 1 automatic retry on transient failure)
      _updateActiveJob(
        job.id,
        (j) => j.copyWith(
          status: PrintJobStatus.printing,
          pagesPrinted: (j.effectiveTotalPages / 2).ceil(),
        ),
      );

      SpoolSubmissionResult result = await _printerService.submitPrintJob(
        job: refreshed,
        composedPdfBytes: composedPdfBytes,
      );

      if (!result.isSuccess &&
          !result.isPrinterOfflineError &&
          refreshed.retryCount < 1) {
        // Automatic retry once for transient spooler hiccup
        _updateActiveJob(
          job.id,
          (j) => j.copyWith(retryCount: j.retryCount + 1),
        );
        result = await _printerService.submitPrintJob(
          job: refreshed.copyWith(retryCount: refreshed.retryCount + 1),
          composedPdfBytes: composedPdfBytes,
        );
      }

      if (result.isSuccess) {
        final completedJob = refreshed.copyWith(
          status: PrintJobStatus.completed,
          pagesPrinted: refreshed.effectiveTotalPages,
          completedAt: DateTime.now(),
          spoolerJobId: result.spoolerJobId,
          clearError: true,
          clearFallbackSuggestion: true,
        );
        _updateActiveJob(job.id, (_) => completedJob);
        await _historyPersistence.recordJobInHistory(completedJob);
        await _reloadHistory();

        final notif = await _notificationService.notify(
          title: 'Print Completed — ${completedJob.fileName}',
          body:
              'Printed ${completedJob.effectiveTotalPages} page(s) on ${completedJob.targetPrinterDisplayName}.',
        );
        state = state.copyWith(latestNotification: notif);
      } else if (result.isPrinterOfflineError) {
        await _transitionJobToOfflineFallback(refreshed, printers);
      } else {
        final failedJob = refreshed.copyWith(
          status: PrintJobStatus.failed,
          completedAt: DateTime.now(),
          errorMessage:
              result.errorMessageEn ?? 'Print job failed during spooling.',
        );
        _updateActiveJob(job.id, (_) => failedJob);
        await _historyPersistence.recordJobInHistory(failedJob);
        await _reloadHistory();

        final notif = await _notificationService.notify(
          title: 'Print Failed — ${failedJob.fileName}',
          body: failedJob.errorMessage ?? 'Check printer status and retry.',
          isError: true,
        );
        state = state.copyWith(latestNotification: notif);
      }
    } catch (e) {
      final failedJob = job.copyWith(
        status: PrintJobStatus.failed,
        completedAt: DateTime.now(),
        errorMessage: 'Unexpected print error: $e',
      );
      _updateActiveJob(job.id, (_) => failedJob);
      await _historyPersistence.recordJobInHistory(failedJob);
      await _reloadHistory();
    }
  }

  Future<void> _transitionJobToOfflineFallback(
    PrintHelperJob job,
    List<PrinterDevice> printers,
  ) async {
    final alternative = printers
        .where(
          (p) =>
              p.systemName != job.targetPrinterSystemName &&
              p.isAvailableForPrinting,
        )
        .firstOrNull;

    final waitingJob = job.copyWith(
      status: PrintJobStatus.awaitingFallback,
      fallbackSuggestedPrinter: alternative?.systemName,
      errorMessage:
          '"${job.targetPrinterDisplayName}" is offline. ${alternative != null ? 'Switch to "${alternative.displayName}"?' : 'Connect a printer and retry.'}',
    );
    _updateActiveJob(job.id, (_) => waitingJob);

    final notif = await _notificationService.notify(
      title: 'Printer Offline — Action Needed',
      body: waitingJob.errorMessage!,
      isError: true,
    );
    state = state.copyWith(latestNotification: notif);
  }

  /// Automatic Fallback Action: reroutes a job stuck in `awaitingFallback` (or `failed`)
  /// to another ready printer and immediately resumes printing.
  Future<void> rerouteJobToFallbackPrinter({
    required String jobId,
    required String newPrinterSystemName,
  }) async {
    final printers = _readAvailablePrinters();
    final match = printers
        .where((p) => p.systemName == newPrinterSystemName)
        .firstOrNull;

    _updateActiveJob(
      jobId,
      (j) => j.copyWith(
        targetPrinterSystemName: newPrinterSystemName,
        targetPrinterDisplayName: match?.displayName ?? newPrinterSystemName,
        status: PrintJobStatus.queued,
        clearError: true,
        clearFallbackSuggestion: true,
      ),
    );
    await _processQueueLoop();
  }

  Future<void> rerouteAllFallbackJobs(String newPrinterSystemName) async {
    final printers = _readAvailablePrinters();
    final match = printers
        .where((p) => p.systemName == newPrinterSystemName)
        .firstOrNull;

    final updated = state.activeJobs.map((j) {
      if (j.status == PrintJobStatus.awaitingFallback) {
        return j.copyWith(
          targetPrinterSystemName: newPrinterSystemName,
          targetPrinterDisplayName: match?.displayName ?? newPrinterSystemName,
          status: PrintJobStatus.queued,
          clearError: true,
          clearFallbackSuggestion: true,
        );
      }
      return j;
    }).toList();

    state = state.copyWith(activeJobs: updated);
    await _processQueueLoop();
  }

  void pauseJob(String jobId) {
    _updateActiveJob(
      jobId,
      (j) => j.status == PrintJobStatus.queued ||
              j.status == PrintJobStatus.awaitingFallback
          ? j.copyWith(status: PrintJobStatus.paused)
          : j,
    );
  }

  Future<void> resumeJob(String jobId) async {
    _updateActiveJob(
      jobId,
      (j) => j.status == PrintJobStatus.paused
          ? j.copyWith(status: PrintJobStatus.queued)
          : j,
    );
    await _processQueueLoop();
  }

  Future<void> cancelJob(String jobId) async {
    PrintHelperJob? canceled;
    _updateActiveJob(jobId, (j) {
      canceled = j.copyWith(
        status: PrintJobStatus.canceled,
        completedAt: DateTime.now(),
      );
      return canceled!;
    });
    if (canceled != null) {
      await _historyPersistence.recordJobInHistory(canceled!);
      await _reloadHistory();
    }
  }

  Future<void> retryJob(String jobId) async {
    _updateActiveJob(
      jobId,
      (j) => j.copyWith(
        status: PrintJobStatus.queued,
        pagesPrinted: 0,
        retryCount: j.retryCount + 1,
        clearError: true,
        clearFallbackSuggestion: true,
      ),
    );
    await _processQueueLoop();
  }

  void pauseAllBatch() {
    final updated = state.activeJobs.map((j) {
      if (j.status == PrintJobStatus.queued) {
        return j.copyWith(status: PrintJobStatus.paused);
      }
      return j;
    }).toList();
    state = state.copyWith(activeJobs: updated, isBatchPaused: true);
  }

  Future<void> resumeAllBatch() async {
    final updated = state.activeJobs.map((j) {
      if (j.status == PrintJobStatus.paused) {
        return j.copyWith(status: PrintJobStatus.queued);
      }
      return j;
    }).toList();
    state = state.copyWith(activeJobs: updated, isBatchPaused: false);
    await _processQueueLoop();
  }

  Future<void> cancelAllBatch() async {
    final updated = <PrintHelperJob>[];
    for (final j in state.activeJobs) {
      if (!j.isTerminal) {
        final c = j.copyWith(
          status: PrintJobStatus.canceled,
          completedAt: DateTime.now(),
        );
        updated.add(c);
        await _historyPersistence.recordJobInHistory(c);
      } else {
        updated.add(j);
      }
    }
    state = state.copyWith(activeJobs: updated, isBatchPaused: false);
    await _reloadHistory();
  }

  void clearCompletedActiveJobs() {
    state = state.copyWith(
      activeJobs: state.activeJobs.where((j) => !j.isTerminal).toList(),
    );
  }

  void _updateActiveJob(
    String id,
    PrintHelperJob Function(PrintHelperJob) updater,
  ) {
    final updated = state.activeJobs.map((j) {
      if (j.id == id) return updater(j);
      return j;
    }).toList();
    state = state.copyWith(activeJobs: updated);
  }

  // ===========================================================================
  // Windows Spooler Queue Live Monitor & Control
  // ===========================================================================

  Future<void> refreshWindowsSpoolerQueues() async {
    final printers = _readAvailablePrinters();
    final map = <String, List<SpoolerJobInfo>>{};
    for (final printer in printers) {
      final jobs = await _printerService.listSpoolerJobs(printer.systemName);
      map[printer.systemName] = jobs;
    }
    state = state.copyWith(spoolerJobsByPrinter: map);
  }

  Future<bool> controlWindowsSpoolerJob({
    required String printerName,
    required int jobId,
    required SpoolerJobCommand command,
  }) async {
    final ok = await _printerService.controlSpoolerJob(
      printerName: printerName,
      jobId: jobId,
      command: command,
    );
    await refreshWindowsSpoolerQueues();
    return ok;
  }

  // ===========================================================================
  // Print History Search, Reprint, CSV Export & Auto-Clear
  // ===========================================================================

  Future<void> setHistorySearchQuery(String query) async {
    state = state.copyWith(historySearchQuery: query);
    await _reloadHistory();
  }

  Future<void> _reloadHistory() async {
    final history = await _historyPersistence.loadHistory(
      searchQuery: state.historySearchQuery,
    );
    state = state.copyWith(historyJobs: history);
  }

  Future<void> reprintFromHistory(PrintHelperJob historicalJob) async {
    final reprintedJob = PrintHelperJob(
      id: _uuid.v4(),
      batchId: _uuid.v4(),
      filePath: historicalJob.filePath,
      fileName: historicalJob.fileName,
      documentType: historicalJob.documentType,
      totalPages: historicalJob.totalPages,
      pagesPrinted: 0,
      targetPrinterSystemName: historicalJob.targetPrinterSystemName,
      targetPrinterDisplayName: historicalJob.targetPrinterDisplayName,
      settings: historicalJob.settings,
      status: PrintJobStatus.queued,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      activeJobs: [...state.activeJobs, reprintedJob],
    );
    await _processQueueLoop();
  }

  Future<File> exportHistoryToCsvFile(String targetPath) {
    return _historyPersistence.exportHistoryToCsvFile(
      targetPath: targetPath,
      jobs: state.historyJobs,
    );
  }

  Future<void> updateRetentionPolicy(HistoryRetentionPolicy policy) async {
    await _historyPersistence.saveRetentionPolicy(policy);
    state = state.copyWith(retentionPolicy: policy);
    await _reloadHistory();
  }

  Future<void> clearAllHistory() async {
    await _historyPersistence.clearAllHistory();
    await _reloadHistory();
  }

  // ===========================================================================
  // Hot Folder Watcher (Auto-Print New Files with Chosen Preset)
  // ===========================================================================

  Future<void> updateHotFolderConfig(HotFolderConfig config) async {
    await _historyPersistence.saveHotFolderConfig(config);
    state = state.copyWith(hotFolderConfig: config);

    await _hotFolderSub?.cancel();
    _hotFolderSub = null;

    if (config.enabled && config.folderPath.isNotEmpty) {
      await _startWatchingHotFolder(config.folderPath);
    }
  }

  Future<void> _startWatchingHotFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return;

    // Seed existing files so we only auto-print newly dropped files during live watch
    try {
      final existing = dir
          .listSync()
          .whereType<File>()
          .map((f) => p.normalize(f.path))
          .toSet();
      state = state.copyWith(
        hotFolderProcessedFiles: {
          ...state.hotFolderProcessedFiles,
          ...existing,
        },
      );

      _hotFolderSub = dir.watch(events: FileSystemEvent.create).listen((event) {
        if (!event.isDirectory) {
          Future<void>.delayed(
            const Duration(milliseconds: 350),
            () => processHotFolderFile(event.path),
          );
        }
      });
    } catch (_) {}
  }

  /// Processes a newly detected file in the Hot Folder (can also be triggered
  /// directly by "Scan Hot Folder Now" or in integration tests).
  Future<void> processHotFolderFile(String filePath) async {
    if (!state.hotFolderConfig.enabled) return;
    final normalized = p.normalize(filePath);
    if (state.hotFolderProcessedFiles.contains(normalized)) return;

    final ext = p.extension(normalized).replaceFirst('.', '').toLowerCase();
    if (!AppConstants.supportedExtensions.contains(ext)) return;

    state = state.copyWith(
      hotFolderProcessedFiles: {
        ...state.hotFolderProcessedFiles,
        normalized,
      },
    );

    final ingest = await _fileService.processFiles(
      [normalized],
      languageCode: 'en',
    );
    if (ingest.addedItems.isEmpty) return;

    // Resolve the chosen Preset settings
    final allPresets = await _presetsPersistence.loadPresets();
    final matchedPreset = allPresets
        .where((pr) => pr.id == state.hotFolderConfig.presetId)
        .firstOrNull;
    final presetSettings =
        matchedPreset?.settings ?? const FilePrintSettings();

    final configuredItems = ingest.addedItems
        .map((item) => item.copyWith(settings: presetSettings))
        .toList();

    final printers = _readAvailablePrinters();
    final targetPrinter = state
            .hotFolderConfig.targetPrinterSystemName.isNotEmpty
        ? state.hotFolderConfig.targetPrinterSystemName
        : (printers.isNotEmpty
            ? printers.first.systemName
            : 'Microsoft Print to PDF');

    await enqueueBatch(
      items: configuredItems,
      primaryPrinterName: targetPrinter,
      overrideMode: MultiPrinterRoutingMode.singlePrinter,
    );
  }

  @override
  void dispose() {
    _hotFolderSub?.cancel();
    super.dispose();
  }
}
