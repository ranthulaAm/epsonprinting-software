import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../services/printer/models/printer_models.dart';
import '../../../services/printer/win32_devmode_configurator.dart';
import '../../presets/data/presets_persistence.dart';
import '../../printers/presentation/printers_controller.dart';
import '../../workspace/domain/print_queue_item.dart';
import '../domain/print_layout_engine.dart';

class LivePrintPreviewDialog extends ConsumerStatefulWidget {
  const LivePrintPreviewDialog({
    super.key,
    required this.item,
    required this.onApplySettings,
    required this.onApplyToAllInQueue,
  });

  final PrintQueueItem item;
  final ValueChanged<FilePrintSettings> onApplySettings;
  final ValueChanged<FilePrintSettings> onApplyToAllInQueue;

  @override
  ConsumerState<LivePrintPreviewDialog> createState() =>
      _LivePrintPreviewDialogState();
}

class _LivePrintPreviewDialogState
    extends ConsumerState<LivePrintPreviewDialog> {
  late FilePrintSettings _draft;
  int _currentSideIndex = 0;
  double _zoomLevel = 1.0;

  late final TextEditingController _pageRangeCtrl;
  late final TextEditingController _watermarkCtrl;
  late final TextEditingController _headerCtrl;
  late final TextEditingController _footerCtrl;
  late final TextEditingController _customWidthCtrl;
  late final TextEditingController _customHeightCtrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.item.settings;
    _pageRangeCtrl = TextEditingController(text: _draft.pageRange);
    _watermarkCtrl = TextEditingController(text: _draft.watermarkText);
    _headerCtrl = TextEditingController(text: _draft.headerText);
    _footerCtrl = TextEditingController(text: _draft.footerText);
    _customWidthCtrl = TextEditingController(
      text: _draft.customWidthMm.toStringAsFixed(0),
    );
    _customHeightCtrl = TextEditingController(
      text: _draft.customHeightMm.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _pageRangeCtrl.dispose();
    _watermarkCtrl.dispose();
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    _customWidthCtrl.dispose();
    _customHeightCtrl.dispose();
    super.dispose();
  }

  void _updateDraft(FilePrintSettings next) {
    setState(() {
      _draft = next;
    });
    widget.onApplySettings(next);
  }

  void _loadPreset(PrintPreset preset) {
    final s = preset.settings;
    _pageRangeCtrl.text = s.pageRange;
    _watermarkCtrl.text = s.watermarkText;
    _headerCtrl.text = s.headerText;
    _footerCtrl.text = s.footerText;
    _customWidthCtrl.text = s.customWidthMm.toStringAsFixed(0);
    _customHeightCtrl.text = s.customHeightMm.toStringAsFixed(0);
    _updateDraft(s);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = AppStrings.of(locale);
    final lang = locale.languageCode;
    final printersState = ref.watch(printersControllerProvider);
    final presets = ref.watch(presetsControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Resolve active printer & evaluate hardware capability restrictions
    final PrinterDevice? activePrinter =
        printersState.printers.isNotEmpty ? printersState.printers.first : null;
    final capEval = PrintLayoutEngine.evaluateCapabilityRestrictions(
      settings: _draft,
      printer: activePrinter,
    );
    final effectiveSettings = capEval.sanitizedSettings;

    final sheets = PrintLayoutEngine.computePhysicalSheets(
      totalDocumentPages: widget.item.pageCount,
      settings: effectiveSettings,
    );
    final int safeSideIdx =
        sheets.isEmpty ? 0 : _currentSideIndex.clamp(0, sheets.length - 1);
    final currentSheet = sheets[safeSideIdx];

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240, maxHeight: 820),
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            backgroundColor: colorScheme.surfaceContainer,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Icon(Icons.preview_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.isSi
                            ? 'සජීවී මුද්‍රණ පෙරදසුන සහ සැකසුම් — ${widget.item.fileName}'
                            : 'Live Print Preview & Settings — ${widget.item.fileName}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      if (activePrinter != null)
                        Text(
                          'Target Printer: ${activePrinter.displayName} (${activePrinter.portName})',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Apply to all files in batch queue
              OutlinedButton.icon(
                onPressed: () {
                  widget.onApplyToAllInQueue(effectiveSettings);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.isSi
                            ? 'මෙම සැකසුම් පෝලිමේ ඇති සියලුම ගොනු සඳහා යොදන ලදී.'
                            : 'Applied settings to all files in the queue.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_all_rounded, size: 17),
                label: Text(
                  strings.isSi ? 'සියලුම ගොනු වලට යොදන්න' : 'Apply to All Files',
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(strings.isSi ? 'හරි (Done)' : 'Done'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT PANE: Live Interactive Sheet Preview with Zoom & Page Navigation
              Expanded(
                flex: 5,
                child: Container(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
                  child: Column(
                    children: [
                      // Preview Toolbar (Page Navigation + Duplex Flip Indicator + Zoom)
                      _PreviewToolbar(
                        currentSideIndex: safeSideIdx,
                        totalSides: sheets.length,
                        currentSheet: currentSheet,
                        settings: effectiveSettings,
                        zoomLevel: _zoomLevel,
                        strings: strings,
                        onPrev: safeSideIdx > 0
                            ? () =>
                                setState(() => _currentSideIndex = safeSideIdx - 1)
                            : null,
                        onNext: safeSideIdx < sheets.length - 1
                            ? () =>
                                setState(() => _currentSideIndex = safeSideIdx + 1)
                            : null,
                        onZoomOut: () => setState(
                          () => _zoomLevel = (_zoomLevel - 0.2).clamp(0.5, 2.5),
                        ),
                        onZoomIn: () => setState(
                          () => _zoomLevel = (_zoomLevel + 0.2).clamp(0.5, 2.5),
                        ),
                        onZoomReset: () => setState(() => _zoomLevel = 1.0),
                      ),

                      // Interactive Sheet Canvas
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(28),
                            child: _PhysicalSheetCanvas(
                              item: widget.item,
                              sheet: currentSheet,
                              totalSides: sheets.length,
                              settings: effectiveSettings,
                              zoomLevel: _zoomLevel,
                              strings: strings,
                            ),
                          ),
                        ),
                      ),

                      // Bottom Summary Strip (Paper Dimensions, Scale, Total Physical Sheets)
                      _PreviewFooterSummary(
                        settings: effectiveSettings,
                        totalSides: sheets.length,
                        activePrinter: activePrinter,
                        strings: strings,
                      ),
                    ],
                  ),
                ),
              ),

              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),

              // RIGHT PANE: Settings Controls, Capability Warnings & Presets
              Expanded(
                flex: 6,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 0. Presets Bar (Load & Save Preset)
                    _PresetSelectorCard(
                      presets: presets,
                      strings: strings,
                      onSelectPreset: _loadPreset,
                      onSaveCurrentAsPreset: () =>
                          _showSavePresetDialog(context, effectiveSettings, strings),
                    ),
                    const SizedBox(height: 16),

                    // 1. Copies, Collate, Page Range, Odd/Even, Reverse Order
                    _SectionHeader(
                      icon: Icons.filter_none_rounded,
                      title: strings.isSi
                          ? 'පිටපත් සහ පිටු පරාසය (Copies & Pages)'
                          : 'Copies, Collate & Page Range',
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 20,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Copies Stepper
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${strings.copiesLabel}:',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.outlined(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _draft.copies > 1
                                          ? () => _updateDraft(
                                                _draft.copyWith(
                                                  copies: _draft.copies - 1,
                                                ),
                                              )
                                          : null,
                                      icon: const Icon(Icons.remove, size: 16),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        '${_draft.copies}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    IconButton.outlined(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _updateDraft(
                                        _draft.copyWith(
                                          copies: _draft.copies + 1,
                                        ),
                                      ),
                                      icon: const Icon(Icons.add, size: 16),
                                    ),
                                  ],
                                ),

                                // Collate Checkbox
                                FilterChip(
                                  selected: _draft.collate,
                                  onSelected: (v) => _updateDraft(
                                    _draft.copyWith(collate: v),
                                  ),
                                  label: Text(
                                    strings.isSi
                                        ? 'පිළිවෙලට සකසන්න (Collate 1-2-3, 1-2-3)'
                                        : 'Collate (1-2-3, 1-2-3)',
                                  ),
                                ),

                                // Reverse Order Checkbox
                                FilterChip(
                                  selected: _draft.reverseOrder,
                                  onSelected: (v) => _updateDraft(
                                    _draft.copyWith(reverseOrder: v),
                                  ),
                                  avatar: const Icon(
                                    Icons.swap_vert_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    strings.isSi
                                        ? 'අවසන් පිටුවේ සිට (Reverse Order)'
                                        : 'Reverse Page Order',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _pageRangeCtrl,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: strings.isSi
                                          ? 'පිටු පරාසය (හිස් = සියලුම පිටු)'
                                          : 'Page Range (Leave blank for All Pages)',
                                      hintText: 'e.g. 1-3, 5, 8-10',
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => _updateDraft(
                                      _draft.copyWith(
                                        pageRange: v,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<PageSubset>(
                                    value: _draft.pageSubset,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: strings.isSi
                                          ? 'පිටු තේරීම'
                                          : 'Pages to Print',
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: PageSubset.all,
                                        child: Text(
                                          strings.isSi
                                              ? 'සියලුම පිටු (All)'
                                              : 'All Pages in Range',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PageSubset.oddOnly,
                                        child: Text(
                                          strings.isSi
                                              ? 'ඔත්තේ පිටු පමණි (Odd)'
                                              : 'Odd Pages Only (1, 3, 5)',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PageSubset.evenOnly,
                                        child: Text(
                                          strings.isSi
                                              ? 'ඉරට්ටේ පිටු පමණි (Even)'
                                              : 'Even Pages Only (2, 4, 6)',
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateDraft(
                                          _draft.copyWith(pageSubset: val),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Single-Sided & Double-Sided (Duplex) with Visual Flip Icons
                    _SectionHeader(
                      icon: Icons.flip_rounded,
                      title: strings.isSi
                          ? 'දෙපැත්තම මුද්‍රණය (Single / Double-Sided Duplex)'
                          : 'Two-Sided (Duplex) & Page Turn Direction',
                    ),
                    if (!capEval.duplexSupported &&
                        capEval.noticeFor('duplex', lang) != null)
                      _DisabledCapabilityBanner(
                        message: capEval.noticeFor('duplex', lang)!,
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: _DuplexVisualOptionCard(
                            mode: DuplexMode.none,
                            selected:
                                effectiveSettings.duplex == DuplexMode.none,
                            enabled: true,
                            title: strings.duplexNone,
                            subtitle: strings.isSi
                                ? 'සෑම කඩදාසියකම එක් පැත්තක් පමණි'
                                : 'Print on one side of each sheet',
                            onTap: () => _updateDraft(
                              _draft.copyWith(duplex: DuplexMode.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DuplexVisualOptionCard(
                            mode: DuplexMode.longEdge,
                            selected:
                                effectiveSettings.duplex == DuplexMode.longEdge,
                            enabled: capEval.duplexSupported,
                            title: strings.duplexLongEdge,
                            subtitle: strings.isSi
                                ? 'පොතක් මෙන් වමට පෙරළන්න'
                                : 'Flip like a standard book',
                            onTap: () => _updateDraft(
                              _draft.copyWith(duplex: DuplexMode.longEdge),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DuplexVisualOptionCard(
                            mode: DuplexMode.shortEdge,
                            selected: effectiveSettings.duplex ==
                                DuplexMode.shortEdge,
                            enabled: capEval.duplexSupported,
                            title: strings.duplexShortEdge,
                            subtitle: strings.isSi
                                ? 'දින දර්ශනයක් මෙන් ඉහළට පෙරළන්න'
                                : 'Flip up like a notepad/calendar',
                            onTap: () => _updateDraft(
                              _draft.copyWith(duplex: DuplexMode.shortEdge),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Orientation, Paper Size, Custom Size, Scaling, Margins, Centering
                    _SectionHeader(
                      icon: Icons.aspect_ratio_rounded,
                      title: strings.isSi
                          ? 'කඩදාසි ප්‍රමාණය, දිශාව සහ මායිම් (Paper, Scaling & Margins)'
                          : 'Orientation, Paper Size, Scaling & Margins',
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Orientation Segmented Button
                                SegmentedButton<PageOrientation>(
                                  segments: [
                                    ButtonSegment(
                                      value: PageOrientation.portrait,
                                      icon: const Icon(
                                        Icons.crop_portrait_rounded,
                                        size: 18,
                                      ),
                                      label: Text(strings.orientationPortrait),
                                    ),
                                    ButtonSegment(
                                      value: PageOrientation.landscape,
                                      icon: const Icon(
                                        Icons.crop_landscape_rounded,
                                        size: 18,
                                      ),
                                      label: Text(strings.orientationLandscape),
                                    ),
                                  ],
                                  selected: {_draft.orientation},
                                  onSelectionChanged: (sel) => _updateDraft(
                                    _draft.copyWith(orientation: sel.first),
                                  ),
                                ),

                                // Paper Size Dropdown
                                SizedBox(
                                  width: 210,
                                  child: DropdownButtonFormField<String>(
                                    value: const [
                                      'A4',
                                      'Letter',
                                      'Legal',
                                      'A3',
                                      'A5',
                                      'Custom',
                                    ].contains(_draft.paperSize)
                                        ? _draft.paperSize
                                        : 'A4',
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: strings.paperSizeLabel,
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'A4',
                                        child: Text('A4 (210 × 297 mm)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Letter',
                                        child: Text('Letter (8.5 × 11 in)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Legal',
                                        child: Text('Legal (8.5 × 14 in)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'A3',
                                        child: Text('A3 (297 × 420 mm)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'A5',
                                        child: Text('A5 (148 × 210 mm)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Custom',
                                        child: Text('Custom Size (mm)...'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateDraft(
                                          _draft.copyWith(paperSize: val),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // Custom Width / Height (mm) when Paper Size == 'Custom'
                            if (_draft.paperSize == 'Custom') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _customWidthCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Width (mm)',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        final w = double.tryParse(v) ?? 210.0;
                                        _updateDraft(
                                          _draft.copyWith(customWidthMm: w),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _customHeightCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Height (mm)',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        final h = double.tryParse(v) ?? 297.0;
                                        _updateDraft(
                                          _draft.copyWith(customHeightMm: h),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 14),
                            // Scaling & Margins Row
                            Row(
                              children: [
                                Expanded(
                                  child:
                                      DropdownButtonFormField<PrintScaleMode>(
                                    value: _draft.scaleMode,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: strings.isSi
                                          ? 'ප්‍රමාණය සැකසීම (Scaling)'
                                          : 'Scaling',
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: PrintScaleMode.fitToPage,
                                        child: Text(
                                          strings.isSi
                                              ? 'පිටුවට ගලපන්න (Fit to Page)'
                                              : 'Fit to Printable Area',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PrintScaleMode.actualSize,
                                        child: Text(
                                          strings.isSi
                                              ? 'සැබෑ ප්‍රමාණය (Actual 100%)'
                                              : 'Actual Size (100%)',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PrintScaleMode.customPercent,
                                        child: Text(
                                          'Custom Scale (${_draft.customScalePercent.round()}%)',
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateDraft(
                                          _draft.copyWith(scaleMode: val),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<MarginPreset>(
                                    value: _draft.marginPreset,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: strings.isSi
                                          ? 'මායිම් (Margins)'
                                          : 'Margins',
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: MarginPreset.normal,
                                        child: Text('Normal (12.7 mm)'),
                                      ),
                                      DropdownMenuItem(
                                        value: MarginPreset.narrow,
                                        child: Text('Narrow (6.35 mm)'),
                                      ),
                                      DropdownMenuItem(
                                        value: MarginPreset.none,
                                        child: Text('None / Borderless (0 mm)'),
                                      ),
                                      DropdownMenuItem(
                                        value: MarginPreset.custom,
                                        child: Text('Custom Margin (mm)'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateDraft(
                                          _draft.copyWith(marginPreset: val),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),

                            if (_draft.scaleMode ==
                                PrintScaleMode.customPercent) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Scale %:'),
                                  Expanded(
                                    child: Slider(
                                      value: _draft.customScalePercent.clamp(
                                        25.0,
                                        200.0,
                                      ),
                                      min: 25,
                                      max: 200,
                                      divisions: 35,
                                      label:
                                          '${_draft.customScalePercent.round()}%',
                                      onChanged: (v) => _updateDraft(
                                        _draft.copyWith(customScalePercent: v),
                                      ),
                                    ),
                                  ),
                                  Text('${_draft.customScalePercent.round()}%'),
                                ],
                              ),
                            ],

                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              children: [
                                FilterChip(
                                  selected: _draft.centerHorizontally,
                                  onSelected: (v) => _updateDraft(
                                    _draft.copyWith(centerHorizontally: v),
                                  ),
                                  label: Text(
                                    strings.isSi
                                        ? 'තිරස්ව මැදට (Center Horizontally)'
                                        : 'Center Horizontally',
                                  ),
                                ),
                                FilterChip(
                                  selected: _draft.centerVertically,
                                  onSelected: (v) => _updateDraft(
                                    _draft.copyWith(centerVertically: v),
                                  ),
                                  label: Text(
                                    strings.isSi
                                        ? 'සිරස්ව මැදට (Center Vertically)'
                                        : 'Center Vertically',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Color/Grayscale, Print Quality/Draft, Paper Tray & Paper Type
                    _SectionHeader(
                      icon: Icons.tune_rounded,
                      title: strings.isSi
                          ? 'වර්ණ, තත්ත්වය සහ කඩදාසි තැටිය (Color, Quality & Tray)'
                          : 'Color Mode, Quality, Paper Tray & Media Type',
                    ),
                    if (!capEval.colorSupported &&
                        capEval.noticeFor('color', lang) != null)
                      _DisabledCapabilityBanner(
                        message: capEval.noticeFor('color', lang)!,
                      ),
                    if (!capEval.traySelectionSupported &&
                        capEval.noticeFor('tray', lang) != null)
                      _DisabledCapabilityBanner(
                        message: capEval.noticeFor('tray', lang)!,
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Color vs Grayscale Segmented Button
                                SegmentedButton<bool>(
                                  segments: [
                                    ButtonSegment(
                                      value: true,
                                      enabled: capEval.colorSupported,
                                      icon: const Icon(
                                        Icons.palette_outlined,
                                        size: 18,
                                      ),
                                      label: Text(strings.colorLabel),
                                    ),
                                    ButtonSegment(
                                      value: false,
                                      icon: const Icon(
                                        Icons.contrast_rounded,
                                        size: 18,
                                      ),
                                      label: Text(strings.bwLabel),
                                    ),
                                  ],
                                  selected: {effectiveSettings.isColor},
                                  onSelectionChanged: (sel) => _updateDraft(
                                    _draft.copyWith(isColor: sel.first),
                                  ),
                                ),

                                // Print Quality / Draft Mode
                                SegmentedButton<PrintQualityMode>(
                                  segments: [
                                    ButtonSegment(
                                      value: PrintQualityMode.draft,
                                      label: Text(
                                        strings.isSi ? 'Draft (ඉතිරි)' : 'Draft',
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: PrintQualityMode.normal,
                                      label: Text(
                                        strings.isSi ? 'සාමාන්‍ය' : 'Normal',
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: PrintQualityMode.high,
                                      label: Text(
                                        strings.isSi ? 'ඉහළ (High)' : 'High',
                                      ),
                                    ),
                                  ],
                                  selected: {_draft.quality},
                                  onSelectionChanged: (sel) => _updateDraft(
                                    _draft.copyWith(quality: sel.first),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                // Paper Tray (from PrinterCapabilities)
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: (activePrinter?.capabilities.trays
                                                .any((t) =>
                                                    t.name ==
                                                    _draft.paperTray) ??
                                            false)
                                        ? _draft.paperTray
                                        : 'Auto Select',
                                    decoration: InputDecoration(
                                      isDense: true,
                                      enabled: capEval.traySelectionSupported,
                                      labelText: strings.paperTrayLabel,
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: (activePrinter?.capabilities.trays
                                                .map((t) => t.name)
                                                .toSet()
                                                .toList() ??
                                            const [
                                              'Auto Select',
                                              'Tray 1',
                                              'Tray 2',
                                              'Manual Feed',
                                            ])
                                        .map(
                                          (trayName) => DropdownMenuItem(
                                            value: trayName,
                                            child: Text(trayName),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: capEval.traySelectionSupported
                                        ? (val) {
                                            if (val != null) {
                                              _updateDraft(
                                                _draft.copyWith(paperTray: val),
                                              );
                                            }
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Paper / Media Type
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _draft.mediaType,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      enabled: capEval.mediaTypeSupported,
                                      labelText: strings.isSi
                                          ? 'කඩදාසි වර්ගය (Paper Type)'
                                          : 'Paper / Media Type',
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Plain Paper',
                                        child: Text('Plain Paper (75-90 gsm)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Matte Paper',
                                        child: Text('Matte Presentation'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Glossy Photo',
                                        child: Text('Glossy Photo Paper'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Cardstock',
                                        child: Text('Heavy Cardstock'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Envelope',
                                        child: Text('Envelope'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Labels',
                                        child: Text('Adhesive Labels'),
                                      ),
                                    ],
                                    onChanged: capEval.mediaTypeSupported
                                        ? (val) {
                                            if (val != null) {
                                              _updateDraft(
                                                _draft.copyWith(mediaType: val),
                                              );
                                            }
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Multiple Pages per Sheet (2, 4, 6, 9), Booklet, Poster & Mirror/Flip
                    _SectionHeader(
                      icon: Icons.grid_view_rounded,
                      title: strings.isSi
                          ? 'බහු-පිටු සැකසුම, Booklet, Poster සහ Mirror'
                          : 'Multi-Page Layout (N-Up, Booklet, Poster) & Mirror/Flip',
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SegmentedButton<SheetLayoutMode>(
                              segments: [
                                ButtonSegment(
                                  value: SheetLayoutMode.standard,
                                  icon: const Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    strings.isSi ? 'සාමාන්‍ය (1-Up)' : '1-Up',
                                  ),
                                ),
                                ButtonSegment(
                                  value: SheetLayoutMode.nUp,
                                  icon: const Icon(
                                    Icons.grid_view_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    strings.isSi
                                        ? 'පිටු කිහිපයක් (N-Up)'
                                        : 'N-Up (2/4/6/9)',
                                  ),
                                ),
                                ButtonSegment(
                                  value: SheetLayoutMode.booklet,
                                  icon: const Icon(
                                    Icons.menu_book_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Booklet'),
                                ),
                                ButtonSegment(
                                  value: SheetLayoutMode.poster,
                                  icon: const Icon(
                                    Icons.apps_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Poster'),
                                ),
                              ],
                              selected: {_draft.layoutMode},
                              onSelectionChanged: (sel) {
                                _currentSideIndex = 0;
                                _updateDraft(
                                  _draft.copyWith(layoutMode: sel.first),
                                );
                              },
                            ),

                            if (_draft.layoutMode == SheetLayoutMode.nUp) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    strings.isSi
                                        ? 'එක් කඩදාසියක පිටු ගණන:'
                                        : 'Pages per sheet:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SegmentedButton<int>(
                                    segments: const [
                                      ButtonSegment(value: 2, label: Text('2')),
                                      ButtonSegment(value: 4, label: Text('4')),
                                      ButtonSegment(value: 6, label: Text('6')),
                                      ButtonSegment(value: 9, label: Text('9')),
                                    ],
                                    selected: {_draft.pagesPerSheet},
                                    onSelectionChanged: (sel) {
                                      _currentSideIndex = 0;
                                      _updateDraft(
                                        _draft.copyWith(
                                          pagesPerSheet: sel.first,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],

                            if (_draft.layoutMode ==
                                SheetLayoutMode.poster) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    strings.isSi
                                        ? 'Poster කොටස් ගණන (Tile Grid):'
                                        : 'Poster Tile Grid:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SegmentedButton<int>(
                                    segments: const [
                                      ButtonSegment(
                                        value: 2,
                                        label: Text('2 × 2 (4 Sheets)'),
                                      ),
                                      ButtonSegment(
                                        value: 3,
                                        label: Text('3 × 3 (9 Sheets)'),
                                      ),
                                      ButtonSegment(
                                        value: 4,
                                        label: Text('4 × 4 (16 Sheets)'),
                                      ),
                                    ],
                                    selected: {_draft.posterGridSize},
                                    onSelectionChanged: (sel) {
                                      _currentSideIndex = 0;
                                      _updateDraft(
                                        _draft.copyWith(
                                          posterGridSize: sel.first,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              children: [
                                FilterChip(
                                  selected: _draft.mirrorHorizontal,
                                  onSelected: (v) => _updateDraft(
                                    _draft.copyWith(mirrorHorizontal: v),
                                  ),
                                  avatar: const Icon(
                                    Icons.flip_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    strings.isSi
                                        ? 'කැඩපත් ප්‍රතිබිම්බය (Mirror Horizontally)'
                                        : 'Mirror Horizontally (T-Shirt / Transfer)',
                                  ),
                                ),
                                FilterChip(
                                  selected: _draft.flipVertical,
                                  onSelected: (v) => _updateDraft(
                                    _draft.copyWith(flipVertical: v),
                                  ),
                                  avatar: const Icon(
                                    Icons.flip_camera_android_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    strings.isSi
                                        ? 'උඩු-යටිකුරු කරන්න (Flip Vertically)'
                                        : 'Flip Upside-Down (Vertical)',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. Watermark, Headers/Footers & Page Numbers (Sinhala-capable)
                    _SectionHeader(
                      icon: Icons.branding_watermark_rounded,
                      title: strings.isSi
                          ? 'දිය සලකුණ (Watermark), ශීර්ෂකය සහ පිටු අංක (සිංහල සහාය)'
                          : 'Watermark, Headers/Footers & Page Numbers (සිංහල Ready)',
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _watermarkCtrl,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: strings.isSi
                                          ? 'දිය සලකුණ (Watermark Text - සිංහල / English)'
                                          : 'Diagonal Watermark Text (English or සිංහල)',
                                      hintText:
                                          'e.g. රහසිගතයි / CONFIDENTIAL / DRAFT',
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => _updateDraft(
                                      _draft.copyWith(watermarkText: v),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Opacity (${(_draft.watermarkOpacity * 100).round()}%)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                      Slider(
                                        value: _draft.watermarkOpacity
                                            .clamp(0.05, 0.65),
                                        min: 0.05,
                                        max: 0.65,
                                        onChanged: (v) => _updateDraft(
                                          _draft.copyWith(watermarkOpacity: v),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _headerCtrl,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: strings.isSi
                                          ? 'ඉහළ ශීර්ෂකය (Header Text)'
                                          : 'Top Header Text',
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => _updateDraft(
                                      _draft.copyWith(headerText: v),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _footerCtrl,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: strings.isSi
                                          ? 'පහළ පාදකය (Footer Text)'
                                          : 'Bottom Footer Text',
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => _updateDraft(
                                      _draft.copyWith(footerText: v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FilterChip(
                              selected: _draft.showPageNumbers,
                              onSelected: (v) => _updateDraft(
                                _draft.copyWith(showPageNumbers: v),
                              ),
                              avatar: const Icon(
                                Icons.format_list_numbered_rounded,
                                size: 16,
                              ),
                              label: Text(
                                strings.isSi
                                    ? 'පිටු අංක මුද්‍රණය කරන්න (පිටුව X / Y)'
                                    : 'Include Page Numbers in Footer (Page X of Y)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 7. Plain Text & Markdown Typography (Sinhala & English)
                    if (widget.item.documentType == PrintDocumentType.plainText ||
                        widget.item.documentType == PrintDocumentType.markdown) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(
                        icon: Icons.text_fields_rounded,
                        title: strings.isSi
                            ? 'පෙළ සහ Markdown අකුරු සැකසුම් (Text & Markdown Typography)'
                            : 'Plain Text & Markdown Typography (සිංහල / English)',
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Font Family selector
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: const [
                                        'NotoSansSinhala',
                                        'Consolas',
                                        'Segoe UI',
                                      ].contains(_draft.textFontFamily)
                                          ? _draft.textFontFamily
                                          : 'NotoSansSinhala',
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: strings.isSi
                                            ? 'අකුරු වර්ගය (Font Family)'
                                            : 'Font Family',
                                        border: const OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'NotoSansSinhala',
                                          child: Text(
                                            'Noto Sans Sinhala (සිංහල + English)',
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Consolas',
                                          child: Text(
                                            'Consolas Monospace (+ සිංහල Fallback)',
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Segoe UI',
                                          child: Text(
                                            'Segoe UI (+ සිංහල Fallback)',
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          _updateDraft(
                                            _draft.copyWith(textFontFamily: val),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Line Spacing selector
                                  Expanded(
                                    child: DropdownButtonFormField<double>(
                                      value: const [1.15, 1.45, 1.75, 2.0]
                                              .contains(_draft.textLineSpacing)
                                          ? _draft.textLineSpacing
                                          : 1.45,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: strings.isSi
                                            ? 'පේළි පරතරය (Line Spacing)'
                                            : 'Line Spacing',
                                        border: const OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 1.15,
                                          child: Text('Compact (1.15×)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 1.45,
                                          child: Text(
                                            'Standard Sinhala/English (1.45×)',
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 1.75,
                                          child: Text('Relaxed (1.75×)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 2.0,
                                          child: Text('Double Spaced (2.0×)'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          _updateDraft(
                                            _draft.copyWith(
                                              textLineSpacing: val,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    strings.isSi
                                        ? 'අකුරු ප්‍රමාණය (${_draft.textFontSizePt.toStringAsFixed(0)} pt):'
                                        : 'Font Size (${_draft.textFontSizePt.toStringAsFixed(0)} pt):',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _draft.textFontSizePt.clamp(
                                        8.0,
                                        24.0,
                                      ),
                                      min: 8.0,
                                      max: 24.0,
                                      divisions: 16,
                                      label:
                                          '${_draft.textFontSizePt.round()} pt',
                                      onChanged: (v) => _updateDraft(
                                        _draft.copyWith(textFontSizePt: v),
                                      ),
                                    ),
                                  ),
                                  FilterChip(
                                    selected: _draft.textWrapLines,
                                    onSelected: (v) => _updateDraft(
                                      _draft.copyWith(textWrapLines: v),
                                    ),
                                    avatar: const Icon(
                                      Icons.wrap_text_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      strings.isSi
                                          ? 'පේළි කඩන්න (Word Wrap)'
                                          : 'Wrap Long Lines',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSavePresetDialog(
    BuildContext context,
    FilePrintSettings settingsToSave,
    AppStrings strings,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          strings.isSi
              ? 'නව පෙර-සැකසුමක් ලෙස සුරකින්න (Save Preset)'
              : 'Save Current Settings as Preset',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                hintText: 'e.g. Double-sided B&W draft',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Short Description (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.isSi ? 'අවලංගු කරන්න' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(presetsControllerProvider.notifier).savePreset(
                    name: nameCtrl.text,
                    description: descCtrl.text,
                    settings: settingsToSave,
                  );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(strings.isSi ? 'සුරකින්න' : 'Save Preset'),
          ),
        ],
      ),
    );
  }
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({
    required this.currentSideIndex,
    required this.totalSides,
    required this.currentSheet,
    required this.settings,
    required this.zoomLevel,
    required this.strings,
    required this.onPrev,
    required this.onNext,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onZoomReset,
  });

  final int currentSideIndex;
  final int totalSides;
  final PreviewPhysicalSheet currentSheet;
  final FilePrintSettings settings;
  final double zoomLevel;
  final AppStrings strings;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDuplex = settings.duplex != DuplexMode.none;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sheet / Side Navigation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                isDuplex
                    ? 'Sheet ${currentSheet.sheetIndex} (${currentSheet.isBackSide ? 'Back' : 'Front'}) • ${currentSideIndex + 1}/$totalSides'
                    : 'Sheet ${currentSideIndex + 1} of $totalSides',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),

          // Zoom Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Zoom Out',
                onPressed: onZoomOut,
                icon: const Icon(Icons.zoom_out_rounded, size: 18),
              ),
              TextButton(
                onPressed: onZoomReset,
                child: Text(
                  '${(zoomLevel * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Zoom In',
                onPressed: onZoomIn,
                icon: const Icon(Icons.zoom_in_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhysicalSheetCanvas extends StatelessWidget {
  const _PhysicalSheetCanvas({
    required this.item,
    required this.sheet,
    required this.totalSides,
    required this.settings,
    required this.zoomLevel,
    required this.strings,
  });

  final PrintQueueItem item;
  final PreviewPhysicalSheet sheet;
  final int totalSides;
  final FilePrintSettings settings;
  final double zoomLevel;
  final AppStrings strings;

  // Standard ITU-R BT.709 luminance grayscale matrix for B&W preview
  static const List<double> _grayscaleMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final dims = settings.effectivePaperDimensionsMm;
    final double aspect = dims.widthMm / dims.heightMm;
    final double baseHeight = aspect >= 1.0 ? 330.0 : 420.0;
    final double baseWidth = baseHeight * aspect;

    final double canvasW = baseWidth * zoomLevel;
    final double canvasH = baseHeight * zoomLevel;

    // Margin in canvas pixels
    final double marginRatio =
        (settings.effectiveMarginMm / dims.widthMm).clamp(0.0, 0.25);
    final double marginPx = canvasW * marginRatio;

    // Scale factor for content inside printable area
    final double contentScale = switch (settings.scaleMode) {
      PrintScaleMode.fitToPage => 1.0,
      PrintScaleMode.actualSize => 0.92,
      PrintScaleMode.customPercent =>
        (settings.customScalePercent / 100.0).clamp(0.25, 2.0),
    };

    final Alignment contentAlignment = Alignment(
      settings.centerHorizontally ? 0.0 : -1.0,
      settings.centerVertically ? 0.0 : -1.0,
    );

    Widget sheetBody = Container(
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Printable Margin Box & Content Grid
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(marginPx),
              child: Container(
                decoration: BoxDecoration(
                  border: settings.marginPreset == MarginPreset.none
                      ? null
                      : Border.all(
                          color: Colors.blueGrey.withOpacity(0.28),
                          width: 1,
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Optional Top Header (Sinhala + English capable)
                    if (settings.headerText.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, top: 2),
                        child: Text(
                          settings.headerText.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Main Imposition Grid (1-Up, N-Up, Booklet, or Poster Tile)
                    Expanded(
                      child: ClipRect(
                        child: Align(
                          alignment: contentAlignment,
                          child: Transform.scale(
                            scale: contentScale,
                            alignment: contentAlignment,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(
                                settings.mirrorHorizontal ? -1.0 : 1.0,
                                settings.flipVertical ? -1.0 : 1.0,
                                1.0,
                              ),
                              child: _buildImpositionGrid(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Optional Bottom Footer & Page Numbers
                    if (settings.footerText.trim().isNotEmpty ||
                        settings.showPageNumbers)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 4, left: 4, right: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              settings.footerText.trim(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                            if (settings.showPageNumbers)
                              Text(
                                strings.isSi
                                    ? 'පිටුව ${sheet.sideNumber} / $totalSides'
                                    : 'Page ${sheet.sideNumber} of $totalSides',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Booklet Center Fold Dashed Line Indicator
          if (sheet.isBookletSpread)
            Positioned(
              top: 0,
              bottom: 0,
              left: canvasW / 2,
              child: Container(
                width: 1.5,
                color: Colors.indigo.withOpacity(0.45),
              ),
            ),

          // Diagonal Watermark Overlay (Sinhala & English ready)
          if (settings.watermarkText.trim().isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -math.pi / 5,
                    child: Opacity(
                      opacity: settings.watermarkOpacity.clamp(0.05, 0.75),
                      child: Text(
                        settings.watermarkText.trim(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28 * zoomLevel,
                          fontWeight: FontWeight.w800,
                          color: _previewColorFor(settings.isColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Duplex Binding Edge Visual Indicator Strip
          if (settings.duplex != DuplexMode.none)
            _buildDuplexBindingEdgeIndicator(canvasW, canvasH),
        ],
      ),
    );

    // Apply B&W Grayscale Filter when Monochrome is selected
    if (!settings.isColor) {
      sheetBody = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
        child: sheetBody,
      );
    }

    // Apply subtle lighter ink appearance when Draft Quality is selected
    if (settings.quality == PrintQualityMode.draft) {
      sheetBody = Opacity(opacity: 0.84, child: sheetBody);
    }

    return sheetBody;
  }

  Widget _buildImpositionGrid() {
    final rows = sheet.rows;
    final cols = sheet.cols;

    return Column(
      children: List.generate(rows, (r) {
        return Expanded(
          child: Row(
            children: List.generate(cols, (c) {
              final idx = (r * cols) + c;
              final slot = idx < sheet.slots.length
                  ? sheet.slots[idx]
                  : const PreviewSheetSlot(sourcePageNumber: null);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: slot.isBlank
                        ? Colors.grey.shade50
                        : const Color(0xFFFDFEFF),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: slot.isBlank
                      ? const Center(
                          child: Text(
                            'Blank Fold Page',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black26,
                            ),
                          ),
                        )
                      : _buildSlotContent(slot),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildSlotContent(PreviewSheetSlot slot) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.thumbnailBytes != null &&
            item.thumbnailBytes!.isNotEmpty &&
            slot.sourcePageNumber == 1)
          Image.memory(
            item.thumbnailBytes!,
            fit: BoxFit.contain,
          )
        else if (item.textPreviewSnippet != null &&
            item.textPreviewSnippet!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Text(
                item.textPreviewSnippet!,
                softWrap: settings.textWrapLines,
                overflow: settings.textWrapLines
                    ? TextOverflow.clip
                    : TextOverflow.fade,
                style: TextStyle(
                  fontFamily: settings.textFontFamily,
                  fontFamilyFallback: const ['NotoSansSinhala', 'Segoe UI'],
                  fontSize: (settings.textFontSizePt * 0.92).clamp(7.5, 22.0),
                  color: Colors.black87,
                  height: settings.textLineSpacing,
                ),
              ),
            ),
          )
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 34,
                  color: Colors.black38,
                ),
                const SizedBox(height: 6),
                Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'සිංහල පෙරදසුන • Preview Ready',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),

        // Source Page Badge or Poster Tile Coordinate Badge
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              sheet.isPosterTile
                  ? 'P.${slot.sourcePageNumber} • Tile (${slot.tileRow + 1},${slot.tileCol + 1}) of ${slot.tileGridSize}×${slot.tileGridSize}'
                  : 'P.${slot.sourcePageNumber}',
              style: const TextStyle(
                fontSize: 9.5,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDuplexBindingEdgeIndicator(double w, double h) {
    final isLongEdge = settings.duplex == DuplexMode.longEdge;
    if (isLongEdge) {
      return Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: Container(
          width: 5,
          color: Colors.blueAccent.withOpacity(0.55),
        ),
      );
    } else {
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          height: 5,
          color: Colors.blueAccent.withOpacity(0.55),
        ),
      );
    }
  }
}

Color _previewColorFor(bool isColor) =>
    isColor ? const Color(0xFFB3261E) : Colors.black54;

class _PreviewFooterSummary extends StatelessWidget {
  const _PreviewFooterSummary({
    required this.settings,
    required this.totalSides,
    required this.activePrinter,
    required this.strings,
  });

  final FilePrintSettings settings;
  final int totalSides;
  final PrinterDevice? activePrinter;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final dims = settings.effectivePaperDimensionsMm;
    final bool isDuplex = settings.duplex != DuplexMode.none;
    final int physicalSheets =
        isDuplex ? ((totalSides + 1) ~/ 2) : totalSides;

    // Run live DEVMODE verification check if a printer is selected
    final devModeReport = activePrinter != null
        ? Win32DevModeConfigurator.verifyAndApplyDevMode(
            printer: activePrinter!,
            settings: settings,
          )
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${settings.paperSize} (${dims.widthMm.toStringAsFixed(0)} × ${dims.heightMm.toStringAsFixed(0)} mm) • '
            '$physicalSheets physical sheet(s) × ${settings.copies} cop${settings.copies == 1 ? 'y' : 'ies'}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (devModeReport != null)
            Text(
              'Win32 DEVMODE: PaperCode=${devModeReport.appliedPaperSizeCode}, DuplexCode=${devModeReport.appliedDuplexCode}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}

class _DuplexVisualOptionCard extends StatelessWidget {
  const _DuplexVisualOptionCard({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final DuplexMode mode;
  final bool selected;
  final bool enabled;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer.withOpacity(0.55)
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? colorScheme.primary : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              _DuplexPaperFlipDiagram(
                mode: mode,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom-drawn icon that visually shows how the paper turns for Single-sided,
/// Long-Edge Book Flip, and Short-Edge Calendar/Notepad Flip.
class _DuplexPaperFlipDiagram extends StatelessWidget {
  const _DuplexPaperFlipDiagram({
    required this.mode,
    required this.color,
  });

  final DuplexMode mode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (mode == DuplexMode.none)
            Icon(Icons.description_outlined, size: 34, color: color)
          else if (mode == DuplexMode.longEdge) ...[
            Icon(Icons.menu_book_rounded, size: 32, color: color),
            Positioned(
              right: 2,
              bottom: 0,
              child: Icon(Icons.sync_alt_rounded, size: 16, color: color),
            ),
          ] else ...[
            Icon(Icons.calendar_today_rounded, size: 30, color: color),
            Positioned(
              right: 2,
              bottom: 0,
              child: Icon(Icons.swap_vert_rounded, size: 18, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetSelectorCard extends StatelessWidget {
  const _PresetSelectorCard({
    required this.presets,
    required this.strings,
    required this.onSelectPreset,
    required this.onSaveCurrentAsPreset,
  });

  final List<PrintPreset> presets;
  final AppStrings strings;
  final ValueChanged<PrintPreset> onSelectPreset;
  final VoidCallback onSaveCurrentAsPreset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.35)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmarks_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                strings.isSi ? 'පෙර සැකසුම් (Presets):' : 'Quick Presets:',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...presets.take(4).map(
                    (preset) => ActionChip(
                      label: Text(
                        preset.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => onSelectPreset(preset),
                    ),
                  ),
              FilledButton.tonalIcon(
                onPressed: onSaveCurrentAsPreset,
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: Text(
                  strings.isSi ? 'සුරකින්න' : 'Save Preset',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DisabledCapabilityBanner extends StatelessWidget {
  const _DisabledCapabilityBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
