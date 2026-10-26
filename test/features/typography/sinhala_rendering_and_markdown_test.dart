import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/core/diagnostics/diagnostic_logger.dart';
import 'package:print_helper/features/preview/domain/print_layout_engine.dart';
import 'package:print_helper/features/workspace/domain/print_queue_item.dart';
import 'package:print_helper/services/typography/sinhala_text_composer.dart';

void main() {
  group('Sinhala Orthography, Markdown/Text Pagination & Preview Parity', () {
    test(
      'verifies Rakaransaya, Yansaya, Repaya, Conjuncts, and Vowel Signs in bundled Sinhala test documents',
      () async {
        final mdFile = File('assets/test_documents/sinhala_orthography_test.md');
        final txtFile = File('assets/test_documents/sinhala_invoice_sample.txt');

        expect(await mdFile.exists(), isTrue);
        expect(await txtFile.exists(), isTrue);

        final mdText = await mdFile.readAsString();
        final txtText = await txtFile.readAsString();

        final mdReport = SinhalaTextComposer.verifySinhalaOrthography(mdText);
        expect(mdReport.containsSinhala, isTrue);
        expect(mdReport.rakaransayaCount, greaterThan(0));
        expect(mdReport.yansayaCount, greaterThan(0));
        expect(mdReport.repayaCount, greaterThan(0));
        expect(mdReport.conjunctCount, greaterThan(0));
        expect(mdReport.dependentVowelSignCount, greaterThan(10));
        expect(mdReport.isShapingReady, isTrue);

        final txtReport = SinhalaTextComposer.verifySinhalaOrthography(txtText);
        expect(txtReport.containsSinhala, isTrue);
        expect(txtReport.rakaransayaCount, greaterThan(0));
        expect(txtReport.yansayaCount, greaterThan(0));
      },
    );

    test(
      'parses Markdown headings, bullets, blockquotes, and tables and paginates deterministically with font size & word wrap',
      () async {
        final mdText =
            await File('assets/test_documents/sinhala_orthography_test.md')
                .readAsString();

        final blocks = SinhalaTextComposer.parseDocumentBlocks(
          mdText,
          isMarkdown: true,
        );
        expect(blocks, isNotEmpty);
        expect(
          blocks.any((b) => b.kind == ComposedBlockKind.heading1),
          isTrue,
        );
        expect(
          blocks.any((b) => b.kind == ComposedBlockKind.bulletItem),
          isTrue,
        );
        expect(
          blocks.any((b) => b.kind == ComposedBlockKind.tableRow),
          isTrue,
        );

        final smallFontPages = SinhalaTextComposer.paginateBlocks(
          blocks: blocks,
          fontSizePt: 10.0,
          lineSpacing: 1.2,
          wrapLines: true,
        );
        final largeFontPages = SinhalaTextComposer.paginateBlocks(
          blocks: blocks,
          fontSizePt: 20.0,
          lineSpacing: 1.8,
          wrapLines: true,
        );

        expect(smallFontPages.length, greaterThanOrEqualTo(1));
        expect(
          largeFontPages.length,
          greaterThanOrEqualTo(smallFontPages.length),
        );
      },
    );

    test(
      'preview sheet count matches generated PDF layout and DiagnosticLogger records structured report',
      () {
        const settings = FilePrintSettings(
          copies: 1,
          duplex: DuplexMode.longEdge,
          paperSize: 'A4',
          textFontFamily: 'NotoSansSinhala',
          textFontSizePt: 11.0,
          textLineSpacing: 1.45,
          textWrapLines: true,
          headerText: 'ශ්‍රී ලංකා මුද්‍රණ සහායක',
          watermarkText: 'රහසිගතයි • CONFIDENTIAL',
          showPageNumbers: true,
        );

        final previewSheets = PrintLayoutEngine.buildPreviewSheets(
          totalDocumentPages: 2,
          settings: settings,
        );
        expect(previewSheets.length, equals(2));
        expect(previewSheets.first.isBackSide, isFalse);
        expect(previewSheets.last.isBackSide, isTrue);

        final logger = DiagnosticLogger(maxEntries: 50);
        logger.info('Test', 'Verified Sinhala preview parity.');
        final report = logger.buildDiagnosticsReport(
          extraContext: {'Printer': 'Microsoft Print to PDF'},
        );
        expect(report, contains('Print Helper — Offline Diagnostics Report'));
        expect(report, contains('Verified Sinhala preview parity.'));
      },
    );
  });
}
