import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/features/pdf_tools/domain/pdf_convert_ocr_models.dart';
import 'package:print_helper/services/pdf_tools/pdf_convert_ocr_service.dart';
import 'package:print_helper/services/process/sandboxed_process_runner.dart';

void main() {
  const service = PdfConvertOcrService();

  group('1. Legacy Sinhala Font (FM Abhaya / DL-Manel) Detection & Unicode Converter', () {
    test('Detects FM Abhaya / Wijesekara ASCII tokens and transcodes to Sinhala Unicode', () {
      const legacyText = ';s% ,xld m%cd;dka;%sl iudcjd§ ckrcfha úoHdj';
      final pdfBytes = Uint8List.fromList(
        utf8.encode('%PDF-1.7\n/BaseFont /FMAbhaya\n$legacyText'),
      );

      final detection = service.detectLegacySinhala(
        pdfBytes: pdfBytes,
        extractedText: legacyText,
      );

      expect(detection.hasLegacySinhalaEncoding, isTrue);
      expect(detection.detectedLegacyFontNames, isNotEmpty);
      expect(detection.transcodedUnicodePreview, contains('ශ්‍රී ලංකා'));
      expect(detection.transcodedUnicodePreview, contains('ප්‍රජාතාන්ත්‍රික'));
      expect(detection.transcodedUnicodePreview, contains('විද්‍යාව'));
      expect(detection.warningEn, contains('Legacy non-Unicode Sinhala font'));
      expect(detection.warningSi, contains('Unicode නොවන සිංහල අකුරු'));
    });

    test('Does not trigger false positive on clean Unicode Sinhala PDF', () {
      const unicodeText = 'ශ්‍රී ලංකා අධ්‍යාපන දෙපාර්තමේන්තුව';
      final pdfBytes = Uint8List.fromList(
        utf8.encode('%PDF-1.7\n/BaseFont /NotoSansSinhala-Regular\n'),
      );

      final detection = service.detectLegacySinhala(
        pdfBytes: pdfBytes,
        extractedText: unicodeText,
      );

      expect(detection.hasLegacySinhalaEncoding, isFalse);
    });
  });

  group('2. Pre-OCR Image Cleanup Pipeline & Tesseract OCR (sin + eng)', () {
    test('Applies auto-rotate, deskew, denoise, contrast stretch, and binarization', () async {
      final outcome = await service.applyPreOcrImageCleanup(
        imageBytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        config: const OcrImageCleanupConfig(
          autoRotateOrientation: true,
          deskewPages: true,
          denoiseSpeckles: true,
          enhanceContrast: true,
          binarizeThreshold: true,
        ),
      );

      expect(outcome.cleanedPngBytes, isNotEmpty);
      expect(outcome.deskewDegrees.abs(), greaterThan(0.0));
    });

    test('Creates searchable PDF with invisible text layer (/Tr 3) and recognizes Sinhala + English', () async {
      final ocrResult = await service.runOcrAndBuildSearchablePdf(
        inputBytes: Uint8List.fromList(utf8.encode('Scanned Sinhala Circular')),
        sourceFileName: 'scanned_circular.pdf',
        languages: const <String>['sin', 'eng'],
      );

      expect(ocrResult.combinedRecognizedText, contains('ශ්‍රී ලංකා'));
      expect(ocrResult.averageConfidencePercent, greaterThan(80.0));
      expect(ocrResult.hasConfidenceWarnings, isFalse);
      expect(ocrResult.searchablePdfBytes, isNotEmpty);

      final pdfString = utf8.decode(
        ocrResult.searchablePdfBytes,
        allowInvalid: true,
      );
      expect(pdfString, contains('PrintHelper-Searchable-OCR-Layer'));
      expect(pdfString, contains('NotoSansSinhala-Regular'));
    });

    test('Triggers low-confidence Sinhala OCR warning when scan confidence < 78%', () async {
      final lowQualityResult = await service.runOcrAndBuildSearchablePdf(
        inputBytes: Uint8List.fromList(utf8.encode('Blurred rubber stamp scan')),
        sourceFileName: 'faded_sinhala_scan.pdf',
        simulateLowQualityScanForTesting: true,
      );

      expect(lowQualityResult.averageConfidencePercent, lessThan(78.0));
      expect(lowQualityResult.hasConfidenceWarnings, isTrue);
      expect(lowQualityResult.confidenceWarningMessageEn, contains('Low Sinhala OCR confidence'));
      expect(lowQualityResult.confidenceWarningMessageSi, contains('සිංහල අකුරු හඳුනාගැනීමේ නිරවද්‍යතාවය අඩු'));
      expect(lowQualityResult.pageReports.first.lowConfidenceWords, isNotEmpty);
    });
  });

  group('3. WIA Scanner Discovery & Multi-Page Scan to PDF', () {
    test('Discovers WIA scanners and acquires multi-page scanned PDF', () async {
      final scanners = await service.discoverWiaScanners();
      expect(scanners, isNotEmpty);
      expect(scanners.first.supportsAutoDocumentFeeder, isTrue);

      final multiPagePdf = await service.scanOrImportPagesToPdf(
        scanner: scanners.first,
        pageCount: 3,
        dpi: 300,
      );
      expect(multiPagePdf, isNotEmpty);
      expect(latin1.decode(multiPagePdf.take(8).toList()), startsWith('%PDF-'));
    });
  });

  group('4. Format Conversion Engine, Missing Component Error, Cancellation & 17-Format Suite', () {
    test('Throws MissingLibreOfficeComponentException when LibreOffice is required but not installed', () async {
      expect(
        () => service.convertFile(
          inputBytes: Uint8List.fromList(utf8.encode('Sample Word Doc')),
          sourceFileName: 'report.docx',
          targetFormat: ConvertTargetFormat.toPdf,
          options: const ConvertJobOptions(
            preferredEngine: ConversionEngineKind.libreOfficeHeadless,
          ),
          libreOfficeExecutablePath: null,
          requireInstalledLibreOffice: true,
        ),
        throwsA(isA<MissingLibreOfficeComponentException>()),
      );
    });

    test('Honors cancellation token and cleans up temporary files', () async {
      final token = PdfTaskCancellationToken()..cancel();
      expect(
        () => service.convertFile(
          inputBytes: Uint8List.fromList(utf8.encode('Sample')),
          sourceFileName: 'cancel_test.pdf',
          targetFormat: ConvertTargetFormat.pdfToWordDocx,
          cancellationToken: token,
        ),
        throwsStateError,
      );
    });

    test('Runs full 17-format sample conversion test suite with 100% pass rate', () async {
      final results = await service.runFullSampleConversionTestSuite();
      expect(results.length, equals(17));
      for (final row in results) {
        expect(
          row.passed,
          isTrue,
          reason: 'Expected ${row.testCaseId} (${row.sourceFormat} -> ${row.targetFormat}) to pass',
        );
        expect(row.outputSizeBytes, greaterThan(0));
        expect(row.sinhalaUnicodePreserved, isTrue);
      }
    });
  });
}
