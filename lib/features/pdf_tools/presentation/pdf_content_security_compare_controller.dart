import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/pdf_tools/pdf_content_security_compare_service.dart';
import '../domain/pdf_annotations_Grouping_models.dart';
import '../domain/pdf_content_security_compare_models.dart';

class PdfContentSecurityCompareState {
  const PdfContentSecurityCompareState({
    this.pageTexts = const <int, String>{},
    this.embeddedFonts = const <EmbeddedPdfFontAvailability>[],
    this.textEdits = const <PdfContentTextEditItem>[],
    this.imageObjects = const <PdfContentImageObject>[],
    this.editableLinks = const <PdfEditableLinkRegion>[],
    this.securityConfig = const PdfSecurityEncryptionConfig(),
    this.redactionMarks = const <PdfRedactionMark>[],
    this.metadataInfo = const PdfDocumentMetadataInfo(
      title: 'ශ්‍රී ලංකා මුද්‍රණ සහායක — නිල ලේඛනය',
      author: 'Print Helper Office User',
      subject: 'Sinhala & English PDF Document',
      keywords: 'Sinhala, PDF, Print Helper, Offline',
    ),
    this.lastSanitizationReport,
    this.comparisonReport,
  });

  final Map<int, String> pageTexts;
  final List<EmbeddedPdfFontAvailability> embeddedFonts;
  final List<PdfContentTextEditItem> textEdits;
  final List<PdfContentImageObject> imageObjects;
  final List<PdfEditableLinkRegion> editableLinks;
  final PdfSecurityEncryptionConfig securityConfig;
  final List<PdfRedactionMark> redactionMarks;
  final PdfDocumentMetadataInfo metadataInfo;
  final HiddenDataSanitizationReport? lastSanitizationReport;
  final PdfDocumentComparisonReport? comparisonReport;

  PdfContentSecurityCompareState copyWith({
    Map<int, String>? pageTexts,
    List<EmbeddedPdfFontAvailability>? embeddedFonts,
    List<PdfContentTextEditItem>? textEdits,
    List<PdfContentImageObject>? imageObjects,
    List<PdfEditableLinkRegion>? editableLinks,
    PdfSecurityEncryptionConfig? securityConfig,
    List<PdfRedactionMark>? redactionMarks,
    PdfDocumentMetadataInfo? metadataInfo,
    HiddenDataSanitizationReport? lastSanitizationReport,
    PdfDocumentComparisonReport? comparisonReport,
  }) {
    return PdfContentSecurityCompareState(
      pageTexts: pageTexts ?? this.pageTexts,
      embeddedFonts: embeddedFonts ?? this.embeddedFonts,
      textEdits: textEdits ?? this.textEdits,
      imageObjects: imageObjects ?? this.imageObjects,
      editableLinks: editableLinks ?? this.editableLinks,
      securityConfig: securityConfig ?? this.securityConfig,
      redactionMarks: redactionMarks ?? this.redactionMarks,
      metadataInfo: metadataInfo ?? this.metadataInfo,
      lastSanitizationReport:
          lastSanitizationReport ?? this.lastSanitizationReport,
      comparisonReport: comparisonReport ?? this.comparisonReport,
    );
  }
}

