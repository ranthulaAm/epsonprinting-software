import 'dart:convert';
import 'package:flutter/material.dart';
import '../../workspace/domain/print_queue_item.dart';

/// Lifecycle status of a customer print job in Shop Mode.
enum CustomerJobStatus {
  waiting(
    labelEn: 'Waiting',
    labelSi: 'රැඳී සිටී (Waiting)',
    color: Color(0xFFD97706),
    icon: Icons.hourglass_top_rounded,
  ),
  printing(
    labelEn: 'Printing',
    labelSi: 'මුද්‍රණය වේ (Printing)',
    color: Color(0xFF2563EB),
    icon: Icons.print_rounded,
  ),
  done(
    labelEn: 'Done (Ready for Pickup)',
    labelSi: 'අවසන් (ලබාගැනීමට සූදානම්)',
    color: Color(0xFF16A34A),
    icon: Icons.check_circle_rounded,
  ),
  pickedUp(
    labelEn: 'Picked up',
    labelSi: 'පාරිභෝගිකයා ලබාගන්නා ලදී (Picked up)',
    color: Color(0xFF64748B),
    icon: Icons.inventory_2_rounded,
  );

  final String labelEn;
  final String labelSi;
  final Color color;
  final IconData icon;

  const CustomerJobStatus({
    required this.labelEn,
    required this.labelSi,
    required this.color,
    required this.icon,
  });
}

/// Editable per-page price rule in the Shop Mode Price List.
///
/// Matches by `paperSize` (`"A4"`, `"A3"`, `"Letter"`, `"Legal"`, `"4x6 in (10x15 cm)"`),
/// `isColor` (Color vs. B&W), `isDoubleSided` (Single vs. Double-sided), and
/// `mediaType` (`"Plain Paper"`, `"Photo Paper Glossy"`, `"Thick Paper"`, etc.).
class ShopPriceRule {
  final String id;
  final String labelEn;
  final String labelSi;
  final String paperSize;
  final bool isColor;
  final bool isDoubleSided;
  final String mediaType;
  final double pricePerPage;

  const ShopPriceRule({
    required this.id,
    required this.labelEn,
    required this.labelSi,
    required this.paperSize,
    required this.isColor,
    required this.isDoubleSided,
    required this.mediaType,
    required this.pricePerPage,
  });

