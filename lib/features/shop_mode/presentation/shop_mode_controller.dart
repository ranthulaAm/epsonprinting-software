import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/file/i_file_service.dart';
import '../../../services/file/local_file_service.dart';
import '../../../services/printer/models/printer_models.dart';
import '../../presets/data/presets_persistence.dart';
import '../../printers/presentation/printers_controller.dart';
import '../../queue/presentation/job_queue_controller.dart';
import '../../workspace/domain/print_queue_item.dart';
import '../data/shop_mode_persistence_and_services.dart';
import '../domain/shop_mode_models.dart';

class ShopModeState {
  final List<PrintQueueItem> quickPrintFiles;
  final String selectedPresetId;
  final String? manualOverridePrinterName;
  final double quickPrintDiscountAmount;
  final double quickPrintDiscountPercent;
  final ShopCustomerJob? lastDispatchedCustomerJob;
  final List<ShopCustomerJob> customerJobs;
  final String barcodeOrJobSearchQuery;
  final CustomerJobStatus? statusFilter;
  final List<ShopPriceRule> priceRules;
  final ShopSupplyCostConfig supplyCostConfig;
  final ShopPrinterRoutingRules routingRules;
  final CustomerDropFoldersConfig customerDropFoldersConfig;
  final DateTime selectedReportDate;
  final Set<String> processedDropFolderFiles;
  final bool isBusy;
  final String? statusBannerMessage;

  const ShopModeState({
    this.quickPrintFiles = const [],
    this.selectedPresetId = 'builtin_duplex_bw_draft',
    this.manualOverridePrinterName,
    this.quickPrintDiscountAmount = 0.0,
    this.quickPrintDiscountPercent = 0.0,
    this.lastDispatchedCustomerJob,
    this.customerJobs = const [],
    this.barcodeOrJobSearchQuery = '',
    this.statusFilter,
    this.priceRules = ShopPriceRule.defaultRulesLkr,
    this.supplyCostConfig = const ShopSupplyCostConfig(),
    this.routingRules = const ShopPrinterRoutingRules(),
    this.customerDropFoldersConfig = const CustomerDropFoldersConfig(),
    required this.selectedReportDate,
    this.processedDropFolderFiles = const {},
    this.isBusy = false,
    this.statusBannerMessage,
  });

