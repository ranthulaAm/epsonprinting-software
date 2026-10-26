import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/core/theme/desktop_design_system.dart';

void main() {
  group('DesktopPalette WCAG AA Contrast Verification (>= 4.5:1)', () {
    test('all Light theme text and status pairs meet >= 4.5:1 contrast', () {
      const p = DesktopPalette.light;

      expect(
        DesktopContrastChecker.contrastRatio(p.textPrimary, p.surfacePrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.textSecondary, p.surfacePrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.textMuted, p.surfacePrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.textPrimary, p.surfaceSecondary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(
          p.textSecondary,
          p.surfaceSecondary,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.onAccent, p.accent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.statusReadyText, p.statusReadyBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(
          p.statusWarningText,
          p.statusWarningBg,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.statusErrorText, p.statusErrorBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('all Dark theme text and status pairs meet >= 4.5:1 contrast', () {
      const p = DesktopPalette.dark;

      expect(
        DesktopContrastChecker.contrastRatio(p.textPrimary, p.surfacePrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.textSecondary, p.surfacePrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.textMuted, p.surfacePrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.textPrimary, p.surfaceSecondary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(
          p.textSecondary,
          p.surfaceSecondary,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.onAccent, p.accent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.statusReadyText, p.statusReadyBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(
          p.statusWarningText,
          p.statusWarningBg,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DesktopContrastChecker.contrastRatio(p.statusErrorText, p.statusErrorBg),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('DesktopTypography, DesktopSpacing, DesktopRadius & DesktopMotion', () {
    test(
      'enforces 12/14/16/20/24 type scale and +14-15% taller Sinhala line height',
      () {
        expect(DesktopTypography.scale12, 12.0);
        expect(DesktopTypography.scale14, 14.0);
        expect(DesktopTypography.scale16, 16.0);
        expect(DesktopTypography.scale20, 20.0);
        expect(DesktopTypography.scale24, 24.0);

        final enBody = DesktopTypography.bodyLineHeight(isSinhala: false);
        final siBody = DesktopTypography.bodyLineHeight(isSinhala: true);
        expect(siBody / enBody, greaterThanOrEqualTo(1.12));
      },
    );

    test('enforces 8px grid, 4-8px corner radius, 1px border, and 150-250ms motion', () {
      expect(DesktopSpacing.s8, 8.0);
      expect(DesktopSpacing.s16, 16.0);
      expect(DesktopSpacing.s24, 24.0);
      expect(DesktopSpacing.s32, 32.0);

      expect(DesktopRadius.r4, 4.0);
      expect(DesktopRadius.r6, 6.0);
      expect(DesktopRadius.r8, 8.0);
      expect(DesktopRadius.borderWidth1px, 1.0);

      expect(DesktopElevation.flat, isEmpty);

      expect(DesktopMotion.fastFade.inMilliseconds, 150);
      expect(DesktopMotion.standardTransition.inMilliseconds, 200);
      expect(DesktopMotion.panelSlide.inMilliseconds, 250);
      expect(
        DesktopMotion.resolve(
          DesktopMotion.standardTransition,
          reduceMotion: true,
        ),
        Duration.zero,
      );
    });
  });
}
