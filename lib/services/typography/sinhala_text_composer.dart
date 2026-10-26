import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum MarkdownBlockType {
  heading1,
  heading2,
  heading3,
  paragraph,
  bulletItem,
  numberedItem,
  blockquote,
  codeLine,
  horizontalRule,
}

class StyledTextBlock {
  const StyledTextBlock({
    required this.type,
    required this.text,
    this.orderPrefix,
  });

  final MarkdownBlockType type;
  final String text;
  final String? orderPrefix;
}

class SinhalaShapingReport {
  const SinhalaShapingReport({
    required this.containsSinhala,
    required this.rakaransayaCount,
    required this.yansayaCount,
    required this.repayaOrConjunctCount,
    required this.splitVowelCount,
    required this.hasReplacementChars,
  });

  final bool containsSinhala;
  final int rakaransayaCount;
  final int yansayaCount;
  final int repayaOrConjunctCount;
  final int splitVowelCount;
  final bool hasReplacementChars;

  bool get isValid => !hasReplacementChars;
}

abstract final class SinhalaTextComposer {
  static const String bundledFontFamily = 'NotoSansSinhala';

  // Unicode regex patterns for Sinhala complex script features
  static final RegExp _sinhalaRange = RegExp(r'[\u0D80-\u0DFF]');
  // Rakaransaya: Halant (U+0DCA) + ZWJ (U+200D) + Ra (U+0DBB)
  static final RegExp _rakaransayaPattern = RegExp('\u0DCA\u200D\u0DBB');
  // Yansaya: Halant (U+0DCA) + ZWJ (U+200D) + Ya (U+0DBA)
  static final RegExp _yansayaPattern = RegExp('\u0DCA\u200D\u0DBA');
  // Repaya or Touching Conjunct: Consonant + Halant + ZWJ + Consonant
  static final RegExp _conjunctPattern =
      RegExp(r'[\u0D9A-\u0DC6]\u0DCA\u200D[\u0D9A-\u0DC6]');
  // Two-part / pre-base vowel signs (Kombuwa variants: ෙ, ේ, ෛ, ො, ෝ, ෞ)
  static final RegExp _splitVowelPattern = RegExp(r'[\u0DD9-\u0DDE]');

  /// Analyzes a text string for Sinhala complex script sequences (Rakaransaya,
  /// Yansaya, Repaya/conjuncts, and pre-base/split vowel signs) and ensures
  /// no corrupted replacement glyphs (`U+FFFD`) exist.
  static SinhalaShapingReport verifySinhalaOrthography(String input) {
    return SinhalaShapingReport(
      containsSinhala: _sinhalaRange.hasMatch(input),
      rakaransayaCount: _rakaransayaPattern.allMatches(input).length,
      yansayaCount: _yansayaPattern.allMatches(input).length,
      repayaOrConjunctCount: _conjunctPattern.allMatches(input).length,
      splitVowelCount: _splitVowelPattern.allMatches(input).length,
      hasReplacementChars: input.contains('\uFFFD'),
    );
  }

