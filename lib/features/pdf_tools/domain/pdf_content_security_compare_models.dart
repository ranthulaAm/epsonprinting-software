import 'dart:typed_data';

import 'pdf_annotations_Grouping_models.dart';

// ============================================================================
// 1. Content Editing Models (Add Text, Whiteout+Overlay, Images, Links, Font Check)
// ============================================================================

enum PdfTextAlignment {
  left,
  center,
  right,
  justify,
}

/// Availability status of a font referenced inside an existing PDF when the user
/// selects text to replace via Whiteout + Overlay.
class EmbeddedPdfFontAvailability {
  const EmbeddedPdfFontAvailability({
    required this.embeddedFontName,
    required this.isAvailableLocally,
    required this.substituteFontFamily,
    required this.noticeEn,
    required this.noticeSi,
  });

  final String embeddedFontName;
  final bool isAvailableLocally;
  final String substituteFontFamily;
  final String noticeEn;
  final String noticeSi;
}

/// Represents either:
/// - A new text block added anywhere on a page (`isWhiteoutReplacement == false`), OR
/// - An existing text replacement using an opaque background-matched Whiteout box
///   plus a new Unicode text overlay (`isWhiteoutReplacement == true`).
class PdfContentTextEditItem {
  const PdfContentTextEditItem({
    required this.id,
    required this.pageNumber,
    required this.bounds,
    required this.text,
    this.fontFamily = 'NotoSansSinhala',
    this.fontSizePt = 12.0,
    this.textColorHex = 0xFF1A1C1E,
    this.alignment = PdfTextAlignment.left,
    this.isBold = false,
    this.isWhiteoutReplacement = false,
    this.whiteoutFillColorHex = 0xFFFFFFFF,
    this.originalEmbeddedFontName,
  });

  final String id;
  final int pageNumber;
  final PdfRectBounds bounds;
  final String text;
  final String fontFamily;
  final double fontSizePt;
  final int textColorHex;
  final PdfTextAlignment alignment;
  final bool isBold;
  final bool isWhiteoutReplacement;
  final int whiteoutFillColorHex;
  final String? originalEmbeddedFontName;

  PdfContentTextEditItem copyWith({
    PdfRectBounds? bounds,
    String? text,
    String? fontFamily,
    double? fontSizePt,
    int? textColorHex,
    PdfTextAlignment? alignment,
    bool? isBold,
  }) {
    return PdfContentTextEditItem(
      id: id,
      pageNumber: pageNumber,
      bounds: bounds ?? this.bounds,
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizePt: fontSizePt ?? this.fontSizePt,
      textColorHex: textColorHex ?? this.textColorHex,
      alignment: alignment ?? this.alignment,
      isBold: isBold ?? this.isBold,
      isWhiteoutReplacement: isWhiteoutReplacement,
      whiteoutFillColorHex: whiteoutFillColorHex,
      originalEmbeddedFontName: originalEmbeddedFontName,
    );
  }
}

/// Represents an image object added, moved, or resized on a PDF page.
class PdfContentImageObject {
  const PdfContentImageObject({
    required this.id,
    required this.pageNumber,
    required this.bounds,
    required this.label,
    required this.imageBytes,
    this.rotationDegrees = 0,
  });

  final String id;
  final int pageNumber;
  final PdfRectBounds bounds;
  final String label;
  final Uint8List imageBytes;
  final int rotationDegrees;

  PdfContentImageObject copyWith({
    PdfRectBounds? bounds,
    int? rotationDegrees,
  }) {
    return PdfContentImageObject(
      id: id,
      pageNumber: pageNumber,
      bounds: bounds ?? this.bounds,
      label: label,
      imageBytes: imageBytes,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }
}

enum PdfLinkActionType {
  externalUrl,
  internalPageNumber,
}

/// Represents an interactive clickable hyperlink (`/Subtype /Link`) on a PDF page.
class PdfEditableLinkRegion {
  const PdfEditableLinkRegion({
    required this.id,
    required this.pageNumber,
    required this.bounds,
    required this.actionType,
    this.targetUrl = 'https://',
    this.targetPageNumber = 1,
    this.visibleBorder = false,
  });

