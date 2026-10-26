import 'dart:typed_data';

// ============================================================================
// 1. PDF Viewer Domain Models (Tabs, Modes, Zoom, Bookmarks, Search, Last Page)
// ============================================================================

enum PdfViewDisplayMode {
  continuous,
  singlePage,
}

enum PdfZoomPreset {
  fitWidth,
  fitPage,
  customScale,
}

class PdfBookmarkNode {
  const PdfBookmarkNode({
    required this.title,
    required this.pageNumber,
    this.children = const <PdfBookmarkNode>[],
  });

  final String title;
  final int pageNumber; // 1-based page number
  final List<PdfBookmarkNode> children;
}

class PdfSearchMatch {
  const PdfSearchMatch({
    required this.pageNumber,
    required this.snippet,
    required this.matchStartIndex,
    required this.matchLength,
  });

  final int pageNumber;
  final String snippet;
  final int matchStartIndex;
  final int matchLength;
}

/// Represents a single open document tab in the multi-tab PDF Viewer.
class PdfDocumentTabState {
  const PdfDocumentTabState({
    required this.tabId,
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.totalPages,
    this.currentPage = 1,
    this.displayMode = PdfViewDisplayMode.continuous,
    this.zoomPreset = PdfZoomPreset.fitWidth,
    this.zoomScale = 1.0,
    this.viewRotationDegrees = 0,
    this.nightMode = false,
    this.showThumbnailsSidebar = true,
    this.showBookmarksSidebar = false,
    this.isPasswordProtected = false,
    this.isUnlocked = true,
    this.passwordUsed,
    this.bookmarks = const <PdfBookmarkNode>[],
    this.pageTexts = const <int, String>{},
    this.searchQuery = '',
    this.searchMatches = const <PdfSearchMatch>[],
    this.activeSearchMatchIndex = 0,
  });

  final String tabId;
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final int totalPages;
  final int currentPage;
  final PdfViewDisplayMode displayMode;
  final PdfZoomPreset zoomPreset;
  final double zoomScale;
  final int viewRotationDegrees; // 0, 90, 180, 270
  final bool nightMode;
  final bool showThumbnailsSidebar;
  final bool showBookmarksSidebar;
  final bool isPasswordProtected;
  final bool isUnlocked;
  final String? passwordUsed;
  final List<PdfBookmarkNode> bookmarks;
  final Map<int, String> pageTexts;
  final String searchQuery;
  final List<PdfSearchMatch> searchMatches;
  final int activeSearchMatchIndex;

  PdfDocumentTabState copyWith({
    int? totalPages,
    int? currentPage,
    PdfViewDisplayMode? displayMode,
    PdfZoomPreset? zoomPreset,
    double? zoomScale,
    int? viewRotationDegrees,
    bool? nightMode,
    bool? showThumbnailsSidebar,
    bool? showBookmarksSidebar,
    bool? isPasswordProtected,
    bool? isUnlocked,
    String? passwordUsed,
    List<PdfBookmarkNode>? bookmarks,
    Map<int, String>? pageTexts,
    String? searchQuery,
    List<PdfSearchMatch>? searchMatches,
    int? activeSearchMatchIndex,
  }) {
    return PdfDocumentTabState(
      tabId: tabId,
      filePath: filePath,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      displayMode: displayMode ?? this.displayMode,
      zoomPreset: zoomPreset ?? this.zoomPreset,
      zoomScale: zoomScale ?? this.zoomScale,
      viewRotationDegrees: viewRotationDegrees ?? this.viewRotationDegrees,
      nightMode: nightMode ?? this.nightMode,
      showThumbnailsSidebar:
          showThumbnailsSidebar ?? this.showThumbnailsSidebar,
      showBookmarksSidebar: showBookmarksSidebar ?? this.showBookmarksSidebar,
      isPasswordProtected: isPasswordProtected ?? this.isPasswordProtected,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      passwordUsed: passwordUsed ?? this.passwordUsed,
      bookmarks: bookmarks ?? this.bookmarks,
      pageTexts: pageTexts ?? this.pageTexts,
      searchQuery: searchQuery ?? this.searchQuery,
      searchMatches: searchMatches ?? this.searchMatches,
      activeSearchMatchIndex:
          activeSearchMatchIndex ?? this.activeSearchMatchIndex,
    );
  }
}

