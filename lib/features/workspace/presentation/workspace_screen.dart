import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/desktop_design_system.dart';
import '../../../core/widgets/desktop_widgets.dart';
import '../../../services/printer/models/printer_intelligence_models.dart';
import '../../../services/printer/models/printer_models.dart';
import '../../../services/printer/printer_intelligence_service.dart';
import '../../onboarding/presentation/onboarding_dialog.dart';
import '../../pdf_tools/presentation/pdf_toolkit_controller.dart';
import '../../printers/presentation/printers_controller.dart';
import '../../queue/domain/print_job_models.dart';
import '../../queue/presentation/job_queue_controller.dart';
import '../domain/print_queue_item.dart';
import '../domain/print_settings_models.dart';
import '../../../services/printer/capability_discovery_service.dart';
import 'queue_controller.dart';
import 'widgets/manual_duplex_assistant_dialog.dart';
import 'widgets/printer_abilities_dialog.dart';
import 'widgets/printer_live_info_panel.dart';
import 'widgets/print_settings_panel.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  StreamSubscription<PrinterLiveIntelligence>? _intelSub;
  StreamSubscription<PrinterHotPlugEvent>? _hotPlugSub;
  PrinterLiveIntelligence? _activePrinterIntelligence;
  bool _isRefreshingIntelligence = false;
  String? _lastObservedPrinterSystemName;
  bool _isAdvancedExpanded = false;
  bool _isQueueDrawerOpen = false;
  UnifiedPrintSettings _unifiedSettings = const UnifiedPrintSettings();

  // Center Preview state
  int _currentPageIndex = 1;
  double _previewZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OnboardingDialog.showIfNeeded(context, ref);
        final intelService = ref.read(printerIntelligenceServiceProvider);
        _intelSub = intelService.intelligenceStream.listen((snapshot) {
          if (mounted && snapshot.printerId == _lastObservedPrinterSystemName) {
            setState(() {
              _activePrinterIntelligence = snapshot;
              _isRefreshingIntelligence = false;
            });
          }
        });

        // Listen for hot-plug and spooler change events
        final capService = ref.read(capabilityDiscoveryServiceProvider);
        _hotPlugSub = capService.hotPlugEvents.listen((event) {
          if (!mounted) return;
          final isSi = ref.read(stringsProvider).isSi;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              content: Row(
                children: [
                  const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSi ? event.toastMessageSi : event.toastMessageEn,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _intelSub?.cancel();
    _hotPlugSub?.cancel();
    super.dispose();
  }

  void _syncActivePrinterTelemetry(
    PrinterDevice? selectedDevice,
    List<PrinterDevice> allPrinters,
  ) {
    final sysName = selectedDevice?.systemName;
    if (sysName == _lastObservedPrinterSystemName) return;
    _lastObservedPrinterSystemName = sysName;

    final intelService = ref.read(printerIntelligenceServiceProvider);
    final cached = sysName != null ? intelService.getCached(sysName) : null;
    _activePrinterIntelligence = cached;
    _isRefreshingIntelligence = selectedDevice != null && cached == null;

    intelService.updateAdaptivePollingTargets(
      selectedPrinter: selectedDevice,
      allPrinters: allPrinters,
    );
  }

  void _applySmartPrintAutoFix(
    SmartPrintValidationFix fix,
    QueueState queueState,
    QueueController controller,
  ) {
    if (queueState.items.isEmpty) return;
    final current = queueState.items.first.settings;
    final updated = switch (fix.actionKind) {
      SmartFixActionKind.switchPaperSizeToLoaded =>
        current.copyWith(paperSize: fix.targetPaperSize ?? 'A4'),
      SmartFixActionKind.switchMediaTypeToLoadedTray =>
        current.copyWith(mediaType: fix.targetMediaType ?? 'Plain Paper'),
      SmartFixActionKind.switchColorToGrayscale =>
        current.copyWith(isColor: false),
      SmartFixActionKind.disableBorderless =>
        current.copyWith(marginPreset: MarginPreset.normal),
      SmartFixActionKind.switchToManualDuplexAssistant =>
        current.copyWith(duplex: DuplexMode.none),
    };
    controller.applySettingsToAllItems(updated);
  }

  Future<void> _openManualDuplexAssistant({
    required QueueState queueState,
    required QueueController controller,
    required JobQueueController jobQueueController,
    required String activePrinterName,
    required bool isSinhala,
  }) async {
    final totalPages = queueState.totalPages > 1 ? queueState.totalPages : 4;
    await showDialog<bool>(
      context: context,
      builder: (_) => ManualDuplexAssistantDialog(
        totalPages: totalPages,
        printerName: activePrinterName,
        isSinhala: isSinhala,
        onDispatchPagesBatch: (pagesBatch) async {
          final rangeStr = pagesBatch.join(', ');
          if (queueState.items.isNotEmpty) {
            final base = queueState.items.first.settings;
            controller.applySettingsToAllItems(
              base.copyWith(
                duplex: DuplexMode.none,
                pageRange: rangeStr,
              ),
            );
            await jobQueueController.enqueueBatch(
              items: ref.read(queueControllerProvider).items,
              primaryPrinterName: activePrinterName,
            );
          }
        },
      ),
    );
  }

  Future<void> _dispatchBatchPrint(
    QueueState queueState,
    QueueController controller,
    PrintersController printersController,
    JobQueueController jobQueueController,
    PrintDocumentType? firstDocType,
    String activePrinterName,
    AppStrings strings,
  ) async {
    if (queueState.items.isEmpty) return;

    // Check Smart Print Validation before dispatching
    final intelService = ref.read(printerIntelligenceServiceProvider);
    final intel = _activePrinterIntelligence;
    if (intel != null) {
      final firstSettings = queueState.items.first.settings;
      final report = intelService.validatePrintJob(
        intelligence: intel,
        requestedPaperSize: firstSettings.paperSize,
        requestedMediaType: firstSettings.mediaType,
        requestedTwoSided: firstSettings.duplex != DuplexMode.none,
        requestedColor: firstSettings.isColor,
        requestedBorderless: firstSettings.marginPreset == MarginPreset.none,
      );

      if (report.requiresManualDuplexAssistant) {
        await _openManualDuplexAssistant(
          queueState: queueState,
          controller: controller,
          jobQueueController: jobQueueController,
          activePrinterName: activePrinterName,
          isSinhala: strings.isSi,
        );
        return;
      }
    }

    controller.selectPrinter(activePrinterName);
    if (firstDocType != null) {
      printersController.rememberPrinterForFileType(
        firstDocType,
        activePrinterName,
      );
    }
    await jobQueueController.enqueueBatch(
      items: queueState.items,
      primaryPrinterName: activePrinterName,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isSi
                ? 'ෆයිල් ${queueState.totalFiles} ක් ප්‍රින්ට් පෝලිමට යොමු කරන ලදී.'
                : 'Dispatched ${queueState.totalFiles} file(s) (${queueState.totalPages} pages) to print queue.',
          ),
          action: SnackBarAction(
            label: strings.isSi ? 'පෝලිම බලන්න' : 'View Jobs',
            onPressed: () => context.go('/jobs'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(queueControllerProvider);
    final controller = ref.read(queueControllerProvider.notifier);
    final printersState = ref.watch(printersControllerProvider);
    final printersController = ref.read(printersControllerProvider.notifier);
    final jobQueueState = ref.watch(jobQueueControllerProvider);
    final jobQueueController = ref.read(jobQueueControllerProvider.notifier);
    final locale = ref.watch(localeProvider);
    final strings = AppStrings.of(locale);
    final palette = DesktopPalette.of(context);

    final firstDocType =
        queueState.items.isNotEmpty ? queueState.items.first.docType : null;
    final preferredPrinterForType = firstDocType != null
        ? printersController.preferredPrinterForFileType(firstDocType)
        : null;

    final activePrinterName = queueState.selectedPrinterSystemName ??
        preferredPrinterForType ??
        printersState.defaultPrinter?.systemName ??
        (printersState.printers.isNotEmpty
            ? printersState.printers.first.systemName
            : 'Default Printer');

    final selectedPrinterDevice = printersState.printers.firstWhere(
      (p) => p.systemName == activePrinterName,
      orElse: () => PrinterDevice(
        systemName: activePrinterName,
        displayName: activePrinterName,
        isDefault: true,
      ),
    );

    _syncActivePrinterTelemetry(
      selectedPrinterDevice,
      printersState.printers,
    );

    final firstSettings = queueState.items.isNotEmpty
        ? queueState.items.first.settings
        : const FilePrintSettings();

    final validationReport = _activePrinterIntelligence != null
        ? ref.read(printerIntelligenceServiceProvider).validatePrintJob(
              intelligence: _activePrinterIntelligence!,
              requestedPaperSize: firstSettings.paperSize,
              requestedMediaType: firstSettings.mediaType,
              requestedTwoSided: firstSettings.duplex != DuplexMode.none,
              requestedColor: firstSettings.isColor,
              requestedBorderless:
                  firstSettings.marginPreset == MarginPreset.none,
            )
        : null;

    return CallbackShortcuts(
      bindings: {
        // Ctrl+P or Cmd+P: Print now
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
            _dispatchBatchPrint(
              queueState,
              controller,
              printersController,
              jobQueueController,
              firstDocType,
              activePrinterName,
              strings,
            ),
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () =>
            _dispatchBatchPrint(
              queueState,
              controller,
              printersController,
              jobQueueController,
              firstDocType,
              activePrinterName,
              strings,
            ),
        // F5: Refresh printers
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            printersController.refreshPrinters(),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive rule:
            // Below 1100 px width, the file queue becomes a collapsible drawer/slide-over.
            // Center preview and right print panel stay visible.
            final isWideScreen = constraints.maxWidth >= 1100;

            final rightPanelWidth = math.max(320.0, constraints.maxWidth * 0.25);
            final leftQueueWidth = isWideScreen ? constraints.maxWidth * 0.30 : 0.0;

            return Stack(
              children: [
                Padding(
                  padding: DesktopSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top responsive bar when below 1100px to toggle queue drawer
                      if (!isWideScreen)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DesktopSpacing.s8),
                          child: Row(
                            children: [
                              SecondaryButton(
                                icon: Icons.queue_outlined,
                                label: queueState.totalFiles > 0
                                    ? '${strings.queueHeader} (${queueState.totalFiles})'
                                    : strings.queueHeader,
                                isSinhala: strings.isSi,
                                onPressed: () {
                                  setState(() {
                                    _isQueueDrawerOpen = !_isQueueDrawerOpen;
                                  });
                                },
                              ),
                              const SizedBox(width: DesktopSpacing.s8),
                              SecondaryButton(
                                icon: Icons.add,
                                label: strings.btnOpenFiles,
                                isSinhala: strings.isSi,
                                onPressed: controller.pickAndAddFiles,
                              ),
                              const Spacer(),
                              Text(
                                strings.totalPagesLabel(queueState.totalPages),
                                style: DesktopTypography.caption12(
                                  palette,
                                  isSinhala: strings.isSi,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Friendly Error Banner if any
                      if (queueState.latestErrorMessages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DesktopSpacing.s16),
                          child: InlineMessage(
                            kind: DesktopStatusKind.warning,
                            message: queueState.latestErrorMessages.join(' • '),
                            actionLabel: strings.actionClose,
                            onAction: controller.dismissErrors,
                            isSinhala: strings.isSi,
                          ),
                        ),

                      // Three Clear Zones
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ZONE 1: Left File Queue with drop zone at top (~30% when >= 1100px)
                            if (isWideScreen) ...[
                              SizedBox(
                                width: leftQueueWidth,
                                child: _buildQueueZone(
                                  context,
                                  palette,
                                  strings,
                                  queueState,
                                  controller,
                                ),
                              ),
                              const SizedBox(width: DesktopSpacing.s16),
                            ],

                            // ZONE 2: Center Live Document Preview (~45% width)
                            Expanded(
                              child: _buildCenterPreviewZone(
                                context,
                                palette,
                                strings,
                                queueState,
                                firstSettings,
                              ),
                            ),
                            const SizedBox(width: DesktopSpacing.s16),

                            // ZONE 3: Right Print Panel (about 25%, min 320 px) with pinned Print button
                            SizedBox(
                              width: rightPanelWidth,
                              child: _buildRightPrintPanel(
                                context,
                                palette,
                                strings,
                                queueState,
                                controller,
                                printersState,
                                printersController,
                                jobQueueController,
                                selectedPrinterDevice,
                                activePrinterName,
                                firstDocType,
                                firstSettings,
                                validationReport,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Slide-over Drawer for File Queue when width < 1100px
                if (!isWideScreen && _isQueueDrawerOpen)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: math.min(360.0, constraints.maxWidth * 0.85),
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.surfacePrimary,
                        border: Border(right: BorderSide(color: palette.borderSubtle)),
                        boxShadow: DesktopElevation.menu,
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(DesktopSpacing.s16),
                              child: Row(
                                children: [
                                  Text(
                                    strings.queueHeader,
                                    style: DesktopTypography.subtitle16(
                                      palette,
                                      isSinhala: strings.isSi,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () =>
                                        setState(() => _isQueueDrawerOpen = false),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _buildQueueZone(
                                context,
                                palette,
                                strings,
                                queueState,
                                controller,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // ZONE 1: Left Queue & Drop Zone
  // ===========================================================================

  Widget _buildQueueZone(
    BuildContext context,
    DesktopPalette palette,
    AppStrings strings,
    QueueState queueState,
    QueueController controller,
  ) {
    return Panel(
      title: strings.queueHeader,
      isSinhala: strings.isSi,
      trailing: queueState.items.isNotEmpty
          ? StatusBadge(
              label: strings.queueCountBadge(queueState.totalFiles),
              kind: DesktopStatusKind.neutral,
              isSinhala: strings.isSi,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pinned Drop Zone at Top
          _buildDropZonePinnedHeader(context, palette, strings, controller),
          const SizedBox(height: DesktopSpacing.s16),

          // Scrollable File List below Drop Zone
          Expanded(
            child: queueState.isLoading && queueState.items.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : queueState.items.isEmpty
                    ? EmptyState(
                        icon: Icons.upload_file_outlined,
                        title: strings.queueEmpty,
                        description: strings.queueEmptyHint,
                        isSinhala: strings.isSi,
                        actionLabel: strings.btnOpenFiles,
                        onAction: controller.pickAndAddFiles,
                      )
                    : ListView.separated(
                        itemCount: queueState.items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: DesktopSpacing.s8),
                        itemBuilder: (context, index) {
                          final item = queueState.items[index];
                          return _buildQueueItemRow(
                            context,
                            palette,
                            strings,
                            item,
                            index,
                            controller,
                          );
                        },
                      ),
          ),

          if (queueState.items.isNotEmpty) ...[
            const SizedBox(height: DesktopSpacing.s8),
            Row(
              children: [
                SecondaryButton(
                  icon: Icons.clear_all,
                  label: strings.btnClearQueue,
                  isSinhala: strings.isSi,
                  onPressed: controller.clearQueue,
                ),
                const Spacer(),
                Text(
                  strings.totalPagesLabel(queueState.totalPages),
                  style: DesktopTypography.caption12(
                    palette,
                    isSinhala: strings.isSi,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropZonePinnedHeader(
    BuildContext context,
    DesktopPalette palette,
    AppStrings strings,
    QueueController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(DesktopSpacing.s16),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(DesktopRadius.r6),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.file_upload_outlined,
                size: 20,
                color: palette.accent,
              ),
              const SizedBox(width: DesktopSpacing.s8),
              Expanded(
                child: Text(
                  strings.dropZoneTitle,
                  style: DesktopTypography.body14(
                    palette,
                    isSinhala: strings.isSi,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesktopSpacing.s8),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  icon: Icons.add,
                  label: strings.btnOpenFiles,
                  isSinhala: strings.isSi,
                  onPressed: controller.pickAndAddFiles,
                ),
              ),
              const SizedBox(width: DesktopSpacing.s8),
              SecondaryButton(
                icon: Icons.content_paste_outlined,
                label: 'Ctrl+V',
                isSinhala: false,
                onPressed: controller.pasteFromClipboard,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItemRow(
    BuildContext context,
    DesktopPalette palette,
    AppStrings strings,
    PrintQueueItem item,
    int index,
    QueueController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopSpacing.s16,
        vertical: DesktopSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(DesktopRadius.r6),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 20,
            color: palette.accent,
          ),
          const SizedBox(width: DesktopSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: item.fileName,
                  child: Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesktopTypography.body14(
                      palette,
                      isSinhala: strings.isSi,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${item.pageCount} ${strings.pagesLabel}',
                  style: DesktopTypography.caption12(
                    palette,
                    isSinhala: strings.isSi,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: strings.queueItemRemoveTooltip,
            color: palette.textSecondary,
            onPressed: () => controller.removeItem(item.id),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ZONE 2: Center Live Document Preview
  // ===========================================================================

  Widget _buildCenterPreviewZone(
    BuildContext context,
    DesktopPalette palette,
    AppStrings strings,
    QueueState queueState,
    FilePrintSettings firstSettings,
  ) {
    final hasFiles = queueState.items.isNotEmpty;
    final totalPages = hasFiles ? queueState.totalPages : 1;

    return Panel(
      title: strings.previewHeader,
      isSinhala: strings.isSi,
      trailing: hasFiles
          ? StatusBadge(
              label: '${firstSettings.paperSize} • ${firstSettings.isColor ? strings.colorModeColor : strings.colorModeBw}',
              kind: DesktopStatusKind.neutral,
              isSinhala: strings.isSi,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sheet Preview Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DesktopSpacing.s8),
              decoration: BoxDecoration(
                color: palette.backgroundCanvas,
                borderRadius: BorderRadius.circular(DesktopRadius.r6),
                border: Border.all(color: palette.borderSubtle),
              ),
              child: Center(
                child: hasFiles
                    ? _buildSimulatedDocumentSheet(
                        palette,
                        strings,
                        firstSettings,
                        _currentPageIndex,
                        totalPages,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 48,
                            color: palette.textMuted,
                          ),
                          const SizedBox(height: DesktopSpacing.s16),
                          Text(
                            strings.queueEmptyHint,
                            textAlign: TextAlign.center,
                            style: DesktopTypography.body14(
                              palette,
                              isSinhala: strings.isSi,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Pinned Bottom Bar: Page Navigation & Zoom Controls
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesktopSpacing.s16,
              vertical: DesktopSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: palette.surfaceSecondary,
              borderRadius: BorderRadius.circular(DesktopRadius.r6),
              border: Border.all(color: palette.borderSubtle),
            ),
            child: Row(
              children: [
                // Page Navigation
                SecondaryButton(
                  icon: Icons.chevron_left,
                  label: strings.prevPage,
                  isSinhala: strings.isSi,
                  onPressed: _currentPageIndex > 1
                      ? () => setState(() => _currentPageIndex--)
                      : null,
                ),
                const SizedBox(width: DesktopSpacing.s8),
                Text(
                  strings.pageCountOf(
                    hasFiles ? _currentPageIndex : 1,
                    totalPages,
                  ),
                  style: DesktopTypography.body14(
                    palette,
                    isSinhala: strings.isSi,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: DesktopSpacing.s8),
                SecondaryButton(
                  icon: Icons.chevron_right,
                  label: strings.nextPage,
                  isSinhala: strings.isSi,
                  onPressed: _currentPageIndex < totalPages
                      ? () => setState(() => _currentPageIndex++)
                      : null,
                ),
                const Spacer(),

                // Zoom Controls
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  tooltip: strings.zoomOut,
                  onPressed: _previewZoom > 0.5
                      ? () => setState(() => _previewZoom -= 0.1)
                      : null,
                ),
                Text(
                  '${(_previewZoom * 100).round()}%',
                  style: DesktopTypography.caption12(
                    palette,
                    isSinhala: false,
                    weight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  tooltip: strings.zoomIn,
                  onPressed: _previewZoom < 2.0
                      ? () => setState(() => _previewZoom += 0.1)
                      : null,
                ),
                const SizedBox(width: DesktopSpacing.s8),
                SecondaryButton(
                  label: strings.fitPage,
                  isSinhala: strings.isSi,
                  onPressed: () => setState(() => _previewZoom = 1.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedDocumentSheet(
    DesktopPalette palette,
    AppStrings strings,
    FilePrintSettings settings,
    int pageIndex,
    int totalPages,
  ) {
    final isLandscape =
        settings.orientation == PrintOrientationPreference.landscape;
    final aspectRatio = isLandscape ? (297 / 210) : (210 / 297);

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        margin: const EdgeInsets.all(DesktopSpacing.s16),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(DesktopRadius.r4),
          border: Border.all(color: palette.borderSubtle),
          boxShadow: DesktopElevation.card,
        ),
        padding: const EdgeInsets.all(DesktopSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: settings.isColor
                        ? palette.accent.withOpacity(0.12)
                        : palette.borderSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.article_outlined,
                    color: settings.isColor ? palette.accent : palette.textSecondary,
                  ),
                ),
                const SizedBox(width: DesktopSpacing.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 140,
                        decoration: BoxDecoration(
                          color: palette.borderSubtle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 8,
                        width: 90,
                        decoration: BoxDecoration(
                          color: palette.borderSubtle.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$pageIndex / $totalPages',
                  style: DesktopTypography.caption12(
                    palette,
                    isSinhala: false,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesktopSpacing.s16),
            Expanded(
              child: Column(
                children: List.generate(
                  6,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: palette.borderSubtle.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ZONE 3: Right Print Panel (Pinned Print Button at Bottom)
  // ===========================================================================

  Widget _buildRightPrintPanel(
    BuildContext context,
    DesktopPalette palette,
    AppStrings strings,
    QueueState queueState,
    QueueController controller,
    PrintersState printersState,
    PrintersController printersController,
    JobQueueController jobQueueController,
    PrinterDevice selectedPrinterDevice,
    String activePrinterName,
    PrintDocumentType? firstDocType,
    FilePrintSettings firstSettings,
    SmartPrintValidationReport? validationReport,
  ) {
    final capsAsync = ref.watch(printerCapabilitiesProvider(activePrinterName));
    final capabilities =
        capsAsync.value ?? DiscoveredCapabilities.genericFallback(activePrinterName);

    // Keep settings in sync with queue state
    if (_unifiedSettings.printerName != activePrinterName ||
        _unifiedSettings.copies != firstSettings.copies ||
        _unifiedSettings.isColor != firstSettings.isColor ||
        _unifiedSettings.duplex != firstSettings.duplex ||
        _unifiedSettings.paperSize != firstSettings.paperSize) {
      _unifiedSettings = _unifiedSettings.copyWith(
        printerName: activePrinterName,
        copies: firstSettings.copies,
        isColor: firstSettings.isColor,
        duplex: firstSettings.duplex,
        paperSize: firstSettings.paperSize,
        mediaType: firstSettings.mediaType,
        quality: firstSettings.quality,
        orientation: firstSettings.orientation,
        isBorderless: firstSettings.marginPreset == MarginPreset.none,
      );
    }

    return PrintSettingsPanel(
      settings: _unifiedSettings,
      capabilities: capabilities,
      liveIntelligence: _activePrinterIntelligence,
      validationReport: validationReport,
      printers: printersState.printers,
      activePrinterName: activePrinterName,
      isLoadingIntelligence: _isRefreshingIntelligence,
      totalPages: queueState.totalPages,
      canPrint: queueState.items.isNotEmpty,
      strings: strings,
      onSettingsChanged: (updated) {
        setState(() => _unifiedSettings = updated);
        controller.applySettingsToAllItems(updated.toFilePrintSettings());
      },
      onPrinterSelected: (chosen) {
        controller.selectPrinter(chosen);
        if (firstDocType != null) {
          printersController.rememberPrinterForFileType(firstDocType, chosen);
        }
      },
      onPrintPressed: () => _dispatchBatchPrint(
        queueState,
        controller,
        printersController,
        jobQueueController,
        firstDocType,
        activePrinterName,
        strings,
      ),
      onRefreshIntelligence: () async {
        setState(() => _isRefreshingIntelligence = true);
        await ref
            .read(printerIntelligenceServiceProvider)
            .refreshPrinter(activePrinterName);
        if (mounted) {
          setState(() => _isRefreshingIntelligence = false);
        }
      },
      onOpenManualDuplexAssistant: () => _openManualDuplexAssistant(
        queueState: queueState,
        controller: controller,
        jobQueueController: jobQueueController,
        activePrinterName: activePrinterName,
        isSinhala: strings.isSi,
      ),
    );
  }
}
