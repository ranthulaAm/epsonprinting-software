import 'dart:convert';
import 'dart:typed_data';

enum PrintDocumentType {
  pdf,
  image,
  plainText,
  markdown,
}

enum DuplexMode {
  none,
  longEdge,
  shortEdge,
}

enum PageOrientation {
  portrait,
  landscape,
}

enum PageSubset {
  all,
  oddOnly,
  evenOnly,
}

enum PrintScaleMode {
  fitToPage,
  actualSize,
  customPercent,
}

enum MarginPreset {
  normal, // 12.7 mm (0.5 in)
  narrow, // 6.35 mm (0.25 in)
  none, // 0 mm (borderless)
  custom,
}

enum PrintQualityMode {
  draft,
  normal,
  high,
}

enum SheetLayoutMode {
  standard, // 1 page per sheet
  nUp, // 2, 4, 6, or 9 pages per sheet
  booklet, // Saddle-stitch 2-up folded booklet imposition
  poster, // Tile 1 page across 2x2, 3x3, or 4x4 sheets
}

class FilePrintSettings {
  const FilePrintSettings({
    this.copies = 1,
    this.collate = true,
    this.pageRange = '', // Empty means "All Pages", e.g. "1-3, 5, 8-10"
    this.pageSubset = PageSubset.all,
    this.reverseOrder = false,
    this.duplex = DuplexMode.none,
    this.orientation = PageOrientation.portrait,
    this.paperSize = 'A4',
    this.customWidthMm = 210.0,
    this.customHeightMm = 297.0,
    this.scaleMode = PrintScaleMode.fitToPage,
    this.customScalePercent = 100.0,
    this.marginPreset = MarginPreset.normal,
    this.customMarginMm = 12.7,
    this.centerHorizontally = true,
    this.centerVertically = true,
    this.isColor = true,
    this.quality = PrintQualityMode.normal,
    this.paperTray = 'Auto Select',
    this.mediaType = 'Plain Paper',
    this.layoutMode = SheetLayoutMode.standard,
    this.pagesPerSheet = 2, // Used when layoutMode == SheetLayoutMode.nUp (2, 4, 6, 9)
    this.posterGridSize = 2, // Used when layoutMode == SheetLayoutMode.poster (2=2x2, 3=3x3, 4=4x4)
    this.mirrorHorizontal = false,
    this.flipVertical = false,
    this.watermarkText = '',
    this.watermarkOpacity = 0.18,
    this.headerText = '',
    this.footerText = '',
    this.showPageNumbers = false,
    this.scaleFitToPage = true,
    this.textFontFamily = 'NotoSansSinhala',
    this.textFontSizePt = 11.0,
    this.textLineSpacing = 1.4,
    this.textWrapLines = true,
  });

  final int copies;
  final bool collate;
  final String pageRange;
  final PageSubset pageSubset;
  final bool reverseOrder;
  final DuplexMode duplex;
  final PageOrientation orientation;
  final String paperSize;
  final double customWidthMm;
  final double customHeightMm;
  final PrintScaleMode scaleMode;
  final double customScalePercent;
  final MarginPreset marginPreset;
  final double customMarginMm;
  final bool centerHorizontally;
  final bool centerVertically;
  final bool isColor;
  final PrintQualityMode quality;
  final String paperTray;
  final String mediaType;
  final SheetLayoutMode layoutMode;
  final int pagesPerSheet;
  final int posterGridSize;
  final bool mirrorHorizontal;
  final bool flipVertical;
  final String watermarkText;
  final double watermarkOpacity;
  final String headerText;
  final String footerText;
  final bool showPageNumbers;
  final bool scaleFitToPage;
  final String textFontFamily;
  final double textFontSizePt;
  final double textLineSpacing;
  final bool textWrapLines;

  double get effectiveMarginMm {
    switch (marginPreset) {
      case MarginPreset.normal:
        return 12.7;
      case MarginPreset.narrow:
        return 6.35;
      case MarginPreset.none:
        return 0.0;
      case MarginPreset.custom:
        return customMarginMm.clamp(0.0, 50.0);
    }
  }

