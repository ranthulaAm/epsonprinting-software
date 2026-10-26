import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'print_queue_item.dart';

/// Rating for effective printed resolution (PPI = Pixels Per Inch).
enum PpiQualityRating {
  crisp(
    minPpi: 300.0,
    labelEn: 'Crisp / Photo Grade (300+ PPI)',
    labelSi: 'ඉතා පැහැදිලියි (300+ PPI)',
    shortLabelEn: '300+ PPI',
    shortLabelSi: '300+ PPI',
    color: Color(0xFF16A34A), // Green
    icon: Icons.verified_rounded,
    descriptionEn: 'High resolution suitable for crisp photos, fine text, and professional printing.',
    descriptionSi: 'පැහැදිලි ඡායාරූප සහ සියුම් අකුරු සඳහා විශිෂ්ට උසස් තත්ත්වයකි.',
  ),
  acceptable(
    minPpi: 150.0,
    labelEn: 'Acceptable / Good (150-299 PPI)',
    labelSi: 'ප්‍රමාණවත් (150-299 PPI)',
    shortLabelEn: 'Good (150-299 PPI)',
    shortLabelSi: 'ප්‍රමාණවත් (150-299 PPI)',
    color: Color(0xFFD97706), // Amber
    icon: Icons.info_outline_rounded,
    descriptionEn: 'Good for general documents, office charts, and viewing from normal reading distances.',
    descriptionSi: 'සාමාන්‍ය කාර්යාලීය ලිපිලේඛන සහ සටහන් සඳහා හොඳ තත්ත්වයකි.',
  ),
  low(
    minPpi: 0.0,
    labelEn: 'Low Resolution / Pixelated (< 150 PPI)',
    labelSi: 'අඩු පැහැදිලි බව (< 150 PPI)',
    shortLabelEn: 'Low (< 150 PPI)',
    shortLabelSi: 'අඩුයි (< 150 PPI)',
    color: Color(0xFFDC2626), // Red
    icon: Icons.warning_amber_rounded,
    descriptionEn: 'Image may appear blurry, soft, or pixelated when printed at this size.',
    descriptionSi: 'මුද්‍රණය කළ පසු බොඳ වී හෝ කොටු කොටු වී (pixelated) පෙනීමට ඉඩ ඇත.',
  );

  final double minPpi;
  final String labelEn;
  final String labelSi;
  final String shortLabelEn;
  final String shortLabelSi;
  final Color color;
  final IconData icon;
  final String descriptionEn;
  final String descriptionSi;

  const PpiQualityRating({
    required this.minPpi,
    required this.labelEn,
    required this.labelSi,
    required this.shortLabelEn,
    required this.shortLabelSi,
    required this.color,
    required this.icon,
    required this.descriptionEn,
    required this.descriptionSi,
  });

  static PpiQualityRating fromPpi(double ppi) {
    if (ppi >= 299.9) return PpiQualityRating.crisp;
    if (ppi >= 149.9) return PpiQualityRating.acceptable;
    return PpiQualityRating.low;
  }
}

/// Calculated effective printed resolution details for an image or page.
class PpiEvaluation {
  final int pixelWidth;
  final int pixelHeight;
  final double printedWidthMm;
  final double printedHeightMm;
  final double effectivePpiX;
  final double effectivePpiY;
  final double effectivePpi;
  final PpiQualityRating rating;
  final double scaleFactor;
  final bool isCropped;
  final bool isRotated;
  final int nUpCount;
  final String explanationEn;
  final String explanationSi;

  const PpiEvaluation({
    required this.pixelWidth,
    required this.pixelHeight,
    required this.printedWidthMm,
    required this.printedHeightMm,
    required this.effectivePpiX,
    required this.effectivePpiY,
    required this.effectivePpi,
    required this.rating,
    required this.scaleFactor,
    required this.isCropped,
    required this.isRotated,
    required this.nUpCount,
    required this.explanationEn,
    required this.explanationSi,
  });

  double get printedWidthInches => printedWidthMm / 25.4;
  double get printedHeightInches => printedHeightMm / 25.4;

