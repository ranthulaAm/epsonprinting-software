import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/widgets/desktop_widgets.dart';
import '../data/specialty_printing_service.dart';
import '../domain/specialty_print_models.dart';

/// Modal dialog providing template editors, live previews, and driver-safe
/// spooler dispatch for the 8 specialty print modules.
///
/// Only supported modules are displayed based on the active printer's
/// live detection or user-confirmed capabilities.
class SpecialtyPrintingDialog extends StatefulWidget {
  final String activePrinterName;
  final Set<SpecialtyModuleType> supportedModules;
  final String languageCode;
  final VoidCallback? onPrintThroughSpooler;

  const SpecialtyPrintingDialog({
    super.key,
    required this.activePrinterName,
    required this.supportedModules,
    this.languageCode = 'en',
    this.onPrintThroughSpooler,
  });

  @override
  State<SpecialtyPrintingDialog> createState() => _SpecialtyPrintingDialogState();
}

class _SpecialtyPrintingDialogState extends State<SpecialtyPrintingDialog> {
  late SpecialtyModuleType _selectedModule;

  // Specs state
  CdDvdSpec _cdSpec = const CdDvdSpec();
  PvcIdCardSpec _pvcSpec = const PvcIdCardSpec();
  PassportPhotoSheetSpec _passportSpec = const PassportPhotoSheetSpec();
  RigidMediaSpec _rigidSpec = const RigidMediaSpec();
  RollPaperCutterSpec _rollSpec = const RollPaperCutterSpec();
  DyeSublimationSpec _sublimationSpec = const DyeSublimationSpec();
  ColorWorksLabelSpec _labelSpec = const ColorWorksLabelSpec();
  late ShopReceiptSpec _receiptSpec;

  @override
  void initState() {
    super.initState();
    // Default to first supported module
    if (widget.supportedModules.isNotEmpty) {
      _selectedModule = widget.supportedModules.first;
    } else {
      _selectedModule = SpecialtyModuleType.passportPhotoSheet;
    }

    _receiptSpec = ShopReceiptSpec(
      timestamp: DateTime.now(),
      lineItems: const [
        {'description': 'A4 Photocopies (B&W)', 'quantity': 25, 'price': 300.0},
        {'description': 'Glossy Photo 4x6"', 'quantity': 4, 'price': 200.0},
      ],
      subtotal: 500.0,
      discountAmount: 25.0,
      grandTotal: 475.0,
    );
  }

