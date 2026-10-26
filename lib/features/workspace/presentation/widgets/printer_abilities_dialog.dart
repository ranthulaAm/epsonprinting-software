import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../services/printer/capability_discovery_service.dart';

/// Modal dialog displaying comprehensive discovered capabilities of ANY printer.
class PrinterAbilitiesDialog extends StatelessWidget {
  final DiscoveredCapabilities capabilities;
  final bool isSinhala;
  final VoidCallback? onCaptureDriverPreferences;

  const PrinterAbilitiesDialog({
    super.key,
    required this.capabilities,
    this.isSinhala = false,
    this.onCaptureDriverPreferences,
  });

  static Future<void> show(
    BuildContext context, {
    required DiscoveredCapabilities capabilities,
    bool isSinhala = false,
    VoidCallback? onCaptureDriverPreferences,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PrinterAbilitiesDialog(
        capabilities: capabilities,
        isSinhala: isSinhala,
        onCaptureDriverPreferences: onCaptureDriverPreferences,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DesktopTheme.of(context).palette;

    return Dialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesktopRadius.r8),
        side: BorderSide(color: palette.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(DesktopSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(DesktopRadius.r6),
                    ),
                    child: Icon(Icons.tune_rounded, color: palette.accent, size: 20),
                  ),
                  const SizedBox(width: DesktopSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSinhala
                              ? '${capabilities.modelName} හැකියාවන්'
                              : '${capabilities.modelName} Abilities & Features',
                          style: DesktopTypography.heading18(palette, isSinhala: isSinhala),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${capabilities.familyName} • ${capabilities.verificationStatus == "verified" ? (isSinhala ? "තහවුරු කළ මාදිලිය" : "Verified hardware profile") : (isSinhala ? "ස්වයංක්‍රීයව හඳුනාගත්" : "Auto-discovered profile")}',
                          style: DesktopTypography.caption12(palette, isSinhala: isSinhala),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: DesktopSpacing.s16),
              const Divider(height: 1),

              // Capabilities Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: DesktopSpacing.s12),
                  children: [
                    // Family & Supply Technology
                    _buildSectionHeader(
                      palette,
                      isSinhala ? 'තාක්ෂණය සහ සැපයුම්' : 'Technology & Supply System',
                      Icons.settings_suggest_rounded,
                    ),
                    _buildTraitPillRow([
                      _PillData(
                        label: isSinhala
                            ? (capabilities.supplyTechnology == 'inkTank' ? 'ඉන්ක් ටෑන්ක් (EcoTank)' : 'කාට්රිජ් (Cartridge)')
                            : (capabilities.supplyTechnology == 'inkTank' ? 'Continuous Ink Tank' : 'Ink Cartridge'),
                        color: palette.accent,
                      ),
                      _PillData(
                        label: capabilities.colorLayout.toUpperCase().replaceAll('_', ' '),
                        color: palette.textSecondary,
                      ),
                      _PillData(
                        label: capabilities.hasDigitalInkPercentage
                            ? (isSinhala ? 'ඩිජිටල් තීන්ත මට්ටම (%)' : 'Digital Percentage (%)')
                            : (isSinhala ? 'දෘශ්‍ය ඇස්තමේන්තුව' : 'Visual / Estimated Levels'),
                        color: capabilities.hasDigitalInkPercentage ? Colors.teal : Colors.amber.shade700,
                      ),
                      _PillData(
                        label: capabilities.hasReplaceableMaintenanceBoxWithChip
                            ? (isSinhala ? 'චිප් සහිත නඩත්තු පෙට්ටිය' : 'Chip Maintenance Box')
                            : (isSinhala ? 'අපද්‍රව්‍ය තීන්ත පෑඩය' : 'Waste Ink Pad Counter'),
                        color: palette.textSecondary,
                      ),
                    ]),

                    const SizedBox(height: DesktopSpacing.s16),

                    // Paper & Trays
                    _buildSectionHeader(
                      palette,
                      isSinhala ? 'කඩදාසි සහ තැටි' : 'Supported Paper & Trays',
                      Icons.layers_rounded,
                    ),
                    Text(
                      isSinhala
                        ? 'සහාය දක්වන ප්‍රමාණ: ${capabilities.supportedPaperSizes.join(", ")}'
                        : 'Sizes: ${capabilities.supportedPaperSizes.join(", ")}',
                      style: DesktopTypography.body14(palette, isSinhala: isSinhala),
                    ),
                    const SizedBox(height: DesktopSpacing.s6),
                    Text(
                      isSinhala
                        ? 'මාධ්‍ය වර්ග: ${capabilities.supportedMediaTypes.join(", ")}'
                        : 'Media: ${capabilities.supportedMediaTypes.join(", ")}',
                      style: DesktopTypography.body14(palette, isSinhala: isSinhala),
                    ),
                    const SizedBox(height: DesktopSpacing.s6),
                    Text(
                      isSinhala
                        ? 'ඇතුළත් කිරීමේ තැටි: ${capabilities.inputBins.join(", ")}'
                        : 'Input Trays: ${capabilities.inputBins.join(", ")}',
                      style: DesktopTypography.caption12(palette, isSinhala: isSinhala),
                    ),

                    const SizedBox(height: DesktopSpacing.s16),

                    // Duplex, Borderless & Media Features
                    _buildSectionHeader(
                      palette,
                      isSinhala ? 'මුද්‍රණ පහසුකම්' : 'Print Features & Capabilities',
                      Icons.featured_play_list_rounded,
                    ),
                    _buildTraitPillRow([
                      _PillData(
                        label: capabilities.supportedDuplexModes.contains(DuplexMode.longEdge)
                            ? (isSinhala ? 'ස්වයංක්‍රීය දෙපැත්ත (Auto-duplex)' : 'Automatic 2-Sided')
                            : (isSinhala ? 'අත්පොත දෙපැත්ත සහායකය' : 'Manual Duplex Assistant Only'),
                        color: capabilities.supportedDuplexModes.contains(DuplexMode.longEdge)
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                      _PillData(
                        label: capabilities.supportsBorderless
                            ? (isSinhala ? 'දාර රහිත (${capabilities.borderlessMaxSize} දක්වා)' : 'Borderless (up to ${capabilities.borderlessMaxSize})')
                            : (isSinhala ? 'දාර රහිත නැත' : 'No Borderless'),
                        color: capabilities.supportsBorderless ? Colors.teal : palette.textSecondary,
                      ),
                      if (capabilities.supportsCdDvd)
                        _PillData(
                          label: isSinhala ? 'CD/DVD තැටි මුද්‍රණය' : 'Direct CD/DVD Print',
                          color: Colors.indigo,
                        ),
                      if (capabilities.supportsRollPaper)
                        _PillData(
                          label: isSinhala ? 'රෝල් කඩදාසි සහ ස්වයංක්‍රීය කැපීම' : 'Roll Paper & Auto-cut',
                          color: Colors.purple,
                        ),
                      _PillData(
                        label: 'Max Optical: ${capabilities.supportedResolutionsDpi.last} DPI',
                        color: palette.textSecondary,
                      ),
                    ]),

                    const SizedBox(height: DesktopSpacing.s16),

                    // Professional & Color Capabilities
                    _buildSectionHeader(
                      palette,
                      isSinhala ? 'වෘත්තීය සහ වර්ණ පාලනය' : 'Professional & Color Capabilities',
                      Icons.palette_rounded,
                    ),
                    _buildTraitPillRow([
                      _PillData(
                        label: isSinhala ? 'ICC වර්ණ පැතිකඩ' : 'ICC Color Management',
                        color: palette.accent,
                      ),
                      if (capabilities.supportsAdvancedBwToning)
                        _PillData(
                          label: isSinhala ? 'උසස් කළු-සුදු ටෝනින්' : 'Advanced B&W Toning',
                          color: Colors.blueGrey,
                        ),
                      if (capabilities.supportsHalftoneScreening)
                        _PillData(
                          label: isSinhala ? 'Halftone ස්ක්‍රීනින්' : 'Halftone Screening',
                          color: Colors.deepPurple,
                        ),
                      if (capabilities.supportsGlossOptimizer)
                        _PillData(
                          label: isSinhala ? 'ග්ලොස් ඔප්ටිමයිසර්' : 'Gloss Optimizer',
                          color: Colors.amber.shade800,
                        ),
                      _PillData(
                        label: isSinhala ? 'N-Up / පත්‍ර පිරිසැලසුම්' : 'N-Up Imposition',
                        color: palette.textSecondary,
                      ),
                      _PillData(
                        label: isSinhala ? 'හැඳුනුම්පත් / පාස්පෝට් ෆොටෝ' : 'Passport / ID Photos',
                        color: palette.textSecondary,
                      ),
                    ]),

                    const SizedBox(height: DesktopSpacing.s16),

                    // Telemetry Sources Breakdown
                    _buildSectionHeader(
                      palette,
                      isSinhala ? 'දත්ත මූලාශ්‍ර' : 'Capability Provenance & Data Sources',
                      Icons.source_rounded,
                    ),
                    ...capabilities.abilitySources.entries.map((entry) {
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ${item.featureKey}: ',
                              style: DesktopTypography.caption12(palette, weight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                '${isSinhala ? item.source.labelSi : item.source.labelEn} (${item.details.isNotEmpty ? item.details : item.confidence.name})',
                                style: DesktopTypography.caption12(palette),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const Divider(height: 1),
              const SizedBox(height: DesktopSpacing.s12),

              // Bottom Actions
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings_applications_rounded, size: 16),
                    label: Text(isSinhala ? 'ධාවක සැකසුම් (Driver Preferences)' : 'Capture Driver Preferences'),
                    onPressed: onCaptureDriverPreferences ?? () {
                      WindowsPrintSchemaBridge.captureDriverPreferences(capabilities.printerName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isSinhala
                                ? 'මුද්‍රණ ධාවකයේ නිල සැකසුම් කවුළුව විවෘත වේ...'
                                : 'Opening official driver preferences window...',
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(isSinhala ? 'විස්තර පිටපත් කරන්න' : 'Copy Diagnostics'),
                    onPressed: () {
                      final diag = StringBuffer();
                      diag.writeln('Printer: ${capabilities.printerName}');
                      diag.writeln('Model: ${capabilities.modelName}');
                      diag.writeln('Family: ${capabilities.familyName}');
                      diag.writeln('Duplex: ${capabilities.supportedDuplexModes.map((d) => d.name).join(", ")}');
                      diag.writeln('Borderless: ${capabilities.supportsBorderless} (${capabilities.borderlessMaxSize})');
                      diag.writeln('Paper Sizes: ${capabilities.supportedPaperSizes.join(", ")}');
                      diag.writeln('Media Types: ${capabilities.supportedMediaTypes.join(", ")}');
                      diag.writeln('Verification: ${capabilities.verificationStatus} - ${capabilities.verificationNote}');
                      Clipboard.setData(ClipboardData(text: diag.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isSinhala ? 'විස්තර ක්ලිප්බෝඩ් එකට පිටපත් විය' : 'Diagnostics copied to clipboard',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: DesktopSpacing.s8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(isSinhala ? 'හරි' : 'Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(DesktopPalette palette, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesktopSpacing.s8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: palette.accent),
          const SizedBox(width: DesktopSpacing.s6),
          Text(
            title,
            style: DesktopTypography.caption12(palette, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitPillRow(List<_PillData> pills) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: pills.map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: p.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(DesktopRadius.r4),
            border: Border.all(color: p.color.withOpacity(0.24)),
          ),
          child: Text(
            p.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: p.color,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PillData {
  final String label;
  final Color color;
  const _PillData({required this.label, required this.color});
}
