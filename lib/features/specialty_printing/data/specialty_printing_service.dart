import 'dart:convert';
import 'dart:math' as math;

import '../domain/specialty_print_models.dart';

/// Service implementing business logic, template generators, mask calculations,
/// and safe spooler job generation for all 8 specialty print modules.
///
/// Adheres strictly to the safety mandate:
/// - Uses official Windows driver print pipelines through the spooler.
/// - NEVER sends unverified raw ESC/P-R control codes or proprietary head commands.
/// - TM-series POS receipt printing supports standard Windows driver output or
///   documented standard ESC/POS ASCII formatting.
class SpecialtyPrintingService {
  // ==========================================================================
  // 1. CD / DVD Disc Mask Geometry & Test Pattern
  // ==========================================================================

  /// Evaluates whether a point $(x, y)$ in mm relative to the disc center
  /// falls inside the printable circular ring.
  ///
  /// Outer and inner boundaries are defined strictly by DIAMETER in mm.
  static bool isPointInsideCdDvdRing({
    required double xMm,
    required double yMm,
    required double outerDiameterMm,
    required double innerDiameterMm,
  }) {
    if (outerDiameterMm <= 0 || innerDiameterMm < 0) return false;
    if (innerDiameterMm >= outerDiameterMm) return false;

    final distMm = math.sqrt(xMm * xMm + yMm * yMm);
    final rOuterMm = outerDiameterMm / 2.0;
    final rInnerMm = innerDiameterMm / 2.0;

    return distMm >= rInnerMm && distMm <= rOuterMm;
  }

  /// Calculates total printable ring area in square millimeters:
  ///
  /// $$\text{Area} = \pi \left(\left(\frac{D_{\text{outer}}}{2}\right)^2 - \left(\frac{D_{\text{inner}}}{2}\right)^2\right)$$
  static double calculateCdDvdPrintableAreaMm2({
    required double outerDiameterMm,
    required double innerDiameterMm,
  }) {
    if (outerDiameterMm <= innerDiameterMm) return 0.0;
    final rOuter = outerDiameterMm / 2.0;
    final rInner = innerDiameterMm / 2.0;
    return math.pi * (rOuter * rOuter - rInner * rInner);
  }

