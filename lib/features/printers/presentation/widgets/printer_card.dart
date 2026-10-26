import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../services/printer/models/printer_models.dart';
import '../../../workspace/domain/print_queue_item.dart';

class PrinterCard extends StatelessWidget {
  const PrinterCard({
    super.key,
    required this.printer,
    required this.strings,
    required this.rememberedForTypes,
    required this.onToggleFavorite,
    required this.onEditNickname,
    required this.onRunHealthCheck,
    required this.onSelectForWorkspace,
  });

  final PrinterDevice printer;
  final AppStrings strings;
  final List<PrintDocumentType> rememberedForTypes;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEditNickname;
  final VoidCallback onRunHealthCheck;
  final VoidCallback onSelectForWorkspace;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusStyle = _statusVisuals(printer.status, strings, colorScheme);
    final caps = printer.capabilities;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon, Name/Nickname, Badges, Favorite, Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Type Icon Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusStyle.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _connectionIcon(printer.connectionType),
                    color: statusStyle.fgColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // Printer Title, System Name, Port/Location & Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            printer.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          // Edit Nickname Icon Button
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            tooltip: strings.isSi
                                ? 'කෙටි නමක් ලබා දෙන්න (Nickname)'
                                : 'Set custom nickname',
                            onPressed: onEditNickname,
                            icon: const Icon(Icons.edit_outlined),
                          ),

                          // Live Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusStyle.bgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusStyle.fgColor.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusStyle.icon,
                                  size: 13,
                                  color: statusStyle.fgColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  statusStyle.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: statusStyle.fgColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),

                          // Default Printer Badge
                          if (printer.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                strings.isSi ? 'පෙරනිමි (Default)' : 'Default',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),

                          // Remembered File Types Badges ("Last used for PDF")
                          ...rememberedForTypes.map(
                            (docType) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 12,
                                    color: colorScheme.onTertiaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    strings.isSi
                                        ? '${_docTypeLabel(docType)} සඳහා තෝරා ඇත'
                                        : 'Auto for ${_docTypeLabel(docType)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color:
                                              colorScheme.onTertiaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (printer.hasNickname)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'System Name: ${printer.systemName}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          _connectionLabel(printer.connectionType, strings),
                          'Port: ${printer.portName}',
                          if (printer.driverName.isNotEmpty)
                            'Driver: ${printer.driverName}',
                          if (printer.location.isNotEmpty)
                            'Location: ${printer.location}',
                          if (printer.activeJobsCount > 0)
                            '${printer.activeJobsCount} active job(s)',
                        ].join('  •  '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),

                // Right Action Buttons: Favorite Star, Health Check, Use Printer
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: strings.isSi
                          ? 'ප්‍රියතම මුද්‍රණ යන්ත්‍රය (Favorite)'
                          : 'Toggle Favorite',
                      onPressed: onToggleFavorite,
                      icon: Icon(
                        printer.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: printer.isFavorite
                            ? Colors.amber.shade700
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: onRunHealthCheck,
                      icon: Icon(
                        printer.isAvailableForPrinting
                            ? Icons.health_and_safety_outlined
                            : Icons.build_circle_outlined,
                        size: 18,
                      ),
                      label: Text(
                        strings.isSi ? 'තත්ත්ව පරීක්ෂාව' : 'Health Check',
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: onSelectForWorkspace,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        strings.isSi ? 'තෝරන්න' : 'Use Printer',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withOpacity(0.45),
            ),
            const SizedBox(height: 10),

            // Per-Printer Hardware Capabilities Strip
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _CapabilityPill(
                  icon: caps.supportsColor
                      ? Icons.palette_outlined
                      : Icons.contrast_rounded,
                  label: caps.supportsColor
                      ? (strings.isSi ? 'වර්ණ / කළු-සුදු (Color)' : 'Color & B&W')
                      : (strings.isSi ? 'කළු-සුදු පමණි (Mono)' : 'Monochrome Only'),
                ),
                _CapabilityPill(
                  icon: Icons.flip_rounded,
                  label: caps.supportsDuplex
                      ? (strings.isSi
                          ? 'දෙපැත්තම මුද්‍රණය (Duplex)'
                          : 'Duplex Supported')
                      : (strings.isSi
                          ? 'එක් පැත්තක් පමණි (Simplex)'
                          : 'Single-Sided Only'),
                ),
                _CapabilityPill(
                  icon: Icons.grid_on_rounded,
                  label: 'Max ${caps.maxResolution.label}',
                ),
                _CapabilityPill(
                  icon: Icons.inbox_rounded,
                  label:
                      '${strings.paperTrayLabel}: ${caps.trays.take(4).map((t) => t.name).join(', ')}',
                ),
                _CapabilityPill(
                  icon: Icons.straighten_rounded,
                  label:
                      '${strings.paperSizeLabel}: ${caps.paperSizes.take(5).map((s) => s.name).join(', ')}${caps.paperSizes.length > 5 ? ' +${caps.paperSizes.length - 5}' : ''}',
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppConstants.animFast, curve: AppConstants.animCurve)
        .slideY(
          begin: 0.03,
          end: 0,
          duration: AppConstants.animMedium,
          curve: AppConstants.animCurve,
        );
  }

  static String _docTypeLabel(PrintDocumentType type) {
    switch (type) {
      case PrintDocumentType.pdf:
        return 'PDF';
      case PrintDocumentType.image:
        return 'Images';
      case PrintDocumentType.plainText:
        return 'Text';
    }
  }

  static IconData _connectionIcon(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.usb:
        return Icons.usb_rounded;
      case PrinterConnectionType.network:
        return Icons.lan_rounded;
      case PrinterConnectionType.virtual:
        return Icons.picture_as_pdf_rounded;
      case PrinterConnectionType.local:
        return Icons.print_rounded;
    }
  }

  static String _connectionLabel(
    PrinterConnectionType type,
    AppStrings strings,
  ) {
    switch (type) {
      case PrinterConnectionType.usb:
        return strings.isSi ? 'USB මුද්‍රණ යන්ත්‍රය' : 'USB Printer';
      case PrinterConnectionType.network:
        return strings.isSi ? 'ජාල (LAN) මුද්‍රණ යන්ත්‍රය' : 'Network (LAN)';
      case PrinterConnectionType.virtual:
        return strings.isSi ? 'අතථ්‍ය (Virtual PDF/XPS)' : 'Virtual Printer';
      case PrinterConnectionType.local:
        return strings.isSi ? 'දේශීය (Local)' : 'Local Port';
    }
  }

  static ({Color bgColor, Color fgColor, IconData icon, String label})
      _statusVisuals(
    PrinterStatusType status,
    AppStrings strings,
    ColorScheme scheme,
  ) {
    switch (status) {
      case PrinterStatusType.ready:
        return (
          bgColor: Colors.green.withOpacity(0.14),
          fgColor: Colors.green.shade700,
          icon: Icons.check_circle_rounded,
          label: strings.isSi ? 'සූදානම් (Ready)' : 'Ready',
        );
      case PrinterStatusType.busy:
        return (
          bgColor: Colors.blue.withOpacity(0.14),
          fgColor: Colors.blue.shade700,
          icon: Icons.sync_rounded,
          label: strings.isSi ? 'මුද්‍රණය වෙමින් (Busy)' : 'Printing / Busy',
        );
      case PrinterStatusType.tonerLow:
        return (
          bgColor: Colors.orange.withOpacity(0.16),
          fgColor: Colors.orange.shade800,
          icon: Icons.opacity_rounded,
          label: strings.isSi ? 'ටෝනර් අඩුයි (Toner Low)' : 'Toner / Ink Low',
        );
      case PrinterStatusType.paused:
        return (
          bgColor: Colors.amber.withOpacity(0.18),
          fgColor: Colors.amber.shade900,
          icon: Icons.pause_circle_filled_rounded,
          label: strings.isSi ? 'නවතා ඇත (Paused)' : 'Paused',
        );
      case PrinterStatusType.outOfPaper:
        return (
          bgColor: scheme.errorContainer,
          fgColor: scheme.onErrorContainer,
          icon: Icons.SimCardAlert_outlined,
          label: strings.isSi ? 'කඩදාසි අවසන් (Out of Paper)' : 'Out of Paper',
        );
      case PrinterStatusType.paperJam:
        return (
          bgColor: scheme.errorContainer,
          fgColor: scheme.onErrorContainer,
          icon: Icons.report_problem_rounded,
          label: strings.isSi ? 'කඩදාසි සිරවී ඇත (Paper Jam)' : 'Paper Jam',
        );
      case PrinterStatusType.doorOpen:
        return (
          bgColor: scheme.errorContainer,
          fgColor: scheme.onErrorContainer,
          icon: Icons.sensor_door_outlined,
          label: strings.isSi ? 'පියන විවෘතයි (Door Open)' : 'Cover Open',
        );
      case PrinterStatusType.offline:
        return (
          bgColor: scheme.surfaceContainerHighest,
          fgColor: scheme.onSurfaceVariant,
          icon: Icons.cloud_off_rounded,
          label: strings.isSi ? 'සම්බන්ධ නැත (Offline)' : 'Offline',
        );
      case PrinterStatusType.error:
        return (
          bgColor: scheme.errorContainer,
          fgColor: scheme.onErrorContainer,
          icon: Icons.error_outline_rounded,
          label: strings.isSi ? 'දෝෂයක් (Error)' : 'Hardware Error',
        );
    }
  }
}

class _CapabilityPill extends StatelessWidget {
  const _CapabilityPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
