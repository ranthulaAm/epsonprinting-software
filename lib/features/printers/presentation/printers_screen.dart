import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../services/printer/models/printer_models.dart';
import '../../workspace/domain/print_queue_item.dart';
import '../../workspace/presentation/queue_controller.dart';
import 'printers_controller.dart';
import 'widgets/add_network_printer_dialog.dart';
import 'widgets/epson_diagnostics_and_matrix_dialogs.dart';
import 'widgets/printer_card.dart';
import 'widgets/printer_health_check_dialog.dart';

enum _PrinterFilter {
  all,
  favorites,
  network,
  usb,
  virtual,
}

class PrintersScreen extends ConsumerStatefulWidget {
  const PrintersScreen({super.key});

  @override
  ConsumerState<PrintersScreen> createState() => _PrintersScreenState();
}

class _PrintersScreenState extends ConsumerState<PrintersScreen> {
  _PrinterFilter _activeFilter = _PrinterFilter.all;

  @override
  Widget build(BuildContext context) {
    final printersState = ref.watch(printersControllerProvider);
    final controller = ref.read(printersControllerProvider.notifier);
    final locale = ref.watch(localeProvider);
    final strings = AppStrings.of(locale);
    final colorScheme = Theme.of(context).colorScheme;

    final filteredPrinters = printersState.printers.where((p) {
      switch (_activeFilter) {
        case _PrinterFilter.all:
          return true;
        case _PrinterFilter.favorites:
          return p.isFavorite;
        case _PrinterFilter.network:
          return p.connectionType == PrinterConnectionType.network;
        case _PrinterFilter.usb:
          return p.connectionType == PrinterConnectionType.usb;
        case _PrinterFilter.virtual:
          return p.connectionType == PrinterConnectionType.virtual;
      }
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header & Actions Bar
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.navPrinters,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.isSi
                        ? 'මුද්‍රණ යන්ත්‍ර ${printersState.printers.length} ක් ස්ථාපනය කර ඇත (${printersState.readyCount} සූදානම්, ${printersState.offlineOrErrorCount} අවධානය යොමු කළ යුතුයි)'
                        : '${printersState.printers.length} printers detected from Windows Spooler (${printersState.readyCount} ready, ${printersState.offlineOrErrorCount} offline/attention)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => EpsonTestMatrixAndDevModeDialog(
                          isSinhala: strings.isSi,
                        ),
                      );
                    },
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: Text(
                      strings.isSi
                          ? 'Epson පරීක්ෂණ වගුව (Test Matrix)'
                          : 'Epson Test Matrix & DEVMODE',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: printersState.isRefreshing
                        ? null
                        : controller.refreshPrinters,
                    icon: printersState.isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      strings.isSi ? 'නැවත පරීක්ෂා කරන්න' : 'Refresh Spooler',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _openAddNetworkDialog(context, 1),
                    icon: const Icon(Icons.radar_rounded, size: 18),
                    label: Text(
                      strings.isSi ? 'LAN මගින් සොයන්න' : 'LAN Discovery',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openAddNetworkDialog(context, 0),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      strings.isSi
                          ? 'IP මුද්‍රණ යන්ත්‍රයක් එක් කරන්න'
                          : 'Add Network Printer (IP)',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // "Last Used Memory per File Type" Card
          _LastUsedMemoryBar(
            printers: printersState.printers,
            lastUsedMap: printersState.lastUsedByFileType,
            strings: strings,
            onAssign: (docType, systemName) =>
                controller.rememberPrinterForFileType(docType, systemName),
          ),
          const SizedBox(height: 14),

          // Filter Chips Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(strings.isSi ? 'සියල්ල (All)' : 'All Printers'),
                selected: _activeFilter == _PrinterFilter.all,
                onSelected: (_) =>
                    setState(() => _activeFilter = _PrinterFilter.all),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.star_rounded, size: 16),
                label: Text(strings.isSi ? 'ප්‍රියතම (Favorites)' : 'Favorites'),
                selected: _activeFilter == _PrinterFilter.favorites,
                onSelected: (_) =>
                    setState(() => _activeFilter = _PrinterFilter.favorites),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.lan_rounded, size: 16),
                label: Text(strings.isSi ? 'ජාල (LAN)' : 'Network / LAN'),
                selected: _activeFilter == _PrinterFilter.network,
                onSelected: (_) =>
                    setState(() => _activeFilter = _PrinterFilter.network),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.usb_rounded, size: 16),
                label: const Text('USB'),
                selected: _activeFilter == _PrinterFilter.usb,
                onSelected: (_) =>
                    setState(() => _activeFilter = _PrinterFilter.usb),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text(strings.isSi ? 'අතථ්‍ය (Virtual)' : 'Virtual PDF/XPS'),
                selected: _activeFilter == _PrinterFilter.virtual,
                onSelected: (_) =>
                    setState(() => _activeFilter = _PrinterFilter.virtual),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Printers List
          Expanded(
            child: filteredPrinters.isEmpty
                ? Center(
                    child: Text(
                      strings.isSi
                          ? 'ගැලපෙන මුද්‍රණ යන්ත්‍ර කිසිවක් හමු නොවීය.'
                          : 'No printers match the selected filter.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredPrinters.length,
                    itemBuilder: (context, index) {
                      final printer = filteredPrinters[index];
                      final rememberedTypes = printersState
                          .lastUsedByFileType.entries
                          .where((e) => e.value == printer.systemName)
                          .map((e) => e.key)
                          .toList();

                      return PrinterCard(
                        key: ValueKey(printer.systemName),
                        printer: printer,
                        strings: strings,
                        rememberedForTypes: rememberedTypes,
                        onToggleFavorite: () =>
                            controller.toggleFavorite(printer.systemName),
                        onEditNickname: () => _showNicknameDialog(
                          context,
                          printer,
                          controller,
                          strings,
                        ),
                        onRunHealthCheck: () async {
                          final report =
                              await controller.runHealthCheck(printer);
                          if (context.mounted) {
                            await showDialog<void>(
                              context: context,
                              builder: (_) => PrinterHealthCheckDialog(
                                report: report,
                                strings: strings,
                              ),
                            );
                          }
                        },
                        onSelectForWorkspace: () {
                          ref
                              .read(queueControllerProvider.notifier)
                              .selectPrinter(printer.systemName);
                          context.go('/print');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddNetworkDialog(
    BuildContext context,
    int initialTab,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AddNetworkPrinterDialog(initialTab: initialTab),
    );
  }

  Future<void> _showNicknameDialog(
    BuildContext context,
    PrinterDevice printer,
    PrintersController controller,
    AppStrings strings,
  ) async {
    final textCtrl = TextEditingController(text: printer.customNickname ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          strings.isSi
              ? 'කෙටි නමක් ලබා දෙන්න (Custom Nickname)'
              : 'Set Printer Nickname',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Name: ${printer.systemName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: strings.isSi ? 'කෙටි නම (Nickname)' : 'Nickname',
                hintText: 'e.g. Reception Color Printer',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          if (printer.hasNickname)
            TextButton(
              onPressed: () async {
                await controller.updateNickname(printer.systemName, null);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(strings.isSi ? 'ඉවත් කරන්න (Reset)' : 'Reset to Default'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.isSi ? 'අවලංගු කරන්න' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.updateNickname(
                printer.systemName,
                textCtrl.text,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(strings.isSi ? 'සුරකින්න' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _LastUsedMemoryBar extends StatelessWidget {
  const _LastUsedMemoryBar({
    required this.printers,
    required this.lastUsedMap,
    required this.strings,
    required this.onAssign,
  });

  final List<PrinterDevice> printers;
  final Map<PrintDocumentType, String> lastUsedMap;
  final AppStrings strings;
  final void Function(PrintDocumentType docType, String systemName) onAssign;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (printers.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.55),
        ),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.memory_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                strings.isSi
                    ? 'ගොනු වර්ගය අනුව අවසන් වරට භාවිතා කළ මුද්‍රණ යන්ත්‍රය:'
                    : 'Last-Used Memory per File Type:',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          _buildTypeSelector(
            context,
            docType: PrintDocumentType.pdf,
            label: 'PDF',
            icon: Icons.picture_as_pdf_rounded,
          ),
          _buildTypeSelector(
            context,
            docType: PrintDocumentType.image,
            label: strings.isSi ? 'රූප (Images)' : 'Images',
            icon: Icons.image_rounded,
          ),
          _buildTypeSelector(
            context,
            docType: PrintDocumentType.plainText,
            label: strings.isSi ? 'පෙළ (Text)' : 'Plain Text',
            icon: Icons.notes_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(
    BuildContext context, {
    required PrintDocumentType docType,
    required String label,
    required IconData icon,
  }) {
    final rememberedSysName = lastUsedMap[docType];
    final validSelection =
        printers.any((p) => p.systemName == rememberedSysName)
            ? rememberedSysName
            : printers.first.systemName;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 5),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 6),
        DropdownButton<String>(
          value: validSelection,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: printers
              .map(
                (p) => DropdownMenuItem(
                  value: p.systemName,
                  child: Text(
                    p.displayName,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              onAssign(docType, val);
            }
          },
        ),
      ],
    );
  }
}
