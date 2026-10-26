import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_motion.dart';

/// 3-screen first-run onboarding modal designed for zero-friction simplicity:
/// 1. Drop Any File Anywhere
/// 2. Pick Any Local, USB, or LAN Printer Offline
/// 3. Print with Confidence (Live Preview, Presets & Sinhala Support)
class OnboardingDialog extends ConsumerStatefulWidget {
  const OnboardingDialog({super.key});

  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final completed = ref.read(onboardingCompletedProvider);
    if (completed) return;
    await show(context);
  }

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const OnboardingDialog(),
    );
  }

  @override
  ConsumerState<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends ConsumerState<OnboardingDialog> {
  int _currentStep = 0;

  void _completeOnboarding() {
    ref.read(onboardingCompletedProvider.notifier).markCompleted();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final strings = AppStrings.of(lang);
    final reduceMotion = ref.watch(reduceMotionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final steps = <_OnboardingSlideData>[
      _OnboardingSlideData(
        icon: Icons.upload_file_rounded,
        badge: strings.isSi ? 'පියවර 1 / 3' : 'Step 1 of 3',
        title: strings.isSi
            ? '1. ඕනෑම ගොනුවක් ඇද දමන්න (Drop Any File)'
            : '1. Drop Files Anywhere in the Window',
        subtitle: strings.isSi
            ? 'PDF, රූප (PNG/JPG/TIFF/WebP), සරල පෙළ (.txt) හෝ Markdown (.md) ගොනු කෙලින්ම කවුළුවට ඇද දමන්න, Clipboard වෙතින් Paste කරන්න (Ctrl+V), හෝ Windows Explorer හරහා විවෘත කරන්න.'
            : 'Drag & drop PDFs, images (PNG/JPG/BMP/TIFF/WebP), plain text (.txt), or Markdown (.md) anywhere in the window, paste with Ctrl+V, or right-click in Windows Explorer.',
        highlights: strings.isSi
            ? const [
                'ගොනු කිහිපයක් එකවර ඇතුළත් කර පෙළගැස්විය හැක (Reorderable Queue)',
                'පිටු 500+ විශාල PDF ගොනු පවා තත්පරයකින් විවෘත වේ',
                'සිංහල (Noto Sans Sinhala) සහ ඉංග්‍රීසි පූර්ණ සහාය',
              ]
            : const [
                'Drop single or batch files with instant page count & thumbnail preview',
                'Opens 500+ page PDFs smoothly without freezing the UI',
                'Full English & සිංහල (Noto Sans Sinhala) typography built in',
              ],
      ),
      _OnboardingSlideData(
        icon: Icons.print_rounded,
        badge: strings.isSi ? 'පියවර 2 / 3' : 'Step 2 of 3',
        title: strings.isSi
            ? '2. මුද්‍රණ යන්ත්‍රය තෝරන්න (100% Offline)'
            : '2. Pick Your USB, Local, or LAN Printer',
        subtitle: strings.isSi
            ? 'අන්තර්ජාලය නොමැතිව වුවද ඔබගේ සියලුම USB සහ LAN ජාලගත මුද්‍රණ යන්ත්‍ර ස්වයංක්‍රීයව හඳුනා ගනී. එකවර මුද්‍රණ යන්ත්‍ර කිහිපයකට (Broadcast / Load Balance) මුද්‍රණය කළ හැක.'
            : 'Automatically detects Windows USB, local, and LAN network printers (IPP / JetDirect 9100) with live status badges — working 100% offline without internet.',
        highlights: strings.isSi
            ? const [
                'මුද්‍රණ යන්ත්‍රයේ සජීවී තත්ත්වය (Ready, Offline, Out of Paper) පෙන්වයි',
                'එක් ගොනුවක් මුද්‍රණ යන්ත්‍ර කිහිපයකට එකවර යැවීමේ පහසුකම',
                'මුද්‍රණ යන්ත්‍රයක් ක්‍රියාවිරහිත වුවහොත් වෙනත් යන්ත්‍රයකට මාරු කිරීමේ හැකියාව',
              ]
            : const [
                'Live Windows Spooler health checks with plain-language troubleshooting',
                'Broadcast to multiple printers at once or split batches for load balancing',
                'Automatic fallback prompt if a printer goes offline mid-job',
              ],
      ),
      _OnboardingSlideData(
        icon: Icons.verified_rounded,
        badge: strings.isSi ? 'පියවර 3 / 3' : 'Step 3 of 3',
        title: strings.isSi
            ? '3. සජීවී පෙරදසුන බලා විශ්වාසයෙන් මුද්‍රණය කරන්න'
            : '3. Preview Live & Print with Confidence',
        subtitle: strings.isSi
            ? 'දෙපස මුද්‍රණය (Duplex), Booklet, Poster, දිය සලකුණු (Watermarks) සහ පිටු අංක සජීවීව පරීක්ෂා කර එක ක්ලික් කිරීමකින් මුද්‍රණය කරන්න. ඔබගේ කිසිදු දත්තයක් පරිගණකයෙන් පිටතට නොයයි.'
            : 'Inspect real-time Duplex flip diagrams, N-Up/Booklet/Poster layouts, and Sinhala-capable watermarks before printing. 100% private — nothing ever leaves your PC.',
        highlights: strings.isSi
            ? const [
                'Ctrl+O (විවෘත කරන්න), Ctrl+P (මුද්‍රණය කරන්න), Ctrl+Shift+P (පෙරදසුන)',
                'නිතර භාවිතා කරන සැකසුම් Presets ලෙස සුරැකිය හැක',
                '100% Offline • ගිණුම් අවශ්‍ය නැත • දත්ත රැස් නොකරයි',
              ]
            : const [
                'Keyboard shortcuts: Ctrl+O Open, Ctrl+P Print, Ctrl+Shift+P Live Preview',
                'Save 1-click Presets (e.g., "Double-sided B&W Draft")',
                '100% Offline • No Login • No Cloud • Zero Telemetry',
              ],
      ),
    ];

    final slide = steps[_currentStep];

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const _NextSlideIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            const _PrevSlideIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const _SkipOnboardingIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NextSlideIntent: CallbackAction<_NextSlideIntent>(
            onInvoke: (_) {
              if (_currentStep < steps.length - 1) {
                setState(() => _currentStep++);
              } else {
                _completeOnboarding();
              }
              return null;
            },
          ),
          _PrevSlideIntent: CallbackAction<_PrevSlideIntent>(
            onInvoke: (_) {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              }
              return null;
            },
          ),
          _SkipOnboardingIntent: CallbackAction<_SkipOnboardingIntent>(
            onInvoke: (_) {
              _completeOnboarding();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 500),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Row: Badge + Language Switcher + Skip
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            slide.badge,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () => ref
                                  .read(appLanguageProvider.notifier)
                                  .toggle(),
                              icon: const Icon(
                                Icons.translate_rounded,
                                size: 16,
                              ),
                              label: Text(
                                strings.isSi ? 'English' : 'සිංහල',
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: _completeOnboarding,
                              child: Text(
                                strings.isSi ? 'මඟ හරින්න (Skip)' : 'Skip',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Slide Body with Motion-aware transition
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.duration(
                          AppMotion.normal,
                          reduceMotion: reduceMotion,
                        ),
                        switchInCurve: AppMotion.enterCurve,
                        switchOutCurve: AppMotion.exitCurve,
                        child: Column(
                          key: ValueKey<int>(_currentStep),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer
                                        .withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    slide.icon,
                                    size: 30,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    slide.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              slide.subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            ...slide.highlights.map(
                              (point) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        point,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Controls: Step Dots + Back / Next / Get Started
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: List.generate(steps.length, (idx) {
                            final active = idx == _currentStep;
                            return AnimatedContainer(
                              duration: AppMotion.duration(
                                AppMotion.fast,
                                reduceMotion: reduceMotion,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              width: active ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }),
                        ),
                        Row(
                          children: [
                            if (_currentStep > 0)
                              OutlinedButton(
                                onPressed: () =>
                                    setState(() => _currentStep--),
                                child: Text(
                                  strings.isSi ? 'ආපසු (Back)' : 'Back',
                                ),
                              ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: () {
                                if (_currentStep < steps.length - 1) {
                                  setState(() => _currentStep++);
                                } else {
                                  _completeOnboarding();
                                }
                              },
                              icon: Icon(
                                _currentStep < steps.length - 1
                                    ? Icons.arrow_forward_rounded
                                    : Icons.rocket_launch_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _currentStep < steps.length - 1
                                    ? (strings.isSi ? 'ඊළඟ (Next)' : 'Next')
                                    : (strings.isSi
                                        ? 'ආරම්භ කරන්න (Get Started)'
                                        : 'Get Started'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.highlights,
  });

  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;
  final List<String> highlights;
}

class _NextSlideIntent extends Intent {
  const _NextSlideIntent();
}

class _PrevSlideIntent extends Intent {
  const _PrevSlideIntent();
}

class _SkipOnboardingIntent extends Intent {
  const _SkipOnboardingIntent();
}
