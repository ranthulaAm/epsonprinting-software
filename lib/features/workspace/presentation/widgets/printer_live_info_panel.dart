import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../services/printer/epson_robust_support_service.dart';
import '../../../../services/printer/models/printer_intelligence_models.dart';
import '../../../../services/printer/models/printer_models.dart';
import '../../../../services/printer/printer_intelligence_service.dart';
import '../../../printers/presentation/widgets/epson_diagnostics_and_matrix_dialogs.dart';

/// Displays live multi-source printer telemetry on the Print Screen whenever a
/// printer is selected, with smooth animated transitions and strict provenance
/// badges (`IPP`, `SNMP`, `Win32 Spooler`, `Consented Web Config`, `Epson Profile`).
///
/// Never guesses unreported values: any attribute not reported by the printer
/// displays `"Not reported by this printer"`.
class PrinterLiveInfoPanel extends ConsumerStatefulWidget {
  final PrinterLiveIntelligence? intelligence;
  final SmartPrintValidationReport? validationReport;
  final bool isLoading;
  final bool isSinhala;
  final String selectedPaperSize;
  final VoidCallback onRefreshRequested;
  final ValueChanged<bool> onWebConfigConsentChanged;
  final ValueChanged<SmartPrintValidationFix> onApplyAutoFix;
  final VoidCallback onOpenManualDuplexAssistant;
  final bool initiallyExpanded;

  const PrinterLiveInfoPanel({
    super.key,
    required this.intelligence,
    required this.validationReport,
    required this.isLoading,
    required this.isSinhala,
    required this.selectedPaperSize,
    required this.onRefreshRequested,
    required this.onWebConfigConsentChanged,
    required this.onApplyAutoFix,
    required this.onOpenManualDuplexAssistant,
    this.initiallyExpanded = false,
  });

  @override
  ConsumerState<PrinterLiveInfoPanel> createState() =>
      _PrinterLiveInfoPanelState();
}

class _PrinterLiveInfoPanelState extends ConsumerState<PrinterLiveInfoPanel> {
  late bool _isExpanded;

