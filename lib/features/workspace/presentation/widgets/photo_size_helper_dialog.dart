import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/widgets/desktop_widgets.dart';
import '../../domain/resolution_system_models.dart';

/// Photo Size Helper Dialog: Calculates resulting PPI across standard photo sizes,
/// highlights the largest photo-grade (300+ PPI) size, and allows custom size exploration.
class PhotoSizeHelperDialog extends StatefulWidget {
  final int pixelWidth;
  final int pixelHeight;
  final String fileName;
  final String currentPaperSize;
  final AppStrings strings;
  final ValueChanged<String> onSelectSize;

  const PhotoSizeHelperDialog({
    super.key,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.fileName,
    required this.currentPaperSize,
    required this.strings,
    required this.onSelectSize,
  });

  @override
  State<PhotoSizeHelperDialog> createState() => _PhotoSizeHelperDialogState();
}

class _PhotoSizeHelperDialogState extends State<PhotoSizeHelperDialog> {
  late List<PhotoPrintSizeSuggestion> _suggestions;
  double _customWidthCm = 15.0;
  double _customHeightCm = 10.0;
  late double _customPpi;
  late PpiQualityRating _customRating;

  @override
  void initState() {
    super.initState();
    _suggestions = EffectivePpiCalculator.suggestBestSizes(widget.pixelWidth, widget.pixelHeight);
    _recalculateCustom();
  }

  void _recalculateCustom() {
    final wInches = (_customWidthCm * 10.0) / 25.4;
    final hInches = (_customHeightCm * 10.0) / 25.4;
    final ppiW = widget.pixelWidth / (wInches > 0.01 ? wInches : 0.01);
    final ppiH = widget.pixelHeight / (hInches > 0.01 ? hInches : 0.01);
    _customPpi = ppiW < ppiH ? ppiW : ppiH;
    _customRating = PpiQualityRating.fromPpi(_customPpi);
  }

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);
    final isSi = widget.strings.isSi;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopRadius.r8)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(DesktopSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Close Button
            Row(
              children: [
                Icon(Icons.photo_size_select_actual_outlined, color: palette.accent, size: 22),
                const SizedBox(width: DesktopSpacing.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'ඡායාරූප ප්‍රමාණ සහායක (Photo Size Helper)' : 'Photo Print Size Helper',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        '${widget.fileName} (${widget.pixelWidth} × ${widget.pixelHeight} px)',
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

            // Concept Explanation Callout
            Container(
              padding: const EdgeInsets.all(DesktopSpacing.s16),
              decoration: BoxDecoration(
                color: palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(DesktopRadius.r6),
                border: Border.all(color: palette.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: palette.accent, size: 20),
                  const SizedBox(width: DesktopSpacing.s8),
                  Expanded(
                    child: Text(
                      isSi
                          ? 'PPI (Pixels Per Inch) යනු මුද්‍රිත ප්‍රමාණයේ පැහැදිලි බවයි. 300+ PPI ඉහළම තත්ත්වය වේ. විශාල කොළවල මුද්‍රණය කරන තරමට PPI අගය අඩු වේ.'
                          : 'PPI (Pixels Per Inch) determines print sharpness. 300+ PPI yields lab-quality photos. Larger print dimensions naturally reduce effective PPI.',
                      style: TextStyle(fontSize: 12, color: palette.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesktopSpacing.s16),

            // Suggestions List
            Text(
              isSi ? 'සම්මත ප්‍රමාණ සඳහා පැහැදිලි බව (Recommended Sizes):' : 'Quality Across Standard Sizes:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary),
            ),
            const SizedBox(height: DesktopSpacing.s8),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final s = _suggestions[index];
                  final isCurrent = s.sizeName.toLowerCase().contains(widget.currentPaperSize.toLowerCase());

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: s.isRecommendedForSource
                          ? palette.accent.withOpacity(0.08)
                          : (isCurrent ? palette.surfaceSecondary : palette.surfacePrimary),
                      borderRadius: BorderRadius.circular(DesktopRadius.r6),
                      border: Border.all(
                        color: s.isRecommendedForSource
                            ? palette.accent
                            : (isCurrent ? palette.borderSubtle : palette.borderLight),
                        width: s.isRecommendedForSource ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (s.isRecommendedForSource) ...[
                          Icon(Icons.star_rounded, size: 16, color: palette.accent),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    s.sizeName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: s.isRecommendedForSource ? FontWeight.w700 : FontWeight.w500,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                  if (s.isRecommendedForSource) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: palette.accent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isSi ? 'උපරිම පැහැදිලි ප්‍රමාණය' : 'Best Crisp Size',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${s.widthMm.toStringAsFixed(1)} × ${s.heightMm.toStringAsFixed(1)} mm',
                                style: TextStyle(fontSize: 11, color: palette.textSecondary),
                              ),
                            ],
                          ),
                        ),

                        // PPI Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: s.rating.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(DesktopRadius.r4),
                            border: Border.all(color: s.rating.color.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(s.rating.icon, size: 12, color: s.rating.color),
                              const SizedBox(width: 4),
                              Text(
                                '${s.expectedPpi.round()} PPI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: s.rating.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Select Size Button
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            widget.onSelectSize(s.sizeName);
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            isSi ? 'තෝරන්න' : 'Select',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: DesktopSpacing.s16),

            // Custom Size Calculator Row
            Container(
              padding: const EdgeInsets.all(DesktopSpacing.s16),
              decoration: BoxDecoration(
                color: palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(DesktopRadius.r6),
                border: Border.all(color: palette.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSi ? 'අභිරුචි ප්‍රමාණ ගණකය (Custom Dimensions):' : 'Custom Dimensions Calculator:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(isSi ? 'පළල (cm): ' : 'W (cm): ', style: const TextStyle(fontSize: 12)),
                      SizedBox(
                        width: 60,
                        height: 30,
                        child: TextFormField(
                          initialValue: _customWidthCm.toStringAsFixed(1),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 6)),
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed != null && parsed > 0) {
                              setState(() {
                                _customWidthCm = parsed;
                                _recalculateCustom();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(isSi ? 'උස (cm): ' : 'H (cm): ', style: const TextStyle(fontSize: 12)),
                      SizedBox(
                        width: 60,
                        height: 30,
                        child: TextFormField(
                          initialValue: _customHeightCm.toStringAsFixed(1),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 6)),
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed != null && parsed > 0) {
                              setState(() {
                                _customHeightCm = parsed;
                                _recalculateCustom();
                              });
                            }
                          },
                        ),
                      ),
                      const Spacer(),
                      // Realtime Custom PPI Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _customRating.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(DesktopRadius.r4),
                          border: Border.all(color: _customRating.color),
                        ),
                        child: Text(
                          '${_customPpi.round()} PPI (${isSi ? _customRating.shortLabelSi : _customRating.shortLabelEn})',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _customRating.color),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesktopSpacing.s16),

            // Done Button
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(isSi ? 'වසන්න' : 'Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