// ============================================================================
// 2. Page Tools Domain Models (Organize, Split, Crop, Resize, Compress, Stamp)
// ============================================================================

enum PdfPageToolKind {
  merge,
  split,
  extractPages,
  deletePages,
  rotatePages,
  reorderPages,
  insertBlankPages,
  insertFromAnotherPdf,
  cropPages,
  resizeStandardPage,
  compressPdf,
  repairDamagedPdf,
  stampBatesHeadersWatermarks,
}

enum PdfSplitStrategy {
  byPageRange, // e.g. "1-3, 4-8"
  everyNPages, // e.g. every 2 pages
  byMaxFileSizeMb, // e.g. max 5 MB per part
  byTopLevelBookmarks, // split at each chapter/bookmark
}

enum PdfCompressionLevel {
  low(
    targetDpi: 220,
    jpegQuality: 88,
    expectedRatioFactor: 0.78,
    labelEn: 'Low Compression (High Visual Quality — 220 DPI)',
    labelSi: 'අඩු හැකිලීම (ඉහළම පැහැදිලි බව — 220 DPI)',
  ),
  medium(
    targetDpi: 150,
    jpegQuality: 75,
    expectedRatioFactor: 0.48,
    labelEn: 'Medium Compression (Balanced Office Standard — 150 DPI)',
    labelSi: 'මධ්‍යම හැකිලීම (සාමාන්‍ය කාර්යාල ප්‍රමිතිය — 150 DPI)',
  ),
  high(
    targetDpi: 96,
    jpegQuality: 58,
    expectedRatioFactor: 0.26,
    labelEn: 'High Compression (Smallest File Size — 96 DPI Downsampling)',
    labelSi: 'ඉහළම හැකිලීම (කුඩාම ගොනු ප්‍රමාණය — 96 DPI)',
  );

  const PdfCompressionLevel({
    required this.targetDpi,
    required this.jpegQuality,
    required this.expectedRatioFactor,
    required this.labelEn,
    required this.labelSi,
  });

  final int targetDpi;
  final int jpegQuality;
  final double expectedRatioFactor;
  final String labelEn;
  final String labelSi;
}

enum PdfStandardPaperSize {
  a4(name: 'A4', widthMm: 210.0, heightMm: 297.0),
  letter(name: 'Letter', widthMm: 215.9, heightMm: 279.4),
  legal(name: 'Legal', widthMm: 215.9, heightMm: 355.6),
  a3(name: 'A3', widthMm: 297.0, heightMm: 420.0),
  a5(name: 'A5', widthMm: 148.0, heightMm: 210.0);

  const PdfStandardPaperSize({
    required this.name,
    required this.widthMm,
    required this.heightMm,
  });

  final String name;
  final double widthMm;
  final double heightMm;

  double get widthPt => (widthMm / 25.4) * 72.0;
  double get heightPt => (heightMm / 25.4) * 72.0;
}

/// Represents a single page tile in the visual drag-and-drop Page Organizer.
class PdfEditablePageDescriptor {
  const PdfEditablePageDescriptor({
    required this.tileId,
    required this.sourceFilePath,
    required this.sourceFileName,
    required this.originalPageNumber, // null if inserted blank page
    this.rotationDegrees = 0,
    this.isBlankInserted = false,
    this.cropTopMm = 0.0,
    this.cropBottomMm = 0.0,
    this.cropLeftMm = 0.0,
    this.cropRightMm = 0.0,
  });

  final String tileId;
  final String sourceFilePath;
  final String sourceFileName;
  final int? originalPageNumber;
  final int rotationDegrees;
  final bool isBlankInserted;
  final double cropTopMm;
  final double cropBottomMm;
  final double cropLeftMm;
  final double cropRightMm;

