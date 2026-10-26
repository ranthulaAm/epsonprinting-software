import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../services/printer/models/printer_models.dart';

class PrinterHealthCheckDialog extends StatelessWidget {
  const PrinterHealthCheckDialog({
    super.key,
    required this.report,
    required this.strings,
  });

  final PrinterHealthReport report;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lang = strings.locale.languageCode;

    final (Color bannerBg, Color bannerFg, IconData bannerIcon) =
        switch (report.severity) {
      HealthSeverity.healthy => (
          Colors.green.withOpacity(0.14),
          Colors.green.shade800,
          Icons.verified_rounded,
        ),
      HealthSeverity.warning => (
          Colors.orange.withOpacity(0.16),
          Colors.orange.shade900,
          Icons.warning_amber_rounded,
        ),
      HealthSeverity.critical => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          Icons.error_outline_rounded,
        ),
    };

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.health_and_safety_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.isSi
                  ? 'මුද්‍රණ යන්ත්‍ර තත්ත්ව පරීක්ෂාව — ${report.printerName}'
                  : 'Printer Health Check — ${report.printerName}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Plain-language headline banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bannerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(bannerIcon, size: 28, color: bannerFg),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        report.headline(lang),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: bannerFg,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Diagnostic Indicators Row
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DiagnosticBadge(
                    label: strings.isSi ? 'Windows Spooler' : 'Windows Spooler',
                    value: report.spoolerOk
                        ? (strings.isSi ? 'ක්‍රියාත්මකයි' : 'Running')
                        : (strings.isSi ? 'නැවතී ඇත' : 'Stopped'),
                    isOk: report.spoolerOk,
                  ),
                  _DiagnosticBadge(
                    label:
                        strings.isSi ? 'සම්බන්ධතාවය (Port)' : 'Port / Network',
                    value: report.portReachable
                        ? (report.pingLatencyMs != null
                            ? 'Reachable (${report.pingLatencyMs}ms)'
                            : (strings.isSi ? 'සම්බන්ධයි' : 'Connected'))
                        : (strings.isSi ? 'ප්‍රතිචාර නැත' : 'Unreachable'),
                    isOk: report.portReachable,
                  ),
                  _DiagnosticBadge(
                    label:
                        strings.isSi ? 'පෝලිමේ ඇති ගොනු' : 'Spooler Queue Jobs',
                    value: '${report.activeJobsCount}',
                    isOk: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                strings.isSi
                    ? 'විසඳුම් සහ පියවර (Troubleshooting Guide):'
                    : 'Plain-Language Troubleshooting Steps:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),

              ...report.steps.map(
                (step) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title(lang),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.detail(lang),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
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
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.isSi ? 'හරි (Close)' : 'Done'),
        ),
      ],
    );
  }
}

class _DiagnosticBadge extends StatelessWidget {
  const _DiagnosticBadge({
    required this.label,
    required this.value,
    required this.isOk,
  });

  final String label;
  final String value;
  final bool isOk;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: isOk ? Colors.green.shade700 : colorScheme.error,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