  Map<String, dynamic> toMap() => {
        'pixelWidth': pixelWidth,
        'pixelHeight': pixelHeight,
        'printedWidthMm': printedWidthMm,
        'printedHeightMm': printedHeightMm,
        'effectivePpiX': effectivePpiX,
        'effectivePpiY': effectivePpiY,
        'effectivePpi': effectivePpi,
        'rating': rating.name,
        'scaleFactor': scaleFactor,
        'isCropped': isCropped,
        'isRotated': isRotated,
        'nUpCount': nUpCount,
        'explanationEn': explanationEn,
        'explanationSi': explanationSi,
      };
}

/// Detailed image occurrence inside a multi-page document or PDF.
class PageImageResolutionDetail {
  final int pageIndex; // 1-based page index
  final String imageId;
  final String imageName;
  final Rect relativeBounds; // Position (0.0 to 1.0) on the page
  final PpiEvaluation evaluation;

  const PageImageResolutionDetail({
    required this.pageIndex,
    required this.imageId,
    required this.imageName,
    required this.relativeBounds,
    required this.evaluation,
  });
}

/// Resampling filter algorithm for print preparation.
enum ResamplingAlgorithm {
  none(
    nameEn: 'None (Nearest Neighbor)',
    nameSi: 'කිසිවක් නැත (Nearest Neighbor)',
    descEn: 'Preserves exact raw pixels. Fast, but produces blocky pixels if upscaled.',
    descSi: 'පැරණි පික්සල් එලෙසම තබයි. ඉක්මන් නමුත් විශාල කළ විට කොටු පෙනේ.',
  ),
  bicubic(
    nameEn: 'Bicubic Interpolation',
    nameSi: 'Bicubic (සිනිඳු කිරීම)',
    descEn: 'Smooth cubic curve interpolation. Standard for office graphics and photos.',
    descSi: 'පික්සල් අතර සිනිඳු සංක්‍රාන්තියක් ඇති කරයි. සාමාන්‍ය ඡායාරූප සඳහා හොඳයි.',
  ),
  lanczos(
    nameEn: 'Lanczos-3 (Windowed Sinc)',
    nameSi: 'Lanczos-3 (උසස් තත්ත්වයේ)',
    descEn: 'High-fidelity 3-lobe windowed sinc filter. Preserves sharp edges without ringing artifacts.',
    descSi: 'දාර තියුණුව තබා ගනිමින් ඉහළම ගුණාත්මක බවකින් විශාල කරයි.',
  );

  final String nameEn;
  final String nameSi;
  final String descEn;
  final String descSi;

  const ResamplingAlgorithm({
    required this.nameEn,
    required this.nameSi,
    required this.descEn,
    required this.descSi,
  });
}

/// Log record of resampling action taken on an image. Never resample silently!
class ResamplingLogRecord {
  final String fileName;
  final int originalWidth;
  final int originalHeight;
  final int newWidth;
  final int newHeight;
  final ResamplingAlgorithm algorithm;
  final DateTime timestamp;
  final String detailsEn;
  final String detailsSi;

  const ResamplingLogRecord({
    required this.fileName,
    required this.originalWidth,
    required this.originalHeight,
    required this.newWidth,
    required this.newHeight,
    required this.algorithm,
    required this.timestamp,
    required this.detailsEn,
    required this.detailsSi,
  });
}

/// Render DPI used when rasterization is explicitly required.
enum RenderDpiChoice {
  auto(
    dpiValue: 0,
    labelEn: 'Auto (Matches Printer DPI: 300 / 600)',
    labelSi: 'ස්වයංක්‍රීය (ප්‍රින්ටරයට අනුව: 300 / 600)',
    memoryTier: 'Normal',
  ),
  dpi150(
    dpiValue: 150,
    labelEn: '150 DPI (Fast Draft Raster)',
    labelSi: '150 DPI (ඉක්මන් කෙටුම්පත්)',
    memoryTier: 'Low',
  ),
  dpi300(
    dpiValue: 300,
    labelEn: '300 DPI (Standard Print)',
    labelSi: '300 DPI (සාමාන්‍ය මුද්‍රණය)',
    memoryTier: 'Medium',
  ),
  dpi600(
    dpiValue: 600,
    labelEn: '600 DPI (High Detail)',
    labelSi: '600 DPI (උසස් පැහැදිලි බව)',
    memoryTier: 'High',
  ),
  dpi1200(
    dpiValue: 1200,
    labelEn: '1200 DPI (Ultra Fine - High Memory)',
    labelSi: '1200 DPI (ඉතා සියුම් - වැඩි මතකයක්)',
    memoryTier: 'Very High',
  );

