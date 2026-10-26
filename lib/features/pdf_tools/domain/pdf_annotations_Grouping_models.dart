import 'dart:math' as math;
import 'dart:typed_data';

// ============================================================================
// 1. Standard PDF Annotation Models (ISO 32000-1 /Annot Subtypes)
// ============================================================================

enum PdfAnnotationToolType {
  selectPan(pdfSubtype: 'None', labelEn: 'Select / Pan', labelSi: 'තෝරන්න'),
  highlight(pdfSubtype: '/Highlight', labelEn: 'Highlight', labelSi: 'උද්දීපනය (Highlight)'),
  underline(pdfSubtype: '/Underline', labelEn: 'Underline', labelSi: 'යටින් ඉර (Underline)'),
  strikethrough(pdfSubtype: '/StrikeOut', labelEn: 'Strikethrough', labelSi: 'කපා හැරීම (StrikeOut)'),
  squiggly(pdfSubtype: '/Squiggly', labelEn: 'Squiggly', labelSi: 'රැලි ඉර (Squiggly)'),
  freehandPen(pdfSubtype: '/Ink', labelEn: 'Freehand Pen', labelSi: 'පෑන (Ink)'),
  rectangle(pdfSubtype: '/Square', labelEn: 'Rectangle', labelSi: 'සෘජුකෝණාස්‍රය'),
  ellipse(pdfSubtype: '/Circle', labelEn: 'Ellipse', labelSi: 'ඉලිප්සය'),
  line(pdfSubtype: '/Line', labelEn: 'Line', labelSi: 'රේඛාව'),
  arrow(pdfSubtype: '/Line', labelEn: 'Arrow', labelSi: 'ඊතලය'),
  textBox(pdfSubtype: '/FreeText', labelEn: 'Text Box', labelSi: 'පෙළ කොටුව (FreeText)'),
  stickyNote(pdfSubtype: '/Text', labelEn: 'Sticky Note', labelSi: 'සටහන (Note)'),
  stamp(pdfSubtype: '/Stamp', labelEn: 'Stamp', labelSi: 'මුද්‍රාව (Stamp)'),
  measurement(pdfSubtype: '/Line', labelEn: 'Measure Distance', labelSi: 'දුර මැනීම (Measure)'),
  eraser(pdfSubtype: 'Eraser', labelEn: 'Eraser', labelSi: 'මකනය (Eraser)');

  const PdfAnnotationToolType({
    required this.pdfSubtype,
    required this.labelEn,
    required this.labelSi,
  });

  final String pdfSubtype;
  final String labelEn;
  final String labelSi;
}

class PdfPoint {
  const PdfPoint(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(PdfPoint other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return math.sqrt((dx * dx) + (dy * dy));
  }
}

class PdfRectBounds {
  const PdfRectBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool containsPoint(PdfPoint pt) {
    return pt.x >= left && pt.x <= right && pt.y >= top && pt.y <= bottom;
  }

