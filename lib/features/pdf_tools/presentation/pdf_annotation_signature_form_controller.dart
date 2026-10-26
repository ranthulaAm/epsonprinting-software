import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/pdf_tools/pdf_annotation_signature_form_service.dart';
import '../domain/pdf_annotations_Grouping_models.dart';

class PdfAnnotationSignatureFormState {
  const PdfAnnotationSignatureFormState({
    this.activeTool = PdfAnnotationToolType.highlight,
    this.selectedColorHex = 0xFFFFEB3B,
    this.selectedStrokeWidth = 2.5,
    this.selectedOpacity = 0.78,
    this.selectedStampLabel = 'APPROVED • අනුමතයි',
    this.annotations = const <PdfAnnotationItem>[],
    this.undoStack = const <List<PdfAnnotationItem>>[],
    this.redoStack = const <List<PdfAnnotationItem>>[],
    this.savedSignatures = const <SavedSignatureProfile>[],
    this.placedSignatures = const <PlacedPageSignature>[],
    this.digitalSignatureRecord,
    this.lastSignedPdfBytes,
    this.formFields = const <PdfAcroFormField>[],
    this.highlightFormFields = true,
    this.isFormFlattened = false,
  });

  final PdfAnnotationToolType activeTool;
  final int selectedColorHex;
  final double selectedStrokeWidth;
  final double selectedOpacity;
  final String selectedStampLabel;
  final List<PdfAnnotationItem> annotations;
  final List<List<PdfAnnotationItem>> undoStack;
  final List<List<PdfAnnotationItem>> redoStack;
  final List<SavedSignatureProfile> savedSignatures;
  final List<PlacedPageSignature> placedSignatures;
  final Pkcs12DigitalSignatureRecord? digitalSignatureRecord;
  final Uint8List? lastSignedPdfBytes;
  final List<PdfAcroFormField> formFields;
  final bool highlightFormFields;
  final bool isFormFlattened;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  PdfAnnotationSignatureFormState copyWith({
    PdfAnnotationToolType? activeTool,
    int? selectedColorHex,
    double? selectedStrokeWidth,
    double? selectedOpacity,
    String? selectedStampLabel,
    List<PdfAnnotationItem>? annotations,
    List<List<PdfAnnotationItem>>? undoStack,
    List<List<PdfAnnotationItem>>? redoStack,
    List<SavedSignatureProfile>? savedSignatures,
    List<PlacedPageSignature>? placedSignatures,
    Pkcs12DigitalSignatureRecord? digitalSignatureRecord,
    bool clearDigitalSignature = false,
    Uint8List? lastSignedPdfBytes,
    List<PdfAcroFormField>? formFields,
    bool? highlightFormFields,
    bool? isFormFlattened,
  }) {
    return PdfAnnotationSignatureFormState(
      activeTool: activeTool ?? this.activeTool,
      selectedColorHex: selectedColorHex ?? this.selectedColorHex,
      selectedStrokeWidth: selectedStrokeWidth ?? this.selectedStrokeWidth,
      selectedOpacity: selectedOpacity ?? this.selectedOpacity,
      selectedStampLabel: selectedStampLabel ?? this.selectedStampLabel,
      annotations: annotations ?? this.annotations,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      savedSignatures: savedSignatures ?? this.savedSignatures,
      placedSignatures: placedSignatures ?? this.placedSignatures,
      digitalSignatureRecord: clearDigitalSignature
          ? null
          : (digitalSignatureRecord ?? this.digitalSignatureRecord),
      lastSignedPdfBytes: lastSignedPdfBytes ?? this.lastSignedPdfBytes,
      formFields: formFields ?? this.formFields,
      highlightFormFields: highlightFormFields ?? this.highlightFormFields,
      isFormFlattened: isFormFlattened ?? this.isFormFlattened,
    );
  }
}

