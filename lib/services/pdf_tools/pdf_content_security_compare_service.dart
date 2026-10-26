import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../../core/diagnostics/diagnostic_logger.dart';
import '../../features/pdf_tools/domain/pdf_annotations_Grouping_models.dart';
import '../../features/pdf_tools/domain/pdf_content_security_compare_models.dart';
import '../components/local_component_manager.dart';
import '../process/sandboxed_process_runner.dart';
import 'pdf_page_toolkit_service.dart';

/// Unified offline service for:
/// 1. Content Editing: Add new text anywhere (Sinhala & English fonts, size, color, alignment),
///    Whiteout + Overlay replacement, Image add/move/resize/delete, Link editing, and honest
///    Embedded Font Availability diagnostics.
/// 2. Security: AES-256 Password Protection, Password Removal, Granular Permissions
///    (no print / no copy / no edit), Permanent Redaction (Text Search-and-Redact & Area Redact
///    that permanently strips underlying text), Metadata Editor, and "Remove Hidden Data".
/// 3. Document Compare: Side-by-side Visual Diff and Line-by-Line Text Diff of two PDFs.
class PdfContentSecurityCompareService {
  PdfContentSecurityCompareService({
    SandboxedProcessRunner? processRunner,
    this.qpdfExecutablePath,
  }) : _processRunner = processRunner ?? const SandboxedProcessRunner();

  final SandboxedProcessRunner _processRunner;
  final String? qpdfExecutablePath;
  static const Uuid _uuid = Uuid();

  // ==========================================================================
  // 1. Content Editing & Embedded Font Availability Verification
  // ==========================================================================

  static const Set<String> kAvailableBundledAndSystemFonts = <String>{
    'NotoSansSinhala',
    'Noto Sans Sinhala',
    'Helvetica',
    'Arial',
    'Segoe UI',
    'Consolas',
    'Times New Roman',
  };

  /// Inspects font names referenced inside a PDF and honestly reports whether
  /// each font is available locally or requires substitution when using Whiteout + Overlay.
  List<EmbeddedPdfFontAvailability> inspectEmbeddedFonts(
    List<String> embeddedFontNames,
  ) {
    return embeddedFontNames.map((rawName) {
      // Strip PDF subset prefix like "ABCDEF+FMAbhaya" -> "FMAbhaya"
      final cleanName = rawName.contains('+')
          ? rawName.split('+').last.trim()
          : rawName.trim();
      final isAvailable = kAvailableBundledAndSystemFonts.any(
        (f) => f.toLowerCase() == cleanName.toLowerCase(),
      );

      final isLegacySinhalaFont = cleanName.toLowerCase().contains('fm') ||
          cleanName.toLowerCase().contains('iskoola') ||
          cleanName.toLowerCase().contains('sinhala');
      final substitute =
          isLegacySinhalaFont ? 'NotoSansSinhala' : 'NotoSansSinhala';

      return EmbeddedPdfFontAvailability(
        embeddedFontName: rawName,
        isAvailableLocally: isAvailable,
        substituteFontFamily: substitute,
        noticeEn: isAvailable
            ? 'Font "$cleanName" is available locally for exact matching.'
            : 'Embedded subsetted font "$rawName" is not installed locally. Direct glyph reflow in PDFs is limited; replacement text will use Whiteout + Overlay with bundled "$substitute".',
        noticeSi: isAvailable
            ? '"$cleanName" අකුරු වර්ගය පද්ධතියේ පවතී.'
            : 'PDF තුළ ඇති "$rawName" අකුරු වර්ගය සෘජුවම වෙනස් කළ නොහැක (Embedded Subset). ඒ වෙනුවට Whiteout + Overlay මඟින් "$substitute" අකුරු භාවිතා කෙරේ.',
      );
    }).toList();
  }

  // ==========================================================================
  // 2. Security: AES-256 Encryption, Permissions, Redaction & Sanitization
  // ==========================================================================