  /// Parses raw Plain Text or Markdown into structured `StyledTextBlock`s.
  static List<StyledTextBlock> parseDocumentBlocks({
    required String rawText,
    required bool isMarkdown,
  }) {
    final lines = const LineSplitter().convert(rawText);
    final List<StyledTextBlock> blocks = [];
    bool inCodeFence = false;

    for (final rawLine in lines) {
      if (!isMarkdown) {
        blocks.add(
          StyledTextBlock(
            type: MarkdownBlockType.paragraph,
            text: _stripInlineMarkdown(rawLine, strip: false),
          ),
        );
        continue;
      }

      final trimmed = rawLine.trim();
      if (trimmed.startsWith('```')) {
        inCodeFence = !inCodeFence;
        continue;
      }

      if (inCodeFence) {
        blocks.add(
          StyledTextBlock(
            type: MarkdownBlockType.codeLine,
            text: rawLine,
          ),
        );
        continue;
      }

      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        blocks.add(
          const StyledTextBlock(
            type: MarkdownBlockType.horizontalRule,
            text: '',
          ),
        );
      } else if (trimmed.startsWith('### ')) {
        blocks.add(
          StyledTextBlock(
            type: MarkdownBlockType.heading3,
            text: _stripInlineMarkdown(trimmed.substring(4)),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        blocks.add(
          StyledTextBlock(
            type: MarkdownBlockType.heading2,
            text: _stripInlineMarkdown(trimmed.substring(3)),
          ),
        );
      } else if (trimmed.startsWith('# ')) {
        blocks.add(
          StyledTextBlock(
            type: MarkdownBlockType.heading1,
            text: _stripInlineMarkdown(trimmed.substring(2)),
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.add(
          StyledTextBlock(
            type: MarkdownBlockType.bulletItem,
            text: _stripInlineMarkdown(trimmed.substring(2)),
            orderPrefix: '•',
          ),
        );
      } else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(trimmed)!;
        blocks.add(
          StyledTextBlock(
            type: MarkdownBlockType.numberedItem,
            orderPrefix: match.group(1),
            text: _stripInlineMarkdown(match.group(2) ?? ''),
          ),
        );
      } else if (trimmed.startsWith('> ')) {
        blocks.add(
          StyledTextBlock(
            type: MarkdownBlockType.blockquote,
            text: _stripInlineMarkdown(trimmed.substring(2)),
          ),
        );
      } else {
        blocks.add(
          StyledTextBlock(
            type: MarkdownBlockType.paragraph,
            text: _stripInlineMarkdown(rawLine),
          ),
        );
      }
    }

    return blocks;
  }

  static String _stripInlineMarkdown(String line, {bool strip = true}) {
    if (!strip) return line;
    return line
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m.group(1)!);
  }

  /// Paginates parsed Plain Text or Markdown blocks into deterministic pages
  /// based on [fontSizePt], [lineSpacing], [wrapLines], and paper dimensions,
  /// ensuring that the Live Preview and Printed Output have identical page breaks.
  static List<List<StyledTextBlock>> paginateBlocks({
    required List<StyledTextBlock> blocks,
    required double printableWidthMm,
    required double printableHeightMm,
    required double fontSizePt,
    required double lineSpacing,
    required bool wrapLines,
  }) {
    final double ptToMm = 0.3528;
    final double lineHeightMm =
        math.max(2.5, fontSizePt * ptToMm * lineSpacing);
    final int maxLinesPerPage =
        math.max(5, (printableHeightMm / lineHeightMm).floor());

    // Approximate characters per line for wrapping calculation
    final double avgCharWidthMm = math.max(1.2, fontSizePt * ptToMm * 0.55);
    final int charsPerLine =
        math.max(16, (printableWidthMm / avgCharWidthMm).floor());

    final List<List<StyledTextBlock>> pages = [];
    List<StyledTextBlock> currentPage = [];
    int currentLineCount = 0;

    for (final block in blocks) {
      int blockLines = 1;
      if (block.type == MarkdownBlockType.heading1 ||
          block.type == MarkdownBlockType.heading2) {
        blockLines = 2;
      } else if (wrapLines && block.text.length > charsPerLine) {
        blockLines = (block.text.length / charsPerLine).ceil();
      }

      if (currentLineCount + blockLines > maxLinesPerPage &&
          currentPage.isNotEmpty) {
        pages.add(currentPage);
        currentPage = [];
        currentLineCount = 0;
      }

      final effectiveText = (!wrapLines && block.text.length > charsPerLine)
          ? block.text.substring(0, charsPerLine)
          : block.text;

      currentPage.add(
        StyledTextBlock(
          type: block.type,
          text: effectiveText,
          orderPrefix: block.orderPrefix,
        ),
      );
      currentLineCount += blockLines;
    }

    if (currentPage.isNotEmpty || pages.isEmpty) {
      pages.add(currentPage);
    }

    return pages;
  }

  /// Renders a paginated text/markdown page + headers/footers/watermarks using
  /// Flutter's HarfBuzz-backed `TextPainter` with `NotoSansSinhala` so that complex
  /// Sinhala ligatures (Rakaransaya `ශ්‍රී`, Yansaya `ක්‍ය`, Repaya `ධර්ම`) are
  /// shaped identically in both preview and printed output.
  static Future<Uint8List?> renderShapedPageToPng({
    required List<StyledTextBlock> pageBlocks,
    required double widthPx,
    required double heightPx,
    required String fontFamily,
    required double fontSizePt,
    required double lineSpacing,
    required bool wrapLines,
    String headerText = '',
    String footerText = '',
    String pageNumberLabel = '',
    String watermarkText = '',
    double watermarkOpacity = 0.18,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, widthPx, heightPx));

      // White paper background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, widthPx, heightPx),
        Paint()..color = const Color(0xFFFFFFFF),
      );