  final String id;
  final int pageNumber;
  final PdfRectBounds bounds;
  final PdfLinkActionType actionType;
  final String targetUrl;
  final int targetPageNumber;
  final bool visibleBorder;

  PdfEditableLinkRegion copyWith({
    PdfRectBounds? bounds,
    PdfLinkActionType? actionType,
    String? targetUrl,
    int? targetPageNumber,
    bool? visibleBorder,
  }) {
    return PdfEditableLinkRegion(
      id: id,
      pageNumber: pageNumber,
      bounds: bounds ?? this.bounds,
      actionType: actionType ?? this.actionType,
      targetUrl: targetUrl ?? this.targetUrl,
      targetPageNumber: targetPageNumber ?? this.targetPageNumber,
      visibleBorder: visibleBorder ?? this.visibleBorder,
    );
  }
}

// ============================================================================
// 2. Security, Encryption (AES-256), Permanent Redaction & Metadata Sanitization
// ============================================================================

/// AES-256 Encryption and granular PDF permission flags (`qpdf --encrypt ... 256 --`).
class PdfSecurityEncryptionConfig {
  const PdfSecurityEncryptionConfig({
    this.enableEncryption = false,
    this.userOpenPassword = '',
    this.ownerPermissionsPassword = '',
    this.allowPrinting = true,
    this.allowCopyingTextAndGraphics = true,
    this.allowModifyingContent = true,
    this.allowAnnotationsAndForms = true,
  });

  final bool enableEncryption;
  final String userOpenPassword;
  final String ownerPermissionsPassword;
  final bool allowPrinting;
  final bool allowCopyingTextAndGraphics;
  final bool allowModifyingContent;
  final bool allowAnnotationsAndForms;

  PdfSecurityEncryptionConfig copyWith({
    bool? enableEncryption,
    String? userOpenPassword,
    String? ownerPermissionsPassword,
    bool? allowPrinting,
    bool? allowCopyingTextAndGraphics,
    bool? allowModifyingContent,
    bool? allowAnnotationsAndForms,
  }) {
    return PdfSecurityEncryptionConfig(
      enableEncryption: enableEncryption ?? this.enableEncryption,
      userOpenPassword: userOpenPassword ?? this.userOpenPassword,
      ownerPermissionsPassword:
          ownerPermissionsPassword ?? this.ownerPermissionsPassword,
      allowPrinting: allowPrinting ?? this.allowPrinting,
      allowCopyingTextAndGraphics:
          allowCopyingTextAndGraphics ?? this.allowCopyingTextAndGraphics,
      allowModifyingContent:
          allowModifyingContent ?? this.allowModifyingContent,
      allowAnnotationsAndForms:
          allowAnnotationsAndForms ?? this.allowAnnotationsAndForms,
    );
  }
}

enum RedactionTargetKind {
  textSearchMatch,
  rectangularArea,
}

/// Represents a permanent redaction mark (either created via Search-and-Redact
/// or by drawing an area box). When applied, the underlying text/pixels are
/// permanently stripped from the page content stream—never merely covered.
class PdfRedactionMark {
  const PdfRedactionMark({
    required this.id,
    required this.pageNumber,
    required this.kind,
    required this.bounds,
    this.matchedText = '',
    this.overlayCodeText = 'REDACTED',
    this.fillColorHex = 0xFF000000,
    this.isAppliedPermanently = false,
  });

  final String id;
  final int pageNumber;
  final RedactionTargetKind kind;
  final PdfRectBounds bounds;
  final String matchedText;
  final String overlayCodeText;
  final int fillColorHex;
  final bool isAppliedPermanently;