  /// Calculates character placement coordinates $(x, y, \text{rotationRad})$
  /// along a circle for curved disc perimeter text.
  static List<({double xMm, double yMm, double rotationRad, String char})>
      calculateCircularTextPath({
    required String text,
    required double radiusMm,
    double startAngleDeg = 0.0,
    double charSpacingDeg = 4.5,
  }) {
    final result = <({double xMm, double yMm, double rotationRad, String char})>[];
    if (text.isEmpty || radiusMm <= 0) return result;

    var currentAngleDeg = startAngleDeg;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final angleRad = currentAngleDeg * (math.pi / 180.0);
      final x = radiusMm * math.cos(angleRad);
      final y = radiusMm * math.sin(angleRad);
      final tangentRad = angleRad + (math.pi / 2.0);

      result.add((xMm: x, yMm: y, rotationRad: tangentRad, char: char));
      currentAngleDeg += charSpacingDeg;
    }
    return result;
  }

  /// Generates printable instructions for loading the physical disc tray.
  static List<String> getCdDvdLoadingInstructions(String languageCode) {
    if (languageCode == 'si') {
      return [
        '1. ප්‍රින්ටරයේ ඉදිරිපස CD/DVD තැටි ආධාරකය (Tray Guide) පහළට අදින්න.',
        '2. මුද්‍රණය කළ හැකි (Inkjet Printable) CD/DVD තැටිය තැටියට (Tray) නිවැරදිව තබන්න.',
        '3. තැටියේ ඊතල ලකුණ ප්‍රින්ටරයේ ඊතල ලකුණට සමපාත වන තෙක් කෙලින්ම ඇතුල් කරන්න.',
        '4. තිරයේ "ප්‍රින්ට් කරන්න" ඔබන්න. (කිසිවිටෙකත් තැටිය බලෙන් තල්ලු නොකරන්න).',
      ];
    }
    return [
      '1. Lower the printer front CD/DVD tray guide.',
      '2. Place the inkjet-printable disc firmly onto the disc tray.',
      '3. Insert the tray straight into the slot until the arrows on the tray and guide line up.',
      '4. Click Print. (Do not force or push the tray once aligned).',
    ];
  }

  // ==========================================================================
  // 2. PVC ID Card Batch & Calibration Calculations
  // ==========================================================================

  /// Validates standard ISO/IEC 7810 CR80 dimensions.
  static bool isValidCr80Dimensions(double widthMm, double heightMm) {
    const targetW = PvcIdCardSpec.cr80WidthMm; // 85.60 mm
    const targetH = PvcIdCardSpec.cr80HeightMm; // 53.98 mm
    const tolerance = 0.5; // 0.5 mm tolerance

    return (widthMm - targetW).abs() <= tolerance &&
        (heightMm - targetH).abs() <= tolerance;
  }

  /// Parses a CSV string of employee/student data into a batch of [PvcCardData].
  static List<PvcCardData> parsePvcCardBatchCsv(String csvContent) {
    final cards = <PvcCardData>[];
    final lines = csvContent.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || i == 0 && line.toLowerCase().contains('id')) continue; // Skip header

      final cols = line.split(',').map((c) => c.trim().replaceAll('"', '')).toList();
      if (cols.isNotEmpty && cols[0].isNotEmpty) {
        cards.add(
          PvcCardData(
            cardId: cols[0],
            fullName: cols.length > 1 ? cols[1] : 'Cardholder',
            roleOrTitle: cols.length > 2 ? cols[2] : 'Staff',
            organization: cols.length > 3 ? cols[3] : null,
            photoPath: cols.length > 4 ? cols[4] : null,
            barcodeData: cols.length > 5 ? cols[5] : cols[0],
          ),
        );
      }
    }
    return cards;
  }

  /// Calculates printed card coordinates on the physical tray after applying
  /// printer-specific calibration offsets $(x, y)$ in mm.
  static ({double slot1X, double slot1Y, double slot2X, double slot2Y})
      calculateCardTrayLayoutCoordinates({
    required double offsetXmm,
    required double offsetYmm,
    double slotGapMm = 12.0,
    double trayTopMarginMm = 20.0,
    double trayLeftMarginMm = 15.0,
  }) {
    final s1X = trayLeftMarginMm + offsetXmm;
    final s1Y = trayTopMarginMm + offsetYmm;

    final s2X = trayLeftMarginMm + offsetXmm;
    final s2Y = trayTopMarginMm + PvcIdCardSpec.cr80HeightMm + slotGapMm + offsetYmm;

    return (slot1X: s1X, slot1Y: s1Y, slot2X: s2X, slot2Y: s2Y);
  }

  // ==========================================================================
  // 3. Passport & ID Photo Imposition Calculations
  // ==========================================================================

  /// Computes optimal photo imposition grid on target paper sheet.
  ///
  /// Returns detailed grid metrics:
  /// - `cols`: number of photos horizontally
  /// - `rows`: number of photos vertically
  /// - `totalFit`: total photos on sheet
  /// - `isRotated`: whether photos were rotated 90 deg for higher yield
  /// - `leftMarginMm`: centered left margin
  /// - `topMarginMm`: centered top margin
  static ({
    int cols,
    int rows,
    int totalFit,
    bool isRotated,
    double leftMarginMm,
    double topMarginMm,
  }) calculatePassportImposition({
    required double photoWidthMm,
    required double photoHeightMm,
    required double sheetWidthMm,
    required double sheetHeightMm,
    double minMarginMm = 5.0,
    double gapBetweenPhotosMm = 2.0,
  }) {
    final usableW = sheetWidthMm - (minMarginMm * 2.0);
    final usableH = sheetHeightMm - (minMarginMm * 2.0);

    if (usableW <= 0 || usableH <= 0 || photoWidthMm <= 0 || photoHeightMm <= 0) {
      return (
        cols: 0,
        rows: 0,
        totalFit: 0,
        isRotated: false,
        leftMarginMm: minMarginMm,
        topMarginMm: minMarginMm,
      );
    }

    // Layout A: Normal orientation
    final colsA = ((usableW + gapBetweenPhotosMm) / (photoWidthMm + gapBetweenPhotosMm)).floor();
    final rowsA = ((usableH + gapBetweenPhotosMm) / (photoHeightMm + gapBetweenPhotosMm)).floor();
    final fitA = (colsA > 0 && rowsA > 0) ? (colsA * rowsA) : 0;

    // Layout B: Rotated 90 degrees
    final colsB = ((usableW + gapBetweenPhotosMm) / (photoHeightMm + gapBetweenPhotosMm)).floor();
    final rowsB = ((usableH + gapBetweenPhotosMm) / (photoWidthMm + gapBetweenPhotosMm)).floor();
    final fitB = (colsB > 0 && rowsB > 0) ? (colsB * rowsB) : 0;

    if (fitB > fitA) {
      final totalGridW = colsB * photoHeightMm + (colsB - 1) * gapBetweenPhotosMm;
      final totalGridH = rowsB * photoWidthMm + (rowsB - 1) * gapBetweenPhotosMm;
      final leftM = (sheetWidthMm - totalGridW) / 2.0;
      final topM = (sheetHeightMm - totalGridH) / 2.0;

      return (
        cols: colsB,
        rows: rowsB,
        totalFit: fitB,
        isRotated: true,
        leftMarginMm: leftM,
        topMarginMm: topM,
      );
    } else {
      final totalGridW = colsA * photoWidthMm + (colsA - 1) * gapBetweenPhotosMm;
      final totalGridH = rowsA * photoHeightMm + (rowsA - 1) * gapBetweenPhotosMm;
      final leftM = (sheetWidthMm - totalGridW) / 2.0;
      final topM = (sheetHeightMm - totalGridH) / 2.0;

      return (
        cols: colsA,
        rows: rowsA,
        totalFit: fitA,
        isRotated: false,
        leftMarginMm: leftM,
        topMarginMm: topM,
      );
    }
  }

  // ==========================================================================
  // 4. Rigid & Thick Media Guardrails
  // ==========================================================================

  /// Validates media thickness and returns honest plain-language guidance
  /// in English and Spoken Sinhala.
  static ({
    bool isAllowed,
    double excessThicknessMm,
    String messageEn,
    String messageSi,
    RigidFeedPathType recommendedPath,
  }) validateRigidMediaThickness({
    required double mediaThicknessMm,
    required double printerMaxLimitMm,
  }) {
    final excess = mediaThicknessMm - printerMaxLimitMm;
    if (excess > 0.001) {
      return (
        isAllowed: false,
        excessThicknessMm: excess,
        messageEn:
            'Selected media thickness (${mediaThicknessMm.toStringAsFixed(2)} mm) exceeds printer hardware limit (${printerMaxLimitMm.toStringAsFixed(2)} mm) by ${excess.toStringAsFixed(2)} mm. Printing will cause a mechanical head strike.',
        messageSi:
            'තෝරාගත් කඩදාසියේ ඝනකම (${mediaThicknessMm.toStringAsFixed(2)} mm) ප්‍රින්ටරයේ උපරිම සීමාවට (${printerMaxLimitMm.toStringAsFixed(2)} mm) වඩා වැඩිය. ප්‍රින්ට් කළහොත් ප්‍රින්ට්හෙඩ් එක සිරවේ.',
        recommendedPath: RigidFeedPathType.rearStraightThrough,
      );
    }

    final path = mediaThicknessMm >= 0.5
        ? RigidFeedPathType.rearStraightThrough
        : RigidFeedPathType.rearVerticalStandard;

    return (
      isAllowed: true,
      excessThicknessMm: 0.0,
      messageEn:
          'Media thickness (${mediaThicknessMm.toStringAsFixed(2)} mm) is within safe limits. Use straight-through feed path.',
      messageSi:
          'කඩදාසියේ ඝනකම (${mediaThicknessMm.toStringAsFixed(2)} mm) ආරක්ෂිතයි. පිටුපස සෘජු මාර්ගයෙන් (Straight feed) ඇතුල් කරන්න.',
      recommendedPath: path,
    );
  }

  // ==========================================================================
  // 5. Dye-Sublimation Merchandise Mirror Geometry
  // ==========================================================================

  /// Applies horizontal mirror transformation: $(x' = \text{width} - x, y' = y)$.
  ///
  /// Sublimation printing MUST be horizontally mirrored so text and logos
  /// read correctly when heat-pressed face down onto mugs, shirts, and lanyards.
  static ({double mirroredX, double mirroredY}) calculateSublimationMirrorCoordinate({
    required double x,
    required double y,
    required double itemWidthMm,
  }) {
    return (mirroredX: itemWidthMm - x, mirroredY: y);
  }

  // ==========================================================================
  // 6. TM-Series POS Thermal Receipt Generation (ESC/POS & Driver Text)
  // ==========================================================================

  /// Generates clean, standard POS thermal receipt string formatted for
  /// 80mm (48 columns) or 58mm (32 columns) paper.
  static String formatShopCounterReceipt(ShopReceiptSpec spec) {
    final cols = spec.columnsCount;
    final buf = StringBuffer();

    // Center header helper
    String center(String s) {
      if (s.length >= cols) return s;
      final pad = (cols - s.length) ~/ 2;
      return ' ' * pad + s;
    }

    // Left/Right row helper
    String row(String left, String right) {
      final total = left.length + right.length;
      if (total >= cols) return '$left $right';
      final spaces = cols - total;
      return left + (' ' * spaces) + right;
    }

    final divider = '-' * cols;
    final doubleDivider = '=' * cols;

    buf.writeln(center(spec.shopName.toUpperCase()));
    buf.writeln(center(spec.shopAddress));
    buf.writeln(center('TEL: ${spec.shopPhone}'));
    buf.writeln(doubleDivider);

    buf.writeln(row('INVOICE: ${spec.invoiceNumber}', spec.timestamp.toIso8601String().substring(0, 16)));
    buf.writeln(row('CASHIER: ${spec.cashierName}', 'CUST: ${spec.customerName}'));
    buf.writeln(divider);

    buf.writeln(row('DESCRIPTION', 'AMOUNT (LKR)'));
    buf.writeln(divider);

    for (final item in spec.lineItems) {
      final desc = (item['description'] ?? 'Item').toString();
      final qty = (item['quantity'] ?? 1).toString();
      final price = (item['price'] ?? 0.0).toString();
      buf.writeln(row('$desc x$qty', 'Rs. $price'));
    }

    buf.writeln(divider);
    buf.writeln(row('SUBTOTAL:', 'Rs. ${spec.subtotal.toStringAsFixed(2)}'));
    if (spec.discountAmount > 0) {
      buf.writeln(row('DISCOUNT:', '-Rs. ${spec.discountAmount.toStringAsFixed(2)}'));
    }
    if (spec.taxAmount > 0) {
      buf.writeln(row('TAX / VAT:', '+Rs. ${spec.taxAmount.toStringAsFixed(2)}'));
    }
    buf.writeln(doubleDivider);
    buf.writeln(row('TOTAL PAID (${spec.paymentMethod.toUpperCase()}):', 'Rs. ${spec.grandTotal.toStringAsFixed(2)}'));
    buf.writeln(doubleDivider);

    buf.writeln(center('THANK YOU FOR YOUR BUSINESS!'));
    buf.writeln(center('Powering Sri Lankan Copy Centers'));
    buf.writeln('\n\n\n'); // Feed 3 lines for clean manual tear-off or auto-cut

    return buf.toString();
  }

  /// Converts receipt text into ESC/POS binary command stream for hardware
  /// direct thermal printing on Epson TM-T88, TM-T20, or TM-m30.
  ///
  /// Commands:
  /// - `ESC @`: Initialize printer
  /// - Standard ASCII payload
  /// - `GS V 0`: Full paper cut
  static List<int> generateEscPosReceiptBytes(ShopReceiptSpec spec) {
    final text = formatShopCounterReceipt(spec);
    final bytes = <int>[];

    // ESC @ (Initialize)
    bytes.addAll([0x1B, 0x40]);

    // Text payload (Latin/ASCII with space fallback)
    bytes.addAll(utf8.encode(text));

    // Optional Cash Drawer Kick (ESC p 0 25 250)
    if (spec.openCashDrawer) {
      bytes.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]);
    }

    // GS V 0 (Auto cut paper)
    if (spec.autoCutPaper) {
      bytes.addAll([0x1D, 0x56, 0x00]);
    }

    return bytes;
  }
}
