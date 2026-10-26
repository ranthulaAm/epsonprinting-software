import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqlite3/sqlite3.dart';

import '../../../services/printer/models/printer_models.dart';
import '../../workspace/domain/print_queue_item.dart';
import '../domain/shop_mode_models.dart';

final shopModePersistenceProvider = Provider<ShopModePersistence>((ref) {
  final persistence = ShopModePersistence();
  ref.onDispose(persistence.dispose);
  return persistence;
});

/// 100% offline local SQLite persistence for Shop Mode:
/// - Customer jobs (`Waiting`, `Printing`, `Done`, `Picked up`)
/// - Editable Price List rules (`ShopPriceRule`)
/// - Supply Cost & Currency configuration (`ShopSupplyCostConfig`)
/// - Printer Routing Rules (`ShopPrinterRoutingRules`)
/// - Customer Drop Folders intake configuration (`CustomerDropFoldersConfig`)
/// - Auto-incrementing Job Number sequence (`JOB-1001`, `JOB-1002`...)
class ShopModePersistence {
  final String? overrideDbPath;
  Database? _db;

  ShopModePersistence({this.overrideDbPath});

  Future<void> init() async {
    if (_db != null) return;
    try {
      final String dbPath;
      if (overrideDbPath != null) {
        dbPath = overrideDbPath!;
      } else {
        final supportDir = await getApplicationSupportDirectory();
        await supportDir.create(recursive: true);
        dbPath = p.join(supportDir.path, 'print_helper_shop_mode.sqlite');
      }
      _db = sqlite3.open(dbPath);
    } catch (_) {
      _db = sqlite3.openInMemory();
    }

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS shop_customer_jobs (
        id TEXT PRIMARY KEY,
        job_number_code TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        payload_json TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS shop_kv_store (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
  }

  Future<int> nextJobSequenceNumber() async {
    await init();
    final db = _db;
    if (db == null) return 1001;
    final rows = db.select(
      'SELECT value FROM shop_kv_store WHERE key = ?;',
      ['job_seq_counter'],
    );
    final current = rows.isEmpty
        ? 1000
        : (int.tryParse(rows.first['value'] as String? ?? '1000') ?? 1000);
    final next = current + 1;
    db.execute(
      '''
      INSERT INTO shop_kv_store (key, value) VALUES ('job_seq_counter', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
      ''',
      ['$next'],
    );
    return next;
  }

  Future<void> saveCustomerJob(ShopCustomerJob job) async {
    await init();
    _db?.execute(
      '''
      INSERT INTO shop_customer_jobs (
        id, job_number_code, customer_name, status, created_at, payload_json
      ) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        job_number_code = excluded.job_number_code,
        customer_name = excluded.customer_name,
        status = excluded.status,
        payload_json = excluded.payload_json;
      ''',
      [
        job.id,
        job.jobNumberCode,
        job.customerNameOrPhone,
        job.status.name,
        job.createdAt.toIso8601String(),
        job.toJsonString(),
      ],
    );
  }

  Future<void> deleteCustomerJob(String id) async {
    await init();
    _db?.execute('DELETE FROM shop_customer_jobs WHERE id = ?;', [id]);
  }

  Future<List<ShopCustomerJob>> loadCustomerJobs() async {
    await init();
    final db = _db;
    if (db == null) return const [];
    final rows = db.select(
      'SELECT payload_json FROM shop_customer_jobs ORDER BY created_at DESC LIMIT 1000;',
    );
    final jobs = <ShopCustomerJob>[];
    for (final row in rows) {
      try {
        final raw = row['payload_json'] as String;
        jobs.add(ShopCustomerJob.fromJsonString(raw));
      } catch (_) {}
    }
    return jobs;
  }

  Future<List<ShopPriceRule>> loadPriceRules() async {
    await init();
    final raw = _readKv('price_rules_json');
    if (raw == null) return ShopPriceRule.defaultRulesLkr;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((e) => ShopPriceRule.fromMap(e as Map<String, dynamic>))
          .toList();
      return parsed.isEmpty ? ShopPriceRule.defaultRulesLkr : parsed;
    } catch (_) {
      return ShopPriceRule.defaultRulesLkr;
    }
  }

  Future<void> savePriceRules(List<ShopPriceRule> rules) async {
    await init();
    _writeKv(
      'price_rules_json',
      jsonEncode(rules.map((r) => r.toMap()).toList()),
    );
  }

  Future<ShopSupplyCostConfig> loadSupplyCostConfig() async {
    await init();
    final raw = _readKv('supply_cost_config_json');
    if (raw == null) return const ShopSupplyCostConfig();
    try {
      return ShopSupplyCostConfig.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ShopSupplyCostConfig();
    }
  }

  Future<void> saveSupplyCostConfig(ShopSupplyCostConfig config) async {
    await init();
    _writeKv('supply_cost_config_json', jsonEncode(config.toMap()));
  }

  Future<ShopPrinterRoutingRules> loadRoutingRules() async {
    await init();
    final raw = _readKv('printer_routing_rules_json');
    if (raw == null) return const ShopPrinterRoutingRules();
    try {
      return ShopPrinterRoutingRules.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ShopPrinterRoutingRules();
    }
  }

  Future<void> saveRoutingRules(ShopPrinterRoutingRules rules) async {
    await init();
    _writeKv('printer_routing_rules_json', jsonEncode(rules.toMap()));
  }

  Future<CustomerDropFoldersConfig> loadCustomerDropFoldersConfig() async {
    await init();
    final raw = _readKv('customer_drop_folders_json');
    if (raw == null) return const CustomerDropFoldersConfig();
    try {
      return CustomerDropFoldersConfig.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const CustomerDropFoldersConfig();
    }
  }

  Future<void> saveCustomerDropFoldersConfig(
      CustomerDropFoldersConfig config) async {
    await init();
    _writeKv('customer_drop_folders_json', jsonEncode(config.toMap()));
  }

  String? _readKv(String key) {
    final db = _db;
    if (db == null) return null;
    final rows =
        db.select('SELECT value FROM shop_kv_store WHERE key = ?;', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  void _writeKv(String key, String value) {
    _db?.execute(
      '''
      INSERT INTO shop_kv_store (key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
      ''',
      [key, value],
    );
  }

  void dispose() {
    _db?.dispose();
    _db = null;
  }
}

/// Core calculation, routing, PDF receipt/invoice, and daily report engine for Shop Mode.
class ShopPricingAndReceiptService {
  const ShopPricingAndReceiptService();

  /// Computes exact customer price, discounts, estimated ink/toner cost,
  /// estimated paper cost, and estimated profit for a list of files.
  ShopJobPriceAndCostEstimate calculateJobEstimate({
    required List<PrintQueueItem> files,
    required List<ShopPriceRule> priceRules,
    required ShopSupplyCostConfig costConfig,
    double flatDiscountAmount = 0.0,
    double discountPercent = 0.0,
  }) {
    final lineItems = <ShopFilePricingBreakdown>[];
    int totalImpressions = 0;
    int totalSheets = 0;
    int bwPages = 0;
    int colorPages = 0;
    int photoPages = 0;
    double grossSubtotal = 0.0;
    double totalInkCost = 0.0;
    double totalPaperCost = 0.0;

    for (final item in files) {
      final s = item.settings;
      final isDuplex = s.duplex != DuplexMode.none;
      final isPhoto = _isPhotoMediaOrSize(s.paperSize, s.mediaType);
      final impressions = (item.pageCount < 1 ? 1 : item.pageCount) * s.copies;
      final sheetsPerCopy = isDuplex
          ? ((item.pageCount < 1 ? 1 : item.pageCount) / 2.0).ceil()
          : (item.pageCount < 1 ? 1 : item.pageCount);
      final sheets = sheetsPerCopy * s.copies;

      final matchedRule = _matchPriceRule(
        settings: s,
        rules: priceRules,
      );

      final unitPrice = matchedRule.pricePerPage;
      final lineSub = impressions * unitPrice;

      // Estimated ink/toner cost
      final double inkPerImpression = s.isColor
          ? (isPhoto
              ? costConfig.estimatedColorInkCostPerPage * 1.45
              : costConfig.estimatedColorInkCostPerPage)
          : costConfig.estimatedBlackInkCostPerPage;
      final estInk = impressions * inkPerImpression;

      // Estimated paper cost
      final double sheetCost = _sheetCostForPaper(s.paperSize, s.mediaType, costConfig);
      final estPaper = sheets * sheetCost;

      totalImpressions += impressions;
      totalSheets += sheets;
      if (isPhoto) {
        photoPages += impressions;
      } else if (s.isColor) {
        colorPages += impressions;
      } else {
        bwPages += impressions;
      }

      grossSubtotal += lineSub;
      totalInkCost += estInk;
      totalPaperCost += estPaper;

      lineItems.add(
        ShopFilePricingBreakdown(
          fileName: item.fileName,
          documentPages: item.pageCount,
          copies: s.copies,
          totalImpressions: impressions,
          physicalSheetsUsed: sheets,
          matchedRuleLabelEn: matchedRule.labelEn,
          matchedRuleLabelSi: matchedRule.labelSi,
          unitPricePerImpression: unitPrice,
          lineSubtotal: lineSub,
          estimatedInkCost: estInk,
          estimatedPaperCost: estPaper,
        ),
      );
    }

    final pctDiscount = grossSubtotal * (discountPercent.clamp(0.0, 100.0) / 100.0);
    final totalDiscount = (pctDiscount + flatDiscountAmount).clamp(0.0, grossSubtotal);
    final finalTotal = (grossSubtotal - totalDiscount).clamp(0.0, double.infinity);

    return ShopJobPriceAndCostEstimate(
      currencyCode: costConfig.currencyCode,
      lineItems: lineItems,
      totalImpressions: totalImpressions,
      totalPhysicalSheets: totalSheets,
      bwPagesCount: bwPages,
      colorPagesCount: colorPages,
      photoPagesCount: photoPages,
      grossSubtotal: grossSubtotal,
      discountAmount: totalDiscount,
      finalCustomerTotal: finalTotal,
      estimatedInkOrTonerCost: totalInkCost,
      estimatedPaperCost: totalPaperCost,
    );
  }

  /// Automatically resolves which printer should handle a job based on
  /// [ShopPrinterRoutingRules]:
  /// 1. Manual override -> uses user-chosen printer
  /// 2. Photo job (`4x6`, `5x7`, `Photo Paper Glossy`) -> `photoPrinterSystemName`
  /// 3. Big job (`totalImpressions >= largeJobPageThreshold`) -> `fastestHighVolumePrinterSystemName`
  /// 4. Color job -> `colorPrinterSystemName`
  /// 5. B&W job -> `monoPrinterSystemName`
  /// 6. Fallback -> first available ready printer
  ResolvedPrinterRoute resolvePrinterForJob({
    required List<PrintQueueItem> files,
    required ShopPrinterRoutingRules rules,
    required List<PrinterDevice> availablePrinters,
    String? manualOverridePrinterName,
  }) {
    final fallbackPrinter = availablePrinters.isNotEmpty
        ? availablePrinters.first.systemName
        : 'Default Printer';

    if (manualOverridePrinterName != null &&
        manualOverridePrinterName.trim().isNotEmpty) {
      return ResolvedPrinterRoute(
        targetPrinterSystemName: manualOverridePrinterName,
        reasonEn: 'Manual printer selection override',
        reasonSi: 'පරිශීලකයා විසින් තෝරාගත් මුද්‍රණ යන්ත්‍රය',
        isManualOverride: true,
      );
    }

    if (!rules.autoRoutingEnabled || files.isEmpty) {
      return ResolvedPrinterRoute(
        targetPrinterSystemName: fallbackPrinter,
        reasonEn: 'Default printer (Auto-routing disabled)',
        reasonSi: 'පෙරනිමි මුද්‍රණ යන්ත්‍රය',
        isManualOverride: false,
      );
    }

    final totalImpressions = files.fold<int>(
      0,
      (sum, f) => sum + (f.pageCount * f.settings.copies),
    );
    final anyPhoto = files.any(
      (f) => _isPhotoMediaOrSize(f.settings.paperSize, f.settings.mediaType),
    );
    final anyColor = files.any((f) => f.settings.isColor);

    // 1. Photo Printer Rule
    if (anyPhoto && rules.photoPrinterSystemName.trim().isNotEmpty) {
      return ResolvedPrinterRoute(
        targetPrinterSystemName: rules.photoPrinterSystemName,
        reasonEn: 'Auto-routed: Photo media/size → Photo Printer',
        reasonSi: 'ස්වයංක්‍රීය යොමුව: ඡායාරූප (Photo) මුද්‍රණ යන්ත්‍රය වෙත',
        isManualOverride: false,
      );
    }

    // 2. High-Volume / Big Job Rule
    if (totalImpressions >= rules.largeJobPageThreshold &&
        rules.fastestHighVolumePrinterSystemName.trim().isNotEmpty) {
      return ResolvedPrinterRoute(
        targetPrinterSystemName: rules.fastestHighVolumePrinterSystemName,
        reasonEn:
            'Auto-routed: Large job ($totalImpressions pages ≥ ${rules.largeJobPageThreshold}) → Fastest Printer',
        reasonSi:
            'ස්වයංක්‍රීය යොමුව: විශාල මුද්‍රණ කාර්යයකි (පිටු $totalImpressions) → වේගවත්ම යන්ත්‍රය වෙත',
        isManualOverride: false,
      );
    }

    // 3. Color Printer Rule
    if (anyColor && rules.colorPrinterSystemName.trim().isNotEmpty) {
      return ResolvedPrinterRoute(
        targetPrinterSystemName: rules.colorPrinterSystemName,
        reasonEn: 'Auto-routed: Color job → Color Printer',
        reasonSi: 'ස්වයංක්‍රීය යොමුව: වර්ණ (Color) මුද්‍රණ යන්ත්‍රය වෙත',
        isManualOverride: false,
      );
    }

    // 4. B&W / Mono Printer Rule
    if (!anyColor && rules.monoPrinterSystemName.trim().isNotEmpty) {
      return ResolvedPrinterRoute(
        targetPrinterSystemName: rules.monoPrinterSystemName,
        reasonEn: 'Auto-routed: B&W job → Mono Printer',
        reasonSi: 'ස්වයංක්‍රීය යොමුව: කළු-සුදු (Mono) මුද්‍රණ යන්ත්‍රය වෙත',
        isManualOverride: false,
      );
    }

    // Smart capability fallback from discovered printers
    if (anyPhoto) {
      final photoCapable = availablePrinters
          .where((p) =>
              p.displayName.toLowerCase().contains('photo') ||
              p.displayName.toLowerCase().contains('l8050') ||
              p.displayName.toLowerCase().contains('sc-p'))
          .firstOrNull;
      if (photoCapable != null) {
        return ResolvedPrinterRoute(
          targetPrinterSystemName: photoCapable.systemName,
          reasonEn: 'Auto-routed to detected Photo Printer',
          reasonSi: 'ඡායාරූප මුද්‍රණ යන්ත්‍රය වෙත යොමු කරන ලදී',
          isManualOverride: false,
        );
      }
    }

    if (!anyColor) {
      final monoCapable = availablePrinters
          .where((p) => !p.capabilities.supportsColor)
          .firstOrNull;
      if (monoCapable != null) {
        return ResolvedPrinterRoute(
          targetPrinterSystemName: monoCapable.systemName,
          reasonEn: 'Auto-routed B&W job to Monochrome Printer',
          reasonSi: 'කළු-සුදු මුද්‍රණ යන්ත්‍රය වෙත යොමු කරන ලදී',
          isManualOverride: false,
        );
      }
    }

    return ResolvedPrinterRoute(
      targetPrinterSystemName: fallbackPrinter,
      reasonEn: 'Routed to primary ready printer',
      reasonSi: 'ප්‍රධාන සූදානම් මුද්‍රණ යන්ත්‍රය වෙත',
      isManualOverride: false,
    );
  }

  /// Aggregates all customer jobs for a target calendar day into a [ShopDailyReportSummary].
  ShopDailyReportSummary buildDailyReport({
    required DateTime targetDate,
    required List<ShopCustomerJob> allJobs,
    required List<ShopPriceRule> priceRules,
    required ShopSupplyCostConfig costConfig,
  }) {
    final dayJobs = allJobs.where((j) {
      return j.createdAt.year == targetDate.year &&
          j.createdAt.month == targetDate.month &&
          j.createdAt.day == targetDate.day;
    }).toList();

    int completedCount = 0;
    int totalImpressions = 0;
    int bwPages = 0;
    int colorPages = 0;
    int photoPages = 0;
    int a4Sheets = 0;
    int a3Sheets = 0;
    int photo4x6Sheets = 0;
    double revenue = 0.0;
    double discounts = 0.0;
    double inkCost = 0.0;
    double paperCost = 0.0;

    for (final job in dayJobs) {
      if (job.status == CustomerJobStatus.done ||
          job.status == CustomerJobStatus.pickedUp) {
        completedCount++;
      }
      final est = calculateJobEstimate(
        files: job.files,
        priceRules: priceRules,
        costConfig: costConfig,
        flatDiscountAmount: job.discountAmount,
        discountPercent: job.discountPercent,
      );

      totalImpressions += est.totalImpressions;
      bwPages += est.bwPagesCount;
      colorPages += est.colorPagesCount;
      photoPages += est.photoPagesCount;
      revenue += est.finalCustomerTotal;
      discounts += est.discountAmount;
      inkCost += est.estimatedInkOrTonerCost;
      paperCost += est.estimatedPaperCost;

      for (final f in job.files) {
        final s = f.settings;
        final isDuplex = s.duplex != DuplexMode.none;
        final sheetsPerCopy = isDuplex
            ? ((f.pageCount < 1 ? 1 : f.pageCount) / 2.0).ceil()
            : (f.pageCount < 1 ? 1 : f.pageCount);
        final sheets = sheetsPerCopy * s.copies;
        final lowerSize = s.paperSize.toLowerCase();
        if (lowerSize.contains('4x6') || lowerSize.contains('10x15')) {
          photo4x6Sheets += sheets;
        } else if (lowerSize.contains('a3')) {
          a3Sheets += sheets;
        } else {
          a4Sheets += sheets;
        }
      }
    }

    return ShopDailyReportSummary(
      date: targetDate,
      currencyCode: costConfig.currencyCode,
      totalJobsCount: dayJobs.length,
      completedOrPickedUpJobsCount: completedCount,
      totalImpressions: totalImpressions,
      bwPagesCount: bwPages,
      colorPagesCount: colorPages,
      photoPagesCount: photoPages,
      a4SheetsUsed: a4Sheets,
      a3SheetsUsed: a3Sheets,
      photo4x6SheetsUsed: photo4x6Sheets,
      totalRevenue: revenue,
      totalDiscountsGiven: discounts,
      estimatedInkOrTonerCost: inkCost,
      estimatedPaperCost: paperCost,
      jobsForDay: dayJobs,
    );
  }

  /// Generates a bilingual (Sinhala + English) Customer Receipt / Invoice PDF
  /// with embedded `NotoSansSinhala` Unicode font, itemized line breakdown,
  /// discount, total in LKR (or selected currency), and job barcode/code.
  Future<Uint8List> generateCustomerReceiptPdfBytes({
    required ShopCustomerJob job,
    required ShopJobPriceAndCostEstimate estimate,
    required ShopSupplyCostConfig shopConfig,
  }) async {
    final doc = pw.Document();
    final font = await _loadSinhalaFont();

    final baseStyle = font != null
        ? pw.TextStyle(font: font, fontSize: 10)
        : const pw.TextStyle(fontSize: 10);
    final boldStyle = font != null
        ? pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold)
        : pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
    final titleStyle = font != null
        ? pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)
        : pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);

    final cur = estimate.currencyCode;
    final dateStr = job.createdAt.toIso8601String().substring(0, 16).replaceAll('T', ' ');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(shopConfig.shopName, style: titleStyle),
              pw.SizedBox(height: 2),
              pw.Text(shopConfig.shopPhoneOrAddress, style: baseStyle),
              pw.SizedBox(height: 6),
              pw.Text(
                'මුද්‍රණ කුවිතාන්සිය / PRINT RECEIPT & INVOICE',
                style: boldStyle,
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Job No / අංකය: ${job.jobNumberCode}',
                    style: boldStyle,
                  ),
                  pw.Text('Date / දිනය: $dateStr', style: baseStyle),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Customer / පාරිභෝගිකයා: ${job.customerNameOrPhone}',
                style: baseStyle,
              ),
              if (job.notes.trim().isNotEmpty)
                pw.Text('Notes / සටහන්: ${job.notes}', style: baseStyle),
              pw.SizedBox(height: 10),

