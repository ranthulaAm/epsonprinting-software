import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale);

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations('en');
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si'),
  ];

  bool get isSi => localeName.startsWith('si');

  String get appTitle =>
      isSi ? 'Print Helper — සරල මුද්‍රණ සහායක' : 'Print Helper';
  String get offlineBadge =>
      isSi ? '100% Offline (අන්තර්ජාලය රහිත)' : '100% Offline';
  String get navPrint => isSi ? 'මුද්‍රණය (Print)' : 'Print';
  String get navPrinters => isSi ? 'මුද්‍රණ යන්ත්‍ර' : 'Printers';
  String get navJobs => isSi ? 'මුද්‍රණ පෝලිම' : 'Jobs';
  String get navPresets => isSi ? 'පෙර සැකසුම්' : 'Presets';
  String get navSettings => isSi ? 'සැකසුම්' : 'Settings';
  String get toggleThemeTooltip =>
      isSi ? 'තේමාව වෙනස් කරන්න (Light/Dark)' : 'Toggle Light/Dark theme';
  String get toggleLangTooltip =>
      isSi ? 'භාෂාව වෙනස් කරන්න (සිංහල / EN)' : 'Switch Language (EN / සිංහල)';
  String get dropZoneTitle => isSi
      ? 'මුද්‍රණය කිරීමට ගොනු මෙතැනට ඇද දමන්න'
      : 'Drop files anywhere to print';
  String get dropZoneSubtitle => isSi
      ? 'PDF, රූප (PNG, JPG, BMP, TIFF, WebP), පෙළ (TXT) සහ Markdown (MD) ගොනු සඳහා සහය දක්වයි'
      : 'Supports PDF, Images (PNG, JPG, BMP, TIFF, WebP), Plain Text (TXT) and Markdown (MD)';
  String get dropOverlayHeadline =>
      isSi ? 'මුද්‍රණය සඳහා ගොනු අතහරින්න' : 'Drop files to print';
  String get dropOverlaySub => isSi
      ? 'ගොනු එකක් හෝ කිහිපයක් එකවර මුද්‍රණ පෝලිමට එක් කළ හැක'
      : 'Release to add one or multiple files to your print queue';
  String get btnOpenFiles => isSi ? 'ගොනු තෝරන්න...' : 'Open Files...';
  String get btnPasteClipboard =>
      isSi ? 'පසුරු පුවරුවෙන් අලවන්න (Ctrl+V)' : 'Paste (Ctrl+V)';
  String get btnClearQueue => isSi ? 'සියල්ල ඉවත් කරන්න' : 'Clear Queue';
  String get btnAddMoreFiles => isSi ? 'තවත් ගොනු එක් කරන්න' : 'Add Files';
  String get step1Label => isSi ? '1. ගොනු එක් කරන්න' : '1. Add Files';
  String get step2Label => isSi ? '2. මුද්‍රණ යන්ත්‍රය තෝරන්න' : '2. Pick Printer';
  String get step3Label => isSi ? '3. මුද්‍රණය කරන්න' : '3. Press Print';
  String get queueHeader =>
      isSi ? 'මුද්‍රණයට සූදානම් ගොනු ලැයිස්තුව' : 'Files Ready to Print';
  String get pagesLabel => isSi ? 'පිටු' : 'pages';
  String get pageLabel => isSi ? 'පිටුව' : 'page';
  String get copiesLabel => isSi ? 'පිටපත්' : 'Copies';
  String get colorLabel => isSi ? 'වර්ණ' : 'Color';
  String get bwLabel => isSi ? 'කළු-සුදු' : 'B&W';
  String get orientationPortrait => isSi ? 'සිරස් (Portrait)' : 'Portrait';
  String get orientationLandscape => isSi ? 'තිරස් (Landscape)' : 'Landscape';
  String get duplexNone => isSi ? 'එක් පැත්තක් පමණි' : 'One-sided';
  String get duplexLongEdge =>
      isSi ? 'දෙපැත්තම (දිගු දාරය - පොතක් ලෙස)' : 'Two-sided (Long Edge)';
  String get duplexShortEdge => isSi
      ? 'දෙපැත්තම (කෙටි දාරය - දින දර්ශනයක් ලෙස)'
      : 'Two-sided (Short Edge)';
  String get pageRangeAll => isSi ? 'සියලුම පිටු' : 'All Pages';
  String get pageRangeCustom => isSi ? 'තෝරාගත් පිටු පරාසය' : 'Custom Range';
  String get advancedOptions => isSi ? 'වැඩිදුර සැකසුම්' : 'Advanced Settings';
  String get paperSizeLabel => isSi ? 'කඩදාසි ප්‍රමාණය' : 'Paper Size';
  String get paperTrayLabel => isSi ? 'කඩදාසි තැටිය (Tray)' : 'Paper Tray';
  String get printAction => isSi ? 'දැන් මුද්‍රණය කරන්න' : 'Print Now';
  String get reorderHint =>
      isSi ? 'අනුපිළිවෙල වෙනස් කිරීමට ඇදගෙන යන්න' : 'Drag handle to reorder batch';
  String get textTypographyHeader => isSi
      ? 'පෙළ සහ Markdown අකුරු සැකසුම් (සිංහල සහාය)'
      : 'Plain Text & Markdown Typography (සිංහල Ready)';
  String get fontFamilyLabel =>
      isSi ? 'අකුරු වර්ගය (Font)' : 'Font Family';
  String get fontSizeLabel =>
      isSi ? 'අකුරු ප්‍රමාණය (pt)' : 'Font Size (pt)';
  String get lineSpacingLabel =>
      isSi ? 'පේළි පරතරය' : 'Line Spacing';
  String get wordWrapLabel => isSi
      ? 'දිගු පේළි පිටුවට ගලපන්න (Word Wrap)'
      : 'Wrap Long Lines';
  String get sinhalaTestDocButton => isSi
      ? 'සිංහල පරීක්ෂණ ලේඛනය එක් කරන්න'
      : 'Load Sinhala Test Document';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'si'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations(locale.languageCode),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