  ShopPriceRule copyWith({
    String? id,
    String? labelEn,
    String? labelSi,
    String? paperSize,
    bool? isColor,
    bool? isDoubleSided,
    String? mediaType,
    double? pricePerPage,
  }) {
    return ShopPriceRule(
      id: id ?? this.id,
      labelEn: labelEn ?? this.labelEn,
      labelSi: labelSi ?? this.labelSi,
      paperSize: paperSize ?? this.paperSize,
      isColor: isColor ?? this.isColor,
      isDoubleSided: isDoubleSided ?? this.isDoubleSided,
      mediaType: mediaType ?? this.mediaType,
      pricePerPage: pricePerPage ?? this.pricePerPage,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'labelEn': labelEn,
        'labelSi': labelSi,
        'paperSize': paperSize,
        'isColor': isColor,
        'isDoubleSided': isDoubleSided,
        'mediaType': mediaType,
        'pricePerPage': pricePerPage,
      };

  factory ShopPriceRule.fromMap(Map<String, dynamic> map) {
    return ShopPriceRule(
      id: map['id'] as String? ?? 'rule',
      labelEn: map['labelEn'] as String? ?? 'Custom Rate',
      labelSi: map['labelSi'] as String? ?? 'මිල ගණන',
      paperSize: map['paperSize'] as String? ?? 'A4',
      isColor: map['isColor'] as bool? ?? false,
      isDoubleSided: map['isDoubleSided'] as bool? ?? false,
      mediaType: map['mediaType'] as String? ?? 'Plain Paper',
      pricePerPage: (map['pricePerPage'] as num?)?.toDouble() ?? 10.0,
    );
  }

  /// Default Sri Lankan & international print shop price list (editable in UI).
  static const List<ShopPriceRule> defaultRulesLkr = [
    ShopPriceRule(
      id: 'rule_a4_bw_single_plain',
      labelEn: 'A4 B&W Single-Sided (Plain)',
      labelSi: 'A4 කළු-සුදු එක් පැත්තක් (සාමාන්‍ය)',
      paperSize: 'A4',
      isColor: false,
      isDoubleSided: false,
      mediaType: 'Plain Paper',
      pricePerPage: 15.0,
    ),
    ShopPriceRule(
      id: 'rule_a4_bw_duplex_plain',
      labelEn: 'A4 B&W Double-Sided (Per Impression)',
      labelSi: 'A4 කළු-සුදු දෙපැත්තම (එක් පිටුවකට)',
      paperSize: 'A4',
      isColor: false,
      isDoubleSided: true,
      mediaType: 'Plain Paper',
      pricePerPage: 10.0,
    ),
    ShopPriceRule(
      id: 'rule_a4_color_single_plain',
      labelEn: 'A4 Color Single-Sided (Plain)',
      labelSi: 'A4 වර්ණ එක් පැත්තක් (සාමාන්‍ය)',
      paperSize: 'A4',
      isColor: true,
      isDoubleSided: false,
      mediaType: 'Plain Paper',
      pricePerPage: 40.0,
    ),
    ShopPriceRule(
      id: 'rule_a4_color_duplex_plain',
      labelEn: 'A4 Color Double-Sided (Per Impression)',
      labelSi: 'A4 වර්ණ දෙපැත්තම (එක් පිටුවකට)',
      paperSize: 'A4',
      isColor: true,
      isDoubleSided: true,
      mediaType: 'Plain Paper',
      pricePerPage: 35.0,
    ),
    ShopPriceRule(
      id: 'rule_photo_4x6_glossy',
      labelEn: 'Photo 4x6 Glossy (Color)',
      labelSi: '4x6 ඡායාරූප කඩදාසි (Photo Glossy)',
      paperSize: '4x6 in (10x15 cm)',
      isColor: true,
      isDoubleSided: false,
      mediaType: 'Photo Paper Glossy',
      pricePerPage: 80.0,
    ),
    ShopPriceRule(
      id: 'rule_a4_photo_glossy',
      labelEn: 'A4 Photo Paper Glossy (Color)',
      labelSi: 'A4 ඡායාරූප කඩදාසි (Photo Glossy)',
      paperSize: 'A4',
      isColor: true,
      isDoubleSided: false,
      mediaType: 'Photo Paper Glossy',
      pricePerPage: 180.0,
    ),
    ShopPriceRule(
      id: 'rule_a3_bw_single',
      labelEn: 'A3 B&W Single-Sided',
      labelSi: 'A3 කළු-සුදු එක් පැත්තක්',
      paperSize: 'A3',
      isColor: false,
      isDoubleSided: false,
      mediaType: 'Plain Paper',
      pricePerPage: 35.0,
    ),
    ShopPriceRule(
      id: 'rule_a3_color_single',
      labelEn: 'A3 Color Single-Sided',
      labelSi: 'A3 වර්ණ එක් පැත්තක්',
      paperSize: 'A3',
      isColor: true,
      isDoubleSided: false,
      mediaType: 'Plain Paper',
      pricePerPage: 90.0,
    ),
  ];
}

/// User-entered ink/toner and paper supply prices used to calculate estimated
/// cost and estimated profit per job.
///
/// Always labeled as an `"estimate"` in the UI and reports.
class ShopSupplyCostConfig {
  final String currencyCode; // e.g., 'LKR', 'USD', 'EUR', 'INR', 'GBP'
  final String shopName;
  final String shopPhoneOrAddress;

  /// Price of a black ink bottle / toner cartridge (e.g., 3200 LKR for Epson 003 bottle)
  final double blackSupplyPrice;

  /// Estimated page yield for one black bottle / cartridge (e.g., 4500 pages)
  final int blackSupplyPageYield;

  /// Combined price of C+M+Y color ink bottles / cartridges (e.g., 9600 LKR)
  final double colorSupplySetPrice;

  /// Estimated page yield for one C+M+Y set (e.g., 6500 pages)
  final int colorSupplySetPageYield;

  /// Price of 1 ream (500 sheets) of A4 plain paper (e.g., 2250 LKR -> 4.50/sheet)
  final double a4PlainReam500Price;

  /// Price of 1 pack (100 sheets) of 4x6 Photo Glossy paper (e.g., 2500 LKR -> 25/sheet)
  final double photo4x6Pack100Price;

  /// Price of 1 ream (500 sheets) of A3 plain paper (e.g., 4500 LKR -> 9.00/sheet)
  final double a3PlainReam500Price;

