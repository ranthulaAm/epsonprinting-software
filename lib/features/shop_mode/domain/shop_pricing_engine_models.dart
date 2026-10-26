import 'dart:convert';
import 'package:flutter/material.dart';

/// Print Type dimension for Shop Pricing Engine.
enum PrintTypeDimension {
  documentText(
    id: 'document_text',
    labelEn: 'Document (Text)',
    labelSi: 'ලේඛන (පෙළ)',
    icon: Icons.description_outlined,
  ),
  mixedDocument(
    id: 'mixed_document',
    labelEn: 'Mixed Document',
    labelSi: 'මිශ්‍ර ලේඛන (පෙළ + වර්ණ)',
    icon: Icons.auto_stories_outlined,
  ),
  photo(
    id: 'photo',
    labelEn: 'Photo Print',
    labelSi: 'ඡායාරූප මුද්‍රණ',
    icon: Icons.photo_outlined,
  ),
  posterLarge(
    id: 'poster_large',
    labelEn: 'Poster / Large Format',
    labelSi: 'පෝස්ටර් / විශාල ප්‍රමාණ',
    icon: Icons.aspect_ratio_outlined,
  ),
  idPassportPhoto(
    id: 'id_passport_photo',
    labelEn: 'ID / Passport Photo Sheet',
    labelSi: 'හැඳුනුම්පත් / පාස්පෝට් ඡායාරූප',
    icon: Icons.badge_outlined,
  ),
  copy(
    id: 'copy',
    labelEn: 'Photocopy / Duplicate',
    labelSi: 'ෆොටෝ කොපි (පිටපත්)',
    icon: Icons.copy_rounded,
  ),
  custom(
    id: 'custom',
    labelEn: 'Custom Print Type',
    labelSi: 'වෙනත් විශේෂ මුද්‍රණ',
    icon: Icons.extension_outlined,
  );

  final String id;
  final String labelEn;
  final String labelSi;
  final IconData icon;

  const PrintTypeDimension({
    required this.id,
    required this.labelEn,
    required this.labelSi,
    required this.icon,
  });

  static PrintTypeDimension fromId(String id) {
    return PrintTypeDimension.values.firstWhere(
      (e) => e.id == id,
      orElse: () => PrintTypeDimension.documentText,
    );
  }
}

/// Color mode dimension for pricing.
enum PrintColorDimension {
  blackAndWhite(
    id: 'bw',
    labelEn: 'Black & White',
    labelSi: 'කළු සුදු (B&W)',
    icon: Icons.contrast_rounded,
  ),
  color(
    id: 'color',
    labelEn: 'Full Color',
    labelSi: 'වර්ණ (Full Color)',
    icon: Icons.palette_outlined,
  ),
  grayscale(
    id: 'grayscale',
    labelEn: 'Grayscale (Tonal Black)',
    labelSi: 'අළු පරිමාණය (Grayscale)',
    icon: Icons.gradient_rounded,
  );

  final String id;
  final String labelEn;
  final String labelSi;
  final IconData icon;

  const PrintColorDimension({
    required this.id,
    required this.labelEn,
    required this.labelSi,
    required this.icon,
  });

  static PrintColorDimension fromId(String id) {
    return PrintColorDimension.values.firstWhere(
      (e) => e.id == id,
      orElse: () => PrintColorDimension.blackAndWhite,
    );
  }
}

/// Paper Type dimension for pricing.
enum PaperTypeDimension {
  plain(id: 'plain', labelEn: 'Plain Paper (80gsm)', labelSi: 'සාමාන්‍ය කඩදාසි (80gsm)'),
  matte(id: 'matte', labelEn: 'Matte Paper (Heavy)', labelSi: 'මැට් කඩදාසි (Matte)'),
  glossyPhoto(id: 'glossy_photo', labelEn: 'Glossy Photo Paper', labelSi: 'ග්ලොසි ෆොටෝ කොළ'),
  card(id: 'card', labelEn: 'Cardstock / Bristol', labelSi: 'කාඩ්බෝඩ් / බ්‍රිස්ටල් (Card)'),
  custom(id: 'custom', labelEn: 'Custom Paper Type', labelSi: 'වෙනත් කඩදාසි වර්ග');

  final String id;
  final String labelEn;
  final String labelSi;

  const PaperTypeDimension({
    required this.id,
    required this.labelEn,
    required this.labelSi,
  });

  static PaperTypeDimension fromId(String id) {
    return PaperTypeDimension.values.firstWhere(
      (e) => e.id == id,
      orElse: () => PaperTypeDimension.plain,
    );
  }
}

/// Print quality dimension for pricing.
enum PrintQualityDimension {
  draft(id: 'draft', labelEn: 'Draft / Eco', labelSi: 'කෙටුම්පත (Draft)'),
  normal(id: 'normal', labelEn: 'Normal / Standard', labelSi: 'සාමාන්‍ය (Normal)'),
  high(id: 'high', labelEn: 'High Detail', labelSi: 'උසස් (High Detail)'),
  best(id: 'best', labelEn: 'Best Photo (Maximum DPI)', labelSi: 'විශිෂ්ට (Best Photo)');

  final String id;
  final String labelEn;
  final String labelSi;

  const PrintQualityDimension({
    required this.id,
    required this.labelEn,
    required this.labelSi,
  });

  static PrintQualityDimension fromId(String id) {
    return PrintQualityDimension.values.firstWhere(
      (e) => e.id == id,
      orElse: () => PrintQualityDimension.normal,
    );
  }
}

