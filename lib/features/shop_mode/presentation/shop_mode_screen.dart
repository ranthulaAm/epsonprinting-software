import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_motion.dart';
import '../../../services/printer/models/printer_models.dart';
import '../../../services/printer/printer_intelligence_service.dart';
import '../../presets/data/presets_persistence.dart';
import '../../printers/presentation/printers_controller.dart';
import '../../queue/presentation/job_queue_controller.dart';
import '../../workspace/domain/print_queue_item.dart';
import '../domain/shop_mode_models.dart';
import 'shop_mode_controller.dart';

/// Complete "Shop Mode" counter screen for high-volume print shops:
/// - Tab 1 (`F1`): **Quick Print (3-Step Counter Flow)** — Drop files -> Pick Preset -> Auto-Routed Printer & Print Now + 1-Click Reprint Last Job + Receipt PDF
/// - Tab 2 (`F2`): **Customer Jobs & Barcode Scanner** — Group files per customer, notes, status (`Waiting` -> `Printing` -> `Done` -> `Picked up`), Hot Folder & Customer Drop Folders
/// - Tab 3 (`F3`): **Multi-Printer Live Dashboard & Routing Rules** — Animated overview of all printers with ink/toner bars, loaded paper, queue length, low-supply alerts, and Auto-Routing Rules
/// - Tab 4 (`F4`): **Price List, Cost/Profit Tracker & Daily Report** — Editable per-page prices (LKR & multi-currency), estimated ink/paper cost & profit (`estimate`), and Daily Report CSV/PDF export
class ShopModeScreen extends ConsumerStatefulWidget {
  const ShopModeScreen({super.key});

  @override
  ConsumerState<ShopModeScreen> createState() => _ShopModeScreenState();
}