  const ShopSupplyCostConfig({
    this.currencyCode = 'LKR',
    this.shopName = 'Print Helper Copy & Digital Shop',
    this.shopPhoneOrAddress = 'Colombo • Tel: 011-2345678',
    this.blackSupplyPrice = 3200.0,
    this.blackSupplyPageYield = 4500,
    this.colorSupplySetPrice = 9600.0,
    this.colorSupplySetPageYield = 6500,
    this.a4PlainReam500Price = 2250.0,
    this.photo4x6Pack100Price = 2500.0,
    this.a3PlainReam500Price = 4500.0,
  });

  double get estimatedBlackInkCostPerPage => blackSupplyPageYield > 0
      ? (blackSupplyPrice / blackSupplyPageYield)
      : 0.0;

  double get estimatedColorInkCostPerPage => colorSupplySetPageYield > 0
      ? (colorSupplySetPrice / colorSupplySetPageYield) +
          (estimatedBlackInkCostPerPage * 0.35)
      : 0.0;

  double get estimatedA4PlainSheetCost => a4PlainReam500Price / 500.0;
  double get estimatedPhoto4x6SheetCost => photo4x6Pack100Price / 100.0;
  double get estimatedA3PlainSheetCost => a3PlainReam500Price / 500.0;

  ShopSupplyCostConfig copyWith({
    String? currencyCode,
    String? shopName,
    String? shopPhoneOrAddress,
    double? blackSupplyPrice,
    int? blackSupplyPageYield,
    double? colorSupplySetPrice,
    int? colorSupplySetPageYield,
    double? a4PlainReam500Price,
    double? photo4x6Pack100Price,
    double? a3PlainReam500Price,
  }) {
    return ShopSupplyCostConfig(
      currencyCode: currencyCode ?? this.currencyCode,
      shopName: shopName ?? this.shopName,
      shopPhoneOrAddress: shopPhoneOrAddress ?? this.shopPhoneOrAddress,
      blackSupplyPrice: blackSupplyPrice ?? this.blackSupplyPrice,
      blackSupplyPageYield: blackSupplyPageYield ?? this.blackSupplyPageYield,
      colorSupplySetPrice: colorSupplySetPrice ?? this.colorSupplySetPrice,
      colorSupplySetPageYield:
          colorSupplySetPageYield ?? this.colorSupplySetPageYield,
      a4PlainReam500Price: a4PlainReam500Price ?? this.a4PlainReam500Price,
      photo4x6Pack100Price: photo4x6Pack100Price ?? this.photo4x6Pack100Price,
      a3PlainReam500Price: a3PlainReam500Price ?? this.a3PlainReam500Price,
    );
  }

  Map<String, dynamic> toMap() => {
        'currencyCode': currencyCode,
        'shopName': shopName,
        'shopPhoneOrAddress': shopPhoneOrAddress,
        'blackSupplyPrice': blackSupplyPrice,
        'blackSupplyPageYield': blackSupplyPageYield,
        'colorSupplySetPrice': colorSupplySetPrice,
        'colorSupplySetPageYield': colorSupplySetPageYield,
        'a4PlainReam500Price': a4PlainReam500Price,
        'photo4x6Pack100Price': photo4x6Pack100Price,
        'a3PlainReam500Price': a3PlainReam500Price,
      };

  factory ShopSupplyCostConfig.fromMap(Map<String, dynamic> map) {
    return ShopSupplyCostConfig(
      currencyCode: map['currencyCode'] as String? ?? 'LKR',
      shopName:
          map['shopName'] as String? ?? 'Print Helper Copy & Digital Shop',
      shopPhoneOrAddress:
          map['shopPhoneOrAddress'] as String? ?? 'Colombo • Tel: 011-2345678',
      blackSupplyPrice:
          (map['blackSupplyPrice'] as num?)?.toDouble() ?? 3200.0,
      blackSupplyPageYield:
          (map['blackSupplyPageYield'] as num?)?.toInt() ?? 4500,
      colorSupplySetPrice:
          (map['colorSupplySetPrice'] as num?)?.toDouble() ?? 9600.0,
      colorSupplySetPageYield:
          (map['colorSupplySetPageYield'] as num?)?.toInt() ?? 6500,
      a4PlainReam500Price:
          (map['a4PlainReam500Price'] as num?)?.toDouble() ?? 2250.0,
      photo4x6Pack100Price:
          (map['photo4x6Pack100Price'] as num?)?.toDouble() ?? 2500.0,
      a3PlainReam500Price:
          (map['a3PlainReam500Price'] as num?)?.toDouble() ?? 4500.0,
    );
  }
}

/// Line item price & cost calculation for a single file within a customer job.
class ShopFilePricingBreakdown {
  final String fileName;
  final int documentPages;
  final int copies;
  final int totalImpressions;
  final int physicalSheetsUsed;
  final String matchedRuleLabelEn;
  final String matchedRuleLabelSi;
  final double unitPricePerImpression;
  final double resolutionSurcharge;
  final int resolutionDpi;
  final double inkCoveragePercent;
  final double inkSaverSavings;
  final double lineSubtotal;
  final double estimatedInkCost;
  final double estimatedPaperCost;

