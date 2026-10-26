import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../domain/print_queue_item.dart';

class QueueItemCard extends StatelessWidget {
  const QueueItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.strings,
    required this.onRemove,
    required this.onToggleExpand,
    required this.onUpdateSettings,
    this.onOpenLivePreview,
  });

  final PrintQueueItem item;
  final int index;
  final AppStrings strings;
  final VoidCallback onRemove;
  final VoidCallback onToggleExpand;
  final ValueChanged<FilePrintSettings> onUpdateSettings;
  final VoidCallback? onOpenLivePreview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = item.settings;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Drag Handle for ReorderableListView
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: strings.reorderHint,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Thumbnail Preview (PDF / Image / Plain Text)
                _DocumentThumbnail(item: item),
                const SizedBox(width: 14),

                // File Name & Metadata Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _BadgeChip(
                            icon: _iconForType(item.documentType),
                            label: item.extension.toUpperCase(),
                            color: colorScheme.primaryContainer,
                            textColor: colorScheme.onPrimaryContainer,
                          ),
                          _BadgeChip(
                            icon: Icons.description_outlined,
                            label:
                                '${item.pageCount} ${item.pageCount == 1 ? strings.pageLabel : strings.pagesLabel}',
                            color: colorScheme.surfaceContainerHighest,
                            textColor: colorScheme.onSurfaceVariant,
                          ),
                          _BadgeChip(
                            icon: Icons.sd_storage_outlined,
                            label: item.formattedFileSize,
                            color: colorScheme.surfaceContainerHighest,
                            textColor: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Quick Per-File Controls (Copies + Color/B&W)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Copies stepper
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            onPressed: settings.copies > 1
                                ? () => onUpdateSettings(
                                      settings.copyWith(
                                        copies: settings.copies - 1,
                                      ),
                                    )
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '${settings.copies} ${strings.copiesLabel}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            onPressed: () => onUpdateSettings(
                              settings.copyWith(copies: settings.copies + 1),
                            ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Color vs B&W quick chip
                    FilterChip(
                      label: Text(
                        settings.isColor ? strings.colorLabel : strings.bwLabel,
                      ),
                      selected: settings.isColor,
                      onSelected: (val) => onUpdateSettings(
                        settings.copyWith(isColor: val),
                      ),
                      avatar: Icon(
                        settings.isColor
                            ? Icons.palette_outlined
                            : Icons.contrast_rounded,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Open Live Print Preview & Full Settings Dialog
                    if (onOpenLivePreview != null)
                      OutlinedButton.icon(
                        onPressed: onOpenLivePreview,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.preview_rounded, size: 16),
                        label: Text(
                          strings.isSi ? 'පෙරදසුන' : 'Preview & Setup',
                        ),
                      ),
                    const SizedBox(width: 4),

                    // Expand Per-File Advanced Settings
                    IconButton(
                      tooltip: strings.advancedOptions,
                      onPressed: onToggleExpand,
                      icon: AnimatedRotation(
                        turns: item.isSettingsExpanded ? 0.5 : 0.0,
                        duration: AppConstants.animFast,
                        curve: AppConstants.animCurve,
                        child: const Icon(Icons.tune_rounded),
                      ),
                    ),

                    // Remove File Button
                    IconButton(
                      tooltip: 'Remove file',
                      onPressed: onRemove,
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Collapsible Per-File Advanced Settings Drawer (150-300ms smooth animation)
          AnimatedSize(
            duration: AppConstants.animMedium,
            curve: AppConstants.animCurve,
            alignment: Alignment.topCenter,
            child: item.isSettingsExpanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(60, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer.withOpacity(0.6),
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outlineVariant.withOpacity(0.4),
                        ),
                      ),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Orientation
                        _SettingDropdown<PageOrientation>(
                          label: 'Orientation',
                          value: settings.orientation,
                          items: [
                            DropdownMenuItem(
                              value: PageOrientation.portrait,
                              child: Text(strings.orientationPortrait),
                            ),
                            DropdownMenuItem(
                              value: PageOrientation.landscape,
                              child: Text(strings.orientationLandscape),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              onUpdateSettings(
                                settings.copyWith(orientation: val),
                              );
                            }
                          },
                        ),

                        // Duplex (Two-sided)
                        _SettingDropdown<DuplexMode>(
                          label: 'Duplex',
                          value: settings.duplex,
                          items: [
                            DropdownMenuItem(
                              value: DuplexMode.none,
                              child: Text(strings.duplexNone),
                            ),
                            DropdownMenuItem(
                              value: DuplexMode.longEdge,
                              child: Text(strings.duplexLongEdge),
                            ),
                            DropdownMenuItem(
                              value: DuplexMode.shortEdge,
                              child: Text(strings.duplexShortEdge),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              onUpdateSettings(settings.copyWith(duplex: val));
                            }
                          },
                        ),

                        // Paper Size
                        _SettingDropdown<String>(
                          label: strings.paperSizeLabel,
                          value: settings.paperSize,
                          items: const [
                            DropdownMenuItem(value: 'A4', child: Text('A4')),
                            DropdownMenuItem(
                              value: 'Letter',
                              child: Text('Letter'),
                            ),
                            DropdownMenuItem(
                              value: 'Legal',
                              child: Text('Legal'),
                            ),
                            DropdownMenuItem(value: 'A3', child: Text('A3')),
                            DropdownMenuItem(value: 'A5', child: Text('A5')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              onUpdateSettings(
                                settings.copyWith(paperSize: val),
                              );
                            }
                          },
                        ),

                        // Paper Tray
                        _SettingDropdown<String>(
                          label: strings.paperTrayLabel,
                          value: settings.paperTray,
                          items: const [
                            DropdownMenuItem(
                              value: 'Auto Select',
                              child: Text('Auto Select'),
                            ),
                            DropdownMenuItem(
                              value: 'Tray 1',
                              child: Text('Tray 1 (Main)'),
                            ),
                            DropdownMenuItem(
                              value: 'Tray 2',
                              child: Text('Tray 2'),
                            ),
                            DropdownMenuItem(
                              value: 'Manual Feed',
                              child: Text('Manual Feed'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              onUpdateSettings(
                                settings.copyWith(paperTray: val),
                              );
                            }
                          },
                        ),

                        // Page Range
                        SizedBox(
                          width: 170,
                          child: TextFormField(
                            initialValue: settings.pageRange,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: strings.pageRangeAll,
                              hintText: 'e.g. 1-3, 5',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (val) => onUpdateSettings(
                              settings.copyWith(pageRange: val.trim()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: AppConstants.animFast, curve: AppConstants.animCurve)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: AppConstants.animMedium,
          curve: AppConstants.animCurve,
        );
  }

  IconData _iconForType(PrintDocumentType type) {
    switch (type) {
      case PrintDocumentType.pdf:
        return Icons.picture_as_pdf_rounded;
      case PrintDocumentType.image:
        return Icons.image_rounded;
      case PrintDocumentType.plainText:
        return Icons.notes_rounded;
    }
  }
}

class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({required this.item});

  final PrintQueueItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 54,
      height: 68,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildInner(context, colorScheme),
    );
  }

  Widget _buildInner(BuildContext context, ColorScheme colorScheme) {
    if (item.thumbnailBytes != null && item.thumbnailBytes!.isNotEmpty) {
      return Image.memory(
        item.thumbnailBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(colorScheme),
      );
    }
    if (item.documentType == PrintDocumentType.plainText &&
        item.textPreviewSnippet != null) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Text(
          item.textPreviewSnippet!,
          maxLines: 6,
          overflow: TextOverflow.fade,
          style: const TextStyle(
            fontSize: 6.5,
            height: 1.2,
          ),
        ),
      );
    }
    return _fallbackIcon(colorScheme);
  }

  Widget _fallbackIcon(ColorScheme colorScheme) {
    final IconData icon;
    switch (item.documentType) {
      case PrintDocumentType.pdf:
        icon = Icons.picture_as_pdf_rounded;
      case PrintDocumentType.image:
        icon = Icons.image_rounded;
      case PrintDocumentType.plainText:
        icon = Icons.article_rounded;
    }
    return Center(
      child: Icon(icon, size: 26, color: colorScheme.primary),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SettingDropdown<T> extends StatelessWidget {
  const _SettingDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 8),
        DropdownButton<T>(
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
