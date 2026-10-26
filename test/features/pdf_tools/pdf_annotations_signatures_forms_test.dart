import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/features/pdf_tools/domain/pdf_annotations_Grouping_models.dart';
import 'package:print_helper/features/pdf_tools/presentation/pdf_annotation_signature_form_controller.dart';
import 'package:print_helper/services/pdf_tools/pdf_annotation_signature_form_service.dart';

void main() {
  group('Standard PDF Annotations, Undo/Redo, Eraser & Distance Measurement', () {
    test(
      'adds annotations across all 14 tools, supports undo/redo and eraser, computes measurement distance in mm, and serializes ISO 32000-1 /Annot objects',
      () {
        const service = PdfAnnotationSignatureFormService();
        final ctrl = PdfAnnotationSignatureFormController(service: service);

        expect(ctrl.state.annotations, isEmpty);
        expect(ctrl.state.canUndo, isFalse);

        // 1. Add Highlight annotation
        ctrl.selectAnnotationTool(PdfAnnotationToolType.highlight);
        ctrl.setAnnotationStyle(
          colorHex: 0xFFFFEB3B,
          strokeWidth: 3.0,
          opacity: 0.65,
        );
        ctrl.addAnnotation(
          pageNumber: 1,
          contents: 'වැදගත් සිංහල වගන්තිය / Important Clause',
        );
        expect(ctrl.state.annotations.length, equals(1));
        expect(ctrl.state.canUndo, isTrue);

        // Verify ISO 32000-1 /Annot dictionary output
        final dictString =
            ctrl.state.annotations.first.toPdfAnnotationDictionaryString();
        expect(dictString, contains('/Type /Annot'));
        expect(dictString, contains('/Subtype /Highlight'));
        expect(dictString, contains('/CA 0.65'));

        // 2. Add Measurement annotation (72 pt horizontal line = 25.4 mm)
        ctrl.selectAnnotationTool(PdfAnnotationToolType.measurement);
        ctrl.addAnnotation(
          pageNumber: 1,
          inkPoints: const <PdfPoint>[
            PdfPoint(100, 100),
            PdfPoint(172, 100), // 72 points = 1 inch = 25.4 mm
          ],
        );
        expect(ctrl.state.annotations.length, equals(2));
        expect(
          ctrl.state.annotations.last.measuredDistanceMm,
          closeTo(25.4, 0.05),
        );

        // 3. Test Undo & Redo
        ctrl.undoAnnotation();
        expect(ctrl.state.annotations.length, equals(1));
        expect(ctrl.state.canRedo, isTrue);

        ctrl.redoAnnotation();
        expect(ctrl.state.annotations.length, equals(2));

        // 4. Test Eraser by ID
        ctrl.eraseAnnotationById(ctrl.state.annotations.first.id);
        expect(ctrl.state.annotations.length, equals(1));
      },
    );
  });

  group('Visual Signatures, Initials, Date Stamps & PKCS#12 Digital Signatures', () {
    test(
      'saves drawn/typed/image signatures, places signature & initials with date stamp, signs with PKCS#12 certificate, and detects post-signing tampering',
      () async {
        const service = PdfAnnotationSignatureFormService();
        final ctrl = PdfAnnotationSignatureFormController(service: service);

        // Save a new signature profile
        ctrl.saveNewSignatureProfile(
          label: 'Director Signature',
          sourceMode: SignatureSourceMode.drawnStroke,
          signerFullName: 'K. D. Silva (කේ. ඩී. සිල්වා)',
          initialsText: 'K.D.S.',
          strokePoints: const <PdfPoint>[PdfPoint(0, 0), PdfPoint(40, 20)],
        );
        expect(ctrl.state.savedSignatures.length, equals(2));

        final profileId = ctrl.state.savedSignatures.last.id;
        ctrl.placeSignatureOnPage(
          profileId: profileId,
          pageNumber: 1,
          isInitialsOnly: false,
          includeDateStamp: true,
        );
        ctrl.placeSignatureOnPage(
          profileId: profileId,
          pageNumber: 1,
          isInitialsOnly: true,
          includeDateStamp: true,
        );
        expect(ctrl.state.placedSignatures.length, equals(2));
        expect(ctrl.state.placedSignatures.last.isInitialsOnly, isTrue);
        expect(ctrl.state.placedSignatures.last.displayText, equals('K.D.S.'));

        // Apply PKCS#12 Digital Signature
        final sigRecord = await ctrl.applyPkcs12DigitalSignature(
          pkcs12FilePath: 'certs/director.p12',
          passphrase: 'strong-passphrase-123',
          signerCommonName: 'K. D. Silva',
        );
        expect(sigRecord.isValid, isTrue);
        expect(
          sigRecord.validityStatus,
          equals(DigitalSignatureValidityStatus.validUntampered),
        );

        // Validate against unmodified signed bytes -> Valid
        final verifiedOk = ctrl.verifyCurrentDigitalSignature();
        expect(verifiedOk!.isValid, isTrue);

        // Tamper with 1 byte of the signed PDF -> Validation must fail
        final tamperedBytes =
            Uint8List.fromList(ctrl.state.lastSignedPdfBytes!);
        tamperedBytes[tamperedBytes.length - 1] ^= 0xFF;

        final verifiedTampered = ctrl.verifyCurrentDigitalSignature(
          documentBytesToVerify: tamperedBytes,
        );
        expect(verifiedTampered!.isValid, isFalse);
        expect(
          verifiedTampered.validityStatus,
          equals(DigitalSignatureValidityStatus.invalidModifiedAfterSigning),
        );
      },
    );
  });

  group('AcroForm Support: Fill, Highlight, Flatten, Import/Export & Flat-Form Auto-Detect', () {
    test(
      'fills text/checkbox/dropdown/radio fields, exports and imports JSON, auto-detects flat form fields, and locks fields when flattened',
      () async {
        const service = PdfAnnotationSignatureFormService();
        final ctrl = PdfAnnotationSignatureFormController(service: service);

        // Fill existing fields
        ctrl.updateFormFieldValue(
          fieldName: 'applicant_full_name',
          textValue: 'නිමල් සිල්වා (Nimal Silva)',
        );
        ctrl.updateFormFieldValue(
          fieldName: 'urgent_processing',
          checkedValue: false,
        );
        ctrl.updateFormFieldValue(
          fieldName: 'delivery_branch',
          selectedOption: 'Kandy (මහනුවර)',
        );

        // Export to JSON
        final exportedJson = ctrl.exportFormFieldsAsJson();
        expect(exportedJson, contains('නිමල් සිල්වා (Nimal Silva)'));
        expect(exportedJson, contains('Kandy (මහනුවර)'));

        // Modify and re-import from JSON
        ctrl.updateFormFieldValue(
          fieldName: 'applicant_full_name',
          textValue: 'Temporary Name',
        );
        ctrl.importFormFieldsFromJson(exportedJson);
        final restoredField = ctrl.state.formFields
            .firstWhere((f) => f.fieldName == 'applicant_full_name');
        expect(restoredField.textValue, equals('නිමල් සිල්වා (Nimal Silva)'));

        // Auto-detect fields on flat form text
        final detectedCount = ctrl.runFlatFormFieldAutoDetection(
          const <int, String>{
            1: 'Passport Number: ______________\n'
                '[ ] Agree to Terms & Conditions\n'
                'Date / දිනය: __________',
          },
        );
        expect(detectedCount, equals(3));

        // Flatten form -> subsequent edits are ignored and exported PDF marks AcroForm flattened
        ctrl.flattenAcroFormFields();
        expect(ctrl.state.isFormFlattened, isTrue);

        ctrl.updateFormFieldValue(
          fieldName: 'applicant_full_name',
          textValue: 'Should Not Change After Flatten',
        );
        expect(
          ctrl.state.formFields
              .firstWhere((f) => f.fieldName == 'applicant_full_name')
              .textValue,
          equals('නිමල් සිල්වා (Nimal Silva)'),
        );

        final exportedPdfBytes =
            await ctrl.exportAnnotatedAndSignedPdfBytes(totalPages: 1);
        final pdfAsciiTail = utf8.decode(exportedPdfBytes, allowMalformed: true);
        expect(pdfAsciiTail, contains('/AcroForm Flattened=true'));
      },
    );
  });
}