  const ShopFilePricingBreakdown({
    required this.fileName,
    required this.documentPages,
    required this.copies,
    required this.totalImpressions,
    required this.physicalSheetsUsed,
    required this.matchedRuleLabelEn,
    required this.matchedRuleLabelSi,
    required this.unitPricePerImpression,
    this.resolutionSurcharge = 0.0,
    this.resolutionDpi = 600,
    this.inkCoveragePercent = 5.0,
    this.inkSaverSavings = 0.0,
    required this.lineSubtotal,
    required this.estimatedInkCost,
    required this.estimatedPaperCost,
  });

  double get estimatedTotalCost => estimatedInkCost + estimatedPaperCost;
}

/// Complete price, discount, estimated cost, and estimated profit summary for a
/// customer job or quick-print batch.
class ShopJobPriceAndCostEstimate {
  final String currencyCode;
  final List<ShopFilePricingBreakdown> lineItems;
  final int totalImpressions;
  final int totalPhysicalSheets;
  final int bwPagesCount;
  final int colorPagesCount;
  final int photoPagesCount;
  final double grossSubtotal;
  final double discountAmount;
  final double finalCustomerTotal;
  final double estimatedInkOrTonerCost;
  final double estimatedPaperCost;

  const ShopJobPriceAndCostEstimate({
    required this.currencyCode,
    required this.lineItems,
    required this.totalImpressions,
    required this.totalPhysicalSheets,
    required this.bwPagesCount,
    required this.colorPagesCount,
    required this.photoPagesCount,
    required this.grossSubtotal,
    required this.discountAmount,
    required this.finalCustomerTotal,
    required this.estimatedInkOrTonerCost,
    required this.estimatedPaperCost,
  });

  double get estimatedTotalSupplyCost =>
      estimatedInkOrTonerCost + estimatedPaperCost;

  /// Clearly labeled as an estimate in the UI.
  double get estimatedProfit => finalCustomerTotal - estimatedTotalSupplyCost;

  String formatAmount(double amount) =>
      '$currencyCode ${amount.toStringAsFixed(2)}';
}

/// Automatic Printer Routing Rules for Shop Mode:
/// - Color jobs -> [colorPrinterSystemName]
/// - B&W jobs -> [monoPrinterSystemName]
/// - Photo jobs (4x6 / 5x7 / Photo media) -> [photoPrinterSystemName]
/// - Big jobs (`totalPages >= largeJobPageThreshold`) -> [fastestHighVolumePrinterSystemName]
/// Always allows manual override per job or on the Quick Print screen.
class ShopPrinterRoutingRules {
  final bool autoRoutingEnabled;
  final String colorPrinterSystemName;
  final String monoPrinterSystemName;
  final String photoPrinterSystemName;
  final String fastestHighVolumePrinterSystemName;
  final int largeJobPageThreshold;

  const ShopPrinterRoutingRules({
    this.autoRoutingEnabled = true,
    this.colorPrinterSystemName = '',
    this.monoPrinterSystemName = '',
    this.photoPrinterSystemName = '',
    this.fastestHighVolumePrinterSystemName = '',
    this.largeJobPageThreshold = 50,
  });

  ShopPrinterRoutingRules copyWith({
    bool? autoRoutingEnabled,
    String? colorPrinterSystemName,
    String? monoPrinterSystemName,
    String? photoPrinterSystemName,
    String? fastestHighVolumePrinterSystemName,
    int? largeJobPageThreshold,
  }) {
    return ShopPrinterRoutingRules(
      autoRoutingEnabled: autoRoutingEnabled ?? this.autoRoutingEnabled,
      colorPrinterSystemName:
          colorPrinterSystemName ?? this.colorPrinterSystemName,
      monoPrinterSystemName:
          monoPrinterSystemName ?? this.monoPrinterSystemName,
      photoPrinterSystemName:
          photoPrinterSystemName ?? this.photoPrinterSystemName,
      fastestHighVolumePrinterSystemName: fastestHighVolumePrinterSystemName ??
          this.fastestHighVolumePrinterSystemName,
      largeJobPageThreshold:
          largeJobPageThreshold ?? this.largeJobPageThreshold,
    );
  }