  List<ShopCustomerJob> get filteredCustomerJobs {
    final q = barcodeOrJobSearchQuery.trim().toLowerCase();
    return customerJobs.where((job) {
      if (statusFilter != null && job.status != statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return job.jobNumberCode.toLowerCase().contains(q) ||
          job.customerNameOrPhone.toLowerCase().contains(q) ||
          job.notes.toLowerCase().contains(q) ||
          job.files.any((f) => f.fileName.toLowerCase().contains(q));
    }).toList();
  }

  ShopModeState copyWith({
    List<PrintQueueItem>? quickPrintFiles,
    String? selectedPresetId,
    String? manualOverridePrinterName,
    bool clearManualOverridePrinter = false,
    double? quickPrintDiscountAmount,
    double? quickPrintDiscountPercent,
    ShopCustomerJob? lastDispatchedCustomerJob,
    List<ShopCustomerJob>? customerJobs,
    String? barcodeOrJobSearchQuery,
    CustomerJobStatus? statusFilter,
    bool clearStatusFilter = false,
    List<ShopPriceRule>? priceRules,
    ShopSupplyCostConfig? supplyCostConfig,
    ShopPrinterRoutingRules? routingRules,
    CustomerDropFoldersConfig? customerDropFoldersConfig,
    DateTime? selectedReportDate,
    Set<String>? processedDropFolderFiles,
    bool? isBusy,
    String? statusBannerMessage,
    bool clearBanner = false,
  }) {
    return ShopModeState(
      quickPrintFiles: quickPrintFiles ?? this.quickPrintFiles,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      manualOverridePrinterName: clearManualOverridePrinter
          ? null
          : (manualOverridePrinterName ?? this.manualOverridePrinterName),
      quickPrintDiscountAmount:
          quickPrintDiscountAmount ?? this.quickPrintDiscountAmount,
      quickPrintDiscountPercent:
          quickPrintDiscountPercent ?? this.quickPrintDiscountPercent,
      lastDispatchedCustomerJob:
          lastDispatchedCustomerJob ?? this.lastDispatchedCustomerJob,
      customerJobs: customerJobs ?? this.customerJobs,
      barcodeOrJobSearchQuery:
          barcodeOrJobSearchQuery ?? this.barcodeOrJobSearchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      priceRules: priceRules ?? this.priceRules,
      supplyCostConfig: supplyCostConfig ?? this.supplyCostConfig,
      routingRules: routingRules ?? this.routingRules,
      customerDropFoldersConfig:
          customerDropFoldersConfig ?? this.customerDropFoldersConfig,
      selectedReportDate: selectedReportDate ?? this.selectedReportDate,
      processedDropFolderFiles:
          processedDropFolderFiles ?? this.processedDropFolderFiles,
      isBusy: isBusy ?? this.isBusy,
      statusBannerMessage:
          clearBanner ? null : (statusBannerMessage ?? this.statusBannerMessage),
    );
  }
}

final shopModeControllerProvider =
    StateNotifierProvider<ShopModeController, ShopModeState>((ref) {
  final persistence = ref.watch(shopModePersistenceProvider);
  final fileService = ref.watch(fileServiceProvider);
  final controller = ShopModeController(
    persistence: persistence,
    fileService: fileService,
    readPresets: () => ref.read(presetsControllerProvider),
    readAvailablePrinters: () => ref.read(printersControllerProvider).printers,
    enqueuePrintBatch: ({
      required List<PrintQueueItem> items,
      required String targetPrinter,
    }) =>
        ref.read(jobQueueControllerProvider.notifier).enqueueBatch(
              items: items,
              primaryPrinterName: targetPrinter,
            ),
  );
  controller.initialize();
  return controller;
});

class ShopModeController extends StateNotifier<ShopModeState> {
  final ShopModePersistence _persistence;
  final IFileService _fileService;
  final List<PrintPreset> Function() _readPresets;
  final List<PrinterDevice> Function() _readAvailablePrinters;
  final Future<void> Function({
    required List<PrintQueueItem> items,
    required String targetPrinter,
  }) _enqueuePrintBatch;

  final ShopPricingAndReceiptService pricingService =
      const ShopPricingAndReceiptService();
  static const _uuid = Uuid();
  StreamSubscription<FileSystemEvent>? _customerDropWatcherSub;

  ShopModeController({
    required ShopModePersistence persistence,
    required IFileService fileService,
    required List<PrintPreset> Function() readPresets,
    required List<PrinterDevice> Function() readAvailablePrinters,
    required Future<void> Function({
      required List<PrintQueueItem> items,
      required String targetPrinter,
    }) enqueuePrintBatch,
  })  : _persistence = persistence,
        _fileService = fileService,
        _readPresets = readPresets,
        _readAvailablePrinters = readAvailablePrinters,
        _enqueuePrintBatch = enqueuePrintBatch,
        super(ShopModeState(selectedReportDate: DateTime.now()));

  Future<void> initialize() async {
    await _persistence.init();
    final jobs = await _persistence.loadCustomerJobs();
    final priceRules = await _persistence.loadPriceRules();
    final supplyCost = await _persistence.loadSupplyCostConfig();
    final routingRules = await _persistence.loadRoutingRules();
    final dropFolders = await _persistence.loadCustomerDropFoldersConfig();

    state = state.copyWith(
      customerJobs: jobs,
      lastDispatchedCustomerJob: jobs.isNotEmpty ? jobs.first : null,
      priceRules: priceRules,
      supplyCostConfig: supplyCost,
      routingRules: routingRules,
      customerDropFoldersConfig: dropFolders,
    );

    if (dropFolders.enabled &&
        dropFolders.rootDropDirectoryPath.trim().isNotEmpty) {
      await _startWatchingCustomerDropFolders(dropFolders.rootDropDirectoryPath);
    }
  }

