import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/integration/global_command_palette_and_recent_files.dart';
import '../../../core/l10n/app_strings.dart';
import '../domain/pdf_annotations_Grouping_models.dart';
import '../domain/pdf_content_security_compare_models.dart';
import 'pdf_annotation_signature_form_controller.dart';
import 'pdf_content_security_compare_controller.dart';

class PdfContentSecurityCompareStudio extends ConsumerStatefulWidget {
  const PdfContentSecurityCompareStudio({super.key});

  @override
  ConsumerState<PdfContentSecurityCompareStudio> createState() =>
      _PdfContentSecurityCompareStudioState();
}

class _PdfContentSecurityCompareStudioState
    extends ConsumerState<PdfContentSecurityCompareStudio> {
  int _activeSection = 0; // 0 = Content Editing, 1 = Security & Redaction, 2 = Document Compare

  // Content Editing Controllers
  final TextEditingController _textEditCtrl = TextEditingController(
    text: 'සංශෝධිත සිංහල පෙළ • Updated Text Overlay',
  );
  final TextEditingController _linkUrlCtrl = TextEditingController(
    text: 'https://www.printhelper.org/offline-docs',
  );
  String _selectedFontFamily = 'NotoSansSinhala';
  double _selectedFontSizePt = 12.0;
  int _selectedTextColorHex = 0xFF1A1C1E;
  PdfTextAlignment _selectedAlignment = PdfTextAlignment.left;
  bool _isWhiteoutMode = true;

  // Security & Redaction Controllers
  final TextEditingController _userPasswordCtrl = TextEditingController();
  final TextEditingController _ownerPasswordCtrl = TextEditingController();
  final TextEditingController _redactSearchCtrl = TextEditingController(
    text: 'ACC-9948-2026',
  );
  final TextEditingController _metaTitleCtrl = TextEditingController(
    text: 'ශ්‍රී ලංකා මුද්‍රණ සහායක — නිල ලේඛනය',
  );
  final TextEditingController _metaAuthorCtrl = TextEditingController(
    text: 'Print Helper Office User',
  );
  final TextEditingController _metaSubjectCtrl = TextEditingController(
    text: 'Sinhala & English PDF Document',
  );
  final TextEditingController _metaKeywordsCtrl = TextEditingController(
    text: 'Sinhala, PDF, Print Helper, Offline',
  );

  // Document Compare Mode (0 = Side-by-Side Visual Diff, 1 = Line-by-Line Text Diff)
  int _compareViewMode = 0;

  @override
  void dispose() {
    _textEditCtrl.dispose();
    _linkUrlCtrl.dispose();
    _userPasswordCtrl.dispose();
    _ownerPasswordCtrl.dispose();
    _redactSearchCtrl.dispose();
    _metaTitleCtrl.dispose();
    _metaAuthorCtrl.dispose();
    _metaSubjectCtrl.dispose();
    _metaKeywordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportSecuredAndEditedPdf(
    BuildContext context,
    PdfContentSecurityCompareController ctrl,
    AppStrings strings,
  ) async {
    final bytes = await ctrl.exportEditedAndSecuredPdfBytes();
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Edited, Redacted & Secured PDF',
      fileName: 'secured_edited_output.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (savePath != null) {
      await File(savePath).writeAsBytes(bytes, flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.isSi
                  ? 'ආරක්ෂිත සහ සංස්කරණය කළ PDF ගොනුව සුරකින ලදී: $savePath'
                  : 'Saved edited, permanently redacted & AES-256 secured PDF: $savePath',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final strings = AppStrings.of(lang);
    final state = ref.watch(pdfContentSecurityCompareControllerProvider);
    final ctrl =
        ref.read(pdfContentSecurityCompareControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Studio Switcher: Content Editing vs Security & Redaction vs Document Compare
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
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
                    icon: const Icon(Icons.text_fields_rounded, size: 17),
                    label: Text(
                      strings.isSi
                          ? 'අන්තර්ගත සංස්කරණය (Content Edit / Whiteout)'
                          : 'Content Editing & Whiteout',
                    ),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.security_rounded, size: 17),
                    label: Text(
                      strings.isSi
                          ? 'ආරක්ෂාව සහ ස්ථිර මැකීම (AES-256 & Redact)'
                          : 'Security, AES-256 & Redaction',
                    ),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: const Icon(Icons.compare_arrows_rounded, size: 17),
                    label: Text(
                      strings.isSi
                          ? 'PDF සංසන්දනය (Document Compare)'
                          : 'Document Compare (Visual & Text Diff)',
                    ),
                  ),
                ],
                selected: {_activeSection},
                onSelectionChanged: (sel) =>
                    setState(() => _activeSection = sel.first),
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const UniversalToolResultActionBar(
                    suggestedFileName: 'secured_edited_output.pdf',
                    compact: true,
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        _exportSecuredAndEditedPdf(context, ctrl, strings),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      strings.isSi
                          ? 'PDF ගොනුව සුරකින්න (Save Edited/Secured PDF)'
                          : 'Save Edited / Secured PDF',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Main Body
        Expanded(
          child: switch (_activeSection) {
            0 => _buildContentEditingStudio(context, state, ctrl, strings),
            1 => _buildSecurityAndRedactionStudio(context, state, ctrl, strings),
            _ => _buildDocumentCompareStudio(context, state, ctrl, strings),
          },
        ),
      ],
    );
  }

  // ==========================================================================
  // Section 0: Content Editing (Add Text, Whiteout+Overlay, Images, Links & Honest Font Notice)
  // ==========================================================================

  Widget _buildContentEditingStudio(
    BuildContext context,
    PdfContentSecurityCompareState state,
    PdfContentSecurityCompareController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Honest Limitation Banner + Embedded Font Availability + Add Text / Whiteout Controls
        Expanded(
          flex: 3,
          child: Card(
            margin: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Honest Embedded Text Editing & Font Availability Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                strings.isSi
                                    ? 'සත්‍ය තාක්ෂණික දැනුම්දීම: PDF තුළ ඇති මුල් අකුරු (Embedded Subset Fonts) සංස්කරණය කිරීම'
                                    : 'Honest Technical Notice — Editing Original Embedded PDF Text & Fonts:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.isSi
                              ? 'PDF ගොනුවල අකුරු තැන්පත් කර ඇත්තේ ස්ථාවර ඛණ්ඩාංක (Fixed Glyph Coordinates) සහ උප-කුලක අකුරු (Subset Fonts) ලෙසයි. එබැවින් Word ලේඛනයක් මෙන් මුල් පෙළ සෘජුවම වෙනස් කිරීම සීමිතය. Print Helper මඟින් පැරණි පෙළ Whiteout කොටුවකින් ආවරණය කර ඒ මත නව සිංහල (Noto Sans Sinhala) හෝ ඉංග්‍රීසි පෙළ පැහැදිලිව තැන්පත් කරයි.'
                              : 'PDF files store glyphs at fixed coordinates using subsetted fonts (often missing full character tables or /ToUnicode maps for legacy Sinhala fonts). Reflowing original embedded text is inherently limited. Print Helper replaces existing text cleanly using Whiteout + Overlay with bundled Noto Sans Sinhala or standard fonts.',
                          style: const TextStyle(fontSize: 11.5, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: state.embeddedFonts.map((f) {
                            return Tooltip(
                              message: strings.isSi ? f.noticeSi : f.noticeEn,
                              child: Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                  f.isAvailableLocally
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  size: 15,
                                  color: f.isAvailableLocally
                                      ? Colors.green
                                      : Colors.orange.shade800,
                                ),
                                label: Text(
                                  f.isAvailableLocally
                                      ? '${f.embeddedFontName} (Available)'
                                      : '${f.embeddedFontName} (Missing → Uses ${f.substituteFontFamily})',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Add New Text Anywhere OR Replace Existing Text via Whiteout + Overlay
                  Text(
                    strings.isSi
                        ? '1. නව පෙළ එක් කරන්න හෝ Whiteout + Overlay මඟින් පෙළ ප්‍රතිස්ථාපනය කරන්න'
                        : '1. Add New Text Anywhere or Replace Existing Text (Whiteout + Overlay)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textEditCtrl,
                          style:
                              const TextStyle(fontFamily: 'NotoSansSinhala'),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText:
                                'Text Content (සිංහල Noto Sans Sinhala / English)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilterChip(
                        selected: _isWhiteoutMode,
                        onSelected: (v) =>
                            setState(() => _isWhiteoutMode = v),
                        avatar: const Icon(
                          Icons.format_color_reset_rounded,
                          size: 16,
                        ),
                        label: Text(
                          strings.isSi
                              ? 'Whiteout + Overlay (පැරණි පෙළ වසන්න)'
                              : 'Whiteout + Overlay Mode',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Font Family Dropdown
                      SizedBox(
                        width: 210,
                        child: DropdownButtonFormField<String>(
                          value: _selectedFontFamily,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Font Family',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'NotoSansSinhala',
                              child: Text('Noto Sans Sinhala (සිංහල + EN)'),
                            ),
                            DropdownMenuItem(
                              value: 'Segoe UI',
                              child: Text('Segoe UI'),
                            ),
                            DropdownMenuItem(
                              value: 'Consolas',
                              child: Text('Consolas Monospace'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedFontFamily = val);
                            }
                          },
                        ),
                      ),

                      // Font Size Slider
                      SizedBox(
                        width: 180,
                        child: Row(
                          children: [
                            Text(
                              '${_selectedFontSizePt.round()} pt:',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _selectedFontSizePt,
                                min: 8,
                                max: 28,
                                onChanged: (v) =>
                                    setState(() => _selectedFontSizePt = v),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Text Color Swatches
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const <int>[
                          0xFF1A1C1E, // Black
                          0xFF0D47A1, // Navy Blue
                          0xFFB71C1C, // Crimson Red
                          0xFF1B5E20, // Forest Green
                        ].map((hex) {
                          final active = _selectedTextColorHex == hex;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedTextColorHex = hex),
                            child: Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Color(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: active
                                      ? colorScheme.primary
                                      : Colors.black26,
                                  width: active ? 2.5 : 1,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Alignment SegmentedButton
                      SegmentedButton<PdfTextAlignment>(
                        segments: const [
                          ButtonSegment(
                            value: PdfTextAlignment.left,
                            icon: Icon(Icons.format_align_left_rounded,
                                size: 16),
                          ),
                          ButtonSegment(
                            value: PdfTextAlignment.center,
                            icon: Icon(Icons.format_align_center_rounded,
                                size: 16),
                          ),
                          ButtonSegment(
                            value: PdfTextAlignment.right,
                            icon: Icon(Icons.format_align_right_rounded,
                                size: 16),
                          ),
                          ButtonSegment(
                            value: PdfTextAlignment.justify,
                            icon: Icon(Icons.format_align_justify_rounded,
                                size: 16),
                          ),
                        ],
                        selected: {_selectedAlignment},
                        onSelectionChanged: (sel) =>
                            setState(() => _selectedAlignment = sel.first),
                      ),

                      FilledButton.tonalIcon(
                        onPressed: () {
                          ctrl.addOrReplaceContentText(
                            pageNumber: 1,
                            text: _textEditCtrl.text,
                            fontFamily: _selectedFontFamily,
                            fontSizePt: _selectedFontSizePt,
                            textColorHex: _selectedTextColorHex,
                            alignment: _selectedAlignment,
                            isWhiteoutReplacement: _isWhiteoutMode,
                            originalEmbeddedFontName: _isWhiteoutMode
                                ? 'SUBSET+FMAbhaya-Bold'
                                : null,
                          );
                        },
                        icon: const Icon(Icons.add_box_rounded, size: 17),
                        label: Text(
                          _isWhiteoutMode
                              ? (strings.isSi
                                  ? 'Whiteout + පෙළ යොදන්න'
                                  : 'Apply Whiteout + Overlay')
                              : (strings.isSi
                                  ? 'නව පෙළ එක් කරන්න'
                                  : 'Add Text Box'),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // 2. Add / Move / Resize / Delete Images & Edit Hyperlinks
                  Text(
                    strings.isSi
                        ? '2. රූප (Add/Move/Resize/Delete Images) සහ සබැඳි (Edit Links)'
                        : '2. Add/Move/Resize/Delete Images & Edit Hyperlinks',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          ctrl.addContentImage(
                            pageNumber: 1,
                            label: 'Company_Seal_${state.imageObjects.length + 1}.png',
                            imageBytes: Uint8List.fromList(<int>[137, 80, 78, 71]),
                          );
                        },
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 17,
                        ),
                        label: Text(
                          strings.isSi ? 'රූපයක් එක් කරන්න' : 'Add Image to Page',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _linkUrlCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Hyperlink URL (/Subtype /Link)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          ctrl.addEditableLink(
                            pageNumber: 1,
                            actionType: PdfLinkActionType.externalUrl,
                            targetUrl: _linkUrlCtrl.text,
                          );
                        },
                        icon: const Icon(Icons.add_link_rounded, size: 17),
                        label: Text(strings.isSi ? 'සබැඳිය එක් කරන්න' : 'Add Link'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Right Column: Active Content Edits, Images & Links Inspector
        SizedBox(
          width: 360,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ListView(
                children: [
                  Text(
                    'Text Edits & Whiteout Overlays (${state.textEdits.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Divider(),
                  ...state.textEdits.map(
                    (e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        e.isWhiteoutReplacement
                            ? Icons.layers_rounded
                            : Icons.text_fields_rounded,
                        size: 18,
                      ),
                      title: Text(
                        e.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'NotoSansSinhala',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${e.isWhiteoutReplacement ? "Whiteout+Overlay" : "Added Text"} • ${e.fontFamily} (${e.fontSizePt.round()}pt, ${e.alignment.name})',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 17),
                        onPressed: () => ctrl.removeContentTextEdit(e.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Page Image Objects (${state.imageObjects.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Divider(),
                  ...state.imageObjects.map(
                    (img) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.image_outlined, size: 18),
                      title: Text(
                        img.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        'Pos: (${img.bounds.left.round()}, ${img.bounds.top.round()}) • Size: ${img.bounds.width.round()}×${img.bounds.height.round()} pt',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Resize +20%',
                            icon: const Icon(Icons.zoom_out_map_rounded, size: 16),
                            onPressed: () => ctrl.moveOrResizeContentImage(
                              img.id,
                              newBounds: img.bounds.copyWith(
                                width: img.bounds.width * 1.2,
                                height: img.bounds.height * 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                            ),
                            onPressed: () => ctrl.deleteContentImage(img.id),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Interactive Hyperlinks (${state.editableLinks.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Divider(),
                  ...state.editableLinks.map(
                    (lnk) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link_rounded, size: 18),
                      title: Text(
                        lnk.targetUrl,
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        'Page ${lnk.pageNumber} • ${lnk.actionType.name}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 17),
                        onPressed: () => ctrl.deleteEditableLink(lnk.id),
                      ),
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

  // ==========================================================================
  // Section 1: Security (AES-256, Permissions, Search-and-Redact, Metadata & Hidden Data)
  // ==========================================================================

  Widget _buildSecurityAndRedactionStudio(
    BuildContext context,
    PdfContentSecurityCompareState state,
    PdfContentSecurityCompareController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final sec = state.securityConfig;
    final annotCount =
        ref.watch(pdfAnnotationSignatureFormControllerProvider).annotations.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: AES-256 Encryption, Password Removal & Permissions + Metadata & Remove Hidden Data
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.isSi
                        ? '1. AES-256 මුරපද ආරක්ෂාව සහ අවසර (Permissions)'
                        : '1. AES-256 Password Protection, Decrypt & Permissions',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable AES-256 Encryption (qpdf 256-bit)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    value: sec.enableEncryption,
                    onChanged: (val) => ctrl.updateSecurityConfig(
                      sec.copyWith(enableEncryption: val),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userPasswordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'User Open Password',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => ctrl.updateSecurityConfig(
                            sec.copyWith(
                              userOpenPassword: v,
                              enableEncryption: v.isNotEmpty,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _ownerPasswordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Owner Permissions Password',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => ctrl.updateSecurityConfig(
                            sec.copyWith(ownerPermissionsPassword: v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        selected: sec.allowPrinting,
                        onSelected: (v) => ctrl.updateSecurityConfig(
                          sec.copyWith(allowPrinting: v),
                        ),
                        label: const Text('Allow Printing'),
                      ),
                      FilterChip(
                        selected: sec.allowCopyingTextAndGraphics,
                        onSelected: (v) => ctrl.updateSecurityConfig(
                          sec.copyWith(allowCopyingTextAndGraphics: v),
                        ),
                        label: const Text('Allow Copy Text'),
                      ),
                      FilterChip(
                        selected: sec.allowModifyingContent,
                        onSelected: (v) => ctrl.updateSecurityConfig(
                          sec.copyWith(allowModifyingContent: v),
                        ),
                        label: const Text('Allow Editing'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          _userPasswordCtrl.clear();
                          _ownerPasswordCtrl.clear();
                          ctrl.removePasswordProtection();
                        },
                        icon: const Icon(Icons.lock_open_rounded, size: 16),
                        label: Text(
                          strings.isSi ? 'මුරපදය ඉවත් කරන්න' : 'Remove Password',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Metadata Editor & "Remove Hidden Data"
                  Text(
                    strings.isSi
                        ? '2. PDF Metadata සංස්කාරකය සහ සැඟවුණු දත්ත ඉවත් කිරීම'
                        : '2. Document Metadata Editor & "Remove Hidden Data"',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _metaTitleCtrl,
                          style:
                              const TextStyle(fontFamily: 'NotoSansSinhala'),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => ctrl.updateDocumentMetadata(
                            state.metadataInfo.copyWith(title: v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _metaAuthorCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Author',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => ctrl.updateDocumentMetadata(
                            state.metadataInfo.copyWith(author: v),
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
                          controller: _metaSubjectCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Subject',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => ctrl.updateDocumentMetadata(
                            state.metadataInfo.copyWith(subject: v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _metaKeywordsCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Keywords',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => ctrl.updateDocumentMetadata(
                            state.metadataInfo.copyWith(keywords: v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      _metaTitleCtrl.clear();
                      _metaAuthorCtrl.clear();
                      _metaSubjectCtrl.clear();
                      _metaKeywordsCtrl.clear();
                      ctrl.removeHiddenDataAndSanitize(
                        activeAnnotationCount: annotCount,
                      );
                    },
                    icon: const Icon(Icons.cleaning_services_rounded, size: 17),
                    label: Text(
                      strings.isSi
                          ? 'සැඟවුණු දත්ත ඉවත් කරන්න (Remove Hidden Data: Metadata, Comments, Attachments)'
                          : 'Remove Hidden Data (Metadata, Comments & Attachments)',
                    ),
                  ),
                  if (state.lastSanitizationReport != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sanitized: ${state.lastSanitizationReport!.metadataFieldsCleared} metadata fields cleared, '
                      '${state.lastSanitizationReport!.commentsAndAnnotationsRemoved} comments stripped, '
                      '${state.lastSanitizationReport!.embeddedAttachmentsRemoved} attachment(s) removed.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Right Column: Permanent Redaction (Search-and-Redact & Area Redaction)
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.isSi
                        ? '3. ස්ථිරවම දත්ත මැකීම (Permanent Redaction — Search & Area)'
                        : '3. Permanent Redaction (Search-and-Redact & Area Redact)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.isSi
                        ? 'අවවාදයයි: ස්ථිර මැකීම (Apply Redactions) ක්‍රියාත්මක කළ පසු අදාළ පෙළ PDF අන්තර්ගතයෙන් සදහටම ඉවත් කෙරේ.'
                        : 'Permanent redaction physically removes matched characters from the PDF content stream so they can never be copied or recovered.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _redactSearchCtrl,
                          style:
                              const TextStyle(fontFamily: 'NotoSansSinhala'),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText:
                                'Search & Redact Text (e.g. ACC-9948-2026 or 011-2345678)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          ctrl.searchAndMarkForRedaction(
                            _redactSearchCtrl.text,
                          );
                        },
                        icon: const Icon(Icons.find_replace_rounded, size: 17),
                        label: const Text('Mark Matches'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () {
                          ctrl.addAreaRedactionMark(
                            pageNumber: 1,
                            bounds: const PdfRectBounds(
                              left: 48,
                              top: 160,
                              width: 240,
                              height: 36,
                            ),
                          );
                        },
                        icon: const Icon(Icons.crop_free_rounded, size: 17),
                        label: const Text('Mark Area'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    onPressed: state.redactionMarks.isEmpty
                        ? null
                        : () {
                            final count = ctrl.applyAllRedactionsPermanently();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Permanently scrubbed $count sensitive occurrence(s) from document stream.',
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.gpp_good_rounded, size: 18),
                    label: Text(
                      strings.isSi
                          ? 'ස්ථිරවම මකා දමන්න (Apply Permanent Redactions • ${state.redactionMarks.length})'
                          : 'Apply Permanent Redactions (${state.redactionMarks.length} Marks)',
                    ),
                  ),
                  const Divider(height: 18),
                  Expanded(
                    child: ListView(
                      children: [
                        const Text(
                          'Live Page 1 Stream Preview (Verify Permanent Text Removal):',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            state.pageTexts[1] ?? '',
                            style: const TextStyle(
                              fontFamily: 'NotoSansSinhala',
                              fontSize: 12,
                            ),
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
      ],
    );
  }

  // ==========================================================================
  // Section 2: Document Compare (Side-by-Side Visual Diff & Line-by-Line Text Diff)
  // ==========================================================================

  Widget _buildDocumentCompareStudio(
    BuildContext context,
    PdfContentSecurityCompareState state,
    PdfContentSecurityCompareController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final report = state.comparisonReport;
    if (report == null) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Compare Summary & Mode Switcher (Side-by-Side Visual Diff vs Text Diff)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${report.leftFileName}  ↔  ${report.rightFileName}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      label: Text(
                        '+${report.addedLinesCount} Added • -${report.removedLinesCount} Removed • ~${report.modifiedLinesCount} Modified',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      icon: const Icon(Icons.view_column_rounded, size: 17),
                      label: Text(
                        strings.isSi
                            ? 'දෘශ්‍ය සංසන්දනය (Side-by-Side Visual Diff)'
                            : 'Side-by-Side Visual Diff',
                      ),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: const Icon(Icons.difference_rounded, size: 17),
                      label: Text(
                        strings.isSi
                            ? 'පෙළ වෙනස්කම් (Text Diff)'
                            : 'Line-by-Line Text Diff',
                      ),
                    ),
                  ],
                  selected: {_compareViewMode},
                  onSelectionChanged: (sel) =>
                      setState(() => _compareViewMode = sel.first),
                ),
              ],
            ),
            const Divider(height: 20),

            Expanded(
              child: _compareViewMode == 0
                  ? _buildSideBySideVisualDiff(report, colorScheme)
                  : _buildLineByLineTextDiff(report, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBySideVisualDiff(
    PdfDocumentComparisonReport report,
    ColorScheme colorScheme,
  ) {
    return ListView.builder(
      itemCount: report.visualPageDiffs.length,
      itemBuilder: (ctx, idx) {
        final vDiff = report.visualPageDiffs[idx];
        final pageNum = vDiff.pageNumber;
        final pageSegs = report.textDiffSegments
            .where((s) => s.pageNumber == pageNum)
            .toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Page $pageNum — Visual Change Density: ${vDiff.visualDifferencePercent.toStringAsFixed(1)}% '
                '(${vDiff.changedRegionBounds.length} highlighted region(s))',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Document Visual Sheet
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LEFT: ${report.leftFileName} (P.$pageNum)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                          const Divider(),
                          ...pageSegs
                              .where((s) => s.leftText.isNotEmpty)
                              .map((s) {
                            final isChanged =
                                s.kind != PdfDiffLineKind.unchanged;
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(4),
                              color: isChanged
                                  ? Colors.red.withOpacity(0.18)
                                  : Colors.transparent,
                              child: Text(
                                s.leftText,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansSinhala',
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Right Document Visual Sheet
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RIGHT: ${report.rightFileName} (P.$pageNum)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                          const Divider(),
                          ...pageSegs
                              .where((s) => s.rightText.isNotEmpty)
                              .map((s) {
                            final isChanged =
                                s.kind != PdfDiffLineKind.unchanged;
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(4),
                              color: isChanged
                                  ? Colors.green.withOpacity(0.22)
                                  : Colors.transparent,
                              child: Text(
                                s.rightText,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansSinhala',
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineByLineTextDiff(
    PdfDocumentComparisonReport report,
    ColorScheme colorScheme,
  ) {
    return ListView.builder(
      itemCount: report.textDiffSegments.length,
      itemBuilder: (ctx, idx) {
        final seg = report.textDiffSegments[idx];
        final (badge, bgColor) = switch (seg.kind) {
          PdfDiffLineKind.unchanged => ('=', Colors.transparent),
          PdfDiffLineKind.addedInRight => (
              '+ ADDED',
              Colors.green.withOpacity(0.16)
            ),
          PdfDiffLineKind.removedFromLeft => (
              '- REMOVED',
              Colors.red.withOpacity(0.16)
            ),
          PdfDiffLineKind.modifiedInBoth => (
              '~ MODIFIED',
              Colors.amber.withOpacity(0.20)
            ),
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.45),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  'P.${seg.pageNumber}:L${seg.lineNumber} $badge',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  seg.kind == PdfDiffLineKind.modifiedInBoth
                      ? '${seg.leftText}  →  ${seg.rightText}'
                      : (seg.rightText.isNotEmpty
                          ? seg.rightText
                          : seg.leftText),
                  style: const TextStyle(
                    fontFamily: 'NotoSansSinhala',
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