      final double margin = widthPx * 0.06;
      final double contentWidth = math.max(50.0, widthPx - (margin * 2));
      double cursorY = margin;

      // 1. Optional Header
      if (headerText.trim().isNotEmpty) {
        final headerTp = TextPainter(
          text: TextSpan(
            text: headerText.trim(),
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: const [bundledFontFamily, 'Iskoola Pota'],
              fontSize: fontSizePt * 0.85,
              color: const Color(0xFF555555),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: contentWidth);
        headerTp.paint(
          canvas,
          Offset(margin + (contentWidth - headerTp.width) / 2, cursorY),
        );
        cursorY += headerTp.height + 10;
      }

      // 2. Main Document Blocks
      for (final block in pageBlocks) {
        if (cursorY > heightPx - margin - 24) break;

        if (block.type == MarkdownBlockType.horizontalRule) {
          canvas.drawLine(
            Offset(margin, cursorY + 6),
            Offset(widthPx - margin, cursorY + 6),
            Paint()
              ..color = const Color(0xFFCCCCCC)
              ..strokeWidth = 1.2,
          );
          cursorY += 14;
          continue;
        }

        final (double scale, FontWeight weight, Color color) =
            switch (block.type) {
          MarkdownBlockType.heading1 => (
              1.45,
              FontWeight.w700,
              const Color(0xFF111111),
            ),
          MarkdownBlockType.heading2 => (
              1.25,
              FontWeight.w700,
              const Color(0xFF1A1A1A),
            ),
          MarkdownBlockType.heading3 => (
              1.1,
              FontWeight.w700,
              const Color(0xFF222222),
            ),
          MarkdownBlockType.blockquote => (
              1.0,
              FontWeight.w400,
              const Color(0xFF444444),
            ),
          MarkdownBlockType.codeLine => (
              0.92,
              FontWeight.w400,
              const Color(0xFF0B57D0),
            ),
          _ => (1.0, FontWeight.w400, const Color(0xFF111111)),
        };

        final displayStr = block.orderPrefix != null
            ? '${block.orderPrefix}  ${block.text}'
            : block.text;

        final tp = TextPainter(
          text: TextSpan(
            text: displayStr,
            style: TextStyle(
              fontFamily: block.type == MarkdownBlockType.codeLine
                  ? 'Consolas'
                  : fontFamily,
              fontFamilyFallback: const [bundledFontFamily, 'Iskoola Pota'],
              fontSize: fontSizePt * scale,
              fontWeight: weight,
              height: lineSpacing,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: wrapLines ? null : 1,
        )..layout(maxWidth: contentWidth);

        tp.paint(canvas, Offset(margin, cursorY));
        cursorY += tp.height + 4;
      }

      // 3. Optional Footer & Page Numbers
      if (footerText.trim().isNotEmpty || pageNumberLabel.isNotEmpty) {
        final footerLine = [
          if (footerText.trim().isNotEmpty) footerText.trim(),
          if (pageNumberLabel.isNotEmpty) pageNumberLabel,
        ].join('   •   ');
        final footerTp = TextPainter(
          text: TextSpan(
            text: footerLine,
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: const [bundledFontFamily, 'Iskoola Pota'],
              fontSize: fontSizePt * 0.85,
              color: const Color(0xFF555555),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: contentWidth);
        footerTp.paint(
          canvas,
          Offset(margin, heightPx - margin - footerTp.height),
        );
      }

      // 4. Optional Diagonal Watermark
      if (watermarkText.trim().isNotEmpty) {
        canvas.save();
        canvas.translate(widthPx / 2, heightPx / 2);
        canvas.rotate(-math.pi / 5);
        final wmTp = TextPainter(
          text: TextSpan(
            text: watermarkText.trim(),
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: const [bundledFontFamily, 'Iskoola Pota'],
              fontSize: fontSizePt * 2.4,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF888888)
                  .withOpacity(watermarkOpacity.clamp(0.05, 0.75)),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        wmTp.paint(canvas, Offset(-wmTp.width / 2, -wmTp.height / 2));
        canvas.restore();
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(widthPx.round(), heightPx.round());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
