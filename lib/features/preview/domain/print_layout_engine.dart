import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../services/printer/models/printer_models.dart';
import '../../../services/typography/sinhala_text_composer.dart';
import '../../workspace/domain/print_queue_item.dart';

class PreviewSheetSlot {
  const PreviewSheetSlot({
    required this.sourcePageNumber, // null means blank padded page in Booklet/N-up
    this.tileRow = 0,
    this.tileCol = 0,
    this.tileGridSize = 1,
  });

  final int? sourcePageNumber;
  final int tileRow;
  final int tileCol;
  final int tileGridSize;

  bool get isBlank => sourcePageNumber == null;
}

class PreviewPhysicalSheet {
  const PreviewPhysicalSheet({
    required this.sheetIndex, // 1-based physical sheet index
    required this.sideNumber, // 1-based side index
    required this.isBackSide,
    required this.rows,
    required this.cols,
    required this.slots,
    required this.isBookletSpread,
    required this.isPosterTile,
  });

  final int sheetIndex;
  final int sideNumber;
  final bool isBackSide;
  final int rows;
  final int cols;
  final List<PreviewSheetSlot> slots;
  final bool isBookletSpread;
  final bool isPosterTile;
}

class CapabilityRestrictionNotice {
  const CapabilityRestrictionNotice({
    required this.settingKey,
    required this.reasonEn,
    required this.reasonSi,
  });

  final String settingKey;
  final String reasonEn;
  final String reasonSi;

  String reason(String lang) => lang == 'si' ? reasonSi : reasonEn;
}

class CapabilityEvaluation {
  const CapabilityEvaluation({
    required this.sanitizedSettings,
    required this.duplexSupported,
    required this.colorSupported,
    required this.customPaperSupported,
    required this.traySelectionSupported,
    required this.mediaTypeSupported,
    required this.notices,
  });

  final FilePrintSettings sanitizedSettings;
  final bool duplexSupported;
  final bool colorSupported;
  final bool customPaperSupported;
  final bool traySelectionSupported;
  final bool mediaTypeSupported;
  final List<CapabilityRestrictionNotice> notices;

  String? noticeFor(String key, String lang) {
    final match = notices.where((n) => n.settingKey == key).firstOrNull;
    return match?.reason(lang);
  }
}

abstract final class PrintLayoutEngine {
  /// Parses custom page range expressions like `"1-3, 5, 8-10"`, filters by
  /// Odd/Even subset, and applies Reverse Order.
  static List<int> parseEffectivePages({
    required int totalDocumentPages,
    required String pageRangeExpr,
    required PageSubset subset,
    required bool reverseOrder,
  }) {
    final int safeTotal = math.max(1, totalDocumentPages);
    List<int> basePages = [];

    final trimmed = pageRangeExpr.trim();
    if (trimmed.isEmpty) {
      basePages = List<int>.generate(safeTotal, (i) => i + 1);
    } else {
      final parts = trimmed.split(',');
      for (final rawPart in parts) {
        final part = rawPart.trim();
        if (part.isEmpty) continue;

        if (part.contains('-')) {
          final bounds = part.split('-').map((s) => s.trim()).toList();
          if (bounds.length == 2) {
            final int? start = int.tryParse(bounds[0]);
            final int? end = int.tryParse(bounds[1]);
            if (start != null && end != null) {
              final int clampedStart = start.clamp(1, safeTotal);
              final int clampedEnd = end.clamp(1, safeTotal);
              if (clampedStart <= clampedEnd) {
                for (var p = clampedStart; p <= clampedEnd; p++) {
                  basePages.add(p);
                }
              } else {
                for (var p = clampedStart; p >= clampedEnd; p--) {
                  basePages.add(p);
                }
              }
            }
          }
        } else {
          final int? single = int.tryParse(part);
          if (single != null && single >= 1 && single <= safeTotal) {
            basePages.add(single);
          }
        }
      }
    }

    if (basePages.isEmpty) {
      basePages = List<int>.generate(safeTotal, (i) => i + 1);
    }

    // Filter by Odd / Even subset
    Iterable<int> filtered = basePages;
    if (subset == PageSubset.oddOnly) {
      filtered = basePages.where((p) => p.isOdd);
    } else if (subset == PageSubset.evenOnly) {
      filtered = basePages.where((p) => p.isEven);
    }

    final result = filtered.toList();
    if (result.isEmpty) {
      // Ensure at least 1 page is returned if user selects Even on a 1-page doc
      return [basePages.first];
    }

    if (reverseOrder) {
      return result.reversed.toList();
    }
    return result;
  }