  Map<String, dynamic> toMap() => {
        'autoRoutingEnabled': autoRoutingEnabled,
        'colorPrinterSystemName': colorPrinterSystemName,
        'monoPrinterSystemName': monoPrinterSystemName,
        'photoPrinterSystemName': photoPrinterSystemName,
        'fastestHighVolumePrinterSystemName':
            fastestHighVolumePrinterSystemName,
        'largeJobPageThreshold': largeJobPageThreshold,
      };

  factory ShopPrinterRoutingRules.fromMap(Map<String, dynamic> map) {
    return ShopPrinterRoutingRules(
      autoRoutingEnabled: map['autoRoutingEnabled'] as bool? ?? true,
      colorPrinterSystemName: map['colorPrinterSystemName'] as String? ?? '',
      monoPrinterSystemName: map['monoPrinterSystemName'] as String? ?? '',
      photoPrinterSystemName: map['photoPrinterSystemName'] as String? ?? '',
      fastestHighVolumePrinterSystemName:
          map['fastestHighVolumePrinterSystemName'] as String? ?? '',
      largeJobPageThreshold:
          (map['largeJobPageThreshold'] as num?)?.toInt() ?? 50,
    );
  }
}

/// Explanation of why a particular printer was chosen by the Shop Routing Engine.
class ResolvedPrinterRoute {
  final String targetPrinterSystemName;
  final String reasonEn;
  final String reasonSi;
  final bool isManualOverride;

  const ResolvedPrinterRoute({
    required this.targetPrinterSystemName,
    required this.reasonEn,
    required this.reasonSi,
    required this.isManualOverride,
  });
}

/// A Customer Job grouping one or more files for a specific customer (name or
/// token/barcode number, e.g. `JOB-1001`), with per-file settings, notes,
/// lifecycle status (`Waiting`, `Printing`, `Done`, `Picked up`), and pricing.
class ShopCustomerJob {
  final String id;
  final String jobNumberCode; // e.g., 'JOB-1001' (searchable via barcode/QR scanner)
  final String customerNameOrPhone;
  final String notes;
  final CustomerJobStatus status;
  final List<PrintQueueItem> files;
  final String assignedPrinterSystemName;
  final bool manualPrinterOverride;
  final double discountAmount;
  final double discountPercent;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? pickedUpAt;

  const ShopCustomerJob({
    required this.id,
    required this.jobNumberCode,
    required this.customerNameOrPhone,
    this.notes = '',
    this.status = CustomerJobStatus.waiting,
    required this.files,
    required this.assignedPrinterSystemName,
    this.manualPrinterOverride = false,
    this.discountAmount = 0.0,
    this.discountPercent = 0.0,
    required this.createdAt,
    this.completedAt,
    this.pickedUpAt,
  });

  int get totalImpressions => files.fold<int>(
        0,
        (sum, item) => sum + (item.pageCount * item.settings.copies),
      );

