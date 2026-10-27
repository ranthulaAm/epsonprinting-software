import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================================
// PRINT HELPER — CENTRAL DESKTOP DESIGN SYSTEM
// ============================================================================
// Design Principles:
// 1. Professional desktop utility aesthetic (Windows 11 / Microsoft Office /
//    accounting software).
// 2. Neutral light/dark palette + ONE calm muted blue-slate accent.
// 3. Semantic status colors strictly for meaning: Green = Ready, Amber = Warning,
//    Red = Error. All text pairs meet WCAG AA >= 4.5:1 contrast.
// 4. Flat surfaces, thin 1px borders, small corner radius (4–8 px). Shadows
//    ONLY on floating popups and menus.
// 5. Single outlined icon set (Material Outlined, uniform 16/18/20 px sizing).
// 6. Fixed type scale (12 / 14 / 16 / 20 / 24) with Segoe UI for English and
//    NotoSansSinhala for Sinhala (+15% line-height so Sinhala diacritics never clip).
// 7. Strict 8 px spacing grid.
// 8. Calm 150–250 ms fades/slides; respects "Reduce motion".
// ============================================================================

/// 1. Color Tokens (Light & Dark Themes, Verified >= 4.5:1 Contrast)
@immutable
class DesktopPalette extends ThemeExtension<DesktopPalette> {
  final Brightness brightness;

  // Neutral Surfaces
  final Color backgroundCanvas;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceHover;

  // 1px Borders
  final Color borderSubtle;
  final Color borderStrong;

  // Neutral Typography (all >= 4.5:1 against surfacePrimary & surfaceSecondary)
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Single Calm Accent (Muted Industrial Slate-Blue)
  final Color accent;
  final Color accentHover;
  final Color accentSubtleBg;
  final Color accentSubtleBorder;
  final Color onAccent;

  // Semantic Status Colors (Strictly for meaning: Ready / Warning / Error)
  final Color statusReadyText;
  final Color statusReadyBg;
  final Color statusReadyBorder;

  final Color statusWarningText;
  final Color statusWarningBg;
  final Color statusWarningBorder;

  final Color statusErrorText;
  final Color statusErrorBg;
  final Color statusErrorBorder;

  // Neutral Ink/Toner Supply Bar Colors (Subdued, non-neon hardware pigments)
  final Color supplyBlack;
  final Color supplyCyan;
  final Color supplyMagenta;
  final Color supplyYellow;
  final Color supplyMaintenance;

  const DesktopPalette({
    required this.brightness,
    required this.backgroundCanvas,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceHover,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentHover,
    required this.accentSubtleBg,
    required this.accentSubtleBorder,
    required this.onAccent,
    required this.statusReadyText,
    required this.statusReadyBg,
    required this.statusReadyBorder,
    required this.statusWarningText,
    required this.statusWarningBg,
    required this.statusWarningBorder,
    required this.statusErrorText,
    required this.statusErrorBg,
    required this.statusErrorBorder,
    required this.supplyBlack,
    required this.supplyCyan,
    required this.supplyMagenta,
    required this.supplyYellow,
    required this.supplyMaintenance,
  });

