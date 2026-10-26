import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/integration/global_command_palette_and_recent_files.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../services/components/local_component_manager.dart';
import '../domain/pdf_tool_models.dart';
import 'pdf_annotation_signature_form_studio.dart';
import 'pdf_content_security_compare_studio.dart';
import 'pdf_convert_ocr_studio.dart';
import 'pdf_toolkit_controller.dart';

class PdfToolsWorkspaceScreen extends ConsumerStatefulWidget {
  const PdfToolsWorkspaceScreen({super.key});

  @override
  ConsumerState<PdfToolsWorkspaceScreen> createState() =>
      _PdfToolsWorkspaceScreenState();
}

class _PdfToolsWorkspaceScreenState
    extends ConsumerState<PdfToolsWorkspaceScreen> {
  int _selectedSubViewIndex = 0; // 0 = PDF Viewer, 1 = Page Tools & Organizer
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _splitRangeCtrl =
      TextEditingController(text: '1-2, 3-4');
  final TextEditingController _watermarkCtrl =
      TextEditingController(text: 'රහසිගතයි • CONFIDENTIAL');
  final TextEditingController _headerCenterCtrl =
      TextEditingController(text: 'ශ්‍රී ලංකා මුද්‍රණ සහායක');
  final TextEditingController _batesPrefixCtrl =
      TextEditingController(text: 'LKA-DOC-');

  double _cropTopMm = 0;
  double _cropBottomMm = 0;
  double _cropLeftMm = 0;
  double _cropRightMm = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(pdfToolkitControllerProvider);
      if (state.openTabs.isEmpty) {
        ref
            .read(pdfToolkitControllerProvider.notifier)
            .openFileInViewerTab(
              'assets/test_documents/sinhala_orthography_test.md',
              pageCountOverride: 4,
            );
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _passwordCtrl.dispose();
    _splitRangeCtrl.dispose();
    _watermarkCtrl.dispose();
    _headerCenterCtrl.dispose();
    _batesPrefixCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndOpenPdfInViewer() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'md', 'txt'],
    );
    if (res == null) return;
    final ctrl = ref.read(pdfToolkitControllerProvider.notifier);
    for (final f in res.files) {
      if (f.path != null) {
        await ctrl.openFileInViewerTab(f.path!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final strings = AppStrings.of(lang);
    final toolkitState = ref.watch(pdfToolkitControllerProvider);
    final ctrl = ref.read(pdfToolkitControllerProvider.notifier);
    final components = ref.watch(componentManagerProvider);
    final selectedSubViewIndex = ref.watch(pdfToolsSubViewIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Mode Bar: Multi-Tab PDF Viewer vs. Page Tools & Organizer + Engine Badges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.55),
              ),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(
                          value: 0,
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          label: Text(
                            strings.isSi
                                ? 'PDF කියවනය (Multi-Tab PDF Viewer)'
                                : 'PDF Viewer (Multi-Tab)',
                          ),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: const Icon(
                            Icons.dashboard_customize_rounded,
                            size: 18,
                          ),
                          label: Text(
                            strings.isSi
                                ? 'පිටු මෙවලම් (Merge / Split / Compress / Stamp)'
                                : 'Page Tools & Organizer (13 Tools)',
                          ),
                        ),
                        ButtonSegment(
                          value: 2,
                          icon: const Icon(
                            Icons.edit_document,
                            size: 18,
                          ),
                          label: Text(
                            strings.isSi
                                ? 'සටහන්, අත්සන් සහ පෝරම (Annotate / Sign)'
                                : 'Annotate, Sign & AcroForms',
                          ),
                        ),
                        ButtonSegment(
                          value: 3,
                          icon: const Icon(
                            Icons.security_rounded,
                            size: 18,
                          ),
                          label: Text(
                            strings.isSi
                                ? 'අන්තර්ගතය, ආරක්ෂාව සහ සංසන්දනය'
                                : 'Edit Content, Security & Compare',
                          ),
                        ),
                        ButtonSegment(
                          value: 4,
                          icon: const Icon(
                            Icons.transform_rounded,
                            size: 18,
                          ),
                          label: Text(
                            strings.isSi
                                ? 'පරිවර්තනය සහ OCR (Convert & OCR)'
                                : 'Convert, OCR (sin+eng) & Scanner',
                          ),
                        ),
                      ],
                      selected: {selectedSubViewIndex},
                      onSelectionChanged: (sel) => ref
                          .read(pdfToolsSubViewIndexProvider.notifier)
                          .state = sel.first,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...components.take(2).map(
                          (c) => Chip(
                            avatar: const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: Colors.green,
                            ),
                            label: Text(
                              '${c.name.split(" ").first} (${c.licenseSpdx})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    FilledButton.tonalIcon(
                      onPressed: _pickAndOpenPdfInViewer,
                      icon: const Icon(Icons.folder_open_rounded, size: 17),
                      label: Text(
                        strings.isSi ? 'PDF විවෘත කරන්න' : 'Open PDF(s)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Main Body: Viewer OR Page Tools OR Annotations/Signatures OR Content/Security/Compare OR Convert/OCR
          Expanded(
            child: switch (selectedSubViewIndex) {
              0 => _buildMultiTabPdfViewer(
                  context,
                  toolkitState,
                  ctrl,
                  strings,
                ),
              1 => _buildPageToolsWorkspace(
                  context,
                  toolkitState,
                  ctrl,
                  strings,
                ),
              2 => const PdfAnnotationSignatureFormStudio(),
              3 => const PdfContentSecurityCompareStudio(),
              _ => const PdfConvertOcrStudio(),
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Sub-View 0: Full-Featured Multi-Tab PDF Viewer
  // ==========================================================================

  Widget _buildMultiTabPdfViewer(
    BuildContext context,
    PdfToolkitWorkspaceState state,
    PdfToolkitController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeTab = state.activeTab;

    if (activeTab == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _pickAndOpenPdfInViewer,
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(
            strings.isSi
                ? 'කියවීමට PDF ගොනුවක් තෝරන්න'
                : 'Open a PDF File to View',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Document Tabs Bar (Multiple Open Files + Demo Password Tab Button)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...state.openTabs.map((tab) {
                final isSelected = tab.tabId == activeTab.tabId;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InputChip(
                    selected: isSelected,
                    avatar: Icon(
                      tab.isPasswordProtected && !tab.isUnlocked
                          ? Icons.lock_rounded
                          : Icons.picture_as_pdf_rounded,
                      size: 16,
                    ),
                    label: Text(
                      '${tab.fileName} (P.${tab.currentPage}/${tab.totalPages})',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onSelected: (_) => ctrl.selectTab(tab.tabId),
                    onDeleted: state.openTabs.length > 1
                        ? () => ctrl.closeTab(tab.tabId)
                        : null,
                  ),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: Text(strings.isSi ? 'නව ටැබ් එකක්' : 'New Tab'),
                onPressed: _pickAndOpenPdfInViewer,
              ),
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.lock_outline_rounded, size: 16),
                label: Text(
                  strings.isSi
                      ? 'මුරපද සහිත PDF පරීක්ෂාව'
                      : 'Test Password-Protected PDF',
                ),
                onPressed: () => ctrl.openFileInViewerTab(
                  'encrypted_confidential_sinhala.pdf',
                  pageCountOverride: 3,
                  isPasswordProtected: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 2. Viewer Toolbar: Sidebar Toggles, Continuous/Single-Page, Zoom, Rotate, Night Mode, Unicode Sinhala Search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Left: Thumbnails & Bookmarks Sidebar toggles + Page Stepper
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilterChip(
                    selected: activeTab.showThumbnailsSidebar,
                    onSelected: (_) => ctrl.toggleThumbnailsSidebar(),
                    avatar: const Icon(Icons.view_sidebar_rounded, size: 16),
                    label: Text(strings.isSi ? 'කුඩා රූප' : 'Thumbnails'),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    selected: activeTab.showBookmarksSidebar,
                    onSelected: (_) => ctrl.toggleBookmarksSidebar(),
                    avatar: const Icon(Icons.bookmark_border_rounded, size: 16),
                    label: Text(strings.isSi ? 'පිටු සලකුණු' : 'Bookmarks'),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: activeTab.currentPage > 1
                        ? () => ctrl.setTabCurrentPage(activeTab.currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    'Page ${activeTab.currentPage} / ${activeTab.totalPages}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: activeTab.currentPage < activeTab.totalPages
                        ? () => ctrl.setTabCurrentPage(activeTab.currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),

              // Center: Continuous vs Single-Page, Zoom Presets, Rotate View, Night Mode
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<PdfViewDisplayMode>(
                    segments: [
                      ButtonSegment(
                        value: PdfViewDisplayMode.continuous,
                        icon: const Icon(Icons.view_day_outlined, size: 16),
                        label: Text(
                          strings.isSi ? 'අඛණ්ඩ (Continuous)' : 'Continuous',
                        ),
                      ),
                      ButtonSegment(
                        value: PdfViewDisplayMode.singlePage,
                        icon: const Icon(
                          Icons.insert_drive_file_outlined,
                          size: 16,
                        ),
                        label: Text(
                          strings.isSi ? 'තනි පිටුව (Single)' : 'Single Page',
                        ),
                      ),
                    ],
                    selected: {activeTab.displayMode},
                    onSelectionChanged: (sel) => ctrl.setDisplayMode(sel.first),
                  ),
                  ActionChip(
                    label: Text(
                      activeTab.zoomPreset == PdfZoomPreset.fitWidth
                          ? 'Fit Width (${(activeTab.zoomScale * 100).round()}%)'
                          : 'Fit Page (${(activeTab.zoomScale * 100).round()}%)',
                    ),
                    onPressed: () {
                      final next =
                          activeTab.zoomPreset == PdfZoomPreset.fitWidth
                              ? PdfZoomPreset.fitPage
                              : PdfZoomPreset.fitWidth;
                      ctrl.setZoomPreset(next);
                    },
                  ),
                  IconButton(
                    tooltip: 'Rotate View 90° Clockwise',
                    onPressed: ctrl.rotateActiveViewClockwise,
                    icon: const Icon(Icons.rotate_right_rounded, size: 20),
                  ),
                  FilterChip(
                    selected: activeTab.nightMode,
                    onSelected: (_) => ctrl.toggleNightMode(),
                    avatar: const Icon(Icons.dark_mode_outlined, size: 16),
                    label: Text(strings.isSi ? 'රාත්‍රී ප්‍රකාරය' : 'Night Mode'),
                  ),
                ],
              ),

              // Right: Unicode-Normalized Sinhala + English Search Bar
              SizedBox(
                width: 290,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          hintText: strings.isSi
                              ? 'සොයන්න (සිංහල / English)...'
                              : 'Search (සිංහල / English)...',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: ctrl.searchInActiveTab,
                      ),
                    ),
                    if (activeTab.searchMatches.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${activeTab.activeSearchMatchIndex + 1}/${activeTab.searchMatches.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: ctrl.nextSearchMatch,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Viewer Main Area: Thumbnails Sidebar + Bookmarks Sidebar + Viewport (or Password Prompt)
        Expanded(
          child: activeTab.isPasswordProtected && !activeTab.isUnlocked
              ? _buildPasswordUnlockPrompt(context, activeTab, ctrl, strings)
              : Row(
                  children: [
                    // Thumbnails Sidebar
                    if (activeTab.showThumbnailsSidebar)
                      Container(
                        width: 155,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: ListView.builder(
                          itemCount: activeTab.totalPages,
                          itemBuilder: (ctx, idx) {
                            final pNum = idx + 1;
                            final isCurrent = pNum == activeTab.currentPage;
                            return InkWell(
                              onTap: () => ctrl.setTabCurrentPage(pNum),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCurrent
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant,
                                    width: isCurrent ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Page $pNum',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isCurrent
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Bookmarks / Outline Sidebar
                    if (activeTab.showBookmarksSidebar)
                      Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.isSi
                                  ? 'පිටු සලකුණු (Outline)'
                                  : 'Bookmarks / Outline',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Divider(),
                            Expanded(
                              child: ListView.builder(
                                itemCount: activeTab.bookmarks.length,
                                itemBuilder: (ctx, idx) {
                                  final bm = activeTab.bookmarks[idx];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.bookmark_rounded,
                                      size: 16,
                                    ),
                                    title: Text(
                                      bm.title,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Text(
                                      'P.${bm.pageNumber}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onTap: () =>
                                        ctrl.setTabCurrentPage(bm.pageNumber),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Main PDF Viewport (Continuous or Single-Page, Night Mode, Rotation, Selectable Text & Copy)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: activeTab.nightMode
                              ? const Color(0xFF121316)
                              : colorScheme.surfaceContainerHighest
                                  .withOpacity(0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: activeTab.displayMode ==
                                PdfViewDisplayMode.singlePage
                            ? Center(
                                child: SingleChildScrollView(
                                  child: _buildRenderedPdfPageSheet(
                                    context,
                                    activeTab,
                                    activeTab.currentPage,
                                    strings,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: activeTab.totalPages,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (ctx, idx) => Center(
                                  child: _buildRenderedPdfPageSheet(
                                    context,
                                    activeTab,
                                    idx + 1,
                                    strings,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPasswordUnlockPrompt(
    BuildContext context,
    PdfDocumentTabState tab,
    PdfToolkitController ctrl,
    AppStrings strings,
  ) {
    return Center(
      child: Card(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 42),
                const SizedBox(height: 12),
                Text(
                  strings.isSi
                      ? 'මුරපදයකින් ආරක්ෂිත PDF ගොනුවකි'
                      : 'Password-Protected PDF Document',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  tab.fileName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        strings.isSi ? 'PDF මුරපදය ඇතුළත් කරන්න' : 'Enter PDF Password',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (val) => ctrl.unlockPasswordProtectedTab(val),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () =>
                      ctrl.unlockPasswordProtectedTab(_passwordCtrl.text),
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(
                    strings.isSi ? 'විවෘත කරන්න (Unlock PDF)' : 'Unlock PDF',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRenderedPdfPageSheet(
    BuildContext context,
    PdfDocumentTabState tab,
    int pageNumber,
    AppStrings strings,
  ) {
    final pageText = tab.pageTexts[pageNumber] ?? '';
    final bgColor =
        tab.nightMode ? const Color(0xFF1E2025) : const Color(0xFFFFFFFF);
    final fgColor =
        tab.nightMode ? const Color(0xFFE6E8EE) : const Color(0xFF1A1C1E);
    final quarterTurns = (tab.viewRotationDegrees ~/ 90) % 4;

    return RotatedBox(
      quarterTurns: quarterTurns,
      child: Container(
        width: 560 * tab.zoomScale,
        constraints: BoxConstraints(minHeight: 340 * tab.zoomScale),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tab.fileName} — Page $pageNumber of ${tab.totalPages}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fgColor.withOpacity(0.65),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pageText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          strings.isSi
                              ? 'පිටුවේ පෙළ Clipboard වෙත පිටපත් කරන ලදී.'
                              : 'Page text copied to clipboard.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(
                    strings.isSi ? 'පෙළ පිටපත් කරන්න' : 'Copy Page Text',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            // Selectable text with Unicode-normalized Sinhala & English search highlight banner
            if (tab.searchQuery.trim().isNotEmpty &&
                tab.searchMatches.any((m) => m.pageNumber == pageNumber))
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.32),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Text(
                  'Search Highlight Match on Page $pageNumber: "${tab.searchQuery}"',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
              ),
            SelectableText(
              pageText,
              style: TextStyle(
                fontFamily: 'NotoSansSinhala',
                fontSize: 13.5 * tab.zoomScale.clamp(0.8, 1.5),
                height: 1.55,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Sub-View 1: Page Tools & Visual Drag-and-Drop Page Organizer (13 Tools)
  // ==========================================================================

  Widget _buildPageToolsWorkspace(
    BuildContext context,
    PdfToolkitWorkspaceState state,
    PdfToolkitController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: All 13 Page Tools Selector + Active Tool Settings + Run / Cancel
        SizedBox(
          width: 390,
          child: Card(
            margin: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.isSi
                        ? '1. PDF පිටු මෙවලම තෝරන්න (Select Page Tool)'
                        : '1. Select PDF Page Tool',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: PdfPageToolKind.values.map((tool) {
                      final selected = state.activeTool == tool;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(
                          _labelForTool(tool, strings.isSi),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onSelected: (_) => ctrl.selectActiveTool(tool),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),

                  // Tool-Specific Parameters Panel
                  _buildToolParametersPanel(context, state, ctrl, strings),

                  const SizedBox(height: 16),

                  // Progress Bar + Cancel Button when Background Job is Running
                  if (state.isJobRunning) ...[
                    LinearProgressIndicator(value: state.jobProgress),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${(state.jobProgress * 100).round()}% — ${state.jobStageMessage}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: ctrl.cancelRunningJob,
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: Text(
                            strings.isSi ? 'අවලංගු කරන්න' : 'Cancel',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Run Tool Button
                  FilledButton.icon(
                    onPressed: state.isJobRunning
                        ? null
                        : () => ctrl.runActivePageToolJob(),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      strings.isSi
                          ? 'මෙවලම ක්‍රියාත්මක කර පෙරදසුන බලන්න (Run & Preview)'
                          : 'Run Tool in Background & Preview Before/After',
                    ),
                  ),

                  // Before/After Size Comparison & Save As New / Overwrite Card
                  if (state.lastExecutionReport != null) ...[
                    const SizedBox(height: 16),
                    _buildBeforeAfterReportCard(
                      context,
                      state.lastExecutionReport!,
                      ctrl,
                      strings,
                      colorScheme,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Right Column: Interactive Drag-and-Drop Page Thumbnails Organizer
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Organizer Toolbar: Add PDF, Insert Blank Page, Rotate All
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        strings.isSi
                            ? 'පිටු සැකසුම (Drag & Drop Reorder • ${state.organizerPages.length} Pages)'
                            : 'Drag-and-Drop Page Thumbnails (${state.organizerPages.length} Pages)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => ctrl.insertBlankPage(),
                            icon: const Icon(Icons.note_add_outlined, size: 16),
                            label: Text(
                              strings.isSi
                                  ? 'හිස් පිටුවක් එක් කරන්න'
                                  : 'Insert Blank Page',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => ctrl.insertPagesFromAnotherPdf(
                              'inserted_appendix.pdf',
                              pageCount: 2,
                            ),
                            icon: const Icon(Icons.post_add_rounded, size: 16),
                            label: Text(
                              strings.isSi
                                  ? 'වෙනත් PDF පිටු එක් කරන්න'
                                  : 'Insert from Another PDF',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ctrl.rotateAllOrganizerPages(deltaDegrees: 90),
                            icon: const Icon(
                              Icons.rotate_90_degrees_cw_rounded,
                              size: 16,
                            ),
                            label: Text(
                              strings.isSi ? 'සියල්ල කරකවන්න' : 'Rotate All 90°',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Reorderable List of Page Tiles
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: state.organizerPages.length,
                      onReorder: ctrl.reorderOrganizerPage,
                      itemBuilder: (ctx, idx) {
                        final tile = state.organizerPages[idx];
                        return Card(
                          key: ValueKey(tile.tileId),
                          margin: const EdgeInsets.only(bottom: 8),
                          color: colorScheme.surfaceContainerLow,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(
                              tile.isBlankInserted
                                  ? (strings.isSi
                                      ? 'ඇතුළත් කළ හිස් පිටුව (Blank Page)'
                                      : 'Inserted Blank Page')
                                  : '${tile.sourceFileName} — Source Page ${tile.originalPageNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'Rotation: ${tile.rotationDegrees}° • '
                              'Crop: T=${tile.cropTopMm.round()}mm, B=${tile.cropBottomMm.round()}mm, '
                              'L=${tile.cropLeftMm.round()}mm, R=${tile.cropRightMm.round()}mm',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Rotate Page 90°',
                                  onPressed: () =>
                                      ctrl.rotateOrganizerPage(tile.tileId),
                                  icon: const Icon(
                                    Icons.rotate_right_rounded,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete Page',
                                  onPressed: () =>
                                      ctrl.deleteOrganizerPage(tile.tileId),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: colorScheme.error,
                                  ),
                                ),
                                const SizedBox(width: 8),
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
        ),
      ],
    );
  }

  Widget _buildToolParametersPanel(
    BuildContext context,
    PdfToolkitWorkspaceState state,
    PdfToolkitController ctrl,
    AppStrings strings,
  ) {
    switch (state.activeTool) {
      case PdfPageToolKind.split:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.isSi ? 'PDF වෙන් කිරීමේ ක්‍රමය (Split Mode):' : 'Split Strategy:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PdfSplitStrategy>(
              value: state.splitStrategy,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                  value: PdfSplitStrategy.byPageRange,
                  child: Text('By Page Ranges (e.g., 1-2, 3-4)'),
                ),
                DropdownMenuItem(
                  value: PdfSplitStrategy.everyNPages,
                  child: Text('Every N Pages'),
                ),
                DropdownMenuItem(
                  value: PdfSplitStrategy.byMaxFileSizeMb,
                  child: Text('By Maximum File Size (MB)'),
                ),
                DropdownMenuItem(
                  value: PdfSplitStrategy.byTopLevelBookmarks,
                  child: Text('By Bookmarks / Chapters'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  ctrl.updateSplitSettings(strategy: val);
                }
              },
            ),
            const SizedBox(height: 10),
            if (state.splitStrategy == PdfSplitStrategy.byPageRange)
              TextField(
                controller: _splitRangeCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Split Page Ranges',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    ctrl.updateSplitSettings(rangeExpression: v),
              ),
            if (state.splitStrategy == PdfSplitStrategy.everyNPages)
              Row(
                children: [
                  const Text('Every N Pages:'),
                  Expanded(
                    child: Slider(
                      value: state.splitEveryNPages.toDouble().clamp(1, 10),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${state.splitEveryNPages}',
                      onChanged: (v) =>
                          ctrl.updateSplitSettings(everyNPages: v.round()),
                    ),
                  ),
                  Text('${state.splitEveryNPages}'),
                ],
              ),
          ],
        );

      case PdfPageToolKind.compressPdf:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.isSi
                  ? 'හැකිලීමේ මට්ටම (Compression Level + Image Downsampling):'
                  : 'Compression Level & Image Downsampling:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...PdfCompressionLevel.values.map(
              (lvl) => RadioListTile<PdfCompressionLevel>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: lvl,
                groupValue: state.compressionLevel,
                onChanged: (val) {
                  if (val != null) ctrl.updateCompressionLevel(val);
                },
                title: Text(
                  strings.isSi ? lvl.labelSi : lvl.labelEn,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        );

      case PdfPageToolKind.cropPages:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crop Page Margins (mm):',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Slider(
              value: _cropTopMm,
              min: 0,
              max: 40,
              label: 'Crop ${(_cropTopMm).round()} mm',
              onChanged: (val) {
                setState(() {
                  _cropTopMm = val;
                  _cropBottomMm = val;
                  _cropLeftMm = val;
                  _cropRightMm = val;
                });
                ctrl.applyCropMarginsToAllPages(
                  topMm: _cropTopMm,
                  bottomMm: _cropBottomMm,
                  leftMm: _cropLeftMm,
                  rightMm: _cropRightMm,
                );
              },
            ),
          ],
        );

      case PdfPageToolKind.resizeStandardPage:
        return DropdownButtonFormField<PdfStandardPaperSize>(
          value: state.targetPaperSize,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Standard Target Paper Size',
            border: OutlineInputBorder(),
          ),
          items: PdfStandardPaperSize.values
              .map(
                (sz) => DropdownMenuItem(
                  value: sz,
                  child: Text(
                    '${sz.name} (${sz.widthMm.round()} × ${sz.heightMm.round()} mm)',
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) ctrl.updateTargetPaperSize(val);
          },
        );

      case PdfPageToolKind.stampBatesHeadersWatermarks:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _watermarkCtrl,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Watermark Text (Noto Sans Sinhala Embedded)',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => ctrl.updateStampingConfig(
                PdfStampingConfig(
                  watermarkText: val,
                  headerCenter: _headerCenterCtrl.text,
                  enableBatesNumbering: true,
                  batesPrefix: _batesPrefixCtrl.text,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _headerCenterCtrl,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Header Text (සිංහල / English)',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => ctrl.updateStampingConfig(
                PdfStampingConfig(
                  watermarkText: _watermarkCtrl.text,
                  headerCenter: val,
                  enableBatesNumbering: true,
                  batesPrefix: _batesPrefixCtrl.text,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _batesPrefixCtrl,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Bates Numbering Prefix (e.g. LKA-DOC-000001)',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => ctrl.updateStampingConfig(
                PdfStampingConfig(
                  watermarkText: _watermarkCtrl.text,
                  headerCenter: _headerCenterCtrl.text,
                  enableBatesNumbering: true,
                  batesPrefix: val,
                ),
              ),
            ),
          ],
        );

      default:
        return Text(
          strings.isSi
              ? 'දකුණු පස ඇති පිටු ලැයිස්තුවෙන් පිටු පෙළගස්වා "Run & Preview" ක්ලික් කරන්න.'
              : 'Use the drag-and-drop page list on the right to organize pages, then click "Run Tool in Background & Preview".',
          style: const TextStyle(fontSize: 12),
        );
    }
  }

  Widget _buildBeforeAfterReportCard(
    BuildContext context,
    PdfToolExecutionReport report,
    PdfToolkitController ctrl,
    AppStrings strings,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.isSi ? report.summarySi : report.summaryEn,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Before Size: ${report.formattedBeforeSize}  →  After Size: ${report.formattedAfterSize} '
            '(${report.sizeChangePercent.toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Generated Preview: ${report.outputPageCount} page(s) in ${report.elapsedMs} ms',
            style: const TextStyle(fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          UniversalToolResultActionBar(
            suggestedFileName: report.outputFiles.first,
            outputBytes: report.previewPdfBytes,
            pageCountOverride: report.outputPageCount,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  final savedPath = await FilePicker.platform.saveFile(
                    dialogTitle: 'Save New PDF File',
                    fileName: report.outputFiles.first,
                    type: FileType.custom,
                    allowedExtensions: const ['pdf'],
                  );
                  if (savedPath != null) {
                    await ctrl.saveLastReportOutput(
                      targetFilePath: savedPath,
                      overwriteExisting: false,
                    );
                  }
                },
                icon: const Icon(Icons.save_alt_rounded, size: 16),
                label: Text(
                  strings.isSi ? 'නව ගොනුවක් ලෙස සුරකින්න' : 'Save as New',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final activePath = ref
                          .read(pdfToolkitControllerProvider)
                          .activeTab
                          ?.filePath ??
                      'output_overwritten.pdf';
                  await ctrl.saveLastReportOutput(
                    targetFilePath: activePath,
                    overwriteExisting: true,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          strings.isSi
                              ? 'මුල් ගොනුව මත සුරකින ලදී (Overwritten).'
                              : 'Atomically overwritten original file.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.published_with_changes_rounded, size: 16),
                label: Text(
                  strings.isSi ? 'මුල් ගොනුව මත සුරකින්න (Overwrite)' : 'Overwrite',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _labelForTool(PdfPageToolKind tool, bool isSi) {
    return switch (tool) {
      PdfPageToolKind.merge => isSi ? 'ඒකාබද්ධ (Merge)' : 'Merge PDFs',
      PdfPageToolKind.split => isSi ? 'වෙන් කරන්න (Split)' : 'Split PDF',
      PdfPageToolKind.extractPages => isSi ? 'පිටු උපුටා ගන්න' : 'Extract Pages',
      PdfPageToolKind.deletePages => isSi ? 'පිටු මකන්න' : 'Delete Pages',
      PdfPageToolKind.rotatePages => isSi ? 'පිටු කරකවන්න' : 'Rotate Pages',
      PdfPageToolKind.reorderPages => isSi ? 'පෙළගස්වන්න' : 'Reorder Pages',
      PdfPageToolKind.insertBlankPages =>
        isSi ? 'හිස් පිටු එක් කරන්න' : 'Insert Blank',
      PdfPageToolKind.insertFromAnotherPdf =>
        isSi ? 'වෙනත් PDF එක් කරන්න' : 'Insert PDF',
      PdfPageToolKind.cropPages => isSi ? 'කපන්න (Crop)' : 'Crop Pages',
      PdfPageToolKind.resizeStandardPage =>
        isSi ? 'ප්‍රමාණය වෙනස් කරන්න' : 'Resize Page',
      PdfPageToolKind.compressPdf =>
        isSi ? 'ගොනුව හකුලන්න (Compress)' : 'Compress PDF',
      PdfPageToolKind.repairDamagedPdf =>
        isSi ? 'අලුත්වැඩියා කරන්න (Repair)' : 'Repair PDF',
      PdfPageToolKind.stampBatesHeadersWatermarks =>
        isSi ? 'පිටු අංක / Bates / දිය සලකුණ' : 'Bates, Numbers & Watermark',
    };
  }
}
