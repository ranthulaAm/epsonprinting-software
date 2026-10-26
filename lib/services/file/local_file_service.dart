import 'dart:collection';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';
import 'package:win32/win32.dart' as win32;

import '../../core/constants/app_constants.dart';
import '../../core/diagnostics/diagnostic_logger.dart';
import '../../core/errors/app_exception.dart';
import '../../features/workspace/domain/print_queue_item.dart';
import '../typography/sinhala_text_composer.dart';
import 'i_file_service.dart';

final fileServiceProvider = Provider<IFileService>((ref) {
  return LocalFileService();
});

/// Bounded LRU thumbnail cache (max 40 thumbnails in RAM) so opening 500+ page
/// PDFs or large batches never spikes memory usage.
class LazyThumbnailCache {
  LazyThumbnailCache({this.maxEntries = 40});

  final int maxEntries;
  final LinkedHashMap<String, Uint8List> _map =
      LinkedHashMap<String, Uint8List>();

  Uint8List? get(String key) {
    final val = _map.remove(key);
    if (val != null) {
      _map[key] = val; // Move to most-recently-used
    }
    return val;
  }

  void put(String key, Uint8List bytes) {
    _map.remove(key);
    _map[key] = bytes;
    while (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
  }

  int get length => _map.length;
}

class LocalFileService implements IFileService {
  static const _uuid = Uuid();
  final LazyThumbnailCache thumbnailCache = LazyThumbnailCache(maxEntries: 40);

  @override
  Future<FileIngestResult> processFiles(
    List<String> filePaths, {
    required String languageCode,
  }) async {
    final List<PrintQueueItem> added = [];
    final List<String> errors = [];

    for (final rawPath in filePaths) {
      final cleanPath = rawPath.trim().replaceAll('"', '');
      if (cleanPath.isEmpty) continue;

      final file = File(cleanPath);
      final fileName = p.basename(cleanPath);

      if (!await file.exists()) {
        errors.add(
          languageCode == 'si'
              ? '"$fileName" ගොනුව හමු නොවීය.'
              : 'File "$fileName" was not found.',
        );
        continue;
      }

      final ext = p.extension(cleanPath).replaceFirst('.', '').toLowerCase();
      if (!AppConstants.supportedExtensions.contains(ext)) {
        final ex = UnsupportedFileException(fileName, ext);
        errors.add(ex.localizedMessage(languageCode));
        DiagnosticLogger.instance.warn(
          'FileService',
          'Rejected unsupported file "$fileName" (.$ext)',
        );
        continue;
      }

      try {
        final stat = await file.stat();
        if (stat.size == 0) {
          throw CorruptOrProtectedFileException(
            fileName,
            reason: 'File is 0 bytes',
          );
        }

        if (ext == 'pdf') {
          final item = await _inspectPdf(file, fileName, stat.size);
          added.add(item);
        } else if (AppConstants.imageExtensions.contains(ext)) {
          final item = await _inspectImage(file, fileName, ext, stat.size);
          added.add(item);
        } else if (AppConstants.textAndMarkdownExtensions.contains(ext)) {
          final item = await _inspectTextOrMarkdown(
            file,
            fileName,
            ext,
            stat.size,
          );
          added.add(item);
        }
      } on AppException catch (e) {
        errors.add(e.localizedMessage(languageCode));
        DiagnosticLogger.instance.warn(
          'FileService',
          'Rejected file "$fileName"',
          details: e.technicalDetails,
        );
      } catch (e) {
        final ex = CorruptOrProtectedFileException(
          fileName,
          reason: e.toString(),
        );
        errors.add(ex.localizedMessage(languageCode));
        DiagnosticLogger.instance.error(
          'FileService',
          'Error inspecting "$fileName"',
          details: e.toString(),
        );
      }
    }

    return FileIngestResult(addedItems: added, rejectedErrors: errors);
  }