  // ===========================================================================
  // 1. Quick Print (3-Step Counter Flow & 1-Click Reprint Last Job)
  // ===========================================================================

  Future<void> pickAndAddQuickPrintFiles() async {
    final paths = await _fileService.pickFiles();
    if (paths.isEmpty) return;
    await addFilesToQuickPrint(paths);
  }

  Future<void> addFilesToQuickPrint(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    state = state.copyWith(isBusy: true, clearBanner: true);
    try {
      final ingest =
          await _fileService.processFiles(filePaths, languageCode: 'en');
      final activePresetSettings = _resolvePresetSettings(state.selectedPresetId);
      final configured = ingest.addedItems
          .map((item) => item.copyWith(settings: activePresetSettings))
          .toList();

      state = state.copyWith(
        quickPrintFiles: [...state.quickPrintFiles, ...configured],
        isBusy: false,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        statusBannerMessage: 'Could not add files: $e',
      );
    }
  }

  void selectQuickPrintPreset(String presetId) {
    final settings = _resolvePresetSettings(presetId);
    final updatedFiles = state.quickPrintFiles
        .map((f) => f.copyWith(settings: settings))
        .toList();
    state = state.copyWith(
      selectedPresetId: presetId,
      quickPrintFiles: updatedFiles,
    );
  }

  void setQuickPrintManualPrinterOverride(String? printerSystemName) {
    if (printerSystemName == null || printerSystemName.isEmpty) {
      state = state.copyWith(clearManualOverridePrinter: true);
    } else {
      state = state.copyWith(manualOverridePrinterName: printerSystemName);
    }
  }

  void updateQuickPrintFileSettings(String itemId, FilePrintSettings settings) {
    final updated = state.quickPrintFiles.map((item) {
      if (item.id == itemId) return item.copyWith(settings: settings);
      return item;
    }).toList();
    state = state.copyWith(quickPrintFiles: updated);
  }

  void removeQuickPrintFile(String itemId) {
    state = state.copyWith(
      quickPrintFiles:
          state.quickPrintFiles.where((f) => f.id != itemId).toList(),
    );
  }

  void clearQuickPrintFiles() {
    state = state.copyWith(
      quickPrintFiles: const [],
      quickPrintDiscountAmount: 0.0,
      quickPrintDiscountPercent: 0.0,
    );
  }

  void setQuickPrintDiscount({double? flatAmount, double? percent}) {
    state = state.copyWith(
      quickPrintDiscountAmount: flatAmount ?? state.quickPrintDiscountAmount,
      quickPrintDiscountPercent: percent ?? state.quickPrintDiscountPercent,
    );
  }

  ResolvedPrinterRoute resolveCurrentQuickPrintRoute() {
    return pricingService.resolvePrinterForJob(
      files: state.quickPrintFiles,
      rules: state.routingRules,
      availablePrinters: _readAvailablePrinters(),
      manualOverridePrinterName: state.manualOverridePrinterName,
    );
  }

  ShopJobPriceAndCostEstimate calculateCurrentQuickPrintEstimate() {
    return pricingService.calculateJobEstimate(
      files: state.quickPrintFiles,
      priceRules: state.priceRules,
      costConfig: state.supplyCostConfig,
      flatDiscountAmount: state.quickPrintDiscountAmount,
      discountPercent: state.quickPrintDiscountPercent,
    );
  }

