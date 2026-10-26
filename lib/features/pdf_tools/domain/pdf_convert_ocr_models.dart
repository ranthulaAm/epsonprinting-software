import 'dart:typed_data';

// ============================================================================
// 1. Legacy Sinhala Font Detection (FM Abhaya, DL-Manel, Wijesekara)
// ============================================================================

class LegacySinhalaDetectionResult {
  const LegacySinhalaDetectionResult({
    required this.hasLegacySinhalaEncoding,
    required this.detectedLegacyFontNames,
    required this.sampleLegacyToken,
    required this.transcodedUnicodePreview,
    required this.warningEn,
    required this.warningSi,
  });

  final bool hasLegacySinhalaEncoding;
  final List<String> detectedLegacyFontNames;
  final String sampleLegacyToken;
  final String transcodedUnicodePreview;
  final String warningEn;
  final String warningSi;
}

// ============================================================================
// 2. Convert Wizard & Batch Conversion Queue Models
// ============================================================================

enum ConversionEngineKind {
  libreOfficeHeadless(
    labelEn: 'LibreOffice Headless (MPL-2.0 Offline CLI)',
    labelSi: 'LibreOffice Headless (Offline CLI)',
  ),
  microsoftOfficeCom(
    labelEn: 'Microsoft Office via Win32 COM Automation (Native Fidelity)',
    labelSi: 'Microsoft Office COM ස්වයංක්‍රීයකරණය (උපරිම පැහැදිලි බව)',
  ),
  nativePdfiumAndOpenXml(
    labelEn: 'Print Helper Native Engine (PDFium + Dart OpenXML / PDF)',
    labelSi: 'Print Helper දේශීය එන්ජිම (PDFium + OpenXML)',
  );

  const ConversionEngineKind({
    required this.labelEn,
    required this.labelSi,
  });

  final String labelEn;
  final String labelSi;
}