  /// Opens even 500+ page PDFs without freezing by reading only the 5-byte magic
  /// header on the file handle, querying the PDFium page table count, and lazily
  /// rendering only Page 1's low-res 120px thumbnail into `LazyThumbnailCache`.
  Future<PrintQueueItem> _inspectPdf(
    File file,
    String fileName,
    int fileSizeBytes,
  ) async {
    final raf = await file.open();
    try {
      final headerBytes = await raf.read(5);
      final headerStr = ascii.decode(headerBytes, allowInvalid: true);
      if (!headerStr.startsWith('%PDF-')) {
        throw CorruptOrProtectedFileException(
          fileName,
          reason: 'Missing %PDF- header',
        );
      }
    } finally {
      await raf.close();
    }

    int pageCount = 1;
    Uint8List? thumbPngBytes = thumbnailCache.get(file.path);

    try {
      final doc = await PdfDocument.openFile(file.path);
      try {
        pageCount = doc.pages.length;
        if (pageCount == 0) {
          throw CorruptOrProtectedFileException(
            fileName,
            reason: 'PDF has 0 pages',
          );
        }
        if (thumbPngBytes == null) {
          final firstPage = doc.pages.first;
          final double scale = 120.0 / firstPage.width;
          const int targetW = 120;
          final int targetH = (firstPage.height * scale).round().clamp(40, 200);
          final pdfImage = await firstPage.render(
            fullWidth: targetW.toDouble(),
            fullHeight: targetH.toDouble(),
            width: targetW,
            height: targetH,
          );
          if (pdfImage != null) {
            try {
              final uiImage = await pdfImage.createImage();
              final byteData =
                  await uiImage.toByteData(format: ui.ImageByteFormat.png);
              if (byteData != null) {
                thumbPngBytes = byteData.buffer.asUint8List();
                thumbnailCache.put(file.path, thumbPngBytes);
              }
              uiImage.dispose();
            } finally {
              pdfImage.dispose();
            }
          }
        }
      } finally {
        await doc.dispose();
      }
    } catch (e) {
      if (e is AppException) rethrow;
      pageCount = await _fallbackEstimatePdfPages(file.path, fileName);
    }

    DiagnosticLogger.instance.info(
      'FileService',
      'Loaded PDF "$fileName" ($pageCount pages, $fileSizeBytes bytes)',
    );

    return PrintQueueItem(
      id: _uuid.v4(),
      filePath: file.path,
      fileName: fileName,
      extension: 'pdf',
      documentType: PrintDocumentType.pdf,
      fileSizeBytes: fileSizeBytes,
      pageCount: pageCount,
      addedAt: DateTime.now(),
      settings: const FilePrintSettings(),
      thumbnailBytes: thumbPngBytes,
    );
  }

  /// Streams/scans `/Type /Page` markers inside an Isolate so 500+ page PDFs
  /// complete in milliseconds without blocking the UI thread.
  Future<int> _fallbackEstimatePdfPages(
    String filePath,
    String fileName,
  ) async {
    return Isolate.run(() {
      final bytes = File(filePath).readAsBytesSync();
      final content = latin1.decode(bytes, allowInvalid: true);
      if (content.contains('/Encrypt')) {
        throw CorruptOrProtectedFileException(
          fileName,
          reason: 'Password-protected PDF',
        );
      }
      final matches = RegExp(r'/Type\s*/Page\b').allMatches(content).length;
      return matches > 0 ? matches : 1;
    });
  }

  Future<PrintQueueItem> _inspectImage(
    File file,
    String fileName,
    String ext,
    int fileSizeBytes,
  ) async {
    final cached = thumbnailCache.get(file.path);
    final result = await Isolate.run<({int pages, Uint8List thumb})?>(() {
      final bytes = File(file.path).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final int frameCount = decoded.numFrames > 0 ? decoded.numFrames : 1;
      if (cached != null) {
        return (pages: frameCount, thumb: cached);
      }
      final resized = img.copyResize(
        decoded,
        width: 120,
        interpolation: img.Interpolation.average,
      );
      final pngThumb = Uint8List.fromList(img.encodePng(resized));
      return (pages: frameCount, thumb: pngThumb);
    });

    if (result == null) {
      throw CorruptOrProtectedFileException(
        fileName,
        reason: 'Invalid image data',
      );
    }

    thumbnailCache.put(file.path, result.thumb);

    return PrintQueueItem(
      id: _uuid.v4(),
      filePath: file.path,
      fileName: fileName,
      extension: ext,
      documentType: PrintDocumentType.image,
      fileSizeBytes: fileSizeBytes,
      pageCount: result.pages,
      addedAt: DateTime.now(),
      settings: const FilePrintSettings(),
      thumbnailBytes: result.thumb,
    );
  }

