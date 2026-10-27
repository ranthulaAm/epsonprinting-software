import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/widgets/desktop_widgets.dart';
import '../../domain/tone_and_ink_models.dart';

/// Dialog for printing test pattern pages (Gray ramp, color patches, nozzle check)
/// via NORMAL document printing without sending raw control or cleaning commands.
class TestPatternDialog extends StatelessWidget {
  final String printerName;
  final AppStrings strings;
  final VoidCallback onPrintDocument;
  final VoidCallback onOpenDriverPreferences;

  const TestPatternDialog({
    super.key,
    required this.printerName,
    required this.strings,
    required this.onPrintDocument,
    required this.onOpenDriverPreferences,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);
    final isSi = strings.isSi;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopRadius.r8)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(DesktopSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.gradient_rounded, color: palette.accent, size: 22),
                const SizedBox(width: DesktopSpacing.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'පරීක්ෂණ රටාව මුද්‍රණය (Test Pattern)' : 'Print Tone & Quality Test Pattern',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        '$printerName — Gray Ramp, Color Patches & Nozzle Chart',
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
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

            // Honest Advisory Callout
            Container(
              padding: const EdgeInsets.all(DesktopSpacing.s16),
              decoration: BoxDecoration(
                color: palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(DesktopRadius.r6),
                border: Border.all(color: palette.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: palette.accent, size: 20),
                  const SizedBox(width: DesktopSpacing.s8),
                  Expanded(
                    child: Text(
                      isSi ? TestPatternGenerator.advisoryNoticeSi : TestPatternGenerator.advisoryNoticeEn,
                      style: TextStyle(fontSize: 12, color: palette.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesktopSpacing.s16),

            // Visual Test Sheet Mockup
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(DesktopRadius.r6),
                border: Border.all(color: palette.borderSubtle),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'PRINT HELPER DIAGNOSTIC TEST SHEET — $printerName',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),

                  // 11-step Gray ramp mockup
                  Row(
                    children: List.generate(11, (idx) {
                      final shade = (idx * 25.5).round();
                      return Expanded(
                        child: Container(
                          height: 20,
                          color: Color.fromARGB(255, shade, shade, shade),
                          child: Center(
                            child: Text(
                              '${idx * 10}%',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: idx < 6 ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),

                  // Color step patches
                  Row(
                    children: [
                      _buildPatchRow(const Color(0xFF06B6D4), 'Cyan'),
                      const SizedBox(width: 4),
                      _buildPatchRow(const Color(0xFFEC4899), 'Magenta'),
                      const SizedBox(width: 4),
                      _buildPatchRow(const Color(0xFFEAB308), 'Yellow'),
                      const SizedBox(width: 4),
                      _buildPatchRow(Colors.black87, 'Black'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Simulated Nozzle & Text sharpness lines
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isSi
                              ? '4pt තියුණු බව | 6pt කියවීම | 8pt සාමාන්‍ය | 10pt ලේඛන'
                              : '4pt Micro Text | 6pt Fine Line | 8pt Normal | 10pt Body Text',
                          style: const TextStyle(fontSize: 9, color: Colors.black54),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Stepped nozzle check pattern
                      Row(
                        children: List.generate(8, (i) => Container(
                          width: 8,
                          height: 14,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          color: Colors.black45,
                        )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesktopSpacing.s16),

            // Action Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_applications_outlined, size: 16),
                  label: Text(isSi ? 'Epson ඩ්‍රයිවර් මෙනුව (Maintenance)' : 'Open Driver Maintenance'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenDriverPreferences();
                  },
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isSi ? 'වසන්න' : 'Close'),
                ),
                const SizedBox(width: DesktopSpacing.s8),
                PrimaryButton(
                  icon: Icons.print_rounded,
                  label: isSi ? 'පරීක්ෂණ පිටුව මුද්‍රණය කරන්න' : 'Print Test Page Now',
                  isSinhala: isSi,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onPrintDocument();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatchRow(Color color, String name) {
    return Expanded(
      child: Container(
        height: 18,
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Center(
          child: Text(
            name,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