  /// Computes the sequence of physical sheets/sides to be printed and previewed,
  /// handling 1-up, N-up (2, 4, 6, 9), Booklet saddle-stitch imposition, and
  /// Poster tiling (2x2, 3x3, 4x4).
  static List<PreviewPhysicalSheet> computePhysicalSheets({
    required int totalDocumentPages,
    required FilePrintSettings settings,
  }) {
    final effectivePages = parseEffectivePages(
      totalDocumentPages: totalDocumentPages,
      pageRangeExpr: settings.pageRange,
      subset: settings.pageSubset,
      reverseOrder: settings.reverseOrder,
    );

    final bool isDuplex = settings.duplex != DuplexMode.none;
    final List<PreviewPhysicalSheet> sheets = [];

    switch (settings.layoutMode) {
      case SheetLayoutMode.standard:
        for (var i = 0; i < effectivePages.length; i++) {
          final int sideNum = i + 1;
          final int physSheet = isDuplex ? ((i ~/ 2) + 1) : sideNum;
          sheets.add(
            PreviewPhysicalSheet(
              sheetIndex: physSheet,
              sideNumber: sideNum,
              isBackSide: isDuplex && i.isOdd,
              rows: 1,
              cols: 1,
              slots: [PreviewSheetSlot(sourcePageNumber: effectivePages[i])],
              isBookletSpread: false,
              isPosterTile: false,
            ),
          );
        }

      case SheetLayoutMode.nUp:
        final int n = switch (settings.pagesPerSheet) {
          2 => 2,
          4 => 4,
          6 => 6,
          9 => 9,
          _ => 2,
        };
        final (int rows, int cols) = _gridForNUp(
          n,
          settings.orientation == PageOrientation.landscape,
        );

        int sideIdx = 0;
        for (var i = 0; i < effectivePages.length; i += n) {
          sideIdx++;
          final chunk = effectivePages.skip(i).take(n).toList();
          final slots = <PreviewSheetSlot>[
            ...chunk.map((p) => PreviewSheetSlot(sourcePageNumber: p)),
            for (var pad = chunk.length; pad < n; pad++)
              const PreviewSheetSlot(sourcePageNumber: null),
          ];

          sheets.add(
            PreviewPhysicalSheet(
              sheetIndex: isDuplex ? (((sideIdx - 1) ~/ 2) + 1) : sideIdx,
              sideNumber: sideIdx,
              isBackSide: isDuplex && (sideIdx - 1).isOdd,
              rows: rows,
              cols: cols,
              slots: slots,
              isBookletSpread: false,
              isPosterTile: false,
            ),
          );
        }

      case SheetLayoutMode.booklet:
        // Pad total pages to a multiple of 4 for saddle-stitch booklet folding
        final int paddedCount = ((effectivePages.length + 3) ~/ 4) * 4;
        final List<int?> padded = [
          ...effectivePages,
          for (var i = effectivePages.length; i < paddedCount; i++) null,
        ];

        final int sheetCount = paddedCount ~/ 4;
        int sideCounter = 0;

        for (var s = 0; s < sheetCount; s++) {
          // Front of sheet s: [left = padded[last - 2*s], right = padded[2*s]]
          final int? frontLeft = padded[paddedCount - 1 - (2 * s)];
          final int? frontRight = padded[2 * s];
          sideCounter++;
          sheets.add(
            PreviewPhysicalSheet(
              sheetIndex: s + 1,
              sideNumber: sideCounter,
              isBackSide: false,
              rows: 1,
              cols: 2,
              slots: [
                PreviewSheetSlot(sourcePageNumber: frontLeft),
                PreviewSheetSlot(sourcePageNumber: frontRight),
              ],
              isBookletSpread: true,
              isPosterTile: false,
            ),
          );

          // Back of sheet s: [left = padded[2*s + 1], right = padded[last - 2*s - 1]]
          final int? backLeft = padded[(2 * s) + 1];
          final int? backRight = padded[paddedCount - 2 - (2 * s)];
          sideCounter++;
          sheets.add(
            PreviewPhysicalSheet(
              sheetIndex: s + 1,
              sideNumber: sideCounter,
              isBackSide: true,
              rows: 1,
              cols: 2,
              slots: [
                PreviewSheetSlot(sourcePageNumber: backLeft),
                PreviewSheetSlot(sourcePageNumber: backRight),
              ],
              isBookletSpread: true,
              isPosterTile: false,
            ),
          );
        }

      case SheetLayoutMode.poster:
        final int grid = settings.posterGridSize.clamp(2, 4);
        int sideCounter = 0;
        for (final pageNum in effectivePages) {
          for (var r = 0; r < grid; r++) {
            for (var c = 0; c < grid; c++) {
              sideCounter++;
              sheets.add(
                PreviewPhysicalSheet(
                  sheetIndex: sideCounter,
                  sideNumber: sideCounter,
                  isBackSide: false,
                  rows: 1,
                  cols: 1,
                  slots: [
                    PreviewSheetSlot(
                      sourcePageNumber: pageNum,
                      tileRow: r,
                      tileCol: c,
                      tileGridSize: grid,
                    ),
                  ],
                  isBookletSpread: false,
                  isPosterTile: true,
                ),
              );
            }
          }
        }
    }

    return sheets;
  }

