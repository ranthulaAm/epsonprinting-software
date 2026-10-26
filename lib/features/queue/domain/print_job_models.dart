import 'dart:convert';

import '../../workspace/domain/print_queue_item.dart';

enum MultiPrinterRoutingMode {
  singlePrinter, // Send all queued files to 1 chosen printer
  broadcastAll, // Send a copy of every file to all chosen printers simultaneously
  loadBalanceSplit, // Split batch across chosen printers to balance page load
}

enum PrintJobStatus {
  queued,
  spooling,
  printing,
  paused,
  awaitingFallback, // Target printer went offline; waiting for user to approve fallback printer
  completed,
  failed,
  canceled,
}

enum SpoolerJobCommand {
  pause,
  resume,
  cancel,
  restart,
}

enum HistoryRetentionPolicy {
  keepAll,
  days7,
  days30,
  days90,
}

class PrintHelperJob {
  const PrintHelperJob({
    required this.id,
    required this.batchId,
    required this.filePath,
    required this.fileName,
    required this.documentType,
    required this.totalPages,
    required this.pagesPrinted,
    required this.targetPrinterSystemName,
    required this.targetPrinterDisplayName,
    required this.settings,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
    this.retryCount = 0,
    this.fallbackSuggestedPrinter,
    this.spoolerJobId,
  });

  final String id;
  final String batchId;
  final String filePath;
  final String fileName;
  final PrintDocumentType documentType;
  final int totalPages;
  final int pagesPrinted;
  final String targetPrinterSystemName;
  final String targetPrinterDisplayName;
  final FilePrintSettings settings;
  final PrintJobStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final int retryCount;
  final String? fallbackSuggestedPrinter;
  final int? spoolerJobId;

  int get effectiveTotalPages => totalPages * settings.copies;

  double get progress => effectiveTotalPages <= 0
      ? 0.0
      : (pagesPrinted / effectiveTotalPages).clamp(0.0, 1.0);

  bool get isTerminal =>
      status == PrintJobStatus.completed ||
      status == PrintJobStatus.failed ||
      status == PrintJobStatus.canceled;

  PrintHelperJob copyWith({
    String? id,
    String? batchId,
    String? filePath,
    String? fileName,
    PrintDocumentType? documentType,
    int? totalPages,
    int? pagesPrinted,
    String? targetPrinterSystemName,
    String? targetPrinterDisplayName,
    FilePrintSettings? settings,
    PrintJobStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
    bool clearError = false,
    int? retryCount,
    String? fallbackSuggestedPrinter,
    bool clearFallbackSuggestion = false,
    int? spoolerJobId,
  }) {
    return PrintHelperJob(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      documentType: documentType ?? this.documentType,
      totalPages: totalPages ?? this.totalPages,
      pagesPrinted: pagesPrinted ?? this.pagesPrinted,
      targetPrinterSystemName:
          targetPrinterSystemName ?? this.targetPrinterSystemName,
      targetPrinterDisplayName:
          targetPrinterDisplayName ?? this.targetPrinterDisplayName,
      settings: settings ?? this.settings,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      retryCount: retryCount ?? this.retryCount,
      fallbackSuggestedPrinter: clearFallbackSuggestion
          ? null
          : (fallbackSuggestedPrinter ?? this.fallbackSuggestedPrinter),
      spoolerJobId: spoolerJobId ?? this.spoolerJobId,
    );
  }

  Map<String, Object?> toHistoryRow() => {
        'id': id,
        'batch_id': batchId,
        'file_path': filePath,
        'file_name': fileName,
        'doc_type': documentType.name,
        'total_pages': totalPages,
        'pages_printed': pagesPrinted,
        'printer_sys_name': targetPrinterSystemName,
        'printer_display_name': targetPrinterDisplayName,
        'settings_json': jsonEncode(settings.toMap()),
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'error_message': errorMessage,
        'retry_count': retryCount,
      };

  factory PrintHelperJob.fromHistoryRow(Map<String, Object?> row) {
    Map<String, dynamic> settingsMap = {};
    try {
      settingsMap = jsonDecode(row['settings_json'] as String? ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {}

    return PrintHelperJob(
      id: row['id'] as String,
      batchId: row['batch_id'] as String? ?? '',
      filePath: row['file_path'] as String,
      fileName: row['file_name'] as String,
      documentType: PrintDocumentType.values.firstWhere(
        (e) => e.name == row['doc_type'],
        orElse: () => PrintDocumentType.pdf,
      ),
      totalPages: (row['total_pages'] as num?)?.toInt() ?? 1,
      pagesPrinted: (row['pages_printed'] as num?)?.toInt() ?? 0,
      targetPrinterSystemName: row['printer_sys_name'] as String,
      targetPrinterDisplayName:
          row['printer_display_name'] as String? ??
              (row['printer_sys_name'] as String),
      settings: FilePrintSettings.fromMap(settingsMap),
      status: PrintJobStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => PrintJobStatus.completed,
      ),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      completedAt: row['completed_at'] != null
          ? DateTime.tryParse(row['completed_at'] as String)
          : null,
      errorMessage: row['error_message'] as String?,
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SpoolSubmissionResult {
  const SpoolSubmissionResult({
    required this.isSuccess,
    this.spoolerJobId,
    this.errorMessageEn,
    this.errorMessageSi,
    this.isPrinterOfflineError = false,
  });

  final bool isSuccess;
  final int? spoolerJobId;
  final String? errorMessageEn;
  final String? errorMessageSi;
  final bool isPrinterOfflineError;

  String? localizedError(String lang) =>
      lang == 'si' ? errorMessageSi : errorMessageEn;
}

class SpoolerJobInfo {
  const SpoolerJobInfo({
    required this.jobId,
    required this.printerName,
    required this.documentName,
    required this.userName,
    required this.statusLabel,
    required this.pagesPrinted,
    required this.totalPages,
    required this.isPaused,
    required this.hasError,
  });

  final int jobId;
  final String printerName;
  final String documentName;
  final String userName;
  final String statusLabel;
  final int pagesPrinted;
  final int totalPages;
  final bool isPaused;
  final bool hasError;
}

class HotFolderConfig {
  const HotFolderConfig({
    this.enabled = false,
    this.folderPath = '',
    this.presetId = 'builtin_duplex_bw_draft',
    this.targetPrinterSystemName = '',
  });

  final bool enabled;
  final String folderPath;
  final String presetId;
  final String targetPrinterSystemName;

  HotFolderConfig copyWith({
    bool? enabled,
    String? folderPath,
    String? presetId,
    String? targetPrinterSystemName,
  }) {
    return HotFolderConfig(
      enabled: enabled ?? this.enabled,
      folderPath: folderPath ?? this.folderPath,
      presetId: presetId ?? this.presetId,
      targetPrinterSystemName:
          targetPrinterSystemName ?? this.targetPrinterSystemName,
    );
  }
}

class AppDesktopNotification {
  const AppDesktopNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isError,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String body;
  final bool isError;
  final DateTime timestamp;
}