  final int dpiValue;
  final String labelEn;
  final String labelSi;
  final String memoryTier;

  const RenderDpiChoice({
    required this.dpiValue,
    required this.labelEn,
    required this.labelSi,
    required this.memoryTier,
  });

  int resolveDpi(int printerHardwareDpi) {
    if (dpiValue > 0) return dpiValue;
    if (printerHardwareDpi >= 1200) return 600;
    return 300;
  }
}

/// Information about printer hardware DPI with speed and ink impact.
class PrinterDpiOptionInfo {
  final int dpi;
  final String labelEn;
  final String labelSi;
  final String speedAndInkNoteEn;
  final String speedAndInkNoteSi;
  final bool isSupportedOnCurrentMedia;
  final String? disabledReasonEn;
  final String? disabledReasonSi;

  const PrinterDpiOptionInfo({
    required this.dpi,
    required this.labelEn,
    required this.labelSi,
    required this.speedAndInkNoteEn,
    required this.speedAndInkNoteSi,
    required this.isSupportedOnCurrentMedia,
    this.disabledReasonEn,
    this.disabledReasonSi,
  });

  static PrinterDpiOptionInfo forDpi({
    required int dpi,
    required String mediaType,
  }) {
    final isPlain = mediaType.toLowerCase().contains('plain');
    final isGlossy = mediaType.toLowerCase().contains('glossy') || mediaType.toLowerCase().contains('photo');

    if (dpi <= 360) {
      final supported = !isGlossy;
      return PrinterDpiOptionInfo(
        dpi: dpi,
        labelEn: '$dpi DPI — Fast / Draft',
        labelSi: '$dpi DPI — ඉක්මන් කෙටුම්පත',
        speedAndInkNoteEn: 'Fastest printing speed; uses minimum ink. Best for everyday rough drafts.',
        speedAndInkNoteSi: 'අධිවේගී මුද්‍රණය; අවම තීන්ත භාවිතය. සාමාන්‍ය කෙටුම්පත් සඳහා සුදුසුයි.',
        isSupportedOnCurrentMedia: supported,
        disabledReasonEn: supported ? null : 'Draft mode is not recommended on glossy photo paper.',
        disabledReasonSi: supported ? null : 'ග්ලොසි ෆොටෝ කොළ සඳහා කෙටුම්පත් (Draft) ක්‍රමය සුදුසු නැත.',
      );
    } else if (dpi <= 720) {
      return PrinterDpiOptionInfo(
        dpi: dpi,
        labelEn: '$dpi DPI — Standard / Normal',
        labelSi: '$dpi DPI — සාමාන්‍ය ගුණාත්මක බව',
        speedAndInkNoteEn: 'Balanced print speed and standard ink consumption. Excellent for text and office graphics.',
        speedAndInkNoteSi: 'සමබර මුද්‍රණ වේගය සහ තීන්ත භාවිතය. ලිපි ලේඛන සඳහා වඩාත් සුදුසුයි.',
        isSupportedOnCurrentMedia: true,
      );
    } else if (dpi <= 1440) {
      return PrinterDpiOptionInfo(
        dpi: dpi,
        labelEn: '$dpi DPI — High Quality / Fine',
        labelSi: '$dpi DPI — උසස් ගුණාත්මක බව',
        speedAndInkNoteEn: 'Sharper fine detail and smoother gradients. Moderate speed and ink usage.',
        speedAndInkNoteSi: 'සියුම් විස්තර සහ පැහැදිලි වර්ණ. මධ්‍යස්ථ වේගයක් සහ තීන්ත ප්‍රමාණයක් ගනී.',
        isSupportedOnCurrentMedia: true,
      );
    } else {
      final supported = !isPlain;
      return PrinterDpiOptionInfo(
        dpi: dpi,
        labelEn: '$dpi DPI — Best / Photo Grade',
        labelSi: '$dpi DPI — ඉහළම ඡායාරූප තත්ත්වය',
        speedAndInkNoteEn: 'Micro-droplet ultra-fine detail. Slower print speed; maximum ink usage.',
        speedAndInkNoteSi: 'ඉතා සියුම් තීන්ත බිඳිති. සෙමින් මුද්‍රණය වන අතර වැඩි තීන්ත ප්‍රමාණයක් ගනී.',
        isSupportedOnCurrentMedia: supported,
        disabledReasonEn: supported ? null : 'Plain paper cannot absorb 2400+ DPI droplet volume without cockling/bleeding.',
        disabledReasonSi: supported ? null : 'සාමාන්‍ය කඩදාසිවලට අධික තීන්ත ප්‍රමාණය උරාගත නොහැකි බැවින් තීන්ත බොඳ විය හැක.',
      );
    }
  }
}

