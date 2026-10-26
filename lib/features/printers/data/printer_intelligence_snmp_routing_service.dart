import 'dart:math' as math;

import '../domain/printer_routing_engine_models.dart';
import '../domain/snmp_printer_mib_models.dart';

/// Core service for Printer MIB SNMP table parsing, special value handling,
/// multi-printer aggregation, and intelligent job routing.
class PrinterIntelligenceSnmpRoutingService {
  // ==========================================================================
  // 1. SNMP Table Walker & Special Value Handler
  // ==========================================================================

  /// Parses raw SNMP OID table walk maps into [ParsedSnmpSupplyEntry] records.
  ///
  /// Strictly adheres to RFC 3805 / RFC 1759 rules for negative special values:
  /// - `rawLevel == -1`: "other" -> do NOT calculate percentage. Status: `presentOk`.
  /// - `rawLevel == -2`: "unknown" -> do NOT calculate percentage. Status: `notReported`.
  /// - `rawLevel == -3`: "some remaining" -> Status: `someRemaining`.
  /// - `rawMaxCapacity <= 0` or `-2`: "unknown capacity" -> do NOT calculate percentage.
  /// - Positive capacity and level -> calculate exact percentage: $(L / C) \times 100$.
  static ParsedSnmpSupplyEntry parseSnmpSupplyRow({
    required int index,
    required String description,
    required int rawLevel,
    required int rawMaxCapacity,
    bool isKnownEstimateModel = false,
  }) {
    final lower = description.toLowerCase();
    final isMaintBox = lower.contains('maintenance box') ||
        lower.contains('waste ink') ||
        lower.contains('waste toner') ||
        lower.contains('ink pad') ||
        lower.contains('maintenance cartridge');

    final colorHex = _extractChannelColorHex(description);

    // Negative / Special Value Handling
    if (rawLevel == -2) {
      return ParsedSnmpSupplyEntry(
        tableIndex: index,
        description: description,
        rawLevel: rawLevel,
        rawMaxCapacity: rawMaxCapacity,
        statusType: SnmpSupplyStatusType.notReported,
        calculatedPercentage: null,
        isMaintenanceBox: isMaintBox,
        isEstimate: isKnownEstimateModel,
        colorHex: colorHex,
      );
    }

    if (rawLevel == -1) {
      return ParsedSnmpSupplyEntry(
        tableIndex: index,
        description: description,
        rawLevel: rawLevel,
        rawMaxCapacity: rawMaxCapacity,
        statusType: SnmpSupplyStatusType.presentOk,
        calculatedPercentage: null,
        isMaintenanceBox: isMaintBox,
        isEstimate: isKnownEstimateModel,
        colorHex: colorHex,
      );
    }

    if (rawLevel == -3) {
      return ParsedSnmpSupplyEntry(
        tableIndex: index,
        description: description,
        rawLevel: rawLevel,
        rawMaxCapacity: rawMaxCapacity,
        statusType: SnmpSupplyStatusType.someRemaining,
        calculatedPercentage: null,
        isMaintenanceBox: isMaintBox,
        isEstimate: isKnownEstimateModel,
        colorHex: colorHex,
      );
    }

    // Invalid or unknown max capacity (-2 or <= 0)
    if (rawMaxCapacity <= 0 || rawMaxCapacity == -2) {
      final status = rawLevel > 0
          ? SnmpSupplyStatusType.someRemaining
          : SnmpSupplyStatusType.lowOrEmpty;

      return ParsedSnmpSupplyEntry(
        tableIndex: index,
        description: description,
        rawLevel: rawLevel,
        rawMaxCapacity: rawMaxCapacity,
        statusType: status,
        calculatedPercentage: null,
        isMaintenanceBox: isMaintBox,
        isEstimate: isKnownEstimateModel,
        colorHex: colorHex,
      );
    }

    // Normal calculation: level / maxCapacity * 100
    final pct = (rawLevel / rawMaxCapacity * 100.0).clamp(0.0, 100.0);
    final status = pct <= 10.0
        ? SnmpSupplyStatusType.lowOrEmpty
        : SnmpSupplyStatusType.percentage;

    return ParsedSnmpSupplyEntry(
      tableIndex: index,
      description: description,
      rawLevel: rawLevel,
      rawMaxCapacity: rawMaxCapacity,
      statusType: status,
      calculatedPercentage: pct,
      isMaintenanceBox: isMaintBox,
      isEstimate: isKnownEstimateModel,
      colorHex: colorHex,
    );
  }