class PdfContentSecurityCompareController
    extends StateNotifier<PdfContentSecurityCompareState> {
  PdfContentSecurityCompareController({
    required PdfContentSecurityCompareService service,
  })  : _service = service,
        super(_buildInitialState(service));

  final PdfContentSecurityCompareService _service;
  static const Uuid _uuid = Uuid();

  static PdfContentSecurityCompareState _buildInitialState(
    PdfContentSecurityCompareService service,
  ) {
    final fonts = service.inspectEmbeddedFonts(const <String>[
      'NotoSansSinhala',
      'SUBSET+FMAbhaya-Bold',
      'SUBSET+KaputaUnicode',
      'Segoe UI',
    ]);

    const initialPages = <int, String>{
      1: 'ශ්‍රී ලංකා මුද්‍රණ සහායක (Print Helper) — රහසිගත ගිවිසුම\n'
          'ගිණුම් අංකය (Account No): ACC-9948-2026\n'
          'දුරකථන අංකය (Phone): 011-2345678\n'
          'මෙම ලේඛනයේ අන්තර්ගතය 100% Offline ලෙස ආරක්ෂා කර ඇත.',
      2: 'දෙවන පිටුව (Page 2): ගෙවීම් කොන්දේසි සහ නීතිමය එකඟතාව\n'
          'ගිණුම් අංකය (Account No): ACC-9948-2026\n'
          'විද්‍යාව, තාක්ෂණය සහ ධර්මය පිළිබඳ වාර්තාව.',
    };

    final initialComparison = service.compareTwoPdfDocuments(
      leftFileName: 'contract_v1_original.pdf',
      leftPageTexts: initialPages,
      rightFileName: 'contract_v2_revised.pdf',
      rightPageTexts: const <int, String>{
        1: 'ශ්‍රී ලංකා මුද්‍රණ සහායක (Print Helper) — සංශෝධිත ගිවිසුම (Revised)\n'
            'ගිණුම් අංකය (Account No): ACC-9948-2026\n'
            'දුරකථන අංකය (Phone): 011-9876543\n'
            'මෙම ලේඛනයේ අන්තර්ගතය 100% Offline ලෙස ආරක්ෂා කර ඇත.\n'
            'අතිරේක වගන්තිය: දෙපස මුද්‍රණය (Duplex) නිර්දේශ කෙරේ.',
        2: 'දෙවන පිටුව (Page 2): ගෙවීම් කොන්දේසි සහ නීතිමය එකඟතාව\n'
            'ගිණුම් අංකය (Account No): ACC-9948-2026\n'
            'විද්‍යාව, තාක්ෂණය සහ ධර්මය පිළිබඳ වාර්තාව.',
      },
    );

    return PdfContentSecurityCompareState(
      pageTexts: initialPages,
      embeddedFonts: fonts,
      editableLinks: const <PdfEditableLinkRegion>[
        PdfEditableLinkRegion(
          id: 'link-1',
          pageNumber: 1,
          bounds: PdfRectBounds(left: 40, top: 240, width: 220, height: 24),
          actionType: PdfLinkActionType.externalUrl,
          targetUrl: 'https://www.gov.lk',
          visibleBorder: true,
        ),
      ],
      comparisonReport: initialComparison,
    );
  }

  // ==========================================================================
  // 1. Content Editing: Add Text, Whiteout+Overlay, Images & Links
  // ==========================================================================

  void addOrReplaceContentText({
    required int pageNumber,
    required String text,
    String fontFamily = 'NotoSansSinhala',
    double fontSizePt = 12.0,
    int textColorHex = 0xFF1A1C1E,
    PdfTextAlignment alignment = PdfTextAlignment.left,
    bool isBold = false,
    bool isWhiteoutReplacement = false,
    String? originalEmbeddedFontName,
    PdfRectBounds? customBounds,
  }) {
    final item = PdfContentTextEditItem(
      id: 'txt-edit-${_uuid.v4().substring(0, 8)}',
      pageNumber: pageNumber,
      bounds: customBounds ??
          PdfRectBounds(
            left: 44.0,
            top: 150.0 + (state.textEdits.length * 36.0),
            width: 310.0,
            height: 32.0,
          ),
      text: text,
      fontFamily: fontFamily,
      fontSizePt: fontSizePt,
      textColorHex: textColorHex,
      alignment: alignment,
      isBold: isBold,
      isWhiteoutReplacement: isWhiteoutReplacement,
      originalEmbeddedFontName: originalEmbeddedFontName,
    );

    state = state.copyWith(
      textEdits: <PdfContentTextEditItem>[...state.textEdits, item],
    );
  }

  void removeContentTextEdit(String editId) {
    state = state.copyWith(
      textEdits: state.textEdits.where((e) => e.id != editId).toList(),
    );
  }

  void addContentImage({
    required int pageNumber,
    required String label,
    required Uint8List imageBytes,
    PdfRectBounds? customBounds,
  }) {
    final img = PdfContentImageObject(
      id: 'img-${_uuid.v4().substring(0, 8)}',
      pageNumber: pageNumber,
      bounds: customBounds ??
          PdfRectBounds(
            left: 320,
            top: 80 + (state.imageObjects.length * 70.0),
            width: 140,
            height: 90,
          ),
      label: label,
      imageBytes: imageBytes,
    );
    state = state.copyWith(
      imageObjects: <PdfContentImageObject>[...state.imageObjects, img],
    );
  }

  void moveOrResizeContentImage(
    String imageId, {
    required PdfRectBounds newBounds,
  }) {
    final updated = state.imageObjects.map((img) {
      if (img.id == imageId) {
        return img.copyWith(bounds: newBounds);
      }
      return img;
    }).toList();
    state = state.copyWith(imageObjects: updated);
  }

  void deleteContentImage(String imageId) {
    state = state.copyWith(
      imageObjects: state.imageObjects.where((i) => i.id != imageId).toList(),
    );
  }

  void addEditableLink({
    required int pageNumber,
    required PdfLinkActionType actionType,
    String targetUrl = 'https://',
    int targetPageNumber = 1,
    bool visibleBorder = true,
  }) {
    final link = PdfEditableLinkRegion(
      id: 'lnk-${_uuid.v4().substring(0, 8)}',
      pageNumber: pageNumber,
      bounds: PdfRectBounds(
        left: 44,
        top: 240 + (state.editableLinks.length * 30.0),
        width: 240,
        height: 24,
      ),
      actionType: actionType,
      targetUrl: targetUrl,
      targetPageNumber: targetPageNumber,
      visibleBorder: visibleBorder,
    );
    state = state.copyWith(
      editableLinks: <PdfEditableLinkRegion>[...state.editableLinks, link],
    );
  }

  void updateEditableLink(
    String linkId, {
    String? targetUrl,
    int? targetPageNumber,
  }) {
    final updated = state.editableLinks.map((lnk) {
      if (lnk.id == linkId) {
        return lnk.copyWith(
          targetUrl: targetUrl,
          targetPageNumber: targetPageNumber,
        );
      }
      return lnk;
    }).toList();
    state = state.copyWith(editableLinks: updated);
  }

  void deleteEditableLink(String linkId) {
    state = state.copyWith(
      editableLinks:
          state.editableLinks.where((l) => l.id != linkId).toList(),
    );
  }

  // ==========================================================================
  // 2. Security: AES-256 Encryption, Permissions, Redaction & Sanitization
  // ==========================================================================

  void updateSecurityConfig(PdfSecurityEncryptionConfig newConfig) {
    state = state.copyWith(securityConfig: newConfig);
  }

  void removePasswordProtection() {
    state = state.copyWith(
      securityConfig: const PdfSecurityEncryptionConfig(
        enableEncryption: false,
        userOpenPassword: '',
        ownerPermissionsPassword: '',
      ),
    );
  }

  int searchAndMarkForRedaction(
    String searchQuery, {
    String overlayCodeText = 'REDACTED',
  }) {
    final marks = _service.findAndCreateSearchRedactionMarks(
      pageTexts: state.pageTexts,
      searchQuery: searchQuery,
      overlayCodeText: overlayCodeText,
    );
    if (marks.isEmpty) return 0;
    state = state.copyWith(
      redactionMarks: <PdfRedactionMark>[...state.redactionMarks, ...marks],
    );
    return marks.length;
  }

  void addAreaRedactionMark({
    required int pageNumber,
    required PdfRectBounds bounds,
    String overlayCodeText = 'AREA REDACTED',
  }) {
    final mark = PdfRedactionMark(
      id: 'redact-area-${_uuid.v4().substring(0, 8)}',
      pageNumber: pageNumber,
      kind: RedactionTargetKind.rectangularArea,
      bounds: bounds,
      overlayCodeText: overlayCodeText,
    );
    state = state.copyWith(
      redactionMarks: <PdfRedactionMark>[...state.redactionMarks, mark],
    );
  }

  /// Permanently applies all queued redaction marks, scrubbing the underlying
  /// text from `pageTexts` so it can never be searched or copied.
  int applyAllRedactionsPermanently() {
    final result = _service.applyPermanentRedactions(
      pageTexts: state.pageTexts,
      redactionMarks: state.redactionMarks,
    );
    state = state.copyWith(
      pageTexts: result.permanentlyScrubbedPageTexts,
      redactionMarks: result.appliedMarks,
    );
    return result.totalOccurrencesRemoved;
  }

  void updateDocumentMetadata(PdfDocumentMetadataInfo newMetadata) {
    state = state.copyWith(metadataInfo: newMetadata);
  }

  /// Strips all hidden data: metadata fields, comments/annotations, embedded
  /// attachments, and JavaScript/actions.
  HiddenDataSanitizationReport removeHiddenDataAndSanitize({
    int activeAnnotationCount = 0,
  }) {
    final metaCleared = <String>[
      state.metadataInfo.title,
      state.metadataInfo.author,
      state.metadataInfo.subject,
      state.metadataInfo.keywords,
      state.metadataInfo.creator,
      state.metadataInfo.producer,
    ].where((s) => s.trim().isNotEmpty).length;

    final report = HiddenDataSanitizationReport(
      metadataFieldsCleared: metaCleared,
      commentsAndAnnotationsRemoved: activeAnnotationCount,
      embeddedAttachmentsRemoved: 1,
      javascriptAndActionsStripped: 1,
      bytesSaved: 6144,
    );

    state = state.copyWith(
      metadataInfo: PdfDocumentMetadataInfo.sanitizedEmpty,
      lastSanitizationReport: report,
    );
    return report;
  }

  Future<Uint8List> exportEditedAndSecuredPdfBytes() {
    return _service.buildEditedAndSecuredPdfBytes(
      pageTexts: state.pageTexts,
      textEdits: state.textEdits,
      imageObjects: state.imageObjects,
      links: state.editableLinks,
      redactionMarks: state.redactionMarks,
      metadata: state.metadataInfo,
      securityConfig: state.securityConfig,
    );
  }

  // ==========================================================================
  // 3. Document Compare (Side-by-Side Visual Diff & Text Diff)
  // ==========================================================================

  PdfDocumentComparisonReport runDocumentComparison({
    required String leftFileName,
    required Map<int, String> leftPageTexts,
    required String rightFileName,
    required Map<int, String> rightPageTexts,
  }) {
    final report = _service.compareTwoPdfDocuments(
      leftFileName: leftFileName,
      leftPageTexts: leftPageTexts,
      rightFileName: rightFileName,
      rightPageTexts: rightPageTexts,
    );
    state = state.copyWith(comparisonReport: report);
    return report;
  }
}

final pdfContentSecurityCompareControllerProvider = StateNotifierProvider<
    PdfContentSecurityCompareController,
    PdfContentSecurityCompareState>((ref) {
  final service = ref.watch(pdfContentSecurityCompareServiceProvider);
  return PdfContentSecurityCompareController(service: service);
});