/// Photo print size recommendation.
class PhotoPrintSizeSuggestion {
  final String sizeName;
  final double widthMm;
  final double heightMm;
  final double expectedPpi;
  final PpiQualityRating rating;
  final bool isRecommendedForSource;

  const PhotoPrintSizeSuggestion({
    required this.sizeName,
    required this.widthMm,
    required this.heightMm,
    required this.expectedPpi,
    required this.rating,
    required this.isRecommendedForSource,
  });
}

/// Core mathematical engine for PPI and Resolution calculations.
class EffectivePpiCalculator {
  static const double mmPerInch = 25.4;

  /// Computes effective PPI at printed size.
  ///
  /// Takes pixel dimensions, target paper dimensions (in mm), margins,
  /// orientation, scale mode, custom scale percentage, N-up count, and crop boundaries.
  static PpiEvaluation evaluate({
    required int pixelWidth,
    required int pixelHeight,
    required String paperSize,
    double? customPaperWidthMm,
    double? customPaperHeightMm,
    PageOrientation orientation = PageOrientation.portrait,
    MarginPreset marginPreset = MarginPreset.normal,
    double customMarginMm = 12.7,
    PrintScaleMode scaleMode = PrintScaleMode.fitToPage,
    double customScalePercent = 100.0,
    int pagesPerSheet = 1,
    Rect? cropRectPixels, // Optional crop area in source pixel space
  }) {
    // 1. Determine effective source pixel dimensions after cropping
    final effectivePxW = cropRectPixels != null ? cropRectPixels.width.round() : pixelWidth;
    final effectivePxH = cropRectPixels != null ? cropRectPixels.height.round() : pixelHeight;

    // 2. Determine base paper dimensions in mm
    final (double baseW, double baseH) = switch (paperSize) {
      'Letter' => (215.9, 279.4),
      'Legal' => (215.9, 355.6),
      'A3' => (297.0, 420.0),
      'A5' => (148.0, 210.0),
      'A6' => (105.0, 148.0),
      '4x6 in (10x15 cm)' => (101.6, 152.4),
      'Photo 4x6' => (101.6, 152.4),
      '5x7 in (13x18 cm)' => (127.0, 177.8),
      'Passport 35x45 mm' => (35.0, 45.0),
      'Visa 2x2 in' => (50.8, 50.8),
      'Custom' => (
          (customPaperWidthMm ?? 210.0).clamp(30.0, 1500.0),
          (customPaperHeightMm ?? 297.0).clamp(30.0, 1500.0),
        ),
      _ => (210.0, 297.0), // Default A4
    };

    final (double sheetW, double sheetH) = orientation == PageOrientation.landscape
        ? (baseH, baseW)
        : (baseW, baseH);

    // 3. Determine margin deduction
    final marginMm = switch (marginPreset) {
      MarginPreset.normal => 12.7,
      MarginPreset.narrow => 6.35,
      MarginPreset.none => 0.0,
      MarginPreset.custom => customMarginMm.clamp(0.0, 50.0),
    };

    final printableW = math.max(10.0, sheetW - (marginMm * 2));
    final printableH = math.max(10.0, sheetH - (marginMm * 2));

    // 4. Factor in N-Up sheet division
    // 1-up: 1.0 factor
    // 2-up: divides sheet into 2 halves (approx scale factor 1/sqrt(2) = 0.707)
    // 4-up: divides sheet into 2x2 grid (scale factor 0.5)
    // 6-up: divides sheet into 2x3 grid (scale factor 0.33)
    // 9-up: divides sheet into 3x3 grid (scale factor 0.33)
    final double nUpScaleFactor = switch (pagesPerSheet) {
      2 => 1.0 / math.sqrt(2.0),
      4 => 0.5,
      6 => 0.38,
      9 => 0.33,
      16 => 0.25,
      _ => 1.0,
    };

    final targetAreaW = printableW * nUpScaleFactor;
    final targetAreaH = printableH * nUpScaleFactor;

    // 5. Calculate final printed dimensions in mm based on scale mode
    double finalPrintedWidthMm;
    double finalPrintedHeightMm;
    double scaleFactorApplied = 1.0;

    final imgAspect = effectivePxW / math.max(1, effectivePxH);
    final targetAspect = targetAreaW / math.max(1.0, targetAreaH);

    if (scaleMode == PrintScaleMode.fitToPage) {
      if (imgAspect > targetAspect) {
        // Image is wider than target area: bound by width
        finalPrintedWidthMm = targetAreaW;
        finalPrintedHeightMm = targetAreaW / imgAspect;
      } else {
        // Image is taller than target area: bound by height
        finalPrintedHeightMm = targetAreaH;
        finalPrintedWidthMm = targetAreaH * imgAspect;
      }
      scaleFactorApplied = finalPrintedWidthMm / targetAreaW;
    } else if (scaleMode == PrintScaleMode.customPercent) {
      final userScale = (customScalePercent / 100.0).clamp(0.05, 5.0);
      // Base printed size at 100% scale assumes 300 PPI native rendering
      final nativeWidthMm = (effectivePxW / 300.0) * mmPerInch;
      final nativeHeightMm = (effectivePxH / 300.0) * mmPerInch;

      finalPrintedWidthMm = nativeWidthMm * userScale;
      finalPrintedHeightMm = nativeHeightMm * userScale;
      scaleFactorApplied = userScale;
    } else {
      // Actual size (assumes 72 or 300 PPI native density, here normalized to 300 PPI baseline)
      finalPrintedWidthMm = (effectivePxW / 300.0) * mmPerInch;
      finalPrintedHeightMm = (effectivePxH / 300.0) * mmPerInch;
      scaleFactorApplied = 1.0;
    }

    // 6. Calculate Effective PPI: pixels divided by printed inches
    final printedWidthInches = finalPrintedWidthMm / mmPerInch;
    final printedHeightInches = finalPrintedHeightMm / mmPerInch;

    final ppiX = effectivePxW / math.max(0.01, printedWidthInches);
    final ppiY = effectivePxH / math.max(0.01, printedHeightInches);
    final effectivePpi = math.min(ppiX, ppiY);

    final rating = PpiQualityRating.fromPpi(effectivePpi);

    // 7. Explanations in spoken Sinhala and English
    final explanationEn = _generateExplanationEn(
      effectivePpi,
      rating,
      paperSize,
      effectivePxW,
      effectivePxH,
      finalPrintedWidthMm,
      finalPrintedHeightMm,
    );

    final explanationSi = _generateExplanationSi(
      effectivePpi,
      rating,
      paperSize,
      effectivePxW,
      effectivePxH,
      finalPrintedWidthMm,
      finalPrintedHeightMm,
    );

    return PpiEvaluation(
      pixelWidth: effectivePxW,
      pixelHeight: effectivePxH,
      printedWidthMm: finalPrintedWidthMm,
      printedHeightMm: finalPrintedHeightMm,
      effectivePpiX: ppiX,
      effectivePpiY: ppiY,
      effectivePpi: effectivePpi,
      rating: rating,
      scaleFactor: scaleFactorApplied,
      isCropped: cropRectPixels != null,
      isRotated: orientation == PageOrientation.landscape,
      nUpCount: pagesPerSheet,
      explanationEn: explanationEn,
      explanationSi: explanationSi,
    );
  }