  /// Light neutral desktop palette (WCAG AA >= 4.5:1 verified).
  static const DesktopPalette light = DesktopPalette(
    brightness: Brightness.light,
    backgroundCanvas: Color(0xFFF5F6F8),
    surfacePrimary: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF0F2F5),
    surfaceHover: Color(0xFFE8ECEF),
    borderSubtle: Color(0xFFD8DEE4),
    borderStrong: Color(0xFFAFB8C1),
    textPrimary: Color(0xFF1B1F24), // 16.6:1 on #FFFFFF
    textSecondary: Color(0xFF4B5563), // 7.56:1 on #FFFFFF, 6.65:1 on #F0F2F5
    textMuted: Color(0xFF57606A), // 6.45:1 on #FFFFFF, 5.68:1 on #F0F2F5
    accent: Color(0xFF0F548C), // Calm muted slate-blue (8.05:1 with #FFFFFF)
    accentHover: Color(0xFF0B4370),
    accentSubtleBg: Color(0xFFEBF3FA),
    accentSubtleBorder: Color(0xFFB6D2EC),
    onAccent: Color(0xFFFFFFFF),
    statusReadyText: Color(0xFF146C2E), // 6.10:1 on #EAF6ED
    statusReadyBg: Color(0xFFEAF6ED),
    statusReadyBorder: Color(0xFFA7D7B4),
    statusWarningText: Color(0xFF8A4B08), // 6.20:1 on #FDF4E7
    statusWarningBg: Color(0xFFFDF4E7),
    statusWarningBorder: Color(0xFFE6C28B),
    statusErrorText: Color(0xFFA41E22), // 6.80:1 on #FDECEC
    statusErrorBg: Color(0xFFFDECEC),
    statusErrorBorder: Color(0xFFE5A9AA),
    supplyBlack: Color(0xFF24292F),
    supplyCyan: Color(0xFF0E7490),
    supplyMagenta: Color(0xFF9D174D),
    supplyYellow: Color(0xFFB45309),
    supplyMaintenance: Color(0xFF57606A),
  );

  /// Dark neutral desktop palette (WCAG AA >= 4.5:1 verified).
  static const DesktopPalette dark = DesktopPalette(
    brightness: Brightness.dark,
    backgroundCanvas: Color(0xFF14171A),
    surfacePrimary: Color(0xFF1C2024),
    surfaceSecondary: Color(0xFF24292E),
    surfaceHover: Color(0xFF2D333B),
    borderSubtle: Color(0xFF343B42),
    borderStrong: Color(0xFF4E5761),
    textPrimary: Color(0xFFF0F3F6), // 14.5:1 on #1C2024
    textSecondary: Color(0xFFB1BAC4), // 8.10:1 on #1C2024, 7.01:1 on #24292E
    textMuted: Color(0xFF959FA9), // 5.80:1 on #1C2024, 5.02:1 on #24292E
    accent: Color(0xFF58A6FF), // Calm muted slate-blue (6.85:1 on #1C2024)
    accentHover: Color(0xFF79B8FF),
    accentSubtleBg: Color(0xFF182A3E),
    accentSubtleBorder: Color(0xFF2A4B6E),
    onAccent: Color(0xFF0D1117), // 7.75:1 on #58A6FF
    statusReadyText: Color(0xFF56D364), // 7.80:1 on #16291D
    statusReadyBg: Color(0xFF16291D),
    statusReadyBorder: Color(0xFF265334),
    statusWarningText: Color(0xFFE3B341), // 7.60:1 on #2B2212
    statusWarningBg: Color(0xFF2B2212),
    statusWarningBorder: Color(0xFF5C4419),
    statusErrorText: Color(0xFFFF7B72), // 6.50:1 on #2D1619
    statusErrorBg: Color(0xFF2D1619),
    statusErrorBorder: Color(0xFF63262A),
    supplyBlack: Color(0xFF8B949E),
    supplyCyan: Color(0xFF38BDF8),
    supplyMagenta: Color(0xFFF472B6),
    supplyYellow: Color(0xFFFBBF24),
    supplyMaintenance: Color(0xFF959FA9),
  );

  static DesktopPalette of(BuildContext context) {
    return Theme.of(context).extension<DesktopPalette>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  DesktopPalette copyWith({Brightness? brightness}) => this;

  @override
  DesktopPalette lerp(ThemeExtension<DesktopPalette>? other, double t) {
    if (other is! DesktopPalette) return this;
    return t < 0.5 ? this : other;
  }
}