class _ShopModeScreenState extends ConsumerState<ShopModeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerNotesCtrl = TextEditingController();
  final TextEditingController _barcodeSearchCtrl = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerNameCtrl.dispose();
    _customerNotesCtrl.dispose();
    _barcodeSearchCtrl.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _printOrSaveReceiptPdf(
    ShopCustomerJob job,
    ShopModeController shopCtrl,
    ShopModeState shopState,
    bool saveToFileOnly,
  ) async {
    final estimate = shopCtrl.pricingService.calculateJobEstimate(
      files: job.files,
      priceRules: shopState.priceRules,
      costConfig: shopState.supplyCostConfig,
      flatDiscountAmount: job.discountAmount,
      discountPercent: job.discountPercent,
    );
    final pdfBytes = await shopCtrl.pricingService.generateCustomerReceiptPdfBytes(
      job: job,
      estimate: estimate,
      shopConfig: shopState.supplyCostConfig,
    );

    if (saveToFileOnly) {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Customer Receipt PDF',
        fileName: '${job.jobNumberCode}_Receipt.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (path != null) {
        await File(path).writeAsBytes(pdfBytes, flush: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved receipt to $path')),
          );
        }
      }
    } else {
      await Printing.layoutPdf(
        name: '${job.jobNumberCode}_Receipt',
        onLayout: (_) async => pdfBytes,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopModeControllerProvider);
    final shopCtrl = ref.read(shopModeControllerProvider.notifier);
    final presets = ref.watch(presetsControllerProvider);
    final printersState = ref.watch(printersControllerProvider);
    final jobQueueState = ref.watch(jobQueueControllerProvider);
    final locale = ref.watch(localeProvider);
    final strings = AppStrings.of(locale);
    final isSi = strings.isSi;
    final colorScheme = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: {
        // F1-F4: Switch Shop Mode tabs
        const SingleActivator(LogicalKeyboardKey.f1): () =>
            _tabController.animateTo(0),
        const SingleActivator(LogicalKeyboardKey.f2): () =>
            _tabController.animateTo(1),
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            _tabController.animateTo(2),
        const SingleActivator(LogicalKeyboardKey.f4): () =>
            _tabController.animateTo(3),
        // Ctrl+R: One-Click Reprint Last Job
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            shopCtrl.reprintLastJob(),
        // Ctrl+Enter: Print Quick Job Now
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            shopCtrl.printQuickJobNow(
              customerNameOrNumber: _customerNameCtrl.text,
              notes: _customerNotesCtrl.text,
            ),
        // Ctrl+B: Focus Barcode / Job Number scanner field
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          _tabController.animateTo(1);
          _barcodeFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Shop Header + One-Click Reprint Last Job + Keyboard Hints
              _buildShopTopHeader(
                context,
                shopState: shopState,
                shopCtrl: shopCtrl,
                isSi: isSi,
              ),
              const SizedBox(height: 12),

              // Large 4-Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.flash_on_rounded, size: 20),
                      text: isSi
                          ? '1. ක්ෂණික මුද්‍රණය (Quick Print • F1)'
                          : '1. Quick Print (F1)',
                    ),
                    Tab(
                      icon: Badge(
                        isLabelVisible: shopState.customerJobs
                            .any((j) => j.status == CustomerJobStatus.waiting),
                        label: Text(
                          '${shopState.customerJobs.where((j) => j.status == CustomerJobStatus.waiting).length}',
                        ),
                        child: const Icon(Icons.people_alt_rounded, size: 20),
                      ),
                      text: isSi
                          ? '2. පාරිභෝගික ඇණවුම් (Customer Jobs • F2)'
                          : '2. Customer Jobs & Scan (F2)',
                    ),
                    Tab(
                      icon: const Icon(Icons.dashboard_customize_rounded, size: 20),
                      text: isSi
                          ? '3. මුද්‍රණ යන්ත්‍ර පුවරුව (Printers • F3)'
                          : '3. Multi-Printer Dashboard (F3)',
                    ),
                    Tab(
                      icon: const Icon(Icons.assessment_rounded, size: 20),
                      text: isSi
                          ? '4. මිල ලැයිස්තුව සහ දෛනික වාර්තාව (F4)'
                          : '4. Prices, Costs & Daily Report (F4)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (shopState.statusBannerMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            shopState.statusBannerMessage!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuickPrintTab(
                      context,
                      shopState: shopState,
                      shopCtrl: shopCtrl,
                      presets: presets,
                      printers: printersState.printers,
                      isSi: isSi,
                    ),
                    _buildCustomerJobsTab(
                      context,
                      shopState: shopState,
                      shopCtrl: shopCtrl,
                      presets: presets,
                      printers: printersState.printers,
                      isSi: isSi,
                    ),
                    _buildMultiPrinterDashboardTab(
                      context,
                      shopState: shopState,
                      shopCtrl: shopCtrl,
                      printers: printersState.printers,
                      jobQueueState: jobQueueState,
                      isSi: isSi,
                    ),
                    _buildPricingAndDailyReportTab(
                      context,
                      shopState: shopState,
                      shopCtrl: shopCtrl,
                      isSi: isSi,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Top Header with One-Click "Reprint Last Job" Button
  // ===========================================================================

  Widget _buildShopTopHeader(
    BuildContext context, {
    required ShopModeState shopState,
    required ShopModeController shopCtrl,
    required bool isSi,
  }) {
    final theme = Theme.of(context);
    final lastJob = shopState.lastDispatchedCustomerJob ??
        (shopState.customerJobs.isNotEmpty
            ? shopState.customerJobs.first
            : null);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.storefront_rounded,
            color: theme.colorScheme.onPrimaryContainer,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSi
                    ? 'මුද්‍රණ හල් ප්‍රකාරය (Shop Mode — 3-Step Fast Counter)'
                    : 'Shop Mode — Fast Counter Print & Billing',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                isSi
                    ? 'පියවර 3 කින් මුද්‍රණය කරන්න: 1. ගොනු දමන්න → 2. පෙර-සැකසුම තෝරන්න → 3. මුද්‍රණය කරන්න (Ctrl+Enter)'
                    : '3 simple steps: 1. Drop Files → 2. Choose Preset → 3. Print (Ctrl+Enter) • Scan Barcode (Ctrl+B)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // ONE-CLICK REPRINT LAST JOB BUTTON
        FilledButton.tonalIcon(
          onPressed: lastJob == null ? null : () => shopCtrl.reprintLastJob(),
          icon: const Icon(Icons.replay_rounded, size: 20),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          label: Text(
            lastJob == null
                ? (isSi
                    ? 'අවසන් මුද්‍රණය නැවත ගන්න (Reprint Last)'
                    : 'Reprint Last Job (None yet)')
                : (isSi
                    ? 'නැවත මුද්‍රණය: ${lastJob.jobNumberCode} (${lastJob.customerNameOrPhone})'
                    : 'Reprint Last: ${lastJob.jobNumberCode} (${lastJob.customerNameOrPhone}) • Ctrl+R'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 1: Quick Print (3 Steps: Drop -> Preset -> Printer & Print + Price Box)
  // ===========================================================================

  Widget _buildQuickPrintTab(
    BuildContext context, {
    required ShopModeState shopState,
    required ShopModeController shopCtrl,
    required List<PrintPreset> presets,
    required List<PrinterDevice> printers,
    required bool isSi,
  }) {
    final theme = Theme.of(context);
    final estimate = shopCtrl.calculateCurrentQuickPrintEstimate();
    final resolvedRoute = shopCtrl.resolveCurrentQuickPrintRoute();
    final cur = estimate.currencyCode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Step 1 (Drop Files) & Step 2 (Large Preset Buttons)
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // STEP 1: DROP OR ADD FILES
              Expanded(
                flex: 5,
                child: DropTarget(
                  onDragDone: (details) {
                    shopCtrl.addFilesToQuickPrint(
                      details.files.map((x) => x.path).toList(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStepBadge(context, '1'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isSi
                                    ? 'ගොනු මෙතැනට දමන්න (Drop Files Here)'
                                    : 'Step 1 — Drop Customer Files',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: shopCtrl.pickAndAddQuickPrintFiles,
                              icon: const Icon(Icons.add_circle_outline_rounded),
                              label: Text(
                                isSi ? 'ගොනු තෝරන්න' : 'Browse Files',
                              ),
                            ),
                            if (shopState.quickPrintFiles.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: shopCtrl.clearQuickPrintFiles,
                                icon: const Icon(Icons.clear_all_rounded),
                                label: Text(isSi ? 'ඉවත් කරන්න' : 'Clear'),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: shopState.quickPrintFiles.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.upload_file_rounded,
                                        size: 46,
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.65),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        isSi
                                            ? 'PDF, රූප (JPG/PNG), හෝ පෙළ ගොනු මෙතැනට ඇද දමන්න'
                                            : 'Drag & drop PDFs, Photos, or Documents here to price & print immediately',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: shopState.quickPrintFiles.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 8),
                                  itemBuilder: (ctx, idx) {
                                    final item = shopState.quickPrintFiles[idx];
                                    final s = item.settings;
                                    return Row(
                                      children: [
                                        const Icon(
                                          Icons.insert_drive_file_outlined,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${item.fileName} (${item.pageCount} pages)',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        // Quick Copies +/- buttons
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: s.copies > 1
                                              ? () => shopCtrl
                                                  .updateQuickPrintFileSettings(
                                                    item.id,
                                                    s.copyWith(
                                                      copies: s.copies - 1,
                                                    ),
                                                  )
                                              : null,
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 18,
                                          ),
                                        ),
                                        Text(
                                          '${s.copies}x',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () =>
                                              shopCtrl.updateQuickPrintFileSettings(
                                            item.id,
                                            s.copyWith(copies: s.copies + 1),
                                          ),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 18,
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => shopCtrl
                                              .removeQuickPrintFile(item.id),
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // STEP 2: CHOOSE SAVED PRESET (Large 1-Click Cards)
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildStepBadge(context, '2'),
                          const SizedBox(width: 8),
                          Text(
                            isSi
                                ? 'පෙර-සැකසුමක් තෝරන්න (Step 2 — Choose Preset)'
                                : 'Step 2 — Choose Saved Preset (1-Click)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.6,
                          ),
                          itemCount: presets.length,
                          itemBuilder: (ctx, idx) {
                            final preset = presets[idx];
                            final isSelected =
                                preset.id == shopState.selectedPresetId;
                            final isColor = preset.settings.isColor;
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () =>
                                  shopCtrl.selectQuickPrintPreset(preset.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isColor
                                          ? Icons.palette_rounded
                                          : Icons.contrast_rounded,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            preset.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: isSelected
                                                  ? theme.colorScheme
                                                      .onPrimaryContainer
                                                  : null,
                                            ),
                                          ),
                                          Text(
                                            '${preset.settings.paperSize} • ${preset.settings.duplex == DuplexMode.none ? "1-Sided" : "2-Sided"}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Right Column: STEP 3 (Printer Selection + Instant Price/Profit Calculator + Big PRINT Button)
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _buildStepBadge(context, '3'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSi
                            ? 'මුද්‍රණ යන්ත්‍රය සහ මිල ගණන (Step 3 — Printer & Total)'
                            : 'Step 3 — Printer, Price & Print',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Smart Auto-Routed Printer + Manual Override Dropdown
                DropdownButtonFormField<String?>(
                  value: printers.any((p) =>
                          p.systemName == shopState.manualOverridePrinterName)
                      ? shopState.manualOverridePrinterName
                      : null,
                  decoration: InputDecoration(
                    labelText: isSi
                        ? 'මුද්‍රණ යන්ත්‍රය (Auto-Routed හෝ තෝරන්න)'
                        : 'Target Printer (Auto-Routed or Override)',
                    helperText: isSi
                        ? '${resolvedRoute.reasonSi} → ${resolvedRoute.targetPrinterSystemName}'
                        : '${resolvedRoute.reasonEn} → ${resolvedRoute.targetPrinterSystemName}',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        isSi
                            ? 'ස්වයංක්‍රීය යොමුව (${resolvedRoute.targetPrinterSystemName})'
                            : 'Auto-Route (${resolvedRoute.targetPrinterSystemName})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...printers.map(
                      (p) => DropdownMenuItem<String?>(
                        value: p.systemName,
                        child: Text(p.displayName),
                      ),
                    ),
                  ],
                  onChanged: shopCtrl.setQuickPrintManualPrinterOverride,
                ),
                const SizedBox(height: 10),

                // Customer Name/Number + Optional Discount Row
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _customerNameCtrl,
                        decoration: InputDecoration(
                          labelText: isSi
                              ? 'පාරිභෝගික නම / අංකය'
                              : 'Customer Name / Token #',
                          hintText: 'Walk-in / 077-xxxxxxx',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              isSi ? 'වට්ටම ($cur)' : 'Discount ($cur)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          shopCtrl.setQuickPrintDiscount(
                            flatAmount: double.tryParse(val) ?? 0.0,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // LIVE PRICE & ESTIMATED PROFIT BOX
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSi ? 'මුළු පිටු / කොළ:' : 'Total Pages / Sheets:',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            '${estimate.totalImpressions} impressions (${estimate.totalPhysicalSheets} sheets)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (estimate.discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isSi ? 'වට්ටම (Discount):' : 'Discount:',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '-$cur ${estimate.discountAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSi ? 'මුළු ගාස්තුව (TOTAL):' : 'CUSTOMER TOTAL:',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$cur ${estimate.finalCustomerTotal.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSi
                                ? 'ඇස්තමේන්තුගත වියදම (Cost estimate):'
                                : 'Supply Cost (estimate):',
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(
                            '$cur ${estimate.estimatedTotalSupplyCost.toStringAsFixed(2)} (estimate)',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSi
                                ? 'ඇස්තමේන්තුගත ලාභය (Profit estimate):'
                                : 'Net Profit (estimate):',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                          Text(
                            '$cur ${estimate.estimatedProfit.toStringAsFixed(2)} (estimate)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // HUGE 1-CLICK PRINT BUTTON
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: shopState.quickPrintFiles.isEmpty
                        ? null
                        : () async {
                            final job = await shopCtrl.printQuickJobNow(
                              customerNameOrNumber: _customerNameCtrl.text,
                              notes: _customerNotesCtrl.text,
                            );
                            if (job != null) {
                              _customerNameCtrl.clear();
                              _customerNotesCtrl.clear();
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 26),
                    label: Text(
                      isSi
                          ? 'දැන් මුද්‍රණය කරන්න (PRINT NOW • $cur ${estimate.finalCustomerTotal.toStringAsFixed(0)})'
                          : 'PRINT NOW ($cur ${estimate.finalCustomerTotal.toStringAsFixed(2)}) • Ctrl+Enter',
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Secondary row: Save as Waiting Customer Job OR Print Receipt for Last Job
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: shopState.quickPrintFiles.isEmpty
                            ? null
                            : () async {
                                await shopCtrl
                                    .saveQuickQueueAsWaitingCustomerJob(
                                  customerNameOrPhone: _customerNameCtrl.text,
                                  notes: _customerNotesCtrl.text,
                                );
                                _customerNameCtrl.clear();
                              },
                        icon: const Icon(Icons.schedule_rounded, size: 18),
                        label: Text(
                          isSi
                              ? 'පෝලිමේ තබන්න (Save Waiting)'
                              : 'Queue as Waiting Job',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: shopState.lastDispatchedCustomerJob == null
                            ? null
                            : () => _printOrSaveReceiptPdf(
                                  shopState.lastDispatchedCustomerJob!,
                                  shopCtrl,
                                  shopState,
                                  false,
                                ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: Text(
                          isSi
                              ? 'රිසිට්පත (Print Receipt)'
                              : 'Receipt PDF (Last Job)',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: Customer Jobs, Barcode/QR Scanner & Drop Folders Intake
  // ===========================================================================

  Widget _buildCustomerJobsTab(
    BuildContext context, {
    required ShopModeState shopState,
    required ShopModeController shopCtrl,
    required List<PrintPreset> presets,
    required List<PrinterDevice> printers,
    required bool isSi,
  }) {
    final theme = Theme.of(context);
    final jobs = shopState.filteredCustomerJobs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barcode/QR Scanner Input + Status Filter Chips + Customer Drop Folders button
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: _barcodeSearchCtrl,
                focusNode: _barcodeFocusNode,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                  labelText: isSi
                      ? 'තීරු කේතය (Barcode / QR) හෝ ඇණවුම් අංකය (JOB-1001) සොයන්න (Ctrl+B)'
                      : 'Scan Barcode / QR or Search Job # / Customer (Ctrl+B)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _barcodeSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _barcodeSearchCtrl.clear();
                            shopCtrl.setBarcodeOrJobSearchQuery('');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        )
                      : null,
                ),
                onChanged: shopCtrl.setBarcodeOrJobSearchQuery,
              ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 6,
              children: [
                FilterChip(
                  label: Text(isSi ? 'සියල්ල (All)' : 'All'),
                  selected: shopState.statusFilter == null,
                  onSelected: (_) => shopCtrl.setCustomerJobStatusFilter(null),
                ),
                ...CustomerJobStatus.values.map((st) {
                  return FilterChip(
                    label: Text(isSi ? st.labelSi : st.labelEn),
                    selected: shopState.statusFilter == st,
                    onSelected: (_) => shopCtrl.setCustomerJobStatusFilter(st),
                  );
                }),
              ],
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: () => _showCustomerDropFoldersDialog(
                context,
                shopState: shopState,
                shopCtrl: shopCtrl,
                presets: presets,
                isSi: isSi,
              ),
              icon: const Icon(Icons.folder_special_rounded, size: 18),
              label: Text(
                isSi ? 'ස්වයංක්‍රීය ෆෝල්ඩර (Drop Folders)' : 'Drop Folders',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Customer Jobs List
        Expanded(
          child: jobs.isEmpty
              ? Center(
                  child: Text(
                    isSi
                        ? 'පාරිභෝගික ඇණවුම් කිසිවක් හමු නොවීය.'
                        : 'No customer jobs match the current filter.',
                    style: theme.textTheme.bodyLarge,
                  ),
                )
              : ListView.separated(
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final job = jobs[idx];
                    final est = shopCtrl.pricingService.calculateJobEstimate(
                      files: job.files,
                      priceRules: shopState.priceRules,
                      costConfig: shopState.supplyCostConfig,
                      flatDiscountAmount: job.discountAmount,
                      discountPercent: job.discountPercent,
                    );

                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: job.status.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    job.status.icon,
                                    color: job.status.color,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    job.jobNumberCode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: job.status.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Customer Details & Files
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${job.customerNameOrPhone} • ${job.files.length} file(s) (${est.totalImpressions} pages)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Printer: ${job.assignedPrinterSystemName} • ${job.files.map((f) => f.fileName).join(", ")}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (job.notes.isNotEmpty)
                                    Text(
                                      'Note: ${job.notes}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Total & Profit (estimate)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${est.currencyCode} ${est.finalCustomerTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Profit: ${est.currencyCode} ${est.estimatedProfit.toStringAsFixed(2)} (estimate)',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Status Transition Dropdown (Waiting -> Printing -> Done -> Picked up)
                            DropdownButton<CustomerJobStatus>(
                              value: job.status,
                              onChanged: (next) {
                                if (next != null) {
                                  shopCtrl.updateCustomerJobStatus(
                                    job.id,
                                    next,
                                  );
                                }
                              },
                              items: CustomerJobStatus.values.map((st) {
                                return DropdownMenuItem(
                                  value: st,
                                  child: Text(isSi ? st.labelSi : st.labelEn),
                                );
                              }).toList(),
                            ),
                            const SizedBox(width: 6),

                            // Receipt PDF Print & Save
                            IconButton(
                              tooltip: isSi
                                  ? 'කුවිතාන්සිය මුද්‍රණය කරන්න (Print Receipt)'
                                  : 'Print Receipt / Invoice PDF',
                              onPressed: () => _printOrSaveReceiptPdf(
                                job,
                                shopCtrl,
                                shopState,
                                false,
                              ),
                              icon: const Icon(Icons.receipt_long_rounded),
                            ),
                            IconButton(
                              tooltip: isSi
                                  ? 'කුවිතාන්සිය PDF ලෙස සුරකින්න'
                                  : 'Save Receipt PDF',
                              onPressed: () => _printOrSaveReceiptPdf(
                                job,
                                shopCtrl,
                                shopState,
                                true,
                              ),
                              icon: const Icon(Icons.save_alt_rounded),
                            ),
                            IconButton(
                              tooltip: isSi ? 'නැවත මුද්‍රණය කරන්න' : 'Reprint Job',
                              onPressed: () => shopCtrl.reprintCustomerJob(job),
                              icon: const Icon(Icons.replay_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: Multi-Printer Animated Dashboard & Smart Routing Rules
  // ===========================================================================

  Widget _buildMultiPrinterDashboardTab(
    BuildContext context, {
    required ShopModeState shopState,
    required ShopModeController shopCtrl,
    required List<PrinterDevice> printers,
    required JobQueueState jobQueueState,
    required bool isSi,
  }) {
    final theme = Theme.of(context);
    final intelService = ref.watch(printerIntelligenceServiceProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);
    final rules = shopState.routingRules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Printer Routing Rules Bar
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.alt_route_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSi
                            ? 'ස්වයංක්‍රීය මුද්‍රණ යොමු කිරීමේ නීති (Automatic Printer Routing Rules)'
                            : 'Automatic Printer Routing Rules (Color / B&W / Photo / Big Jobs)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Switch(
                      value: rules.autoRoutingEnabled,
                      onChanged: (v) => shopCtrl.updateRoutingRules(
                        rules.copyWith(autoRoutingEnabled: v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildRouteRuleDropdown(
                        context,
                        label: isSi ? 'වර්ණ (Color Jobs)' : 'Color Jobs →',
                        value: rules.colorPrinterSystemName,
                        printers: printers,
                        onChanged: (v) => shopCtrl.updateRoutingRules(
                          rules.copyWith(colorPrinterSystemName: v ?? ''),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildRouteRuleDropdown(
                        context,
                        label: isSi ? 'කළු-සුදු (B&W Jobs)' : 'B&W / Mono Jobs →',
                        value: rules.monoPrinterSystemName,
                        printers: printers,
                        onChanged: (v) => shopCtrl.updateRoutingRules(
                          rules.copyWith(monoPrinterSystemName: v ?? ''),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildRouteRuleDropdown(
                        context,
                        label: isSi ? 'ඡායාරූප (Photos)' : 'Photo Jobs →',
                        value: rules.photoPrinterSystemName,
                        printers: printers,
                        onChanged: (v) => shopCtrl.updateRoutingRules(
                          rules.copyWith(photoPrinterSystemName: v ?? ''),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildRouteRuleDropdown(
                        context,
                        label: isSi
                            ? 'විශාල ඇණවුම් (≥${rules.largeJobPageThreshold}p)'
                            : 'Big Jobs (≥${rules.largeJobPageThreshold}p) →',
                        value: rules.fastestHighVolumePrinterSystemName,
                        printers: printers,
                        onChanged: (v) => shopCtrl.updateRoutingRules(
                          rules.copyWith(
                            fastestHighVolumePrinterSystemName: v ?? '',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Multi-Printer Animated Grid Overview
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.75,
            ),
            itemCount: printers.length,
            itemBuilder: (ctx, idx) {
              final printer = printers[idx];
              final intel = intelService.getCached(printer.systemName);
              final queueLen = jobQueueState.activeJobs
                  .where((j) =>
                      j.targetPrinterSystemName == printer.systemName &&
                      !j.isTerminal)
                  .length;
              final hasLowSupply = intel?.supplies.value
                      ?.any((m) => m.isLow || m.isEmpty) ??
                  (printer.status == PrinterStatusType.tonerLow);

              return AnimatedContainer(
                duration: AppMotion.duration(
                  AppMotion.mediumDuration,
                  reduceMotion: reduceMotion,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasLowSupply
                        ? const Color(0xFFD97706)
                        : theme.colorScheme.outlineVariant,
                    width: hasLowSupply ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.print_rounded,
                          color: printer.isAvailableForPrinting
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            printer.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isSi ? 'පෝලිම: $queueLen' : 'Queue: $queueLen jobs',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Paper Loaded: ${intel?.readyPaperSizes.formatOrNotReported((l) => l.join(", ")) ?? printer.capabilities.paperSizes.map((p) => p.name).take(3).join(", ")}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (hasLowSupply)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 15,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSi
                                  ? 'අවවාදයයි: තීන්ත / ටෝනර් අඩු මට්ටමක පවතී!'
                                  : 'Alert: Low Ink / Toner reported',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFFD97706),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    // Supply mini-bars
                    if (intel != null &&
                        intel.supplies.isReported &&
                        intel.supplies.value != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: intel.supplies.value!.take(5).map((m) {
                          final txt = m.levelPercent.isReported &&
                                  m.levelPercent.value != null
                              ? '${m.name}: ${m.levelPercent.value}%'
                              : '${m.name}: ${m.qualitativeStatus.value?.labelEn ?? "Not reported"}';
                          return Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              txt,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Text(
                        isSi
                            ? 'සජීවී තීන්ත මට්ටම් පූරණය කිරීමට යාවත්කාලීන කරන්න'
                            : 'Click Refresh to poll live IPP/SNMP supply levels',
                        style: theme.textTheme.labelSmall,
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            intelService.fetchIntelligence(printer),
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: Text(isSi ? 'යාවත්කාලීන කරන්න' : 'Poll Now'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRouteRuleDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<PrinterDevice> printers,
    required ValueChanged<String?> onChanged,
  }) {
    final validVal =
        printers.any((p) => p.systemName == value) ? value : '';
    return DropdownButtonFormField<String>(
      value: validVal,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(
          value: '',
          child: Text('Auto Detect'),
        ),
        ...printers.map(
          (p) => DropdownMenuItem(
            value: p.systemName,
            child: Text(
              p.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  // ===========================================================================
  // TAB 4: Editable Price List, Supply Cost Tracker & Daily Report Export
  // ===========================================================================

  Widget _buildPricingAndDailyReportTab(
    BuildContext context, {
    required ShopModeState shopState,
    required ShopModeController shopCtrl,
    required bool isSi,
  }) {
    final theme = Theme.of(context);
    final summary = shopCtrl.buildCurrentDailyReport();
    final cur = shopState.supplyCostConfig.currencyCode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Editable Price List & Supply Cost Config
        Expanded(
          flex: 6,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isSi
                            ? 'පිටුවක මිල ලැයිස්තුව (Editable Price List • $cur)'
                            : 'Per-Page Price List ($cur)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      DropdownButton<String>(
                        value: cur,
                        items: const ['LKR', 'USD', 'EUR', 'INR', 'GBP']
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text('Currency: $c'),
                                ))
                            .toList(),
                        onChanged: (nextCur) {
                          if (nextCur != null) {
                            shopCtrl.updateSupplyCostConfig(
                              shopState.supplyCostConfig
                                  .copyWith(currencyCode: nextCur),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: shopState.priceRules.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (ctx, idx) {
                        final rule = shopState.priceRules[idx];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            isSi ? rule.labelSi : rule.labelEn,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${rule.paperSize} • ${rule.isColor ? "Color" : "B&W"} • ${rule.isDoubleSided ? "2-Sided" : "1-Sided"} • ${rule.mediaType}',
                          ),
                          trailing: OutlinedButton.icon(
                            onPressed: () => _showEditPriceRuleDialog(
                              context,
                              rule: rule,
                              currency: cur,
                              shopCtrl: shopCtrl,
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 15),
                            label: Text(
                              '$cur ${rule.pricePerPage.toStringAsFixed(2)} / page',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  // Supply Cost Config summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isSi
                              ? 'ඇස්තමේන්තුගත වියදම්: කළු පිටුවකට $cur ${shopState.supplyCostConfig.estimatedBlackInkCostPerPage.toStringAsFixed(2)} • වර්ණ $cur ${shopState.supplyCostConfig.estimatedColorInkCostPerPage.toStringAsFixed(2)} • A4 කොළයකට $cur ${shopState.supplyCostConfig.estimatedA4PlainSheetCost.toStringAsFixed(2)} (estimate)'
                              : 'Estimated Costs: B&W Ink $cur ${shopState.supplyCostConfig.estimatedBlackInkCostPerPage.toStringAsFixed(2)}/p • Color Ink $cur ${shopState.supplyCostConfig.estimatedColorInkCostPerPage.toStringAsFixed(2)}/p • A4 Sheet $cur ${shopState.supplyCostConfig.estimatedA4PlainSheetCost.toStringAsFixed(2)} (estimate)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _showSupplyCostEditorDialog(
                          context,
                          config: shopState.supplyCostConfig,
                          shopCtrl: shopCtrl,
                          isSi: isSi,
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: Text(
                          isSi ? 'තීන්ත/කඩදාසි මිල' : 'Edit Supply Costs',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Right: Daily Report Card + CSV / PDF Export
        Expanded(
          flex: 5,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isSi
                        ? 'දෛනික වාර්තාව (Daily Shop Report — Offline)'
                        : 'Daily Report (Jobs, Pages, Revenue & Profit)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReportMetricRow(
                    isSi ? 'මුළු ඇණවුම් ගණන (Total Jobs):' : 'Total Customer Jobs:',
                    '${summary.totalJobsCount} (${summary.completedOrPickedUpJobsCount} completed)',
                  ),
                  _buildReportMetricRow(
                    isSi ? 'මුළු මුද්‍රිත පිටු (Total Pages):' : 'Total Pages Printed:',
                    '${summary.totalImpressions} pages',
                  ),
                  _buildReportMetricRow(
                    isSi ? 'පිටු වර්ගීකරණය (By Type):' : 'Pages by Type:',
                    'B&W: ${summary.bwPagesCount} • Color: ${summary.colorPagesCount} • Photo: ${summary.photoPagesCount}',
                  ),
                  _buildReportMetricRow(
                    isSi ? 'භාවිතා කළ කඩදාසි (Sheets Used):' : 'Physical Sheets Used:',
                    'A4: ${summary.a4SheetsUsed} • A3: ${summary.a3SheetsUsed} • 4x6 Photo: ${summary.photo4x6SheetsUsed}',
                  ),
                  const Divider(height: 22),
                  _buildReportMetricRow(
                    isSi ? 'මුළු ආදායම (Total Revenue):' : 'Total Revenue:',
                    '$cur ${summary.totalRevenue.toStringAsFixed(2)}',
                    highlight: true,
                  ),
                  _buildReportMetricRow(
                    isSi
                        ? 'ඇස්තමේන්තුගත වියදම (Supply Cost — estimate):'
                        : 'Supply Cost (Ink/Toner + Paper — estimate):',
                    '$cur ${summary.estimatedTotalSupplyCost.toStringAsFixed(2)} (estimate)',
                  ),
                  _buildReportMetricRow(
                    isSi
                        ? 'ඇස්තමේන්තුගත ශුද්ධ ලාභය (Net Profit — estimate):'
                        : 'Estimated Net Profit (estimate):',
                    '$cur ${summary.estimatedNetProfit.toStringAsFixed(2)} (estimate)',
                    highlight: true,
                    color: const Color(0xFF16A34A),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            final path = await FilePicker.platform.saveFile(
                              dialogTitle: 'Export Daily Report CSV',
                              fileName:
                                  'Shop_Daily_Report_${summary.date.toIso8601String().substring(0, 10)}.csv',
                              type: FileType.custom,
                              allowedExtensions: const ['csv'],
                            );
                            if (path != null) {
                              await shopCtrl.pricingService
                                  .exportDailyReportCsv(
                                summary: summary,
                                priceRules: shopState.priceRules,
                                costConfig: shopState.supplyCostConfig,
                                targetPath: path,
                              );
                            }
                          },
                          icon: const Icon(Icons.table_view_rounded),
                          label: Text(isSi ? 'CSV නිර්යාත කරන්න' : 'Export CSV'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final path = await FilePicker.platform.saveFile(
                              dialogTitle: 'Export Daily Report PDF',
                              fileName:
                                  'Shop_Daily_Report_${summary.date.toIso8601String().substring(0, 10)}.pdf',
                              type: FileType.custom,
                              allowedExtensions: const ['pdf'],
                            );
                            if (path != null) {
                              await shopCtrl.pricingService
                                  .exportDailyReportPdf(
                                summary: summary,
                                costConfig: shopState.supplyCostConfig,
                                targetPath: path,
                              );
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: Text(isSi ? 'PDF නිර්යාත කරන්න' : 'Export PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportMetricRow(
    String label,
    String value, {
    bool highlight = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
              fontSize: highlight ? 15 : 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBadge(BuildContext context, String stepNumber) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        stepNumber,
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _showEditPriceRuleDialog(
    BuildContext context, {
    required ShopPriceRule rule,
    required String currency,
    required ShopModeController shopCtrl,
  }) async {
    final ctrl =
        TextEditingController(text: rule.pricePerPage.toStringAsFixed(2));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Rate — ${rule.labelEn}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Price per page ($currency)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final nextPrice = double.tryParse(ctrl.text) ?? rule.pricePerPage;
              await shopCtrl.updatePriceRule(
                rule.copyWith(pricePerPage: nextPrice),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupplyCostEditorDialog(
    BuildContext context, {
    required ShopSupplyCostConfig config,
    required ShopModeController shopCtrl,
    required bool isSi,
  }) async {
    final shopNameCtrl = TextEditingController(text: config.shopName);
    final blackPriceCtrl =
        TextEditingController(text: config.blackSupplyPrice.toStringAsFixed(0));
    final blackYieldCtrl =
        TextEditingController(text: '${config.blackSupplyPageYield}');
    final colorPriceCtrl = TextEditingController(
        text: config.colorSupplySetPrice.toStringAsFixed(0));
    final colorYieldCtrl =
        TextEditingController(text: '${config.colorSupplySetPageYield}');
    final a4ReamCtrl =
        TextEditingController(text: config.a4PlainReam500Price.toStringAsFixed(0));

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isSi
              ? 'තීන්ත සහ කඩදාසි වියදම් සැකසුම් (Cost Estimate Settings)'
              : 'Supply Cost Settings (For Profit Estimate)',
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: shopNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop Name (on Receipt PDF)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: blackPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'Black Bottle/Toner (${config.currencyCode})',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: blackYieldCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Black Page Yield',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: colorPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'CMY Color Set (${config.currencyCode})',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: colorYieldCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Color Set Page Yield',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: a4ReamCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      'A4 Paper Ream (500 Sheets) Price (${config.currencyCode})',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await shopCtrl.updateSupplyCostConfig(
                config.copyWith(
                  shopName: shopNameCtrl.text.trim(),
                  blackSupplyPrice: double.tryParse(blackPriceCtrl.text),
                  blackSupplyPageYield: int.tryParse(blackYieldCtrl.text),
                  colorSupplySetPrice: double.tryParse(colorPriceCtrl.text),
                  colorSupplySetPageYield: int.tryParse(colorYieldCtrl.text),
                  a4PlainReam500Price: double.tryParse(a4ReamCtrl.text),
                ),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save Costs'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomerDropFoldersDialog(
    BuildContext context, {
    required ShopModeState shopState,
    required ShopModeController shopCtrl,
    required List<PrintPreset> presets,
    required bool isSi,
  }) async {
    final cfg = shopState.customerDropFoldersConfig;
    bool enabled = cfg.enabled;
    String folderPath = cfg.rootDropDirectoryPath;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            isSi
                ? 'පාරිභෝගික ෆෝල්ඩර නිරීක්ෂකය (Customer Drop Folders)'
                : 'Customer Drop Folders Intake',
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSi
                      ? 'මෙම ප්‍රධාන ෆෝල්ඩරය තුළ ඇති එක් එක් පාරිභෝගික උප-ෆෝල්ඩරය (උදා: "Kamal_077123/") ස්වයංක්‍රීයව පාරිභෝගික ඇණවුමක් ලෙස එක් කෙරේ.'
                      : 'Each subfolder inside this root directory (e.g. "Nimal_0771234567/") is automatically imported as a Customer Job in Waiting status.',
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Customer Drop Folders Watcher'),
                  value: enabled,
                  onChanged: (v) => setModalState(() => enabled = v),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        folderPath.isEmpty
                            ? 'No root folder chosen'
                            : folderPath,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final chosen =
                            await FilePicker.platform.getDirectoryPath();
                        if (chosen != null) {
                          setModalState(() => folderPath = chosen);
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: const Text('Choose Folder'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                await shopCtrl.updateCustomerDropFoldersConfig(
                  cfg.copyWith(
                    enabled: enabled,
                    rootDropDirectoryPath: folderPath,
                  ),
                );
                await shopCtrl.scanCustomerDropFoldersNow();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save & Scan Now'),
            ),
          ],
        ),
      ),
    );
  }
}