  /// Dispatches the Quick Print files immediately AND records them as a
  /// Customer Job so the counter operator can print a receipt, track status,
  /// or click "Reprint Last Job" in 1 click.
  Future<ShopCustomerJob?> printQuickJobNow({
    String customerNameOrNumber = 'Walk-in Customer',
    String notes = '',
  }) async {
    if (state.quickPrintFiles.isEmpty) return null;

    final route = resolveCurrentQuickPrintRoute();
    final seq = await _persistence.nextJobSequenceNumber();
    final jobCode = 'JOB-$seq';
    final cleanCustomer = customerNameOrNumber.trim().isEmpty
        ? 'Walk-in #$seq'
        : customerNameOrNumber.trim();

    final createdJob = ShopCustomerJob(
      id: _uuid.v4(),
      jobNumberCode: jobCode,
      customerNameOrPhone: cleanCustomer,
      notes: notes.trim(),
      status: CustomerJobStatus.printing,
      files: List<PrintQueueItem>.from(state.quickPrintFiles),
      assignedPrinterSystemName: route.targetPrinterSystemName,
      manualPrinterOverride: route.isManualOverride,
      discountAmount: state.quickPrintDiscountAmount,
      discountPercent: state.quickPrintDiscountPercent,
      createdAt: DateTime.now(),
    );

    await _enqueuePrintBatch(
      items: createdJob.files,
      targetPrinter: createdJob.assignedPrinterSystemName,
    );

    final completedJob = createdJob.copyWith(
      status: CustomerJobStatus.done,
      completedAt: DateTime.now(),
    );
    await _persistence.saveCustomerJob(completedJob);

    final allJobs = await _persistence.loadCustomerJobs();
    state = state.copyWith(
      customerJobs: allJobs,
      lastDispatchedCustomerJob: completedJob,
      quickPrintFiles: const [],
      quickPrintDiscountAmount: 0.0,
      quickPrintDiscountPercent: 0.0,
      statusBannerMessage:
          'Printed $jobCode ($cleanCustomer) on ${completedJob.assignedPrinterSystemName}',
    );
    return completedJob;
  }

  /// One-click reprint of the last dispatched job.
  Future<bool> reprintLastJob() async {
    final last = state.lastDispatchedCustomerJob ??
        (state.customerJobs.isNotEmpty ? state.customerJobs.first : null);
    if (last == null || last.files.isEmpty) return false;

    await _enqueuePrintBatch(
      items: last.files,
      targetPrinter: last.assignedPrinterSystemName,
    );
    state = state.copyWith(
      statusBannerMessage:
          'Reprinted ${last.jobNumberCode} (${last.customerNameOrPhone}) on ${last.assignedPrinterSystemName}',
    );
    return true;
  }

  // ===========================================================================
  // 2. Customer Jobs Queue, Status Transitions & Barcode Lookup
  // ===========================================================================

  /// Creates a Customer Job in `Waiting` status without printing yet (e.g., when
  /// a customer drops off a USB drive or sends files ahead of time).
  Future<ShopCustomerJob?> saveQuickQueueAsWaitingCustomerJob({
    required String customerNameOrPhone,
    String notes = '',
  }) async {
    if (state.quickPrintFiles.isEmpty) return null;

    final route = resolveCurrentQuickPrintRoute();
    final seq = await _persistence.nextJobSequenceNumber();
    final jobCode = 'JOB-$seq';
    final cleanCustomer = customerNameOrPhone.trim().isEmpty
        ? 'Customer #$seq'
        : customerNameOrPhone.trim();

    final job = ShopCustomerJob(
      id: _uuid.v4(),
      jobNumberCode: jobCode,
      customerNameOrPhone: cleanCustomer,
      notes: notes.trim(),
      status: CustomerJobStatus.waiting,
      files: List<PrintQueueItem>.from(state.quickPrintFiles),
      assignedPrinterSystemName: route.targetPrinterSystemName,
      manualPrinterOverride: route.isManualOverride,
      discountAmount: state.quickPrintDiscountAmount,
      discountPercent: state.quickPrintDiscountPercent,
      createdAt: DateTime.now(),
    );

    await _persistence.saveCustomerJob(job);
    final allJobs = await _persistence.loadCustomerJobs();
    state = state.copyWith(
      customerJobs: allJobs,
      quickPrintFiles: const [],
      statusBannerMessage: 'Saved $jobCode ($cleanCustomer) as Waiting.',
    );
    return job;
  }

