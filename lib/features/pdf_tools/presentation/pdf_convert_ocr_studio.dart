import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/integration/global_command_palette_and_recent_files.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../services/components/local_component_manager.dart';
import '../domain/pdf_convert_ocr_models.dart';
import 'pdf_convert_ocr_controller.dart';

class PdfConvertOcrStudio extends ConsumerWidget {
  const PdfConvertOcrStudio({super.key});

  Future<void> _pickFilesForConversion(
    BuildContext context,
    PdfConvertOcrController ctrl,
  ) async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    final paths = res.files
        .map((f) => f.path)
        .whereType<String>()
        .toList();
    if (paths.isNotEmpty) {
      await ctrl.addFilesToBatchQueue(paths);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final strings = AppStrings.of(lang);
    final state = ref.watch(pdfConvertOcrControllerProvider);
    final ctrl = ref.read(pdfConvertOcrControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Sub-Navigation Bar: Convert Wizard & Batch Queue vs. Tesseract OCR & WIA Scanner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.transform_rounded, size: 18),
                    label: Text(
                      strings.isSi
                          ? 'ගොනු පරිවර්තනය (Convert Wizard & Batch Queue)'
                          : 'Convert Wizard & Batch Queue',
                    ),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.document_scanner_rounded, size: 18),
                    label: Text(
                      strings.isSi
                          ? 'සිංහල + ඉංග්‍රීසි OCR සහ ස්කෑනරය (Tesseract + WIA)'
                          : 'Tesseract OCR (sin + eng) & WIA Scanner',
                    ),
                  ),
                ],
                selected: {state.activeSubTabIndex},
                onSelectionChanged: (sel) => ctrl.setSubTab(sel.first),
              ),
              if (state.statusMessage != null)
                Chip(
                  avatar: const Icon(Icons.info_outline_rounded, size: 16),
                  label: Text(
                    state.statusMessage!,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: state.activeSubTabIndex == 0
              ? _buildConvertWizardAndBatchQueue(
                  context,
                  ref,
                  state,
                  ctrl,
                  strings,
                )
              : _buildOcrAndScannerWorkspace(
                  context,
                  ref,
                  state,
                  ctrl,
                  strings,
                ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Sub-Tab 0: Convert Wizard & Batch Conversion Queue
  // ==========================================================================

  Widget _buildConvertWizardAndBatchQueue(
    BuildContext context,
    WidgetRef ref,
    PdfConvertOcrState state,
    PdfConvertOcrController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedFmt = state.selectedTargetFormat;
    final hasAnyLegacySinhala = state.batchQueue.any(
      (i) => i.legacySinhalaDetection?.hasLegacySinhalaEncoding ?? false,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Panel (380px): 4-Step Convert Wizard Controls + Expected Quality Note
        Container(
          width: 390,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.isSi
                      ? '1. ගොනු එක් කරන්න (Drop / Select Files)'
                      : '1. Drop or Select Files',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _pickFilesForConversion(context, ctrl),
                      icon: const Icon(Icons.upload_file_rounded, size: 17),
                      label: Text(
                        strings.isSi ? 'ගොනු තෝරන්න' : 'Add Files to Queue',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ctrl.addFilesToBatchQueue(<String>[
                        'scanned_sinhala_circular.pdf',
                      ]),
                      icon: const Icon(Icons.scanner_rounded, size: 16),
                      label: Text(
                        strings.isSi ? 'ස්කෑන් PDF නිදසුන' : '+ Scanned PDF Sample',
                      ),
                    ),
                  ],
                ),
                const Divider(height: 22),

                // Step 2: Target Format Selector
                Text(
                  strings.isSi
                      ? '2. ඉලක්කගත ආකෘතිය (Target Format)'
                      : '2. Choose Target Format',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ConvertTargetFormat>(
                  value: selectedFmt,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: ConvertTargetFormat.values.map((fmt) {
                    return DropdownMenuItem(
                      value: fmt,
                      child: Text(
                        strings.isSi ? fmt.labelSi : fmt.labelEn,
                        style: const TextStyle(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) ctrl.selectTargetFormat(val);
                  },
                ),
                const SizedBox(height: 10),

                // Honest "Expected Quality" Card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            strings.isSi
                                ? 'අපේක්ෂිත ගුණාත්මකභාවය (${selectedFmt.qualityRatingStars}/5 ★)'
                                : 'Expected Quality Note (${selectedFmt.qualityRatingStars}/5 ★)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.isSi
                            ? selectedFmt.expectedQualityNoteSi
                            : selectedFmt.expectedQualityNoteEn,
                        style: const TextStyle(fontSize: 11.5, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 22),

                // Step 3: Engine & Sinhala / Scanned PDF Options
                Text(
                  strings.isSi
                      ? '3. එන්ජිම සහ විකල්ප (Engine & Options)'
                      : '3. Conversion Engine & Options',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ConversionEngineKind>(
                  value: state.jobOptions.preferredEngine,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: ConversionEngineKind.values.map((eng) {
                    return DropdownMenuItem(
                      value: eng,
                      child: Text(
                        strings.isSi ? eng.labelSi : eng.labelEn,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (eng) {
                    if (eng != null) {
                      ctrl.updateJobOptions(
                        state.jobOptions.copyWith(preferredEngine: eng),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),

                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    strings.isSi
                        ? 'ස්කෑන් කළ PDF සඳහා පළමුව OCR ක්‍රියාත්මක කරන්න'
                        : 'Scanned PDFs: Run OCR (sin+eng) first so output is editable',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: state.jobOptions.autoRunOcrOnScannedPdf,
                  onChanged: (v) => ctrl.updateJobOptions(
                    state.jobOptions.copyWith(autoRunOcrOnScannedPdf: v),
                  ),
                ),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    strings.isSi
                        ? 'පැරණි සිංහල අකුරු (FM Abhaya / DL-Manel) Unicode බවට හරවන්න'
                        : 'Convert Legacy Sinhala (FM Abhaya / DL-Manel) to Unicode',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: state.jobOptions.transcodeLegacySinhalaToUnicode,
                  onChanged: (v) => ctrl.updateJobOptions(
                    state.jobOptions.copyWith(transcodeLegacySinhalaToUnicode: v),
                  ),
                ),

                // Format-specific controls for PDF <-> Images
                if (selectedFmt == ConvertTargetFormat.pdfToImages) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: state.jobOptions.imageFormat,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Image Format',
                            border: OutlineInputBorder(),
                          ),
                          items: const ['png', 'jpg', 'tiff', 'bmp', 'webp']
                              .map(
                                (fmt) => DropdownMenuItem(
                                  value: fmt,
                                  child: Text(fmt.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              ctrl.updateJobOptions(
                                state.jobOptions.copyWith(imageFormat: v),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: state.jobOptions.imageDpi,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Render DPI',
                            border: OutlineInputBorder(),
                          ),
                          items: const [150, 300, 600]
                              .map(
                                (dpi) => DropdownMenuItem(
                                  value: dpi,
                                  child: Text('$dpi DPI'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              ctrl.updateJobOptions(
                                state.jobOptions.copyWith(imageDpi: v),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: state.isBatchRunning
                      ? null
                      : ctrl.runBatchConversionQueue,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    strings.isSi
                        ? '4. සියලු ගොනු පරිවර්තනය කරන්න (Convert Queue)'
                        : '4. Convert All Queued Files',
                  ),
                ),
                if (state.isBatchRunning) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: ctrl.cancelActiveJob,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(strings.isSi ? 'අවලංගු කරන්න' : 'Cancel Job'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: ctrl.runConversionBenchmarkSuite,
                  icon: const Icon(Icons.fact_check_outlined, size: 17),
                  label: Text(
                    strings.isSi
                        ? 'ආකෘති 17 පරීක්ෂණ වගුව ක්‍රියාත්මක කරන්න'
                        : 'Run 17-Format Sample Test Suite',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Right Panel: Warnings (Missing LibreOffice / Legacy FM Abhaya) + Batch Queue + Test Suite Table
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Missing LibreOffice Component Banner with 1-Click Offline Installer
              if (state.missingLibreOfficeError)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade600),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.isSi
                              ? 'LibreOffice Headless අංගය ස්ථාපනය කර නොමැත. Offline පැකේජය මගින් එක් ක්ලික් කිරීමකින් ස්ථාපනය කරන්න.'
                              : 'LibreOffice Headless component is not installed. Click "Install Component Offline (.phpack)" to register it without internet.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => ctrl.installOfflineComponentOneClick(
                          EngineComponentId.libreOffice,
                        ),
                        icon: const Icon(Icons.download_done_rounded, size: 16),
                        label: Text(
                          strings.isSi
                              ? 'Install Component (.phpack)'
                              : '1-Click Offline Install (.phpack)',
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Legacy Sinhala Font (FM Abhaya / DL-Manel) Detection Warning Banner
              if (hasAnyLegacySinhala)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade800),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.translate_rounded, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.isSi
                              ? 'පැරණි සිංහල අකුරු (FM Abhaya / DL-Manel) සහිත PDF ගොනුවක් හඳුනාගැනුණි! ";s% ,xld" -> "ශ්‍රී ලංකා" ලෙස ස්වයංක්‍රීයව Unicode බවට පරිවර්තනය කෙරේ.'
                              : 'Legacy Sinhala font (FM Abhaya / Wijesekara ASCII) detected! ";s% ,xld" will be automatically converted to Unicode "ශ්‍රී ලංකා" before exporting.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 3. Batch Queue List & Sample Test Suite Results Table
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        strings.isSi
                            ? 'පරිවර්තන පෝලිම (Batch Conversion Queue — ${state.batchQueue.length} files)'
                            : 'Batch Conversion Queue (${state.batchQueue.length} files)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: state.batchQueue.length,
                          separatorBuilder: (_, __) => const Divider(height: 12),
                          itemBuilder: (ctx, idx) {
                            final item = state.batchQueue[idx];
                            final leg = item.legacySinhalaDetection;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.insert_drive_file_outlined),
                              title: Text(
                                '${item.sourceFileName}  →  .${item.targetFormat.extension.toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status: ${item.status.name} • ${(item.progress * 100).round()}%'
                                    '${item.ranOcrPrepass ? " • OCR Pre-Pass Applied" : ""}',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  if (leg != null && leg.hasLegacySinhalaEncoding)
                                    Text(
                                      'Legacy Font (${leg.detectedLegacyFontNames.join(", ")}): '
                                      '"${leg.sampleLegacyToken}" → "${leg.transcodedUnicodePreview}"',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (item.status ==
                                      ConvertBatchItemStatus.completed)
                                    UniversalToolResultActionBar(
                                      suggestedFileName:
                                          '${item.sourceFileName}_converted.${item.targetFormat.extension}',
                                      existingFilePath: item.outputFilePath,
                                      outputBytes: item.outputBytes,
                                      compact: true,
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        ctrl.removeBatchItem(item.jobId),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      if (state.benchmarkRows.isNotEmpty) ...[
                        const Divider(height: 18),
                        Text(
                          'Sample-File Conversion Test Suite Results (${state.benchmarkRows.where((r) => r.passed).length}/${state.benchmarkRows.length} Passed)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 155,
                          child: ListView.builder(
                            itemCount: state.benchmarkRows.length,
                            itemBuilder: (ctx, i) {
                              final row = state.benchmarkRows[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '✓ [${row.testCaseId}] ${row.sourceFormat} → ${row.targetFormat} '
                                  '(${row.outputSizeBytes} B) — ${row.notes}',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Sub-Tab 1: Tesseract OCR (sin + eng), Image Cleanup & WIA Scanner Import
  // ==========================================================================

  Widget _buildOcrAndScannerWorkspace(
    BuildContext context,
    WidgetRef ref,
    PdfConvertOcrState state,
    PdfConvertOcrController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final cleanup = state.cleanupConfig;
    final ocrResult = state.lastOcrResult;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Panel (390px): Pre-OCR Image Cleanup + Language Packs + WIA Scanner Import
        Container(
          width: 390,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.isSi
                      ? '1. OCR භාෂා පැකේජ (Tesseract sin + eng Models)'
                      : '1. Tesseract Language Packs (sin + eng)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 6),
                ...state.languagePacks.map((pack) {
                  final selected =
                      state.selectedLanguages.contains(pack.langCode);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selected,
                    onChanged: (_) => ctrl.toggleOcrLanguage(pack.langCode),
                    title: Text(
                      strings.isSi ? pack.displayNameSi : pack.displayNameEn,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${pack.trainedDataFileName} (${pack.sizeMb} MB) • Installed',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }),
                const Divider(height: 20),

                // Pre-OCR Image Cleanup Pipeline
                Text(
                  strings.isSi
                      ? '2. OCR පෙර රූප පිරිසිදු කිරීම (Image Cleanup Before OCR)'
                      : '2. Image Cleanup Before OCR',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Auto-Rotate Orientation (90°/180°/270°)',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: cleanup.autoRotateOrientation,
                  onChanged: (v) => ctrl.updateCleanupConfig(
                    cleanup.copyWith(autoRotateOrientation: v),
                  ),
                ),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Deskew Tilted Scan Lines',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: cleanup.deskewPages,
                  onChanged: (v) =>
                      ctrl.updateCleanupConfig(cleanup.copyWith(deskewPages: v)),
                ),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Denoise Speckles & Scanner Dust',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: cleanup.denoiseSpeckles,
                  onChanged: (v) => ctrl.updateCleanupConfig(
                    cleanup.copyWith(denoiseSpeckles: v),
                  ),
                ),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Contrast Stretch (Faded Ink / Stamps)',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: cleanup.enhanceContrast,
                  onChanged: (v) => ctrl.updateCleanupConfig(
                    cleanup.copyWith(enhanceContrast: v),
                  ),
                ),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Adaptive Binarization (Crisp Black & White)',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: cleanup.binarizeThreshold,
                  onChanged: (v) => ctrl.updateCleanupConfig(
                    cleanup.copyWith(binarizeThreshold: v),
                  ),
                ),
                const Divider(height: 20),

                // WIA Scanner & Camera Folder Import
                Text(
                  strings.isSi
                      ? '3. ස්කෑනරයෙන් හෝ කැමරා ෆෝල්ඩරයෙන් ලබාගන්න (WIA Scanner)'
                      : '3. Import from Scanner (WIA) or Camera Folder',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          ctrl.importFromWiaScannerAndRunOcr(pageCount: 3),
                      icon: const Icon(Icons.scanner_rounded, size: 17),
                      label: Text(
                        strings.isSi
                            ? 'WIA ස්කෑනරයෙන් පිටු ලබාගන්න'
                            : 'Import from Scanner (WIA Multi-Page)',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ctrl.importFromWiaScannerAndRunOcr(pageCount: 2),
                      icon: const Icon(Icons.photo_camera_back_rounded, size: 17),
                      label: Text(
                        strings.isSi
                            ? 'කැමරා / රූප ෆෝල්ඩරයෙන්'
                            : 'Import from Image/Camera Folder',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.isOcrRunning ? null : () => ctrl.runOcrJob(),
                  icon: const Icon(Icons.document_scanner_rounded),
                  label: Text(
                    strings.isSi
                        ? 'OCR ක්‍රියාත්මක කර Searchable PDF සාදන්න'
                        : 'Run OCR & Build Searchable PDF',
                  ),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: state.isOcrRunning
                      ? null
                      : () => ctrl.runOcrJob(simulateLowConfidenceScan: true),
                  icon: const Icon(Icons.warning_amber_rounded, size: 16),
                  label: Text(
                    strings.isSi
                        ? 'අඩු පැහැදිලි සිංහල ස්කෑන් පරීක්ෂාව'
                        : 'Test Low-Confidence Sinhala Scan Warning',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Right Panel: Recognized Sinhala/English Text, Confidence Warning & Searchable PDF Export
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: ocrResult == null
                ? Center(
                    child: Text(
                      strings.isSi
                          ? 'ස්කෑන් කළ PDF හෝ රූපයක් තෝරා "Run OCR" ඔබන්න.'
                          : 'Click "Run OCR & Build Searchable PDF" or "Import from Scanner (WIA)" to recognize Sinhala & English text.',
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Low-Quality Sinhala OCR Confidence Warning Banner
                      if (ocrResult.hasConfidenceWarnings)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade800),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange.shade900,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  strings.isSi
                                      ? ocrResult.confidenceWarningMessageSi
                                      : ocrResult.confidenceWarningMessageEn,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recognized Text (${ocrResult.languagesUsed.join("+")}) — '
                            'Confidence: ${ocrResult.averageConfidencePercent.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: ocrResult.combinedRecognizedText,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Recognized UTF-8 Sinhala/English text copied to clipboard.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Export Text (.txt)'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      UniversalToolResultActionBar(
                        suggestedFileName:
                            '${ocrResult.sourceFileName}_searchable_ocr.pdf',
                        outputBytes: ocrResult.searchablePdfBytes,
                        pageCountOverride: ocrResult.pageReports.length,
                      ),
                      const Divider(height: 20),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: SelectableText(
                            ocrResult.combinedRecognizedText,
                            style: const TextStyle(
                              fontFamily: 'NotoSansSinhala',
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
