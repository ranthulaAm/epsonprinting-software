import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/widgets/desktop_widgets.dart';
import '../../../../services/printer/capability_discovery_service.dart';
import '../../../../services/printer/models/printer_intelligence_models.dart';
import '../../../../services/printer/models/printer_models.dart';
import '../../domain/print_queue_item.dart';
import '../../domain/print_settings_models.dart';
import '../../domain/resolution_system_models.dart';
import '../../domain/tone_and_ink_models.dart';
import 'manual_duplex_assistant_dialog.dart';
import 'photo_size_helper_dialog.dart';
import 'printer_abilities_dialog.dart';
import 'printer_live_info_panel.dart';
import 'resample_preview_dialog.dart';
import 'test_pattern_dialog.dart';
import 'tone_and_ink_panel.dart';

/// Multi-tier print settings panel adhering to Windows 11 desktop styling,
/// with Basic, Standard, and Professional tiers, capability filtering,
/// live sticky plain-language summary, and media-first auto-fixes.
class PrintSettingsPanel extends ConsumerStatefulWidget {
  final UnifiedPrintSettings settings;
  final DiscoveredCapabilities capabilities;
  final PrinterLiveIntelligence? liveIntelligence;
  final SmartPrintValidationReport? validationReport;
  final List<PrinterDevice> printers;
  final String activePrinterName;
  final bool isLoadingIntelligence;
  final int totalPages;
  final bool canPrint;
  final AppStrings strings;
  final ValueChanged<UnifiedPrintSettings> onSettingsChanged;
  final ValueChanged<String> onPrinterSelected;
  final VoidCallback onPrintPressed;
  final VoidCallback onRefreshIntelligence;
  final VoidCallback onOpenManualDuplexAssistant;

  const PrintSettingsPanel({
    super.key,
    required this.settings,
    required this.capabilities,
    required this.liveIntelligence,
    required this.validationReport,
    required this.printers,
    required this.activePrinterName,
    required this.isLoadingIntelligence,
    required this.totalPages,
    required this.canPrint,
    required this.strings,
    required this.onSettingsChanged,
    required this.onPrinterSelected,
    required this.onPrintPressed,
    required this.onRefreshIntelligence,
    required this.onOpenManualDuplexAssistant,
  });

  @override
  ConsumerState<PrintSettingsPanel> createState() => _PrintSettingsPanelState();
}

class _PrintSettingsPanelState extends ConsumerState<PrintSettingsPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyChangedSettings = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(String term) {
    if (_searchQuery.isEmpty) return true;
    return term.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final palette = DesktopTheme.of(context).palette;
    final isSi = widget.strings.isSi;

    // Validate settings against capabilities
    final validationIssues = SettingsCapabilityValidator.validate(
      settings: widget.settings,
      capabilities: widget.capabilities,
    );