  static String _generateExplanationEn(
    double ppi,
    PpiQualityRating rating,
    String paperSize,
    int pxW,
    int pxH,
    double wMm,
    double hMm,
  ) {
    final ppiInt = ppi.round();
    final wCm = (wMm / 10).toStringAsFixed(1);
    final hCm = (hMm / 10).toStringAsFixed(1);

    if (rating == PpiQualityRating.crisp) {
      return 'Prints at ${wCm}x${hCm} cm on $paperSize with $ppiInt PPI. Photo-grade crisp quality.';
    } else if (rating == PpiQualityRating.acceptable) {
      return 'Prints at ${wCm}x${hCm} cm on $paperSize with $ppiInt PPI. Good for reading distance.';
    } else {
      return 'Prints at ${wCm}x${hCm} cm on $paperSize with only $ppiInt PPI. May look soft or pixelated.';
    }
  }

  static String _generateExplanationSi(
    double ppi,
    PpiQualityRating rating,
    String paperSize,
    int pxW,
    int pxH,
    double wMm,
    double hMm,
  ) {
    final ppiInt = ppi.round();
    final wCm = (wMm / 10).toStringAsFixed(1);
    final hCm = (hMm / 10).toStringAsFixed(1);

    if (rating == PpiQualityRating.crisp) {
      return '$paperSize කොළයේ ${wCm}x${hCm} cm ප්‍රමාණයෙන් $ppiInt PPI අගයකින් ඉතා පැහැදිලිව මුද්‍රණය වේ.';
    } else if (rating == PpiQualityRating.acceptable) {
      return '$paperSize කොළයේ ${wCm}x${hCm} cm ප්‍රමාණයෙන් $ppiInt PPI අගයකින් සතුටුදායක ලෙස මුද්‍රණය වේ.';
    } else {
      return '$paperSize කොළයේ ${wCm}x${hCm} cm ප්‍රමාණයෙන් ඇත්තේ $ppiInt PPI පමණි. මුද්‍රණය බොඳ විය හැක.';
    }
  }

