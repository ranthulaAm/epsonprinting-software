import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../workspace/domain/print_queue_item.dart';
import '../../workspace/presentation/queue_controller.dart';
import '../data/presets_persistence.dart';

class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsControllerProvider);
    final controller = ref.read(presetsControllerProvider.notifier);
    final queueController = ref.read(queueControllerProvider.notifier);
    final locale = ref.watch(localeProvider);
    final strings = AppStrings.of(locale);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.navPresets,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.isSi
                        ? 'එක් ක්ලික් කිරීමකින් මුද්‍රණ සැකසුම් යොදන්න හෝ ඔබගේම පෙර-සැකසුම් සුරකින්න.'
                        : 'Save and load one-click print configurations (e.g., "Double-sided B&W draft").',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () =>
                    _showCreateCustomPresetDialog(context, controller, strings),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  strings.isSi ? 'නව පෙර-සැකසුමක්' : 'Create Custom Preset',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final preset = presets[index];
                final s = preset.settings;
                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: preset.isBuiltIn
                                ? colorScheme.primaryContainer
                                : colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            preset.isBuiltIn
                                ? Icons.bookmarks_rounded
                                : Icons.person_pin_rounded,
                            color: preset.isBuiltIn
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    preset.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  if (preset.isBuiltIn)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Built-In',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                preset.description(locale.languageCode),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _PresetTag(label: s.paperSize),
                                  _PresetTag(
                                    label: s.isColor ? 'Color' : 'B&W',
                                  ),
                                  _PresetTag(
                                    label: switch (s.duplex) {
                                      DuplexMode.none => '1-Sided',
                                      DuplexMode.longEdge =>
                                        'Duplex (Long-Edge)',
                                      DuplexMode.shortEdge =>
                                        'Duplex (Short-Edge)',
                                    },
                                  ),
                                  _PresetTag(
                                    label: 'Quality: ${s.quality.name}',
                                  ),
                                  if (s.layoutMode == SheetLayoutMode.nUp)
                                    _PresetTag(
                                      label: '${s.pagesPerSheet}-Up Sheet',
                                    ),
                                  if (s.layoutMode == SheetLayoutMode.booklet)
                                    const _PresetTag(label: 'Booklet Fold'),
                                  if (s.watermarkText.isNotEmpty)
                                    _PresetTag(
                                      label: 'Watermark: ${s.watermarkText}',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!preset.isBuiltIn)
                          IconButton(
                            tooltip: 'Delete Preset',
                            onPressed: () => controller.deletePreset(preset.id),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: colorScheme.error,
                            ),
                          ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            queueController.applySettingsToAllItems(
                              preset.settings,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.isSi
                                      ? '"${preset.name}" පෙර-සැකසුම සක්‍රිය කරන ලදී.'
                                      : 'Applied preset "${preset.name}" to print queue.',
                                ),
                              ),
                            );
                            context.go('/print');
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            strings.isSi
                                ? 'පෝලිමට යොදන්න'
                                : 'Apply to Queue',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateCustomPresetDialog(
    BuildContext context,
    PresetsController controller,
    AppStrings strings,
  ) async {
    final nameCtrl = TextEditingController();
    DuplexMode duplex = DuplexMode.longEdge;
    bool isColor = false;
    PrintQualityMode quality = PrintQualityMode.draft;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            strings.isSi ? 'නව පෙර-සැකසුමක් සාදන්න' : 'Create Custom Preset',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Preset Name',
                  hintText: 'e.g. Office Invoice Draft',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DuplexMode>(
                value: duplex,
                decoration: const InputDecoration(
                  labelText: 'Duplex Mode',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: DuplexMode.none,
                    child: Text('Single-Sided'),
                  ),
                  DropdownMenuItem(
                    value: DuplexMode.longEdge,
                    child: Text('Double-Sided (Long Edge)'),
                  ),
                  DropdownMenuItem(
                    value: DuplexMode.shortEdge,
                    child: Text('Double-Sided (Short Edge)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setModalState(() => duplex = v);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Color Printing'),
                value: isColor,
                onChanged: (v) => setModalState(() => isColor = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.savePreset(
                  name: nameCtrl.text,
                  settings: FilePrintSettings(
                    duplex: duplex,
                    isColor: isColor,
                    quality: quality,
                  ),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save Preset'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTag extends StatelessWidget {
  const _PresetTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