  /// Maps supply descriptions to standard UI color swatches.
  static String _extractChannelColorHex(String desc) {
    final lower = desc.toLowerCase();
    if (lower.contains('cyan') && !lower.contains('light')) return '#00BCD4'; // Cyan
    if (lower.contains('light cyan') || lower.contains('photo cyan')) return '#80DEEA';
    if (lower.contains('magenta') && !lower.contains('light')) return '#E91E63'; // Magenta
    if (lower.contains('light magenta') || lower.contains('photo magenta')) return '#F48FB1';
    if (lower.contains('yellow')) return '#FDD835'; // Yellow
    if (lower.contains('photo black')) return '#37474F';
    if (lower.contains('matte black') || lower.contains('black') || lower.contains('key')) return '#212121';
    if (lower.contains('gray') || lower.contains('grey')) return '#9E9E9E';
    if (lower.contains('red')) return '#D32F2F';
    if (lower.contains('blue')) return '#1976D2';
    if (lower.contains('gloss optimizer') || lower.contains('clear')) return '#B2DFDB';
    if (lower.contains('maintenance box') || lower.contains('waste')) return '#78909C';
    return '#455A64';
  }

  // ==========================================================================
  // 2. Intelligent Multi-Printer Job Routing Engine
  // ==========================================================================