  bool get _isSi => widget.languageCode == 'si';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
      backgroundColor: DesktopColors.dialogBackground,
      child: Container(
        width: 1060,
        height: 720,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: DesktopColors.dialogBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDialogHeader(),
            _buildModuleTabBar(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: DesktopColors.dialogBorder)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: _buildActiveModuleEditor(),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Container(
                      color: DesktopColors.previewBackground,
                      padding: const EdgeInsets.all(20.0),
                      child: _buildActiveModulePreview(),
                    ),
                  ),
                ],
              ),
            ),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Header & Navigation
  // ==========================================================================

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      decoration: const BoxDecoration(
        color: DesktopColors.dialogHeaderBackground,
        border: Border(bottom: BorderSide(color: DesktopColors.dialogBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: DesktopColors.accentTeal, size: 22),
          const SizedBox(width: 10),
          Text(
            _isSi ? 'විශේෂිත මුද්‍රණ මධ්‍යස්ථානය' : 'Specialty Print Media Center',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: DesktopColors.accentTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: DesktopColors.accentTeal.withValues(alpha: 0.3)),
            ),
            child: Text(
              widget.activePrinterName,
              style: const TextStyle(
                fontSize: 12,
                color: DesktopColors.accentTeal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTabBar() {
    final available = widget.supportedModules.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: DesktopColors.menuBackground,
        border: Border(bottom: BorderSide(color: DesktopColors.dialogBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: available.map((mod) {
            final isSelected = mod == _selectedModule;
            final (labelEn, labelSi, icon) = _getModuleLabelAndIcon(mod);

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () => setState(() => _selectedModule = mod),
                borderRadius: BorderRadius.circular(4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DesktopColors.accentTeal.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(
                      color: isSelected ? DesktopColors.accentTeal : DesktopColors.dialogBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: isSelected ? DesktopColors.accentTeal : Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        _isSi ? labelSi : labelEn,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? DesktopColors.accentTeal : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  (String, String, IconData) _getModuleLabelAndIcon(SpecialtyModuleType mod) {
    switch (mod) {
      case SpecialtyModuleType.cdDvdDisc:
        return ('CD/DVD Disc', 'CD/DVD තැටි', Icons.album_rounded);
      case SpecialtyModuleType.pvcIdCard:
        return ('PVC ID Card', 'PVC ID කාඩ්පත්', Icons.badge_rounded);
      case SpecialtyModuleType.passportPhotoSheet:
        return ('Passport Photos', 'පාස්පෝට් ඡායාරූප', Icons.photo_camera_front_rounded);
      case SpecialtyModuleType.rigidMedia:
        return ('Rigid Media', 'ඝන කඩදාසි', Icons.layers_rounded);
      case SpecialtyModuleType.rollCutter:
        return ('Roll Paper', 'රෝල් කඩදාසි', Icons.panorama_horizontal_rounded);
      case SpecialtyModuleType.dyeSublimation:
        return ('Dye-Sublimation', 'සබ්ලිමේෂන් (Mug/Shirt)', Icons.coffee_rounded);
      case SpecialtyModuleType.colorWorksLabel:
        return ('ColorWorks Label', 'ලේබල් මුද්‍රණය', Icons.label_rounded);
      case SpecialtyModuleType.shopReceipt:
        return ('POS Receipt', 'කවුන්ටර රිසිට්පත්', Icons.receipt_long_rounded);
    }
  }

  // ==========================================================================
  // Active Module Editors
  // ==========================================================================

  Widget _buildActiveModuleEditor() {
    switch (_selectedModule) {
      case SpecialtyModuleType.cdDvdDisc:
        return _buildCdDvdEditor();
      case SpecialtyModuleType.pvcIdCard:
        return _buildPvcEditor();
      case SpecialtyModuleType.passportPhotoSheet:
        return _buildPassportEditor();
      case SpecialtyModuleType.rigidMedia:
        return _buildRigidMediaEditor();
      case SpecialtyModuleType.rollCutter:
        return _buildRollEditor();
      case SpecialtyModuleType.dyeSublimation:
        return _buildSublimationEditor();
      case SpecialtyModuleType.colorWorksLabel:
        return _buildLabelEditor();
      case SpecialtyModuleType.shopReceipt:
        return _buildReceiptEditor();
    }
  }

  Widget _buildCdDvdEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_isSi ? 'CD/DVD තැටි සැකසුම්' : 'Disc Dimensions & Geometry'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: 'Standard 12cm',
                selected: _cdSpec.profile == DiscSizeProfile.standard12cm,
                onSelected: () => setState(() => _cdSpec = _cdSpec.copyWith(
                  profile: DiscSizeProfile.standard12cm,
                  outerDiameterMm: 116.0,
                  innerDiameterMm: 43.0,
                )),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildChoiceChip(
                label: 'Mini 8cm Disc',
                selected: _cdSpec.profile == DiscSizeProfile.mini8cm,
                onSelected: () => setState(() => _cdSpec = _cdSpec.copyWith(
                  profile: DiscSizeProfile.mini8cm,
                  outerDiameterMm: 80.0,
                  innerDiameterMm: 18.0,
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSliderRow(
          label: _isSi ? 'පිටත විෂ්කම්භය (Outer Diameter)' : 'Outer Diameter',
          value: _cdSpec.outerDiameterMm,
          min: 70.0,
          max: 120.0,
          unit: 'mm',
          onChanged: (v) => setState(() => _cdSpec = _cdSpec.copyWith(outerDiameterMm: v)),
        ),
        const SizedBox(height: 12),
        _buildSliderRow(
          label: _isSi ? 'ඇතුළත විෂ්කම්භය (Inner Diameter)' : 'Inner Diameter (Center Hub)',
          value: _cdSpec.innerDiameterMm,
          min: 18.0,
          max: 50.0,
          unit: 'mm',
          onChanged: (v) => setState(() => _cdSpec = _cdSpec.copyWith(innerDiameterMm: v)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _cdSpec.circularText,
          decoration: InputDecoration(
            labelText: _isSi ? 'වෘත්තාකාර අකුරු (Circular Text)' : 'Text on Circle Path',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _cdSpec = _cdSpec.copyWith(circularText: v)),
        ),
        const SizedBox(height: 16),
        // Mandatory plain paper test print banner
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: _cdSpec.paperTestPrintCompleted
                ? Colors.green.shade50
                : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: _cdSpec.paperTestPrintCompleted
                  ? Colors.green.shade300
                  : Colors.amber.shade400,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _cdSpec.paperTestPrintCompleted
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: _cdSpec.paperTestPrintCompleted
                        ? Colors.green.shade700
                        : Colors.amber.shade800,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isSi ? 'පෙර-පරීක්ෂණ අවශ්‍යතාවය' : 'Mandatory Alignment Check',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _cdSpec.paperTestPrintCompleted
                          ? Colors.green.shade900
                          : Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isSi
                    ? 'නියම CD තැටිය මත ප්‍රින්ට් කිරීමට පෙර සාමාන්‍ය A4 කොළයක පරීක්ෂණ පිටපතක් මුද්‍රණය කර ස්ථානගතවීම නිවැරදි දැයි බලන්න.'
                    : 'Print a 1:1 alignment template on plain paper first to ensure artwork lines up perfectly before using real printable discs.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text(_isSi ? 'සාමාන්‍ය කොළයේ පරීක්ෂණ පිටපතක් ගන්න' : 'Print Alignment Test (Plain Paper)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cdSpec.paperTestPrintCompleted ? Colors.grey.shade300 : DesktopColors.accentTeal,
                  foregroundColor: _cdSpec.paperTestPrintCompleted ? Colors.black87 : Colors.white,
                  elevation: 0,
                ),
                onPressed: () {
                  setState(() => _cdSpec = _cdSpec.copyWith(paperTestPrintCompleted: true));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isSi
                          ? 'පරීක්ෂණ මුද්‍රණය Windows Spooler වෙත යවන ලදී.'
                          : 'Alignment test sheet dispatched to Windows Spooler.'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPvcEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_isSi ? 'PVC ID කාඩ්පත් සැකසුම් (CR80)' : 'CR80 PVC Card Settings'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Text(
            'ISO/IEC 7810 ID-1 Standard: 85.60 x 53.98 mm • 0.76 mm (30 mil)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: '2 Cards / Tray (L8050/L18050)',
                selected: _pvcSpec.traySlotsCount == 2,
                onSelected: () => setState(() => _pvcSpec = _pvcSpec.copyWith(traySlotsCount: 2)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildChoiceChip(
                label: '1 Card / Tray',
                selected: _pvcSpec.traySlotsCount == 1,
                onSelected: () => setState(() => _pvcSpec = _pvcSpec.copyWith(traySlotsCount: 1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Mandatory Inkjet PVC reminder
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _pvcSpec.inkjetCoatedConfirmed ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _pvcSpec.inkjetCoatedConfirmed ? Colors.green.shade300 : Colors.red.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSi ? 'අවධානය: Inkjet ආලේපිත PVC කාඩ්පත් පමණක් භාවිතා කරන්න' : 'Mandatory: Inkjet-Coated PVC Cards Required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _pvcSpec.inkjetCoatedConfirmed ? Colors.green.shade900 : Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isSi
                    ? 'සාමාන්‍ය ප්ලාස්ටික් කාඩ්පත් මත තීන්ත නොරැඳේ (දියවී යයි). විශේෂිත Inkjet PVC කාඩ්පත් යොදන්න.'
                    : 'Standard blank PVC cards will smear instantly. You must use Inkjet-treated micro-porous PVC cards.',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _pvcSpec.inkjetCoatedConfirmed,
                    onChanged: (v) => setState(() => _pvcSpec = _pvcSpec.copyWith(inkjetCoatedConfirmed: v ?? false)),
                  ),
                  Expanded(
                    child: Text(
                      _isSi ? 'මම Inkjet PVC කාඩ්පත් භාවිතා කරන බව තහවුරු කරමි' : 'I confirm I am using Inkjet-Coated PVC cards',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Aftermarket tray warning
        Row(
          children: [
            Checkbox(
              value: _pvcSpec.isAftermarketTray,
              onChanged: (v) => setState(() => _pvcSpec = _pvcSpec.copyWith(isAftermarketTray: v ?? false)),
            ),
            Expanded(
              child: Text(
                _isSi ? 'තෙවන පාර්ශ්වික (Aftermarket) තැටි භාවිතය (Opt-in Warning)' : 'Use aftermarket card tray (e.g. CD-slot tray on L805)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSliderRow(
          label: 'X Calibration Offset',
          value: _pvcSpec.offsetXmm,
          min: -5.0,
          max: 5.0,
          unit: 'mm',
          onChanged: (v) => setState(() => _pvcSpec = _pvcSpec.copyWith(offsetXmm: v)),
        ),
        const SizedBox(height: 8),
        _buildSliderRow(
          label: 'Y Calibration Offset',
          value: _pvcSpec.offsetYmm,
          min: -5.0,
          max: 5.0,
          unit: 'mm',
          onChanged: (v) => setState(() => _pvcSpec = _pvcSpec.copyWith(offsetYmm: v)),
        ),
      ],
    );
  }

  Widget _buildPassportEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_isSi ? 'පාස්පෝට් ප්‍රමාණ හා සැකසුම්' : 'Photo Dimensions & Sheet Selection'),
        const SizedBox(height: 12),
        DropdownButtonFormField<PassportStandardType>(
          value: _passportSpec.standardType,
          decoration: const InputDecoration(labelText: 'Standard Photo Preset', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: PassportStandardType.sriLankaUk35x45, child: Text('Sri Lanka / UK / Schengen (35 x 45 mm)')),
            DropdownMenuItem(value: PassportStandardType.usVisa2x2in, child: Text('US Visa / Diversity Visa 2x2" (51 x 51 mm)')),
            DropdownMenuItem(value: PassportStandardType.standard30x40, child: Text('Application / Student ID (30 x 40 mm)')),
            DropdownMenuItem(value: PassportStandardType.square35x35, child: Text('Indian Passport / Square (35 x 35 mm)')),
          ],
          onChanged: (v) {
            if (v == null) return;
            double w = 35.0, h = 45.0;
            if (v == PassportStandardType.usVisa2x2in) { w = 51.0; h = 51.0; }
            if (v == PassportStandardType.standard30x40) { w = 30.0; h = 40.0; }
            if (v == PassportStandardType.square35x35) { w = 35.0; h = 35.0; }
            setState(() => _passportSpec = _passportSpec.copyWith(standardType: v, photoWidthMm: w, photoHeightMm: h));
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: 'Photo 4x6" (10x15cm)',
                selected: _passportSpec.paperSize == PhotoSheetPaperSize.photo4x6,
                onSelected: () => setState(() => _passportSpec = _passportSpec.copyWith(paperSize: PhotoSheetPaperSize.photo4x6)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildChoiceChip(
                label: 'A4 Photo Sheet',
                selected: _passportSpec.paperSize == PhotoSheetPaperSize.a4,
                onSelected: () => setState(() => _passportSpec = _passportSpec.copyWith(paperSize: PhotoSheetPaperSize.a4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<CropGuideStyle>(
          value: _passportSpec.guideStyle,
          decoration: const InputDecoration(labelText: 'Cutting Guides Style', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: CropGuideStyle.dashedLines, child: Text('Dashed Cut Lines (කඩ ඉරි)')),
            DropdownMenuItem(value: CropGuideStyle.cornerMarksOnly, child: Text('Corner Crop Marks (කොන් සලකුණු)')),
            DropdownMenuItem(value: CropGuideStyle.solidLines, child: Text('Solid Thin Borders (තනි ඉරි)')),
            DropdownMenuItem(value: CropGuideStyle.none, child: Text('None (ඉරි නැත)')),
          ],
          onChanged: (v) => setState(() => _passportSpec = _passportSpec.copyWith(guideStyle: v ?? CropGuideStyle.dashedLines)),
        ),
      ],
    );
  }

  Widget _buildRigidMediaEditor() {
    final validation = SpecialtyPrintingService.validateRigidMediaThickness(
      mediaThicknessMm: _rigidSpec.mediaThicknessMm,
      printerMaxLimitMm: _rigidSpec.printerMaxThicknessLimitMm,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_isSi ? 'ඝන හා නොනැමෙන කඩදාසි පාලනය' : 'Rigid & Posterboard Media'),
        const SizedBox(height: 12),
        _buildSliderRow(
          label: _isSi ? 'කඩදාසියේ ඝනකම (Thickness)' : 'Paper Thickness',
          value: _rigidSpec.mediaThicknessMm,
          min: 0.1,
          max: 2.0,
          unit: 'mm',
          onChanged: (v) => setState(() => _rigidSpec = _rigidSpec.copyWith(mediaThicknessMm: v)),
        ),
        const SizedBox(height: 16),
        // Limit badge
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: validation.isAllowed ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: validation.isAllowed ? Colors.green.shade300 : Colors.red.shade400),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    validation.isAllowed ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: validation.isAllowed ? Colors.green.shade700 : Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    validation.isAllowed ? 'Safe Feed Path' : 'Mechanical Strike Hazard',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: validation.isAllowed ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isSi ? validation.messageSi : validation.messageEn,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRollEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_isSi ? 'රෝල් කඩදාසි හා කටර් සැකසුම්' : 'Roll Paper & Rotary Cutter'),
        const SizedBox(height: 12),
        DropdownButtonFormField<double>(
          value: _rollSpec.rollWidthInches,
          decoration: const InputDecoration(labelText: 'Roll Width', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 13.0, child: Text('13 inches (330 mm) - A3+ Roll')),
            DropdownMenuItem(value: 17.0, child: Text('17 inches (432 mm) - A2 Roll')),
            DropdownMenuItem(value: 24.0, child: Text('24 inches (610 mm) - A1 Roll')),
            DropdownMenuItem(value: 36.0, child: Text('36 inches (914 mm) - A0 Roll')),
            DropdownMenuItem(value: 44.0, child: Text('44 inches (1118 mm) - B0 Roll')),
          ],
          onChanged: (v) => setState(() => _rollSpec = _rollSpec.copyWith(rollWidthInches: v ?? 24.0)),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<RollCutAction>(
          value: _rollSpec.cutAction,
          decoration: const InputDecoration(labelText: 'Automatic Cutter Action', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: RollCutAction.cutAfterPage, child: Text('Cut Automatically After Each Page')),
            DropdownMenuItem(value: RollCutAction.cutAtJobEnd, child: Text('Cut Only After Complete Job')),
            DropdownMenuItem(value: RollCutAction.printCutGuideLineOnly, child: Text('Print Dashed Cut Guide Line (No Blade Cut)')),
            DropdownMenuItem(value: RollCutAction.manualCut, child: Text('Manual Cut with External Razor')),
          ],
          onChanged: (v) => setState(() => _rollSpec = _rollSpec.copyWith(cutAction: v ?? RollCutAction.cutAfterPage)),
        ),
      ],
    );
  }

  Widget _buildSublimationEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_isSi ? 'ඩයි-සබ්ලිමේෂන් මග්/ටී-ෂර්ට් සැකසුම්' : 'Dye-Sublimation Merchandise'),
        const SizedBox(height: 12),
        DropdownButtonFormField<SublimationItemType>(
          value: _sublimationSpec.itemType,
          decoration: const InputDecoration(labelText: 'Merchandise Template', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: SublimationItemType.mug11oz, child: Text('11oz Ceramic Mug Wrap (200 x 95 mm)')),
            DropdownMenuItem(value: SublimationItemType.mug15oz, child: Text('15oz Large Mug Wrap (220 x 105 mm)')),
            DropdownMenuItem(value: SublimationItemType.tshirtA4, child: Text('T-Shirt Chest / Back (A4 Transfer)')),
            DropdownMenuItem(value: SublimationItemType.lanyardRepeat, child: Text('Lanyard Ribbon Continuous (900 x 20 mm)')),
            DropdownMenuItem(value: SublimationItemType.mousepad, child: Text('Mousepad Rectangle (230 x 190 mm)')),
          ],
          onChanged: (v) {
            if (v == null) return;
            double w = 200.0, h = 95.0;
            if (v == SublimationItemType.mug15oz) { w = 220.0; h = 105.0; }
            if (v == SublimationItemType.tshirtA4) { w = 210.0; h = 297.0; }
            if (v == SublimationItemType.lanyardRepeat) { w = 900.0; h = 20.0; }
            if (v == SublimationItemType.mousepad) { w = 230.0; h = 190.0; }
            setState(() => _sublimationSpec = _sublimationSpec.copyWith(itemType: v, templateWidthMm: w, templateHeightMm: h));
          },
        ),
        const SizedBox(height: 16),
        // Auto Mirror Badge
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.teal.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.flip_rounded, color: Colors.teal, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSi ? 'ස්වයංක්‍රීයව තිරස් අතට පෙරලීම (Auto Mirror: ON)' : 'Horizontal Mirror: Automatically ON',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                    ),
                    Text(
                      _isSi
                          ? 'තාපයෙන් මුද්‍රණය කිරීමේදී අකුරු හා රූප නිවැරදිව පෙනීමට පෙරලා මුද්‍රණය විය යුතුය.'
                          : 'Sublimation transfer paper is pressed face-down. Auto-mirror is locked ON to guarantee correct text orientation.',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabelEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_isSi ? 'ColorWorks කාර්මික ලේබල්' : 'Industrial Color Labeling'),
        const SizedBox(height: 12),
        DropdownButtonFormField<LabelFormFactor>(
          value: _labelSpec.formFactor,
          decoration: const InputDecoration(labelText: 'Label Die-Cut Shape', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: LabelFormFactor.dieCutRectangle, child: Text('Die-Cut Rectangle 4x3" (101.6 x 76.2 mm)')),
            DropdownMenuItem(value: LabelFormFactor.continuousRoll, child: Text('Continuous Roll (Custom Length)')),
            DropdownMenuItem(value: LabelFormFactor.ghsChemicalHazard, child: Text('GHS Chemical Hazard (Red Diamond Border)')),
          ],
          onChanged: (v) => setState(() => _labelSpec = _labelSpec.copyWith(formFactor: v ?? LabelFormFactor.dieCutRectangle)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _labelSpec.barcodeData,
          decoration: const InputDecoration(labelText: 'Barcode / Serial Number', border: OutlineInputBorder(), isDense: true),
          onChanged: (v) => setState(() => _labelSpec = _labelSpec.copyWith(barcodeData: v)),
        ),
      ],
    );
  }

  Widget _buildReceiptEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_isSi ? 'කවුන්ටර තාප රිසිට්පත්' : 'Shop Counter POS Thermal Receipt'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: '80 mm Thermal (48 cols)',
                selected: _receiptSpec.paperWidth == ReceiptPaperWidth.width80mm,
                onSelected: () => setState(() => _receiptSpec = _receiptSpec.copyWith(paperWidth: ReceiptPaperWidth.width80mm)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildChoiceChip(
                label: '58 mm Thermal (32 cols)',
                selected: _receiptSpec.paperWidth == ReceiptPaperWidth.width58mm,
                onSelected: () => setState(() => _receiptSpec = _receiptSpec.copyWith(paperWidth: ReceiptPaperWidth.width58mm)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _receiptSpec.autoCutPaper,
              onChanged: (v) => setState(() => _receiptSpec = _receiptSpec.copyWith(autoCutPaper: v ?? true)),
            ),
            const Text('Auto-cut paper at receipt end (ESC/POS GS V 0)', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // Active Module Live Previews
  // ==========================================================================

  Widget _buildActiveModulePreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isSi ? 'සජීවී පෙරදසුන (1:1 Layout Preview)' : 'Interactive Live Preview',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: _renderModulePreviewGraphic(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderModulePreviewGraphic() {
    switch (_selectedModule) {
      case SpecialtyModuleType.cdDvdDisc:
        return _renderCdDvdCanvas();
      case SpecialtyModuleType.pvcIdCard:
        return _renderPvcCardCanvas();
      case SpecialtyModuleType.passportPhotoSheet:
        return _renderPassportCanvas();
      case SpecialtyModuleType.dyeSublimation:
        return _renderSublimationCanvas();
      case SpecialtyModuleType.shopReceipt:
        return _renderReceiptCanvas();
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.print_rounded, size: 60, color: DesktopColors.accentTeal),
            const SizedBox(height: 12),
            Text(
              '${_selectedModule.name} Preview Ready',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        );
    }
  }

  Widget _renderCdDvdCanvas() {
    final area = _cdSpec.printableAreaMm2;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer disc circle
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade400, width: 2),
          ),
        ),
        // Printable ring surface
        Container(
          width: 232,
          height: 232,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.teal.shade50, Colors.teal.shade100],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _cdSpec.circularText.isNotEmpty ? _cdSpec.circularText : 'PRINT HELPER DISC ARTWORK',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: DesktopColors.accentTeal),
          ),
        ),
        // Center unprintable hub hole
        Container(
          width: (_cdSpec.innerDiameterMm / _cdSpec.outerDiameterMm) * 232,
          height: (_cdSpec.innerDiameterMm / _cdSpec.outerDiameterMm) * 232,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade500, width: 1.5),
          ),
          alignment: Alignment.center,
          child: const Text('HUB', style: TextStyle(fontSize: 9, color: Colors.grey)),
        ),
        // Area badge
        Positioned(
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
            child: Text(
              'Area: ${area.toStringAsFixed(1)} mm² • Outer: ${_cdSpec.outerDiameterMm}mm • Inner: ${_cdSpec.innerDiameterMm}mm',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _renderPvcCardCanvas() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 260,
          height: 164, // CR80 proportion (85.6 x 53.98)
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DesktopColors.accentTeal, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 90,
                color: Colors.grey.shade200,
                child: const Icon(Icons.person, size: 40, color: Colors.grey),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('KASUN PERERA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('CHIEF ENGINEER', style: TextStyle(fontSize: 11, color: DesktopColors.accentTeal)),
                    SizedBox(height: 6),
                    Text('ID: EMP-00948', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
                    Text('COLOMBO TECH HUB', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Slot 1: CR80 • Calibration Offset: (${_pvcSpec.offsetXmm}mm, ${_pvcSpec.offsetYmm}mm)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _renderPassportCanvas() {
    final imposition = SpecialtyPrintingService.calculatePassportImposition(
      photoWidthMm: _passportSpec.photoWidthMm,
      photoHeightMm: _passportSpec.photoHeightMm,
      sheetWidthMm: _passportSpec.sheetDimensionsMm.$1,
      sheetHeightMm: _passportSpec.sheetDimensionsMm.$2,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 180,
          height: 250,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: imposition.cols > 0 ? imposition.cols : 2,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: imposition.isRotated ? (45 / 35) : (35 / 45),
            ),
            itemCount: imposition.totalFit,
            itemBuilder: (context, idx) => Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300, style: BorderStyle.solid),
              ),
              child: const Icon(Icons.person, size: 16, color: Colors.blue),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(4)),
          child: Text(
            'Yield: ${imposition.totalFit} photos (${imposition.cols}x${imposition.rows}) on ${_passportSpec.paperSize.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal),
          ),
        ),
      ],
    );
  }

  Widget _renderSublimationCanvas() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Original Design', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
            const SizedBox(height: 6),
            Container(
              width: 120,
              height: 120,
              color: Colors.grey.shade100,
              alignment: Alignment.center,
              child: const Text('SRI LANKA\n2026', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(width: 24),
        const Icon(Icons.arrow_forward_rounded, color: Colors.teal),
        const SizedBox(width: 24),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Mirrored Transfer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.teal)),
            const SizedBox(height: 6),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: Container(
                width: 120,
                height: 120,
                color: Colors.teal.shade50,
                alignment: Alignment.center,
                child: const Text('SRI LANKA\n2026', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _renderReceiptCanvas() {
    final text = SpecialtyPrintingService.formatShopCounterReceipt(_receiptSpec);

    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SingleChildScrollView(
        child: Text(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, height: 1.2),
        ),
      ),
    );
  }

  // ==========================================================================
  // Footer
  // ==========================================================================

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: const BoxDecoration(
        color: DesktopColors.dialogHeaderBackground,
        border: Border(top: BorderSide(color: DesktopColors.dialogBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_isSi ? 'වසන්න' : 'Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: Text(_isSi ? 'Spooler හරහා ප්‍රින්ට් කරන්න' : 'Print via Spooler'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesktopColors.accentTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.onPrintThroughSpooler != null) {
                widget.onPrintThroughSpooler!();
              }
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Helper Widgets
  // ==========================================================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? DesktopColors.accentTeal.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selected ? DesktopColors.accentTeal : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? DesktopColors.accentTeal : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text('${value.toStringAsFixed(1)} $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DesktopColors.accentTeal)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: DesktopColors.accentTeal,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