/// Coverage bands for optional ink-coverage pricing.
enum CoverageBand {
  any(id: 'any', labelEn: 'Standard / Any Coverage', labelSi: 'සාමාන්‍ය ආවරණය'),
  light(id: 'light', labelEn: 'Light Coverage (< 10%)', labelSi: 'අඩු තීන්ත (< 10%)'),
  medium(id: 'medium', labelEn: 'Medium Coverage (10 - 25%)', labelSi: 'මධ්‍යම තීන්ත (10 - 25%)'),
  heavy(id: 'heavy', labelEn: 'Heavy Coverage (> 25%)', labelSi: 'වැඩි තීන්ත (> 25%)');

  final String id;
  final String labelEn;
  final String labelSi;

  const CoverageBand({
    required this.id,
    required this.labelEn,
    required this.labelSi,
  });

  static CoverageBand fromId(String id) {
    return CoverageBand.values.firstWhere(
      (e) => e.id == id,
      orElse: () => CoverageBand.any,
    );
  }
}

/// Rounding rules supported by the shop pricing engine.
enum RoundingRule {
  none(id: 'none', labelEn: 'No Rounding (Exact cents / decimals)', labelSi: 'වටයන්නේ නැත (ශත සහිතව)'),
  nearest1(id: 'nearest_1', labelEn: 'Nearest Rs. 1 (Integer)', labelSi: 'ආසන්නම රු. 1'),
  nearest5(id: 'nearest_5', labelEn: 'Nearest Rs. 5', labelSi: 'ආසන්නම රු. 5'),
  nearest10(id: 'nearest_10', labelEn: 'Nearest Rs. 10', labelSi: 'ආසන්නම රු. 10'),
  nearest50(id: 'nearest_50', labelEn: 'Nearest Rs. 50', labelSi: 'ආසන්නම රු. 50');

  final String id;
  final String labelEn;
  final String labelSi;

  const RoundingRule({
    required this.id,
    required this.labelEn,
    required this.labelSi,
  });

  double apply(double amount) {
    switch (this) {
      case RoundingRule.none:
        return amount;
      case RoundingRule.nearest1:
        return amount.roundToDouble();
      case RoundingRule.nearest5:
        return (amount / 5.0).roundToDouble() * 5.0;
      case RoundingRule.nearest10:
        return (amount / 10.0).roundToDouble() * 10.0;
      case RoundingRule.nearest50:
        return (amount / 50.0).roundToDouble() * 50.0;
    }
  }
}

/// Customer Group for differential pricing and discounts.
enum CustomerGroupType {
  walkIn(id: 'walk_in', labelEn: 'Regular / Walk-in Customer', labelSi: 'සාමාන්‍ය පාරිභෝගිකයා'),
  student(id: 'student', labelEn: 'Student Discount', labelSi: 'ශිෂ්‍ය වට්ටම්'),
  business(id: 'business', labelEn: 'Business / Corporate Account', labelSi: 'ව්‍යාපාරික / ආයතනික ගිණුම'),
  custom(id: 'custom', labelEn: 'Special Group', labelSi: 'විශේෂ කණ්ඩායම');

  final String id;
  final String labelEn;
  final String labelSi;

  const CustomerGroupType({
    required this.id,
    required this.labelEn,
    required this.labelSi,
  });
}

/// Quantity tier for bulk/tiered volume pricing (e.g. 1-10 @ Rs. 15, 11-50 @ Rs. 12, etc.).
class QuantityTier {
  final int minQty;
  final int? maxQty; // null represents infinity (e.g. 201+)
  final double unitPrice;

  const QuantityTier({
    required this.minQty,
    this.maxQty,
    required this.unitPrice,
  });

  bool matches(int quantity) {
    if (quantity < minQty) return false;
    if (maxQty != null && quantity > maxQty!) return false;
    return true;
  }

  String get label {
    if (maxQty == null) return '$minQty+ pages';
    return '$minQty - $maxQty pages';
  }

  Map<String, dynamic> toMap() => {
        'minQty': minQty,
        'maxQty': maxQty,
        'unitPrice': unitPrice,
      };

  factory QuantityTier.fromMap(Map<String, dynamic> map) {
    return QuantityTier(
      minQty: (map['minQty'] as num?)?.toInt() ?? 1,
      maxQty: (map['maxQty'] as num?)?.toInt(),
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 10.0,
    );
  }

