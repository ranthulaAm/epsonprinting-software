import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/integration/global_command_palette_and_recent_files.dart';
import '../../../core/l10n/app_strings.dart';
import '../domain/pdf_annotations_Grouping_models.dart';
import 'pdf_annotation_signature_form_controller.dart';

class PdfAnnotationSignatureFormStudio extends ConsumerStatefulWidget {
  const PdfAnnotationSignatureFormStudio({super.key});

  @override
  ConsumerState<PdfAnnotationSignatureFormStudio> createState() =>
      _PdfAnnotationSignatureFormStudioState();
}

class _PdfAnnotationSignatureFormStudioState
    extends ConsumerState<PdfAnnotationSignatureFormStudio> {
  int _activeStudioSection = 0; // 0 = Annotations, 1 = Signatures & PKCS#12, 2 = AcroForms
  final TextEditingController _annotNoteCtrl = TextEditingController(
    text: 'සිංහල සහ English සටහන • Standard /Annot',
  );
  final TextEditingController _typedSigNameCtrl = TextEditingController(
    text: 'N. S. Jayasinghe (එන්. එස්. ජයසිංහ)',
  );
  final TextEditingController _typedSigInitialsCtrl = TextEditingController(
    text: 'N.S.J.',
  );
  final TextEditingController _pkcs12PathCtrl = TextEditingController(
    text: 'certificates/signer_identity.p12',
  );
  final TextEditingController _pkcs12PassCtrl = TextEditingController(
    text: 'offline-cert-pass-2026',
  );
  final TextEditingController _pkcs12CnCtrl = TextEditingController(
    text: 'R. A. Perera (Colombo Branch)',
  );

  @override
  void dispose() {
    _annotNoteCtrl.dispose();
    _typedSigNameCtrl.dispose();
    _typedSigInitialsCtrl.dispose();
    _pkcs12PathCtrl.dispose();
    _pkcs12PassCtrl.dispose();
    _pkcs12CnCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportStandardAnnotatedPdf(
    BuildContext context,
    PdfAnnotationSignatureFormController ctrl,
    AppStrings strings,
  ) async {
    final bytes = await ctrl.exportAnnotatedAndSignedPdfBytes(totalPages: 2);
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Annotated, Signed & Form-Filled PDF',
      fileName: 'annotated_signed_output.pdf',
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
                  ? 'සම්මත PDF සටහන් (/Annot), අත්සන් සහ පෝරම සමඟ සුරකින ලදී: $savePath'
                  : 'Saved PDF with standard ISO 32000-1 /Annot objects, signatures & forms: $savePath',
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
    final state = ref.watch(pdfAnnotationSignatureFormControllerProvider);
    final ctrl =
        ref.read(pdfAnnotationSignatureFormControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Studio Switcher: Annotations vs Signatures (Visual + PKCS#12) vs AcroForms + Save Standard PDF
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
                    icon: const Icon(Icons.draw_rounded, size: 17),
                    label: Text(
                      strings.isSi
                          ? 'සටහන් මෙවලම් (Annotations • ${state.annotations.length})'
                          : 'Annotations (${state.annotations.length})',
                    ),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.verified_user_outlined, size: 17),
                    label: Text(
                      strings.isSi
                          ? 'අත්සන් සහ PKCS#12 සහතික (Signatures)'
                          : 'Signatures & PKCS#12 Certs',
                    ),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: const Icon(Icons.assignment_outlined, size: 17),
                    label: Text(
                      strings.isSi
                          ? 'පෝරම පිරවුම (AcroForms • ${state.formFields.length})'
                          : 'AcroForms (${state.formFields.length})',
                    ),
                  ),
                ],
                selected: {_activeStudioSection},
                onSelectionChanged: (sel) =>
                    setState(() => _activeStudioSection = sel.first),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Undo Annotation',
                    onPressed: state.canUndo ? ctrl.undoAnnotation : null,
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  IconButton(
                    tooltip: 'Redo Annotation',
                    onPressed: state.canRedo ? ctrl.redoAnnotation : null,
                    icon: const Icon(Icons.redo_rounded),
                  ),
                  const SizedBox(width: 8),
                  const UniversalToolResultActionBar(
                    suggestedFileName: 'annotated_signed_output.pdf',
                    compact: true,
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () =>
                        _exportStandardAnnotatedPdf(context, ctrl, strings),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      strings.isSi
                          ? 'සම්මත PDF ලෙස සුරකින්න (Save Standard PDF)'
                          : 'Save Standard PDF (/Annot + Forms)',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Main Studio Content
        Expanded(
          child: switch (_activeStudioSection) {
            0 => _buildAnnotationsStudio(context, state, ctrl, strings),
            1 => _buildSignaturesAndPkcs12Studio(context, state, ctrl, strings),
            _ => _buildAcroFormsStudio(context, state, ctrl, strings),
          },
        ),
      ],
    );
  }

  // ==========================================================================
  // Section 0: All 14 Annotation Tools + Color/Thickness/Opacity + List Panel
  // ==========================================================================

  Widget _buildAnnotationsStudio(
    BuildContext context,
    PdfAnnotationSignatureFormState state,
    PdfAnnotationSignatureFormController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    const paletteColors = <int>[
      0xFFFFEB3B, // Yellow Highlight
      0xFF4CAF50, // Green
      0xFF2196F3, // Blue
      0xFFE53935, // Red Markup
      0xFF9C27B0, // Purple
      0xFF212121, // Charcoal Ink
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left & Center: Tool Palette + Style Controls + Interactive Page Canvas
        Expanded(
          flex: 3,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 14 Annotation Tools Wrap
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: PdfAnnotationToolType.values.map((tool) {
                      final isSelected = state.activeTool == tool;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          strings.isSi ? tool.labelSi : tool.labelEn,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onSelected: (_) => ctrl.selectAnnotationTool(tool),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Color, Thickness (Stroke Width), Opacity & Note Input Row
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Color Swatches
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: paletteColors.map((hex) {
                          final active = state.selectedColorHex == hex;
                          return GestureDetector(
                            onTap: () =>
                                ctrl.setAnnotationStyle(colorHex: hex),
                            child: Container(
                              width: 24,
                              height: 24,
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

                      // Thickness Slider
                      SizedBox(
                        width: 190,
                        child: Row(
                          children: [
                            Text(
                              'Width (${state.selectedStrokeWidth.toStringAsFixed(1)}pt):',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            Expanded(
                              child: Slider(
                                value: state.selectedStrokeWidth.clamp(1.0, 8.0),
                                min: 1.0,
                                max: 8.0,
                                onChanged: (v) => ctrl.setAnnotationStyle(
                                  strokeWidth: v,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Opacity Slider
                      SizedBox(
                        width: 190,
                        child: Row(
                          children: [
                            Text(
                              'Opacity (${(state.selectedOpacity * 100).round()}%):',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            Expanded(
                              child: Slider(
                                value: state.selectedOpacity.clamp(0.15, 1.0),
                                min: 0.15,
                                max: 1.0,
                                onChanged: (v) =>
                                    ctrl.setAnnotationStyle(opacity: v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _annotNoteCtrl,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: strings.isSi
                                ? 'සටහන් පෙළ හෝ මුද්‍රාව (Text Box / Sticky Note / Stamp Content)'
                                : 'Annotation Text / Sticky Note / Stamp Label (සිංහල Ready)',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonalIcon(
                        onPressed: () => ctrl.addAnnotation(
                          pageNumber: 1,
                          contents: _annotNoteCtrl.text,
                          inkPoints: state.activeTool ==
                                  PdfAnnotationToolType.measurement
                              ? const <PdfPoint>[
                                  PdfPoint(40, 100),
                                  PdfPoint(220, 100),
                                ]
                              : const <PdfPoint>[],
                        ),
                        icon: const Icon(Icons.add_comment_rounded, size: 17),
                        label: Text(
                          strings.isSi
                              ? 'පිටුවට එක් කරන්න (Add to Page)'
                              : 'Place on Page',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Interactive Page Annotation Canvas
                  Expanded(
                    child: GestureDetector(
                      onTapUp: (details) {
                        final pt = PdfPoint(
                          details.localPosition.dx,
                          details.localPosition.dy,
                        );
                        if (state.activeTool == PdfAnnotationToolType.eraser) {
                          ctrl.eraseAnnotationsAtPoint(1, pt);
                        } else if (state.activeTool !=
                            PdfAnnotationToolType.selectPan) {
                          ctrl.addAnnotation(
                            pageNumber: 1,
                            boundsOverride: PdfRectBounds(
                              left: pt.x.clamp(16.0, 420.0),
                              top: pt.y.clamp(16.0, 260.0),
                              width: 185,
                              height: 36,
                            ),
                            contents: _annotNoteCtrl.text,
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Stack(
                          children: [
                            const Positioned(
                              left: 24,
                              top: 20,
                              child: Text(
                                'Click anywhere on the page to place the selected annotation (or click with Eraser to remove).\n'
                                'ශ්‍රී ලංකා මුද්‍රණ සහායක — සම්මත PDF සටහන් (ISO 32000-1 /Annot)',
                                style: TextStyle(
                                  fontFamily: 'NotoSansSinhala',
                                  fontSize: 12.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            ...state.annotations.map((annot) {
                              return Positioned(
                                left: annot.bounds.left,
                                top: annot.bounds.top,
                                child: Opacity(
                                  opacity: annot.opacity,
                                  child: Container(
                                    width: annot.bounds.width,
                                    height: annot.bounds.height,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: annot.toolType ==
                                              PdfAnnotationToolType.highlight
                                          ? Color(annot.colorHex)
                                              .withOpacity(0.45)
                                          : Color(annot.colorHex)
                                              .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(
                                        annot.toolType ==
                                                PdfAnnotationToolType.ellipse
                                            ? 999
                                            : 4,
                                      ),
                                      border: Border.all(
                                        color: Color(annot.colorHex),
                                        width: annot.strokeWidth,
                                      ),
                                    ),
                                    child: Text(
                                      annot.toolType ==
                                              PdfAnnotationToolType.measurement
                                          ? '📏 ${annot.measuredDistanceMm.toStringAsFixed(1)} mm'
                                          : '${annot.toolType.pdfSubtype}: ${annot.contents}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'NotoSansSinhala',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Right: Annotations List Panel (Inspect ISO 32000-1 Subtype, Jump, or Delete)
        SizedBox(
          width: 340,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.isSi
                        ? 'සටහන් ලැයිස්තුව (Annotations List • ${state.annotations.length})'
                        : 'Annotations List Panel (${state.annotations.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Divider(),
                  Expanded(
                    child: state.annotations.isEmpty
                        ? Center(
                            child: Text(
                              strings.isSi
                                  ? 'තවමත් සටහන් එක් කර නොමැත.'
                                  : 'No annotations added yet.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: state.annotations.length,
                            itemBuilder: (ctx, idx) {
                              final item = state.annotations[idx];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(item.colorHex),
                                ),
                                title: Text(
                                  '${item.toolType.labelEn} (${item.toolType.pdfSubtype})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  item.toolType ==
                                          PdfAnnotationToolType.measurement
                                      ? 'Page ${item.pageNumber} • ${item.measuredDistanceMm.toStringAsFixed(2)} mm'
                                      : 'Page ${item.pageNumber} • ${item.contents}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: colorScheme.error,
                                  ),
                                  onPressed: () =>
                                      ctrl.eraseAnnotationById(item.id),
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

  // ==========================================================================
  // Section 1: Visual Signatures (Draw/Type/Import, Date, Initials) + PKCS#12
  // ==========================================================================

  Widget _buildSignaturesAndPkcs12Studio(
    BuildContext context,
    PdfAnnotationSignatureFormState state,
    PdfAnnotationSignatureFormController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final sigRecord = state.digitalSignatureRecord;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Visual Signatures, Saved Profiles, Initials & Date Stamp Placement
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
                        ? '1. අත්සන නිර්මාණය සහ සුරැකීම (Draw, Type, or Import Image)'
                        : '1. Create & Save Visual Signature / Initials Profile',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _typedSigNameCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Full Signature Name (English / සිංහල)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _typedSigInitialsCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Initials',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          ctrl.saveNewSignatureProfile(
                            label: _typedSigNameCtrl.text,
                            sourceMode: SignatureSourceMode.typedText,
                            signerFullName: _typedSigNameCtrl.text,
                            initialsText: _typedSigInitialsCtrl.text,
                            typedSignatureText: _typedSigNameCtrl.text,
                          );
                        },
                        icon: const Icon(Icons.keyboard_rounded, size: 17),
                        label: Text(
                          strings.isSi
                              ? 'ටයිප් කළ අත්සන සුරකින්න'
                              : 'Save Typed Signature',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          ctrl.saveNewSignatureProfile(
                            label: 'Drawn Ink (${_typedSigInitialsCtrl.text})',
                            sourceMode: SignatureSourceMode.drawnStroke,
                            signerFullName: _typedSigNameCtrl.text,
                            initialsText: _typedSigInitialsCtrl.text,
                            strokePoints: const <PdfPoint>[
                              PdfPoint(10, 30),
                              PdfPoint(55, 12),
                              PdfPoint(120, 28),
                            ],
                          );
                        },
                        icon: const Icon(Icons.gesture_rounded, size: 17),
                        label: Text(
                          strings.isSi ? 'ඇඳි අත්සන සුරකින්න' : 'Save Drawn Signature',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final res = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: const ['png', 'jpg', 'webp'],
                          );
                          if (res != null && res.files.single.path != null) {
                            final bytes =
                                await File(res.files.single.path!).readAsBytes();
                            ctrl.saveNewSignatureProfile(
                              label: 'Imported Image Signature',
                              sourceMode: SignatureSourceMode.importedImage,
                              signerFullName: _typedSigNameCtrl.text,
                              initialsText: _typedSigInitialsCtrl.text,
                              imageBytes: bytes,
                            );
                          }
                        },
                        icon: const Icon(Icons.image_outlined, size: 17),
                        label: Text(
                          strings.isSi ? 'රූපයක් ආයාත කරන්න' : 'Import Signature Image',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    strings.isSi
                        ? 'සුරැකි අත්සන් (${state.savedSignatures.length}) — පිටුව මත තබන්න:'
                        : 'Saved Signatures (${state.savedSignatures.length}) — Place on Page:',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...state.savedSignatures.map((prof) {
                    return Card(
                      color: colorScheme.surfaceContainerLow,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          prof.signerFullName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Initials: ${prof.initialsText} • Mode: ${prof.sourceMode.name}',
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => ctrl.placeSignatureOnPage(
                                profileId: prof.id,
                                pageNumber: 1,
                                isInitialsOnly: false,
                                includeDateStamp: true,
                              ),
                              child: const Text('Place Signature + Date'),
                            ),
                            OutlinedButton(
                              onPressed: () => ctrl.placeSignatureOnPage(
                                profileId: prof.id,
                                pageNumber: 1,
                                isInitialsOnly: true,
                                includeDateStamp: true,
                              ),
                              child: const Text('Place Initials'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (state.placedSignatures.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Placed on Pages (${state.placedSignatures.length}):',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    ...state.placedSignatures.map(
                      (pSig) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'P.${pSig.pageNumber}: ${pSig.displayText} (${pSig.dateFormatted})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          'Size: ${pSig.bounds.width.round()}×${pSig.bounds.height.round()} pt',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () =>
                              ctrl.removePlacedSignature(pSig.placementId),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Right: Cryptographic PKCS#12 (.p12 / .pfx) Digital Signing & Signature Validation
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded,
                          color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.isSi
                              ? '2. PKCS#12 (.p12 / .pfx) ඩිජිටල් අත්සන සහ වලංගුතා පරීක්ෂාව'
                              : '2. Cryptographic PKCS#12 Digital Signature & Validation',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pkcs12PathCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'PKCS#12 Certificate File (.p12 / .pfx)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pkcs12PassCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Certificate Passphrase',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _pkcs12CnCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Signer Common Name (CN)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => ctrl.applyPkcs12DigitalSignature(
                          pkcs12FilePath: _pkcs12PathCtrl.text,
                          passphrase: _pkcs12PassCtrl.text,
                          signerCommonName: _pkcs12CnCtrl.text,
                        ),
                        icon: const Icon(Icons.key_rounded, size: 18),
                        label: Text(
                          strings.isSi
                              ? 'PKCS#12 සහතිකයෙන් අත්සන් කරන්න'
                              : 'Sign PDF with PKCS#12 Certificate',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: sigRecord == null
                            ? null
                            : () => ctrl.verifyCurrentDigitalSignature(),
                        icon: const Icon(Icons.fact_check_outlined, size: 18),
                        label: Text(
                          strings.isSi
                              ? 'අත්සනේ වලංගුභාවය පරීක්ෂා කරන්න'
                              : 'Validate Digital Signature',
                        ),
                      ),
                    ],
                  ),
                  if (sigRecord != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: sigRecord.isValid
                            ? Colors.green.withOpacity(0.12)
                            : colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sigRecord.isValid
                              ? Colors.green.shade700
                              : colorScheme.error,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                sigRecord.isValid
                                    ? Icons.verified_rounded
                                    : Icons.gpp_bad_rounded,
                                color: sigRecord.isValid
                                    ? Colors.green.shade700
                                    : colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  sigRecord.isValid
                                      ? 'VALID PKCS#12 DIGITAL SIGNATURE — Document Untampered'
                                      : 'INVALID SIGNATURE — Document Modified After Signing',
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
                            'Signer CN: ${sigRecord.signerCommonName}\n'
                            'Cert Serial: ${sigRecord.certificateSerialHex}\n'
                            'SHA-256 Digest: ${sigRecord.documentDigestSha256Hex.substring(0, 32)}...\n'
                            'Signed At (UTC): ${sigRecord.signedAtUtc.toIso8601String()}',
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Section 2: AcroForms (Fill, Highlight, Flatten, Import/Export, Auto-Detect)
  // ==========================================================================

  Widget _buildAcroFormsStudio(
    BuildContext context,
    PdfAnnotationSignatureFormState state,
    PdfAnnotationSignatureFormController ctrl,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AcroForm Toolbar: Highlight Toggle, Auto-Detect Flat Form Fields, Flatten, Import/Export JSON
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilterChip(
                      selected: state.highlightFormFields,
                      onSelected: ctrl.toggleHighlightFormFields,
                      avatar: const Icon(Icons.highlight_alt_rounded, size: 16),
                      label: Text(
                        strings.isSi
                            ? 'පෝරම ක්ෂේත්‍ර උද්දීපනය කරන්න'
                            : 'Highlight Form Fields',
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (state.isFormFlattened)
                      Chip(
                        avatar: const Icon(Icons.lock_rounded, size: 15),
                        label: Text(
                          strings.isSi
                              ? 'පෝරමය ස්ථිර කර ඇත (Flattened)'
                              : 'Form Flattened (Read-Only)',
                        ),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        final count = ctrl.runFlatFormFieldAutoDetection(
                          const <int, String>{
                            1: 'National ID / හැඳුනුම්පත් අංකය: ____________\n'
                                '[ ] I confirm the Sinhala & English details are accurate\n'
                                'Date / දිනය: __________',
                          },
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Auto-detected $count form fields from flat page patterns.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                      label: Text(
                        strings.isSi
                            ? 'ක්ෂේත්‍ර ස්වයංක්‍රීයව හඳුනාගන්න (Auto-Detect)'
                            : 'Auto-Detect Flat Form Fields',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final jsonStr = ctrl.exportFormFieldsAsJson();
                        Clipboard.setData(ClipboardData(text: jsonStr));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Exported AcroForm data (JSON) to clipboard.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(
                        strings.isSi ? 'දත්ත නිර්යාත කරන්න (Export)' : 'Export Form Data',
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: state.isFormFlattened
                          ? null
                          : ctrl.flattenAcroFormFields,
                      icon: const Icon(Icons.layers_clear_rounded, size: 16),
                      label: Text(
                        strings.isSi
                            ? 'පෝරමය ස්ථිර කරන්න (Flatten Form)'
                            : 'Flatten Form Fields',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),

            // Interactive Form Fields List (Text, Checkbox, Radio, Dropdown, Auto-Detected)
            Expanded(
              child: ListView.builder(
                itemCount: state.formFields.length,
                itemBuilder: (ctx, idx) {
                  final field = state.formFields[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: state.highlightFormFields
                          ? colorScheme.primaryContainer.withOpacity(0.24)
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: state.highlightFormFields
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                field.label,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansSinhala',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Field Name: ${field.fieldName} • Type: ${field.fieldType.name}'
                                '${field.isAutoDetectedFromFlatPage ? " • [Auto-Detected]" : ""}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _buildFormFieldControl(
                            field,
                            state.isFormFlattened,
                            ctrl,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFieldControl(
    PdfAcroFormField field,
    bool isFlattened,
    PdfAnnotationSignatureFormController ctrl,
  ) {
    switch (field.fieldType) {
      case PdfAcroFormFieldType.checkbox:
        return CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: field.checkedValue,
          onChanged: isFlattened
              ? null
              : (val) => ctrl.updateFormFieldValue(
                    fieldName: field.fieldName,
                    checkedValue: val ?? false,
                  ),
          title: Text(field.checkedValue ? 'Checked (✓)' : 'Unchecked'),
        );

      case PdfAcroFormFieldType.dropdown:
        return DropdownButtonFormField<String>(
          value: field.options.contains(field.selectedOption)
              ? field.selectedOption
              : (field.options.isNotEmpty ? field.options.first : null),
          isDense: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: field.options
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
              .toList(),
          onChanged: isFlattened
              ? null
              : (val) {
                  if (val != null) {
                    ctrl.updateFormFieldValue(
                      fieldName: field.fieldName,
                      selectedOption: val,
                    );
                  }
                },
        );

      case PdfAcroFormFieldType.radioGroup:
        return Wrap(
          spacing: 8,
          children: field.options.map((opt) {
            final selected = field.selectedOption == opt;
            return ChoiceChip(
              selected: selected,
              label: Text(opt, style: const TextStyle(fontSize: 12)),
              onSelected: isFlattened
                  ? null
                  : (_) => ctrl.updateFormFieldValue(
                        fieldName: field.fieldName,
                        selectedOption: opt,
                      ),
            );
          }).toList(),
        );

      default:
        return TextFormField(
          initialValue: field.textValue,
          enabled: !isFlattened,
          style: const TextStyle(fontFamily: 'NotoSansSinhala', fontSize: 13),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => ctrl.updateFormFieldValue(
            fieldName: field.fieldName,
            textValue: val,
          ),
        );
    }
  }
}