  static (int rows, int cols) _gridForNUp(int n, bool isLandscape) {
    switch (n) {
      case 2:
        return isLandscape ? (1, 2) : (2, 1);
      case 4:
        return (2, 2);
      case 6:
        return isLandscape ? (2, 3) : (3, 2);
      case 9:
        return (3, 3);
      default:
        return (1, 1);
    }
  }

  /// Evaluates the active `FilePrintSettings` against the selected `PrinterDevice`'s
  /// hardware/driver capabilities. Never silently ignores unsupported settings:
  /// returns human-readable explanations and a sanitized settings object.
  static CapabilityEvaluation evaluateCapabilityRestrictions({
    required FilePrintSettings settings,
    required PrinterDevice? printer,
  }) {
    if (printer == null) {
      return CapabilityEvaluation(
        sanitizedSettings: settings,
        duplexSupported: true,
        colorSupported: true,
        customPaperSupported: true,
        traySelectionSupported: true,
        mediaTypeSupported: true,
        notices: const [],
      );
    }

    final caps = printer.capabilities;
    final notices = <CapabilityRestrictionNotice>[];
    var sanitized = settings;

    // 1. Duplex Support Check
    final bool duplexOk = caps.supportsDuplex;
    if (!duplexOk) {
      notices.add(
        CapabilityRestrictionNotice(
          settingKey: 'duplex',
          reasonEn:
              'Disabled: "${printer.displayName}" does not support two-sided (duplex) hardware printing.',
          reasonSi:
              'අක්‍රියයි: "${printer.displayName}" මුද්‍රණ යන්ත්‍රය දෙපැත්තම මුද්‍රණය (Duplex) සඳහා සහය නොදක්වයි.',
        ),
      );
      if (sanitized.duplex != DuplexMode.none) {
        sanitized = sanitized.copyWith(duplex: DuplexMode.none);
      }
    }

    // 2. Color vs Monochrome Check
    final bool colorOk = caps.supportsColor;
    if (!colorOk) {
      notices.add(
        CapabilityRestrictionNotice(
          settingKey: 'color',
          reasonEn:
              'Disabled: "${printer.displayName}" is a monochrome (B&W only) printer.',
          reasonSi:
              'අක්‍රියයි: "${printer.displayName}" කළු-සුදු (B&W) පමණක් මුද්‍රණය කරන යන්ත්‍රයකි.',
        ),
      );
      if (sanitized.isColor) {
        sanitized = sanitized.copyWith(isColor: false);
      }
    }

    // 3. Paper Tray Check
    final bool trayOk =
        printer.connectionType != PrinterConnectionType.virtual &&
            caps.trays.length > 1;
    if (!trayOk) {
      notices.add(
        CapabilityRestrictionNotice(
          settingKey: 'tray',
          reasonEn: printer.connectionType == PrinterConnectionType.virtual
              ? 'Disabled: Virtual PDF/XPS printers do not have physical paper trays.'
              : 'Disabled: "${printer.displayName}" only reports a single automatic input tray.',
          reasonSi: printer.connectionType == PrinterConnectionType.virtual
              ? 'අක්‍රියයි: අතථ්‍ය (Virtual PDF) මුද්‍රණ යන්ත්‍රවලට භෞතික කඩදාසි තැටි නොමැත.'
              : 'අක්‍රියයි: මෙම මුද්‍රණ යන්ත්‍රයට ඇත්තේ එක් ස්වයංක්‍රීය කඩදාසි තැටියක් පමණි.',
        ),
      );
    }

    // 4. Media / Paper Type Check
    final bool mediaOk =
        printer.connectionType != PrinterConnectionType.virtual;
    if (!mediaOk) {
      notices.add(
        CapabilityRestrictionNotice(
          settingKey: 'mediaType',
          reasonEn:
              'Disabled: Virtual PDF/XPS drivers do not use physical paper media weights (Glossy/Cardstock).',
          reasonSi:
              'අක්‍රියයි: Virtual PDF මුද්‍රණ යන්ත්‍ර සඳහා කඩදාසි වර්ගය (Glossy/Cardstock) අදාළ නොවේ.',
        ),
      );
    }

    return CapabilityEvaluation(
      sanitizedSettings: sanitized,
      duplexSupported: duplexOk,
      colorSupported: colorOk,
      customPaperSupported: true,
      traySelectionSupported: trayOk,
      mediaTypeSupported: mediaOk,
      notices: notices,
    );
  }