  /// Evaluates an incoming [JobRoutingRequest] against a fleet of [DashboardPrinterCardData].
  ///
  /// Routing Priorities:
  /// 1. Physical Hardware Specialty Requirements (CR80 ID card, CD/DVD, Roll, Sublimation, Rigid Board, Labels).
  /// 2. Target printer availability check (if offline or out of paper/ink -> propose reroute with confirmation).
  /// 3. Media Format constraints (A3 vs A4, Borderless).
  /// 4. High-volume document load balancing (send to least busy high-capacity printer).
  /// 5. B&W vs Color cost optimization.
  static RoutingDecisionResult evaluateJobRouting({
    required JobRoutingRequest job,
    required List<DashboardPrinterCardData> fleet,
  }) {
    if (fleet.isEmpty) {
      return const RoutingDecisionResult(
        selectedPrinterId: '',
        selectedPrinterName: 'No Printers Available',
        rationaleSentenceEn: 'No configured printers found on the network.',
        rationaleSentenceSi: 'ජාලයේ සක්‍රිය ප්‍රින්ටර් කිසිවක් හමු නොවීය.',
      );
    }

    // Step 1: Check Preferred Printer if specified
    DashboardPrinterCardData? preferredPrinter;
    if (job.preferredPrinterId != null) {
      preferredPrinter = fleet.cast<DashboardPrinterCardData?>().firstWhere(
            (p) => p?.id == job.preferredPrinterId,
            orElse: () => null,
          );
    }

    // Step 2: Physical Hardware Constraints for Specialty Jobs
    switch (job.classification) {
      case PrintJobClassification.pvcIdCard:
        final capable = fleet.where((p) => p.specialtyBadges.contains('ID Card') || p.specialtyBadges.contains('PVC')).toList();
        return _selectBestCapable(
          job: job,
          capablePrinters: capable,
          allFleet: fleet,
          preferred: preferredPrinter,
          featureNameEn: 'CR80 PVC ID Card Tray',
          featureNameSi: 'PVC ID කාඩ්පත් තැටිය',
        );

      case PrintJobClassification.cdDvdDisc:
        final capable = fleet.where((p) => p.specialtyBadges.contains('CD/DVD')).toList();
        return _selectBestCapable(
          job: job,
          capablePrinters: capable,
          allFleet: fleet,
          preferred: preferredPrinter,
          featureNameEn: 'Direct CD/DVD Disc Tray',
          featureNameSi: 'CD/DVD තැටි මුද්‍රණය',
        );

      case PrintJobClassification.rigidPosterboard:
        final capable = fleet.where((p) => p.specialtyBadges.contains('Rigid Board') || p.specialtyBadges.contains('Thick Media')).toList();
        return _selectBestCapable(
          job: job,
          capablePrinters: capable,
          allFleet: fleet,
          preferred: preferredPrinter,
          featureNameEn: 'Straight-Through Rigid Board Path (${job.mediaThicknessMm}mm)',
          featureNameSi: 'ඝන කඩදාසි සෘජු මාර්ගය',
        );

      case PrintJobClassification.rollBanner:
        final capable = fleet.where((p) => p.specialtyBadges.contains('Roll Cutter') || p.specialtyBadges.contains('Roll')).toList();
        return _selectBestCapable(
          job: job,
          capablePrinters: capable,
          allFleet: fleet,
          preferred: preferredPrinter,
          featureNameEn: 'Roll Media & Rotary Cutter',
          featureNameSi: 'රෝල් කඩදාසි හා කටරය',
        );

      case PrintJobClassification.dyeSublimationTransfer:
        final capable = fleet.where((p) => p.specialtyBadges.contains('Sublimation')).toList();
        return _selectBestCapable(
          job: job,
          capablePrinters: capable,
          allFleet: fleet,
          preferred: preferredPrinter,
          featureNameEn: 'Dye-Sublimation Transfer & Auto-Mirror',
          featureNameSi: 'සබ්ලිමේෂන් හීට් ට්‍රාන්ස්ෆර්',
        );

      case PrintJobClassification.colorLabelRoll:
        final capable = fleet.where((p) => p.specialtyBadges.contains('Labels') || p.specialtyBadges.contains('Label')).toList();
        return _selectBestCapable(
          job: job,
          capablePrinters: capable,
          allFleet: fleet,
          preferred: preferredPrinter,
          featureNameEn: 'ColorWorks On-Demand Labeling',
          featureNameSi: 'ColorWorks ලේබල් මුද්‍රණය',
        );

      // Step 3: Standard Photo / Document Optimization
      case PrintJobClassification.photoBorderless:
        // Photo printer with borderless support
        var photoCapable = fleet.where((p) => p.specialtyBadges.contains('Borderless')).toList();
        if (job.paperSize == 'A3' || job.paperSize == 'A3+') {
          photoCapable = photoCapable.where((p) => p.name.contains('A3') || p.modelName.contains('L180') || p.modelName.contains('L8180') || p.modelName.contains('SC-P')).toList();
        }
        return _selectBestCapable(
          job: job,
          capablePrinters: photoCapable.isNotEmpty ? photoCapable : fleet,
          allFleet: fleet,
          preferred: preferredPrinter,
          featureNameEn: 'Borderless Photo Printing (${job.paperSize})',
          featureNameSi: '${job.paperSize} පාරිභෝගික ඡායාරූප මුද්‍රණය',
        );

      case PrintJobClassification.documentTextMono:
        // Optimize for B&W: dedicated monochrome printer or lowest queue
        final monoCapable = fleet.where((p) => p.modelName.startsWith('M') || p.name.contains('Mono')).toList();
        final targets = monoCapable.isNotEmpty ? monoCapable : fleet;
        return _selectBestByQueueAndSupplies(
          job: job,
          candidates: targets,
          preferred: preferredPrinter,
          reasonEn: 'Sent to the fastest monochrome printer for lowest per-page cost.',
          reasonSi: 'පිටුවකට අඩුම පිරිවැයක් සහිත අධිවේගී කළු-සුදු ප්‍රින්ටරය වෙත යවන ලදී.',
        );

      case PrintJobClassification.documentColor:
      case PrintJobClassification.passportPhotoSheet:
        // Standard color document or passport grid
        return _selectBestByQueueAndSupplies(
          job: job,
          candidates: fleet,
          preferred: preferredPrinter,
          reasonEn: 'Sent to ${preferredPrinter?.name ?? fleet.first.name} (Ready with lowest queue).',
          reasonSi: '${preferredPrinter?.name ?? fleet.first.name} වෙත යවන ලදී (අවම පෝලිමක් සහිතයි).',
        );
    }
  }

