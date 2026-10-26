import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/features/pdf_tools/domain/pdf_annotations_Grouping_models.dart';
import 'package:print_helper/features/pdf_tools/domain/pdf_content_security_compare_models.dart';
import 'package:print_helper/features/pdf_tools/presentation/pdf_content_security_compare_controller.dart';
import 'package:print_helper/services/pdf_tools/pdf_content_security_compare_service.dart';

void main() {
  group('Content Editing: Add Text, Whiteout+Overlay, Images, Links & Font Availability', () {
    test(
      'detects missing subsetted fonts vs bundled NotoSansSinhala and manages text edits, whiteout overlays, images, and links',
      () {
        final service = PdfContentSecurityCompareService();
        final ctrl = PdfContentSecurityCompareController(service: service);

        // Verify font availability inspection
        final fonts = ctrl.state.embeddedFonts;
        expect(fonts, isNotEmpty);
        final noto = fonts.firstWhere(
          (f) => f.embeddedFontName == 'NotoSansSinhala',
        );
        final legacySubset = fonts.firstWhere(
          (f) => f.embeddedFontName == 'SUBSET+FMAbhaya-Bold',
        );
        expect(noto.isAvailableLocally, isTrue);
        expect(legacySubset.isAvailableLocally, isFalse);
        expect(legacySubset.substituteFontFamily, equals('NotoSansSinhala'));
        expect(legacySubset.noticeEn, contains('Whiteout + Overlay'));

        // Add new text and a Whiteout + Overlay replacement
        ctrl.addOrReplaceContentText(
          pageNumber: 1,
          text: 'නව සිංහල පෙළ (Added Text)',
          fontFamily: 'NotoSansSinhala',
          fontSizePt: 14.0,
          alignment: PdfTextAlignment.center,
          isWhiteoutReplacement: false,
        );
        ctrl.addOrReplaceContentText(
          pageNumber: 1,
          text: 'ප්‍රතිස්ථාපනය කළ පෙළ (Whiteout Replacement)',
          fontFamily: 'NotoSansSinhala',
          fontSizePt: 12.0,
          isWhiteoutReplacement: true,
          originalEmbeddedFontName: 'SUBSET+FMAbhaya-Bold',
        );
        expect(ctrl.state.textEdits.length, equals(2));
        expect(ctrl.state.textEdits.last.isWhiteoutReplacement, isTrue);

        // Add, resize/move, and delete an image object
        ctrl.addContentImage(
          pageNumber: 1,
          label: 'Seal.png',
          imageBytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        );
        expect(ctrl.state.imageObjects.length, equals(1));
        final imgId = ctrl.state.imageObjects.first.id;
        ctrl.moveOrResizeContentImage(
          imgId,
          newBounds: const PdfRectBounds(
            left: 100,
            top: 120,
            width: 200,
            height: 150,
          ),
        );
        expect(ctrl.state.imageObjects.first.bounds.width, equals(200));
        ctrl.deleteContentImage(imgId);
        expect(ctrl.state.imageObjects, isEmpty);

        // Add and update a hyperlink
        ctrl.addEditableLink(
          pageNumber: 1,
          actionType: PdfLinkActionType.externalUrl,
          targetUrl: 'https://www.printhelper.org',
        );
        expect(ctrl.state.editableLinks.length, equals(2));
        final linkId = ctrl.state.editableLinks.last.id;
        ctrl.updateEditableLink(
          linkId,
          targetUrl: 'https://www.gov.lk/sinhala',
        );
        expect(
          ctrl.state.editableLinks.last.targetUrl,
          equals('https://www.gov.lk/sinhala'),
        );
      },
    );
  });

  group('Security: AES-256 Encryption, Permissions, Permanent Redaction & Remove Hidden Data', () {
    test(
      'builds qpdf AES-256 encryption & permission flags, permanently scrubs search-and-redact matches from page streams, and sanitizes metadata',
      () async {
        final service = PdfContentSecurityCompareService();
        final ctrl = PdfContentSecurityCompareController(service: service);

        // Configure AES-256 encryption with no print / no copy / no edit permissions
        const secConfig = PdfSecurityEncryptionConfig(
          enableEncryption: true,
          userOpenPassword: 'user-secret',
          ownerPermissionsPassword: 'owner-secret',
          allowPrinting: false,
          allowCopyingTextAndGraphics: false,
          allowModifyingContent: false,
          allowAnnotationsAndForms: false,
        );
        ctrl.updateSecurityConfig(secConfig);

        final qpdfArgs = service.buildQpdfAes256EncryptionArgs(
          inputPath: 'in.pdf',
          outputPath: 'out.pdf',
          config: secConfig,
        );
        expect(qpdfArgs, contains('--encrypt'));
        expect(qpdfArgs, contains('256'));
        expect(qpdfArgs, contains('--print=none'));
        expect(qpdfArgs, contains('--extract=n'));
        expect(qpdfArgs, contains('--modify=none'));

        // Search-and-Redact sensitive account number across all pages
        final markedCount = ctrl.searchAndMarkForRedaction('ACC-9948-2026');
        expect(markedCount, equals(2)); // Present on both Page 1 and Page 2

        // Apply permanent redaction -> sensitive string must be completely removed from pageTexts
        final removedOccurrences = ctrl.applyAllRedactionsPermanently();
        expect(removedOccurrences, equals(2));
        expect(ctrl.state.pageTexts[1]!.contains('ACC-9948-2026'), isFalse);
        expect(ctrl.state.pageTexts[2]!.contains('ACC-9948-2026'), isFalse);
        expect(ctrl.state.pageTexts[1]!, contains('[██████████]'));

        // Remove Hidden Data (Metadata, Comments, Attachments)
        final sanitizeReport =
            ctrl.removeHiddenDataAndSanitize(activeAnnotationCount: 4);
        expect(sanitizeReport.metadataFieldsCleared, greaterThan(0));
        expect(sanitizeReport.commentsAndAnnotationsRemoved, equals(4));
        expect(ctrl.state.metadataInfo.title, isEmpty);
        expect(ctrl.state.metadataInfo.author, isEmpty);

        // Export PDF bytes and verify AES-256 descriptor trailer
        final pdfBytes = await ctrl.exportEditedAndSecuredPdfBytes();
        final ascii = utf8.decode(pdfBytes, allowMalformed: true);
        expect(ascii, contains('/Length 256'));
        expect(ascii, contains('ACC-9948-2026') == false);
      },
    );
  });

  group('Document Compare: Side-by-Side Visual Diff & Line-by-Line Text Diff', () {
    test(
      'computes added, removed, and modified lines plus visual page difference percentages between two PDFs',
      () {
        final service = PdfContentSecurityCompareService();
        final report = service.compareTwoPdfDocuments(
          leftFileName: 'doc_v1.pdf',
          leftPageTexts: const <int, String>{
            1: 'ශ්‍රී ලංකා මුද්‍රණ සහායක\nගාස්තුව: රු. 1,500.00\nපැරණි වගන්තිය ඉවත් කරන ලදී.',
          },
          rightFileName: 'doc_v2.pdf',
          rightPageTexts: const <int, String>{
            1: 'ශ්‍රී ලංකා මුද්‍රණ සහායක\nගාස්තුව: රු. 2,000.00\nපැරණි වගන්තිය ඉවත් කරන ලදී.\nනව අතිරේක වගන්තිය එක් කරන ලදී.',
          },
        );

        expect(report.areIdentical, isFalse);
        expect(report.modifiedLinesCount, equals(1)); // 1,500.00 -> 2,000.00
        expect(report.addedLinesCount, equals(1)); // නව අතිරේක වගන්තිය...
        expect(report.removedLinesCount, equals(0));
        expect(
          report.visualPageDiffs.first.visualDifferencePercent,
          greaterThan(0.0),
        );
        expect(
          report.visualPageDiffs.first.changedRegionBounds.length,
          equals(2),
        );
      },
    );
  });
}