  PdfRedactionMark copyWith({bool? isAppliedPermanently}) {
    return PdfRedactionMark(
      id: id,
      pageNumber: pageNumber,
      kind: kind,
      bounds: bounds,
      matchedText: matchedText,
      overlayCodeText: overlayCodeText,
      fillColorHex: fillColorHex,
      isAppliedPermanently: isAppliedPermanently ?? this.isAppliedPermanently,
    );
  }
}

/// PDF Document Info (`/Info`) & XMP Metadata fields.
class PdfDocumentMetadataInfo {
  const PdfDocumentMetadataInfo({
    this.title = '',
    this.author = '',
    this.subject = '',
    this.keywords = '',
    this.creator = 'Print Helper Offline PDF Toolkit',
    this.producer = 'Print Helper (PDFium / qpdf / Dart PDF)',
    this.creationDateIso = '',
    this.modificationDateIso = '',
  });

  final String title;
  final String author;
  final String subject;
  final String keywords;
  final String creator;
  final String producer;
  final String creationDateIso;
  final String modificationDateIso;

  /// Returns a completely blank metadata object used by "Remove Hidden Data".
  static const PdfDocumentMetadataInfo sanitizedEmpty = PdfDocumentMetadataInfo(
    title: '',
    author: '',
    subject: '',
    keywords: '',
    creator: '',
    producer: '',
    creationDateIso: '',
    modificationDateIso: '',
  );

  PdfDocumentMetadataInfo copyWith({
    String? title,
    String? author,
    String? subject,
    String? keywords,
    String? creator,
    String? producer,
  }) {
    return PdfDocumentMetadataInfo(
      title: title ?? this.title,
      author: author ?? this.author,
      subject: subject ?? this.subject,
      keywords: keywords ?? this.keywords,
      creator: creator ?? this.creator,
      producer: producer ?? this.producer,
      creationDateIso: creationDateIso,
      modificationDateIso: modificationDateIso,
    );
  }
}

/// Summary report returned after running "Remove Hidden Data".
class HiddenDataSanitizationReport {
  const HiddenDataSanitizationReport({
    required this.metadataFieldsCleared,
    required this.commentsAndAnnotationsRemoved,
    required this.embeddedAttachmentsRemoved,
    required this.javascriptAndActionsStripped,
    required this.bytesSaved,
  });

  final int metadataFieldsCleared;
  final int commentsAndAnnotationsRemoved;
  final int embeddedAttachmentsRemoved;
  final int javascriptAndActionsStripped;
  final int bytesSaved;
}

// ============================================================================
// 3. Document Compare Models (Side-by-Side Visual Diff & Text Diff of 2 PDFs)
// ============================================================================

enum PdfDiffLineKind {
  unchanged,
  addedInRight,
  removedFromLeft,
  modifiedInBoth,
}

class PdfTextDiffSegment {
  const PdfTextDiffSegment({
    required this.pageNumber,
    required this.lineNumber,
    required this.kind,
    required this.leftText,
    required this.rightText,
  });

  final int pageNumber;
  final int lineNumber;
  final PdfDiffLineKind kind;
  final String leftText;
  final String rightText;
}

class PdfVisualPageDiffMetric {
  const PdfVisualPageDiffMetric({
    required this.pageNumber,
    required this.visualDifferencePercent,
    required this.changedRegionBounds,
  });

  final int pageNumber;
  final double visualDifferencePercent; // 0.0 to 100.0
  final List<PdfRectBounds> changedRegionBounds;

  bool get hasVisualChanges => visualDifferencePercent > 0.01;
}

class PdfDocumentComparisonReport {
  const PdfDocumentComparisonReport({
    required this.leftFileName,
    required this.rightFileName,
    required this.leftTotalPages,
    required this.rightTotalPages,
    required this.textDiffSegments,
    required this.visualPageDiffs,
    required this.addedLinesCount,
    required this.removedLinesCount,
    required this.modifiedLinesCount,
  });

  final String leftFileName;
  final String rightFileName;
  final int leftTotalPages;
  final int rightTotalPages;
  final List<PdfTextDiffSegment> textDiffSegments;
  final List<PdfVisualPageDiffMetric> visualPageDiffs;
  final int addedLinesCount;
  final int removedLinesCount;
  final int modifiedLinesCount;

  bool get areIdentical =>
      addedLinesCount == 0 &&
      removedLinesCount == 0 &&
      modifiedLinesCount == 0 &&
      visualPageDiffs.every((v) => !v.hasVisualChanges);
}
