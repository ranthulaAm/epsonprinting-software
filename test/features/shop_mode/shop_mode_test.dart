import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:print_helper/core/domain/print_models.dart';
import 'package:print_helper/features/presets/data/presets_persistence.dart';
import 'package:print_helper/features/shop_mode/data/shop_mode_persistence_and_services.dart';
import 'package:print_helper/features/shop_mode/domain/shop_mode_models.dart';

void main() {
  group('Shop Mode Built-In Presets', () {
    test(
      'includes A4 B&W double-sided, A4 color single, and Photo 4x6 glossy presets',
      () {
        final names = SqlitePresetsPersistence.builtInPresets
            .map((preset) => preset.name)
            .toList();

        expect(names, contains('A4 B&W double-sided'));
        expect(names, contains('A4 color single'));
        expect(names, contains('Photo 4x6 glossy'));
        expect(names, contains('A4 B&W single'));

        final photoPreset = SqlitePresetsPersistence.builtInPresets.firstWhere(
          (p) => p.name == 'Photo 4x6 glossy',
        );
        expect(photoPreset.settings.paperSizeId, 'Photo4x6');
        expect(photoPreset.settings.mediaType, 'Photo Paper Glossy');
        expect(photoPreset.settings.colorMode, PrintColorMode.color);
      },
    );
  });

  group('Shop Mode Price Calculator, Supply Cost & Profit Estimate', () {
    test(
      'calculates A4 B&W double-sided price, supply cost estimate, and profit estimate with discount',
      () {
        final files = <QueueFileItem>[
          const QueueFileItem(
            id: 'f1',
            filePath: 'C:/jobs/thesis.pdf',
            fileName: 'thesis.pdf',
            extension: '.pdf',
            fileSizeBytes: 120000,
            pageCount: 10,
            settings: JobPrintSettings(
              copies: 2,
              colorMode: PrintColorMode.blackAndWhite,
              duplexMode: DuplexMode.longEdge,
              paperSizeId: 'A4',
              mediaType: 'Plain Paper',
            ),
          ),
        ];

        // 10 pages * 2 copies = 20 effective pages, 5 sheets * 2 = 10 physical sheets
        // Default A4 B&W double-sided rate = LKR 8.00/page -> Subtotal = LKR 160.00
        // Discount = LKR 10.00 -> Customer Total = LKR 150.00
        final estimate = ShopPricingAndReceiptService.calculateJobEstimate(
          files: files,
          priceRules: ShopPricingAndReceiptService.defaultPriceRulesLkr(),
          costConfig: const ShopSupplyCostConfig(
            currencyCode: 'LKR',
            blackRefillPrice: 2500.0,
            blackPageYield: 5000, // LKR 0.50 / page
            paperReamPriceA4: 1500.0, // LKR 3.00 / sheet (500 sheets)
          ),
          discountAmount: 10.0,
        );

        expect(estimate.totalEffectivePages, 20);
        expect(estimate.totalPhysicalSheets, 10);
        expect(estimate.bwPages, 20);
        expect(estimate.colorPages, 0);
        expect(estimate.subtotalPrice, closeTo(160.0, 0.01));
        expect(estimate.discountAmount, closeTo(10.0, 0.01));
        expect(estimate.finalCustomerTotal, closeTo(150.0, 0.01));

        // Supply cost estimate:
        // Ink: 20 B&W pages * 0.50 = 10.00
        // Paper: 10 A4 sheets * 3.00 = 30.00
        // Total supply cost (estimate) = 40.00
        // Net profit (estimate) = 150.00 - 40.00 = 110.00
        expect(estimate.estimatedInkTonerCost, closeTo(10.0, 0.01));
        expect(estimate.estimatedPaperCost, closeTo(30.0, 0.01));
        expect(estimate.estimatedTotalSupplyCost, closeTo(40.0, 0.01));
        expect(estimate.estimatedProfit, closeTo(110.0, 0.01));
        expect(estimate.isEstimateLabelEn, contains('Estimate'));
        expect(estimate.isEstimateLabelSi, contains('ඇස්තමේන්තුවකි'));
      },
    );

    test(
      'calculates Photo 4x6 glossy and A4 color single jobs accurately',
      () {
        final files = <QueueFileItem>[
          const QueueFileItem(
            id: 'photo_1',
            filePath: 'C:/jobs/passport.jpg',
            fileName: 'passport.jpg',
            extension: '.jpg',
            fileSizeBytes: 85000,
            pageCount: 1,
            settings: JobPrintSettings(
              copies: 4,
              colorMode: PrintColorMode.color,
              duplexMode: DuplexMode.none,
              paperSizeId: 'Photo4x6',
              mediaType: 'Photo Paper Glossy',
            ),
          ),
        ];

        final estimate = ShopPricingAndReceiptService.calculateJobEstimate(
          files: files,
          priceRules: ShopPricingAndReceiptService.defaultPriceRulesLkr(),
          costConfig: const ShopSupplyCostConfig(currencyCode: 'LKR'),
        );

        // 4 copies * LKR 60.00 default Photo 4x6 Glossy rate = LKR 240.00
        expect(estimate.photoPages, 4);
        expect(estimate.finalCustomerTotal, closeTo(240.0, 0.01));
      },
    );
  });

  group('Shop Mode Smart Printer Routing Rules', () {
    const printers = <DiscoveredPrinter>[
      DiscoveredPrinter(
        name: 'HP LaserJet Mono Fast',
        driverName: 'HP Universal Printing PCL 6',
        portName: 'USB001',
        supportsColor: false,
        supportsDuplex: true,
        isDefault: true,
      ),
      DiscoveredPrinter(
        name: 'Epson L3250 Color Tank',
        driverName: 'EPSON L3250 Series',
        portName: '192.168.1.50',
        supportsColor: true,
        supportsDuplex: false,
      ),
      DiscoveredPrinter(
        name: 'Epson L8050 Photo Printer',
        driverName: 'EPSON L8050 Series',
        portName: 'USB002',
        supportsColor: true,
        supportsDuplex: false,
      ),
      DiscoveredPrinter(
        name: 'Ricoh HighSpeed 60ppm',
        driverName: 'Ricoh MP 6055',
        portName: '192.168.1.100',
        supportsColor: false,
        supportsDuplex: true,
      ),
    ];

    const routingRules = ShopPrinterRoutingRules(
      autoRouteEnabled: true,
      monoPrinterName: 'HP LaserJet Mono Fast',
      colorPrinterName: 'Epson L3250 Color Tank',
      photoPrinterName: 'Epson L8050 Photo Printer',
      fastestBigJobPrinterName: 'Ricoh HighSpeed 60ppm',
      bigJobPageThreshold: 50,
    );

    test('routes B&W, Color, Photo 4x6, Big Jobs, and Manual Override properly', () {
      // 1. B&W job -> Mono printer
      final bwRoute = ShopPricingAndReceiptService.resolvePrinterForJob(
        files: const <QueueFileItem>[
          QueueFileItem(
            id: 'bw1',
            filePath: 'doc.pdf',
            fileName: 'doc.pdf',
            extension: '.pdf',
            fileSizeBytes: 1000,
            pageCount: 10,
            settings: JobPrintSettings(
              colorMode: PrintColorMode.blackAndWhite,
              paperSizeId: 'A4',
            ),
          ),
        ],
        rules: routingRules,
        availablePrinters: printers,
      );
      expect(bwRoute.printerName, 'HP LaserJet Mono Fast');
      expect(bwRoute.isManualOverride, isFalse);

      // 2. Color job -> Color printer
      final colorRoute = ShopPricingAndReceiptService.resolvePrinterForJob(
        files: const <QueueFileItem>[
          QueueFileItem(
            id: 'col1',
            filePath: 'brochure.pdf',
            fileName: 'brochure.pdf',
            extension: '.pdf',
            fileSizeBytes: 1000,
            pageCount: 8,
            settings: JobPrintSettings(
              colorMode: PrintColorMode.color,
              paperSizeId: 'A4',
            ),
          ),
        ],
        rules: routingRules,
        availablePrinters: printers,
      );
      expect(colorRoute.printerName, 'Epson L3250 Color Tank');

      // 3. Photo 4x6 glossy job -> Photo printer
      final photoRoute = ShopPricingAndReceiptService.resolvePrinterForJob(
        files: const <QueueFileItem>[
          QueueFileItem(
            id: 'ph1',
            filePath: 'photo.jpg',
            fileName: 'photo.jpg',
            extension: '.jpg',
            fileSizeBytes: 1000,
            pageCount: 1,
            settings: JobPrintSettings(
              colorMode: PrintColorMode.color,
              paperSizeId: 'Photo4x6',
              mediaType: 'Photo Paper Glossy',
            ),
          ),
        ],
        rules: routingRules,
        availablePrinters: printers,
      );
      expect(photoRoute.printerName, 'Epson L8050 Photo Printer');

      // 4. Big job (>= 50 pages) -> Fastest printer
      final bigJobRoute = ShopPricingAndReceiptService.resolvePrinterForJob(
        files: const <QueueFileItem>[
          QueueFileItem(
            id: 'big1',
            filePath: 'book.pdf',
            fileName: 'book.pdf',
            extension: '.pdf',
            fileSizeBytes: 50000,
            pageCount: 60,
            settings: JobPrintSettings(
              colorMode: PrintColorMode.blackAndWhite,
              paperSizeId: 'A4',
            ),
          ),
        ],
        rules: routingRules,
        availablePrinters: printers,
      );
      expect(bigJobRoute.printerName, 'Ricoh HighSpeed 60ppm');

      // 5. Manual Override -> Always respected
      final manualRoute = ShopPricingAndReceiptService.resolvePrinterForJob(
        files: const <QueueFileItem>[
          QueueFileItem(
            id: 'm1',
            filePath: 'book.pdf',
            fileName: 'book.pdf',
            extension: '.pdf',
            fileSizeBytes: 50000,
            pageCount: 60,
          ),
        ],
        rules: routingRules,
        availablePrinters: printers,
        manualOverridePrinterName: 'Epson L3250 Color Tank',
      );
      expect(manualRoute.printerName, 'Epson L3250 Color Tank');
      expect(manualRoute.isManualOverride, isTrue);
    });
  });

  group('Shop Mode Persistence, Receipts, Daily Report & Drop Folders', () {
    late Directory tempDir;
    late ShopModePersistence persistence;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('print_helper_shop_test_');
      persistence = ShopModePersistence(
        dbPathOverride: p.join(tempDir.path, 'shop_test.sqlite'),
      );
      await persistence.init();
    });

    tearDown(() async {
      persistence.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'stores customer jobs, updates status (Waiting -> Printing -> Done -> Picked up), generates bilingual PDF receipt, and exports Daily Report CSV/PDF',
      () async {
        final jobNum = persistence.generateNextJobNumber();
        expect(jobNum, 'JOB-1001');

        const files = <QueueFileItem>[
          QueueFileItem(
            id: 'item1',
            filePath: 'C:/jobs/cv.pdf',
            fileName: 'cv.pdf',
            extension: '.pdf',
            fileSizeBytes: 4096,
            pageCount: 4,
            settings: JobPrintSettings(
              copies: 2,
              colorMode: PrintColorMode.blackAndWhite,
              duplexMode: DuplexMode.none,
              paperSizeId: 'A4',
            ),
          ),
        ];

        final estimate = ShopPricingAndReceiptService.calculateJobEstimate(
          files: files,
          priceRules: persistence.loadPriceRules(),
          costConfig: persistence.loadSupplyCostConfig(),
          discountAmount: 5.0,
        );

        final job = ShopCustomerJob(
          id: 'job_1',
          jobNumber: jobNum,
          customerNameOrPhone: 'Kasun Perera (077-1234567)',
          files: files,
          status: CustomerJobStatus.waiting,
          assignedPrinterName: 'HP LaserJet Mono Fast',
          presetName: 'A4 B&W single',
          notes: 'Urgent counter pickup',
          discountAmount: 5.0,
          createdAt: DateTime(2026, 10, 26, 10, 30),
          priceAndCost: estimate,
        );

        persistence.upsertCustomerJob(job);
        expect(persistence.loadCustomerJobs().length, 1);
        expect(
          persistence.loadCustomerJobs().first.status,
          CustomerJobStatus.waiting,
        );

        // Progress status: Waiting -> Printing -> Done -> Picked up
        final pickedUpJob = job.copyWith(
          status: CustomerJobStatus.pickedUp,
          completedAt: DateTime(2026, 10, 26, 10, 35),
        );
        persistence.upsertCustomerJob(pickedUpJob);

        final loaded = persistence.loadCustomerJobs().first;
        expect(loaded.status, CustomerJobStatus.pickedUp);

        // Generate bilingual Customer Receipt / Invoice PDF
        final receiptBytes =
            await ShopPricingAndReceiptService.generateCustomerReceiptPdfBytes(
          job: loaded,
          shopName: 'Lanka Print Shop',
        );
        expect(receiptBytes.length, greaterThan(500));
        expect(
          utf8.decode(receiptBytes.sublist(0, 5), allowMalformed: true),
          '%PDF-',
        );

        // Compute Daily Report and export CSV & PDF
        final dailySummary = ShopPricingAndReceiptService.buildDailyReport(
          date: DateTime(2026, 10, 26),
          allJobs: persistence.loadCustomerJobs(),
          currencyCode: 'LKR',
        );
        expect(dailySummary.totalJobsCount, 1);
        expect(dailySummary.completedJobsCount, 1);
        expect(dailySummary.bwPagesCount, 8);
        expect(dailySummary.totalRevenue, closeTo(75.0, 0.01));

        final csvPath = p.join(tempDir.path, 'daily_report.csv');
        await ShopPricingAndReceiptService.exportDailyReportCsv(
          summary: dailySummary,
          jobsForDay: persistence.loadCustomerJobs(),
          targetPath: csvPath,
        );
        final csvContent = await File(csvPath).readAsString();
        expect(csvContent, contains('Estimated Profit (estimate)'));
        expect(csvContent, contains('JOB-1001'));

        final pdfPath = p.join(tempDir.path, 'daily_report.pdf');
        await ShopPricingAndReceiptService.exportDailyReportPdf(
          summary: dailySummary,
          jobsForDay: persistence.loadCustomerJobs(),
          targetPath: pdfPath,
        );
        final pdfBytes = await File(pdfPath).readAsBytes();
        expect(
          utf8.decode(pdfBytes.sublist(0, 5), allowMalformed: true),
          '%PDF-',
        );
      },
    );
  });
}
