import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/widgets/desktop_widgets.dart';
import '../../domain/resolution_system_models.dart';

/// Dialog showing an interactive before-and-after comparison of image resampling,
/// with algorithm choices (None, Bicubic, Lanczos-3), magnification preview,
/// and clear transformation logging (Never silently resample!).
class ResamplePreviewDialog extends StatefulWidget {
  final String fileName;
  final int originalWidth;
  final int originalHeight;
  final double currentEffectivePpi;
  final AppStrings strings;
  final void Function(ResamplingAlgorithm algorithm, double multiplier) onApplyUpscale;

  const ResamplePreviewDialog({
    super.key,
    required this.fileName,
    required this.originalWidth,
    required this.originalHeight,
    required this.currentEffectivePpi,
    required this.strings,
    required this.onApplyUpscale,
  });

  @override
  State<ResamplePreviewDialog> createState() => _ResamplePreviewDialogState();
}

class _ResamplePreviewDialogState extends State<ResamplePreviewDialog> {
  ResamplingAlgorithm _selectedAlgorithm = ResamplingAlgorithm.lanczos;
  double _multiplier = 2.0;

  @override
  Widget build(BuildContext context) {
    final palette = DesktopTheme.of(context).palette;
    final isSi = widget.strings.isSi;

    final targetW = (widget.originalWidth * _multiplier).round();
    final targetH = (widget.originalHeight * _multiplier).round();
    final newPpi = widget.currentEffectivePpi * _multiplier;
    final oldRating = PpiQualityRating.fromPpi(widget.currentEffectivePpi);
    final newRating = PpiQualityRating.fromPpi(newPpi);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopRadius.r8)),
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(DesktopSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, color: palette.accent, size: 22),
                const SizedBox(width: DesktopSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'මුද්‍රණය සඳහා ප්‍රතිනියැදීම (Resample & Upscale for Print)' : 'Image Resample & Print Upscale',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        '${widget.fileName} — ${widget.originalWidth}×${widget.originalHeight} px → ${targetW}×${targetH} px',
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

            // Controls Row: Algorithm & Multiplier
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'ප්‍රතිනියැදි ක්‍රමය (Algorithm):' : 'Resampling Filter:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<ResamplingAlgorithm>(
                        value: _selectedAlgorithm,
                        isExpanded: true,
                        items: ResamplingAlgorithm.values.map((algo) {
                          return DropdownMenuItem(
                            value: algo,
                            child: Text(
                              isSi ? algo.nameSi : algo.nameEn,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAlgorithm = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DesktopSpacing.s16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'විශාල කිරීමේ සාධකය:' : 'Upscale Multiplier:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<double>(
                        value: _multiplier,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 1.5, child: Text('1.5× (+50% Pixels)')),
                          DropdownMenuItem(value: 2.0, child: Text('2.0× Standard Upscale (4× Pixels)')),
                          DropdownMenuItem(value: 3.0, child: Text('3.0× High Magnification')),
                          DropdownMenuItem(value: 4.0, child: Text('4.0× Ultra Scale')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _multiplier = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesktopSpacing.s12),

            // Algorithm Description Box
            Container(
              padding: const EdgeInsets.all(DesktopSpacing.s10),
              decoration: BoxDecoration(
                color: palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(DesktopRadius.r6),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                isSi ? _selectedAlgorithm.descSi : _selectedAlgorithm.descEn,
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
            ),
            const SizedBox(height: DesktopSpacing.s16),

            // Visual Before vs After Comparison Card
            Row(
              children: [
                // BEFORE
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(DesktopSpacing.s12),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(DesktopRadius.r6),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isSi ? 'මුල් තත්ත්වය (Before)' : 'Original (Before)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(DesktopRadius.r4),
                            border: Border.all(color: palette.borderLight),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.grid_4x4_rounded, size: 36, color: palette.textTertiary),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.originalWidth} × ${widget.originalHeight} px',
                                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: oldRating.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: oldRating.color),
                          ),
                          child: Text(
                            '${widget.currentEffectivePpi.round()} PPI (${isSi ? oldRating.shortLabelSi : oldRating.shortLabelEn})',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: oldRating.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DesktopSpacing.s12),

                // Arrow
                Icon(Icons.arrow_forward_rounded, color: palette.accent, size: 24),
                const SizedBox(width: DesktopSpacing.s12),

                // AFTER
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(DesktopSpacing.s12),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(DesktopRadius.r6),
                      border: Border.all(color: palette.accent),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isSi ? 'ප්‍රතිනියැදීමෙන් පසු (After)' : 'Resampled (After)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.accent),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: palette.accent.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(DesktopRadius.r4),
                            border: Border.all(color: palette.accent.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.high_quality_rounded, size: 36, color: palette.accent),
                                const SizedBox(height: 4),
                                Text(
                                  '$targetW × $targetH px',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: newRating.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: newRating.color),
                          ),
                          child: Text(
                            '${newPpi.round()} PPI (${isSi ? newRating.shortLabelSi : newRating.shortLabelEn})',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: newRating.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesktopSpacing.s16),

            // Vector Preservation & Audit Guarantee
            Container(
              padding: const EdgeInsets.all(DesktopSpacing.s8),
              decoration: BoxDecoration(
                color: palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(DesktopRadius.r4),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: palette.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSi
                          ? 'සටහන: PDF අකුරු (vector fonts) සහ රේඛා වෙනස් නොවේ. රූප පමණක් පැහැදිලි කෙරේ. ප්‍රතිනියැදි විස්තර සටහන් වේ.'
                          : 'Guarantee: Vector text, fonts, and PDF lines are never rasterized. Only bitmap photos are enhanced. Transformation is logged in print records.',
                      style: TextStyle(fontSize: 11, color: palette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesktopSpacing.s16),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isSi ? 'අවලංගු කරන්න' : 'Cancel'),
                ),
                const SizedBox(width: DesktopSpacing.s10),
                PrimaryButton(
                  icon: Icons.check_circle_outline,
                  label: isSi ? 'ප්‍රතිනියැදීම යොදන්න' : 'Apply Upscale to Job',
                  isSinhala: isSi,
                  onPressed: () {
                    widget.onApplyUpscale(_selectedAlgorithm, _multiplier);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
