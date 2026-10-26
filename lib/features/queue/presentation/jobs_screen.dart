import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../services/printer/models/printer_models.dart';
import '../../presets/data/presets_persistence.dart';
import '../../printers/presentation/printers_controller.dart';
import '../domain/print_job_models.dart';
import 'job_queue_controller.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(jobQueueControllerProvider);
    final controller = ref.read(jobQueueControllerProvider.notifier);
    final printersState = ref.watch(printersControllerProvider);
    final presets = ref.watch(presetsControllerProvider);
    final locale = ref.watch(localeProvider);
    final strings = AppStrings.of(locale);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header & Desktop Notification Toast Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.navJobs,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.isSi
                        ? 'මුද්‍රණ පෝලිම, Windows Spooler, මුද්‍රණ ඉතිහාසය (CSV) සහ Hot Folder ස්වයංක්‍රීය මුද්‍රණය'
                        : 'Batch job queue, live Windows Spooler monitor, local print history (CSV), and Hot Folder watcher.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              if (jobState.latestNotification != null)
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: jobState.latestNotification!.isError
                          ? colorScheme.errorContainer
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          jobState.latestNotification!.isError
                              ? Icons.notifications_active_rounded
                              : Icons.check_circle_rounded,
                          size: 18,
                          color: jobState.latestNotification!.isError
                              ? colorScheme.onErrorContainer
                              : colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                jobState.latestNotification!.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: jobState.latestNotification!.isError
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onPrimaryContainer,
                                ),
                              ),
                              Text(
                                jobState.latestNotification!.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: jobState.latestNotification!.isError
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          onPressed: controller.dismissLatestNotification,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: Badge(
                  isLabelVisible: jobState.runningOrQueuedCount > 0,
                  label: Text('${jobState.runningOrQueuedCount}'),
                  child: const Icon(Icons.playlist_play_rounded),
                ),
                text: strings.isSi
                    ? 'සක්‍රිය මුද්‍රණ පෝලිම'
                    : 'Active Batch Queue (${jobState.activeJobs.length})',
              ),
              Tab(
                icon: const Icon(Icons.dns_rounded),
                text: strings.isSi
                    ? 'Windows Spooler පෝලිම'
                    : 'Windows Spooler Monitor',
              ),
              Tab(
                icon: const Icon(Icons.history_rounded),
                text: strings.isSi
                    ? 'මුද්‍රණ ඉතිහාසය (History & CSV)'
                    : 'Print History (${jobState.historyJobs.length})',
              ),
              Tab(
                icon: Icon(
                  Icons.folder_special_rounded,
                  color: jobState.hotFolderConfig.enabled
                      ? Colors.green
                      : null,
                ),
                text: strings.isSi
                    ? 'Hot Folder (ස්වයංක්‍රීය මුද්‍රණය)'
                    : 'Hot Folder Auto-Print',
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Active Print Helper Queue & Automatic Offline Fallback
                _ActiveQueueTab(
                  jobState: jobState,
                  controller: controller,
                  printers: printersState.printers,
                  strings: strings,
                ),

                // TAB 2: Live Windows Spooler Monitor
                _WindowsSpoolerTab(
                  jobState: jobState,
                  controller: controller,
                  printers: printersState.printers,
                  strings: strings,
                ),

                // TAB 3: Local Print History (Search, Reprint, CSV Export, Auto-Clear)
                _PrintHistoryTab(
                  jobState: jobState,
                  controller: controller,
                  searchController: _searchCtrl,
                  strings: strings,
                ),

                // TAB 4: Hot Folder Auto-Print Watcher
                _HotFolderTab(
                  jobState: jobState,
                  controller: controller,
                  printers: printersState.printers,
                  presets: presets,
                  strings: strings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveQueueTab extends StatelessWidget {
  const _ActiveQueueTab({
    required this.jobState,
    required this.controller,
    required this.printers,
    required this.strings,
  });

  final JobQueueState jobState;
  final JobQueueController controller;
  final List<PrinterDevice> printers;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final waitingFallback = jobState.jobsAwaitingFallback;
    final readyAlternativePrinters =
        printers.where((p) => p.isAvailableForPrinting).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Batch Controls Toolbar
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: jobState.isBatchPaused
                      ? controller.resumeAllBatch
                      : controller.pauseAllBatch,
                  icon: Icon(
                    jobState.isBatchPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                  label: Text(
                    jobState.isBatchPaused
                        ? (strings.isSi ? 'නැවත අරඹන්න' : 'Resume Batch')
                        : (strings.isSi ? 'තාවකාලිකව නවත්වන්න' : 'Pause Batch'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: jobState.activeJobs.isNotEmpty
                      ? controller.cancelAllBatch
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(
                    strings.isSi ? 'සියල්ල අවලංගු කරන්න' : 'Cancel All',
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: controller.clearCompletedActiveJobs,
              icon: const Icon(Icons.cleaning_services_outlined, size: 17),
              label: Text(
                strings.isSi
                    ? 'අවසන් වූ ගොනු ඉවත් කරන්න'
                    : 'Clear Finished Jobs',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Automatic Fallback Banner if a Printer Went Offline
        if (waitingFallback.isNotEmpty && readyAlternativePrinters.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swap_calls_rounded,
                  color: colorScheme.onErrorContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.isSi
                            ? 'මුද්‍රණ යන්ත්‍රය Offline තත්ත්වයේ පවතී — වෙනත් මුද්‍රණ යන්ත්‍රයකට යොමු කරන්නද?'
                            : 'Automatic Printer Fallback: ${waitingFallback.length} job(s) paused because target printer is offline.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.isSi
                            ? 'එක් ක්ලික් කිරීමකින් සූදානම් මුද්‍රණ යන්ත්‍රයකට මාරු කරන්න:'
                            : 'Send waiting job(s) to an online printer right now:',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: readyAlternativePrinters.take(2).map((alt) {
                    return FilledButton.icon(
                      onPressed: () =>
                          controller.rerouteAllFallbackJobs(alt.systemName),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: Text('Send to ${alt.displayName}'),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

        // Active Jobs List
        Expanded(
          child: jobState.activeJobs.isEmpty
              ? Center(
                  child: Text(
                    strings.isSi
                        ? 'දැනට ක්‍රියාත්මක වන මුද්‍රණ කටයුතු කිසිවක් නොමැත.'
                        : 'No active print jobs. Drop files on the Print tab and press Print Now.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: jobState.activeJobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final job = jobState.activeJobs[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _statusIcon(job.status),
                                  color: _statusColor(job.status, colorScheme),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        job.fileName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Printer: ${job.targetPrinterDisplayName}  •  '
                                        '${job.pagesPrinted}/${job.effectiveTotalPages} page(s)  •  '
                                        'Status: ${job.status.name.toUpperCase()}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      if (job.errorMessage != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            job.errorMessage!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.error,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Per-Job Controls (Fallback Switch, Pause/Resume, Retry, Cancel)
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    if (job.status ==
                                            PrintJobStatus.awaitingFallback &&
                                        job.fallbackSuggestedPrinter != null)
                                      FilledButton.tonalIcon(
                                        onPressed: () => controller
                                            .rerouteJobToFallbackPrinter(
                                          jobId: job.id,
                                          newPrinterSystemName:
                                              job.fallbackSuggestedPrinter!,
                                        ),
                                        icon: const Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'Use ${job.fallbackSuggestedPrinter}',
                                        ),
                                      ),
                                    if (job.status == PrintJobStatus.queued)
                                      IconButton(
                                        tooltip: 'Pause Job',
                                        onPressed: () =>
                                            controller.pauseJob(job.id),
                                        icon: const Icon(Icons.pause_rounded),
                                      ),
                                    if (job.status == PrintJobStatus.paused)
                                      IconButton(
                                        tooltip: 'Resume Job',
                                        onPressed: () =>
                                            controller.resumeJob(job.id),
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                        ),
                                      ),
                                    if (job.status == PrintJobStatus.failed ||
                                        job.status == PrintJobStatus.canceled ||
                                        job.status ==
                                            PrintJobStatus.awaitingFallback)
                                      IconButton(
                                        tooltip: 'Retry Job',
                                        onPressed: () =>
                                            controller.retryJob(job.id),
                                        icon: const Icon(Icons.refresh_rounded),
                                      ),
                                    if (!job.isTerminal)
                                      IconButton(
                                        tooltip: 'Cancel Job',
                                        onPressed: () =>
                                            controller.cancelJob(job.id),
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: colorScheme.error,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: job.progress,
                                minHeight: 5,
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
    );
  }

  static IconData _statusIcon(PrintJobStatus status) {
    switch (status) {
      case PrintJobStatus.queued:
        return Icons.schedule_rounded;
      case PrintJobStatus.spooling:
      case PrintJobStatus.printing:
        return Icons.print_rounded;
      case PrintJobStatus.paused:
        return Icons.pause_circle_outline_rounded;
      case PrintJobStatus.awaitingFallback:
        return Icons.warning_amber_rounded;
      case PrintJobStatus.completed:
        return Icons.check_circle_rounded;
      case PrintJobStatus.failed:
        return Icons.error_outline_rounded;
      case PrintJobStatus.canceled:
        return Icons.cancel_outlined;
    }
  }

  static Color _statusColor(PrintJobStatus status, ColorScheme scheme) {
    switch (status) {
      case PrintJobStatus.completed:
        return Colors.green.shade700;
      case PrintJobStatus.printing:
      case PrintJobStatus.spooling:
        return scheme.primary;
      case PrintJobStatus.awaitingFallback:
      case PrintJobStatus.paused:
        return Colors.orange.shade800;
      case PrintJobStatus.failed:
      case PrintJobStatus.canceled:
        return scheme.error;
      case PrintJobStatus.queued:
        return scheme.onSurfaceVariant;
    }
  }
}

class _WindowsSpoolerTab extends StatelessWidget {
  const _WindowsSpoolerTab({
    required this.jobState,
    required this.controller,
    required this.printers,
    required this.strings,
  });

  final JobQueueState jobState;
  final JobQueueController controller;
  final List<PrinterDevice> printers;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.isSi
                  ? 'එක් එක් මුද්‍රණ යන්ත්‍රයේ Windows Spooler පෝලිම:'
                  : 'Live Windows Print Spooler Queue by Printer:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            FilledButton.tonalIcon(
              onPressed: controller.refreshWindowsSpoolerQueues,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                strings.isSi ? 'Spooler යාවත්කාලීන කරන්න' : 'Poll Spooler Now',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: printers.length,
            itemBuilder: (context, index) {
              final printer = printers[index];
              final jobs =
                  jobState.spoolerJobsByPrinter[printer.systemName] ?? const [];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  initiallyExpanded: jobs.isNotEmpty,
                  leading: const Icon(Icons.print_rounded),
                  title: Text(
                    printer.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${jobs.length} OS spooler job(s) • Port: ${printer.portName}',
                  ),
                  children: jobs.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              strings.isSi
                                  ? 'Windows Spooler පෝලිම හිස්ය.'
                                  : 'Windows Spooler queue is empty for this printer.',
                            ),
                          ),
                        ]
                      : jobs.map((sJob) {
                          return ListTile(
                            title: Text(
                              '#${sJob.jobId} — ${sJob.documentName}',
                            ),
                            subtitle: Text(
                              '${sJob.statusLabel} • ${sJob.pagesPrinted}/${sJob.totalPages} pages',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: sJob.isPaused ? 'Resume' : 'Pause',
                                  onPressed: () =>
                                      controller.controlWindowsSpoolerJob(
                                    printerName: printer.systemName,
                                    jobId: sJob.jobId,
                                    command: sJob.isPaused
                                        ? SpoolerJobCommand.resume
                                        : SpoolerJobCommand.pause,
                                  ),
                                  icon: Icon(
                                    sJob.isPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Restart Spooler Job',
                                  onPressed: () =>
                                      controller.controlWindowsSpoolerJob(
                                    printerName: printer.systemName,
                                    jobId: sJob.jobId,
                                    command: SpoolerJobCommand.restart,
                                  ),
                                  icon: const Icon(Icons.restart_alt_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Cancel Spooler Job',
                                  onPressed: () =>
                                      controller.controlWindowsSpoolerJob(
                                    printerName: printer.systemName,
                                    jobId: sJob.jobId,
                                    command: SpoolerJobCommand.cancel,
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PrintHistoryTab extends StatelessWidget {
  const _PrintHistoryTab({
    required this.jobState,
    required this.controller,
    required this.searchController,
    required this.strings,
  });

  final JobQueueState jobState;
  final JobQueueController controller;
  final TextEditingController searchController;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search, Auto-Clear Policy & Export CSV Toolbar
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: strings.isSi
                      ? 'ගොනුවේ නම හෝ මුද්‍රණ යන්ත්‍රය අනුව සොයන්න...'
                      : 'Search history by file, printer, or status...',
                  border: const OutlineInputBorder(),
                ),
                onChanged: controller.setHistorySearchQuery,
              ),
            ),
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Auto-Clear Retention Policy Dropdown
                DropdownButton<HistoryRetentionPolicy>(
                  value: jobState.retentionPolicy,
                  isDense: true,
                  onChanged: (val) {
                    if (val != null) {
                      controller.updateRetentionPolicy(val);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: HistoryRetentionPolicy.keepAll,
                      child: Text('Keep History Forever'),
                    ),
                    DropdownMenuItem(
                      value: HistoryRetentionPolicy.days7,
                      child: Text('Auto-Clear > 7 Days'),
                    ),
                    DropdownMenuItem(
                      value: HistoryRetentionPolicy.days30,
                      child: Text('Auto-Clear > 30 Days'),
                    ),
                    DropdownMenuItem(
                      value: HistoryRetentionPolicy.days90,
                      child: Text('Auto-Clear > 90 Days'),
                    ),
                  ],
                ),

                // Export to CSV Button
                FilledButton.tonalIcon(
                  onPressed: jobState.historyJobs.isEmpty
                      ? null
                      : () async {
                          final savePath =
                              await FilePicker.platform.saveFile(
                            dialogTitle: 'Export Print History to CSV',
                            fileName: 'print_helper_history.csv',
                            type: FileType.custom,
                            allowedExtensions: ['csv'],
                          );
                          if (savePath != null && savePath.isNotEmpty) {
                            await controller.exportHistoryToCsvFile(savePath);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Exported CSV to $savePath'),
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    strings.isSi ? 'CSV ලෙස බාගන්න' : 'Export CSV',
                  ),
                ),

                // Clear All History Button
                TextButton.icon(
                  onPressed: jobState.historyJobs.isEmpty
                      ? null
                      : controller.clearAllHistory,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text(strings.isSi ? 'ඉතිහාසය මකන්න' : 'Clear History'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // History Items List with Reprint Button
        Expanded(
          child: jobState.historyJobs.isEmpty
              ? Center(
                  child: Text(
                    strings.isSi
                        ? 'මුද්‍රණ ඉතිහාස වාර්තා කිසිවක් නොමැත (සියලු දත්ත ඔබගේ පරිගණකයේ පමණක් තැන්පත් වේ).'
                        : 'No print history records found (stored 100% locally on this PC).',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: jobState.historyJobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final hJob = jobState.historyJobs[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: Icon(
                          hJob.status == PrintJobStatus.completed
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: hJob.status == PrintJobStatus.completed
                              ? Colors.green.shade700
                              : colorScheme.error,
                        ),
                        title: Text(
                          hJob.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${hJob.targetPrinterDisplayName} • '
                          '${hJob.effectiveTotalPages} page(s) • '
                          '${hJob.status.name.toUpperCase()} • '
                          '${hJob.createdAt.toLocal().toString().substring(0, 16)}',
                        ),
                        trailing: FilledButton.tonalIcon(
                          onPressed: () => controller.reprintFromHistory(hJob),
                          icon: const Icon(Icons.replay_rounded, size: 17),
                          label: Text(
                            strings.isSi ? 'නැවත මුද්‍රණය (Reprint)' : 'Reprint',
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _HotFolderTab extends StatelessWidget {
  const _HotFolderTab({
    required this.jobState,
    required this.controller,
    required this.printers,
    required this.presets,
    required this.strings,
  });

  final JobQueueState jobState;
  final JobQueueController controller;
  final List<PrinterDevice> printers;
  final List<PrintPreset> presets;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final config = jobState.hotFolderConfig;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: config.enabled,
                onChanged: (val) => controller.updateHotFolderConfig(
                  config.copyWith(enabled: val),
                ),
                title: Text(
                  strings.isSi
                      ? 'Hot Folder ස්වයංක්‍රීය මුද්‍රණය සක්‍රිය කරන්න'
                      : 'Enable Hot Folder Auto-Printing',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  strings.isSi
                      ? 'තෝරාගත් ෆෝල්ඩරයට අලුතින් එක් වන PDF/රූප/පෙළ ගොනු තෝරාගත් පෙර-සැකසුම (Preset) මගින් ස්වයංක්‍රීයව මුද්‍රණය වේ.'
                      : 'Automatically watch a local folder and print newly dropped PDF, Image, or Text files with your chosen Preset.',
                ),
              ),
              const Divider(height: 24),

              // Watched Folder Picker
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Watched Folder Path',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder_open_rounded),
                      ),
                      child: Text(
                        config.folderPath.isEmpty
                            ? 'No folder selected'
                            : config.folderPath,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final selectedDir =
                          await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Select Hot Folder to Watch',
                      );
                      if (selectedDir != null && selectedDir.isNotEmpty) {
                        await controller.updateHotFolderConfig(
                          config.copyWith(folderPath: selectedDir),
                        );
                      }
                    },
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Choose Folder...'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Preset & Target Printer Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: presets.any((p) => p.id == config.presetId)
                          ? config.presetId
                          : presets.first.id,
                      decoration: const InputDecoration(
                        labelText: 'Auto-Print Preset',
                        border: OutlineInputBorder(),
                      ),
                      items: presets
                          .map(
                            (pr) => DropdownMenuItem(
                              value: pr.id,
                              child: Text(pr.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          controller.updateHotFolderConfig(
                            config.copyWith(presetId: val),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: printers.any(
                        (p) => p.systemName == config.targetPrinterSystemName,
                      )
                          ? config.targetPrinterSystemName
                          : (printers.isNotEmpty
                              ? printers.first.systemName
                              : null),
                      decoration: const InputDecoration(
                        labelText: 'Target Printer',
                        border: OutlineInputBorder(),
                      ),
                      items: printers
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.systemName,
                              child: Text(p.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          controller.updateHotFolderConfig(
                            config.copyWith(targetPrinterSystemName: val),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Auto-processed files in this session: ${jobState.hotFolderProcessedFiles.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
