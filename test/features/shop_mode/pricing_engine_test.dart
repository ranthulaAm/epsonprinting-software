import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_pdf_gear/features/workspace/domain/print_queue_item.dart';
import 'package:antigravity_pdf_gear/features/workspace/domain/print_settings_models.dart';
import 'package:antigravity_pdf_gear/features/shop_mode/domain/shop_mode_models.dart';
import 'package:antigravity_pdf_gear/features/shop_mode/domain/shop_pricing_engine_models.dart';
import 'package:antigravity_pdf_gear/features/shop_mode/data/shop_pricing_engine_service.dart';

void main() {
  const service = ShopPricingEngineService();
  final defaultPriceList = PriceListPackage(
    id: 'test_pkg',
    name: 'Test Price List',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    entries: PriceListPackage.defaultEntriesLkr,
    customerGroups: CustomerGroupConfig.defaultCustomerGroups,
    feesConfig: const JobFeesConfig(minimumJobCharge: 30.0, setupServiceFee: 0.0),
    currencyConfig: const CurrencyAndRoundingConfig(roundingRule: RoundingRule.nearest1),
    pinConfig: const SecurityPinConfig(isPinLockEnabled: true, hashedPin: '5566'),
  );

  const supplyCosts = ShopSupplyCostConfig(
    blackSupplyPrice: 3200.0,
    blackSupplyPageYield: 4500,
    colorSupplySetPrice: 9600.0,
    colorSupplySetPageYield: 6500,
    a4PlainReam500Price: 2250.0,
  );

  group('Shop Pricing Engine Tests', () {
    test('1. Exact multidimensional rule matching', () {
      final fileA4Bw = PrintQueueItem(
        id: 'f1',
        filePath: '/docs/invoice.pdf',
        fileName: 'invoice.pdf',
        fileSizeBytes: 1024,
        pageCount: 5,
        settings: const FilePrintSettings(paperSize: 'A4', isColor: false, mediaType: 'Plain Paper'),
      );

      final quote = service.calculateQuote(
        files: [fileA4Bw],
        priceList: defaultPriceList,
        supplyCosts: supplyCosts,
      );

      expect(quote.items.length, 1);
      final item = quote.items.first;
      expect(item.segments.length, 1);
      expect(item.segments.first.matchedRuleId, 'rule_a4_doc_bw_single');
      expect(item.segments.first.unitPrice, 15.0);
    });

    test('2. Tier boundaries (1-10 @ 15, 11-50 @ 12, 51-200 @ 10, 201+ @ 8)', () {
      final entry = defaultPriceList.entries.firstWhere((e) => e.id == 'rule_a4_doc_bw_single');

      // Test boundary 10 vs 11
      expect(entry.getPriceForQuantity(1), 15.0);
      expect(entry.getPriceForQuantity(10), 15.0);
      expect(entry.getPriceForQuantity(11), 12.0);

      // Test boundary 50 vs 51
      expect(entry.getPriceForQuantity(50), 12.0);
      expect(entry.getPriceForQuantity(51), 10.0);

      // Test boundary 200 vs 201
      expect(entry.getPriceForQuantity(200), 10.0);
      expect(entry.getPriceForQuantity(201), 8.0);
      expect(entry.getPriceForQuantity(500), 8.0);
    });

    test('3. Automatic page classification and mixed document split billing', () {
      final mixedFile = PrintQueueItem(
        id: 'f_mixed',
        filePath: '/docs/annual_report.pdf',
        fileName: 'annual_report.pdf',
        fileSizeBytes: 2048,
        pageCount: 20,
        settings: const FilePrintSettings(paperSize: 'A4', isColor: true, mediaType: 'Plain Paper'),
      );

      // Custom classification: 17 B&W pages + 3 Color pages
      final customClassifications = List.generate(20, (idx) {
        final p = idx + 1;
        final isCol = p >= 18;
        return PageClassificationRecord(
          pageIndex: p,
          detectedColor: isCol ? PrintColorDimension.color : PrintColorDimension.blackAndWhite,
          isPhotoHeavy: false,
          isOwnerOverridden: true,
        );
      });

      final quote = service.calculateQuote(
        files: [mixedFile],
        priceList: defaultPriceList,
        supplyCosts: supplyCosts,
        filePageClassifications: {'f_mixed': customClassifications},
      );

      final item = quote.items.first;
      expect(item.segments.length, 2);

      // Segment 1: 17 B&W pages
      final bwSeg = item.segments.firstWhere((s) => s.matchedRuleId == 'rule_a4_doc_bw_single');
      expect(bwSeg.pageCount, 17);
      expect(bwSeg.unitPrice, 12.0); // 17 impressions hits tier 11-50 @ Rs. 12
      expect(bwSeg.subtotal, 17 * 12.0); // 204.0

      // Segment 2: 3 Color pages
      final colSeg = item.segments.firstWhere((s) => s.matchedRuleId == 'rule_a4_doc_color_single');
      expect(colSeg.pageCount, 3);
      expect(colSeg.unitPrice, 40.0); // 3 impressions hits tier 1-10 @ Rs. 40
      expect(colSeg.subtotal, 3 * 40.0); // 120.0

      expect(quote.grossSubtotal, 204.0 + 120.0); // 324.0
    });

    test('4. Customer group discounts (Student 15%, Business 2 free pages)', () {
      final docFile = PrintQueueItem(
        id: 'f_doc',
        filePath: '/docs/thesis.pdf',
        fileName: 'thesis.pdf',
        fileSizeBytes: 1024,
        pageCount: 10,
        settings: const FilePrintSettings(paperSize: 'A4', isColor: false, mediaType: 'Plain Paper'),
      );

      // Student 15% discount: 10 pages @ 15 = 150. Discount = 22.50. Payable = 127.50 -> rounded nearest 1 = 128
      final studentQuote = service.calculateQuote(
        files: [docFile],
        priceList: defaultPriceList,
        supplyCosts: supplyCosts,
        customerGroup: CustomerGroupType.student,
      );
      expect(studentQuote.grossSubtotal, 150.0);
      expect(studentQuote.customerGroupDiscount, 22.50);
      expect(studentQuote.finalPayableTotal, 128.0);

      // Business account: 2 free pages. 2 * 15 = 30 free pages deduction!
      // Plus 10% discount on remaining 120 = 12. Total = 108.
      final businessQuote = service.calculateQuote(
        files: [docFile],
        priceList: defaultPriceList,
        supplyCosts: supplyCosts,
        customerGroup: CustomerGroupType.business,
      );
      expect(businessQuote.freePagesDeduction, 30.0);
      expect(businessQuote.customerGroupDiscount, 12.0);
      expect(businessQuote.finalPayableTotal, 108.0);
    });

    test('5. Minimum job charge enforcement', () {
      final singlePageFile = PrintQueueItem(
        id: 'f_one',
        filePath: '/docs/single.pdf',
        fileName: 'single.pdf',
        fileSizeBytes: 512,
        pageCount: 1,
        settings: const FilePrintSettings(paperSize: 'A4', isColor: false, mediaType: 'Plain Paper'),
      );

      // Gross is 1 page @ 15 = Rs. 15. Minimum job charge is Rs. 30!
      final quote = service.calculateQuote(
        files: [singlePageFile],
        priceList: defaultPriceList,
        supplyCosts: supplyCosts,
      );

      expect(quote.grossSubtotal, 15.0);
      expect(quote.minimumJobAdjustment, 15.0);
      expect(quote.finalPayableTotal, 30.0);
    });

    test('6. Configurable Rounding Rules (none, nearest 1, 5, 10, 50)', () {
      const val = 123.40;
      expect(RoundingRule.none.apply(val), 123.40);
      expect(RoundingRule.nearest1.apply(val), 123.0);
      expect(RoundingRule.nearest5.apply(val), 125.0);
      expect(RoundingRule.nearest10.apply(val), 120.0);
      expect(RoundingRule.nearest50.apply(val), 100.0);

      const val2 = 138.60;
      expect(RoundingRule.nearest5.apply(val2), 140.0);
      expect(RoundingRule.nearest10.apply(val2), 140.0);
      expect(RoundingRule.nearest50.apply(val2), 150.0);
    });

    test('7. Missing price safeguard (never silently charges zero)', () {
      // Create price list with empty entries
      final emptyPriceList = defaultPriceList.copyWith(entries: const []);

      final file = PrintQueueItem(
        id: 'f_unk',
        filePath: '/docs/weird.pdf',
        fileName: 'weird.pdf',
        fileSizeBytes: 1024,
        pageCount: 2,
        settings: const FilePrintSettings(paperSize: 'Legal', isColor: true, mediaType: 'Custom Card'),
      );

      final quote = service.calculateQuote(
        files: [file],
        priceList: emptyPriceList,
        supplyCosts: supplyCosts,
      );

      // Must NOT be zero! Conservative fallback of Rs. 40 for Color is applied
      expect(quote.grossSubtotal, greaterThan(0.0));
      expect(quote.warnings.isNotEmpty, true);
      expect(quote.items.first.hasMissingPriceWarning, true);
    });

    test('8. Missing price combination detector', () {
      // Detect on default price list
      final missing = service.detectMissingPrices(defaultPriceList);
      // Default list has plain A4 B&W/Color, A3, Photo 4x6. Obscure combinations (like A3 Glossy) are flagged.
      expect(missing, isA<List<MissingPriceCombination>>());
      for (final m in missing) {
        expect(m.suggestedRate, greaterThan(0.0));
      }
    });

    test('9. Cost side and profit estimation', () {
      final file = PrintQueueItem(
        id: 'f_cost',
        filePath: '/docs/thesis.pdf',
        fileName: 'thesis.pdf',
        fileSizeBytes: 1024,
        pageCount: 10,
        settings: const FilePrintSettings(paperSize: 'A4', isColor: false, mediaType: 'Plain Paper'),
      );

      final quote = service.calculateQuote(
        files: [file],
        priceList: defaultPriceList,
        supplyCosts: supplyCosts,
      );

      // Estimated ink: 10 * (3200 / 4500) = 7.11
      // Estimated paper: 10 * (2250 / 500) = 45.0
      // Total cost: ~52.11
      // Customer Total: 150
      // Profit: 150 - 52.11 = ~97.89
      expect(quote.estimatedInkCost, closeTo(7.11, 0.5));
      expect(quote.estimatedPaperCost, closeTo(45.0, 0.5));
      expect(quote.estimatedTotalCost, closeTo(52.11, 1.0));
      expect(quote.estimatedProfit, closeTo(97.89, 1.0));
    });

    test('10. CSV export, JSON package duplicate & PIN lock', () {
      final csv = defaultPriceList.exportToCsv();
      expect(csv.contains('rule_a4_doc_bw_single'), true);
      expect(csv.contains('Base Price'), true);

      // Duplicate
      final cloned = defaultPriceList.duplicate(newName: 'Holiday Seasonal Price List');
      expect(cloned.name, 'Holiday Seasonal Price List');
      expect(cloned.isDefault, false);
      expect(cloned.changeHistory.length, 1);

      // PIN check
      expect(defaultPriceList.pinConfig.verify('5566'), true);
      expect(defaultPriceList.pinConfig.verify('0000'), false);
    });
  });
}