  bool get isSinhala => widget.isSinhala;
  bool get isLoading => widget.isLoading;
  VoidCallback get onRefreshRequested => widget.onRefreshRequested;
  ValueChanged<bool> get onWebConfigConsentChanged =>
      widget.onWebConfigConsentChanged;
  ValueChanged<SmartPrintValidationFix> get onApplyAutoFix =>
      widget.onApplyAutoFix;
  VoidCallback get onOpenManualDuplexAssistant =>
      widget.onOpenManualDuplexAssistant;
  String get selectedPaperSize => widget.selectedPaperSize;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ref.watch(reduceMotionProvider);
    final duration = AppMotion.duration(
      AppMotion.mediumDuration,
      reduceMotion: reduceMotion,
    );

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.standardCurve,
      switchOutCurve: AppMotion.standardCurve,
      child: widget.intelligence == null
          ? _buildLoadingOrEmptyCard(context)
          : _buildPopulatedPanel(context, ref, widget.intelligence!, duration),
    );
  }

  Widget _buildLoadingOrEmptyCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('printer_info_empty'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.isSinhala
                    ? 'ප්‍රින්ටර් එකේ සජීවී තොරතුරු ලබා ගනිමින් පවතී...'
                    : 'Reading live printer intelligence...',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopulatedPanel(
    BuildContext context,
    WidgetRef ref,
    PrinterLiveIntelligence intel,
    Duration animDuration,
  ) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      key: ValueKey('printer_info_${intel.printerId}'),
      duration: animDuration,
      curve: AppMotion.standardCurve,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. STATUS HEADER & PLAIN-LANGUAGE PROBLEMS
          _buildStatusHeader(context, intel),

          if (intel.activeProblems.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildProblemsList(context, intel.activeProblems),
          ],

          // COMPACT VIEW: Mini supply strip + loaded paper & duplex summary + expand toggle
          if (!_isExpanded) ...[
            const SizedBox(height: 8),
            _buildCompactSupplyStrip(context, intel),
            const SizedBox(height: 6),
            _buildCompactPaperSummary(context, intel),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _isExpanded = true),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isSinhala ? 'තවත් විස්තර බලන්න' : 'Show more details',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // EXPANDED VIEW: Full diagnostics, trays, capabilities, maintenance
            // SMART PRINT VALIDATION ("Fix it for me")
            if (widget.validationReport != null &&
                widget.validationReport!.checks.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSmartValidationSection(context, widget.validationReport!),
            ],

            const Divider(height: 20),

            // 2. SUPPLY LEVELS (Ink / Toner / Maintenance Box / Waste Ink Pad)
            _buildSupplyLevelsSection(context, intel),

            const Divider(height: 20),

            // 3. PAPER & TRAYS ("Loaded now" / "Supported but not loaded" / "Not supported")
            _buildPaperAndTraysSection(context, intel),

            const Divider(height: 20),

            // 4. CAPABILITIES BADGES
            _buildCapabilitiesBadgesSection(context, intel),

            const Divider(height: 20),

            // 5. MAINTENANCE INFO & CONSENSUAL WEB CONFIG FALLBACK
            _buildMaintenanceSection(context, ref, intel),

            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _isExpanded = false),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isSinhala ? 'විස්තර සඟවන්න' : 'Hide details',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactSupplyStrip(
    BuildContext context,
    PrinterLiveIntelligence intel,
  ) {
    final theme = Theme.of(context);
    final supplies = intel.supplies;
    if (supplies.isEmpty) {
      return Text(
        widget.isSinhala
            ? 'තීන්ත මට්ටම වාර්තා වී නැත'
            : 'Supply levels not reported',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: supplies.take(4).map((s) {
            final color = s.colorCode != null
                ? Color(s.colorCode!)
                : theme.colorScheme.primary;
            final pct = s.levelPercent;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct != null ? (pct / 100.0).clamp(0.0, 1.0) : 0.5,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pct != null ? '$pct%' : (s.isLow ? 'Low' : 'OK'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: s.isLow
                            ? const Color(0xFFD97706)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompactPaperSummary(
    BuildContext context,
    PrinterLiveIntelligence intel,
  ) {
    final theme = Theme.of(context);
    final loadedTrays = intel.inputTrays
        .where((t) => t.isLoadedNow && t.currentLoadedPaperSize != null)
        .toList();
    final paperText = loadedTrays.isNotEmpty
        ? loadedTrays.map((t) => t.currentLoadedPaperSize).join(', ')
        : (intel.supportedPaperSizes.isNotEmpty
            ? intel.supportedPaperSizes.first
            : 'A4');
    final duplexText = intel.duplexMode == DuplexCapability.automatic
        ? (widget.isSinhala ? 'දෙපැත්තම (Auto)' : 'Auto Duplex')
        : (widget.isSinhala ? 'එක් පැත්තක්' : 'Single-sided');

    return Row(
      children: [
        Icon(
          Icons.description_outlined,
          size: 14,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: 4),
        Text(
          paperText,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text('•', style: TextStyle(color: theme.colorScheme.outline)),
        const SizedBox(width: 8),
        Icon(
          Icons.sync_alt_rounded,
          size: 14,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: 4),
        Text(
          duplexText,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 1. Status Header
  // ===========================================================================

  Widget _buildStatusHeader(
    BuildContext context,
    PrinterLiveIntelligence intel,
  ) {
    final theme = Theme.of(context);
    final stateVal = intel.printerState.value ?? LivePrinterState.ready;
    final stateLabel = isSinhala ? stateVal.labelSi : stateVal.labelEn;

    final connectionText = switch (intel.connectionType) {
      PrinterConnectionType.network => intel.ipAddress != null
          ? (isSinhala
              ? 'ජාලය (Network • ${intel.ipAddress})'
              : 'Network (${intel.ipAddress})')
          : (isSinhala ? 'ජාලය (Network)' : 'Network'),
      PrinterConnectionType.usb => isSinhala ? 'USB කේබල්' : 'USB Direct',
      PrinterConnectionType.virtual =>
        isSinhala ? 'අතථ්‍ය (Virtual)' : 'Virtual',
      PrinterConnectionType.local => isSinhala ? 'දේශීය (Local)' : 'Local Port',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: stateVal.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(stateVal.icon, color: stateVal.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intel.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${intel.modelName} • $connectionText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (intel.matchedProfile != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      intel.matchedProfile!.familyName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: isLoading ? null : onRefreshRequested,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              tooltip: isSinhala
                  ? 'සජීවී තත්ත්වය යාවත්කාලීන කරන්න'
                  : 'Refresh live printer status',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: stateVal.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: stateVal.color.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(stateVal.icon, size: 13, color: stateVal.color),
                  const SizedBox(width: 4),
                  Text(
                    stateLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: stateVal.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _buildProvenanceChip(
              context,
              source: intel.printerState.source,
              confidence: intel.printerState.confidence,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProblemsList(
    BuildContext context,
    List<PlainLanguagePrinterProblem> problems,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: problems.map((p) {
        final color = p.isHardStopBlockingError
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                p.isHardStopBlockingError
                    ? Icons.error_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSinhala ? p.titleSi : p.titleEn,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSinhala ? p.detailSi : p.detailEn,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // Smart Pre-Print Validation & "Fix it for me"
  // ===========================================================================

  Widget _buildSmartValidationSection(
    BuildContext context,
    SmartPrintValidationReport report,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isSinhala
                      ? 'මුද්‍රණයට පෙර ස්වයංක්‍රීය පරීක්ෂාව (Smart Print Check)'
                      : 'Smart Print Validation',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...report.checks.map((check) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        check.severity.icon,
                        size: 16,
                        color: check.severity.color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isSinhala ? check.messageSi : check.messageEn,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (check.autoFix != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          if (check.autoFix!.actionKind ==
                              SmartFixActionKind
                                  .switchToManualDuplexAssistant) {
                            onOpenManualDuplexAssistant();
                          } else {
                            onApplyAutoFix(check.autoFix!);
                          }
                        },
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
                        label: Text(
                          isSinhala
                              ? check.autoFix!.buttonLabelSi
                              : check.autoFix!.buttonLabelEn,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. Supply Levels
  // ===========================================================================

  Widget _buildSupplyLevelsSection(
    BuildContext context,
    PrinterLiveIntelligence intel,
  ) {
    final theme = Theme.of(context);
    final supplyLabel = isSinhala
        ? intel.primarySupplyLabel.labelSi
        : intel.primarySupplyLabel.labelEn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isSinhala
                    ? '$supplyLabel මට්ටම් (Supply Levels)'
                    : '$supplyLabel & Maintenance Levels',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _buildProvenanceChip(
              context,
              source: intel.supplies.source,
              confidence: intel.supplies.confidence,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!intel.supplies.isReported ||
            intel.supplies.value == null ||
            intel.supplies.value!.isEmpty)
          _buildNotReportedRow(
            context,
            label: isSinhala
                ? 'තීන්ත / ටෝනර් මට්ටම්'
                : '${intel.primarySupplyLabel.labelEn} levels',
          )
        else
          Column(
            children: intel.supplies.value!
                .map((m) => _buildSupplyBarRow(context, m))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildSupplyBarRow(BuildContext context, SupplyMarkerInfo marker) {
    final theme = Theme.of(context);
    final hasExactPercent =
        marker.levelPercent.isReported && marker.levelPercent.value != null;
    final pct = hasExactPercent ? marker.levelPercent.value!.clamp(0, 100) : 0;

    final String statusRightText;
    if (hasExactPercent) {
      statusRightText = '$pct%';
    } else if (marker.qualitativeStatus.isReported &&
        marker.qualitativeStatus.value != null) {
      statusRightText = isSinhala
          ? marker.qualitativeStatus.value!.labelSi
          : marker.qualitativeStatus.value!.labelEn;
    } else {
      statusRightText =
          isSinhala ? kNotReportedByPrinterSi : kNotReportedByPrinterEn;
    }

    final barFraction = hasExactPercent
        ? (pct / 100.0)
        : (marker.qualitativeStatus.value == QualitativeSupplyStatus.ok
            ? 1.0
            : (marker.qualitativeStatus.value == QualitativeSupplyStatus.low
                ? 0.18
                : 0.0));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: marker.displayColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  marker.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (marker.isLow || marker.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: marker.isEmpty
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFD97706),
                  ),
                ),
              Text(
                statusRightText,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: marker.isEmpty
                      ? const Color(0xFFDC2626)
                      : (marker.isLow
                          ? const Color(0xFFD97706)
                          : theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 7,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              valueColor: AlwaysStoppedAnimation<Color>(marker.displayColor),
            ),
          ),
          if (marker.estimatedPagesRemaining.isReported &&
              marker.estimatedPagesRemaining.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                isSinhala
                    ? '~ පිටු ${marker.estimatedPagesRemaining.value} ඉතිරිව ඇත (ඇස්තමේන්තුවකි / estimate)'
                    : '~${marker.estimatedPagesRemaining.value} pages remaining (estimate)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. Paper & Trays
  // ===========================================================================

  Widget _buildPaperAndTraysSection(
    BuildContext context,
    PrinterLiveIntelligence intel,
  ) {
    final theme = Theme.of(context);
    final selectedEval = intel.evaluatePaperSize(selectedPaperSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.layers_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isSinhala
                    ? 'කඩදාසි තැටි සහ ප්‍රමාණ (Paper & Trays)'
                    : 'Paper Trays & Media',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _buildProvenanceChip(
              context,
              source: intel.trays.source,
              confidence: intel.trays.confidence,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Selected paper size evaluation badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selectedEval.badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedEval.badgeColor.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 15,
                color: selectedEval.badgeColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isSinhala
                      ? 'තෝරාගත් ප්‍රමාණය ($selectedPaperSize): ${selectedEval.labelSi}'
                      : 'Selected size ($selectedPaperSize): ${selectedEval.labelEn}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selectedEval.badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Per-tray breakdown
        if (!intel.trays.isReported ||
            intel.trays.value == null ||
            intel.trays.value!.isEmpty)
          _buildNotReportedRow(
            context,
            label: isSinhala ? 'කඩදාසි තැටි' : 'Input Trays',
          )
        else
          ...intel.trays.value!.map((tray) {
            final sizeStr = tray.loadedPaperSize.formatOrNotReported(
              (v) => v,
              isSinhala: isSinhala,
            );
            final typeStr = tray.loadedMediaType.formatOrNotReported(
              (v) => v,
              isSinhala: isSinhala,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inbox_rounded, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${tray.trayName}: $sizeStr • $typeStr',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tray.availability.badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSinhala
                          ? tray.availability.labelSi
                          : tray.availability.labelEn,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: tray.availability.badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 6),
        Text(
          isSinhala
              ? 'සහාය දක්වන ප්‍රමාණ: ${intel.supportedPaperSizes.formatOrNotReported((l) => l.join(", "), isSinhala: true)}'
              : 'Supported sizes: ${intel.supportedPaperSizes.formatOrNotReported((l) => l.join(", "))}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isSinhala
              ? 'කඩදාසි වර්ග: ${intel.supportedMediaTypes.formatOrNotReported((l) => l.join(", "), isSinhala: true)}'
              : 'Media types: ${intel.supportedMediaTypes.formatOrNotReported((l) => l.join(", "))}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. Capabilities Badges
  // ===========================================================================

  Widget _buildCapabilitiesBadgesSection(
    BuildContext context,
    PrinterLiveIntelligence intel,
  ) {
    final theme = Theme.of(context);

    final duplexText = intel.duplexSupport.formatOrNotReported(
      (mode) => isSinhala ? mode.labelSi : mode.labelEn,
      isSinhala: isSinhala,
    );
    final colorText = intel.supportsColor.formatOrNotReported(
      (c) => c
          ? (isSinhala ? 'වර්ණ (Color)' : 'Color')
          : (isSinhala ? 'කළු-සුදු පමණි (Mono)' : 'Monochrome'),
      isSinhala: isSinhala,
    );
    final borderlessText = intel.supportsBorderless.formatOrNotReported(
      (b) => b
          ? (isSinhala ? 'දාර රහිත (Borderless)' : 'Borderless Supported')
          : (isSinhala ? 'සාමාන්‍ය දාර පමණි' : 'Standard Margins Only'),
      isSinhala: isSinhala,
    );
    final dpiText = intel.maxResolutionDpi.formatOrNotReported(
      (dpi) => 'Max $dpi',
      isSinhala: isSinhala,
    );
    final orientText = intel.supportedOrientations.formatOrNotReported(
      (list) => list.join(' / '),
      isSinhala: isSinhala,
    );
    final binsText = intel.supportedOutputBins.formatOrNotReported(
      (bins) => bins.join(', '),
      isSinhala: isSinhala,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isSinhala
              ? 'මුද්‍රණ හැකියාවන් (Capabilities)'
              : 'Capabilities & Hardware Features',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildCapBadge(context, Icons.swap_horiz_rounded, duplexText),
            _buildCapBadge(context, Icons.palette_outlined, colorText),
            _buildCapBadge(context, Icons.crop_free_rounded, borderlessText),
            _buildCapBadge(context, Icons.hd_outlined, dpiText),
            _buildCapBadge(
                context, Icons.screen_rotation_outlined, orientText),
            _buildCapBadge(
              context,
              Icons.output_rounded,
              isSinhala ? 'පිටවුම් තැටිය: $binsText' : 'Output bin: $binsText',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCapBadge(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. Maintenance Info & Consented Epson Web Config Fallback
  // ===========================================================================

  Widget _buildMaintenanceSection(
    BuildContext context,
    WidgetRef ref,
    PrinterLiveIntelligence intel,
  ) {
    final theme = Theme.of(context);

    final pagesText = intel.lifetimePageCount.formatOrNotReported(
      (count) => isSinhala ? 'පිටු $count' : '$count pages',
      isSinhala: isSinhala,
    );
    final fwText = intel.firmwareVersion.formatOrNotReported(
      (fw) => fw,
      isSinhala: isSinhala,
    );
    final maintBoxText = intel.maintenanceBoxStatus.formatOrNotReported(
      (status) => status,
      isSinhala: isSinhala,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isSinhala
              ? 'නඩත්තු තොරතුරු (Maintenance & Counters)'
              : 'Maintenance & Hardware Counters',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        _buildKeyValLine(
          context,
          label: isSinhala ? 'මුළු මුද්‍රිත පිටු ගණන' : 'Total page counter',
          value: pagesText,
          source: intel.lifetimePageCount.source,
        ),
        _buildKeyValLine(
          context,
          label: isSinhala ? 'ස්ථිරාංග අනුවාදය (Firmware)' : 'Firmware version',
          value: fwText,
          source: intel.firmwareVersion.source,
        ),
        _buildKeyValLine(
          context,
          label:
              isSinhala ? 'නඩත්තු කොටුව (Maintenance Box)' : 'Maintenance box',
          value: maintBoxText,
          source: intel.maintenanceBoxStatus.source,
        ),
        if (intel.matchedProfile != null &&
            intel.matchedProfile!.quirks.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    intel.matchedProfile!.quirks.first,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (intel.connectionType == PrinterConnectionType.network) ...[
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              isSinhala
                  ? 'අවශ්‍ය වූ විට මුද්‍රණ යන්ත්‍රයේ වෙබ් පිටුවෙන් (Epson Web Config) තොරතුරු කියවීමට අවසර දෙන්න'
                  : 'Allow reading printer built-in web status page (Epson Web Config fallback)',
              style: theme.textTheme.bodySmall,
            ),
            value: intel.userConsentedWebConfig,
            onChanged: onWebConfigConsentChanged,
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => PrinterDiagnosticsDialog.copyAndShow(
                context,
                ref: ref,
                intelligence: intel,
                isSinhala: isSinhala,
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 15),
              label: Text(
                isSinhala
                    ? 'පරීක්ෂණ වාර්තාව පිටපත් කරන්න (Diagnostics)'
                    : 'Copy printer diagnostics',
                style: const TextStyle(fontSize: 11.5),
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final service = ref.read(printerIntelligenceServiceProvider);
                final currentConfig = service.getAuthConfig(intel.printerId);
                showDialog<void>(
                  context: context,
                  builder: (_) => PrinterNetworkAuthConfigDialog(
                    initialConfig: currentConfig,
                    isSinhala: isSinhala,
                    onSaved: (updated) {
                      service.setAuthConfig(updated);
                      onRefreshRequested();
                    },
                  ),
                );
              },
              icon: const Icon(Icons.vpn_key_outlined, size: 15),
              label: Text(
                isSinhala
                    ? 'SNMP / IPP සහ IP සැකසුම්'
                    : 'SNMP / IPP Auth & IP',
                style: const TextStyle(fontSize: 11.5),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => EpsonSafeMaintenanceConfirmDialog(
                    commandType: SafeMaintenanceCommandType.nozzleCheckPattern,
                    intelligence: intel,
                    isSinhala: isSinhala,
                  ),
                );
              },
              icon: const Icon(Icons.grid_on_rounded, size: 15),
              label: Text(
                isSinhala ? 'Nozzle Check' : 'Nozzle Check',
                style: const TextStyle(fontSize: 11.5),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => EpsonSafeMaintenanceConfirmDialog(
                    commandType:
                        SafeMaintenanceCommandType.standardHeadCleaning,
                    intelligence: intel,
                    isSinhala: isSinhala,
                  ),
                );
              },
              icon: const Icon(Icons.cleaning_services_outlined, size: 15),
              label: Text(
                isSinhala
                    ? 'Head Cleaning (තහවුරු කරන්න)'
                    : 'Head Cleaning (Confirm)',
                style: const TextStyle(fontSize: 11.5),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => EpsonTestMatrixAndDevModeDialog(
                    isSinhala: isSinhala,
                  ),
                );
              },
              icon: const Icon(Icons.fact_check_outlined, size: 15),
              label: Text(
                isSinhala
                    ? 'Epson පරීක්ෂණ වගුව (Test Matrix)'
                    : 'Epson Test Matrix & DEVMODE',
                style: const TextStyle(fontSize: 11.5),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyValLine(
    BuildContext context, {
    required String label,
    required String value,
    required PrinterTelemetrySource source,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotReportedRow(BuildContext context, {required String label}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label: ${isSinhala ? kNotReportedByPrinterSi : kNotReportedByPrinterEn}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvenanceChip(
    BuildContext context, {
    required PrinterTelemetrySource source,
    required TelemetryConfidence confidence,
  }) {
    final theme = Theme.of(context);
    final label = isSinhala ? source.sinhalaLabel : source.shortLabel;
    final tooltip = isSinhala ? confidence.labelSi : confidence.labelEn;

    return Tooltip(
      message: '$label • $tooltip',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
