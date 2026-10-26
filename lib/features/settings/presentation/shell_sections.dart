import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/diagnostics/diagnostic_logger.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/presentation/onboarding_dialog.dart';
import 'ai_settings_card.dart';

/// Complete Settings, Accessibility, Diagnostics, Update Check & Compliance Screen.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _checkingForUpdates = false;
  String? _updateCheckStatus;

  Future<void> _runManualUpdateCheck(AppStrings strings) async {
    setState(() {
      _checkingForUpdates = true;
      _updateCheckStatus = null;
    });

    ref.read(diagnosticLoggerProvider.notifier).info(
          'Updates',
          'User manually initiated opt-in update check.',
        );

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    setState(() {
      _checkingForUpdates = false;
      _updateCheckStatus = strings.isSi
          ? 'Print Helper v${AppConstants.appVersion} යාවත්කාලීනයි (Up to date). ඔබ ක්ලික් කළ විට පමණක් පරීක්ෂා කෙරේ.'
          : 'Print Helper v${AppConstants.appVersion} is up to date. Update checks run strictly when you click this button.';
    });
  }

  Future<void> _copyDiagnosticsToClipboard(
    BuildContext context,
    AppStrings strings,
  ) async {
    final logger = ref.read(diagnosticLoggerProvider.notifier);
    final report = logger.buildDiagnosticsReport(
      extraContext: <String, String>{
        'Language': strings.language.code,
        'ReduceMotion': ref.read(reduceMotionProvider).toString(),
        'HighContrast': ref.read(highContrastProvider).toString(),
        'TextScale':
            '${(ref.read(textScaleFactorProvider) * 100).round()}%',
      },
    );
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          strings.isSi
              ? 'දෝෂ වාර්තාව (Diagnostics Report) Clipboard වෙත පිටපත් කරන ලදී.'
              : 'Diagnostics report copied to clipboard.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final strings = AppStrings.of(lang);
    final themeMode = ref.watch(themeModeProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);
    final highContrast = ref.watch(highContrastProvider);
    final textScale = ref.watch(textScaleFactorProvider);
    final logs = ref.watch(diagnosticLoggerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.navSettings,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.isSi
                        ? 'භාෂාව, ප්‍රවේශ්‍යතාව (Accessibility), පෞද්ගලිකත්වය සහ දෝෂ වාර්තා'
                        : 'Language, Accessibility, Motion, Offline Privacy & Diagnostics',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => OnboardingDialog.show(context),
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: Text(
                  strings.isSi
                      ? 'හඳුන්වාදීමේ මාර්ගෝපදේශය (Onboarding)'
                      : 'Replay 3-Step Intro',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Language & Appearance Card
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(strings.isSi ? 'භාෂාව (Language)' : 'UI Language'),
                  subtitle: Text(
                    strings.isSi
                        ? 'English / සිංහල (Noto Sans Sinhala අකුරු සමඟ)'
                        : 'English / සිංහල (Bundled Noto Sans Sinhala)',
                  ),
                  trailing: SegmentedButton<AppLanguage>(
                    segments: const [
                      ButtonSegment(
                        value: AppLanguage.en,
                        label: Text('English'),
                      ),
                      ButtonSegment(
                        value: AppLanguage.si,
                        label: Text('සිංහල'),
                      ),
                    ],
                    selected: {lang},
                    onSelectionChanged: (selected) {
                      ref
                          .read(appLanguageProvider.notifier)
                          .setLanguage(selected.first);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.brightness_6_rounded),
                  title:
                      Text(strings.isSi ? 'තේමාව (Theme)' : 'Appearance Theme'),
                  subtitle: Text(
                    strings.isSi
                        ? 'පද්ධති තේමාව, ආලෝකමත් (Light) හෝ අඳුරු (Dark) තේමාව'
                        : 'System default, Light, or Dark workspace theme',
                  ),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(strings.isSi ? 'පද්ධතිය' : 'System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(strings.isSi ? 'ආලෝකමත්' : 'Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(strings.isSi ? 'අඳුරු' : 'Dark'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selected) {
                      ref.read(themeModeProvider.notifier).state =
                          selected.first;
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Accessibility & Motion System Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.motion_photos_off_rounded),
                    title: Text(
                      strings.isSi
                          ? 'සජීවිකරණ අඩු කරන්න (Reduce Motion)'
                          : 'Reduce Motion (Low-End PC & Accessibility Mode)',
                    ),
                    subtitle: Text(
                      strings.isSi
                          ? 'අඩු බලැති පරිගණකවල වේගවත් ක්‍රියාකාරිත්වය සඳහා සියලුම සජීවිකරණ ක්ෂණික කරයි.'
                          : 'Disables transition animations for instant 0ms response on low-end PCs.',
                    ),
                    value: reduceMotion,
                    onChanged: (val) => ref
                        .read(reduceMotionProvider.notifier)
                        .setReduceMotion(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.contrast_rounded),
                    title: Text(
                      strings.isSi
                          ? 'ඉහළ වෙනසක් සහිත තේමාව (High Contrast)'
                          : 'High Contrast Mode',
                    ),
                    subtitle: Text(
                      strings.isSi
                          ? 'පැහැදිලිව කියවීම සඳහා තද මායිම් සහ ඉහළ වර්ණ වෙනසක් ලබා දෙයි.'
                          : 'Sharp borders and maximum foreground/background contrast for visual accessibility.',
                    ),
                    value: highContrast,
                    onChanged: (val) => ref
                        .read(highContrastProvider.notifier)
                        .setHighContrast(val),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.format_size_rounded),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.isSi
                                    ? 'අකුරු විශාලත්වය (Text Scaling: ${(textScale * 100).round()}%)'
                                    : 'UI Text Scale (${(textScale * 100).round()}%)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Slider(
                                value: textScale,
                                min: 0.85,
                                max: 1.45,
                                divisions: 12,
                                label: '${(textScale * 100).round()}%',
                                onChanged: (val) => ref
                                    .read(textScaleFactorProvider.notifier)
                                    .setScale(val),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(textScaleFactorProvider.notifier)
                              .setScale(1.0),
                          child: Text(strings.isSi ? '100% යළි පිහිටුවන්න' : 'Reset 100%'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Privacy Guarantee, Opt-In Updates & Permissive Licenses Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.isSi
                              ? 'පෞද්ගලිකත්ව ප්‍රකාශය: ඔබගේ පරිගණකයෙන් කිසිවක් පිටතට නොයයි ("Nothing leaves your PC")'
                              : 'Privacy Statement: Nothing Leaves Your PC (100% Offline)',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.isSi
                        ? 'Print Helper 100% Offline ලෙස ක්‍රියා කරයි. ගිණුම් (Login), Cloud සේවා හෝ රහසිගත දත්ත රැස් කිරීම් (Telemetry) කිසිවක් නොමැත. ඔබගේ ලේඛන සහ මුද්‍රණ ඉතිහාසය ඔබගේ පරිගණකයේ පමණක් තැන්පත් වේ.'
                        : 'Print Helper operates 100% offline. There are no accounts, no cloud servers, and zero telemetry or analytics. All documents, presets, and print history remain strictly on your local machine.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _checkingForUpdates
                            ? null
                            : () => _runManualUpdateCheck(strings),
                        icon: _checkingForUpdates
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.system_update_alt_rounded,
                                size: 18),
                        label: Text(
                          strings.isSi
                              ? 'යාවත්කාලීන පරීක්ෂා කරන්න (Opt-in Update Check)'
                              : 'Check for Updates (User-Initiated Only)',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showPermissiveLicensesDialog(context, strings),
                        icon: const Icon(Icons.gavel_rounded, size: 18),
                        label: Text(
                          strings.isSi
                              ? 'විවෘත කේත බලපත්‍ර (MIT/BSD/Apache/OFL)'
                              : 'Third-Party Permissive Licenses',
                        ),
                      ),
                    ],
                  ),
                  if (_updateCheckStatus != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _updateCheckStatus!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Settings > AI Section ("Coming Soon", Disabled by Default, Strict Consent Model)
          const AiSettingsSectionCard(),
          const SizedBox(height: 16),

          // 5. Local Diagnostic Log Viewer & "Copy Diagnostics" Button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.terminal_rounded,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            strings.isSi
                                ? 'දෝෂ සහ ක්‍රියාකාරකම් සටහන (Diagnostic Log Viewer)'
                                : 'Local Diagnostic Log Viewer (${logs.length} entries)',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _copyDiagnosticsToClipboard(context, strings),
                            icon: const Icon(Icons.copy_all_rounded, size: 18),
                            label: Text(
                              strings.isSi
                                  ? 'වාර්තාව පිටපත් කරන්න (Copy Diagnostics)'
                                  : 'Copy Diagnostics',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => ref
                                .read(diagnosticLoggerProvider.notifier)
                                .clear(),
                            icon: const Icon(Icons.clear_all_rounded, size: 18),
                            label: Text(
                              strings.isSi ? 'මකන්න (Clear)' : 'Clear Log',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: logs.isEmpty
                        ? Center(
                            child: Text(
                              strings.isSi
                                  ? 'කිසිදු දෝෂ වාර්තාවක් නොමැත.'
                                  : 'No diagnostic log entries recorded.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final entry = logs[logs.length - 1 - index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: SelectableText(
                                  entry.formatLine(),
                                  style: const TextStyle(
                                    fontFamily: 'Consolas',
                                    fontFamilyFallback: ['NotoSansSinhala'],
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissiveLicensesDialog(
    BuildContext context,
    AppStrings strings,
  ) {
    const dependencies = <({String name, String version, String license})>[
      (name: 'flutter / dart sdk', version: '3.24+', license: 'BSD-3-Clause'),
      (name: 'flutter_riverpod', version: '^2.5.1', license: 'MIT'),
      (name: 'go_router', version: '^14.2.0', license: 'BSD-3-Clause'),
      (name: 'window_manager', version: '^0.4.2', license: 'MIT'),
      (name: 'desktop_drop', version: '^0.5.0', license: 'MIT'),
      (name: 'file_picker', version: '^8.1.2', license: 'MIT'),
      (name: 'pasteboard', version: '^0.3.0', license: 'MIT'),
      (name: 'flutter_animate', version: '^4.5.0', license: 'MIT'),
      (name: 'shared_preferences', version: '^2.3.2', license: 'BSD-3-Clause'),
      (name: 'path_provider', version: '^2.1.4', license: 'BSD-3-Clause'),
      (name: 'path', version: '^1.9.0', license: 'BSD-3-Clause'),
      (name: 'uuid', version: '^4.4.2', license: 'MIT'),
      (name: 'intl', version: '^0.19.0', license: 'BSD-3-Clause'),
      (name: 'pdf', version: '^3.11.1', license: 'Apache-2.0'),
      (name: 'ffi', version: '^2.1.3', license: 'BSD-3-Clause'),
      (name: 'win32', version: '^5.5.4', license: 'BSD-3-Clause'),
      (name: 'pdfrx (Google PDFium)', version: '^1.0.79', license: 'BSD-3-Clause / MIT'),
      (name: 'qpdf CLI (Isolated Child Process)', version: '11.9.1', license: 'Apache-2.0'),
      (name: 'Tesseract OCR + sin/eng LSTM Models', version: '5.4.0', license: 'Apache-2.0'),
      (name: 'LibreOffice Headless (Optional CLI)', version: '24.8.2', license: 'MPL-2.0'),
      (name: 'image', version: '^4.2.0', license: 'MIT'),
      (
        name: 'Google Noto Sans Sinhala',
        version: '2.004',
        license: 'SIL Open Font License 1.1 (OFL-1.1)'
      ),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          strings.isSi
              ? 'විවෘත කේත බලපත්‍ර (Permissive Open-Source Licenses)'
              : 'Third-Party Permissive Licenses (No GPL/AGPL)',
        ),
        content: SizedBox(
          width: 540,
          height: 380,
          child: ListView.separated(
            itemCount: dependencies.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, idx) {
              final dep = dependencies[idx];
              return ListTile(
                dense: true,
                title: Text(
                  '${dep.name} (${dep.version})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: Chip(
                  label: Text(
                    dep.license,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              showLicensePage(
                context: ctx,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
              );
            },
            child: Text(
              strings.isSi ? 'සම්පූර්ණ බලපත්‍ර පෙළ' : 'View Full License Texts',
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.isSi ? 'වසන්න (Close)' : 'Close'),
          ),
        ],
      ),
    );
  }
}