enum ConvertTargetFormat {
  // Office / Text / HTML -> PDF
  toPdf(
    extension: 'pdf',
    labelEn: 'PDF Document (.pdf)',
    labelSi: 'PDF ලේඛනය (.pdf)',
    qualityRatingStars: 5,
    expectedQualityNoteEn:
        'Exact pagination, tables, and embedded Noto Sans Sinhala Unicode fonts.',
    expectedQualityNoteSi:
        'පිටු සැකසුම, වගු සහ සිංහල Unicode අකුරු නිවැරදිව ආරක්ෂා කෙරේ.',
  ),
  toPdfA2b(
    extension: 'pdf',
    labelEn: 'PDF/A-2b Archival & Optimized (.pdf)',
    labelSi: 'PDF/A-2b දිගුකාලීන සංරක්ෂණ ආකෘතිය (.pdf)',
    qualityRatingStars: 4,
    expectedQualityNoteEn:
        'Best-effort ISO 19005-2 archival compliance: embeds Noto Sans Sinhala, writes PDF/A XMP metadata, and optimizes streams.',
    expectedQualityNoteSi:
        'සිංහල අකුරු ගොනුව තුළම තැන්පත් කර දිගුකාලීන සංරක්ෂණය සඳහා සකසයි.',
  ),
  // PDF -> Office / Editable Formats
  pdfToWordDocx(
    extension: 'docx',
    labelEn: 'Microsoft Word (.docx)',
    labelSi: 'Microsoft Word ලේඛනය (.docx)',
    qualityRatingStars: 4,
    expectedQualityNoteEn:
        'High quality for single-column reports & tables (especially with MS Word COM). Complex multi-column layouts or floating boxes may need manual adjustment.',
    expectedQualityNoteSi:
        'සාමාන්‍ය ලේඛන සහ වගු සඳහා ඉහළ ගුණාත්මකභාවයක් ලබා දෙයි. සංකීර්ණ තීරු (Multi-column) සැකසුම් අතින් සකස් කිරීමට සිදුවිය හැක.',
  ),
  pdfToExcelXlsx(
    extension: 'xlsx',
    labelEn: 'Microsoft Excel (.xlsx)',
    labelSi: 'Microsoft Excel පැතුරුම්පත (.xlsx)',
    qualityRatingStars: 3,
    expectedQualityNoteEn:
        'Extracts aligned rows and columns into spreadsheet cells; borderless or merged multi-line headers may need manual adjustment.',
    expectedQualityNoteSi:
        'PDF තුළ ඇති වගු Excel කොටු (Cells) බවට පත් කරයි; සංකීර්ණ ඒකාබද්ධ කොටු (Merged cells) සකස් කිරීමට සිදුවිය හැක.',
  ),
  pdfToPowerPointPptx(
    extension: 'pptx',
    labelEn: 'Microsoft PowerPoint (.pptx)',
    labelSi: 'Microsoft PowerPoint ඉදිරිපත් කිරීම (.pptx)',
    qualityRatingStars: 4,
    expectedQualityNoteEn:
        'Creates one presentation slide per PDF page with editable text boxes.',
    expectedQualityNoteSi:
        'සෑම PDF පිටුවක්ම සංස්කරණය කළ හැකි PowerPoint Slide එකක් බවට පත් කරයි.',
  ),
  pdfToRtf(
    extension: 'rtf',
    labelEn: 'Rich Text Format (.rtf)',
    labelSi: 'Rich Text ලේඛනය (.rtf)',
    qualityRatingStars: 4,
    expectedQualityNoteEn:
        'Compatible with WordPad, Word, and LibreOffice; complex vector graphics are omitted.',
    expectedQualityNoteSi:
        'ඕනෑම Word මෘදුකාංගයක විවෘත කළ හැකි Rich Text ගොනුවකි.',
  ),
  pdfToTxt(
    extension: 'txt',
    labelEn: 'Plain Text UTF-8 (.txt)',
    labelSi: 'සරල පෙළ UTF-8 (.txt)',
    qualityRatingStars: 5,
    expectedQualityNoteEn:
        'Extracts clean UTF-8 Sinhala & English text in reading order.',
    expectedQualityNoteSi:
        'සිංහල සහ ඉංග්‍රීසි පෙළ UTF-8 ආකෘතියෙන් උපුටා ගනී.',
  ),
  pdfToHtml(
    extension: 'html',
    labelEn: 'HTML Web Document (.html)',
    labelSi: 'HTML වෙබ් පිටුව (.html)',
    qualityRatingStars: 4,
    expectedQualityNoteEn:
        'Generates semantic UTF-8 HTML5 with headings, paragraphs, and tables.',
    expectedQualityNoteSi:
        'මාතෘකා, ඡේද සහ වගු සහිත HTML5 වෙබ් පිටුවක් නිර්මාණය කරයි.',
  ),
  pdfToMarkdown(
    extension: 'md',
    labelEn: 'Markdown (.md)',
    labelSi: 'Markdown ලේඛනය (.md)',
    qualityRatingStars: 5,
    expectedQualityNoteEn:
        'Preserves headings, bullet lists, and tables in clean Markdown syntax.',
    expectedQualityNoteSi:
        'මාතෘකා සහ වගු Markdown ආකෘතියෙන් සුරකියි.',
  ),
  pdfToEpub(
    extension: 'epub',
    labelEn: 'EPUB E-Book (.epub)',
    labelSi: 'EPUB විද්‍යුත් පොත (.epub)',
    qualityRatingStars: 4,
    expectedQualityNoteEn:
        'Packages flowing chapters into a valid EPUB 3 container; fixed-layout tables may reflow.',
    expectedQualityNoteSi:
        'ජංගම උපාංගවල කියවිය හැකි EPUB 3 විද්‍යුත් පොතක් ලෙස සකසයි.',
  ),
  // PDF <-> Images
  pdfToImages(
    extension: 'png',
    labelEn: 'PDF to Images (PNG / JPG / TIFF / BMP / WebP)',
    labelSi: 'PDF පිටු රූප බවට (PNG / JPG / TIFF / BMP / WebP)',
    qualityRatingStars: 5,
    expectedQualityNoteEn:
        '100% exact visual rendering at your selected DPI (72–600 DPI) and page range.',
    expectedQualityNoteSi:
        'ඔබ තෝරන DPI අගයට අනුව 100% පැහැදිලි රූප බවට පත් කරයි.',
  ),
  imagesToPdf(
    extension: 'pdf',
    labelEn: 'Images to PDF (Multi-Image Reorder, Page Size & Margins)',
    labelSi: 'රූප කිහිපයක් තනි PDF ගොනුවක් බවට (Images to PDF)',
    qualityRatingStars: 5,
    expectedQualityNoteEn:
        'Combines multiple images in your chosen order with configurable paper size and margins.',
    expectedQualityNoteSi:
        'රූප කිහිපයක් පෙළගස්වා තනි PDF ගොනුවක් ලෙස සකසයි.',
  );

  const ConvertTargetFormat({
    required this.extension,
    required this.labelEn,
    required this.labelSi,
    required this.qualityRatingStars,
    required this.expectedQualityNoteEn,
    required this.expectedQualityNoteSi,
  });

  final String extension;
  final String labelEn;
  final String labelSi;
  final int qualityRatingStars;
  final String expectedQualityNoteEn;
  final String expectedQualityNoteSi;
}

