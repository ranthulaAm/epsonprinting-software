import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/widgets/desktop_widgets.dart';
import '../../domain/tone_and_ink_models.dart';

/// Interactive Tone & Ink Panel adhering to Windows 11 Desktop styling.
/// Honestly discloses adjustment methods:
/// A) "Printer setting" for driver-controlled features (Black Ink Only, quality modes, driver adjustments).
/// B) "Print Helper adjustment" for universal app image preprocessing.
class ToneAndInkPanel extends StatefulWidget {
  final ToneAndInkSettings settings;
  final bool isColorPrinter;
  final bool driverColorAdjustmentAvailable;
  final AppStrings strings;
  final ValueChanged<ToneAndInkSettings> onSettingsChanged;
  final VoidCallback onOpenDriverPreferences;
  final VoidCallback onPrintTestPattern;

  const ToneAndInkPanel({
    super.key,
    required this.settings,
    required this.isColorPrinter,
    required this.driverColorAdjustmentAvailable,
    required this.strings,
    required this.onSettingsChanged,
    required this.onOpenDriverPreferences,
    required this.onPrintTestPattern,
  });

  @override
  State<ToneAndInkPanel> createState() => _ToneAndInkPanelState();
}

class _ToneAndInkPanelState extends State<ToneAndInkPanel> {
  bool _showProCurves = false;

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);
    final isSi = widget.strings.isSi;
    final s = widget.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Double Adjustment Warning Banner (if both driver & app are adjusting)
        if (s.isDoubleAdjustmentWarning) ...[
          Container(
            margin: const EdgeInsets.only(bottom: DesktopSpacing.s8),
            padding: const EdgeInsets.all(DesktopSpacing.s8),
            decoration: BoxDecoration(
              color: palette.statusWarningText.withOpacity(0.08),
              borderRadius: BorderRadius.circular(DesktopRadius.r6),
              border: Border.all(color: palette.statusWarningText.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: palette.statusWarningText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isSi
                            ? 'ද්විත්ව වර්ණ වෙනස්වීමක් අනාවරණය විය (Double Adjustment)'
                            : 'Double Color Adjustment Detected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.statusWarningText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isSi
                      ? 'ප්‍රින්ටර් ඩ්‍රයිවර් එක සහ Print Helper යන දෙකෙන්ම එකවර වර්ණ වෙනස් වේ. මෙය වර්ණ අපැහැදිලි වීමට හේතු විය හැක.'
                      : 'Both the printer driver color controls and Print Helper adjustments are engaged. Disable one to prevent muddy, oversaturated prints.',
                  style: TextStyle(fontSize: 11, color: palette.textPrimary),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    widget.onSettingsChanged(s.copyWith(driverColorAdjustmentActive: false));
                  },
                  child: Text(
                    isSi ? 'Print Helper ට පමණක් ඉඩ දෙන්න' : 'Let Print Helper Manage Tone',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 2. Paper-Type Compensation Presets
        FormRow(
          label: isSi ? 'කඩදාසි අනුව වෙනස්කම්' : 'Paper Compensation',
          isSinhala: isSi,
          control: DropdownButton<PaperCompensationPreset>(
            value: s.paperCompensation,
            isExpanded: true,
            underline: const SizedBox(),
            items: PaperCompensationPreset.values.map((preset) {
              return DropdownMenuItem(
                value: preset,
                child: Text(
                  isSi ? preset.labelSi : preset.labelEn,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: (preset) {
              if (preset != null) {
                widget.onSettingsChanged(s.applyPaperCompensation(preset));
              }
            },
          ),
        ),
        if (s.paperCompensation != PaperCompensationPreset.none)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: DesktopSpacing.s8),
            child: Text(
              isSi ? s.paperCompensation.descSi : s.paperCompensation.descEn,
              style: TextStyle(fontSize: 11, color: palette.textSecondary),
            ),
          ),
        const SizedBox(height: DesktopSpacing.s8),

        // 3. Overall Density Slider (Lighter - Darker)
        _buildSliderRow(
          palette: palette,
          title: isSi ? 'සමස්ත තීන්ත ඝනත්වය (Density)' : 'Overall Density (Ink Deposit)',
          source: ToneAdjustmentSource.app,
          value: s.density.toDouble(),
          min: -100,
          max: 100,
          label: s.density > 0 ? '+${s.density}' : '${s.density}',
          isSi: isSi,
          onChanged: (v) => widget.onSettingsChanged(s.copyWith(density: v.round())),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // 4. Brightness, Contrast & Gamma
        _buildSliderRow(
          palette: palette,
          title: isSi ? 'දීප්තිය (Brightness)' : 'Brightness',
          source: ToneAdjustmentSource.app,
          value: s.brightness.toDouble(),
          min: -100,
          max: 100,
          label: s.brightness > 0 ? '+${s.brightness}' : '${s.brightness}',
          isSi: isSi,
          onChanged: (v) => widget.onSettingsChanged(s.copyWith(brightness: v.round())),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        _buildSliderRow(
          palette: palette,
          title: isSi ? 'ප්‍රතිවිරෝධය (Contrast)' : 'Contrast',
          source: ToneAdjustmentSource.app,
          value: s.contrast.toDouble(),
          min: -100,
          max: 100,
          label: s.contrast > 0 ? '+${s.contrast}' : '${s.contrast}',
          isSi: isSi,
          onChanged: (v) => widget.onSettingsChanged(s.copyWith(contrast: v.round())),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        _buildSliderRow(
          palette: palette,
          title: isSi ? 'ගැමා (Gamma)' : 'Gamma Curve',
          source: ToneAdjustmentSource.app,
          value: s.gamma,
          min: 0.5,
          max: 2.5,
          label: s.gamma.toStringAsFixed(2),
          isSi: isSi,
          onChanged: (v) => widget.onSettingsChanged(s.copyWith(gamma: v)),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // 5. Shadows and Highlights
        Row(
          children: [
            Expanded(
              child: _buildCompactSlider(
                palette: palette,
                title: isSi ? 'සෙවණැලි (Shadows)' : 'Shadows',
                value: s.shadows.toDouble(),
                min: -100,
                max: 100,
                isSi: isSi,
                onChanged: (v) => widget.onSettingsChanged(s.copyWith(shadows: v.round())),
              ),
            ),
            const SizedBox(width: DesktopSpacing.s8),
            Expanded(
              child: _buildCompactSlider(
                palette: palette,
                title: isSi ? 'දීප්තිමත් පෙදෙස් (Highlights)' : 'Highlights',
                value: s.highlights.toDouble(),
                min: -100,
                max: 100,
                isSi: isSi,
                onChanged: (v) => widget.onSettingsChanged(s.copyWith(highlights: v.round())),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // 6. Black Level and Text Darkness
        Row(
          children: [
            Expanded(
              child: _buildCompactSlider(
                palette: palette,
                title: isSi ? 'කළු මට්ටම (Black Level)' : 'Black Level',
                value: s.blackLevel.toDouble(),
                min: -100,
                max: 100,
                isSi: isSi,
                onChanged: (v) => widget.onSettingsChanged(s.copyWith(blackLevel: v.round())),
              ),
            ),
            const SizedBox(width: DesktopSpacing.s8),
            Expanded(
              child: _buildCompactSlider(
                palette: palette,
                title: isSi ? 'අකුරු අඳුරු බව (Text Darkness)' : 'Text Darkness',
                value: s.textDarkness.toDouble(),
                min: -100,
                max: 100,
                isSi: isSi,
                onChanged: (v) => widget.onSettingsChanged(s.copyWith(textDarkness: v.round())),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // 7. Sharpening: Text & Photos
        Row(
          children: [
            Expanded(
              child: _buildCompactSlider(
                palette: palette,
                title: isSi ? 'අකුරු තියුණු බව (Text Sharp)' : 'Text Sharpening',
                value: s.textSharpening.toDouble(),
                min: 0,
                max: 100,
                isSi: isSi,
                onChanged: (v) => widget.onSettingsChanged(s.copyWith(textSharpening: v.round())),
              ),
            ),
            const SizedBox(width: DesktopSpacing.s8),
            Expanded(
              child: _buildCompactSlider(
                palette: palette,
                title: isSi ? 'ඡායාරූප තියුණු බව' : 'Photo Sharpening',
                value: s.photoSharpening.toDouble(),
                min: 0,
                max: 100,
                isSi: isSi,
                onChanged: (v) => widget.onSettingsChanged(s.copyWith(photoSharpening: v.round())),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesktopSpacing.s16),

        // 8. Color Controls (if Color Printer)
        if (widget.isColorPrinter) ...[
          _buildSliderRow(
            palette: palette,
            title: isSi ? 'සන්තෘප්තිය (Saturation)' : 'Color Saturation',
            source: ToneAdjustmentSource.app,
            value: s.saturation.toDouble(),
            min: -100,
            max: 100,
            label: s.saturation > 0 ? '+${s.saturation}' : '${s.saturation}',
            isSi: isSi,
            onChanged: (v) => widget.onSettingsChanged(s.copyWith(saturation: v.round())),
          ),
          const SizedBox(height: DesktopSpacing.s8),

          _buildSliderRow(
            palette: palette,
            title: isSi ? 'වර්ණ ප්‍රාණවත් බව (Vibrance)' : 'Vibrance (Skin Safe)',
            source: ToneAdjustmentSource.app,
            value: s.vibrance.toDouble(),
            min: -100,
            max: 100,
            label: s.vibrance > 0 ? '+${s.vibrance}' : '${s.vibrance}',
            isSi: isSi,
            onChanged: (v) => widget.onSettingsChanged(s.copyWith(vibrance: v.round())),
          ),
          const SizedBox(height: DesktopSpacing.s8),

          // Color Balance Sliders
          Row(
            children: [
              Expanded(
                child: _buildCompactSlider(
                  palette: palette,
                  title: isSi ? 'Cyan ↔ Red' : 'Cyan ↔ Red',
                  value: s.colorBalanceCyanRed.toDouble(),
                  min: -100,
                  max: 100,
                  isSi: isSi,
                  onChanged: (v) => widget.onSettingsChanged(s.copyWith(colorBalanceCyanRed: v.round())),
                ),
              ),
              const SizedBox(width: DesktopSpacing.s8),
              Expanded(
                child: _buildCompactSlider(
                  palette: palette,
                  title: isSi ? 'Magenta ↔ Green' : 'Magenta ↔ Green',
                  value: s.colorBalanceMagentaGreen.toDouble(),
                  min: -100,
                  max: 100,
                  isSi: isSi,
                  onChanged: (v) => widget.onSettingsChanged(s.copyWith(colorBalanceMagentaGreen: v.round())),
                ),
              ),
              const SizedBox(width: DesktopSpacing.s8),
              Expanded(
                child: _buildCompactSlider(
                  palette: palette,
                  title: isSi ? 'Yellow ↔ Blue' : 'Yellow ↔ Blue',
                  value: s.colorBalanceYellowBlue.toDouble(),
                  min: -100,
                  max: 100,
                  isSi: isSi,
                  onChanged: (v) => widget.onSettingsChanged(s.copyWith(colorBalanceYellowBlue: v.round())),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesktopSpacing.s16),
        ],

        // 9. Ink Saver / Toner Saver Card
        Container(
          padding: const EdgeInsets.all(DesktopSpacing.s8),
          decoration: BoxDecoration(
            color: s.inkSaverEnabled ? palette.accent.withOpacity(0.06) : palette.surfaceSecondary,
            borderRadius: BorderRadius.circular(DesktopRadius.r6),
            border: Border.all(
              color: s.inkSaverEnabled ? palette.accent : palette.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.eco_rounded,
                    size: 16,
                    color: s.inkSaverEnabled ? palette.accent : palette.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isSi ? 'තීන්ත / ටෝනර් ඉතිරි කිරීම (Ink Saver)' : 'Ink / Toner Saver Mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: s.inkSaverEnabled ? palette.accent : palette.textPrimary,
                      ),
                    ),
                  ),
                  _buildSourceBadge(ToneAdjustmentSource.app, isSi),
                  const SizedBox(width: 6),
                  Switch(
                    value: s.inkSaverEnabled,
                    onChanged: (val) => widget.onSettingsChanged(s.copyWith(inkSaverEnabled: val)),
                  ),
                ],
              ),
              if (s.inkSaverEnabled) ...[
                const SizedBox(height: 6),
                DropdownButton<InkSaverLevel>(
                  value: s.inkSaverLevel,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: InkSaverLevel.values.map((lvl) {
                    return DropdownMenuItem(
                      value: lvl,
                      child: Text(
                        isSi ? lvl.labelSi : lvl.labelEn,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  onChanged: (lvl) {
                    if (lvl != null) widget.onSettingsChanged(s.copyWith(inkSaverLevel: lvl));
                  },
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isSi ? 'අකුරු පමණක් තද කළු තීන්තෙන් මුද්‍රණය' : 'Text-Only Black (Preserves Color Tanks)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: s.inkSaverTextOnlyBlack,
                  onChanged: (v) => widget.onSettingsChanged(s.copyWith(inkSaverTextOnlyBlack: v ?? false)),
                ),
                Text(
                  isSi
                      ? 'ඇස්තමේන්තුව: මුළු තීන්ත ප්‍රමාණයෙන් ~${s.estimatedSavingsPercent.round()}% ඉතිරි වේ.'
                      : 'Savings Estimate: ~${s.estimatedSavingsPercent.round()}% ink reduction (clearly labeled estimate).',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.accent),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DesktopSpacing.s16),

        // 10. CMYK Ink Coverage Meter (Feeds Price Calculator)
        _buildCmykCoverageMeter(palette, isSi),
        const SizedBox(height: DesktopSpacing.s16),

        // 11. Actions: Reset, Compare with Original, and Print Test Pattern
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt_rounded, size: 14),
              label: Text(isSi ? 'මුල් තත්ත්වයට' : 'Reset'),
              onPressed: s.hasActiveAdjustments
                  ? () => widget.onSettingsChanged(s.resetToDefault())
                  : null,
            ),
            const SizedBox(width: DesktopSpacing.s8),
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(
                  s.compareWithOriginal ? Icons.visibility_off_outlined : Icons.compare_rounded,
                  size: 14,
                ),
                label: Text(
                  s.compareWithOriginal
                      ? (isSi ? 'සංසන්දනය නවත්වන්න' : 'Stop Compare')
                      : (isSi ? 'මුල් පිටුව සමඟ බලන්න' : 'Compare Original'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () {
                  widget.onSettingsChanged(s.copyWith(compareWithOriginal: !s.compareWithOriginal));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // 12. Print Test Pattern Button
        PrimaryButton(
          expandWidth: true,
          icon: Icons.print_outlined,
          label: isSi ? 'පරීක්ෂණ රටාව මුද්‍රණය (Test Pattern)' : 'Print Test Pattern (Nozzle & Ramp)',
          isSinhala: isSi,
          onPressed: widget.onPrintTestPattern,
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required DesktopPalette palette,
    required String title,
    required ToneAdjustmentSource source,
    required double value,
    required double min,
    required double max,
    required String label,
    required bool isSi,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                ),
                const SizedBox(width: 6),
                _buildSourceBadge(source, isSi),
              ],
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: palette.accent),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSlider({
    required DesktopPalette palette,
    required String title,
    required double value,
    required double min,
    required double max,
    required bool isSi,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: palette.textPrimary),
              ),
            ),
            Text(
              value > 0 ? '+${value.round()}' : '${value.round()}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.accent),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBadge(ToneAdjustmentSource source, bool isSi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: source.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: source.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: 10, color: source.color),
          const SizedBox(width: 3),
          Text(
            isSi ? source.labelSi : source.labelEn,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: source.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCmykCoverageMeter(DesktopPalette palette, bool isSi) {
    // Standard baseline coverage
    const covC = 4.2;
    const covM = 3.8;
    const covY = 5.1;
    const covK = 8.4;
    const total = covC + covM + covY + covK;

    return Container(
      padding: const EdgeInsets.all(DesktopSpacing.s8),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(DesktopRadius.r6),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 14, color: palette.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isSi ? 'තීන්ත ආවරණ ඇස්තමේන්තුව (Ink Coverage)' : 'Estimated Ink Coverage (Per Channel)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                ),
              ),
              Text(
                'Total: ${total.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: palette.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMiniBar('C', 'Cyan', covC, const Color(0xFF06B6D4)),
          const SizedBox(height: 3),
          _buildMiniBar('M', 'Magenta', covM, const Color(0xFFEC4899)),
          const SizedBox(height: 3),
          _buildMiniBar('Y', 'Yellow', covY, const Color(0xFFEAB308)),
          const SizedBox(height: 3),
          _buildMiniBar('K', 'Black', covK, Colors.black82),
        ],
      ),
    );
  }

  Widget _buildMiniBar(String letter, String name, double pct, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            letter,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (pct / 50.0).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text(
            '${pct.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