  Future<PrintQueueItem> _inspectTextOrMarkdown(
    File file,
    String fileName,
    String ext,
    int fileSizeBytes,
  ) async {
    final bool isMarkdown = ext == 'md' || ext == 'markdown';

    final result = await Isolate.run<
        ({
          int pages,
          String snippet,
          SinhalaShapingReport shapingReport,
        })>(() {
      final bytes = File(file.path).readAsBytesSync();
      final text = utf8.decode(bytes, allowInvalid: true);
      if (text.trim().isEmpty) {
        throw CorruptOrProtectedFileException(
          fileName,
          reason: 'Empty text/markdown file',
        );
      }
      final blocks = SinhalaTextComposer.parseDocumentBlocks(
        rawText: text,
        isMarkdown: isMarkdown,
      );
      final paginated = SinhalaTextComposer.paginateBlocks(
        blocks: blocks,
        printableWidthMm: 184.6, // A4 width minus normal margins
        printableHeightMm: 271.6,
        fontSizePt: 11.0,
        lineSpacing: 1.4,
        wrapLines: true,
      );
      final shaping = SinhalaTextComposer.verifySinhalaOrthography(text);
      final lines = const LineSplitter().convert(text);
      final snippet = lines.take(8).join('\n');
      return (
        pages: paginated.length,
        snippet: snippet,
        shapingReport: shaping,
      );
    });

    if (result.shapingReport.containsSinhala) {
      DiagnosticLogger.instance.info(
        'SinhalaShaping',
        'Verified Sinhala text in "$fileName": '
            'Rakaransaya=${result.shapingReport.rakaransayaCount}, '
            'Yansaya=${result.shapingReport.yansayaCount}, '
            'Conjuncts=${result.shapingReport.repayaOrConjunctCount}, '
            'SplitVowels=${result.shapingReport.splitVowelCount}',
      );
    }

    return PrintQueueItem(
      id: _uuid.v4(),
      filePath: file.path,
      fileName: fileName,
      extension: ext,
      documentType:
          isMarkdown ? PrintDocumentType.markdown : PrintDocumentType.plainText,
      fileSizeBytes: fileSizeBytes,
      pageCount: result.pages,
      addedAt: DateTime.now(),
      settings: const FilePrintSettings(),
      textPreviewSnippet: result.snippet,
    );
  }

  @override
  Future<FileIngestResult> pasteFromClipboard({
    required String languageCode,
  }) async {
    if (Platform.isWindows) {
      final droppedFiles = _readWindowsClipboardFiles();
      if (droppedFiles.isNotEmpty) {
        return processFiles(droppedFiles, languageCode: languageCode);
      }
    }

    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipData?.text?.trim() ?? '';
    if (text.isEmpty) {
      return FileIngestResult(
        addedItems: const [],
        rejectedErrors: [
          languageCode == 'si'
              ? 'පසුරු පුවරුවේ (Clipboard) ගොනු හෝ පෙළ කිසිවක් නොමැත.'
              : 'Clipboard is empty or contains no printable files/text.',
        ],
      );
    }

    final candidateLines = const LineSplitter()
        .convert(text)
        .map((l) => l.trim().replaceAll('"', ''))
        .where((l) => l.isNotEmpty)
        .toList();

    if (candidateLines.isNotEmpty &&
        candidateLines.every((pStr) => File(pStr).existsSync())) {
      return processFiles(candidateLines, languageCode: languageCode);
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File(p.join(tempDir.path, 'Clipboard_$timestamp.txt'));
    await tempFile.writeAsString(text, encoding: utf8, flush: true);

    return processFiles([tempFile.path], languageCode: languageCode);
  }

  List<String> _readWindowsClipboardFiles() {
    if (!Platform.isWindows) return const [];
    final List<String> paths = [];
    if (win32.OpenClipboard(win32.NULL) == win32.FALSE) {
      return const [];
    }
    try {
      if (win32.IsClipboardFormatAvailable(win32.CF_HDROP) == win32.FALSE) {
        return const [];
      }
      final int hDrop = win32.GetClipboardData(win32.CF_HDROP);
      if (hDrop == 0) return const [];

      final int fileCount =
          win32.DragQueryFile(hDrop, 0xFFFFFFFF, ffi.nullptr, 0);
      for (var i = 0; i < fileCount; i++) {
        final int charLen = win32.DragQueryFile(hDrop, i, ffi.nullptr, 0);
        if (charLen > 0) {
          final buffer = wsalloc(charLen + 1);
          try {
            win32.DragQueryFile(hDrop, i, buffer, charLen + 1);
            paths.add(buffer.toDartString());
          } finally {
            free(buffer);
          }
        }
      }
    } catch (_) {
    } finally {
      win32.CloseClipboard();
    }
    return paths;
  }
}