              // Line items table
              pw.TableHelper.fromTextArray(
                cellStyle: baseStyle,
                headerStyle: boldStyle,
                headers: const [
                  'File / විස්තරය',
                  'Pages x Copies',
                  'Rate',
                  'Amount',
                ],
                data: estimate.lineItems.map((li) {
                  return [
                    '${li.fileName}\n(${li.matchedRuleLabelEn})',
                    '${li.documentPages} x ${li.copies} (${li.totalImpressions}p)',
                    '$cur ${li.unitPricePerImpression.toStringAsFixed(2)}',
                    '$cur ${li.lineSubtotal.toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Subtotal / උප එකතුව: $cur ${estimate.grossSubtotal.toStringAsFixed(2)}',
                      style: baseStyle,
                    ),
                    if (estimate.discountAmount > 0)
                      pw.Text(
                        'Discount / වට්ටම: -$cur ${estimate.discountAmount.toStringAsFixed(2)}',
                        style: baseStyle,
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'TOTAL / මුළු ගෙවීම: $cur ${estimate.finalCustomerTotal.toStringAsFixed(2)}',
                      style: titleStyle,
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'ස්තූතියි! නැවත පැමිණෙන්න • Thank you for your business! (${job.jobNumberCode})',
                  style: baseStyle,
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Exports the Daily Report to a UTF-8 BOM CSV file (compatible with Excel Sinhala).
  Future<File> exportDailyReportCsv({
    required ShopDailyReportSummary summary,
    required List<ShopPriceRule> priceRules,
    required ShopSupplyCostConfig costConfig,
    required String targetPath,
  }) async {
    final buf = StringBuffer();
    final dateOnly = summary.date.toIso8601String().substring(0, 10);
    buf.writeln('Print Helper Shop Mode — Daily Report ($dateOnly)');
    buf.writeln(
      'Total Jobs,Completed/Picked Up,Total Impressions,B&W Pages,Color Pages,Photo Pages,A4 Sheets,A3 Sheets,4x6 Photo Sheets,Revenue (${summary.currencyCode}),Estimated Supply Cost (${summary.currencyCode} - estimate),Estimated Net Profit (${summary.currencyCode} - estimate)',
    );
    buf.writeln(
      '${summary.totalJobsCount},${summary.completedOrPickedUpJobsCount},${summary.totalImpressions},${summary.bwPagesCount},${summary.colorPagesCount},${summary.photoPagesCount},${summary.a4SheetsUsed},${summary.a3SheetsUsed},${summary.photo4x6SheetsUsed},${summary.totalRevenue.toStringAsFixed(2)},${summary.estimatedTotalSupplyCost.toStringAsFixed(2)},${summary.estimatedNetProfit.toStringAsFixed(2)}',
    );
    buf.writeln();
    buf.writeln(
      'Job Code,Customer,Status,Printer,Impressions,Customer Total (${summary.currencyCode}),Estimated Supply Cost (estimate),Estimated Profit (estimate),Created At',
    );

    for (final job in summary.jobsForDay) {
      final est = calculateJobEstimate(
        files: job.files,
        priceRules: priceRules,
        costConfig: costConfig,
        flatDiscountAmount: job.discountAmount,
        discountPercent: job.discountPercent,
      );
      buf.writeln(
        '"${job.jobNumberCode}","${job.customerNameOrPhone.replaceAll('"', '""')}","${job.status.name}","${job.assignedPrinterSystemName}",${est.totalImpressions},${est.finalCustomerTotal.toStringAsFixed(2)},${est.estimatedTotalSupplyCost.toStringAsFixed(2)},${est.estimatedProfit.toStringAsFixed(2)},"${job.createdAt.toIso8601String()}"',
      );
    }

    final file = File(targetPath);
    await file.parent.create(recursive: true);
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(buf.toString())];
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Exports the Daily Report to a bilingual PDF document.
  Future<File> exportDailyReportPdf({
    required ShopDailyReportSummary summary,
    required ShopSupplyCostConfig costConfig,
    required String targetPath,
  }) async {
    final doc = pw.Document();
    final font = await _loadSinhalaFont();
    final baseStyle = font != null
        ? pw.TextStyle(font: font, fontSize: 10)
        : const pw.TextStyle(fontSize: 10);
    final boldStyle = font != null
        ? pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold)
        : pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
    final titleStyle = font != null
        ? pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)
        : pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);

    final cur = summary.currencyCode;
    final dateOnly = summary.date.toIso8601String().substring(0, 10);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${costConfig.shopName} — Daily Report / දෛනික වාර්තාව ($dateOnly)',
                style: titleStyle,
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                cellStyle: baseStyle,
                headerStyle: boldStyle,
                headers: const ['Metric / විස්තරය', 'Value / අගය'],
                data: [
                  ['Total Customer Jobs / මුළු ඇණවුම්', '${summary.totalJobsCount}'],
                  [
                    'Completed & Picked Up / අවසන් කළ ඇණවුම්',
                    '${summary.completedOrPickedUpJobsCount}'
                  ],
                  ['Total Impressions / මුළු පිටු', '${summary.totalImpressions}'],
                  ['B&W Pages / කළු-සුදු පිටු', '${summary.bwPagesCount}'],
                  ['Color Pages / වර්ණ පිටු', '${summary.colorPagesCount}'],
                  ['Photo Pages / ඡායාරූප පිටු', '${summary.photoPagesCount}'],
                  [
                    'Sheets Used (A4 / A3 / 4x6)',
                    '${summary.a4SheetsUsed} A4 • ${summary.a3SheetsUsed} A3 • ${summary.photo4x6SheetsUsed} (4x6)'
                  ],
                  [
                    'Total Revenue / මුළු ආදායම',
                    '$cur ${summary.totalRevenue.toStringAsFixed(2)}'
                  ],
                  [
                    'Estimated Ink/Toner & Paper Cost (estimate)',
                    '$cur ${summary.estimatedTotalSupplyCost.toStringAsFixed(2)} (estimate)'
                  ],
                  [
                    'Estimated Net Profit / ඇස්තමේන්තුගත ලාභය (estimate)',
                    '$cur ${summary.estimatedNetProfit.toStringAsFixed(2)} (estimate)'
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );

    final file = File(targetPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  static ShopPriceRule _matchPriceRule({
    required FilePrintSettings settings,
    required List<ShopPriceRule> rules,
  }) {
    final isDuplex = settings.duplex != DuplexMode.none;
    final reqSize = settings.paperSize.toLowerCase();
    final reqMedia = settings.mediaType.toLowerCase();

    // Exact match on size + color + duplex + media
    for (final r in rules) {
      if (_sizesMatch(reqSize, r.paperSize.toLowerCase()) &&
          r.isColor == settings.isColor &&
          r.isDoubleSided == isDuplex &&
          _mediaMatch(reqMedia, r.mediaType.toLowerCase())) {
        return r;
      }
    }

    // Fallback match on size + color + duplex
    for (final r in rules) {
      if (_sizesMatch(reqSize, r.paperSize.toLowerCase()) &&
          r.isColor == settings.isColor &&
          r.isDoubleSided == isDuplex) {
        return r;
      }
    }

    // Fallback match on color + duplex
    for (final r in rules) {
      if (r.isColor == settings.isColor && r.isDoubleSided == isDuplex) {
        return r;
      }
    }

    return rules.isNotEmpty
        ? rules.first
        : ShopPriceRule.defaultRulesLkr.first;
  }

  static bool _sizesMatch(String a, String b) {
    if (a == b) return true;
    if (a.contains('4x6') && b.contains('4x6')) return true;
    if (a.contains('a4') && b.contains('a4')) return true;
    if (a.contains('a3') && b.contains('a3')) return true;
    return false;
  }

  static bool _mediaMatch(String a, String b) {
    if (a == b) return true;
    if (a.contains('plain') && b.contains('plain')) return true;
    if ((a.contains('photo') || a.contains('glossy')) &&
        (b.contains('photo') || b.contains('glossy'))) {
      return true;
    }
    return false;
  }

  static bool _isPhotoMediaOrSize(String paperSize, String mediaType) {
    final ls = paperSize.toLowerCase();
    final lm = mediaType.toLowerCase();
    return ls.contains('4x6') ||
        ls.contains('5x7') ||
        lm.contains('photo') ||
        lm.contains('glossy');
  }

  static double _sheetCostForPaper(
    String paperSize,
    String mediaType,
    ShopSupplyCostConfig costConfig,
  ) {
    if (_isPhotoMediaOrSize(paperSize, mediaType)) {
      return costConfig.estimatedPhoto4x6SheetCost;
    }
    if (paperSize.toLowerCase().contains('a3')) {
      return costConfig.estimatedA3PlainSheetCost;
    }
    return costConfig.estimatedA4PlainSheetCost;
  }

  static Future<pw.Font?> _loadSinhalaFont() async {
    try {
      final f = File('assets/fonts/NotoSansSinhala-Regular.ttf');
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        return pw.Font.ttf(bytes.buffer.asByteData());
      }
      final data =
          await rootBundle.load('assets/fonts/NotoSansSinhala-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }
}