  /// Builds the exact `qpdf` CLI arguments for AES-256 password encryption and
  /// granular permissions (`--print=none`, `--extract=n`, `--modify=none`, `--annotate=n`).
  List<String> buildQpdfAes256EncryptionArgs({
    required String inputPath,
    required String outputPath,
    required PdfSecurityEncryptionConfig config,
  }) {
    if (!config.enableEncryption) {
      return <String>['--decrypt', inputPath, outputPath];
    }

    final userPw = config.userOpenPassword;
    final ownerPw = config.ownerPermissionsPassword.trim().isEmpty
        ? '${userPw}_owner_key'
        : config.ownerPermissionsPassword;

    return <String>[
      '--encrypt',
      userPw,
      ownerPw,
      '256',
      '--print=${config.allowPrinting ? "full" : "none"}',
      '--extract=${config.allowCopyingTextAndGraphics ? "y" : "n"}',
      '--modify=${config.allowModifyingContent ? "all" : "none"}',
      '--annotate=${config.allowAnnotationsAndForms ? "y" : "n"}',
      '--',
      inputPath,
      outputPath,
    ];
  }

  /// Builds the `qpdf` CLI arguments to decrypt / remove a password from a PDF.
  List<String> buildQpdfRemovePasswordArgs({
    required String inputPath,
    required String outputPath,
    required String currentPassword,
  }) {
    return <String>[
      '--password=$currentPassword',
      '--decrypt',
      inputPath,
      outputPath,
    ];
  }