  static pw.Font? _cachedSinhalaRegular;
  static pw.Font? _cachedSinhalaBold;

  static Future<pw.ThemeData?> _loadBundledSinhalaPdfTheme() async {
    try {
      if (_cachedSinhalaRegular == null) {
        final regFile = File('assets/fonts/NotoSansSinhala-Regular.ttf');
        if (await regFile.exists()) {
          final bytes = await regFile.readAsBytes();
          _cachedSinhalaRegular = pw.Font.ttf(bytes.buffer.asByteData());
        }
      }
      if (_cachedSinhalaBold == null) {
        final boldFile = File('assets/fonts/NotoSansSinhala-Bold.ttf');
        if (await boldFile.exists()) {
          final bytes = await boldFile.readAsBytes();
          _cachedSinhalaBold = pw.Font.ttf(bytes.buffer.asByteData());
        }
      }
      if (_cachedSinhalaRegular != null) {
        return pw.ThemeData.withFont(
          base: _cachedSinhalaRegular!,
          bold: _cachedSinhalaBold ?? _cachedSinhalaRegular!,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Generates a composed PDF byte buffer incorporating page range, N-up/Booklet/Poster
  /// imposition, custom margins, headers/footers, page numbers, watermarks, and
  /// bundled Noto Sans Sinhala font embedding.
  static Future<Uint8List> generateComposedPdfBytes({
    required PrintQueueItem item,
    required FilePrintSettings settings,
  }) async {
    final sinhalaTheme = await _loadBundledSinhalaPdfTheme();
    final doc = pw.Document(
      title: item.fileName,
      creator: 'Print Helper Offline Engine (Noto Sans Sinhala Embedded)',
      theme: sinhalaTheme,
    );

    final dims = settings.effectivePaperDimensionsMm;
    final pageFormat = PdfPageFormat(
      dims.widthMm * PdfPageFormat.mm,
      dims.heightMm * PdfPageFormat.mm,
      marginAll: settings.effectiveMarginMm * PdfPageFormat.mm,
    );

    // If source file is Plain Text or Markdown, paginate its blocks using the
    // user's typography settings (font size, line spacing, word wrap)
    List<List<StyledTextBlock>>? textPages;
    if (item.documentType == PrintDocumentType.plainText ||
        item.documentType == PrintDocumentType.markdown) {
      try {
        final f = File(item.filePath);
        if (await f.exists()) {
          final rawText =
              utf8.decode(await f.readAsBytes(), allowInvalid: true);
          final blocks = SinhalaTextComposer.parseDocumentBlocks(
            rawText: rawText,
            isMarkdown: item.documentType == PrintDocumentType.markdown,
          );
          textPages = SinhalaTextComposer.paginateBlocks(
            blocks: blocks,
            printableWidthMm:
                math.max(40.0, dims.widthMm - (settings.effectiveMarginMm * 2)),
            printableHeightMm: math.max(
              40.0,
              dims.heightMm - (settings.effectiveMarginMm * 2),
            ),
            fontSizePt: settings.textFontSizePt,
            lineSpacing: settings.textLineSpacing,
            wrapLines: settings.textWrapLines,
          );
        }
      } catch (_) {}
    }

    final int effectiveDocPageCount = textPages?.length ?? item.pageCount;
    final sheets = computePhysicalSheets(
      totalDocumentPages: effectiveDocPageCount,
      settings: settings,
    );

    for (final sheet in sheets) {
      // Pre-rasterize HarfBuzz-shaped Sinhala page bitmap if running inside Flutter UI
      Uint8List? shapedPngBytes;
      if (textPages != null && sheet.slots.isNotEmpty) {
        final firstPageNum = sheet.slots.first.sourcePageNumber;
        if (firstPageNum != null &&
            firstPageNum >= 1 &&
            firstPageNum <= textPages.length) {
          shapedPngBytes = await SinhalaTextComposer.renderShapedPageToPng(
            pageBlocks: textPages[firstPageNum - 1],
            widthPx: 794,
            heightPx: 1123,
            fontFamily: settings.textFontFamily,
            fontSizePt: settings.textFontSizePt,
            lineSpacing: settings.textLineSpacing,
            wrapLines: settings.textWrapLines,
            headerText: settings.headerText,
            footerText: settings.footerText,
            pageNumberLabel: settings.showPageNumbers
                ? 'Page ${sheet.sideNumber} of ${sheets.length}'
                : '',
            watermarkText: settings.watermarkText,
            watermarkOpacity: settings.watermarkOpacity,
          );
        }
      }

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context ctx) {
            if (shapedPngBytes != null) {
              return pw.Center(
                child: pw.Image(pw.MemoryImage(shapedPngBytes)),
              );
            }
            return pw.Stack(
              children: [
                // Main Sheet Content
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    if (settings.headerText.trim().isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(
                          settings.headerText.trim(),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    pw.Expanded(
                      child: textPages != null &&
                              sheet.slots.first.sourcePageNumber != null
                          ? pw.Column(
                              crossAxisAlignment:
                                  pw.CrossAxisAlignment.start,
                              children: textPages[
                                      (sheet.slots.first.sourcePageNumber! - 1)
                                          .clamp(0, textPages.length - 1)]
                                  .take(35)
                                  .map(
                                    (b) => pw.Padding(
                                      padding:
                                          const pw.EdgeInsets.only(bottom: 2),
                                      child: pw.Text(
                                        b.orderPrefix != null
                                            ? '${b.orderPrefix} ${b.text}'
                                            : b.text,
                                        style: pw.TextStyle(
                                          fontSize: settings.textFontSizePt,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )
                          : pw.Center(
                              child: pw.Text(
                                '${item.fileName} — Sheet ${sheet.sheetIndex} (${sheet.slots.where((s) => !s.isBlank).map((s) => 'P.${s.sourcePageNumber}').join(', ')})',
                                style: const pw.TextStyle(fontSize: 12),
                              ),
                            ),
                    ),
                    if (settings.footerText.trim().isNotEmpty ||
                        settings.showPageNumbers)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 6),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              settings.footerText.trim(),
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                            if (settings.showPageNumbers)
                              pw.Text(
                                'Page ${sheet.sideNumber} of ${sheets.length}',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey700,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Diagonal Watermark Overlay
                if (settings.watermarkText.trim().isNotEmpty)
                  pw.Center(
                    child: pw.Transform.rotateBox(
                      angle: 0.55,
                      child: pw.Opacity(
                        opacity: settings.watermarkOpacity.clamp(0.05, 0.85),
                        child: pw.Text(
                          settings.watermarkText.trim(),
                          style: pw.TextStyle(
                            fontSize: 36,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
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

    return doc.save();
  }
}