  Future<void> updateCustomerJobStatus(
    String jobId,
    CustomerJobStatus newStatus,
  ) async {
    final target = state.customerJobs.where((j) => j.id == jobId).firstOrNull;
    if (target == null) return;

    if (newStatus == CustomerJobStatus.printing) {
      await _enqueuePrintBatch(
        items: target.files,
        targetPrinter: target.assignedPrinterSystemName,
      );
    }

    final updated = target.copyWith(
      status: newStatus,
      completedAt: newStatus == CustomerJobStatus.done
          ? DateTime.now()
          : target.completedAt,
      pickedUpAt: newStatus == CustomerJobStatus.pickedUp
          ? DateTime.now()
          : target.pickedUpAt,
    );

    await _persistence.saveCustomerJob(updated);
    final allJobs = await _persistence.loadCustomerJobs();
    state = state.copyWith(
      customerJobs: allJobs,
      lastDispatchedCustomerJob: newStatus == CustomerJobStatus.printing ||
              newStatus == CustomerJobStatus.done
          ? updated
          : state.lastDispatchedCustomerJob,
    );
  }

  Future<void> reprintCustomerJob(ShopCustomerJob job) async {
    await _enqueuePrintBatch(
      items: job.files,
      targetPrinter: job.assignedPrinterSystemName,
    );
    state = state.copyWith(
      lastDispatchedCustomerJob: job,
      statusBannerMessage:
          'Reprinted ${job.jobNumberCode} (${job.customerNameOrPhone})',
    );
  }

  Future<void> deleteCustomerJob(String jobId) async {
    await _persistence.deleteCustomerJob(jobId);
    final allJobs = await _persistence.loadCustomerJobs();
    state = state.copyWith(customerJobs: allJobs);
  }

  void setBarcodeOrJobSearchQuery(String query) {
    state = state.copyWith(barcodeOrJobSearchQuery: query);
  }

