import '../../features/workspace/domain/print_queue_item.dart';

class FileIngestResult {
  const FileIngestResult({
    required this.addedItems,
    required this.rejectedErrors,
  });

  final List<PrintQueueItem> addedItems;
  final List<String> rejectedErrors;

  bool get hasErrors => rejectedErrors.isNotEmpty;
}

abstract interface class IFileService {
  /// Validates and inspects a list of file paths, returning valid PrintQueueItems
  /// with page counts and thumbnails, alongside human-readable errors for any
  /// unsupported or corrupt files.
  Future<FileIngestResult> processFiles(
    List<String> filePaths, {
    required String languageCode,
  });

  /// Reads file paths or plain text from the system clipboard (including
  /// Windows Explorer `CF_HDROP` copied files or copied text) and converts
  /// them into queue items.
  Future<FileIngestResult> pasteFromClipboard({
    required String languageCode,
  });
}
