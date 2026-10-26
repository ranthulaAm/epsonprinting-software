import 'dart:math';
import '../../workspace/domain/print_queue_item.dart';
import '../../workspace/domain/print_settings_models.dart';
import '../domain/shop_mode_models.dart';
import '../domain/shop_pricing_engine_models.dart';

/// Service performing automatic page classification, multi-dimensional pricing,
/// volume tiering, mixed-document breakdown, customer group discounts, and profit estimation.
class ShopPricingEngineService {
  const ShopPricingEngineService();

  /// Automatically classifies pages within a file into B&W, Color, and Photo-heavy.
  /// If [ownerOverrides] are provided, they take precedence over automatic detection.
  List<PageClassificationRecord> classifyFilePages({
    required PrintQueueItem file,
    Map<int, PrintColorDimension>? ownerOverrides,
    Map<int, bool>? photoOverrides,
  }) {
    final pageCount = max(1, file.pageCount);
    final isGlobalBw = !file.settings.isColor;
    final isGlobalPhoto = _isPhotoSizeOrMedia(file.settings.paperSize, file.settings.mediaType);

    final records = <PageClassificationRecord>[];

    for (int p = 1; p <= pageCount; p++) {
      // 1. Check Owner Override
      if (ownerOverrides != null && ownerOverrides.containsKey(p)) {
        final color = ownerOverrides[p]!;
        final isPhoto = photoOverrides?[p] ?? (color == PrintColorDimension.color && isGlobalPhoto);
        records.add(
          PageClassificationRecord(
            pageIndex: p,
            detectedColor: color,
            isPhotoHeavy: isPhoto,
            estimatedCoveragePercent: isPhoto ? 45.0 : (color == PrintColorDimension.color ? 15.0 : 5.0),
            isOwnerOverridden: true,
          ),
        );
        continue;
      }

      // 2. Automatic Detection
      // If user globally chose B&W, force B&W
      if (isGlobalBw) {
        records.add(
          PageClassificationRecord(
            pageIndex: p,
            detectedColor: PrintColorDimension.blackAndWhite,
            isPhotoHeavy: false,
            estimatedCoveragePercent: 4.5,
            isOwnerOverridden: false,
          ),
        );
        continue;
      }

      // If document is classified as photo or media is glossy
      if (isGlobalPhoto) {
        records.add(
          PageClassificationRecord(
            pageIndex: p,
            detectedColor: PrintColorDimension.color,
            isPhotoHeavy: true,
            estimatedCoveragePercent: 55.0,
            isOwnerOverridden: false,
          ),
        );
        continue;
      }

      // Mixed Document Heuristic (e.g. for multi-page documents where later pages are color graphs)
      // When a document is Color, but mostly text:
      final bool pageHasColor = (pageCount > 1 && p > (pageCount * 0.8).floor()) || pageCount <= 2;
      final colorDim = pageHasColor ? PrintColorDimension.color : PrintColorDimension.blackAndWhite;
      final bool isPhoto = pageHasColor && p == pageCount;

      records.add(
        PageClassificationRecord(
          pageIndex: p,
          detectedColor: colorDim,
          isPhotoHeavy: isPhoto,
          estimatedCoveragePercent: isPhoto ? 35.0 : (pageHasColor ? 12.0 : 4.5),
          isOwnerOverridden: false,
        ),
      );
    }

    return records;
  }