  /// Suggests the best print sizes for a given source image.
  static List<PhotoPrintSizeSuggestion> suggestBestSizes(int pixelWidth, int pixelHeight) {
    final standardSizes = [
      (name: 'Passport 35x45 mm', w: 35.0, h: 45.0),
      (name: 'Visa 2x2 in (50x50 mm)', w: 50.8, h: 50.8),
      (name: 'Photo 4x6 in (10x15 cm)', w: 101.6, h: 152.4),
      (name: 'Photo 5x7 in (13x18 cm)', w: 127.0, h: 177.8),
      (name: 'Photo 8x10 in (20x25 cm)', w: 203.2, h: 254.0),
      (name: 'A4 Document (21x29.7 cm)', w: 210.0, h: 297.0),
      (name: 'A3 Poster (29.7x42 cm)', w: 297.0, h: 420.0),
    ];

    final suggestions = <PhotoPrintSizeSuggestion>[];
    String? bestRecommendedName;

    for (final s in standardSizes) {
      // Align paper orientation with image aspect ratio for optimal fit
      final (paperLong, paperShort) = s.w >= s.h ? (s.w, s.h) : (s.h, s.w);
      final (imgLong, imgShort) = pixelWidth >= pixelHeight
          ? (pixelWidth.toDouble(), pixelHeight.toDouble())
          : (pixelHeight.toDouble(), pixelWidth.toDouble());

      final ppiLong = imgLong / (paperLong / mmPerInch);
      final ppiShort = imgShort / (paperShort / mmPerInch);
      final ppi = math.min(ppiLong, ppiShort);
      final rating = PpiQualityRating.fromPpi(ppi);

      suggestions.add(
        PhotoPrintSizeSuggestion(
          sizeName: s.name,
          widthMm: s.w,
          heightMm: s.h,
          expectedPpi: ppi,
          rating: rating,
          isRecommendedForSource: false,
        ),
      );
    }

    // Mark the largest recommended size that achieves 300+ PPI (or acceptable if none)
    var recommended = suggestions.lastWhere(
      (s) => s.rating == PpiQualityRating.crisp,
      orElse: () => suggestions.firstWhere(
        (s) => s.rating == PpiQualityRating.acceptable,
        orElse: () => suggestions.first,
      ),
    );

    return suggestions.map((s) {
      if (s.sizeName == recommended.sizeName) {
        return PhotoPrintSizeSuggestion(
          sizeName: s.sizeName,
          widthMm: s.widthMm,
          heightMm: s.heightMm,
          expectedPpi: s.expectedPpi,
          rating: s.rating,
          isRecommendedForSource: true,
        );
      }
      return s;
    }).toList();
  }

  /// Calculates estimated rasterization memory footprint in Megabytes (MB).
  static double estimateRasterMemoryMb({
    required double pageWInches,
    required double pageHInches,
    required int renderDpi,
    int colorChannels = 3, // 3 for 24-bit RGB, 4 for 32-bit CMYK
  }) {
    final pxW = pageWInches * renderDpi;
    final pxH = pageHInches * renderDpi;
    final totalBytes = pxW * pxH * colorChannels;
    return totalBytes / (1024.0 * 1024.0);
  }
}