/// Mathematical WCAG 2.1 contrast ratio checker (verifies >= 4.5:1 text contrast).
abstract final class DesktopContrastChecker {
  static double relativeLuminance(Color c) {
    double channel(int eightBit) {
      final sRgb = eightBit / 255.0;
      return sRgb <= 0.03928
          ? sRgb / 12.92
          : math.pow((sRgb + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = channel((c.value >> 16) & 0xFF);
    final g = channel((c.value >> 8) & 0xFF);
    final b = channel(c.value & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double contrastRatio(Color foreground, Color background) {
    final l1 = relativeLuminance(foreground);
    final l2 = relativeLuminance(background);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static bool meetsWcagAA(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= 4.5;
  }
}

/// 2. Fixed Type Scale (12 / 14 / 16 / 20 / 24) & Language-Tuned Line Height
///
/// English uses `Segoe UI`, Sinhala uses `NotoSansSinhala` with +15% line-height
/// so Sinhala vowel signs (ispilla, papilla) never clip.
abstract final class DesktopTypography {
  static const String englishFontFamily = 'Segoe UI';
  static const String sinhalaFontFamily = 'NotoSansSinhala';

  static const List<String> fontFallbackChain = <String>[
    'Segoe UI',
    'NotoSansSinhala',
    'Noto Sans Sinhala',
    'Iskoola Pota',
    'sans-serif',
  ];

  // Fixed Type Scale (px)
  static const double scale12 = 12.0; // Captions, table headers, metadata, badges
  static const double scale14 = 14.0; // Standard desktop body, controls, buttons
  static const double scale16 = 16.0; // Panel titles, section headers
  static const double scale20 = 20.0; // Screen headers, primary totals
  static const double scale24 = 24.0; // Top-level page titles

  // Line heights: Sinhala receives ~14-15% taller line-height than English
  static double bodyLineHeight({required bool isSinhala}) =>
      isSinhala ? 1.60 : 1.40;

  static double headingLineHeight({required bool isSinhala}) =>
      isSinhala ? 1.50 : 1.30;

  static String primaryFontFamily({required bool isSinhala}) =>
      isSinhala ? sinhalaFontFamily : englishFontFamily;

  /// 12 px — Metadata, table headers, badges, secondary labels
  static TextStyle caption12(
    DesktopPalette palette, {
    bool isSinhala = false,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: primaryFontFamily(isSinhala: isSinhala),
      fontFamilyFallback: fontFallbackChain,
      fontSize: scale12,
      height: bodyLineHeight(isSinhala: isSinhala),
      fontWeight: weight,
      color: color ?? palette.textSecondary,
    );
  }

  /// 14 px — Standard desktop UI body text, inputs, and buttons
  static TextStyle body14(
    DesktopPalette palette, {
    bool isSinhala = false,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: primaryFontFamily(isSinhala: isSinhala),
      fontFamilyFallback: fontFallbackChain,
      fontSize: scale14,
      height: bodyLineHeight(isSinhala: isSinhala),
      fontWeight: weight,
      color: color ?? palette.textPrimary,
    );
  }

  /// 16 px — Panel titles and section headings
  static TextStyle section16(
    DesktopPalette palette, {
    bool isSinhala = false,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: primaryFontFamily(isSinhala: isSinhala),
      fontFamilyFallback: fontFallbackChain,
      fontSize: scale16,
      height: headingLineHeight(isSinhala: isSinhala),
      fontWeight: weight,
      color: color ?? palette.textPrimary,
    );
  }

  /// 20 px — Screen title / primary summary metric
  static TextStyle title20(
    DesktopPalette palette, {
    bool isSinhala = false,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: primaryFontFamily(isSinhala: isSinhala),
      fontFamilyFallback: fontFallbackChain,
      fontSize: scale20,
      height: headingLineHeight(isSinhala: isSinhala),
      fontWeight: weight,
      color: color ?? palette.textPrimary,
    );
  }

  /// 24 px — Top-level workspace header
  static TextStyle display24(
    DesktopPalette palette, {
    bool isSinhala = false,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: primaryFontFamily(isSinhala: isSinhala),
      fontFamilyFallback: fontFallbackChain,
      fontSize: scale24,
      height: headingLineHeight(isSinhala: isSinhala),
      fontWeight: weight,
      color: color ?? palette.textPrimary,
    );
  }
}

/// 3. 8 px Spacing Grid Tokens (No arbitrary margins or gaps)
abstract final class DesktopSpacing {
  static const double s0 = 0.0;
  static const double s4 = 4.0; // Half-grid step for tight inline icon-to-label gap
  static const double s8 = 8.0; // 1x grid unit
  static const double s16 = 16.0; // 2x grid unit
  static const double s24 = 24.0; // 3x grid unit
  static const double s32 = 32.0; // 4x grid unit
  static const double s40 = 40.0; // 5x grid unit
  static const double s48 = 48.0; // 6x grid unit

  static const EdgeInsets panelPadding = EdgeInsets.all(s16);
  static const EdgeInsets compactPadding = EdgeInsets.all(s8);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: s16,
    vertical: s8,
  );
  static const EdgeInsets badgePadding = EdgeInsets.symmetric(
    horizontal: s8,
    vertical: s4,
  );
  static const EdgeInsets screenPadding = EdgeInsets.all(s16);
}

/// 4. Small Corner Radius & 1px Border Tokens (4–8 px only)
abstract final class DesktopRadius {
  static const double r4 = 4.0; // Buttons, inputs, badges, supply bars
  static const double r6 = 6.0; // Inline messages, sub-containers
  static const double r8 = 8.0; // Panels, dialogs, menus

  static const BorderRadius border4 = BorderRadius.all(Radius.circular(r4));
  static const BorderRadius border6 = BorderRadius.all(Radius.circular(r6));
  static const BorderRadius border8 = BorderRadius.all(Radius.circular(r8));

  static const double borderWidth1px = 1.0;
}

/// 5. Elevation Tokens (Flat surfaces everywhere; shadows ONLY on popups/menus)
abstract final class DesktopElevation {
  /// Flat surface: zero shadow on all panels, buttons, and workspace areas.
  static const List<BoxShadow> flat = <BoxShadow>[];

  /// Subtle shadow used strictly for floating menus, dropdowns, and modal dialogs.
  static List<BoxShadow> popupOrMenuShadow(Brightness brightness) {
    final alpha = brightness == Brightness.dark ? 0.45 : 0.12;
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: alpha),
        blurRadius: 8.0,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

/// 6. Motion Tokens (150–250 ms fades & slides only; respects Reduce Motion)
abstract final class DesktopMotion {
  static const Duration fastFade = Duration(milliseconds: 150);
  static const Duration standardTransition = Duration(milliseconds: 200);
  static const Duration panelSlide = Duration(milliseconds: 250);

  static const Curve curve = Curves.easeOutCubic;

  static Duration resolve(
    Duration base, {
    required bool reduceMotion,
  }) {
    return reduceMotion ? Duration.zero : base;
  }
}

/// 7. Central ThemeData Builder (`DesktopTheme`)
abstract final class DesktopTheme {
  static ThemeData light({bool isSinhala = false}) =>
      _build(DesktopPalette.light, isSinhala: isSinhala);

  static ThemeData dark({bool isSinhala = false}) =>
      _build(DesktopPalette.dark, isSinhala: isSinhala);

  static ThemeData _build(
    DesktopPalette palette, {
    required bool isSinhala,
  }) {
    final isDark = palette.brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: palette.brightness,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      primaryContainer: palette.accentSubtleBg,
      onPrimaryContainer: palette.textPrimary,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      secondaryContainer: palette.surfaceSecondary,
      onSecondaryContainer: palette.textPrimary,
      error: palette.statusErrorText,
      onError: palette.surfacePrimary,
      errorContainer: palette.statusErrorBg,
      onErrorContainer: palette.statusErrorText,
      surface: palette.surfacePrimary,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.borderStrong,
      outlineVariant: palette.borderSubtle,
      surfaceContainerLowest: palette.surfacePrimary,
      surfaceContainerLow: palette.surfacePrimary,
      surfaceContainer: palette.surfaceSecondary,
      surfaceContainerHigh: palette.surfaceSecondary,
      surfaceContainerHighest: palette.surfaceHover,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.backgroundCanvas,
      fontFamily: DesktopTypography.primaryFontFamily(isSinhala: isSinhala),
      fontFamilyFallback: DesktopTypography.fontFallbackChain,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: palette.surfaceHover,
      dividerTheme: DividerThemeData(
        color: palette.borderSubtle,
        thickness: DesktopRadius.borderWidth1px,
        space: DesktopSpacing.s16,
      ),
      iconTheme: IconThemeData(
        color: palette.textSecondary,
        size: 18.0,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: palette.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: DesktopRadius.border8,
          side: BorderSide(
            color: palette.borderSubtle,
            width: DesktopRadius.borderWidth1px,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfacePrimary,
        elevation: isDark ? 6 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: DesktopRadius.border6,
          side: BorderSide(
            color: palette.borderSubtle,
            width: DesktopRadius.borderWidth1px,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfacePrimary,
        elevation: isDark ? 8 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: DesktopRadius.border8,
          side: BorderSide(
            color: palette.borderSubtle,
            width: DesktopRadius.borderWidth1px,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfacePrimary,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesktopSpacing.s8,
          vertical: DesktopSpacing.s8,
        ),
        border: OutlineInputBorder(
          borderRadius: DesktopRadius.border4,
          borderSide: BorderSide(
            color: palette.borderStrong,
            width: DesktopRadius.borderWidth1px,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesktopRadius.border4,
          borderSide: BorderSide(
            color: palette.borderStrong,
            width: DesktopRadius.borderWidth1px,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesktopRadius.border4,
          borderSide: BorderSide(
            color: palette.accent,
            width: DesktopRadius.borderWidth1px,
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        palette,
      ],
    );
  }
}

/// Compatibility tokens used by the specialty printing dialog.
///
/// Values are aligned to the light [DesktopPalette] (single slate-blue accent,
/// no teal) so they compile in `const` contexts. TODO: migrate the dialog to
/// `DesktopPalette.of(context)` so it follows dark mode.
abstract final class DesktopColors {
  static const Color accentTeal = Color(0xFF0F548C); // == DesktopPalette.light.accent
  static const Color dialogBackground = Color(0xFFFFFFFF);
  static const Color dialogBorder = Color(0xFFD8DEE4);
  static const Color dialogHeaderBackground = Color(0xFFF0F2F5);
  static const Color menuBackground = Color(0xFFF0F2F5);
  static const Color previewBackground = Color(0xFFF5F6F8);
}
