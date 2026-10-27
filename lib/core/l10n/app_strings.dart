import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage {
  en('en', 'English'),
  si('si', 'සිංහල');

  const AppLanguage(this.code, this.displayName);
  final String code;
  final String displayName;
}

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.en);

  void setLanguage(AppLanguage lang) => state = lang;
  void toggle() =>
      state = state == AppLanguage.en ? AppLanguage.si : AppLanguage.en;
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier();
});

final localeProvider = StateProvider<Locale>((ref) {
  final lang = ref.watch(appLanguageProvider);
  return Locale(lang.code);
});

/// Authoritative, typed string loader that reads strictly from ARB dictionary maps.
/// Ensures zero hardcoded UI strings in widgets and complete spoken-style Sinhala.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  AppLanguage get language =>
      locale.languageCode == 'si' ? AppLanguage.si : AppLanguage.en;

  bool get isSi => locale.languageCode == 'si';

  static AppStrings of(Object localeOrLanguage) {
    if (localeOrLanguage is Locale) {
      return AppStrings(localeOrLanguage);
    }
    if (localeOrLanguage is AppLanguage) {
      return AppStrings(Locale(localeOrLanguage.code));
    }
    return const AppStrings(Locale('en'));
  }

  String _lookup(String key, [Map<String, dynamic>? vars]) {
    final dict = isSi ? _siMap : _enMap;
    var text = dict[key] ?? _enMap[key] ?? key;
    if (vars != null) {
      vars.forEach((k, v) {
        text = text.replaceAll('{$k}', v.toString());
      });
    }
    return text;
  }

  // Navigation
  String get navPrint => _lookup('navPrint');
  String get navPrinters => _lookup('navPrinters');
  String get navJobs => _lookup('navJobs');
  String get navTools => _lookup('navTools');
  String get navShop => _lookup('navShop');
  String get navSettings => _lookup('navSettings');
  String get navPresets => _lookup('navPresets');

  // Print option labels (queue card & preview dialog)
  String get bwLabel => _lookup('bwLabel');
  String get colorLabel => _lookup('colorLabel');
  String get duplexNone => _lookup('duplexNone');
  String get duplexLongEdge => _lookup('duplexLongEdge');
  String get duplexShortEdge => _lookup('duplexShortEdge');
  String get advancedOptions => _lookup('advancedOptions');
  String get reorderHint => _lookup('reorderHint');

  // Title Bar & System
  String get appTitle => _lookup('appTitle');
  String get offlineBadge => _lookup('offlineBadge');
  String get privacyStatementBanner => _lookup('privacyStatementBanner');
  String get toggleThemeTooltip => _lookup('toggleThemeTooltip');
  String get toggleLangTooltip => _lookup('toggleLangTooltip');
  String get commandPaletteHint => _lookup('commandPaletteHint');
  String get commandPaletteTitle => _lookup('commandPaletteTitle');
  String get recentFilesTitle => _lookup('recentFilesTitle');
  String get clearRecentFilesLabel => _lookup('clearRecentFilesLabel');

  // Actions
  String get actionPrint => _lookup('actionPrint');
  String actionPrintWithPages(int pages) =>
      _lookup('actionPrintWithPages', {'pages': pages});
  String get actionSave => _lookup('actionSave');
  String get actionCancel => _lookup('actionCancel');
  String get actionClose => _lookup('actionClose');
  String get actionOpen => _lookup('actionOpen');
  String get actionApply => _lookup('actionApply');
  String get actionOpenInViewer => _lookup('actionOpenInViewer');
  String get actionConvertAgain => _lookup('actionConvertAgain');

  // Drop Zone & Queue
  String get dropZoneTitle => _lookup('dropZoneTitle');
  String get dropZoneSubtitle => _lookup('dropZoneSubtitle');
  String get dropOverlayHeadline => _lookup('dropOverlayHeadline');
  String get dropOverlaySub => _lookup('dropOverlaySub');
  String get btnOpenFiles => _lookup('btnOpenFiles');
  String get btnPasteClipboard => _lookup('btnPasteClipboard');
  String get btnClearQueue => _lookup('btnClearQueue');
  String get btnAddMoreFiles => _lookup('btnAddMoreFiles');
  String get queueHeader => _lookup('queueHeader');
  String get queueEmpty => _lookup('queueEmpty');
  String get queueEmptyHint => _lookup('queueEmptyHint');
  String get queueItemRemoveTooltip => _lookup('queueItemRemoveTooltip');
  String queueCountBadge(int count) =>
      _lookup('queueCountBadge', {'count': count});
  String totalPagesLabel(int count) =>
      _lookup('totalPagesLabel', {'count': count});

  // Preview
  String get previewHeader => _lookup('previewHeader');
  String get prevPage => _lookup('prevPage');
  String get nextPage => _lookup('nextPage');
  String pageCountOf(int current, int total) =>
      _lookup('pageCountOf', {'current': current, 'total': total});
  String get zoomIn => _lookup('zoomIn');
  String get zoomOut => _lookup('zoomOut');
  String get fitPage => _lookup('fitPage');
  String get fitWidth => _lookup('fitWidth');

  // Print Settings Panel
  String get printPanelHeader => _lookup('printPanelHeader');
  String get printerLabel => _lookup('printerLabel');
  String get selectPrinterHint => _lookup('selectPrinterHint');
  String get copiesLabel => _lookup('copiesLabel');
  String get colorModeLabel => _lookup('colorModeLabel');
  String get colorModeColor => _lookup('colorModeColor');
  String get colorModeBw => _lookup('colorModeBw');
  String get sidesLabel => _lookup('sidesLabel');
  String get sidesSingle => _lookup('sidesSingle');
  String get sidesDoubleLong => _lookup('sidesDoubleLong');
  String get sidesDoubleShort => _lookup('sidesDoubleShort');
  String get paperSizeLabel => _lookup('paperSizeLabel');
  String get paperTrayLabel => _lookup('paperTrayLabel');
  String get advancedSettings => _lookup('advancedSettings');
  String get pageRangeLabel => _lookup('pageRangeLabel');
  String get pageRangeAll => _lookup('pageRangeAll');
  String get pageRangeCustom => _lookup('pageRangeCustom');
  String get pageRangeHint => _lookup('pageRangeHint');
  String get paperTypeLabel => _lookup('paperTypeLabel');
  String get paperTypePlain => _lookup('paperTypePlain');
  String get paperTypeMatte => _lookup('paperTypeMatte');
  String get paperTypeGlossy => _lookup('paperTypeGlossy');
  String get paperTypeEnvelope => _lookup('paperTypeEnvelope');
  String get printQualityLabel => _lookup('printQualityLabel');
  String get qualityDraft => _lookup('qualityDraft');
  String get qualityNormal => _lookup('qualityNormal');
  String get qualityHigh => _lookup('qualityHigh');
  String get orientationLabel => _lookup('orientationLabel');
  String get orientationPortrait => _lookup('orientationPortrait');
  String get orientationLandscape => _lookup('orientationLandscape');
  String get layoutNupLabel => _lookup('layoutNupLabel');
  String get borderlessLabel => _lookup('borderlessLabel');
  String get saveAsPreset => _lookup('saveAsPreset');

  // Printer Live Intelligence
  String get printerStatusReady => _lookup('printerStatusReady');
  String get printerStatusPrinting => _lookup('printerStatusPrinting');
  String get printerStatusOffline => _lookup('printerStatusOffline');
  String get printerStatusError => _lookup('printerStatusError');
  String get printerStatusPaused => _lookup('printerStatusPaused');
  String get supplyInkLabel => _lookup('supplyInkLabel');
  String get supplyTonerLabel => _lookup('supplyTonerLabel');
  String get supplyLowWarning => _lookup('supplyLowWarning');
  String get supplyEmptyWarning => _lookup('supplyEmptyWarning');
  String get paperLoadedBadge => _lookup('paperLoadedBadge');
  String get paperNotLoadedBadge => _lookup('paperNotLoadedBadge');
  String trayLoadedStatus(String size) =>
      _lookup('trayLoadedStatus', {'size': size});
  String get duplexAutoBadge => _lookup('duplexAutoBadge');
  String get duplexManualBadge => _lookup('duplexManualBadge');
  String get colorCapableBadge => _lookup('colorCapableBadge');
  String get monoOnlyBadge => _lookup('monoOnlyBadge');
  String get copyDiagnostics => _lookup('copyDiagnostics');
  String get diagnosticsCopied => _lookup('diagnosticsCopied');
  String get expandDetails => _lookup('expandDetails');
  String get collapseDetails => _lookup('collapseDetails');

  // Plain Language Alerts
  String get epsonCoverOpen => _lookup('epsonCoverOpen');
  String get epsonPaperJam => _lookup('epsonPaperJam');
  String epsonPaperOut(String tray) =>
      _lookup('epsonPaperOut', {'tray': tray});
  String get epsonInkNotRecognized => _lookup('epsonInkNotRecognized');
  String get epsonMaintenanceBoxNearEnd =>
      _lookup('epsonMaintenanceBoxNearEnd');
  String get epsonHeadCleaning => _lookup('epsonHeadCleaning');
  String get epsonBorderlessNotice => _lookup('epsonBorderlessNotice');

  // Shop Mode
  String get shopTitle => _lookup('shopTitle');
  String get shopCustomerJobs => _lookup('shopCustomerJobs');
  String get shopPriceCalc => _lookup('shopPriceCalc');
  String get shopReceipt => _lookup('shopReceipt');
  String get shopCostTracking => _lookup('shopCostTracking');
  String get shopMultiPrinter => _lookup('shopMultiPrinter');
  String get shopDailyReport => _lookup('shopDailyReport');
  String get shopAddJob => _lookup('shopAddJob');
  String get shopOneClickReprint => _lookup('shopOneClickReprint');
  String get shopStatusWaiting => _lookup('shopStatusWaiting');
  String get shopStatusPrinting => _lookup('shopStatusPrinting');
  String get shopStatusDone => _lookup('shopStatusDone');
  String get shopStatusPickedUp => _lookup('shopStatusPickedUp');

  // PDF Tools
  String get toolsConvertTitle => _lookup('toolsConvertTitle');
  String get toolsOrganizeTitle => _lookup('toolsOrganizeTitle');
  String get toolsEditTitle => _lookup('toolsEditTitle');
  String get toolsSecurityTitle => _lookup('toolsSecurityTitle');
  String get toolsCompareTitle => _lookup('toolsCompareTitle');
  String get toolsOcrTitle => _lookup('toolsOcrTitle');
  String get toolsConvertQualityNote => _lookup('toolsConvertQualityNote');

  // Settings
  String get settingsGeneral => _lookup('settingsGeneral');
  String get settingsTheme => _lookup('settingsTheme');
  String get settingsThemeLight => _lookup('settingsThemeLight');
  String get settingsThemeDark => _lookup('settingsThemeDark');
  String get settingsLanguage => _lookup('settingsLanguage');
  String get settingsLanguageEn => _lookup('settingsLanguageEn');
  String get settingsLanguageSi => _lookup('settingsLanguageSi');
  String get settingsReduceMotion => _lookup('settingsReduceMotion');
  String get settingsLicenses => _lookup('settingsLicenses');
  String get settingsLogs => _lookup('settingsLogs');
  String get globalSearchHint => _lookup('globalSearchHint');

  // Steps & Typography
  String get step1Label => _lookup('step1Label');
  String get step2Label => _lookup('step2Label');
  String get step3Label => _lookup('step3Label');
  String get pagesLabel => _lookup('pagesLabel');
  String get pageLabel => _lookup('pageLabel');
  String get textTypographyHeader => _lookup('textTypographyHeader');
  String get fontFamilyLabel => _lookup('fontFamilyLabel');
  String get fontSizeLabel => _lookup('fontSizeLabel');
  String get lineSpacingLabel => _lookup('lineSpacingLabel');
  String get wordWrapLabel => _lookup('wordWrapLabel');
  String get sinhalaTestDocButton => _lookup('sinhalaTestDocButton');
  String get printAction => _lookup('actionPrint');

  // Static dictionaries mapped directly to ARB contents
  static final Map<String, String> _enMap = {
    'appTitle': 'Print Helper',
    'offlineBadge': '100% Offline',
    'privacyStatementBanner':
        'Nothing leaves your PC — 100% Offline & Zero Telemetry',
    'navPrint': 'Print',
    'navPrinters': 'Printers',
    'navJobs': 'Jobs',
    'navTools': 'Tools',
    'navShop': 'Shop',
    'navSettings': 'Settings',
    'navPresets': 'Presets',
    'toggleThemeTooltip': 'Toggle Light/Dark theme',
    'toggleLangTooltip': 'Switch Language (EN / සිංහල)',
    'commandPaletteHint': 'Search all tools & commands (Ctrl+K)...',
    'commandPaletteTitle': 'Global Tool Search & Command Palette (Ctrl+K)',
    'recentFilesTitle': 'Recent Files Across All Tools',
    'clearRecentFilesLabel': 'Clear Recent',
    'actionPrint': 'Print',
    'actionPrintWithPages': 'Print ({pages} pages)',
    'actionSave': 'Save',
    'actionCancel': 'Cancel',
    'actionClose': 'Close',
    'actionOpen': 'Open',
    'actionApply': 'Apply',
    'actionOpenInViewer': 'Open in Viewer',
    'actionConvertAgain': 'Convert Again',
    'dropZoneTitle': 'Drop files here to print',
    'dropZoneSubtitle':
        'Supports PDF, Images (PNG, JPG, BMP, TIFF, WebP), Plain Text (TXT) and Markdown (MD)',
    'dropOverlayHeadline': 'Drop files to print',
    'dropOverlaySub': 'Release to add files to your print queue',
    'btnOpenFiles': 'Add Files',
    'btnPasteClipboard': 'Paste (Ctrl+V)',
    'btnClearQueue': 'Clear All',
    'btnAddMoreFiles': 'Add More Files',
    'queueHeader': 'Files to Print',
    'queueEmpty': 'No files added yet',
    'queueEmptyHint': 'Drag and drop files here or click Add Files to begin.',
    'queueItemRemoveTooltip': 'Remove this file',
    'queueCountBadge': '{count} files',
    'totalPagesLabel': '{count} pages',
    'previewHeader': 'Preview',
    'prevPage': 'Previous',
    'nextPage': 'Next',
    'pageCountOf': 'Page {current} of {total}',
    'zoomIn': 'Zoom In',
    'zoomOut': 'Zoom Out',
    'fitPage': 'Fit Page',
    'fitWidth': 'Fit Width',
    'printPanelHeader': 'Print Settings',
    'printerLabel': 'Printer',
    'selectPrinterHint': 'Choose a printer',
    'copiesLabel': 'Copies',
    'colorModeLabel': 'Color',
    'colorModeColor': 'Color',
    'colorModeBw': 'Black & White',
    'sidesLabel': 'Sides',
    'sidesSingle': 'Single-sided',
    'sidesDoubleLong': 'Two-sided (Long Edge)',
    'sidesDoubleShort': 'Two-sided (Short Edge)',
    'paperSizeLabel': 'Paper Size',
    'paperTrayLabel': 'Paper Tray',
    'advancedSettings': 'Advanced Settings',
    'pageRangeLabel': 'Page Range',
    'pageRangeAll': 'All Pages',
    'pageRangeCustom': 'Custom Pages',
    'pageRangeHint': 'e.g. 1-3, 5',
    'paperTypeLabel': 'Paper Type',
    'bwLabel': 'Black & White',
    'colorLabel': 'Color',
    'duplexNone': 'One-sided',
    'duplexLongEdge': 'Two-sided (long edge)',
    'duplexShortEdge': 'Two-sided (short edge)',
    'advancedOptions': 'Advanced options',
    'reorderHint': 'Drag to reorder',
    'paperTypePlain': 'Plain Paper',
    'paperTypeMatte': 'Matte Paper',
    'paperTypeGlossy': 'Glossy Photo Paper',
    'paperTypeEnvelope': 'Envelope',
    'printQualityLabel': 'Quality',
    'qualityDraft': 'Draft',
    'qualityNormal': 'Normal',
    'qualityHigh': 'High Quality',
    'orientationLabel': 'Orientation',
    'orientationPortrait': 'Portrait',
    'orientationLandscape': 'Landscape',
    'layoutNupLabel': 'Pages Per Sheet',
    'borderlessLabel': 'Borderless',
    'saveAsPreset': 'Save as Preset...',
    'printerStatusReady': 'Ready',
    'printerStatusPrinting': 'Printing',
    'printerStatusOffline': 'Printer is offline',
    'printerStatusError': 'Printer error',
    'printerStatusPaused': 'Paused',
    'supplyInkLabel': 'Ink Levels',
    'supplyTonerLabel': 'Toner Levels',
    'supplyLowWarning': 'Ink is low',
    'supplyEmptyWarning': 'Ink is empty',
    'paperLoadedBadge': 'Loaded',
    'paperNotLoadedBadge': 'Supported but not loaded',
    'trayLoadedStatus': '{size} loaded',
    'duplexAutoBadge': 'Auto Duplex',
    'duplexManualBadge': 'Manual Duplex',
    'colorCapableBadge': 'Color & B&W',
    'monoOnlyBadge': 'B&W Only',
    'copyDiagnostics': 'Copy printer diagnostics',
    'diagnosticsCopied': 'Printer diagnostics copied to clipboard',
    'expandDetails': 'Show more details',
    'collapseDetails': 'Hide details',
    'epsonCoverOpen': 'Printer cover is open. Please close the cover.',
    'epsonPaperJam': 'Paper jam detected. Please remove jammed paper.',
    'epsonPaperOut': 'Out of paper. Please load paper in tray.',
    'epsonInkNotRecognized':
        'Ink cartridge not recognized. Reinsert or replace cartridge.',
    'epsonMaintenanceBoxNearEnd':
        'Maintenance box is near end of life. Prepare a replacement.',
    'epsonHeadCleaning': 'Head cleaning in progress. Please wait a moment.',
    'epsonBorderlessNotice':
        'Borderless printing requires supported photo paper size.',
    'shopTitle': 'Shop Quick Print',
    'shopCustomerJobs': 'Customer Jobs',
    'shopPriceCalc': 'Price Calculator',
    'shopReceipt': 'Print Receipt / Invoice',
    'shopCostTracking': 'Cost & Profit Estimate',
    'shopMultiPrinter': 'Multi-Printer Dashboard',
    'shopDailyReport': 'Daily Report',
    'shopAddJob': 'New Customer Job',
    'shopOneClickReprint': 'Reprint Last Job',
    'shopStatusWaiting': 'Waiting',
    'shopStatusPrinting': 'Printing',
    'shopStatusDone': 'Done',
    'shopStatusPickedUp': 'Picked Up',
    'toolsConvertTitle': 'Convert Files',
    'toolsOrganizeTitle': 'Organize Pages',
    'toolsEditTitle': 'Edit Content',
    'toolsSecurityTitle': 'Protect & Redact',
    'toolsCompareTitle': 'Compare Documents',
    'toolsOcrTitle': 'Text Recognition (OCR)',
    'toolsConvertQualityNote':
        'Note: Complex layouts may need manual adjustment.',
    'settingsGeneral': 'General',
    'settingsTheme': 'Theme',
    'settingsThemeLight': 'Light',
    'settingsThemeDark': 'Dark',
    'settingsLanguage': 'Language',
    'settingsLanguageEn': 'English',
    'settingsLanguageSi': 'සිංහල',
    'settingsReduceMotion': 'Reduce Motion',
    'settingsLicenses': 'Licenses',
    'settingsLogs': 'Diagnostic Logs',
    'globalSearchHint': 'Search tools, presets, settings (Ctrl+K)...',
    'step1Label': '1. Add Files',
    'step2Label': '2. Pick Printer',
    'step3Label': '3. Press Print',
    'pagesLabel': 'pages',
    'pageLabel': 'page',
    'textTypographyHeader': 'Plain Text & Markdown Typography',
    'fontFamilyLabel': 'Font Family',
    'fontSizeLabel': 'Font Size (pt)',
    'lineSpacingLabel': 'Line Spacing',
    'wordWrapLabel': 'Wrap Long Lines',
    'sinhalaTestDocButton': 'Load Sinhala Test Document',
  };

  static final Map<String, String> _siMap = {
    'appTitle': 'Print Helper',
    'offlineBadge': '100% නොබැඳිව (Offline)',
    'privacyStatementBanner':
        'ඔබේ කිසිම දත්තයක් පරිගණකයෙන් පිටතට නොයයි — 100% Offline',
    'navPrint': 'ප්‍රින්ට්',
    'navPrinters': 'ප්‍රින්ටර්ස්',
    'navJobs': 'පෝලිම',
    'navTools': 'PDF මෙවලම්',
    'navShop': 'කඩේ මුද්‍රණ',
    'navSettings': 'සැකසුම්',
    'navPresets': 'ලෑස්ති සැකසුම්',
    'toggleThemeTooltip': 'තේමාව මාරු කරන්න',
    'toggleLangTooltip': 'භාෂාව මාරු කරන්න (English / සිංහල)',
    'commandPaletteHint': 'මෙවලම් සහ සැකසුම් සොයන්න (Ctrl+K)...',
    'commandPaletteTitle': 'මෙවලම් සහ විධාන සොයන්න (Ctrl+K)',
    'recentFilesTitle': 'මෑතකදී ගත් ෆයිල්',
    'clearRecentFilesLabel': 'මෑත ෆයිල් අයින් කරන්න',
    'actionPrint': 'ප්‍රින්ට් කරන්න',
    'actionPrintWithPages': 'ප්‍රින්ට් කරන්න (පිටු {pages})',
    'actionSave': 'සුරකින්න',
    'actionCancel': 'අවලංගු කරන්න',
    'actionClose': 'වහන්න',
    'actionOpen': 'අරින්න',
    'actionApply': 'යොදන්න',
    'actionOpenInViewer': 'කියවනයේ අරින්න',
    'actionConvertAgain': 'නැවත හරවන්න',
    'dropZoneTitle': 'ෆයිල් මෙතනට දාන්න',
    'dropZoneSubtitle':
        'PDF, පින්තූර (PNG, JPG, WebP), TXT සහ Markdown ෆයිල් දැමිය හැක',
    'dropOverlayHeadline': 'ෆයිල් මෙතනින් අතහරින්න',
    'dropOverlaySub': 'ප්‍රින්ට් කිරීමට ෆයිල් එකතු වේ',
    'btnOpenFiles': 'ෆයිල් එකතු කරන්න',
    'btnPasteClipboard': 'පේස්ට් කරන්න (Ctrl+V)',
    'btnClearQueue': 'සියල්ල අයින් කරන්න',
    'btnAddMoreFiles': 'තවත් ෆයිල් දාන්න',
    'queueHeader': 'ප්‍රින්ට් කරන ෆයිල්',
    'queueEmpty': 'තවම ෆයිල් එකතු කර නැහැ',
    'queueEmptyHint': 'ෆයිල් මෙතනට දාන්න හෝ \'ෆයිල් එකතු කරන්න\' ඔබන්න.',
    'queueItemRemoveTooltip': 'මේ ෆයිල් එක අයින් කරන්න',
    'queueCountBadge': 'ෆයිල් {count}',
    'totalPagesLabel': 'පිටු {count}',
    'previewHeader': 'පෙරදසුන',
    'prevPage': 'කලින් පිටුව',
    'nextPage': 'ඊළඟ පිටුව',
    'pageCountOf': 'පිටුව {current} / {total}',
    'zoomIn': 'විශාල කරන්න',
    'zoomOut': 'කුඩා කරන්න',
    'fitPage': 'මුළු පිටුවම',
    'fitWidth': 'පළලට ගලපන්න',
    'printPanelHeader': 'ප්‍රින්ට් සැකසුම්',
    'printerLabel': 'ප්‍රින්ටර් එක',
    'selectPrinterHint': 'ප්‍රින්ටර් එකක් තෝරන්න',
    'copiesLabel': 'කොපි ගණන',
    'colorModeLabel': 'පාට',
    'colorModeColor': 'පාටින්',
    'colorModeBw': 'කළු සුදු',
    'sidesLabel': 'මුද්‍රණය කරන පැත්ත',
    'sidesSingle': 'එක පැත්තකින්',
    'sidesDoubleLong': 'දෙපැත්තෙන්ම (පොතක් වගේ)',
    'sidesDoubleShort': 'දෙපැත්තෙන්ම (දින දර්ශනයක් වගේ)',
    'paperSizeLabel': 'කඩදාසි ප්‍රමාණය',
    'paperTrayLabel': 'කඩදාසි තැටිය',
    'advancedSettings': 'වැඩිදුර සැකසුම්',
    'pageRangeLabel': 'පිටු පරාසය',
    'pageRangeAll': 'සියලුම පිටු',
    'pageRangeCustom': 'තෝරාගත් පිටු',
    'pageRangeHint': 'උදා: 1-3, 5',
    'paperTypeLabel': 'කඩදාසි වර්ගය',
    'bwLabel': 'කළු සහ සුදු',
    'colorLabel': 'වර්ණ',
    'duplexNone': 'එක් පැත්තක්',
    'duplexLongEdge': 'පැති දෙකම (දිගු දාරය)',
    'duplexShortEdge': 'පැති දෙකම (කෙටි දාරය)',
    'advancedOptions': 'උසස් විකල්ප',
    'reorderHint': 'නැවත පිළිවෙළ කිරීමට ඇදගෙන යන්න',
    'paperTypePlain': 'සාමාන්‍ය කඩදාසි',
    'paperTypeMatte': 'මැට් කඩදාසි',
    'paperTypeGlossy': 'ග්ලොසි ෆොටෝ කඩදාසි',
    'paperTypeEnvelope': 'ලියුම් කවර',
    'printQualityLabel': 'තත්ත්වය',
    'qualityDraft': 'වේගවත් (Draft)',
    'qualityNormal': 'සාමාන්‍ය',
    'qualityHigh': 'උසස් තත්ත්වයෙන්',
    'orientationLabel': 'දිශාව',
    'orientationPortrait': 'සිරස්',
    'orientationLandscape': 'තිරස්',
    'layoutNupLabel': 'පිටුවකට පිටු ගණන',
    'borderlessLabel': 'දාර රහිතව',
    'saveAsPreset': 'ලෑස්ති සැකසුමක් ලෙස සුරකින්න...',
    'printerStatusReady': 'සූදානම්',
    'printerStatusPrinting': 'ප්‍රින්ට් වෙනවා',
    'printerStatusOffline': 'ප්‍රින්ටර් එක සම්බන්ධ වෙලා නැහැ',
    'printerStatusError': 'ප්‍රින්ටර් එකේ දෝෂයක්',
    'printerStatusPaused': 'නවත්වා ඇත',
    'supplyInkLabel': 'ඉන්ක් මට්ටම',
    'supplyTonerLabel': 'ටෝනර් මට්ටම',
    'supplyLowWarning': 'තීන්ත අඩුයි',
    'supplyEmptyWarning': 'තීන්ත ඉවරයි',
    'paperLoadedBadge': 'දමා ඇත',
    'paperNotLoadedBadge': 'සහය දක්වයි (දමා නැත)',
    'trayLoadedStatus': '{size} කඩදාසි දමා ඇත',
    'duplexAutoBadge': 'ස්වයංක්‍රීය දෙපැත්ත',
    'duplexManualBadge': 'අතින් දෙපැත්ත හරවන්න',
    'colorCapableBadge': 'පාට සහ කළු සුදු',
    'monoOnlyBadge': 'කළු සුදු පමණි',
    'copyDiagnostics': 'ප්‍රින්ටර් විස්තර කොපි කරන්න',
    'diagnosticsCopied': 'ප්‍රින්ටර් විස්තර කොපි කරගන්නා ලදී',
    'expandDetails': 'තවත් විස්තර බලන්න',
    'collapseDetails': 'විස්තර සඟවන්න',
    'epsonCoverOpen': 'ප්‍රින්ටර් එකේ පියන ඇරලා තියෙන්නේ. කරුණාකර පියන වහන්න.',
    'epsonPaperJam': 'කඩදාසි හිරවෙලා. කරුණාකර හිරවුණු කඩදාසි ඉවත් කරන්න.',
    'epsonPaperOut': 'කඩදාසි ඉවරයි. කරුණාකර තැටියට කඩදාසි දාන්න.',
    'epsonInkNotRecognized':
        'ඉන්ක් කාට්‍රිජ් එක හඳුනාගත නොහැක. නැවත දමන්න හෝ අලුත් එකක් දමන්න.',
    'epsonMaintenanceBoxNearEnd':
        'මේන්ටෙනන්ස් බොක්ස් එක පිරීගෙන එයි. අලුත් එකක් සූදානම් කරගන්න.',
    'epsonHeadCleaning':
        'හෙඩ් එක ක්ලීන් වෙනවා. කරුණාකර සුළු මොහොතක් රැඳී සිටින්න.',
    'epsonBorderlessNotice':
        'දාර රහිතව මුද්‍රණයට නියමිත ෆොටෝ කඩදාසි ප්‍රමාණයක් තෝරන්න.',
    'shopTitle': 'කඩේ ඉක්මන් මුද්‍රණ',
    'shopCustomerJobs': 'පාරිභෝගික ඇණවුම්',
    'shopPriceCalc': 'මිල ගණනය',
    'shopReceipt': 'රිසිට්පත මුද්‍රණය',
    'shopCostTracking': 'වියදම සහ ලාභය (ඇස්තමේන්තුව)',
    'shopMultiPrinter': 'සියලු ප්‍රින්ටර් තත්ත්වය',
    'shopDailyReport': 'දෛනික වාර්තාව',
    'shopAddJob': 'අලුත් ඇණවුමක්',
    'shopOneClickReprint': 'අවසාන ඇණවුම නැවත ප්‍රින්ට් කරන්න',
    'shopStatusWaiting': 'පොරොත්තුවේ',
    'shopStatusPrinting': 'ප්‍රින්ට් වෙනවා',
    'shopStatusDone': 'අවසන්',
    'shopStatusPickedUp': 'භාර දුන්නා',
    'toolsConvertTitle': 'ෆයිල් පරිවර්තනය',
    'toolsOrganizeTitle': 'පිටු සැකසීම',
    'toolsEditTitle': 'වෙනස්කම් කරන්න',
    'toolsSecurityTitle': 'මුරපද සහ ආරක්ෂාව',
    'toolsCompareTitle': 'PDF සංසන්දනය',
    'toolsOcrTitle': 'අකුරු හඳුනාගැනීම (OCR)',
    'toolsConvertQualityNote':
        'සටහන: සංකීර්ණ සැකසුම් සුළු වශයෙන් වෙනස් විය හැක.',
    'settingsGeneral': 'සාමාන්‍ය',
    'settingsTheme': 'තේමාව',
    'settingsThemeLight': 'ලා පැහැය',
    'settingsThemeDark': 'තද පැහැය',
    'settingsLanguage': 'භාෂාව',
    'settingsLanguageEn': 'English',
    'settingsLanguageSi': 'සිංහල',
    'settingsReduceMotion': 'සජීවිකරණ අවම කරන්න',
    'settingsLicenses': 'බලපත්‍ර (Licenses)',
    'settingsLogs': 'දෝෂ සටහන් (Logs)',
    'globalSearchHint': 'මෙවලම් සහ සැකසුම් සොයන්න (Ctrl+K)...',
    'step1Label': '1. ෆයිල් එකතු කරන්න',
    'step2Label': '2. ප්‍රින්ටර් එක තෝරන්න',
    'step3Label': '3. ප්‍රින්ට් කරන්න',
    'pagesLabel': 'පිටු',
    'pageLabel': 'පිටුව',
    'textTypographyHeader': 'පෙළ සහ Markdown අකුරු සැකසුම්',
    'fontFamilyLabel': 'අකුරු වර්ගය',
    'fontSizeLabel': 'අකුරු ප්‍රමාණය (pt)',
    'lineSpacingLabel': 'පේළි පරතරය',
    'wordWrapLabel': 'දිගු පේළි පිටුවට ගලපන්න',
    'sinhalaTestDocButton': 'සිංහල පරීක්ෂණ ෆයිල් එකක් එක් කරන්න',
  };
}