  /// Selects the best printer among hardware-capable candidates, checking
  /// availability and failover conditions.
  static RoutingDecisionResult _selectBestCapable({
    required JobRoutingRequest job,
    required List<DashboardPrinterCardData> capablePrinters,
    required List<DashboardPrinterCardData> allFleet,
    DashboardPrinterCardData? preferred,
    required String featureNameEn,
    required String featureNameSi,
  }) {
    if (capablePrinters.isEmpty) {
      return RoutingDecisionResult(
        selectedPrinterId: allFleet.first.id,
        selectedPrinterName: allFleet.first.name,
        rationaleSentenceEn: 'Warning: No printers report $featureNameEn support. Manual verification required.',
        rationaleSentenceSi: 'අවවාදයයි: $featureNameSi සඳහා සහාය දක්වන ප්‍රින්ටර් හමු නොවීය.',
        requiresOperatorConfirmation: true,
        confirmationPromptEn: 'No connected printer reports native support for $featureNameEn. Proceed anyway?',
        confirmationPromptSi: '$featureNameSi සඳහා කිසිදු ප්‍රින්ටරයක් වාර්තා වී නැත. ඉදිරියට යන්නද?',
      );
    }

    // Check if preferred printer is capable and ready
    if (preferred != null && capablePrinters.any((p) => p.id == preferred.id)) {
      if (preferred.isAvailableForJobs && !preferred.hasLowSupplyAlert) {
        return RoutingDecisionResult(
          selectedPrinterId: preferred.id,
          selectedPrinterName: preferred.name,
          wasReroutedFromPreferred: false,
          rationaleSentenceEn: 'Sent to ${preferred.name} as requested ($featureNameEn).',
          rationaleSentenceSi: 'ඉල්ලීම පරිදි ${preferred.name} වෙත යවන ලදී ($featureNameSi).',
        );
      } else {
        // Preferred printer is offline or low on supplies -> Propose reroute!
        final alternative = capablePrinters.firstWhere(
          (p) => p.id != preferred.id && p.isAvailableForJobs && !p.hasLowSupplyAlert,
          orElse: () => capablePrinters.firstWhere((p) => p.id != preferred.id, orElse: () => preferred),
        );

        if (alternative.id != preferred.id) {
          final isOffline = preferred.state == FleetPrinterState.offline;
          final causeEn = isOffline ? 'is offline' : 'has a low supply / paper warning';
          final causeSi = isOffline ? 'විසන්ධි වී ඇත' : 'තීන්ත හෝ කඩදාසි අවසන් වී ඇත';

          return RoutingDecisionResult(
            selectedPrinterId: alternative.id,
            selectedPrinterName: alternative.name,
            wasReroutedFromPreferred: true,
            originalPreferredPrinterId: preferred.id,
            rationaleSentenceEn:
                'Rerouted to ${alternative.name} because preferred printer ${preferred.name} $causeEn.',
            rationaleSentenceSi:
                'මූලික ප්‍රින්ටරය (${preferred.name}) $causeSi බැවින් කාර්යය ${alternative.name} වෙත මාරු කිරීමට යෝජනා කරයි.',
            requiresOperatorConfirmation: true,
            confirmationPromptEn:
                'Target printer ${preferred.name} $causeEn. Move job to ${alternative.name} ($featureNameEn)?',
            confirmationPromptSi:
                'ප්‍රින්ටරය (${preferred.name}) $causeSi. මෙම කාර්යය ${alternative.name} වෙත මාරු කරන්නද?',
          );
        }
      }
    }

    // Default to best capable by lowest queue
    capablePrinters.sort((a, b) => a.activeQueueLength.compareTo(b.activeQueueLength));
    final best = capablePrinters.first;

    return RoutingDecisionResult(
      selectedPrinterId: best.id,
      selectedPrinterName: best.name,
      wasReroutedFromPreferred: false,
      rationaleSentenceEn: 'Sent to ${best.name} because it supports $featureNameEn.',
      rationaleSentenceSi: '$featureNameSi සහාය දක්වන බැවින් ${best.name} වෙත යවන ලදී.',
    );
  }