  ({double widthMm, double heightMm}) get effectivePaperDimensionsMm {
    final (double baseW, double baseH) = switch (paperSize) {
      'Letter' => (215.9, 279.4),
      'Legal' => (215.9, 355.6),
      'A3' => (297.0, 420.0),
      'A5' => (148.0, 210.0),
      'Custom' => (
          customWidthMm.clamp(50.0, 1200.0),
          customHeightMm.clamp(50.0, 1200.0),
        ),
      _ => (210.0, 297.0), // Default A4
    };

    if (orientation == PageOrientation.landscape) {
      return (widthMm: baseH, heightMm: baseW);
    }
    return (widthMm: baseW, heightMm: baseH);
  }

  FilePrintSettings copyWith({
    int? copies,
    bool? collate,
    String? pageRange,
    PageSubset? pageSubset,
    bool? reverseOrder,
    DuplexMode? duplex,
    PageOrientation? orientation,
    String? paperSize,
    double? customWidthMm,
    double? customHeightMm,
    PrintScaleMode? scaleMode,
    double? customScalePercent,
    MarginPreset? marginPreset,
    double? customMarginMm,
    bool? centerHorizontally,
    bool? centerVertically,
    bool? isColor,
    PrintQualityMode? quality,
    String? paperTray,
    String? mediaType,
    SheetLayoutMode? layoutMode,
    int? pagesPerSheet,
    int? posterGridSize,
    bool? mirrorHorizontal,
    bool? flipVertical,
    String? watermarkText,
    double? watermarkOpacity,
    String? headerText,
    String? footerText,
    bool? showPageNumbers,
    bool? scaleFitToPage,
    String? textFontFamily,
    double? textFontSizePt,
    double? textLineSpacing,
    bool? textWrapLines,
  }) {
    return FilePrintSettings(
      copies: copies ?? this.copies,
      collate: collate ?? this.collate,
      pageRange: pageRange ?? this.pageRange,
      pageSubset: pageSubset ?? this.pageSubset,
      reverseOrder: reverseOrder ?? this.reverseOrder,
      duplex: duplex ?? this.duplex,
      orientation: orientation ?? this.orientation,
      paperSize: paperSize ?? this.paperSize,
      customWidthMm: customWidthMm ?? this.customWidthMm,
      customHeightMm: customHeightMm ?? this.customHeightMm,
      scaleMode: scaleMode ?? this.scaleMode,
      customScalePercent: customScalePercent ?? this.customScalePercent,
      marginPreset: marginPreset ?? this.marginPreset,
      customMarginMm: customMarginMm ?? this.customMarginMm,
      centerHorizontally: centerHorizontally ?? this.centerHorizontally,
      centerVertically: centerVertically ?? this.centerVertically,
      isColor: isColor ?? this.isColor,
      quality: quality ?? this.quality,
      paperTray: paperTray ?? this.paperTray,
      mediaType: mediaType ?? this.mediaType,
      layoutMode: layoutMode ?? this.layoutMode,
      pagesPerSheet: pagesPerSheet ?? this.pagesPerSheet,
      posterGridSize: posterGridSize ?? this.posterGridSize,
      mirrorHorizontal: mirrorHorizontal ?? this.mirrorHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      watermarkText: watermarkText ?? this.watermarkText,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      scaleFitToPage: scaleFitToPage ?? this.scaleFitToPage,
      textFontFamily: textFontFamily ?? this.textFontFamily,
      textFontSizePt: textFontSizePt ?? this.textFontSizePt,
      textLineSpacing: textLineSpacing ?? this.textLineSpacing,
      textWrapLines: textWrapLines ?? this.textWrapLines,
    );
  }

