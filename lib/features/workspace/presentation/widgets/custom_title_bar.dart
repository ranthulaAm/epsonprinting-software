import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/integration/global_command_palette_and_recent_files.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class CustomTitleBar extends ConsumerWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = AppStrings.of(locale);
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.print_rounded,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          // Draggable window area
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                if (Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS) {
                  windowManager.startDragging();
                }
              },
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Row(
                children: [
                  Text(
                    strings.appTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 12,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          strings.offlineBadge,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Global Tool Search & Command Palette (Ctrl+K) Pill
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              avatar: const Icon(Icons.search_rounded, size: 15),
              label: Text(
                strings.isSi ? 'සොයන්න (Ctrl+K)' : 'Search Tools (Ctrl+K)',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () => GlobalCommandPaletteDialog.show(context),
            ),
          ),
          // Language Toggle (EN / සිංහල)
          Tooltip(
            message: strings.toggleLangTooltip,
            child: TextButton.icon(
              onPressed: () {
                ref.read(appLanguageProvider.notifier).toggle();
              },
              icon: const Icon(Icons.translate_rounded, size: 16),
              label: Text(
                locale.languageCode == 'en' ? 'සිංහල' : 'EN',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // Theme Toggle (Light / Dark)
          IconButton(
            tooltip: strings.toggleThemeTooltip,
            iconSize: 18,
            onPressed: () {
              final next = themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              ref.read(themeModeProvider.notifier).state = next;
            },
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          const VerticalDivider(width: 8, indent: 10, endIndent: 10),
          // Native Window Controls
          _WindowCaptionButton(
            icon: Icons.remove_rounded,
            tooltip: 'Minimize',
            onPressed: () => windowManager.minimize(),
          ),
          _WindowCaptionButton(
            icon: Icons.crop_square_rounded,
            tooltip: 'Maximize / Restore',
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowCaptionButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            isClose: true,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _WindowCaptionButton extends StatefulWidget {
  const _WindowCaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<_WindowCaptionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = !_hovering
        ? Colors.transparent
        : (widget.isClose
            ? const Color(0xFFE81123)
            : colorScheme.onSurface.withOpacity(0.08));
    final fgColor = _hovering && widget.isClose
        ? Colors.white
        : colorScheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 44,
          height: 44,
          color: bgColor,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 16, color: fgColor),
        ),
      ),
    );
  }
}