class ConvertJobOptions {
  const ConvertJobOptions({
    this.preferredEngine = ConversionEngineKind.nativePdfiumAndOpenXml,
    this.autoRunOcrOnScannedPdf = true,
    this.transcodeLegacySinhalaToUnicode = true,
    this.imageFormat = 'png', // png, jpg, tiff, bmp, webp
    this.imageDpi = 300,
    this.pageRangeExpression = '1-z',
    this.imagesToPdfPaperSize = 'A4',
    this.imagesToPdfMarginMm = 10.0,
    this.optimizePdfStreams = true,
  });

  final ConversionEngineKind preferredEngine;
  final bool autoRunOcrOnScannedPdf;
  final bool transcodeLegacySinhalaToUnicode;
  final String imageFormat;
  final int imageDpi;
  final String pageRangeExpression;
  final String imagesToPdfPaperSize;
  final double imagesToPdfMarginMm;
  final bool optimizePdfStreams;

  ConvertJobOptions copyWith({
    ConversionEngineKind? preferredEngine,
    bool? autoRunOcrOnScannedPdf,
    bool? transcodeLegacySinhalaToUnicode,
    String? imageFormat,
    int? imageDpi,
    String? pageRangeExpression,
    String? imagesToPdfPaperSize,
    double? imagesToPdfMarginMm,
    bool? optimizePdfStreams,
  }) {
    return ConvertJobOptions(
      preferredEngine: preferredEngine ?? this.preferredEngine,
      autoRunOcrOnScannedPdf:
          autoRunOcrOnScannedPdf ?? this.autoRunOcrOnScannedPdf,
      transcodeLegacySinhalaToUnicode: transcodeLegacySinhalaToUnicode ??
          this.transcodeLegacySinhalaToUnicode,
      imageFormat: imageFormat ?? this.imageFormat,
      imageDpi: imageDpi ?? this.imageDpi,
      pageRangeExpression: pageRangeExpression ?? this.pageRangeExpression,
      imagesToPdfPaperSize: imagesToPdfPaperSize ?? this.imagesToPdfPaperSize,
      imagesToPdfMarginMm: imagesToPdfMarginMm ?? this.imagesToPdfMarginMm,
      optimizePdfStreams: optimizePdfStreams ?? this.optimizePdfStreams,
    );
  }
}

enum ConvertBatchItemStatus {
  queued,
  runningOcrPrepass,
  transcodingLegacySinhala,
  converting,
  completed,
  failed,
  cancelled,
}

class ConvertBatchQueueItem {
  const ConvertBatchQueueItem({
    required this.jobId,
    required this.sourceFilePath,
    required this.sourceFileName,
    required this.sourceFormatExtension,
    required this.targetFormat,
    this.status = ConvertBatchItemStatus.queued,
    this.progress = 0.0,
    this.outputFilePath,
    this.outputBytes,
    this.legacySinhalaDetection,
    this.ranOcrPrepass = false,
    this.errorMessage,
    this.elapsedMs = 0,
  });

  final String jobId;
  final String sourceFilePath;
  final String sourceFileName;
  final String sourceFormatExtension;
  final ConvertTargetFormat targetFormat;
  final ConvertBatchItemStatus status;
  final double progress;
  final String? outputFilePath;
  final Uint8List? outputBytes;
  final LegacySinhalaDetectionResult? legacySinhalaDetection;
  final bool ranOcrPrepass;
  final String? errorMessage;
  final int elapsedMs;

  ConvertBatchQueueItem copyWith({
    ConvertTargetFormat? targetFormat,
    ConvertBatchItemStatus? status,
    double? progress,
    String? outputFilePath,
    Uint8List? outputBytes,
    LegacySinhalaDetectionResult? legacySinhalaDetection,
    bool? ranOcrPrepass,
    String? errorMessage,
    int? elapsedMs,
  }) {
    return ConvertBatchQueueItem(
      jobId: jobId,
      sourceFilePath: sourceFilePath,
      sourceFileName: sourceFileName,
      sourceFormatExtension: sourceFormatExtension,
      targetFormat: targetFormat ?? this.targetFormat,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputFilePath: outputFilePath ?? this.outputFilePath,
      outputBytes: outputBytes ?? this.outputBytes,
      legacySinhalaDetection:
          legacySinhalaDetection ?? this.legacySinhalaDetection,
      ranOcrPrepass: ranOcrPrepass ?? this.ranOcrPrepass,
      errorMessage: errorMessage ?? this.errorMessage,
      elapsedMs: elapsedMs ?? this.elapsedMs,
    );
  }
}

// ============================================================================
// 3. Tesseract OCR (sin + eng), Image Cleanup, WIA Scanner & Confidence Models
// ============================================================================

/// Pre-OCR image cleanup pipeline settings:
/// auto-rotate, deskew, denoise, contrast boost, and Sauvola/Otsu binarization.
class OcrImageCleanupConfig {
  const OcrImageCleanupConfig({
    this.autoRotateOrientation = true,
    this.deskewPages = true,
    this.denoiseSpeckles = true,
    this.enhanceContrast = true,
    this.binarizeThreshold = true,
  });