  Map<String, dynamic> toMap() => {
        'copies': copies,
        'collate': collate,
        'pageRange': pageRange,
        'pageSubset': pageSubset.name,
        'reverseOrder': reverseOrder,
        'duplex': duplex.name,
        'orientation': orientation.name,
        'paperSize': paperSize,
        'customWidthMm': customWidthMm,
        'customHeightMm': customHeightMm,
        'scaleMode': scaleMode.name,
        'customScalePercent': customScalePercent,
        'marginPreset': marginPreset.name,
        'customMarginMm': customMarginMm,
        'centerHorizontally': centerHorizontally,
        'centerVertically': centerVertically,
        'isColor': isColor,
        'quality': quality.name,
        'paperTray': paperTray,
        'mediaType': mediaType,
        'layoutMode': layoutMode.name,
        'pagesPerSheet': pagesPerSheet,
        'posterGridSize': posterGridSize,
        'mirrorHorizontal': mirrorHorizontal,
        'flipVertical': flipVertical,
        'watermarkText': watermarkText,
        'watermarkOpacity': watermarkOpacity,
        'headerText': headerText,
        'footerText': footerText,
        'showPageNumbers': showPageNumbers,
        'scaleFitToPage': scaleFitToPage,
        'textFontFamily': textFontFamily,
        'textFontSizePt': textFontSizePt,
        'textLineSpacing': textLineSpacing,
        'textWrapLines': textWrapLines,
      };

  factory FilePrintSettings.fromMap(Map<String, dynamic> map) {
    return FilePrintSettings(
      copies: (map['copies'] as num?)?.toInt().clamp(1, 999) ?? 1,
      collate: map['collate'] as bool? ?? true,
      pageRange: map['pageRange'] as String? ?? '',
      pageSubset: PageSubset.values.firstWhere(
        (e) => e.name == map['pageSubset'],
        orElse: () => PageSubset.all,
      ),
      reverseOrder: map['reverseOrder'] as bool? ?? false,
      duplex: DuplexMode.values.firstWhere(
        (e) => e.name == map['duplex'],
        orElse: () => DuplexMode.none,
      ),
      orientation: PageOrientation.values.firstWhere(
        (e) => e.name == map['orientation'],
        orElse: () => PageOrientation.portrait,
      ),
      paperSize: map['paperSize'] as String? ?? 'A4',
      customWidthMm: (map['customWidthMm'] as num?)?.toDouble() ?? 210.0,
      customHeightMm: (map['customHeightMm'] as num?)?.toDouble() ?? 297.0,
      scaleMode: PrintScaleMode.values.firstWhere(
        (e) => e.name == map['scaleMode'],
        orElse: () => PrintScaleMode.fitToPage,
      ),
      customScalePercent:
          (map['customScalePercent'] as num?)?.toDouble() ?? 100.0,
      marginPreset: MarginPreset.values.firstWhere(
        (e) => e.name == map['marginPreset'],
        orElse: () => MarginPreset.normal,
      ),
      customMarginMm: (map['customMarginMm'] as num?)?.toDouble() ?? 12.7,
      centerHorizontally: map['centerHorizontally'] as bool? ?? true,
      centerVertically: map['centerVertically'] as bool? ?? true,
      isColor: map['isColor'] as bool? ?? true,
      quality: PrintQualityMode.values.firstWhere(
        (e) => e.name == map['quality'],
        orElse: () => PrintQualityMode.normal,
      ),
      paperTray: map['paperTray'] as String? ?? 'Auto Select',
      mediaType: map['mediaType'] as String? ?? 'Plain Paper',
      layoutMode: SheetLayoutMode.values.firstWhere(
        (e) => e.name == map['layoutMode'],
        orElse: () => SheetLayoutMode.standard,
      ),
      pagesPerSheet: (map['pagesPerSheet'] as num?)?.toInt() ?? 2,
      posterGridSize: (map['posterGridSize'] as num?)?.toInt() ?? 2,
      mirrorHorizontal: map['mirrorHorizontal'] as bool? ?? false,
      flipVertical: map['flipVertical'] as bool? ?? false,
      watermarkText: map['watermarkText'] as String? ?? '',
      watermarkOpacity: (map['watermarkOpacity'] as num?)?.toDouble() ?? 0.18,
      headerText: map['headerText'] as String? ?? '',
      footerText: map['footerText'] as String? ?? '',
      showPageNumbers: map['showPageNumbers'] as bool? ?? false,
      scaleFitToPage: map['scaleFitToPage'] as bool? ?? true,
      textFontFamily: map['textFontFamily'] as String? ?? 'NotoSansSinhala',
      textFontSizePt: (map['textFontSizePt'] as num?)?.toDouble() ?? 11.0,
      textLineSpacing: (map['textLineSpacing'] as num?)?.toDouble() ?? 1.4,
      textWrapLines: map['textWrapLines'] as bool? ?? true,
    );
  }
}