  PdfRectBounds copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    return PdfRectBounds(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// Represents a single annotation placed on a PDF page.
/// Serializes to standard ISO 32000-1 PDF `/Annot` dictionary objects so external
/// PDF viewers (Adobe Acrobat, Edge, Chrome, macOS Preview) recognize and list them.
class PdfAnnotationItem {
  const PdfAnnotationItem({
    required this.id,
    required this.pageNumber,
    required this.toolType,
    required this.bounds,
    this.colorHex = 0xFFFFEB3B,
    this.strokeWidth = 2.5,
    this.opacity = 0.75,
    this.contents = '',
    this.author = 'Print Helper User',
    this.createdAt,
    this.inkPoints = const <PdfPoint>[],
    this.stampLabel = 'APPROVED / අනුමතයි',
    this.measurementScaleMmPerPt = 25.4 / 72.0,
  });

  final String id;
  final int pageNumber; // 1-based page number
  final PdfAnnotationToolType toolType;
  final PdfRectBounds bounds;
  final int colorHex;
  final double strokeWidth;
  final double opacity;
  final String contents;
  final String author;
  final DateTime? createdAt;
  final List<PdfPoint> inkPoints;
  final String stampLabel;
  final double measurementScaleMmPerPt;

  /// Computes the real-world measured distance in millimeters for `measurement` annotations.
  double get measuredDistanceMm {
    if (inkPoints.length >= 2) {
      return inkPoints.first.distanceTo(inkPoints.last) *
          measurementScaleMmPerPt;
    }
    final diagPt =
        math.sqrt((bounds.width * bounds.width) + (bounds.height * bounds.height));
    return diagPt * measurementScaleMmPerPt;
  }

  /// Generates the ISO 32000-1 standard `/Annot` dictionary representation
  /// used when embedding non-flattened interactive PDF annotations.
  String toPdfAnnotationDictionaryString({double pageHeightPt = 841.89}) {
    final llx = bounds.left.toStringAsFixed(2);
    final lly = (pageHeightPt - bounds.bottom).toStringAsFixed(2);
    final urx = bounds.right.toStringAsFixed(2);
    final ury = (pageHeightPt - bounds.top).toStringAsFixed(2);

    final r = (((colorHex >> 16) & 0xFF) / 255.0).toStringAsFixed(3);
    final g = (((colorHex >> 8) & 0xFF) / 255.0).toStringAsFixed(3);
    final b = ((colorHex & 0xFF) / 255.0).toStringAsFixed(3);
    final ca = opacity.clamp(0.05, 1.0).toStringAsFixed(2);
    final escapedContents = contents
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');

    final buffer = StringBuffer()
      ..writeln('<<')
      ..writeln('  /Type /Annot')
      ..writeln('  /Subtype ${toolType.pdfSubtype}')
      ..writeln('  /NM ($id)')
      ..writeln('  /Rect [$llx $lly $urx $ury]')
      ..writeln('  /C [$r $g $b]')
      ..writeln('  /CA $ca')
      ..writeln('  /W ${strokeWidth.toStringAsFixed(1)}')
      ..writeln('  /T ($author)')
      ..writeln('  /Contents ($escapedContents)')
      ..writeln('  /F 4'); // Print flag enabled (bit 3 = 4) so annotations also print

    if (toolType == PdfAnnotationToolType.arrow) {
      buffer.writeln('  /LE [/None /ClosedArrow]');
    } else if (toolType == PdfAnnotationToolType.stamp) {
      buffer.writeln('  /Name /Approved');
    } else if (toolType == PdfAnnotationToolType.measurement) {
      buffer.writeln(
        '  /Measure << /Type /Measure /Subtype /RL /R (${measuredDistanceMm.toStringAsFixed(2)} mm) >>',
      );
    }

    buffer.write('>>');
    return buffer.toString();
  }

  PdfAnnotationItem copyWith({
    PdfRectBounds? bounds,
    int? colorHex,
    double? strokeWidth,
    double? opacity,
    String? contents,
  }) {
    return PdfAnnotationItem(
      id: id,
      pageNumber: pageNumber,
      toolType: toolType,
      bounds: bounds ?? this.bounds,
      colorHex: colorHex ?? this.colorHex,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      contents: contents ?? this.contents,
      author: author,
      createdAt: createdAt,
      inkPoints: inkPoints,
      stampLabel: stampLabel,
      measurementScaleMmPerPt: measurementScaleMmPerPt,
    );
  }
}

// ============================================================================
// 2. Visual Signatures, Initials, Date Stamps & PKCS#12 Digital Signatures
// ============================================================================

enum SignatureSourceMode {
  drawnStroke,
  typedText,
  importedImage,
}

/// A reusable visual signature or initials profile saved by the user.
class SavedSignatureProfile {
  const SavedSignatureProfile({
    required this.id,
    required this.label,
    required this.sourceMode,
    required this.signerFullName,
    required this.initialsText,
    this.typedSignatureText = '',
    this.strokePoints = const <PdfPoint>[],
    this.imageBytes,
    this.inkColorHex = 0xFF0D47A1,
  });

  final String id;
  final String label;
  final SignatureSourceMode sourceMode;
  final String signerFullName;
  final String initialsText;
  final String typedSignatureText;
  final List<PdfPoint> strokePoints;
  final Uint8List? imageBytes;
  final int inkColorHex;
}

/// A placed visual signature, initials box, or date field on a PDF page.
class PlacedPageSignature {
  const PlacedPageSignature({
    required this.placementId,
    required this.profileId,
    required this.pageNumber,
    required this.bounds,
    required this.displayText,
    required this.includeDateStamp,
    required this.isInitialsOnly,
    required this.dateFormatted,
    this.inkColorHex = 0xFF0D47A1,
    this.strokePoints = const <PdfPoint>[],
    this.imageBytes,
  });

  final String placementId;
  final String profileId;
  final int pageNumber;
  final PdfRectBounds bounds;
  final String displayText;
  final bool includeDateStamp;
  final bool isInitialsOnly;
  final String dateFormatted;
  final int inkColorHex;
  final List<PdfPoint> strokePoints;
  final Uint8List? imageBytes;

  PlacedPageSignature copyWith({PdfRectBounds? bounds}) {
    return PlacedPageSignature(
      placementId: placementId,
      profileId: profileId,
      pageNumber: pageNumber,
      bounds: bounds ?? this.bounds,
      displayText: displayText,
      includeDateStamp: includeDateStamp,
      isInitialsOnly: isInitialsOnly,
      dateFormatted: dateFormatted,
      inkColorHex: inkColorHex,
      strokePoints: strokePoints,
      imageBytes: imageBytes,
    );
  }
}

enum DigitalSignatureValidityStatus {
  validUntampered,
  invalidModifiedAfterSigning,
  certificateExpiredOrUntrusted,
  unsigned,
}

/// Cryptographic PKCS#12 (`.p12` / `.pfx`) digital signature record & validation report.
class Pkcs12DigitalSignatureRecord {
  const Pkcs12DigitalSignatureRecord({
    required this.signatureId,
    required this.signerCommonName,
    required this.signerOrganization,
    required this.certificateSerialHex,
    required this.sha256FingerprintHex,
    required this.documentDigestSha256Hex,
    required this.reason,
    required this.location,
    required this.signedAtUtc,
    required this.validityStatus,
  });

  final String signatureId;
  final String signerCommonName;
  final String signerOrganization;
  final String certificateSerialHex;
  final String sha256FingerprintHex;
  final String documentDigestSha256Hex;
  final String reason;
  final String location;
  final DateTime signedAtUtc;
  final DigitalSignatureValidityStatus validityStatus;

  bool get isValid =>
      validityStatus == DigitalSignatureValidityStatus.validUntampered;
}

// ============================================================================
// 3. Interactive AcroForm Fields, Data Import/Export & Auto-Detection
// ============================================================================

enum PdfAcroFormFieldType {
  textField,
  checkbox,
  radioGroup,
  dropdown,
  dateField,
  initialsField,
}

class PdfAcroFormField {
  const PdfAcroFormField({
    required this.fieldName,
    required this.label,
    required this.fieldType,
    required this.pageNumber,
    required this.bounds,
    this.textValue = '',
    this.checkedValue = false,
    this.selectedOption = '',
    this.options = const <String>[],
    this.isAutoDetectedFromFlatPage = false,
    this.isFlattened = false,
  });

  final String fieldName;
  final String label;
  final PdfAcroFormFieldType fieldType;
  final int pageNumber;
  final PdfRectBounds bounds;
  final String textValue;
  final bool checkedValue;
  final String selectedOption;
  final List<String> options;
  final bool isAutoDetectedFromFlatPage;
  final bool isFlattened;

  dynamic get effectiveValue {
    return switch (fieldType) {
      PdfAcroFormFieldType.checkbox => checkedValue,
      PdfAcroFormFieldType.radioGroup ||
      PdfAcroFormFieldType.dropdown =>
        selectedOption,
      _ => textValue,
    };
  }

  PdfAcroFormField copyWith({
    String? textValue,
    bool? checkedValue,
    String? selectedOption,
    bool? isFlattened,
  }) {
    return PdfAcroFormField(
      fieldName: fieldName,
      label: label,
      fieldType: fieldType,
      pageNumber: pageNumber,
      bounds: bounds,
      textValue: textValue ?? this.textValue,
      checkedValue: checkedValue ?? this.checkedValue,
      selectedOption: selectedOption ?? this.selectedOption,
      options: options,
      isAutoDetectedFromFlatPage: isAutoDetectedFromFlatPage,
      isFlattened: isFlattened ?? this.isFlattened,
    );
  }
}