  final bool autoRotateOrientation;
  final bool deskewPages;
  final bool denoiseSpeckles;
  final bool enhanceContrast;
  final bool binarizeThreshold;

  OcrImageCleanupConfig copyWith({
    bool? autoRotateOrientation,
    bool? deskewPages,
    bool? denoiseSpeckles,
    bool? enhanceContrast,
    bool? binarizeThreshold,
  }) {
    return OcrImageCleanupConfig(
      autoRotateOrientation:
          autoRotateOrientation ?? this.autoRotateOrientation,
      deskewPages: deskewPages ?? this.deskewPages,
      denoiseSpeckles: denoiseSpeckles ?? this.denoiseSpeckles,
      enhanceContrast: enhanceContrast ?? this.enhanceContrast,
      binarizeThreshold: binarizeThreshold ?? this.binarizeThreshold,
    );
  }
}

class OcrLanguagePackInfo {
  const OcrLanguagePackInfo({
    required this.langCode,
    required this.displayNameEn,
    required this.displayNameSi,
    required this.trainedDataFileName,
    required this.sizeMb,
    required this.isInstalled,
    this.localPath,
  });

  final String langCode; // 'sin' or 'eng'
  final String displayNameEn;
  final String displayNameSi;
  final String trainedDataFileName;
  final double sizeMb;
  final bool isInstalled;
  final String? localPath;

  OcrLanguagePackInfo copyWith({
    bool? isInstalled,
    String? localPath,
  }) {
    return OcrLanguagePackInfo(
      langCode: langCode,
      displayNameEn: displayNameEn,
      displayNameSi: displayNameSi,
      trainedDataFileName: trainedDataFileName,
      sizeMb: sizeMb,
      isInstalled: isInstalled ?? this.isInstalled,
      localPath: localPath ?? this.localPath,
    );
  }
}

class OcrPageRecognitionReport {
  const OcrPageRecognitionReport({
    required this.pageNumber,
    required this.recognizedText,
    required this.confidencePercent,
    required this.detectedDeskewDegrees,
    required this.autoRotatedDegrees,
    required this.lowConfidenceWords,
  });

  final int pageNumber;
  final String recognizedText;
  final double confidencePercent; // 0.0 to 100.0
  final double detectedDeskewDegrees;
  final int autoRotatedDegrees;
  final List<String> lowConfidenceWords;

  /// Flags low-quality Sinhala OCR when page confidence drops below 78%.
  bool get hasLowSinhalaConfidenceWarning => confidencePercent < 78.0;
}

class OcrExecutionResult {
  const OcrExecutionResult({
    required this.sourceFileName,
    required this.languagesUsed,
    required this.pageReports,
    required this.combinedRecognizedText,
    required this.searchablePdfBytes,
    required this.averageConfidencePercent,
    required this.hasConfidenceWarnings,
    required this.confidenceWarningMessageEn,
    required this.confidenceWarningMessageSi,
    required this.cleanupApplied,
    required this.elapsedMs,
  });

  final String sourceFileName;
  final List<String> languagesUsed; // e.g. ['sin', 'eng']
  final List<OcrPageRecognitionReport> pageReports;
  final String combinedRecognizedText;
  final Uint8List searchablePdfBytes;
  final double averageConfidencePercent;
  final bool hasConfidenceWarnings;
  final String confidenceWarningMessageEn;
  final String confidenceWarningMessageSi;
  final OcrImageCleanupConfig cleanupApplied;
  final int elapsedMs;
}

/// Represents a physical scanner discovered via Windows Image Acquisition (WIA 2.0)
/// or an imported multi-page scan batch.
class WiaScannerDevice {
  const WiaScannerDevice({
    required this.deviceId,
    required this.name,
    required this.manufacturer,
    required this.supportsAutoDocumentFeeder,
    required this.maxOpticalDpi,
  });

  final String deviceId;
  final String name;
  final String manufacturer;
  final bool supportsAutoDocumentFeeder;
  final int maxOpticalDpi;
}

/// Matrix row for the Automated Format Conversion Test Suite.
class ConversionMatrixBenchmarkRow {
  const ConversionMatrixBenchmarkRow({
    required this.testCaseId,
    required this.sourceFormat,
    required this.targetFormat,
    required this.engineUsed,
    required this.sinhalaUnicodePreserved,
    required this.legacySinhalaHandled,
    required this.passed,
    required this.outputSizeBytes,
    required this.notes,
  });

  final String testCaseId;
  final String sourceFormat;
  final String targetFormat;
  final String engineUsed;
  final bool sinhalaUnicodePreserved;
  final bool legacySinhalaHandled;
  final bool passed;
  final int outputSizeBytes;
  final String notes;
}