class PrintQueueItem {
  const PrintQueueItem({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.extension,
    required this.documentType,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.addedAt,
    required this.settings,
    this.thumbnailBytes,
    this.textPreviewSnippet,
    this.isSettingsExpanded = false,
  });

  final String id;
  final String filePath;
  final String fileName;
  final String extension;
  final PrintDocumentType documentType;
  final int fileSizeBytes;
  final int pageCount;
  final DateTime addedAt;
  final FilePrintSettings settings;
  final Uint8List? thumbnailBytes;
  final String? textPreviewSnippet;
  final bool isSettingsExpanded;

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    final kb = fileSizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  PrintQueueItem copyWith({
    String? id,
    String? filePath,
    String? fileName,
    String? extension,
    PrintDocumentType? documentType,
    int? fileSizeBytes,
    int? pageCount,
    DateTime? addedAt,
    FilePrintSettings? settings,
    Uint8List? thumbnailBytes,
    String? textPreviewSnippet,
    bool? isSettingsExpanded,
  }) {
    return PrintQueueItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      extension: extension ?? this.extension,
      documentType: documentType ?? this.documentType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      addedAt: addedAt ?? this.addedAt,
      settings: settings ?? this.settings,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      textPreviewSnippet: textPreviewSnippet ?? this.textPreviewSnippet,
      isSettingsExpanded: isSettingsExpanded ?? this.isSettingsExpanded,
    );
  }

  Map<String, dynamic> toStorageRow(int sortOrder) => {
        'id': id,
        'file_path': filePath,
        'file_name': fileName,
        'extension': extension,
        'doc_type': documentType.name,
        'file_size_bytes': fileSizeBytes,
        'page_count': pageCount,
        'added_at': addedAt.toIso8601String(),
        'settings_json': jsonEncode(settings.toMap()),
        'thumbnail_blob': thumbnailBytes,
        'text_snippet': textPreviewSnippet,
        'sort_order': sortOrder,
      };

  factory PrintQueueItem.fromStorageRow(Map<String, Object?> row) {
    final settingsRaw = row['settings_json'] as String? ?? '{}';
    Map<String, dynamic> settingsMap = {};
    try {
      settingsMap = jsonDecode(settingsRaw) as Map<String, dynamic>;
    } catch (_) {}

    final rawThumb = row['thumbnail_blob'];
    Uint8List? thumbBytes;
    if (rawThumb is Uint8List) {
      thumbBytes = rawThumb;
    } else if (rawThumb is List<int>) {
      thumbBytes = Uint8List.fromList(rawThumb);
    }

    return PrintQueueItem(
      id: row['id'] as String,
      filePath: row['file_path'] as String,
      fileName: row['file_name'] as String,
      extension: row['extension'] as String? ?? '',
      documentType: PrintDocumentType.values.firstWhere(
        (e) => e.name == row['doc_type'],
        orElse: () => PrintDocumentType.pdf,
      ),
      fileSizeBytes: (row['file_size_bytes'] as num?)?.toInt() ?? 0,
      pageCount: (row['page_count'] as num?)?.toInt() ?? 1,
      addedAt: DateTime.tryParse(row['added_at'] as String? ?? '') ??
          DateTime.now(),
      settings: FilePrintSettings.fromMap(settingsMap),
      thumbnailBytes: thumbBytes,
      textPreviewSnippet: row['text_snippet'] as String?,
    );
  }
}