  void setCustomerJobStatusFilter(CustomerJobStatus? status) {
    if (status == null) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: status);
    }
  }

  // ===========================================================================
  // 3. Price Calculator, Cost Tracking & Printer Routing Rules
  // ===========================================================================

  Future<void> updatePriceRule(ShopPriceRule updatedRule) async {
    final exists = state.priceRules.any((r) => r.id == updatedRule.id);
    final nextRules = exists
        ? state.priceRules
            .map((r) => r.id == updatedRule.id ? updatedRule : r)
            .toList()
        : [...state.priceRules, updatedRule];
    await _persistence.savePriceRules(nextRules);
    state = state.copyWith(priceRules: nextRules);
  }

  Future<void> deletePriceRule(String ruleId) async {
    final nextRules =
        state.priceRules.where((r) => r.id != ruleId).toList();
    await _persistence.savePriceRules(nextRules);
    state = state.copyWith(priceRules: nextRules);
  }

  Future<void> updateSupplyCostConfig(ShopSupplyCostConfig config) async {
    await _persistence.saveSupplyCostConfig(config);
    state = state.copyWith(supplyCostConfig: config);
  }

  Future<void> updateRoutingRules(ShopPrinterRoutingRules rules) async {
    await _persistence.saveRoutingRules(rules);
    state = state.copyWith(routingRules: rules);
  }

  void setReportDate(DateTime date) {
    state = state.copyWith(selectedReportDate: date);
  }

  ShopDailyReportSummary buildCurrentDailyReport() {
    return pricingService.buildDailyReport(
      targetDate: state.selectedReportDate,
      allJobs: state.customerJobs,
      priceRules: state.priceRules,
      costConfig: state.supplyCostConfig,
    );
  }

  // ===========================================================================
  // 4. Customer Drop Folders Intake Watcher
  // ===========================================================================

  Future<void> updateCustomerDropFoldersConfig(
      CustomerDropFoldersConfig config) async {
    await _persistence.saveCustomerDropFoldersConfig(config);
    state = state.copyWith(customerDropFoldersConfig: config);

    await _customerDropWatcherSub?.cancel();
    _customerDropWatcherSub = null;

    if (config.enabled && config.rootDropDirectoryPath.trim().isNotEmpty) {
      await _startWatchingCustomerDropFolders(config.rootDropDirectoryPath);
    }
  }

  Future<void> _startWatchingCustomerDropFolders(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return;

    try {
      await scanCustomerDropFoldersNow();
      _customerDropWatcherSub = rootDir
          .watch(events: FileSystemEvent.create, recursive: true)
          .listen((event) {
        if (!event.isDirectory) {
          Future<void>.delayed(
            const Duration(milliseconds: 400),
            scanCustomerDropFoldersNow,
          );
        }
      });
    } catch (_) {}
  }

  /// Scans `rootDropDirectoryPath/<CustomerNameOrNumber>/*` and automatically
  /// creates or appends to a `Waiting` customer job for each customer subfolder.
  Future<int> scanCustomerDropFoldersNow() async {
    final cfg = state.customerDropFoldersConfig;
    if (cfg.rootDropDirectoryPath.trim().isEmpty) return 0;

    final rootDir = Directory(cfg.rootDropDirectoryPath);
    if (!await rootDir.exists()) return 0;

    int importedJobsCount = 0;
    final presetSettings = _resolvePresetSettings(cfg.defaultPresetId);
    final newProcessed = Set<String>.from(state.processedDropFolderFiles);

    await for (final entity in rootDir.list(followLinks: false)) {
      if (entity is Directory) {
        final customerFolderName = p.basename(entity.path);
        final candidateFiles = <String>[];

        await for (final child in entity.list(followLinks: false)) {
          if (child is File) {
            final norm = p.normalize(child.path);
            final ext = p.extension(norm).replaceFirst('.', '').toLowerCase();
            if (!newProcessed.contains(norm) &&
                AppConstants.supportedExtensions.contains(ext)) {
              candidateFiles.add(norm);
              newProcessed.add(norm);
            }
          }
        }

        if (candidateFiles.isNotEmpty) {
          final ingest = await _fileService.processFiles(
            candidateFiles,
            languageCode: 'en',
          );
          if (ingest.addedItems.isNotEmpty) {
            final configured = ingest.addedItems
                .map((i) => i.copyWith(settings: presetSettings))
                .toList();
            final route = pricingService.resolvePrinterForJob(
              files: configured,
              rules: state.routingRules,
              availablePrinters: _readAvailablePrinters(),
            );
            final seq = await _persistence.nextJobSequenceNumber();
            final job = ShopCustomerJob(
              id: _uuid.v4(),
              jobNumberCode: 'JOB-$seq',
              customerNameOrPhone: customerFolderName,
              notes: 'Auto-imported from Customer Drop Folder',
              status: CustomerJobStatus.waiting,
              files: configured,
              assignedPrinterSystemName: route.targetPrinterSystemName,
              createdAt: DateTime.now(),
            );
            await _persistence.saveCustomerJob(job);
            importedJobsCount++;
          }
        }
      }
    }

    if (importedJobsCount > 0) {
      final allJobs = await _persistence.loadCustomerJobs();
      state = state.copyWith(
        customerJobs: allJobs,
        processedDropFolderFiles: newProcessed,
        statusBannerMessage:
            'Imported $importedJobsCount customer job(s) from drop folders.',
      );
    } else {
      state = state.copyWith(processedDropFolderFiles: newProcessed);
    }

    return importedJobsCount;
  }

  FilePrintSettings _resolvePresetSettings(String presetId) {
    final presets = _readPresets();
    final matched = presets.where((p) => p.id == presetId).firstOrNull;
    return matched?.settings ??
        SqlitePresetsPersistence.builtInPresets.first.settings;
  }

  @override
  void dispose() {
    _customerDropWatcherSub?.cancel();
    super.dispose();
  }
}
