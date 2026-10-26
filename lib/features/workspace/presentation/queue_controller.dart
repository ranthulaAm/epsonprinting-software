import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/diagnostics/diagnostic_logger.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/storage/queue_persistence.dart';
import '../../../services/file/i_file_service.dart';
import '../../../services/file/local_file_service.dart';
import '../domain/print_queue_item.dart';

class QueueState {
  const QueueState({
    this.items = const [],
    this.isLoading = false,
    this.isDraggingOverWindow = false,
    this.latestErrorMessages = const [],
    this.selectedPrinterName = 'Microsoft Print to PDF (Default)',
  });

  final List<PrintQueueItem> items;
  final bool isLoading;
  final bool isDraggingOverWindow;
  final List<String> latestErrorMessages;
  final String selectedPrinterName;

  int get totalFiles => items.length;
  int get totalPages => items.fold(
        0,
        (sum, item) => sum + (item.pageCount * item.settings.copies),
      );

  QueueState copyWith({
    List<PrintQueueItem>? items,
    bool? isLoading,
    bool? isDraggingOverWindow,
    List<String>? latestErrorMessages,
    String? selectedPrinterName,
  }) {
    return QueueState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isDraggingOverWindow: isDraggingOverWindow ?? this.isDraggingOverWindow,
      latestErrorMessages: latestErrorMessages ?? this.latestErrorMessages,
      selectedPrinterName: selectedPrinterName ?? this.selectedPrinterName,
    );
  }
}

final queueControllerProvider =
    StateNotifierProvider<QueueController, QueueState>((ref) {
  final persistence = ref.watch(queuePersistenceProvider);
  final fileService = ref.watch(fileServiceProvider);
  final locale = ref.watch(localeProvider);
  return QueueController(
    persistence: persistence,
    fileService: fileService,
    languageCode: locale.languageCode,
  );
});

class QueueController extends StateNotifier<QueueState> {
  QueueController({
    required IQueuePersistence persistence,
    required IFileService fileService,
    required String languageCode,
  })  : _persistence = persistence,
        _fileService = fileService,
        _languageCode = languageCode,
        super(const QueueState(isLoading: true));

  final IQueuePersistence _persistence;
  final IFileService _fileService;
  final String _languageCode;

  /// Restores persisted queue from SQLite and appends any files passed via
  /// Windows Explorer "Open with Print Helper" CLI arguments.
  Future<void> initialize({List<String> launchFileArgs = const []}) async {
    state = state.copyWith(isLoading: true, latestErrorMessages: const []);
    final savedItems = await _persistence.loadQueue();
    state = state.copyWith(items: savedItems, isLoading: false);

    if (launchFileArgs.isNotEmpty) {
      await addFilePaths(launchFileArgs);
    }
  }

  void setDraggingOverWindow(bool isDragging) {
    if (state.isDraggingOverWindow == isDragging) return;
    state = state.copyWith(isDraggingOverWindow: isDragging);
  }

  void dismissErrors() {
    if (state.latestErrorMessages.isEmpty) return;
    state = state.copyWith(latestErrorMessages: const []);
  }

  void selectPrinter(String printerName) {
    state = state.copyWith(selectedPrinterName: printerName);
  }

  Future<void> pickAndAddFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedExtensions.toList(),
      dialogTitle: _languageCode == 'si'
          ? 'මුද්‍රණය කිරීමට ගොනු තෝරන්න'
          : 'Select files to print',
    );
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList();

    await addFilePaths(paths);
  }

  Future<void> addFilePaths(List<String> paths) async {
    if (paths.isEmpty) return;
    state = state.copyWith(isLoading: true, latestErrorMessages: const []);

    final ingestResult = await _fileService.processFiles(
      paths,
      languageCode: _languageCode,
    );

    final updatedList = [...state.items, ...ingestResult.addedItems];
    state = state.copyWith(
      items: updatedList,
      isLoading: false,
      latestErrorMessages: ingestResult.rejectedErrors,
    );

    await _persistence.saveQueue(updatedList);
  }

  Future<void> pasteFromClipboard() async {
    state = state.copyWith(isLoading: true, latestErrorMessages: const []);
    final ingestResult = await _fileService.pasteFromClipboard(
      languageCode: _languageCode,
    );

    final updatedList = [...state.items, ...ingestResult.addedItems];
    state = state.copyWith(
      items: updatedList,
      isLoading: false,
      latestErrorMessages: ingestResult.rejectedErrors,
    );

    if (ingestResult.addedItems.isNotEmpty) {
      await _persistence.saveQueue(updatedList);
    }
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.items.length) return;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    newIndex = newIndex.clamp(0, state.items.length - 1);
    if (oldIndex == newIndex) return;

    final updated = List<PrintQueueItem>.from(state.items);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);

    state = state.copyWith(items: updated);
    await _persistence.saveQueue(updated);
  }

  Future<void> removeItem(String id) async {
    final updated = state.items.where((item) => item.id != id).toList();
    state = state.copyWith(items: updated);
    await _persistence.saveQueue(updated);
  }

  Future<void> clearAll() async {
    state = state.copyWith(items: const [], latestErrorMessages: const []);
    await _persistence.clearQueue();
  }

  void toggleItemSettingsExpanded(String id) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(isSettingsExpanded: !item.isSettingsExpanded);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  Future<void> updateItemSettings(
    String id,
    FilePrintSettings newSettings,
  ) async {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(settings: newSettings);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
    await _persistence.saveQueue(updated);
  }

  Future<void> applySettingsToAllItems(FilePrintSettings newSettings) async {
    if (state.items.isEmpty) return;
    final updated = state.items
        .map((item) => item.copyWith(settings: newSettings))
        .toList();
    state = state.copyWith(items: updated);
    await _persistence.saveQueue(updated);
  }

  /// Loads the bundled Sinhala Orthography & Invoice test documents into the queue
  /// so the user can inspect Rakaransaya, Yansaya, Repaya, conjuncts, and vowel signs
  /// in Live Preview and print output with one click.
  Future<void> loadBundledSinhalaTestDocuments() async {
    try {
      state = state.copyWith(isLoading: true, latestErrorMessages: const []);
      final tempDir = await getTemporaryDirectory();
      final sampleAssets = <String>[
        'assets/test_documents/sinhala_orthography_test.md',
        'assets/test_documents/sinhala_invoice_sample.txt',
      ];
      final writtenPaths = <String>[];

      for (final assetPath in sampleAssets) {
        final content = await rootBundle.loadString(assetPath);
        final fileName = p.basename(assetPath);
        final targetFile = File(p.join(tempDir.path, fileName));
        await targetFile.writeAsString(content, flush: true);
        writtenPaths.add(targetFile.path);
      }

      DiagnosticLogger.instance.info(
        'SinhalaSamples',
        'Loaded ${writtenPaths.length} bundled Sinhala test documents into queue.',
      );
      await addFilePaths(writtenPaths);
    } catch (e, st) {
      DiagnosticLogger.instance.error(
        'SinhalaSamples',
        'Failed to load bundled Sinhala test documents: $e',
        stackTrace: st,
      );
      state = state.copyWith(isLoading: false);
    }
  }
}