class PdfAnnotationSignatureFormController
    extends StateNotifier<PdfAnnotationSignatureFormState> {
  PdfAnnotationSignatureFormController({
    required PdfAnnotationSignatureFormService service,
  })  : _service = service,
        super(_buildInitialState());

  final PdfAnnotationSignatureFormService _service;
  static const Uuid _uuid = Uuid();

  static PdfAnnotationSignatureFormState _buildInitialState() {
    return const PdfAnnotationSignatureFormState(
      savedSignatures: <SavedSignatureProfile>[
        SavedSignatureProfile(
          id: 'sig-default-1',
          label: 'Official Sinhala & English Signature',
          sourceMode: SignatureSourceMode.typedText,
          signerFullName: 'R. A. Perera (ආර්. ඒ. පෙරේරා)',
          initialsText: 'R.A.P.',
          typedSignatureText: 'R. A. Perera • ආර්. ඒ. පෙරේරා',
          inkColorHex: 0xFF0D47A1,
        ),
      ],
      formFields: <PdfAcroFormField>[
        PdfAcroFormField(
          fieldName: 'applicant_full_name',
          label: 'සම්පූර්ණ නම / Full Name',
          fieldType: PdfAcroFormFieldType.textField,
          pageNumber: 1,
          bounds: PdfRectBounds(left: 40, top: 80, width: 260, height: 28),
          textValue: 'කමල් පෙරේරා (Kamal Perera)',
        ),
        PdfAcroFormField(
          fieldName: 'urgent_processing',
          label: 'හදිසි සැකසුම / Urgent Processing',
          fieldType: PdfAcroFormFieldType.checkbox,
          pageNumber: 1,
          bounds: PdfRectBounds(left: 40, top: 120, width: 220, height: 24),
          checkedValue: true,
        ),
        PdfAcroFormField(
          fieldName: 'delivery_branch',
          label: 'ශාඛාව / Branch Office',
          fieldType: PdfAcroFormFieldType.dropdown,
          pageNumber: 1,
          bounds: PdfRectBounds(left: 40, top: 155, width: 240, height: 28),
          selectedOption: 'Colombo (කොළඹ)',
          options: <String>[
            'Colombo (කොළඹ)',
            'Kandy (මහනුවර)',
            'Galle (ගාල්ල)',
            'Jaffna (යාපනය)',
          ],
        ),
        PdfAcroFormField(
          fieldName: 'payment_method',
          label: 'ගෙවීම් ක්‍රමය / Payment Method',
          fieldType: PdfAcroFormFieldType.radioGroup,
          pageNumber: 1,
          bounds: PdfRectBounds(left: 40, top: 195, width: 240, height: 28),
          selectedOption: 'Bank Transfer',
          options: <String>['Bank Transfer', 'Cash', 'Card'],
        ),
      ],
    );
  }

  // ==========================================================================
  // 1. Annotation Tools, Styling, Eraser & Undo/Redo Stack
  // ==========================================================================

  void selectAnnotationTool(PdfAnnotationToolType tool) {
    state = state.copyWith(activeTool: tool);
  }

  void setAnnotationStyle({
    int? colorHex,
    double? strokeWidth,
    double? opacity,
    String? stampLabel,
  }) {
    state = state.copyWith(
      selectedColorHex: colorHex,
      selectedStrokeWidth: strokeWidth,
      selectedOpacity: opacity,
      selectedStampLabel: stampLabel,
    );
  }

  void addAnnotation({
    required int pageNumber,
    PdfAnnotationToolType? toolOverride,
    PdfRectBounds? boundsOverride,
    String contents = '',
    List<PdfPoint> inkPoints = const <PdfPoint>[],
  }) {
    final tool = toolOverride ?? state.activeTool;
    if (tool == PdfAnnotationToolType.selectPan ||
        tool == PdfAnnotationToolType.eraser) {
      return;
    }

    final bounds = boundsOverride ??
        PdfRectBounds(
          left: 48.0 + ((state.annotations.length % 5) * 22.0),
          top: 90.0 + ((state.annotations.length % 6) * 34.0),
          width: tool == PdfAnnotationToolType.stickyNote ? 150.0 : 210.0,
          height: tool == PdfAnnotationToolType.stickyNote ? 64.0 : 36.0,
        );

    final newItem = PdfAnnotationItem(
      id: 'annot-${_uuid.v4().substring(0, 8)}',
      pageNumber: pageNumber,
      toolType: tool,
      bounds: bounds,
      colorHex: state.selectedColorHex,
      strokeWidth: state.selectedStrokeWidth,
      opacity: state.selectedOpacity,
      contents: contents.isEmpty
          ? _defaultContentsForTool(tool)
          : contents,
      createdAt: DateTime.now(),
      inkPoints: inkPoints,
      stampLabel: state.selectedStampLabel,
    );

    _commitAnnotationMutation(<PdfAnnotationItem>[
      ...state.annotations,
      newItem,
    ]);
  }

  /// Erases an annotation by ID or at a clicked point (`PdfAnnotationToolType.eraser`).
  void eraseAnnotationById(String annotationId) {
    if (!state.annotations.any((a) => a.id == annotationId)) return;
    final remaining =
        state.annotations.where((a) => a.id != annotationId).toList();
    _commitAnnotationMutation(remaining);
  }

  void eraseAnnotationsAtPoint(int pageNumber, PdfPoint point) {
    final remaining = state.annotations
        .where(
          (a) => !(a.pageNumber == pageNumber && a.bounds.containsPoint(point)),
        )
        .toList();
    if (remaining.length != state.annotations.length) {
      _commitAnnotationMutation(remaining);
    }
  }

  void updateAnnotationContents(String annotationId, String newContents) {
    final updated = state.annotations.map((a) {
      if (a.id == annotationId) {
        return a.copyWith(contents: newContents);
      }
      return a;
    }).toList();
    _commitAnnotationMutation(updated);
  }

  void undoAnnotation() {
    if (!state.canUndo) return;
    final previousList = state.undoStack.last;
    final nextUndoStack =
        state.undoStack.sublist(0, state.undoStack.length - 1);
    final nextRedoStack = <List<PdfAnnotationItem>>[
      ...state.redoStack,
      state.annotations,
    ];
    state = state.copyWith(
      annotations: previousList,
      undoStack: nextUndoStack,
      redoStack: nextRedoStack,
    );
  }

  void redoAnnotation() {
    if (!state.canRedo) return;
    final nextList = state.redoStack.last;
    final nextRedoStack =
        state.redoStack.sublist(0, state.redoStack.length - 1);
    final nextUndoStack = <List<PdfAnnotationItem>>[
      ...state.undoStack,
      state.annotations,
    ];
    state = state.copyWith(
      annotations: nextList,
      undoStack: nextUndoStack,
      redoStack: nextRedoStack,
    );
  }

  void _commitAnnotationMutation(List<PdfAnnotationItem> nextAnnotations) {
    final updatedUndo = <List<PdfAnnotationItem>>[
      ...state.undoStack,
      state.annotations,
    ];
    state = state.copyWith(
      annotations: nextAnnotations,
      undoStack: updatedUndo,
      redoStack: const <List<PdfAnnotationItem>>[],
    );
  }

  // ==========================================================================
  // 2. Visual Signatures, Initials, Date Fields & PKCS#12 Digital Signatures
  // ==========================================================================

  void saveNewSignatureProfile({
    required String label,
    required SignatureSourceMode sourceMode,
    required String signerFullName,
    required String initialsText,
    String typedSignatureText = '',
    List<PdfPoint> strokePoints = const <PdfPoint>[],
    Uint8List? imageBytes,
    int inkColorHex = 0xFF0D47A1,
  }) {
    final profile = SavedSignatureProfile(
      id: 'sig-${_uuid.v4().substring(0, 8)}',
      label: label,
      sourceMode: sourceMode,
      signerFullName: signerFullName,
      initialsText: initialsText,
      typedSignatureText: typedSignatureText,
      strokePoints: strokePoints,
      imageBytes: imageBytes,
      inkColorHex: inkColorHex,
    );
    state = state.copyWith(
      savedSignatures: <SavedSignatureProfile>[
        ...state.savedSignatures,
        profile,
      ],
    );
  }

  void placeSignatureOnPage({
    required String profileId,
    required int pageNumber,
    bool isInitialsOnly = false,
    bool includeDateStamp = true,
    PdfRectBounds? customBounds,
  }) {
    final profile = state.savedSignatures
            .where((p) => p.id == profileId)
            .firstOrNull ??
        state.savedSignatures.first;

    final placed = PlacedPageSignature(
      placementId: 'placed-${_uuid.v4().substring(0, 8)}',
      profileId: profile.id,
      pageNumber: pageNumber,
      bounds: customBounds ??
          PdfRectBounds(
            left: 310,
            top: 220 + (state.placedSignatures.length * 48.0),
            width: isInitialsOnly ? 110 : 210,
            height: isInitialsOnly ? 44 : 58,
          ),
      displayText: isInitialsOnly
          ? profile.initialsText
          : (profile.typedSignatureText.isNotEmpty
              ? profile.typedSignatureText
              : profile.signerFullName),
      includeDateStamp: includeDateStamp,
      isInitialsOnly: isInitialsOnly,
      dateFormatted: DateTime.now().toIso8601String().split('T').first,
      inkColorHex: profile.inkColorHex,
      strokePoints: profile.strokePoints,
      imageBytes: profile.imageBytes,
    );

    state = state.copyWith(
      placedSignatures: <PlacedPageSignature>[
        ...state.placedSignatures,
        placed,
      ],
    );
  }

  void resizeOrMovePlacedSignature(
    String placementId,
    PdfRectBounds newBounds,
  ) {
    final updated = state.placedSignatures.map((sig) {
      if (sig.placementId == placementId) {
        return sig.copyWith(bounds: newBounds);
      }
      return sig;
    }).toList();
    state = state.copyWith(placedSignatures: updated);
  }

  void removePlacedSignature(String placementId) {
    state = state.copyWith(
      placedSignatures: state.placedSignatures
          .where((s) => s.placementId != placementId)
          .toList(),
    );
  }

  Future<Pkcs12DigitalSignatureRecord> applyPkcs12DigitalSignature({
    required String pkcs12FilePath,
    required String passphrase,
    required String signerCommonName,
    String signerOrganization = 'Print Helper Verified Signer',
    String reason = 'Approved & Signed Offline / අනුමත කරන ලදී',
    String location = 'Colombo, Sri Lanka',
  }) async {
    final pdfBytes = await _service.exportPdfWithStandardAnnotationsAndForms(
      totalPages: 2,
      annotations: state.annotations,
      placedSignatures: state.placedSignatures,
      formFields: state.formFields,
      flattenForms: state.isFormFlattened,
    );

    final record = _service.signDocumentWithPkcs12(
      documentBytes: pdfBytes,
      pkcs12FilePath: pkcs12FilePath,
      passphrase: passphrase,
      signerCommonName: signerCommonName,
      signerOrganization: signerOrganization,
      reason: reason,
      location: location,
    );

    state = state.copyWith(
      digitalSignatureRecord: record,
      lastSignedPdfBytes: pdfBytes,
    );
    return record;
  }

  Pkcs12DigitalSignatureRecord? verifyCurrentDigitalSignature({
    Uint8List? documentBytesToVerify,
  }) {
    final existing = state.digitalSignatureRecord;
    final bytes = documentBytesToVerify ?? state.lastSignedPdfBytes;
    if (existing == null || bytes == null) return null;

    final verified = _service.validateDigitalSignature(
      currentDocumentBytes: bytes,
      existingSignature: existing,
    );
    state = state.copyWith(digitalSignatureRecord: verified);
    return verified;
  }

  // ==========================================================================
  // 3. AcroForm Filling, Highlighting, Flattening, Import/Export & Auto-Detect
  // ==========================================================================

  void toggleHighlightFormFields(bool highlight) {
    state = state.copyWith(highlightFormFields: highlight);
  }

  void updateFormFieldValue({
    required String fieldName,
    String? textValue,
    bool? checkedValue,
    String? selectedOption,
  }) {
    if (state.isFormFlattened) return; // Flattened forms are read-only
    final updated = state.formFields.map((field) {
      if (field.fieldName == fieldName) {
        return field.copyWith(
          textValue: textValue,
          checkedValue: checkedValue,
          selectedOption: selectedOption,
        );
      }
      return field;
    }).toList();
    state = state.copyWith(formFields: updated);
  }

  void flattenAcroFormFields() {
    final flattened = state.formFields
        .map((f) => f.copyWith(isFlattened: true))
        .toList();
    state = state.copyWith(
      formFields: flattened,
      isFormFlattened: true,
    );
  }

  String exportFormFieldsAsJson() {
    return _service.exportFormDataToJson(state.formFields);
  }

  void importFormFieldsFromJson(String jsonContent) {
    final updated = _service.importFormDataFromJson(
      existingFields: state.formFields,
      jsonContent: jsonContent,
    );
    state = state.copyWith(formFields: updated);
  }

  int runFlatFormFieldAutoDetection(Map<int, String> pageTexts) {
    final detected = _service.autoDetectFieldsOnFlatForm(pageTexts: pageTexts);
    if (detected.isEmpty) return 0;
    state = state.copyWith(
      formFields: <PdfAcroFormField>[
        ...state.formFields,
        ...detected,
      ],
    );
    return detected.length;
  }

  Future<Uint8List> exportAnnotatedAndSignedPdfBytes({
    int totalPages = 2,
  }) {
    return _service.exportPdfWithStandardAnnotationsAndForms(
      totalPages: totalPages,
      annotations: state.annotations,
      placedSignatures: state.placedSignatures,
      formFields: state.formFields,
      flattenForms: state.isFormFlattened,
      digitalSignature: state.digitalSignatureRecord,
    );
  }

  String _defaultContentsForTool(PdfAnnotationToolType tool) {
    return switch (tool) {
      PdfAnnotationToolType.highlight =>
        'Highlighted text (උද්දීපනය කළ පෙළ)',
      PdfAnnotationToolType.underline => 'Underlined clause',
      PdfAnnotationToolType.strikethrough => 'Strikethrough revision',
      PdfAnnotationToolType.squiggly => 'Squiggly spelling/review mark',
      PdfAnnotationToolType.freehandPen => 'Freehand ink stroke',
      PdfAnnotationToolType.rectangle => 'Rectangle callout box',
      PdfAnnotationToolType.ellipse => 'Ellipse highlight ring',
      PdfAnnotationToolType.line => 'Connecting line',
      PdfAnnotationToolType.arrow => 'Pointer arrow',
      PdfAnnotationToolType.textBox =>
        'සිංහල සහ English FreeText Box',
      PdfAnnotationToolType.stickyNote =>
        'Sticky Note: කරුණාකර මෙම වගන්තිය පරීක්ෂා කරන්න.',
      PdfAnnotationToolType.stamp => state.selectedStampLabel,
      PdfAnnotationToolType.measurement => 'Measured distance',
      _ => '',
    };
  }
}

final pdfAnnotationSignatureFormControllerProvider = StateNotifierProvider<
    PdfAnnotationSignatureFormController,
    PdfAnnotationSignatureFormState>((ref) {
  final service = ref.watch(pdfAnnotationSignatureFormServiceProvider);
  return PdfAnnotationSignatureFormController(service: service);
});