  /// Computes a comprehensive quote and cost/profit estimate for a list of files.
  EngineJobQuote calculateQuote({
    required List<PrintQueueItem> files,
    required PriceListPackage priceList,
    required ShopSupplyCostConfig supplyCosts,
    CustomerGroupType customerGroup = CustomerGroupType.walkIn,
    Map<String, List<PageClassificationRecord>>? filePageClassifications,
    bool isRushJob = false,
    String? customJobCode,
  }) {
    final cur = priceList.currencyConfig;
    final fees = priceList.feesConfig;

    final customerConfig = priceList.customerGroups.firstWhere(
      (g) => g.groupType == customerGroup,
      orElse: () => CustomerGroupConfig(
        groupType: customerGroup,
        groupNameEn: 'Walk-in Customer',
        groupNameSi: 'සාමාන්‍ය පාරිභෝගිකයා',
      ),
    );

    final lineItems = <EngineFilePricingItem>[];
    final warnings = <String>[];

    int totalImpressions = 0;
    int totalPhysicalSheets = 0;
    int bwImpressions = 0;
    int colorImpressions = 0;
    int photoImpressions = 0;

    double grossSubtotal = 0.0;
    double totalInkCost = 0.0;
    double totalPaperCost = 0.0;

    int remainingFreePages = customerConfig.freePagesAllowance;
    double freePagesDeductedAmount = 0.0;

    for (final file in files) {
      final s = file.settings;
      final copies = max(1, s.copies);
      final pageCount = max(1, file.pageCount);
      final isDuplex = s.duplex != DuplexMode.none;

      // Obtain or generate page classifications
      final classifications = filePageClassifications?[file.id] ??
          classifyFilePages(file: file);

      // Group pages by classification: B&W vs Color vs Photo
      int fileBwPages = 0;
      int fileColorPages = 0;
      int filePhotoPages = 0;

      for (final r in classifications) {
        if (r.isPhotoHeavy) {
          filePhotoPages++;
        } else if (r.detectedColor == PrintColorDimension.color) {
          fileColorPages++;
        } else {
          fileBwPages++;
        }
      }

      final fileImpressions = pageCount * copies;
      final fileSheetsPerCopy = isDuplex ? (pageCount / 2.0).ceil() : pageCount;
      final filePhysicalSheets = fileSheetsPerCopy * copies;

      totalImpressions += fileImpressions;
      totalPhysicalSheets += filePhysicalSheets;
      bwImpressions += (fileBwPages * copies);
      colorImpressions += (fileColorPages * copies);
      photoImpressions += (filePhotoPages * copies);

      final segments = <PriceSegmentBreakdown>[];
      double fileGross = 0.0;
      bool hasMissingPrice = false;
      String? missingNotice;

      // Segment 1: Black and White Pages
      if (fileBwPages > 0) {
        final segmentImpressions = fileBwPages * copies;
        final match = _findBestMatch(
          priceList: priceList,
          printType: _detectPrintType(file.fileName, s),
          colorMode: 'bw',
          paperSize: s.paperSize,
          paperType: _mapPaperTypeToId(s.mediaType),
          isDuplex: isDuplex,
          quality: _mapQualityToId(s.quality),
          printerId: 'any',
          coverageBand: 'any',
        );

        if (match == null) {
          hasMissingPrice = true;
          missingNotice = 'No rate defined for [${s.paperSize} B&W ${_mapPaperTypeToId(s.mediaType)}]. Fallback rate used.';
          warnings.add('Warning: Missing price for "${file.fileName}" B&W segment. Never silently charging zero; applied conservative fallback.');
        }

        final unitRate = match != null
            ? match.getPriceForQuantity(segmentImpressions)
            : 15.0; // Fallback rate: never 0!

        final segmentSubtotal = segmentImpressions * unitRate;
        fileGross += segmentSubtotal;

        segments.add(
          PriceSegmentBreakdown(
            segmentLabelEn: 'B&W Pages (${fileBwPages}p × $copies copies)',
            segmentLabelSi: 'කළු සුදු පිටු (${fileBwPages} × කොපි $copies)',
            pageCount: fileBwPages,
            copies: copies,
            totalImpressions: segmentImpressions,
            unitPrice: unitRate,
            subtotal: segmentSubtotal,
            matchedRuleId: match?.id ?? 'FALLBACK_BW',
          ),
        );
      }

      // Segment 2: Color Document Pages
      if (fileColorPages > 0) {
        final segmentImpressions = fileColorPages * copies;
        final match = _findBestMatch(
          priceList: priceList,
          printType: _detectPrintType(file.fileName, s),
          colorMode: 'color',
          paperSize: s.paperSize,
          paperType: _mapPaperTypeToId(s.mediaType),
          isDuplex: isDuplex,
          quality: _mapQualityToId(s.quality),
          printerId: 'any',
          coverageBand: 'any',
        );

        if (match == null) {
          hasMissingPrice = true;
          missingNotice = 'No rate defined for [${s.paperSize} Color ${_mapPaperTypeToId(s.mediaType)}]. Fallback rate used.';
          warnings.add('Warning: Missing price for "${file.fileName}" Color segment. Applied conservative fallback rate.');
        }

        final unitRate = match != null
            ? match.getPriceForQuantity(segmentImpressions)
            : 40.0; // Fallback rate: never 0!

        final segmentSubtotal = segmentImpressions * unitRate;
        fileGross += segmentSubtotal;

        segments.add(
          PriceSegmentBreakdown(
            segmentLabelEn: 'Color Pages (${fileColorPages}p × $copies copies)',
            segmentLabelSi: 'වර්ණ පිටු (${fileColorPages} × කොපි $copies)',
            pageCount: fileColorPages,
            copies: copies,
            totalImpressions: segmentImpressions,
            unitPrice: unitRate,
            subtotal: segmentSubtotal,
            matchedRuleId: match?.id ?? 'FALLBACK_COLOR',
          ),
        );
      }

      // Segment 3: Photo Heavy Pages
      if (filePhotoPages > 0) {
        final segmentImpressions = filePhotoPages * copies;
        final match = _findBestMatch(
          priceList: priceList,
          printType: 'photo',
          colorMode: 'color',
          paperSize: s.paperSize,
          paperType: _mapPaperTypeToId(s.mediaType),
          isDuplex: false, // Photos are typically single-sided
          quality: 'high',
          printerId: 'any',
          coverageBand: 'any',
        );

        if (match == null) {
          hasMissingPrice = true;
          missingNotice = 'No rate defined for [${s.paperSize} Photo]. Fallback rate used.';
          warnings.add('Warning: Missing price for "${file.fileName}" Photo segment. Applied conservative fallback rate.');
        }

        final unitRate = match != null
            ? match.getPriceForQuantity(segmentImpressions)
            : 80.0; // Fallback photo rate: never 0!

        final segmentSubtotal = segmentImpressions * unitRate;
        fileGross += segmentSubtotal;

        segments.add(
          PriceSegmentBreakdown(
            segmentLabelEn: 'Photo Pages (${filePhotoPages}p × $copies copies)',
            segmentLabelSi: 'ඡායාරූප පිටු (${filePhotoPages} × කොපි $copies)',
            pageCount: filePhotoPages,
            copies: copies,
            totalImpressions: segmentImpressions,
            unitPrice: unitRate,
            subtotal: segmentSubtotal,
            matchedRuleId: match?.id ?? 'FALLBACK_PHOTO',
          ),
        );
      }

      // Surcharges per file:
      // A. High Resolution Surcharge (1440+ DPI or Best photo quality)
      final double resSurcharge = (s.targetDpi >= 1440 || s.quality == PrintQualityMode.high)
          ? (25.0 * fileImpressions)
          : 0.0;

      // B. Borderless Printing Surcharge
      final double borderlessSurcharge = s.isBorderless ? (fees.borderlessSurcharge * fileImpressions) : 0.0;

      fileGross += (resSurcharge + borderlessSurcharge);
      grossSubtotal += fileGross;

      // Supply Cost Side Estimation:
      // Ink cost factoring in Ink Saver savings
      double inkSaverDiscount = 0.0;
      if (s.toneAndInkMap != null && s.toneAndInkMap!['inkSaverEnabled'] == true) {
        inkSaverDiscount = 0.28; // 28% estimated reduction
      }
      final double rawBwInk = supplyCosts.estimatedBlackInkCostPerPage;
      final double rawColorInk = supplyCosts.estimatedColorInkCostPerPage;

      final estInk = ((fileBwPages * rawBwInk) + (fileColorPages * rawColorInk) + (filePhotoPages * rawColorInk * 1.5)) *
          copies *
          (1.0 - inkSaverDiscount);

      final sheetUnitCost = _resolvePaperUnitCost(s.paperSize, s.mediaType, supplyCosts);
      final estPaper = filePhysicalSheets * sheetUnitCost;

      totalInkCost += estInk;
      totalPaperCost += estPaper;

      lineItems.add(
        EngineFilePricingItem(
          fileName: file.fileName,
          totalPages: pageCount,
          copies: copies,
          totalImpressions: fileImpressions,
          physicalSheets: filePhysicalSheets,
          segments: segments,
          resolutionSurcharge: resSurcharge,
          borderlessSurcharge: borderlessSurcharge,
          lineGrossTotal: fileGross,
          estimatedInkCost: estInk,
          estimatedPaperCost: estPaper,
          hasMissingPriceWarning: hasMissingPrice,
          missingPriceNotice: missingNotice,
        ),
      );
    }

    // 1. Free Pages Allowance Deduction (e.g. first 2 pages free for Business/Students)
    if (remainingFreePages > 0 && lineItems.isNotEmpty) {
      final firstItem = lineItems.first;
      if (firstItem.segments.isNotEmpty) {
        final firstSeg = firstItem.segments.first;
        final freePagesToDeduct = min(remainingFreePages, firstSeg.pageCount);
        freePagesDeductedAmount = freePagesToDeduct * firstSeg.unitPrice;
      }
    }

    final afterFreePagesGross = max(0.0, grossSubtotal - freePagesDeductedAmount);

    // 2. Customer Group Percentage & Fixed Discount
    final percentDisc = afterFreePagesGross * (customerConfig.percentDiscount.clamp(0.0, 100.0) / 100.0);
    final totalGroupDiscount = min(afterFreePagesGross, percentDisc + customerConfig.fixedDiscount);
    final discountedSubtotal = max(0.0, afterFreePagesGross - totalGroupDiscount);

    // 3. Setup / Service Fee
    final setupFee = fees.setupServiceFee;

    // 4. Rush Fee
    final rushFee = isRushJob ? (discountedSubtotal * (fees.rushFeePercent / 100.0)) : 0.0;

    // 5. Minimum Job Charge Enforcement
    double minAdjustment = 0.0;
    final preMinTotal = discountedSubtotal + setupFee + rushFee;
    if (preMinTotal < fees.minimumJobCharge && totalImpressions > 0) {
      minAdjustment = fees.minimumJobCharge - preMinTotal;
    }

    final postMinTotal = preMinTotal + minAdjustment;

    // 6. Tax / Service Charge (e.g. VAT or SSCL)
    final taxRate = customerConfig.taxRatePercent > 0 ? customerConfig.taxRatePercent : fees.serviceChargePercent;
    final taxAmount = postMinTotal * (taxRate / 100.0);

    // 7. Final Total with Rounding Rule
    final rawFinal = postMinTotal + taxAmount;
    final finalPayable = cur.roundingRule.apply(rawFinal);

    // Cost side
    final totalCost = totalInkCost + totalPaperCost;
    final estProfit = finalPayable - totalCost;

    final quoteJobCode = customJobCode ?? 'QUOTE-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return EngineJobQuote(
      quoteId: 'Q_${DateTime.now().millisecondsSinceEpoch}',
      jobNumberCode: quoteJobCode,
      createdAt: DateTime.now(),
      customerGroupLabel: customerConfig.groupNameEn,
      currencyConfig: cur,
      items: lineItems,
      totalImpressions: totalImpressions,
      totalPhysicalSheets: totalPhysicalSheets,
      bwPageImpressions: bwImpressions,
      colorPageImpressions: colorImpressions,
      photoPageImpressions: photoImpressions,
      grossSubtotal: grossSubtotal,
      customerGroupDiscount: totalGroupDiscount,
      freePagesDeduction: freePagesDeductedAmount,
      minimumJobAdjustment: minAdjustment,
      setupFee: setupFee,
      rushFee: rushFee,
      taxAmount: taxAmount,
      finalPayableTotal: finalPayable,
      estimatedInkCost: totalInkCost,
      estimatedPaperCost: totalPaperCost,
      estimatedTotalCost: totalCost,
      estimatedProfit: estProfit,
      warnings: warnings,
    );
  }

  /// Checks common paper size, color, and media combinations against [priceList].
  /// Returns a list of combinations that lack a matching rule.
  List<MissingPriceCombination> detectMissingPrices(PriceListPackage priceList) {
    const checkSizes = ['A4', 'A3', '4x6 in (10x15 cm)'];
    const checkColors = ['bw', 'color'];
    const checkMedias = ['plain', 'glossy_photo'];
    const checkSides = [false, true];

    final missing = <MissingPriceCombination>[];

    for (final size in checkSizes) {
      for (final color in checkColors) {
        for (final media in checkMedias) {
          for (final duplex in checkSides) {
            // Photos are rarely duplex
            if (media == 'glossy_photo' && duplex) continue;

            final match = _findBestMatch(
              priceList: priceList,
              printType: media == 'glossy_photo' ? 'photo' : 'document_text',
              colorMode: color,
              paperSize: size,
              paperType: media,
              isDuplex: duplex,
              quality: 'normal',
              printerId: 'any',
              coverageBand: 'any',
            );

            if (match == null) {
              missing.add(
                MissingPriceCombination(
                  printType: media == 'glossy_photo' ? 'photo' : 'document_text',
                  colorMode: color,
                  paperSize: size,
                  paperType: media,
                  isDoubleSided: duplex,
                  suggestedRate: _suggestRate(size, color, media, duplex),
                ),
              );
            }
          }
        }
      }
    }

    return missing;
  }

  /// Matches the most specific rule from the price table.
  PriceTableEntry? _findBestMatch({
    required PriceListPackage priceList,
    required String printType,
    required String colorMode,
    required String paperSize,
    required String paperType,
    required bool isDuplex,
    required String quality,
    required String printerId,
    required String coverageBand,
  }) {
    PriceTableEntry? bestMatch;
    int highestScore = -1;

    for (final entry in priceList.entries) {
      final score = entry.matchScore(
        printType: printType,
        colorMode: colorMode,
        size: paperSize,
        paperType: paperType,
        duplex: isDuplex,
        quality: quality,
        printerId: printerId,
        coverageBand: coverageBand,
      );

      if (score > highestScore) {
        highestScore = score;
        bestMatch = entry;
      }
    }

    return bestMatch;
  }

  String _detectPrintType(String fileName, FilePrintSettings s) {
    final lower = fileName.toLowerCase();
    if (lower.contains('photo') || lower.endsWith('.jpg') || lower.endsWith('.png') || lower.endsWith('.jpeg')) {
      return 'photo';
    }
    if (lower.contains('passport') || lower.contains('id_card')) {
      return 'id_passport_photo';
    }
    if (s.paperSize == 'A3' && s.mediaType.contains('Matte')) {
      return 'poster_large';
    }
    return 'document_text';
  }

  String _mapPaperTypeToId(String mediaType) {
    final lower = mediaType.toLowerCase();
    if (lower.contains('glossy') || lower.contains('photo')) return 'glossy_photo';
    if (lower.contains('matte')) return 'matte';
    if (lower.contains('card') || lower.contains('bristol')) return 'card';
    return 'plain';
  }

  String _mapQualityToId(PrintQualityMode quality) {
    switch (quality) {
      case PrintQualityMode.draft:
        return 'draft';
      case PrintQualityMode.normal:
        return 'normal';
      case PrintQualityMode.high:
        return 'high';
      case PrintQualityMode.best:
        return 'best';
    }
  }

  bool _isPhotoSizeOrMedia(String paperSize, String mediaType) {
    final sLower = paperSize.toLowerCase();
    final mLower = mediaType.toLowerCase();
    return sLower.contains('4x6') ||
        sLower.contains('5x7') ||
        mLower.contains('photo') ||
        mLower.contains('glossy');
  }

  double _resolvePaperUnitCost(String size, String media, ShopSupplyCostConfig config) {
    final sLower = size.toLowerCase();
    final mLower = media.toLowerCase();
    if (sLower.contains('4x6') || mLower.contains('photo') || mLower.contains('glossy')) {
      return config.estimatedPhoto4x6SheetCost;
    }
    if (sLower.contains('a3')) {
      return config.estimatedA3PlainSheetCost;
    }
    return config.estimatedA4PlainSheetCost;
  }

  double _suggestRate(String size, String color, String media, bool duplex) {
    if (media == 'glossy_photo') return 80.0;
    if (size == 'A3') return color == 'color' ? 90.0 : 35.0;
    if (color == 'color') return duplex ? 35.0 : 40.0;
    return duplex ? 10.0 : 15.0;
  }
}

/// Represents a missing combination detected by the safeguard validator.
class MissingPriceCombination {
  final String printType;
  final String colorMode;
  final String paperSize;
  final String paperType;
  final bool isDoubleSided;
  final double suggestedRate;

  const MissingPriceCombination({
    required this.printType,
    required this.colorMode,
    required this.paperSize,
    required this.paperType,
    required this.isDoubleSided,
    required this.suggestedRate,
  });

  String get summary =>
      '$paperSize • ${colorMode == "bw" ? "B&W" : "Color"} • ${isDoubleSided ? "2-Sided" : "1-Sided"} • $paperType';
}