  QuantityTier copyWith({int? minQty, int? maxQty, double? unitPrice}) {
    return QuantityTier(
      minQty: minQty ?? this.minQty,
      maxQty: maxQty ?? this.maxQty,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

/// Multi-dimensional Price Table Entry.
/// Any combination of dimensions can have its own price and tiered volume rates.
class PriceTableEntry {
  final String id;
  final String labelEn;
  final String labelSi;

  // Dimensions
  final String printTypeId; // 'document_text', 'photo', 'any', etc.
  final String colorModeId; // 'bw', 'color', 'grayscale', 'any'
  final String paperSize; // 'A4', 'A3', '4x6 in (10x15 cm)', 'any', or custom
  final String paperTypeId; // 'plain', 'matte', 'glossy_photo', 'any', or custom
  final bool? isDoubleSided; // null = any, true = duplex, false = single
  final String qualityId; // 'draft', 'normal', 'high', 'best', 'any'
  final String targetPrinterId; // 'any' or specific printer ID
  final String coverageBandId; // 'any', 'light', 'medium', 'heavy'

  // Pricing
  final double basePrice;
  final List<QuantityTier> tiers;

  const PriceTableEntry({
    required this.id,
    required this.labelEn,
    required this.labelSi,
    this.printTypeId = 'document_text',
    this.colorModeId = 'bw',
    this.paperSize = 'A4',
    this.paperTypeId = 'plain',
    this.isDoubleSided = false,
    this.qualityId = 'normal',
    this.targetPrinterId = 'any',
    this.coverageBandId = 'any',
    required this.basePrice,
    this.tiers = const [],
  });

  /// Evaluates exact unit price for a given page volume.
  double getPriceForQuantity(int quantity) {
    if (tiers.isNotEmpty) {
      for (final tier in tiers) {
        if (tier.matches(quantity)) {
          return tier.unitPrice;
        }
      }
    }
    return basePrice;
  }

  /// Calculates specificity score (higher = more specific match over generic wildcards).
  int matchScore({
    required String printType,
    required String colorMode,
    required String size,
    required String paperType,
    required bool duplex,
    required String quality,
    required String printerId,
    required String coverageBand,
  }) {
    int score = 0;

    // Print type match
    if (printTypeId == printType) {
      score += 100;
    } else if (printTypeId != 'any') {
      return -1; // Mismatch
    }

    // Color mode match
    if (colorModeId == colorMode) {
      score += 80;
    } else if (colorModeId != 'any') {
      return -1;
    }

    // Paper size match
    if (paperSize.toLowerCase() == size.toLowerCase()) {
      score += 60;
    } else if (paperSize != 'any') {
      return -1;
    }

    // Paper type match
    if (paperTypeId == paperType) {
      score += 50;
    } else if (paperTypeId != 'any') {
      return -1;
    }

    // Sides match
    if (isDoubleSided == null) {
      score += 10;
    } else if (isDoubleSided == duplex) {
      score += 40;
    } else {
      return -1;
    }

    // Quality match
    if (qualityId == quality) {
      score += 30;
    } else if (qualityId != 'any') {
      return -1;
    }

    // Printer ID match
    if (targetPrinterId == printerId) {
      score += 70;
    } else if (targetPrinterId != 'any') {
      return -1;
    }

    // Coverage band match
    if (coverageBandId == coverageBand) {
      score += 25;
    } else if (coverageBandId != 'any') {
      return -1;
    }

    return score;
  }

  PriceTableEntry copyWith({
    String? id,
    String? labelEn,
    String? labelSi,
    String? printTypeId,
    String? colorModeId,
    String? paperSize,
    String? paperTypeId,
    bool? isDoubleSided,
    String? qualityId,
    String? targetPrinterId,
    String? coverageBandId,
    double? basePrice,
    List<QuantityTier>? tiers,
  }) {
    return PriceTableEntry(
      id: id ?? this.id,
      labelEn: labelEn ?? this.labelEn,
      labelSi: labelSi ?? this.labelSi,
      printTypeId: printTypeId ?? this.printTypeId,
      colorModeId: colorModeId ?? this.colorModeId,
      paperSize: paperSize ?? this.paperSize,
      paperTypeId: paperTypeId ?? this.paperTypeId,
      isDoubleSided: isDoubleSided ?? this.isDoubleSided,
      qualityId: qualityId ?? this.qualityId,
      targetPrinterId: targetPrinterId ?? this.targetPrinterId,
      coverageBandId: coverageBandId ?? this.coverageBandId,
      basePrice: basePrice ?? this.basePrice,
      tiers: tiers ?? this.tiers,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'labelEn': labelEn,
        'labelSi': labelSi,
        'printTypeId': printTypeId,
        'colorModeId': colorModeId,
        'paperSize': paperSize,
        'paperTypeId': paperTypeId,
        'isDoubleSided': isDoubleSided,
        'qualityId': qualityId,
        'targetPrinterId': targetPrinterId,
        'coverageBandId': coverageBandId,
        'basePrice': basePrice,
        'tiers': tiers.map((t) => t.toMap()).toList(),
      };

  factory PriceTableEntry.fromMap(Map<String, dynamic> map) {
    return PriceTableEntry(
      id: map['id'] as String? ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
      labelEn: map['labelEn'] as String? ?? 'Rate Rule',
      labelSi: map['labelSi'] as String? ?? 'මිල රීතිය',
      printTypeId: map['printTypeId'] as String? ?? 'document_text',
      colorModeId: map['colorModeId'] as String? ?? 'bw',
      paperSize: map['paperSize'] as String? ?? 'A4',
      paperTypeId: map['paperTypeId'] as String? ?? 'plain',
      isDoubleSided: map['isDoubleSided'] as bool?,
      qualityId: map['qualityId'] as String? ?? 'normal',
      targetPrinterId: map['targetPrinterId'] as String? ?? 'any',
      coverageBandId: map['coverageBandId'] as String? ?? 'any',
      basePrice: (map['basePrice'] as num?)?.toDouble() ?? 10.0,
      tiers: (map['tiers'] as List<dynamic>?)
              ?.map((t) => QuantityTier.fromMap(Map<String, dynamic>.from(t as Map)))
              .toList() ??
          const [],
    );
  }
}

/// Configuration for customer groups, group discounts and tax settings.
class CustomerGroupConfig {
  final CustomerGroupType groupType;
  final String groupNameEn;
  final String groupNameSi;
  final double percentDiscount; // e.g. 15.0 for 15% discount
  final double fixedDiscount; // e.g. Rs. 20 flat discount
  final int freePagesAllowance; // e.g. first 2 pages free
  final double taxRatePercent; // e.g. 0% or 2.5% SSCL / VAT

  const CustomerGroupConfig({
    required this.groupType,
    required this.groupNameEn,
    required this.groupNameSi,
    this.percentDiscount = 0.0,
    this.fixedDiscount = 0.0,
    this.freePagesAllowance = 0,
    this.taxRatePercent = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'groupType': groupType.name,
        'groupNameEn': groupNameEn,
        'groupNameSi': groupNameSi,
        'percentDiscount': percentDiscount,
        'fixedDiscount': fixedDiscount,
        'freePagesAllowance': freePagesAllowance,
        'taxRatePercent': taxRatePercent,
      };

  factory CustomerGroupConfig.fromMap(Map<String, dynamic> map) {
    return CustomerGroupConfig(
      groupType: CustomerGroupType.values.firstWhere(
        (g) => g.name == map['groupType'],
        orElse: () => CustomerGroupType.walkIn,
      ),
      groupNameEn: map['groupNameEn'] as String? ?? 'Regular Customer',
      groupNameSi: map['groupNameSi'] as String? ?? 'සාමාන්‍ය පාරිභෝගිකයා',
      percentDiscount: (map['percentDiscount'] as num?)?.toDouble() ?? 0.0,
      fixedDiscount: (map['fixedDiscount'] as num?)?.toDouble() ?? 0.0,
      freePagesAllowance: (map['freePagesAllowance'] as num?)?.toInt() ?? 0,
      taxRatePercent: (map['taxRatePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static List<CustomerGroupConfig> get defaultCustomerGroups => const [
        CustomerGroupConfig(
          groupType: CustomerGroupType.walkIn,
          groupNameEn: 'Walk-in Customer',
          groupNameSi: 'සාමාන්‍ය පාරිභෝගිකයා',
          percentDiscount: 0.0,
          fixedDiscount: 0.0,
          freePagesAllowance: 0,
        ),
        CustomerGroupConfig(
          groupType: CustomerGroupType.student,
          groupNameEn: 'Student Discount (15%)',
          groupNameSi: 'ශිෂ්‍ය වට්ටම (15%)',
          percentDiscount: 15.0,
          fixedDiscount: 0.0,
          freePagesAllowance: 0,
        ),
        CustomerGroupConfig(
          groupType: CustomerGroupType.business,
          groupNameEn: 'Business Account (2 Free Pages)',
          groupNameSi: 'ව්‍යාපාරික ගිණුම (නොමිලේ පිටු 2)',
          percentDiscount: 10.0,
          fixedDiscount: 0.0,
          freePagesAllowance: 2,
        ),
      ];
}

/// Surcharges, setup fees and minimum job charge rules.
class JobFeesConfig {
  final double minimumJobCharge; // e.g. Rs. 30.0 minimum per job
  final double setupServiceFee; // e.g. Rs. 20.0 file preparation / handling
  final double rushFeePercent; // e.g. 25.0% for immediate priority print
  final double borderlessSurcharge; // e.g. Rs. 25.0 for edge-to-edge trimming
  final double specialMediaSurcharge; // e.g. Rs. 35.0 for heavy cardstock handling
  final double serviceChargePercent; // e.g. 5.0% service charge

  const JobFeesConfig({
    this.minimumJobCharge = 30.0,
    this.setupServiceFee = 0.0,
    this.rushFeePercent = 0.0,
    this.borderlessSurcharge = 20.0,
    this.specialMediaSurcharge = 30.0,
    this.serviceChargePercent = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'minimumJobCharge': minimumJobCharge,
        'setupServiceFee': setupServiceFee,
        'rushFeePercent': rushFeePercent,
        'borderlessSurcharge': borderlessSurcharge,
        'specialMediaSurcharge': specialMediaSurcharge,
        'serviceChargePercent': serviceChargePercent,
      };

  factory JobFeesConfig.fromMap(Map<String, dynamic> map) {
    return JobFeesConfig(
      minimumJobCharge: (map['minimumJobCharge'] as num?)?.toDouble() ?? 30.0,
      setupServiceFee: (map['setupServiceFee'] as num?)?.toDouble() ?? 0.0,
      rushFeePercent: (map['rushFeePercent'] as num?)?.toDouble() ?? 0.0,
      borderlessSurcharge: (map['borderlessSurcharge'] as num?)?.toDouble() ?? 20.0,
      specialMediaSurcharge: (map['specialMediaSurcharge'] as num?)?.toDouble() ?? 30.0,
      serviceChargePercent: (map['serviceChargePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  JobFeesConfig copyWith({
    double? minimumJobCharge,
    double? setupServiceFee,
    double? rushFeePercent,
    double? borderlessSurcharge,
    double? specialMediaSurcharge,
    double? serviceChargePercent,
  }) {
    return JobFeesConfig(
      minimumJobCharge: minimumJobCharge ?? this.minimumJobCharge,
      setupServiceFee: setupServiceFee ?? this.setupServiceFee,
      rushFeePercent: rushFeePercent ?? this.rushFeePercent,
      borderlessSurcharge: borderlessSurcharge ?? this.borderlessSurcharge,
      specialMediaSurcharge: specialMediaSurcharge ?? this.specialMediaSurcharge,
      serviceChargePercent: serviceChargePercent ?? this.serviceChargePercent,
    );
  }
}

/// Currency settings with LKR as default, configurable rounding and bilingual formatting.
class CurrencyAndRoundingConfig {
  final String currencyCode; // e.g. 'LKR', 'USD', 'EUR', 'GBP', 'INR'
  final String currencySymbolEn; // e.g. 'Rs.', '$', '€', '£', '₹'
  final String currencySymbolSi; // e.g. 'රු.', '$'
  final RoundingRule roundingRule;

  const CurrencyAndRoundingConfig({
    this.currencyCode = 'LKR',
    this.currencySymbolEn = 'Rs.',
    this.currencySymbolSi = 'රු.',
    this.roundingRule = RoundingRule.nearest1,
  });

  String format(double amount, {bool isSi = false}) {
    final rounded = roundingRule.apply(amount);
    final symbol = isSi ? currencySymbolSi : currencySymbolEn;
    if (roundingRule == RoundingRule.none) {
      return '$symbol ${rounded.toStringAsFixed(2)}';
    } else {
      return '$symbol ${rounded.round()}';
    }
  }

  Map<String, dynamic> toMap() => {
        'currencyCode': currencyCode,
        'currencySymbolEn': currencySymbolEn,
        'currencySymbolSi': currencySymbolSi,
        'roundingRule': roundingRule.name,
      };

  factory CurrencyAndRoundingConfig.fromMap(Map<String, dynamic> map) {
    return CurrencyAndRoundingConfig(
      currencyCode: map['currencyCode'] as String? ?? 'LKR',
      currencySymbolEn: map['currencySymbolEn'] as String? ?? 'Rs.',
      currencySymbolSi: map['currencySymbolSi'] as String? ?? 'රු.',
      roundingRule: RoundingRule.values.firstWhere(
        (r) => r.name == map['roundingRule'],
        orElse: () => RoundingRule.nearest1,
      ),
    );
  }
}

/// Automatic Page Classification Record for a single page of a document.
class PageClassificationRecord {
  final int pageIndex; // 1-based index
  final PrintColorDimension detectedColor;
  final bool isPhotoHeavy;
  final double estimatedCoveragePercent;
  final bool isOwnerOverridden;

  const PageClassificationRecord({
    required this.pageIndex,
    required this.detectedColor,
    this.isPhotoHeavy = false,
    this.estimatedCoveragePercent = 5.0,
    this.isOwnerOverridden = false,
  });

  PageClassificationRecord copyWith({
    int? pageIndex,
    PrintColorDimension? detectedColor,
    bool? isPhotoHeavy,
    double? estimatedCoveragePercent,
    bool? isOwnerOverridden,
  }) {
    return PageClassificationRecord(
      pageIndex: pageIndex ?? this.pageIndex,
      detectedColor: detectedColor ?? this.detectedColor,
      isPhotoHeavy: isPhotoHeavy ?? this.isPhotoHeavy,
      estimatedCoveragePercent: estimatedCoveragePercent ?? this.estimatedCoveragePercent,
      isOwnerOverridden: isOwnerOverridden ?? this.isOwnerOverridden,
    );
  }

  Map<String, dynamic> toMap() => {
        'pageIndex': pageIndex,
        'detectedColor': detectedColor.id,
        'isPhotoHeavy': isPhotoHeavy,
        'estimatedCoveragePercent': estimatedCoveragePercent,
        'isOwnerOverridden': isOwnerOverridden,
      };

  factory PageClassificationRecord.fromMap(Map<String, dynamic> map) {
    return PageClassificationRecord(
      pageIndex: (map['pageIndex'] as num?)?.toInt() ?? 1,
      detectedColor: PrintColorDimension.fromId(map['detectedColor'] as String? ?? 'bw'),
      isPhotoHeavy: map['isPhotoHeavy'] as bool? ?? false,
      estimatedCoveragePercent: (map['estimatedCoveragePercent'] as num?)?.toDouble() ?? 5.0,
      isOwnerOverridden: map['isOwnerOverridden'] as bool? ?? false,
    );
  }
}

/// Audit log record tracking who/when changed a price entry.
class PriceChangeLogEntry {
  final String id;
  final DateTime timestamp;
  final String changedBy;
  final String ruleId;
  final String fieldName;
  final String oldValue;
  final String newValue;
  final String reason;

  const PriceChangeLogEntry({
    required this.id,
    required this.timestamp,
    required this.changedBy,
    required this.ruleId,
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    this.reason = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'changedBy': changedBy,
        'ruleId': ruleId,
        'fieldName': fieldName,
        'oldValue': oldValue,
        'newValue': newValue,
        'reason': reason,
      };

  factory PriceChangeLogEntry.fromMap(Map<String, dynamic> map) {
    return PriceChangeLogEntry(
      id: map['id'] as String? ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      changedBy: map['changedBy'] as String? ?? 'Shop Owner',
      ruleId: map['ruleId'] as String? ?? '',
      fieldName: map['fieldName'] as String? ?? 'price',
      oldValue: map['oldValue'] as String? ?? '',
      newValue: map['newValue'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
    );
  }
}

/// Security PIN configuration to lock price editing from staff tampering.
class SecurityPinConfig {
  final bool isPinLockEnabled;
  final String hashedPin; // 4 to 6 digit PIN (e.g. '1234')

  const SecurityPinConfig({
    this.isPinLockEnabled = false,
    this.hashedPin = '1234',
  });

  bool verify(String inputPin) {
    if (!isPinLockEnabled) return true;
    return inputPin == hashedPin;
  }

  Map<String, dynamic> toMap() => {
        'isPinLockEnabled': isPinLockEnabled,
        'hashedPin': hashedPin,
      };

  factory SecurityPinConfig.fromMap(Map<String, dynamic> map) {
    return SecurityPinConfig(
      isPinLockEnabled: map['isPinLockEnabled'] as bool? ?? false,
      hashedPin: map['hashedPin'] as String? ?? '1234',
    );
  }
}

/// Detailed pricing breakdown for a single page classification segment.
/// (e.g. 17 B&W pages at B&W rate + 3 Color pages at Color rate in a 20-page document).
class PriceSegmentBreakdown {
  final String segmentLabelEn;
  final String segmentLabelSi;
  final int pageCount;
  final int copies;
  final int totalImpressions;
  final double unitPrice;
  final double subtotal;
  final String matchedRuleId;

  const PriceSegmentBreakdown({
    required this.segmentLabelEn,
    required this.segmentLabelSi,
    required this.pageCount,
    required this.copies,
    required this.totalImpressions,
    required this.unitPrice,
    required this.subtotal,
    required this.matchedRuleId,
  });
}

/// Itemized line item in a customer quote / invoice.
class EngineFilePricingItem {
  final String fileName;
  final int totalPages;
  final int copies;
  final int totalImpressions;
  final int physicalSheets;
  final List<PriceSegmentBreakdown> segments;
  final double resolutionSurcharge;
  final double borderlessSurcharge;
  final double lineGrossTotal;
  final double estimatedInkCost;
  final double estimatedPaperCost;
  final bool hasMissingPriceWarning;
  final String? missingPriceNotice;

  const EngineFilePricingItem({
    required this.fileName,
    required this.totalPages,
    required this.copies,
    required this.totalImpressions,
    required this.physicalSheets,
    required this.segments,
    this.resolutionSurcharge = 0.0,
    this.borderlessSurcharge = 0.0,
    required this.lineGrossTotal,
    required this.estimatedInkCost,
    required this.estimatedPaperCost,
    this.hasMissingPriceWarning = false,
    this.missingPriceNotice,
  });

  double get estimatedTotalCost => estimatedInkCost + estimatedPaperCost;
}

/// Comprehensive Job Quote & Estimate produced by the Pricing Engine.
class EngineJobQuote {
  final String quoteId;
  final String jobNumberCode;
  final DateTime createdAt;
  final String customerGroupLabel;
  final CurrencyAndRoundingConfig currencyConfig;
  final List<EngineFilePricingItem> items;

  // Totals & Impressions
  final int totalImpressions;
  final int totalPhysicalSheets;
  final int bwPageImpressions;
  final int colorPageImpressions;
  final int photoPageImpressions;

  // Price breakdown
  final double grossSubtotal;
  final double customerGroupDiscount;
  final double freePagesDeduction;
  final double minimumJobAdjustment;
  final double setupFee;
  final double rushFee;
  final double taxAmount;
  final double finalPayableTotal;

  // Cost & Profit
  final double estimatedInkCost;
  final double estimatedPaperCost;
  final double estimatedTotalCost;
  final double estimatedProfit;

  // Safeguards
  final List<String> warnings;

  const EngineJobQuote({
    required this.quoteId,
    required this.jobNumberCode,
    required this.createdAt,
    required this.customerGroupLabel,
    required this.currencyConfig,
    required this.items,
    required this.totalImpressions,
    required this.totalPhysicalSheets,
    required this.bwPageImpressions,
    required this.colorPageImpressions,
    required this.photoPageImpressions,
    required this.grossSubtotal,
    required this.customerGroupDiscount,
    required this.freePagesDeduction,
    required this.minimumJobAdjustment,
    required this.setupFee,
    required this.rushFee,
    required this.taxAmount,
    required this.finalPayableTotal,
    required this.estimatedInkCost,
    required this.estimatedPaperCost,
    required this.estimatedTotalCost,
    required this.estimatedProfit,
    this.warnings = const [],
  });

  String get formattedFinalTotal => currencyConfig.format(finalPayableTotal);
  String get formattedEstimatedProfit => currencyConfig.format(estimatedProfit);
  String get formattedEstimatedCost => currencyConfig.format(estimatedTotalCost);
}

/// Package containing complete shop price list, customer groups, fees and change logs.
class PriceListPackage {
  final String id;
  final String name;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PriceTableEntry> entries;
  final List<CustomerGroupConfig> customerGroups;
  final JobFeesConfig feesConfig;
  final CurrencyAndRoundingConfig currencyConfig;
  final SecurityPinConfig pinConfig;
  final List<PriceChangeLogEntry> changeHistory;

  const PriceListPackage({
    required this.id,
    required this.name,
    this.isDefault = true,
    required this.createdAt,
    required this.updatedAt,
    required this.entries,
    required this.customerGroups,
    required this.feesConfig,
    required this.currencyConfig,
    required this.pinConfig,
    this.changeHistory = const [],
  });

  PriceListPackage copyWith({
    String? id,
    String? name,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PriceTableEntry>? entries,
    List<CustomerGroupConfig>? customerGroups,
    JobFeesConfig? feesConfig,
    CurrencyAndRoundingConfig? currencyConfig,
    SecurityPinConfig? pinConfig,
    List<PriceChangeLogEntry>? changeHistory,
  }) {
    return PriceListPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      entries: entries ?? this.entries,
      customerGroups: customerGroups ?? this.customerGroups,
      feesConfig: feesConfig ?? this.feesConfig,
      currencyConfig: currencyConfig ?? this.currencyConfig,
      pinConfig: pinConfig ?? this.pinConfig,
      changeHistory: changeHistory ?? this.changeHistory,
    );
  }

  /// Creates a duplicate of this price list with a new name and ID.
  PriceListPackage duplicate({required String newName}) {
    final now = DateTime.now();
    return PriceListPackage(
      id: 'pricelist_${now.millisecondsSinceEpoch}',
      name: newName,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
      entries: entries
          .map((e) => e.copyWith(id: 'rule_${DateTime.now().microsecondsSinceEpoch}_${e.id}'))
          .toList(),
      customerGroups: List.from(customerGroups),
      feesConfig: feesConfig,
      currencyConfig: currencyConfig,
      pinConfig: pinConfig,
      changeHistory: [
        PriceChangeLogEntry(
          id: 'log_${now.millisecondsSinceEpoch}',
          timestamp: now,
          changedBy: 'Shop Owner',
          ruleId: 'ALL',
          fieldName: 'DUPLICATE',
          oldValue: name,
          newValue: newName,
          reason: 'Duplicated price list package',
        )
      ],
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'entries': entries.map((e) => e.toMap()).toList(),
        'customerGroups': customerGroups.map((g) => g.toMap()).toList(),
        'feesConfig': feesConfig.toMap(),
        'currencyConfig': currencyConfig.toMap(),
        'pinConfig': pinConfig.toMap(),
        'changeHistory': changeHistory.map((c) => c.toMap()).toList(),
      };

  factory PriceListPackage.fromMap(Map<String, dynamic> map) {
    return PriceListPackage(
      id: map['id'] as String? ?? 'default_pricelist',
      name: map['name'] as String? ?? 'Master Price List (LKR)',
      isDefault: map['isDefault'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      entries: (map['entries'] as List<dynamic>?)
              ?.map((e) => PriceTableEntry.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          defaultEntriesLkr,
      customerGroups: (map['customerGroups'] as List<dynamic>?)
              ?.map((g) => CustomerGroupConfig.fromMap(Map<String, dynamic>.from(g as Map)))
              .toList() ??
          CustomerGroupConfig.defaultCustomerGroups,
      feesConfig: map['feesConfig'] != null
          ? JobFeesConfig.fromMap(Map<String, dynamic>.from(map['feesConfig'] as Map))
          : const JobFeesConfig(),
      currencyConfig: map['currencyConfig'] != null
          ? CurrencyAndRoundingConfig.fromMap(
              Map<String, dynamic>.from(map['currencyConfig'] as Map))
          : const CurrencyAndRoundingConfig(),
      pinConfig: map['pinConfig'] != null
          ? SecurityPinConfig.fromMap(Map<String, dynamic>.from(map['pinConfig'] as Map))
          : const SecurityPinConfig(),
      changeHistory: (map['changeHistory'] as List<dynamic>?)
              ?.map((c) => PriceChangeLogEntry.fromMap(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          const [],
    );
  }

  String toJson() => jsonEncode(toMap());
  factory PriceListPackage.fromJson(String jsonStr) =>
      PriceListPackage.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);

  /// Exports table entries to CSV string.
  String exportToCsv() {
    final buf = StringBuffer();
    buf.writeln('Rule ID,Label (EN),Label (SI),Print Type,Color,Paper Size,Paper Type,Sides,Quality,Printer,Coverage,Base Price,Tier Rates');
    for (final e in entries) {
      final tierStr = e.tiers.map((t) => '${t.minQty}-${t.maxQty ?? "+"}:${t.unitPrice}').join(';');
      buf.writeln(
        '"${e.id}","${e.labelEn}","${e.labelSi}","${e.printTypeId}","${e.colorModeId}","${e.paperSize}","${e.paperTypeId}","${e.isDoubleSided == null ? "any" : (e.isDoubleSided! ? "duplex" : "single")}","${e.qualityId}","${e.targetPrinterId}","${e.coverageBandId}",${e.basePrice},"${tierStr}"',
      );
    }
    return buf.toString();
  }

  /// Default baseline price table for high-volume Sri Lankan and international print shops.
  static List<PriceTableEntry> get defaultEntriesLkr => [
        // 1. A4 Document B&W Single with Volume Tiers
        PriceTableEntry(
          id: 'rule_a4_doc_bw_single',
          labelEn: 'A4 Document B&W Single (Plain)',
          labelSi: 'A4 ලේඛන කළු සුදු එක් පැත්තක්',
          printTypeId: 'document_text',
          colorModeId: 'bw',
          paperSize: 'A4',
          paperTypeId: 'plain',
          isDoubleSided: false,
          qualityId: 'normal',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 15.0,
          tiers: const [
            QuantityTier(minQty: 1, maxQty: 10, unitPrice: 15.0),
            QuantityTier(minQty: 11, maxQty: 50, unitPrice: 12.0),
            QuantityTier(minQty: 51, maxQty: 200, unitPrice: 10.0),
            QuantityTier(minQty: 201, maxQty: null, unitPrice: 8.0),
          ],
        ),
        // 2. A4 Document B&W Double-Sided (Duplex)
        PriceTableEntry(
          id: 'rule_a4_doc_bw_duplex',
          labelEn: 'A4 Document B&W Duplex (Per Impression)',
          labelSi: 'A4 ලේඛන කළු සුදු දෙපැත්තම (පිටුවකට)',
          printTypeId: 'document_text',
          colorModeId: 'bw',
          paperSize: 'A4',
          paperTypeId: 'plain',
          isDoubleSided: true,
          qualityId: 'normal',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 10.0,
          tiers: const [
            QuantityTier(minQty: 1, maxQty: 10, unitPrice: 10.0),
            QuantityTier(minQty: 11, maxQty: 50, unitPrice: 8.5),
            QuantityTier(minQty: 51, maxQty: 200, unitPrice: 7.0),
            QuantityTier(minQty: 201, maxQty: null, unitPrice: 6.0),
          ],
        ),
        // 3. A4 Document Color Single
        PriceTableEntry(
          id: 'rule_a4_doc_color_single',
          labelEn: 'A4 Document Color Single (Plain)',
          labelSi: 'A4 ලේඛන වර්ණ එක් පැත්තක්',
          printTypeId: 'document_text',
          colorModeId: 'color',
          paperSize: 'A4',
          paperTypeId: 'plain',
          isDoubleSided: false,
          qualityId: 'normal',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 40.0,
          tiers: const [
            QuantityTier(minQty: 1, maxQty: 10, unitPrice: 40.0),
            QuantityTier(minQty: 11, maxQty: 50, unitPrice: 35.0),
            QuantityTier(minQty: 51, maxQty: null, unitPrice: 30.0),
          ],
        ),
        // 4. A4 Document Color Duplex
        PriceTableEntry(
          id: 'rule_a4_doc_color_duplex',
          labelEn: 'A4 Document Color Duplex (Per Impression)',
          labelSi: 'A4 ලේඛන වර්ණ දෙපැත්තම (පිටුවකට)',
          printTypeId: 'document_text',
          colorModeId: 'color',
          paperSize: 'A4',
          paperTypeId: 'plain',
          isDoubleSided: true,
          qualityId: 'normal',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 35.0,
          tiers: const [
            QuantityTier(minQty: 1, maxQty: 10, unitPrice: 35.0),
            QuantityTier(minQty: 11, maxQty: 50, unitPrice: 30.0),
            QuantityTier(minQty: 51, maxQty: null, unitPrice: 25.0),
          ],
        ),
        // 5. Photo 4x6 Glossy
        PriceTableEntry(
          id: 'rule_photo_4x6_glossy',
          labelEn: 'Photo 4x6 in (Glossy Resin)',
          labelSi: '4x6 ඡායාරූප මුද්‍රණය (Glossy)',
          printTypeId: 'photo',
          colorModeId: 'color',
          paperSize: '4x6 in (10x15 cm)',
          paperTypeId: 'glossy_photo',
          isDoubleSided: false,
          qualityId: 'high',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 80.0,
          tiers: const [
            QuantityTier(minQty: 1, maxQty: 5, unitPrice: 80.0),
            QuantityTier(minQty: 6, maxQty: 20, unitPrice: 70.0),
            QuantityTier(minQty: 21, maxQty: null, unitPrice: 60.0),
          ],
        ),
        // 6. Photo 5x7 Glossy
        PriceTableEntry(
          id: 'rule_photo_5x7_glossy',
          labelEn: 'Photo 5x7 in (Glossy Resin)',
          labelSi: '5x7 ඡායාරූප මුද්‍රණය (Glossy)',
          printTypeId: 'photo',
          colorModeId: 'color',
          paperSize: '5x7 in (13x18 cm)',
          paperTypeId: 'glossy_photo',
          isDoubleSided: false,
          qualityId: 'high',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 140.0,
        ),
        // 7. A4 Photo Glossy
        PriceTableEntry(
          id: 'rule_a4_photo_glossy',
          labelEn: 'A4 Full Page Photo (Glossy Resin)',
          labelSi: 'A4 සම්පූර්ණ පිටු ඡායාරූප (Glossy)',
          printTypeId: 'photo',
          colorModeId: 'color',
          paperSize: 'A4',
          paperTypeId: 'glossy_photo',
          isDoubleSided: false,
          qualityId: 'high',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 180.0,
        ),
        // 8. ID / Passport Photo Sheet
        PriceTableEntry(
          id: 'rule_id_passport_sheet',
          labelEn: 'ID / Passport Sheet (6 to 8 Photos)',
          labelSi: 'හැඳුනුම්පත් / පාස්පෝට් ඡායාරූප පත්‍රිකාව',
          printTypeId: 'id_passport_photo',
          colorModeId: 'color',
          paperSize: '4x6 in (10x15 cm)',
          paperTypeId: 'glossy_photo',
          isDoubleSided: false,
          qualityId: 'best',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 250.0,
        ),
        // 9. A3 B&W Single
        PriceTableEntry(
          id: 'rule_a3_bw_single',
          labelEn: 'A3 Document B&W Single',
          labelSi: 'A3 ලේඛන කළු සුදු එක් පැත්තක්',
          printTypeId: 'document_text',
          colorModeId: 'bw',
          paperSize: 'A3',
          paperTypeId: 'plain',
          isDoubleSided: false,
          qualityId: 'normal',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 35.0,
        ),
        // 10. A3 Color Single
        PriceTableEntry(
          id: 'rule_a3_color_single',
          labelEn: 'A3 Document Color Single',
          labelSi: 'A3 ලේඛන වර්ණ එක් පැත්තක්',
          printTypeId: 'document_text',
          colorModeId: 'color',
          paperSize: 'A3',
          paperTypeId: 'plain',
          isDoubleSided: false,
          qualityId: 'normal',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 90.0,
        ),
        // 11. Large Poster (A3+ / Photo Media)
        PriceTableEntry(
          id: 'rule_poster_large',
          labelEn: 'Poster / Large Format (Matte / Card)',
          labelSi: 'පෝස්ටර් / විශාල ආකෘති මුද්‍රණය',
          printTypeId: 'posterLarge',
          colorModeId: 'color',
          paperSize: 'A3',
          paperTypeId: 'matte',
          isDoubleSided: false,
          qualityId: 'best',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 220.0,
        ),
        // 12. Photocopy / Duplicate B&W
        PriceTableEntry(
          id: 'rule_photocopy_bw',
          labelEn: 'Photocopy B&W (A4 Walk-in)',
          labelSi: 'ෆොටෝ කොපි කළු සුදු (A4)',
          printTypeId: 'copy',
          colorModeId: 'bw',
          paperSize: 'A4',
          paperTypeId: 'plain',
          isDoubleSided: false,
          qualityId: 'draft',
          targetPrinterId: 'any',
          coverageBandId: 'any',
          basePrice: 10.0,
          tiers: const [
            QuantityTier(minQty: 1, maxQty: 10, unitPrice: 10.0),
            QuantityTier(minQty: 11, maxQty: 50, unitPrice: 8.0),
            QuantityTier(minQty: 51, maxQty: null, unitPrice: 6.0),
          ],
        ),
      ];
}