  PdfEditablePageDescriptor copyWith({
    int? rotationDegrees,
    double? cropTopMm,
    double? cropBottomMm,
    double? cropLeftMm,
    double? cropRightMm,
  }) {
    return PdfEditablePageDescriptor(
      tileId: tileId,
      sourceFilePath: sourceFilePath,
      sourceFileName: sourceFileName,
      originalPageNumber: originalPageNumber,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      isBlankInserted: isBlankInserted,
      cropTopMm: cropTopMm ?? this.cropTopMm,
      cropBottomMm: cropBottomMm ?? this.cropBottomMm,
      cropLeftMm: cropLeftMm ?? this.cropLeftMm,
      cropRightMm: cropRightMm ?? this.cropRightMm,
    );
  }
}

/// Configuration for Page Numbers, Headers/Footers, Bates Numbering, and Watermarks
/// (Text or Image, with bundled Noto Sans Sinhala embedded).
class PdfStampingConfig {
  const PdfStampingConfig({
    this.includePageNumbers = true,
    this.pageNumberFormat = 'Page {page} of {total}',
    this.headerLeft = '',
    this.headerCenter = '',
    this.headerRight = '',
    this.footerLeft = '',
    this.footerCenter = '',
    this.footerRight = '',
    this.enableBatesNumbering = false,
    this.batesPrefix = 'DOC-',
    this.batesSuffix = '',
    this.batesStartNumber = 1,
    this.batesDigits = 6,
    this.watermarkText = '',
    this.watermarkImageBytes,
    this.watermarkOpacity = 0.22,
    this.watermarkRotationDegrees = -35.0,
    this.fontSizePt = 10.0,
  });

  final bool includePageNumbers;
  final String pageNumberFormat;
  final String headerLeft;
  final String headerCenter;
  final String headerRight;
  final String footerLeft;
  final String footerCenter;
  final String footerRight;
  final bool enableBatesNumbering;
  final String batesPrefix;
  final String batesSuffix;
  final int batesStartNumber;
  final int batesDigits;
  final String watermarkText;
  final Uint8List? watermarkImageBytes;
  final double watermarkOpacity;
  final double watermarkRotationDegrees;
  final double fontSizePt;

  /// Formats a Bates stamp for a 0-based sequential index (e.g., `DOC-000001`).
  String formatBatesForIndex(int zeroBasedIndex) {
    final numVal = batesStartNumber + zeroBasedIndex;
    final padded = numVal.toString().padLeft(batesDigits.clamp(1, 12), '0');
    return '$batesPrefix$padded$batesSuffix';
  }
}

/// Result of any PDF Page Tool execution, including exact Before/After sizes,
/// generated preview bytes, and output file paths.
class PdfToolExecutionReport {
  const PdfToolExecutionReport({
    required this.toolKind,
    required this.beforeSizeBytes,
    required this.afterSizeBytes,
    required this.inputPageCount,
    required this.outputPageCount,
    required this.outputFiles,
    required this.previewPdfBytes,
    required this.summaryEn,
    required this.summarySi,
    required this.elapsedMs,
    this.usedQpdfCli = false,
  });

  final PdfPageToolKind toolKind;
  final int beforeSizeBytes;
  final int afterSizeBytes;
  final int inputPageCount;
  final int outputPageCount;
  final List<String> outputFiles;
  final Uint8List previewPdfBytes;
  final String summaryEn;
  final String summarySi;
  final int elapsedMs;
  final bool usedQpdfCli;

  int get sizeDeltaBytes => afterSizeBytes - beforeSizeBytes;

  double get sizeChangePercent {
    if (beforeSizeBytes <= 0) return 0.0;
    return ((afterSizeBytes - beforeSizeBytes) / beforeSizeBytes) * 100.0;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedBeforeSize => formatBytes(beforeSizeBytes);
  String get formattedAfterSize => formatBytes(afterSizeBytes);
}