  ShopCustomerJob copyWith({
    String? id,
    String? jobNumberCode,
    String? customerNameOrPhone,
    String? notes,
    CustomerJobStatus? status,
    List<PrintQueueItem>? files,
    String? assignedPrinterSystemName,
    bool? manualPrinterOverride,
    double? discountAmount,
    double? discountPercent,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? pickedUpAt,
  }) {
    return ShopCustomerJob(
      id: id ?? this.id,
      jobNumberCode: jobNumberCode ?? this.jobNumberCode,
      customerNameOrPhone: customerNameOrPhone ?? this.customerNameOrPhone,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      files: files ?? this.files,
      assignedPrinterSystemName:
          assignedPrinterSystemName ?? this.assignedPrinterSystemName,
      manualPrinterOverride:
          manualPrinterOverride ?? this.manualPrinterOverride,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'jobNumberCode': jobNumberCode,
        'customerNameOrPhone': customerNameOrPhone,
        'notes': notes,
        'status': status.name,
        'files': files
            .asMap()
            .entries
            .map((e) => e.value.toStorageRow(e.key))
            .toList(),
        'assignedPrinterSystemName': assignedPrinterSystemName,
        'manualPrinterOverride': manualPrinterOverride,
        'discountAmount': discountAmount,
        'discountPercent': discountPercent,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'pickedUpAt': pickedUpAt?.toIso8601String(),
      };

  factory ShopCustomerJob.fromMap(Map<String, dynamic> map) {
    final rawFiles = map['files'] as List<dynamic>? ?? const [];
    final parsedFiles = rawFiles
        .map((r) => PrintQueueItem.fromStorageRow(
              Map<String, Object?>.from(r as Map),
            ))
        .toList();

    return ShopCustomerJob(
      id: map['id'] as String? ?? '',
      jobNumberCode: map['jobNumberCode'] as String? ?? 'JOB-0000',
      customerNameOrPhone:
          map['customerNameOrPhone'] as String? ?? 'Walk-in Customer',
      notes: map['notes'] as String? ?? '',
      status: CustomerJobStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => CustomerJobStatus.waiting,
      ),
      files: parsedFiles,
      assignedPrinterSystemName:
          map['assignedPrinterSystemName'] as String? ?? '',
      manualPrinterOverride: map['manualPrinterOverride'] as bool? ?? false,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
      pickedUpAt: map['pickedUpAt'] != null
          ? DateTime.tryParse(map['pickedUpAt'] as String)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toMap());

  factory ShopCustomerJob.fromJsonString(String raw) =>
      ShopCustomerJob.fromMap(jsonDecode(raw) as Map<String, dynamic>);
}

/// Daily Report aggregation for a chosen date: jobs count, pages by type
/// (B&W, Color, Photo), total revenue, estimated supplies used (sheets + ink/toner cost),
/// and estimated net profit.
class ShopDailyReportSummary {
  final DateTime date;
  final String currencyCode;
  final int totalJobsCount;
  final int completedOrPickedUpJobsCount;
  final int totalImpressions;
  final int bwPagesCount;
  final int colorPagesCount;
  final int photoPagesCount;
  final int a4SheetsUsed;
  final int a3SheetsUsed;
  final int photo4x6SheetsUsed;
  final double totalRevenue;
  final double totalDiscountsGiven;
  final double estimatedInkOrTonerCost;
  final double estimatedPaperCost;
  final List<ShopCustomerJob> jobsForDay;

  const ShopDailyReportSummary({
    required this.date,
    required this.currencyCode,
    required this.totalJobsCount,
    required this.completedOrPickedUpJobsCount,
    required this.totalImpressions,
    required this.bwPagesCount,
    required this.colorPagesCount,
    required this.photoPagesCount,
    required this.a4SheetsUsed,
    required this.a3SheetsUsed,
    required this.photo4x6SheetsUsed,
    required this.totalRevenue,
    required this.totalDiscountsGiven,
    required this.estimatedInkOrTonerCost,
    required this.estimatedPaperCost,
    required this.jobsForDay,
  });

  double get estimatedTotalSupplyCost =>
      estimatedInkOrTonerCost + estimatedPaperCost;

  double get estimatedNetProfit => totalRevenue - estimatedTotalSupplyCost;
}

/// Configuration for Customer Drop Folders intake (watches root directory where
/// each subfolder `CustomerName_Or_Number/` automatically groups dropped files
/// into a `ShopCustomerJob`).
class CustomerDropFoldersConfig {
  final bool enabled;
  final String rootDropDirectoryPath;
  final String defaultPresetId;

  const CustomerDropFoldersConfig({
    this.enabled = false,
    this.rootDropDirectoryPath = '',
    this.defaultPresetId = 'builtin_duplex_bw_draft',
  });

  CustomerDropFoldersConfig copyWith({
    bool? enabled,
    String? rootDropDirectoryPath,
    String? defaultPresetId,
  }) {
    return CustomerDropFoldersConfig(
      enabled: enabled ?? this.enabled,
      rootDropDirectoryPath:
          rootDropDirectoryPath ?? this.rootDropDirectoryPath,
      defaultPresetId: defaultPresetId ?? this.defaultPresetId,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'rootDropDirectoryPath': rootDropDirectoryPath,
        'defaultPresetId': defaultPresetId,
      };

  factory CustomerDropFoldersConfig.fromMap(Map<String, dynamic> map) {
    return CustomerDropFoldersConfig(
      enabled: map['enabled'] as bool? ?? false,
      rootDropDirectoryPath: map['rootDropDirectoryPath'] as String? ?? '',
      defaultPresetId:
          map['defaultPresetId'] as String? ?? 'builtin_duplex_bw_draft',
    );
  }
}