    return Panel(
      title: isSi ? 'මුද්‍රණ සැකසුම්' : 'Print Settings',
      isSinhala: isSi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tier Switcher Bar (Basic | Standard | Professional)
          _buildTierSwitcher(palette, isSi),
          const SizedBox(height: DesktopSpacing.s8),

          // 2. Search & "Only Changed" Filter Row
          _buildSearchAndFilterRow(palette, isSi),
          const SizedBox(height: DesktopSpacing.s8),

          // 3. Scrollable Settings Zone: Never pushes Print button off screen!
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sticky Plain-Language Summary Strip
                  _buildStickySummaryStrip(palette, isSi),
                  const SizedBox(height: DesktopSpacing.s8),

                  // Validation Issues / Media Conflicts Banner
                  if (validationIssues.isNotEmpty) ...[
                    _buildValidationBanners(palette, isSi, validationIssues),
                    const SizedBox(height: DesktopSpacing.s8),
                  ],

                  // Printer Selector & Info
                  if (_matchesSearch('printer') || _matchesSearch('model'))
                    _buildPrinterSelector(palette, isSi),
                  const SizedBox(height: DesktopSpacing.s8),

                  // Compact Printer Live Info Panel
                  PrinterLiveInfoPanel(
                    intelligence: widget.liveIntelligence,
                    validationReport: widget.validationReport,
                    isLoading: widget.isLoadingIntelligence,
                    isSinhala: isSi,
                    selectedPaperSize: widget.settings.paperSize,
                    initiallyExpanded: false,
                    onRefreshRequested: widget.onRefreshIntelligence,
                    onWebConfigConsentChanged: (consent) {
                      ref
                          .read(printerIntelligenceServiceProvider)
                          .setUserWebConfigConsent(widget.activePrinterName, consent);
                    },
                    onApplyAutoFix: (fix) {
                      // Apply intelligence fix
                    },
                    onOpenManualDuplexAssistant: widget.onOpenManualDuplexAssistant,
                  ),
                  const SizedBox(height: DesktopSpacing.s12),

                  // Tier Content: BASIC
                  if (widget.settings.tier == PrintSettingsTier.basic) ...[
                    _buildBasicTier(palette, isSi),
                  ] else if (widget.settings.tier == PrintSettingsTier.standard) ...[
                    // STANDARD Tier includes basic essentials + office features
                    _buildBasicTier(palette, isSi),
                    const SizedBox(height: DesktopSpacing.s12),
                    _buildStandardTier(palette, isSi),
                  ] else ...[
                    // PROFESSIONAL Tier includes all features
                    _buildBasicTier(palette, isSi),
                    const SizedBox(height: DesktopSpacing.s12),
                    _buildStandardTier(palette, isSi),
                    const SizedBox(height: DesktopSpacing.s12),
                    _buildProfessionalTier(palette, isSi),
                  ],
                ],
              ),
            ),
          ),

          // 4. Fixed / Pinned Print Action Button: NEVER pushed off screen!
          Padding(
            padding: const EdgeInsets.only(top: DesktopSpacing.s12),
            child: PrimaryButton(
              expandWidth: true,
              icon: Icons.print_rounded,
              label: widget.totalPages > 0
                  ? widget.strings.actionPrintWithPages(widget.totalPages)
                  : widget.strings.actionPrint,
              isSinhala: isSi,
              onPressed: widget.canPrint ? widget.onPrintPressed : null,
            ),
          ),
        ],
      ),
    );
  }

  // --- TIER SWITCHER ---
  Widget _buildTierSwitcher(DesktopPalette palette, bool isSi) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(DesktopRadius.r6),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: PrintSettingsTier.values.map((tier) {
          final isSelected = widget.settings.tier == tier;
          return Expanded(
            child: InkWell(
              onTap: () {
                widget.onSettingsChanged(widget.settings.copyWith(tier: tier));
              },
              borderRadius: BorderRadius.circular(DesktopRadius.r4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? palette.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(DesktopRadius.r4),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    isSi ? tier.nameSi.split(' ')[0] : tier.nameEn,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? palette.accent : palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- SEARCH AND FILTER ROW ---
  Widget _buildSearchAndFilterRow(DesktopPalette palette, bool isSi) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 12, color: palette.textPrimary),
              decoration: InputDecoration(
                hintText: isSi ? 'සැකසුම් සොයන්න...' : 'Search settings...',
                hintStyle: TextStyle(fontSize: 12, color: palette.textTertiary),
                prefixIcon: Icon(Icons.search, size: 16, color: palette.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                filled: true,
                fillColor: palette.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesktopRadius.r6),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesktopRadius.r6),
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
        const SizedBox(width: DesktopSpacing.s8),
        InkWell(
          onTap: () => setState(() => _onlyChangedSettings = !_onlyChangedSettings),
          borderRadius: BorderRadius.circular(DesktopRadius.r4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _onlyChangedSettings ? palette.accent.withOpacity(0.12) : palette.surfaceSecondary,
              borderRadius: BorderRadius.circular(DesktopRadius.r4),
              border: Border.all(
                color: _onlyChangedSettings ? palette.accent : palette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 14,
                  color: _onlyChangedSettings ? palette.accent : palette.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  isSi ? 'වෙනස් කළ ඒවා' : 'Changed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _onlyChangedSettings ? palette.accent : palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STICKY SUMMARY STRIP ---
  Widget _buildStickySummaryStrip(DesktopPalette palette, bool isSi) {
    final summary = isSi ? widget.settings.generateSummarySi() : widget.settings.generateSummaryEn();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DesktopSpacing.s10, vertical: DesktopSpacing.s6),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(DesktopRadius.r6),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: palette.accent),
          const SizedBox(width: DesktopSpacing.s8),
          Expanded(
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- VALIDATION BANNERS & AUTO-FIXES ---
  Widget _buildValidationBanners(
    DesktopPalette palette,
    bool isSi,
    List<SettingsValidationIssue> issues,
  ) {
    return Column(
      children: issues.map((issue) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(DesktopSpacing.s8),
          decoration: BoxDecoration(
            color: issue.isBlocking ? Colors.red.shade50 : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(DesktopRadius.r6),
            border: Border.all(
              color: issue.isBlocking ? Colors.red.shade300 : Colors.amber.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    issue.isBlocking ? Icons.error_outline : Icons.warning_amber_rounded,
                    size: 16,
                    color: issue.isBlocking ? Colors.red.shade800 : Colors.amber.shade900,
                  ),
                  const SizedBox(width: DesktopSpacing.s6),
                  Expanded(
                    child: Text(
                      isSi ? issue.messageSi : issue.messageEn,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: issue.isBlocking ? Colors.red.shade900 : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              if (issue.autoFix != null) ...[
                const SizedBox(height: DesktopSpacing.s6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: issue.isBlocking ? Colors.red.shade400 : Colors.amber.shade500,
                      ),
                    ),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                    label: Text(
                      isSi ? issue.autoFix!.labelSi : issue.autoFix!.labelEn,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: issue.isBlocking ? Colors.red.shade900 : Colors.amber.shade900,
                      ),
                    ),
                    onPressed: () {
                      final updated = issue.autoFix!.applyFix(widget.settings);
                      widget.onSettingsChanged(updated);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- PRINTER SELECTOR ---
  Widget _buildPrinterSelector(DesktopPalette palette, bool isSi) {
    return FormRow(
      label: isSi ? 'ප්‍රින්ටරය' : 'Printer',
      isSinhala: isSi,
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              value: widget.printers.any((p) => p.name == widget.activePrinterName)
                  ? widget.activePrinterName
                  : (widget.printers.isNotEmpty ? widget.printers.first.name : null),
              isExpanded: true,
              underline: const SizedBox(),
              items: widget.printers.map((p) {
                return DropdownMenuItem(
                  value: p.name,
                  child: Text(
                    p.name,
                    style: TextStyle(fontSize: 13, color: palette.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (chosen) {
                if (chosen != null) widget.onPrinterSelected(chosen);
              },
            ),
          ),
          IconButton(
            tooltip: isSi ? 'ප්‍රින්ටර් හැකියාවන් බලන්න' : 'View Printer Abilities',
            icon: Icon(Icons.tune_rounded, size: 18, color: palette.accent),
            onPressed: () {
              PrinterAbilitiesDialog.show(
                context,
                capabilities: widget.capabilities,
                isSinhala: isSi,
              );
            },
          ),
        ],
      ),
    );
  }

  // --- BASIC TIER ---
  Widget _buildBasicTier(DesktopPalette palette, bool isSi) {
    final s = widget.settings;
    final caps = widget.capabilities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Copies
        if (_matchesSearch('copies') || _matchesSearch('පිටපත්')) ...[
          FormRow(
            label: widget.strings.copiesLabel,
            isSinhala: isSi,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: s.copies > 1
                      ? () => widget.onSettingsChanged(s.copyWith(copies: s.copies - 1))
                      : null,
                ),
                Text(
                  '${s.copies}',
                  style: DesktopTypography.body14(palette, weight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => widget.onSettingsChanged(s.copyWith(copies: s.copies + 1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),
        ],

        // Page Range
        if (_matchesSearch('pages') || _matchesSearch('range')) ...[
          FormRow(
            label: isSi ? 'පිටු පරාසය' : 'Page Range',
            isSinhala: isSi,
            child: SizedBox(
              width: 140,
              height: 32,
              child: TextField(
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: isSi ? 'සියල්ල (උදා. 1-3, 5)' : 'All (e.g. 1-3, 5)',
                  hintStyle: TextStyle(fontSize: 11, color: palette.textTertiary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesktopRadius.r4)),
                ),
                controller: TextEditingController(text: s.pageRange),
                onSubmitted: (val) => widget.onSettingsChanged(s.copyWith(pageRange: val)),
              ),
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),
        ],

        // Color Mode (Color vs B&W)
        if (_matchesSearch('color') || _matchesSearch('black') || _matchesSearch('පාට')) ...[
          FormRow(
            label: widget.strings.colorModeLabel,
            isSinhala: isSi,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(widget.strings.colorModeColor),
                  enabled: caps.supportsColor,
                ),
                ButtonSegment(
                  value: false,
                  label: Text(widget.strings.colorModeBw),
                ),
              ],
              selected: {s.isColor},
              onSelectionChanged: (set) => widget.onSettingsChanged(s.copyWith(isColor: set.first)),
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),
        ],

        // Duplex (Single vs Double-sided)
        if (_matchesSearch('duplex') || _matchesSearch('sides') || _matchesSearch('දෙපැත්ත')) ...[
          FormRow(
            label: widget.strings.sidesLabel,
            isSinhala: isSi,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<DuplexMode>(
                    value: s.duplex,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(
                        value: DuplexMode.none,
                        child: Text(widget.strings.sidesSingle),
                      ),
                      DropdownMenuItem(
                        value: DuplexMode.longEdge,
                        enabled: caps.supportsDuplex(DuplexMode.longEdge),
                        child: Text(
                          caps.supportsDuplex(DuplexMode.longEdge)
                              ? widget.strings.sidesDoubleLong
                              : '${widget.strings.sidesDoubleLong} (${isSi ? "සහාය නොදක්වයි" : "Unsupported"})',
                        ),
                      ),
                      DropdownMenuItem(
                        value: DuplexMode.shortEdge,
                        enabled: caps.supportsDuplex(DuplexMode.shortEdge),
                        child: Text(
                          caps.supportsDuplex(DuplexMode.shortEdge)
                              ? widget.strings.sidesDoubleShort
                              : '${widget.strings.sidesDoubleShort} (${isSi ? "සහාය නොදක්වයි" : "Unsupported"})',
                        ),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) widget.onSettingsChanged(s.copyWith(duplex: mode));
                    },
                  ),
                ),
                if (!caps.supportsDuplex(DuplexMode.longEdge))
                  IconButton(
                    tooltip: isSi ? 'අත්පොත දෙපැත්ත සහායකය' : 'Manual Duplex Assistant',
                    icon: Icon(Icons.flip_to_back_rounded, size: 16, color: palette.accent),
                    onPressed: widget.onOpenManualDuplexAssistant,
                  ),
              ],
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),
        ],

        // Paper Size
        if (_matchesSearch('paper') || _matchesSearch('size') || _matchesSearch('ප්‍රමාණය')) ...[
          FormRow(
            label: widget.strings.paperSizeLabel,
            isSinhala: isSi,
            child: DropdownButton<String>(
              value: caps.isPaperSizeSupported(s.paperSize) ? s.paperSize : caps.supportedPaperSizes.first,
              isExpanded: true,
              underline: const SizedBox(),
              items: caps.supportedPaperSizes.map((sz) {
                return DropdownMenuItem(value: sz, child: Text(sz));
              }).toList(),
              onChanged: (size) {
                if (size != null) widget.onSettingsChanged(s.copyWith(paperSize: size));
              },
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),
        ],

        // Orientation
        if (_matchesSearch('orientation') || _matchesSearch('දිශාව')) ...[
          FormRow(
            label: widget.strings.orientationLabel,
            isSinhala: isSi,
            child: SegmentedButton<PageOrientation>(
              segments: [
                ButtonSegment(
                  value: PageOrientation.portrait,
                  label: Text(widget.strings.orientationPortrait),
                ),
                ButtonSegment(
                  value: PageOrientation.landscape,
                  label: Text(widget.strings.orientationLandscape),
                ),
              ],
              selected: {s.orientation},
              onSelectionChanged: (set) => widget.onSettingsChanged(s.copyWith(orientation: set.first)),
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),
        ],

        // Fit to page
        if (_matchesSearch('fit') || _matchesSearch('scale')) ...[
          FormRow(
            label: isSi ? 'කොළයට ගැලපීම' : 'Fit to Page',
            isSinhala: isSi,
            child: Switch(
              value: s.fitToPage,
              onChanged: (val) => widget.onSettingsChanged(s.copyWith(fitToPage: val)),
            ),
          ),
        ],
      ],
    );
  }

  // --- STANDARD TIER ---
  Widget _buildStandardTier(DesktopPalette palette, bool isSi) {
    final s = widget.settings;
    final caps = widget.capabilities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(palette, isSi ? 'සාමාන්‍ය මුද්‍රණ විකල්ප' : 'Standard Office Options', Icons.tune),

        // Media / Paper Type
        FormRow(
          label: widget.strings.paperTypeLabel,
          isSinhala: isSi,
          child: DropdownButton<String>(
            value: caps.isMediaTypeSupported(s.mediaType) ? s.mediaType : caps.supportedMediaTypes.first,
            isExpanded: true,
            underline: const SizedBox(),
            items: caps.supportedMediaTypes.map((m) {
              return DropdownMenuItem(value: m, child: Text(m));
            }).toList>,
            onChanged: (media) {
              if (media != null) widget.onSettingsChanged(s.copyWith(mediaType: media));
            },
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // Print Quality
        FormRow(
          label: isSi ? 'ගුණාත්මකභාවය' : 'Print Quality',
          isSinhala: isSi,
          child: DropdownButton<PrintQualityMode>(
            value: s.quality,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: PrintQualityMode.draft, child: Text('Draft (Fast)')),
              DropdownMenuItem(value: PrintQualityMode.normal, child: Text('Standard (Normal)')),
              DropdownMenuItem(value: PrintQualityMode.high, child: Text('High Quality')),
            ],
            onChanged: (q) {
              if (q != null) widget.onSettingsChanged(s.copyWith(quality: q));
            },
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // Printer Hardware Resolution (DPI)
        _buildHardwareDpiPicker(palette, isSi),

        // Effective Image Sharpness (PPI) & Photo Size Helper
        _buildEffectivePpiBadge(palette, isSi),
        const SizedBox(height: DesktopSpacing.s8),

        // Paper Tray
        FormRow(
          label: isSi ? 'කඩදාසි තැටිය' : 'Paper Tray',
          isSinhala: isSi,
          child: DropdownButton<String>(
            value: caps.inputBins.contains(s.paperTray) ? s.paperTray : caps.inputBins.first,
            isExpanded: true,
            underline: const SizedBox(),
            items: caps.inputBins.map((tray) {
              return DropdownMenuItem(value: tray, child: Text(tray));
            }).toList(),
            onChanged: (tr) {
              if (tr != null) widget.onSettingsChanged(s.copyWith(paperTray: tr));
            },
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // Pages per Sheet (N-Up)
        FormRow(
          label: isSi ? 'කොළයකට පිටු (N-up)' : 'Pages Per Sheet',
          isSinhala: isSi,
          child: DropdownButton<int>(
            value: s.pagesPerSheet,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 page (Standard)')),
              DropdownMenuItem(value: 2, child: Text('2 pages per sheet')),
              DropdownMenuItem(value: 4, child: Text('4 pages per sheet')),
              DropdownMenuItem(value: 6, child: Text('6 pages per sheet')),
              DropdownMenuItem(value: 9, child: Text('9 pages per sheet')),
            ],
            onChanged: (n) {
              if (n != null) widget.onSettingsChanged(s.copyWith(pagesPerSheet: n));
            },
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // Borderless switch
        FormRow(
          label: widget.strings.borderlessLabel,
          isSinhala: isSi,
          child: Switch(
            value: s.isBorderless,
            onChanged: caps.supportsBorderless
                ? (val) => widget.onSettingsChanged(s.copyWith(isBorderless: val))
                : null,
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // Collate and Reverse Order
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(isSi ? 'පිළිවෙලට සැකසීම (Collate)' : 'Collate Copies', style: const TextStyle(fontSize: 12)),
                value: s.collate,
                onChanged: (val) => widget.onSettingsChanged(s.copyWith(collate: val ?? true)),
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(isSi ? 'පසුපසින් මුද්‍රණය' : 'Reverse Order', style: const TextStyle(fontSize: 12)),
                value: s.reverseOrder,
                onChanged: (val) => widget.onSettingsChanged(s.copyWith(reverseOrder: val ?? false)),
              ),
            ),
          ],
        ),

        // Ink Saving & Black Ink Only
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(isSi ? 'තීන්ත ඉතිරි කිරීම' : 'Ink-Saving Mode', style: const TextStyle(fontSize: 12)),
                value: s.inkSavingMode,
                onChanged: (val) => widget.onSettingsChanged(s.copyWith(inkSavingMode: val ?? false)),
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(isSi ? 'කළු තීන්ත පමණක්' : 'Black Ink Only', style: const TextStyle(fontSize: 12)),
                value: s.blackInkOnly,
                onChanged: (val) => widget.onSettingsChanged(s.copyWith(blackInkOnly: val ?? false)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- PROFESSIONAL TIER ---
  Widget _buildProfessionalTier(DesktopPalette palette, bool isSi) {
    final s = widget.settings;
    final caps = widget.capabilities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 0. Resolution & Resampling
        _buildSectionTitle(palette, isSi ? 'විභේදනය සහ ප්‍රතිනියැදීම (Resolution & Resampling)' : 'Resolution & Resampling', Icons.blur_linear),

        // Render DPI (Page Rasterization)
        FormRow(
          label: isSi ? 'විදැහුම් විභේදනය (Render DPI)' : 'Render DPI (Rasterization)',
          isSinhala: isSi,
          child: DropdownButton<RenderDpiChoice>(
            value: s.renderDpi,
            isExpanded: true,
            underline: const SizedBox(),
            items: RenderDpiChoice.values.map((choice) {
              return DropdownMenuItem(
                value: choice,
                child: Text(isSi ? choice.labelSi : choice.labelEn, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            onChanged: (choice) {
              if (choice != null) widget.onSettingsChanged(s.copyWith(renderDpi: choice));
            },
          ),
        ),
        // Live memory estimate & vector notice
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: DesktopSpacing.s8),
          child: Row(
            children: [
              Icon(Icons.memory_rounded, size: 13, color: s.renderDpi == RenderDpiChoice.dpi1200 ? palette.warning : palette.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  isSi
                      ? 'මතක භාවිතය: ~${EffectivePpiCalculator.estimateRasterMemoryMb(pageWInches: 8.27, pageHInches: 11.69, renderDpi: s.renderDpi.resolveDpi(s.hardwareDpi)).round()} MB/පිටුව. PDF අකුරු rasterize නොකරයි.'
                      : 'Est. Memory: ~${EffectivePpiCalculator.estimateRasterMemoryMb(pageWInches: 8.27, pageHInches: 11.69, renderDpi: s.renderDpi.resolveDpi(s.hardwareDpi)).round()} MB/page. Vector text preserved directly.',
                  style: TextStyle(
                    fontSize: 11,
                    color: s.renderDpi == RenderDpiChoice.dpi1200 ? palette.warning : palette.textSecondary,
                    fontWeight: s.renderDpi == RenderDpiChoice.dpi1200 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Resample Filter
        FormRow(
          label: isSi ? 'ප්‍රතිනියැදි ෆිල්ටරය' : 'Resample Filter',
          isSinhala: isSi,
          child: DropdownButton<ResamplingAlgorithm>(
            value: s.resampleFilter,
            isExpanded: true,
            underline: const SizedBox(),
            items: ResamplingAlgorithm.values.map((algo) {
              return DropdownMenuItem(
                value: algo,
                child: Text(isSi ? algo.nameSi : algo.nameEn, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            onChanged: (algo) {
              if (algo != null) widget.onSettingsChanged(s.copyWith(resampleFilter: algo));
            },
          ),
        ),
        const SizedBox(height: DesktopSpacing.s6),

        // Upscale for Print Button with Dialog
        OutlinedButton.icon(
          icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
          label: Text(isSi ? 'මුද්‍රණය සඳහා පැහැදිලි කරන්න (Upscale 2x)...' : 'Upscale for Print (2x Lanczos Preview)...'),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => ResamplePreviewDialog(
                fileName: 'Document / Image',
                originalWidth: 800,
                originalHeight: 600,
                currentEffectivePpi: s.currentEffectivePpi > 0 ? s.currentEffectivePpi : 96.0,
                strings: widget.strings,
                onApplyUpscale: (algo, mult) {
                  widget.onSettingsChanged(s.copyWith(
                    resampleFilter: algo,
                    isUpscaledForPrint: true,
                    upscaleMultiplier: mult,
                    currentEffectivePpi: (s.currentEffectivePpi > 0 ? s.currentEffectivePpi : 96.0) * mult,
                  ));
                },
              ),
            );
          },
        ),
        const SizedBox(height: DesktopSpacing.s10),

        // Tone and Ink Adjustment Panel
        _buildSectionTitle(palette, isSi ? 'ටෝන සහ තීන්ත පාලනය (Tone & Ink)' : 'Tone & Ink Adjustments', Icons.palette_outlined),
        ToneAndInkPanel(
          settings: s.toneAndInk,
          isColorPrinter: caps.supportsColor,
          driverColorAdjustmentAvailable: caps.supportsDriverColorAdjustment,
          strings: widget.strings,
          onSettingsChanged: (updatedTone) {
            widget.onSettingsChanged(s.copyWith(toneAndInk: updatedTone));
          },
          onOpenDriverPreferences: () {
            showDialog(
              context: context,
              builder: (ctx) => PrinterAbilitiesDialog(
                capabilities: caps,
                strings: widget.strings,
                onCapturePreferences: () {},
                onCopyDiagnostics: () {},
              ),
            );
          },
          onPrintTestPattern: () {
            showDialog(
              context: context,
              builder: (ctx) => TestPatternDialog(
                printerName: widget.activePrinterName,
                strings: widget.strings,
                onPrintDocument: () {},
                onOpenDriverPreferences: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => PrinterAbilitiesDialog(
                      capabilities: caps,
                      strings: widget.strings,
                      onCapturePreferences: () {},
                      onCopyDiagnostics: () {},
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: DesktopSpacing.s12),

        _buildSectionTitle(palette, isSi ? 'වෘත්තීය වර්ණ සහ පිරිසැලසුම්' : 'Professional Color & Imposition', Icons.auto_awesome),

        // 1. Color Management & ICC
        FormRow(
          label: isSi ? 'වර්ණ කළමනාකරණය' : 'Color Management',
          isSinhala: isSi,
          child: DropdownButton<ProColorManagementMode>(
            value: s.colorMode,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: ProColorManagementMode.driverManaged, child: Text('Driver Managed (Recommended)')),
              DropdownMenuItem(value: ProColorManagementMode.appManaged, child: Text('App Managed (Print Helper ICC)')),
              DropdownMenuItem(value: ProColorManagementMode.off, child: Text('No Color Management (Raw RGB)')),
            ],
            onChanged: (mode) {
              if (mode != null) widget.onSettingsChanged(s.copyWith(colorMode: mode));
            },
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        if (s.colorMode == ProColorManagementMode.appManaged) ...[
          FormRow(
            label: isSi ? 'ICC පැතිකඩ' : 'ICC Profile',
            isSinhala: isSi,
            child: DropdownButton<String>(
              value: s.iccProfile,
              isExpanded: true,
              underline: const SizedBox(),
              items: caps.installedIccProfiles.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (p) {
                if (p != null) widget.onSettingsChanged(s.copyWith(iccProfile: p));
              },
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),

          FormRow(
            label: isSi ? 'වර්ණ විදැහුම් අරමුණ' : 'Rendering Intent',
            isSinhala: isSi,
            child: DropdownButton<IccRenderingIntent>(
              value: s.renderingIntent,
              isExpanded: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: IccRenderingIntent.perceptual, child: Text('Perceptual (Photographic)')),
                DropdownMenuItem(value: IccRenderingIntent.relativeColorimetric, child: Text('Relative Colorimetric (Proofing)')),
                DropdownMenuItem(value: IccRenderingIntent.saturation, child: Text('Saturation (Business Graphics)')),
                DropdownMenuItem(value: IccRenderingIntent.absoluteColorimetric, child: Text('Absolute Colorimetric')),
              ],
              onChanged: (intent) {
                if (intent != null) widget.onSettingsChanged(s.copyWith(renderingIntent: intent));
              },
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),
        ],

        // 2. Advanced B&W Toning
        if (caps.supportsAdvancedBwToning) ...[
          FormRow(
            label: isSi ? 'විශේෂ කළු-සුදු ටෝනින්' : 'Advanced B&W Toning',
            isSinhala: isSi,
            child: Row(
              children: [
                Switch(
                  value: s.advancedBwEnabled,
                  onChanged: (val) => widget.onSettingsChanged(s.copyWith(advancedBwEnabled: val)),
                ),
                if (s.advancedBwEnabled)
                  Expanded(
                    child: DropdownButton<AdvancedBwTone>(
                      value: s.advancedBwTone,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: AdvancedBwTone.neutral, child: Text('Neutral Black')),
                        DropdownMenuItem(value: AdvancedBwTone.cool, child: Text('Cool Tone (Slight Blue)')),
                        DropdownMenuItem(value: AdvancedBwTone.warm, child: Text('Warm Tone (Soft Glow)')),
                        DropdownMenuItem(value: AdvancedBwTone.sepia, child: Text('Sepia (Classic Brown)')),
                      ],
                      onChanged: (tone) {
                        if (tone != null) widget.onSettingsChanged(s.copyWith(advancedBwTone: tone));
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),
        ],

        // 3. Imposition & Layout
        FormRow(
          label: isSi ? 'පිරිසැලසුම (Imposition)' : 'Sheet Imposition',
          isSinhala: isSi,
          child: DropdownButton<ProImpositionMode>(
            value: s.impositionMode,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: ProImpositionMode.standard, child: Text('Standard (1-up)')),
              DropdownMenuItem(value: ProImpositionMode.nup, child: Text('N-Up Grid')),
              DropdownMenuItem(value: ProImpositionMode.bookletSaddleStitch, child: Text('Booklet (Saddle-Stitch)')),
              DropdownMenuItem(value: ProImpositionMode.stepAndRepeat, child: Text('Step & Repeat (Labels/Cards)')),
              DropdownMenuItem(value: ProImpositionMode.posterTiling, child: Text('Poster Tiling (Multi-sheet)')),
              DropdownMenuItem(value: ProImpositionMode.banner, child: Text('Banner Panoramic Print')),
            ],
            onChanged: (mode) {
              if (mode != null) widget.onSettingsChanged(s.copyWith(impositionMode: mode));
            },
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // 4. Passport & ID Photo Sheet Generator
        FormRow(
          label: isSi ? 'පාස්පෝට් / හැඳුනුම්පත් ෆොටෝ' : 'Passport / ID Photo Sheet',
          isSinhala: isSi,
          child: Row(
            children: [
              Switch(
                value: s.photoIdLayoutEnabled,
                onChanged: (val) => widget.onSettingsChanged(s.copyWith(photoIdLayoutEnabled: val)),
              ),
              if (s.photoIdLayoutEnabled)
                Expanded(
                  child: DropdownButton<PassportIdPreset>(
                    value: s.photoIdPreset,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: PassportIdPreset.passport35x45, child: Text('Passport 35x45 mm (SL/EU)')),
                      DropdownMenuItem(value: PassportIdPreset.visa2x2, child: Text('Visa 2x2 in (US/Square)')),
                      DropdownMenuItem(value: PassportIdPreset.id30x40, child: Text('NIC / ID 30x40 mm')),
                    ],
                    onChanged: (preset) {
                      if (preset != null) widget.onSettingsChanged(s.copyWith(photoIdPreset: preset));
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // 5. Direct CD/DVD Print
        if (caps.supportsCdDvd) ...[
          FormRow(
            label: isSi ? 'CD/DVD තැටි මුද්‍රණය' : 'Direct CD/DVD Print',
            isSinhala: isSi,
            child: Switch(
              value: s.cdDvdPrintEnabled,
              onChanged: (val) => widget.onSettingsChanged(s.copyWith(cdDvdPrintEnabled: val)),
            ),
          ),
          const SizedBox(height: DesktopSpacing.s8),
        ],

        // 6. Overlays & Stamps
        FormRow(
          label: isSi ? 'මුද්‍රා තැබීම (Stamp)' : 'Document Stamp',
          isSinhala: isSi,
          child: DropdownButton<OverlayStampPreset>(
            value: s.stampPreset,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: OverlayStampPreset.none, child: Text('None')),
              DropdownMenuItem(value: OverlayStampPreset.copy, child: Text('COPY')),
              DropdownMenuItem(value: OverlayStampPreset.paid, child: Text('PAID')),
              DropdownMenuItem(value: OverlayStampPreset.draft, child: Text('DRAFT')),
              DropdownMenuItem(value: OverlayStampPreset.sinhalaCopy, child: Text('පිටපත (Sinhala Copy)')),
              DropdownMenuItem(value: OverlayStampPreset.sinhalaPaid, child: Text('ගෙවන ලදී (Sinhala Paid)')),
              DropdownMenuItem(value: OverlayStampPreset.sinhalaDraft, child: Text('කෙටුම්පත (Sinhala Draft)')),
            ],
            onChanged: (st) {
              if (st != null) widget.onSettingsChanged(s.copyWith(stampPreset: st));
            },
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // 7. Staff Lock (PIN Protected Shop Mode)
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            isSi ? 'සේවක අගුල (Staff Lock - මුද්‍රණ සැකසුම් ආරක්ෂාව)' : 'Staff Lock (Prevent Unintended Shop Setting Changes)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          value: s.isStaffLocked,
          onChanged: (val) => widget.onSettingsChanged(s.copyWith(isStaffLocked: val ?? false)),
        ),
      ],
    );
  }

  // --- HARDWARE RESOLUTION (DPI) PICKER ---
  Widget _buildHardwareDpiPicker(DesktopPalette palette, bool isSi) {
    final s = widget.settings;
    final availableDpis = widget.capabilities.supportedResolutionsDpi.isNotEmpty
        ? widget.capabilities.supportedResolutionsDpi
        : [300, 600, 1200, 2400, 4800];

    final currentDpi = s.hardwareDpi > 0 ? s.hardwareDpi : 600;
    final currentInfo = PrinterDpiOptionInfo.forDpi(dpi: currentDpi, mediaType: s.mediaType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormRow(
          label: isSi ? 'මුද්‍රණ විභේදනය (DPI)' : 'Printer Resolution (DPI)',
          isSinhala: isSi,
          child: DropdownButton<int>(
            value: availableDpis.contains(currentDpi) ? currentDpi : availableDpis.first,
            isExpanded: true,
            underline: const SizedBox(),
            items: availableDpis.map((dpi) {
              final info = PrinterDpiOptionInfo.forDpi(dpi: dpi, mediaType: s.mediaType);
              final isSupported = info.isSupportedOnCurrentMedia;
              return DropdownMenuItem<int>(
                value: dpi,
                enabled: isSupported,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isSi ? info.labelSi : info.labelEn,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSupported ? palette.textPrimary : palette.textTertiary,
                          decoration: isSupported ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    if (!isSupported)
                      Icon(Icons.block_rounded, size: 14, color: palette.error),
                  ],
                ),
              );
            }).toList(),
            onChanged: (dpi) {
              if (dpi != null) {
                widget.onSettingsChanged(s.copyWith(hardwareDpi: dpi));
              }
            },
          ),
        ),
        // Speed and Ink Note
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: DesktopSpacing.s8),
          child: Text(
            isSi ? currentInfo.speedAndInkNoteSi : currentInfo.speedAndInkNoteEn,
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
        ),
      ],
    );
  }

  // --- EFFECTIVE PPI CHECKER BADGE ---
  Widget _buildEffectivePpiBadge(DesktopPalette palette, bool isSi) {
    final s = widget.settings;
    final ppi = s.currentEffectivePpi > 0 ? s.currentEffectivePpi : 300.0;
    final rating = PpiQualityRating.fromPpi(ppi);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: DesktopSpacing.s4),
      padding: const EdgeInsets.all(DesktopSpacing.s10),
      decoration: BoxDecoration(
        color: rating.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(DesktopRadius.r6),
        border: Border.all(color: rating.color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(rating.icon, size: 16, color: rating.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isSi ? 'පැහැදිලි බව: ${ppi.round()} PPI (${rating.shortLabelSi})' : 'Sharpness: ${ppi.round()} PPI (${rating.shortLabelEn})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: rating.color,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => PhotoSizeHelperDialog(
                      pixelWidth: 1800,
                      pixelHeight: 1200,
                      fileName: 'Selected Image',
                      currentPaperSize: s.paperSize,
                      strings: widget.strings,
                      onSelectSize: (chosen) {
                        widget.onSettingsChanged(s.copyWith(paperSize: chosen));
                      },
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_size_select_actual_outlined, size: 12, color: palette.accent),
                      const SizedBox(width: 4),
                      Text(
                        isSi ? 'ප්‍රමාණ සහායක' : 'Photo Size Helper',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isSi ? rating.descriptionSi : rating.descriptionEn,
            style: TextStyle(fontSize: 11, color: palette.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(DesktopPalette palette, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: DesktopSpacing.s8, bottom: DesktopSpacing.s8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: palette.accent),
          const SizedBox(width: DesktopSpacing.s6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}