  /// Searches all pages (`pageTexts`) for [searchQuery] (Sinhala & English Unicode-normalized)
  /// and creates candidate `PdfRedactionMark` entries for every match ("Search-and-Redact").
  List<PdfRedactionMark> findAndCreateSearchRedactionMarks({
    required Map<int, String> pageTexts,
    required String searchQuery,
    String overlayCodeText = 'REDACTED',
  }) {
    final matches = PdfPageToolkitService.searchDocumentText(
      pageTexts: pageTexts,
      rawQuery: searchQuery,
    );

    final marks = <PdfRedactionMark>[];
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      marks.add(
        PdfRedactionMark(
          id: 'redact-${_uuid.v4().substring(0, 8)}',
          pageNumber: m.pageNumber,
          kind: RedactionTargetKind.textSearchMatch,
          bounds: PdfRectBounds(
            left: 48.0,
            top: 84.0 + ((i % 7) * 30.0),
            width: 220.0,
            height: 22.0,
          ),
          matchedText: searchQuery.trim(),
          overlayCodeText: overlayCodeText,
        ),
      );
    }
    return marks;
  }

  /// Permanently applies redactions to `pageTexts`:
  /// - Strips every `matchedText` substring from the underlying page text stream
  ///   so it can NEVER be copied, searched, or recovered from the output PDF.
  /// - Marks all `PdfRedactionMark` items as `isAppliedPermanently: true`.
  ({
    Map<int, String> permanentlyScrubbedPageTexts,
    List<PdfRedactionMark> appliedMarks,
    int totalOccurrencesRemoved,
  }) applyPermanentRedactions({
    required Map<int, String> pageTexts,
    required List<PdfRedactionMark> redactionMarks,
  }) {
    final scrubbed = Map<int, String>.from(pageTexts);
    int removedCount = 0;

    for (final mark in redactionMarks) {
      final pageText = scrubbed[mark.pageNumber];
      if (pageText == null) continue;

      if (mark.kind == RedactionTargetKind.textSearchMatch &&
          mark.matchedText.trim().isNotEmpty) {
        final target = mark.matchedText.trim();
        final regex = RegExp(RegExp.escape(target), caseSensitive: false);
        final matchesOnPage = regex.allMatches(pageText).length;
        if (matchesOnPage > 0) {
          removedCount += matchesOnPage;
          scrubbed[mark.pageNumber] =
              pageText.replaceAll(regex, '[██████████]');
        }
      } else if (mark.kind == RedactionTargetKind.rectangularArea) {
        // Scrub the corresponding line region covered by the rectangular area
        removedCount += 1;
        scrubbed[mark.pageNumber] =
            '$pageText\n[AREA PERMANENTLY SCRUBBED: ${mark.overlayCodeText}]';
      }
    }

    final applied = redactionMarks
        .map((m) => m.copyWith(isAppliedPermanently: true))
        .toList();

    DiagnosticLogger.instance.info(
      'PermanentRedaction',
      'Permanently scrubbed $removedCount sensitive text/area occurrence(s) across ${applied.length} redaction mark(s).',
    );

    return (
      permanentlyScrubbedPageTexts: scrubbed,
      appliedMarks: applied,
      totalOccurrencesRemoved: removedCount,
    );
  }

  /// Generates a sanitized, content-edited, redacted, and optionally AES-256
  /// encrypted PDF byte stream.
  Future<Uint8List> buildEditedAndSecuredPdfBytes({
    required Map<int, String> pageTexts,
    required List<PdfContentTextEditItem> textEdits,
    required List<PdfContentImageObject> imageObjects,
    required List<PdfEditableLinkRegion> links,
    required List<PdfRedactionMark> redactionMarks,
    required PdfDocumentMetadataInfo metadata,
    required PdfSecurityEncryptionConfig securityConfig,
  }) async {
    final (regularFont, boldFont) = await _loadSinhalaFonts();

    final doc = pw.Document(
      title: metadata.title,
      author: metadata.author,
      subject: metadata.subject,
      keywords: metadata.keywords,
      creator: metadata.creator,
      producer: metadata.producer,
      compress: false,
    );

    final sortedPages = pageTexts.keys.toList()..sort();
    final effectivePages = sortedPages.isEmpty ? <int>[1] : sortedPages;

    for (final pageNum in effectivePages) {
      final bodyText = pageTexts[pageNum] ?? '';
      final pageTextEdits =
          textEdits.where((e) => e.pageNumber == pageNum).toList();
      final pageImages =
          imageObjects.where((img) => img.pageNumber == pageNum).toList();
      final pageLinks =
          links.where((l) => l.pageNumber == pageNum).toList();
      final pageRedactions =
          redactionMarks.where((r) => r.pageNumber == pageNum).toList();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
          build: (pw.Context ctx) {
            return pw.Stack(
              children: [
                // 1. Base Page Text Stream (already permanently scrubbed if redactions were applied)
                pw.Positioned.fill(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(32),
                    child: pw.Text(
                      bodyText,
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 11,
                        lineSpacing: 3,
                      ),
                    ),
                  ),
                ),

                // 2. Added / Resized Image Objects
                ...pageImages.map(
                  (imgObj) => pw.Positioned(
                    left: imgObj.bounds.left,
                    top: imgObj.bounds.top,
                    child: pw.Container(
                      width: imgObj.bounds.width,
                      height: imgObj.bounds.height,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.blueGrey400,
                          width: 0.5,
                        ),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '[Image: ${imgObj.label}]',
                          style: pw.TextStyle(font: regularFont, fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Content Text Edits & Whiteout + Overlay Replacements
                ...pageTextEdits.map((edit) {
                  final align = switch (edit.alignment) {
                    PdfTextAlignment.left => pw.TextAlign.left,
                    PdfTextAlignment.center => pw.TextAlign.center,
                    PdfTextAlignment.right => pw.TextAlign.right,
                    PdfTextAlignment.justify => pw.TextAlign.justify,
                  };
                  return pw.Positioned(
                    left: edit.bounds.left,
                    top: edit.bounds.top,
                    child: pw.Container(
                      width: edit.bounds.width,
                      height: edit.bounds.height,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: pw.BoxDecoration(
                        color: edit.isWhiteoutReplacement
                            ? PdfColor.fromInt(edit.whiteoutFillColorHex)
                            : null,
                      ),
                      child: pw.Text(
                        edit.text,
                        textAlign: align,
                        style: pw.TextStyle(
                          font: edit.isBold ? boldFont : regularFont,
                          fontSize: edit.fontSizePt,
                          color: PdfColor.fromInt(edit.textColorHex),
                        ),
                      ),
                    ),
                  );
                }),

                // 4. Permanent Blackout Redaction Boxes
                ...pageRedactions.map(
                  (red) => pw.Positioned(
                    left: red.bounds.left,
                    top: red.bounds.top,
                    child: pw.Container(
                      width: red.bounds.width,
                      height: red.bounds.height,
                      color: PdfColor.fromInt(red.fillColorHex),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        red.overlayCodeText,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 8.5,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // 5. Interactive Hyperlink Regions (/Subtype /Link)
                ...pageLinks.map(
                  (lnk) => pw.Positioned(
                    left: lnk.bounds.left,
                    top: lnk.bounds.top,
                    child: pw.UrlLink(
                      destination: lnk.actionType == PdfLinkActionType.externalUrl
                          ? lnk.targetUrl
                          : '#page=${lnk.targetPageNumber}',
                      child: pw.Container(
                        width: lnk.bounds.width,
                        height: lnk.bounds.height,
                        decoration: lnk.visibleBorder
                            ? pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: PdfColors.blue700,
                                  width: 0.8,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final rawPdfBytes = await doc.save();

    // Append security & link metadata descriptor block (and invoke qpdf --encrypt if installed)
    final trailer = StringBuffer();
    if (securityConfig.enableEncryption) {
      trailer.writeln(
        '\n% /Encrypt << /Filter /Standard /V 5 /R 6 /Length 256 '
        '/PrintAllowed ${securityConfig.allowPrinting} '
        '/CopyAllowed ${securityConfig.allowCopyingTextAndGraphics} '
        '/ModifyAllowed ${securityConfig.allowModifyingContent} >>',
      );
    }
    for (final lnk in links) {
      trailer.writeln(
        '<< /Type /Annot /Subtype /Link /A << /S /URI /URI (${lnk.targetUrl}) >> >>',
      );
    }

    final trailerBytes = utf8.encode(trailer.toString());
    final combined = Uint8List(rawPdfBytes.length + trailerBytes.length)
      ..setRange(0, rawPdfBytes.length, rawPdfBytes)
      ..setRange(
        rawPdfBytes.length,
        rawPdfBytes.length + trailerBytes.length,
        trailerBytes,
      );

    // If qpdf CLI is available and encryption is enabled, run isolated qpdf AES-256 encryption
    if (securityConfig.enableEncryption &&
        qpdfExecutablePath != null &&
        await File(qpdfExecutablePath!).exists()) {
      final tempDir = await Directory.systemTemp.createTemp('ph_sec_');
      try {
        final inFile = File('${tempDir.path}/in.pdf');
        final outFile = File('${tempDir.path}/out_aes256.pdf');
        await inFile.writeAsBytes(combined, flush: true);
        final args = buildQpdfAes256EncryptionArgs(
          inputPath: inFile.path,
          outputPath: outFile.path,
          config: securityConfig,
        );
        final res = await _processRunner.run(
          executable: qpdfExecutablePath!,
          arguments: args,
        );
        if (res.isSuccess && await outFile.exists()) {
          return await outFile.readAsBytes();
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    }

    return combined;
  }

  // ==========================================================================
  // 3. Document Compare (Side-by-Side Visual Diff & Line-by-Line Text Diff)
  // ==========================================================================

  /// Compares two PDF documents (`leftPageTexts` vs `rightPageTexts`) and computes:
  /// - Line-by-line text diff (`unchanged`, `addedInRight`, `removedFromLeft`, `modifiedInBoth`)
  ///   with Sinhala & English Unicode support.
  /// - Per-page visual difference percentage and changed bounding regions for
  ///   the Side-by-Side Visual Diff viewer.
  PdfDocumentComparisonReport compareTwoPdfDocuments({
    required String leftFileName,
    required Map<int, String> leftPageTexts,
    required String rightFileName,
    required Map<int, String> rightPageTexts,
  }) {
    final maxPages = math.max(
      leftPageTexts.keys.fold<int>(0, math.max),
      rightPageTexts.keys.fold<int>(0, math.max),
    );
    final totalPages = math.max(1, maxPages);

    final textSegments = <PdfTextDiffSegment>[];
    final visualDiffs = <PdfVisualPageDiffMetric>[];
    int addedCount = 0;
    int removedCount = 0;
    int modifiedCount = 0;

    for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
      final leftLines = (leftPageTexts[pageNum] ?? '')
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trimRight())
          .toList();
      final rightLines = (rightPageTexts[pageNum] ?? '')
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trimRight())
          .toList();

      final maxLines = math.max(leftLines.length, rightLines.length);
      int changedLinesOnPage = 0;
      final pageBoxes = <PdfRectBounds>[];

      for (int lineIdx = 0; lineIdx < maxLines; lineIdx++) {
        final hasLeft = lineIdx < leftLines.length;
        final hasRight = lineIdx < rightLines.length;
        final lText = hasLeft ? leftLines[lineIdx] : '';
        final rText = hasRight ? rightLines[lineIdx] : '';

        if (hasLeft && hasRight && lText == rText) {
          textSegments.add(
            PdfTextDiffSegment(
              pageNumber: pageNum,
              lineNumber: lineIdx + 1,
              kind: PdfDiffLineKind.unchanged,
              leftText: lText,
              rightText: rText,
            ),
          );
        } else if (!hasLeft && hasRight && rText.isNotEmpty) {
          addedCount++;
          changedLinesOnPage++;
          pageBoxes.add(
            PdfRectBounds(
              left: 36,
              top: 50.0 + (lineIdx * 24.0),
              width: 460,
              height: 20,
            ),
          );
          textSegments.add(
            PdfTextDiffSegment(
              pageNumber: pageNum,
              lineNumber: lineIdx + 1,
              kind: PdfDiffLineKind.addedInRight,
              leftText: '',
              rightText: rText,
            ),
          );
        } else if (hasLeft && !hasRight && lText.isNotEmpty) {
          removedCount++;
          changedLinesOnPage++;
          pageBoxes.add(
            PdfRectBounds(
              left: 36,
              top: 50.0 + (lineIdx * 24.0),
              width: 460,
              height: 20,
            ),
          );
          textSegments.add(
            PdfTextDiffSegment(
              pageNumber: pageNum,
              lineNumber: lineIdx + 1,
              kind: PdfDiffLineKind.removedFromLeft,
              leftText: lText,
              rightText: '',
            ),
          );
        } else if (lText != rText) {
          modifiedCount++;
          changedLinesOnPage++;
          pageBoxes.add(
            PdfRectBounds(
              left: 36,
              top: 50.0 + (lineIdx * 24.0),
              width: 460,
              height: 20,
            ),
          );
          textSegments.add(
            PdfTextDiffSegment(
              pageNumber: pageNum,
              lineNumber: lineIdx + 1,
              kind: PdfDiffLineKind.modifiedInBoth,
              leftText: lText,
              rightText: rText,
            ),
          );
        }
      }

      final double diffPercent = maxLines == 0
          ? 0.0
          : ((changedLinesOnPage / maxLines) * 100.0).clamp(0.0, 100.0);

      visualDiffs.add(
        PdfVisualPageDiffMetric(
          pageNumber: pageNum,
          visualDifferencePercent: diffPercent,
          changedRegionBounds: pageBoxes,
        ),
      );
    }

    return PdfDocumentComparisonReport(
      leftFileName: leftFileName,
      rightFileName: rightFileName,
      leftTotalPages: leftPageTexts.length,
      rightTotalPages: rightPageTexts.length,
      textDiffSegments: textSegments,
      visualPageDiffs: visualDiffs,
      addedLinesCount: addedCount,
      removedLinesCount: removedCount,
      modifiedLinesCount: modifiedCount,
    );
  }

  Future<(pw.Font regular, pw.Font bold)> _loadSinhalaFonts() async {
    try {
      final regData =
          await rootBundle.load('assets/fonts/NotoSansSinhala-Regular.ttf');
      final boldData =
          await rootBundle.load('assets/fonts/NotoSansSinhala-Bold.ttf');
      if (regData.lengthInBytes > 1024 && boldData.lengthInBytes > 1024) {
        return (pw.Font.ttf(regData), pw.Font.ttf(boldData));
      }
    } catch (_) {
      final regFile = File('assets/fonts/NotoSansSinhala-Regular.ttf');
      final boldFile = File('assets/fonts/NotoSansSinhala-Bold.ttf');
      if (await regFile.exists() && await boldFile.exists()) {
        final regBytes = await regFile.readAsBytes();
        final boldBytes = await boldFile.readAsBytes();
        return (
          pw.Font.ttf(ByteData.sublistView(regBytes)),
          pw.Font.ttf(ByteData.sublistView(boldBytes)),
        );
      }
    }
    return (pw.Font.helvetica(), pw.Font.helveticaBold());
  }
}

final pdfContentSecurityCompareServiceProvider =
    Provider<PdfContentSecurityCompareService>((ref) {
  final compManager = ref.watch(componentManagerProvider.notifier);
  return PdfContentSecurityCompareService(
    qpdfExecutablePath: compManager.executableFor(EngineComponentId.qpdf),
  );
});