  /// Selects best candidate printer based on queue load balancing and supply levels.
  static RoutingDecisionResult _selectBestByQueueAndSupplies({
    required JobRoutingRequest job,
    required List<DashboardPrinterCardData> candidates,
    DashboardPrinterCardData? preferred,
    required String reasonEn,
    required String reasonSi,
  }) {
    if (candidates.isEmpty) {
      return const RoutingDecisionResult(
        selectedPrinterId: '',
        selectedPrinterName: '',
        rationaleSentenceEn: 'No candidates available.',
        rationaleSentenceSi: 'ප්‍රින්ටර් කිසිවක් හමු නොවීය.',
      );
    }

    // If preferred is available, use it
    if (preferred != null && preferred.isAvailableForJobs && !preferred.hasLowSupplyAlert) {
      return RoutingDecisionResult(
        selectedPrinterId: preferred.id,
        selectedPrinterName: preferred.name,
        rationaleSentenceEn: 'Sent to selected printer ${preferred.name}.',
        rationaleSentenceSi: 'තෝරාගත් ${preferred.name} ප්‍රින්ටරය වෙත යවන ලදී.',
      );
    }

    // Sort by:
    // 1. Availability (Ready > Error/Offline)
    // 2. Supply warnings (Healthy > Low Supplies)
    // 3. Queue length (Shortest first)
    final sorted = List<DashboardPrinterCardData>.from(candidates);
    sorted.sort((a, b) {
      if (a.isAvailableForJobs != b.isAvailableForJobs) {
        return a.isAvailableForJobs ? -1 : 1;
      }
      if (a.hasLowSupplyAlert != b.hasLowSupplyAlert) {
        return a.hasLowSupplyAlert ? 1 : -1;
      }
      return a.activeQueueLength.compareTo(b.activeQueueLength);
    });

    final chosen = sorted.first;

    // Failover detection if preferred was unavailable
    if (preferred != null && chosen.id != preferred.id) {
      return RoutingDecisionResult(
        selectedPrinterId: chosen.id,
        selectedPrinterName: chosen.name,
        wasReroutedFromPreferred: true,
        originalPreferredPrinterId: preferred.id,
        rationaleSentenceEn:
            'Moved from ${preferred.name} to ${chosen.name} (Ready with lowest queue).',
        rationaleSentenceSi:
            '${preferred.name} කාර්යබහුල/විසන්ධි බැවින් අඩුම පෝලිමක් ඇති ${chosen.name} වෙත මාරු කරන ලදී.',
        requiresOperatorConfirmation: true,
        confirmationPromptEn:
            'Target printer ${preferred.name} is unavailable. Send to ${chosen.name} instead?',
        confirmationPromptSi:
            '${preferred.name} ප්‍රින්ටරය භාවිත කළ නොහැක. ${chosen.name} වෙත යවන්නද?',
      );
    }

    return RoutingDecisionResult(
      selectedPrinterId: chosen.id,
      selectedPrinterName: chosen.name,
      rationaleSentenceEn: reasonEn,
      rationaleSentenceSi: reasonSi,
    );
  }
}
