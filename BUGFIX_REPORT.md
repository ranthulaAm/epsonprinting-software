# Bug-fix report (static pass — NOT compiled)

No Dart/Flutter SDK was available, so none of this has been built or run.
Run `flutter pub get && flutter analyze` first and send me the output.

## Fixed
- print_settings_panel.dart:687 `.toList>,` -> `.toList(),` (syntax error, blocked the whole build)
- 8 broken relative imports in 5 files (verified with a script that resolves every import; 0 remain in lib/)
- 3 tests imported `package:antigravity_pdf_gear` -> `package:print_helper`
- Added missing `assets/icons/` (pubspec referenced it)
- Spacing tokens s6/s10/s12/s20 (do not exist, break 8px grid) -> s8/s8/s16/s16
- DesktopPalette: border->borderSubtle, surface->surfacePrimary, warning->statusWarningText, textTertiary->textMuted
- `DesktopTheme.of(context).palette` -> `DesktopPalette.of(context)` (3 files)
- `FormRow(child:)` -> `control:` (25 calls)
- Added `DesktopColors` (used 29x in specialty dialog, never defined). Light-theme values only:
  TODO migrate that dialog to DesktopPalette so dark mode works.
- `Colors.redGreyOrIndigo` (invalid extension on Colors) -> private `_previewColorFor()`
- `Icons.SimCardAlert_outlined` -> `Icons.sim_card_alert_outlined`
- `TelemetryConfidence.verified` -> `.high`; `PrintDocumentType.text` -> `.plainText`
- `PrinterDevice.name` -> `.systemName` in print_settings_panel.dart
- Added 7 missing AppStrings getters (EN + Sinhala): bwLabel, colorLabel, duplexNone,
  duplexLongEdge, duplexShortEdge, advancedOptions, reorderHint
  (Sinhala text is mine — have a native speaker review it.)

## Corrected from the earlier report
- `archive` is NOT missing: the code uses `img.Archive` / `img.ZipEncoder`, re-exported by the `image` package.

## Not fixed yet
- test/ is stale: shop_mode_test.dart imports non-existent `core/domain/print_models.dart`; many tests target APIs that don't exist.
- README claims ESC/POS thermal printing and Plus Jakarta Sans; neither is in the code/assets.
- Windows printing (win32 FFI, DEVMODE, SNMP) needs real-hardware testing.
- Possibly more errors only the real analyzer will show.
