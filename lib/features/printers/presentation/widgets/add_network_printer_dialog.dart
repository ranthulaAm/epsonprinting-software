import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../services/printer/models/printer_models.dart';
import '../printers_controller.dart';

class AddNetworkPrinterDialog extends ConsumerStatefulWidget {
  const AddNetworkPrinterDialog({
    super.key,
    required this.initialTab,
  });

  final int initialTab;

  @override
  ConsumerState<AddNetworkPrinterDialog> createState() =>
      _AddNetworkPrinterDialogState();
}

class _AddNetworkPrinterDialogState
    extends ConsumerState<AddNetworkPrinterDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _hostController = TextEditingController(text: '192.168.1.');
  final _portController = TextEditingController(text: '9100');
  final _nicknameController = TextEditingController();
  NetworkPrintProtocol _protocol = NetworkPrintProtocol.raw9100;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _onProtocolChanged(NetworkPrintProtocol next) {
    setState(() {
      _protocol = next;
      _portController.text =
          next == NetworkPrintProtocol.ipp631 ? '631' : '9100';
    });
    ref.read(printersControllerProvider.notifier).clearConnectionTest();
  }

  @override
  Widget build(BuildContext context) {
    final printersState = ref.watch(printersControllerProvider);
    final controller = ref.read(printersControllerProvider.notifier);
    final locale = ref.watch(localeProvider);
    final strings = AppStrings.of(locale);
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lan_rounded, color: colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                strings.isSi
                    ? 'ජාල (LAN) මුද්‍රණ යන්ත්‍රයක් එක් කරන්න'
                    : 'Add Network / LAN Printer (Offline-Ready)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.settings_ethernet_rounded, size: 18),
                text: strings.isSi
                    ? 'IP ලිපිනය හෝ නාමය මගින්'
                    : 'By IP Address / Hostname',
              ),
              Tab(
                icon: const Icon(Icons.radar_rounded, size: 18),
                text: strings.isSi
                    ? 'ජාලය තුළ සොයන්න (LAN Discovery)'
                    : 'Discover on Local Network (LAN)',
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 410,
        child: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: Manual IP / Hostname + Connection Test
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _hostController,
                          decoration: InputDecoration(
                            labelText: strings.isSi
                                ? 'IP ලිපිනය හෝ Hostname'
                                : 'IP Address or Hostname',
                            hintText: 'e.g. 192.168.1.50 or printer.local',
                            prefixIcon: const Icon(Icons.dns_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => controller.clearConnectionTest(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Protocol Selector (RAW 9100 vs IPP 631)
                  Text(
                    strings.isSi
                        ? 'මුද්‍රණ ප්‍රොටෝකෝලය (Protocol):'
                        : 'Print Protocol:',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<NetworkPrintProtocol>(
                    segments: const [
                      ButtonSegment(
                        value: NetworkPrintProtocol.raw9100,
                        icon: Icon(Icons.bolt_rounded),
                        label: Text('RAW / JetDirect (Port 9100)'),
                      ),
                      ButtonSegment(
                        value: NetworkPrintProtocol.ipp631,
                        icon: Icon(Icons.http_rounded),
                        label: Text('IPP (Port 631)'),
                      ),
                    ],
                    selected: {_protocol},
                    onSelectionChanged: (sel) => _onProtocolChanged(sel.first),
                  ),
                  const SizedBox(height: 16),

                  // Optional Friendly Nickname
                  TextField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      labelText: strings.isSi
                          ? 'කෙටි නාමය (Nickname - අත්‍යවශ්‍ය නොවේ)'
                          : 'Custom Nickname (Optional, e.g. "2nd Floor LaserJet")',
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Test Connection Button & Live Result Card
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: printersState.isTestingConnection
                            ? null
                            : () {
                                final port = int.tryParse(
                                      _portController.text.trim(),
                                    ) ??
                                    9100;
                                controller.testNetworkConnection(
                                  host: _hostController.text,
                                  port: port,
                                  protocol: _protocol,
                                );
                              },
                        icon: printersState.isTestingConnection
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.network_check_rounded),
                        label: Text(
                          strings.isSi
                              ? 'සම්බන්ධතාවය පරීක්ෂා කරන්න'
                              : 'Test Connection',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (printersState.latestConnectionTest != null)
                    _ConnectionTestResultCard(
                      result: printersState.latestConnectionTest!,
                      langCode: locale.languageCode,
                    ).animate().fadeIn(duration: AppConstants.animFast),
                ],
              ),
            ),

            // TAB 2: Offline LAN Discovery (mDNS/Bonjour + Consent-based Subnet Scan)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Consent Box for Subnet Scan Fallback
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: printersState.userConsentedSubnetScan,
                      onChanged: printersState.isDiscoveringLan
                          ? null
                          : (val) =>
                              controller.setSubnetScanConsent(val ?? false),
                      title: Text(
                        strings.isSi
                            ? 'Bonjour (mDNS) වලට අමතරව දේශීය ජාලයේ (Subnet) IP ලිපින පරීක්ෂා කිරීමට අවසර දෙන්න'
                            : 'Allow local subnet scan fallback (ports 9100 & 631) in addition to mDNS/Bonjour',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        strings.isSi
                            ? 'අන්තර්ජාලය නොමැතිව ක්‍රියා කරයි. ඔබගේ අවසරය ඇතිව පමණක් දේශීය LAN පරාසය පරීක්ෂා කරයි.'
                            : 'Works 100% offline. Probes your local /24 LAN subnet only with your explicit permission.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Start / Stop Discovery Bar + Progress Animation
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: printersState.isDiscoveringLan
                            ? controller.stopLanDiscovery
                            : controller.startLanDiscovery,
                        icon: Icon(
                          printersState.isDiscoveringLan
                              ? Icons.stop_circle_outlined
                              : Icons.radar_rounded,
                        ),
                        label: Text(
                          printersState.isDiscoveringLan
                              ? (strings.isSi ? 'නවත්වන්න' : 'Stop Scan')
                              : (strings.isSi
                                  ? 'LAN මුද්‍රණ යන්ත්‍ර සොයන්න'
                                  : 'Scan Local Network'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (printersState.discoveryProgress != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _phaseDescription(
                                      printersState.discoveryProgress!,
                                      strings,
                                    ),
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                  Text(
                                    '${(printersState.discoveryProgress!.progress * 100).round()}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value:
                                      printersState.discoveryProgress!.progress,
                                  minHeight: 7,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Discovered LAN Printers List
                  Expanded(
                    child: _buildDiscoveredList(
                      context,
                      printersState,
                      controller,
                      strings,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            controller.stopLanDiscovery();
            Navigator.of(context).pop();
          },
          child: Text(strings.isSi ? 'අවලංගු කරන්න' : 'Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final host = _hostController.text.trim();
            if (host.isEmpty) return;
            final port = int.tryParse(_portController.text.trim()) ?? 9100;
            final nick = _nicknameController.text.trim();

            await controller.addNetworkPrinter(
              host: host,
              port: port,
              protocol: _protocol,
              nickname: nick.isEmpty ? null : nick,
            );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(
            strings.isSi ? 'මුද්‍රණ යන්ත්‍රය එක් කරන්න' : 'Add Printer',
          ),
        ),
      ],
    );
  }

  String _phaseDescription(
    LanDiscoveryProgress progress,
    AppStrings strings,
  ) {
    switch (progress.phase) {
      case LanDiscoveryPhase.mdnsQuery:
        return strings.isSi
            ? 'mDNS / Bonjour හරහා සොයමින්...'
            : 'Querying mDNS / Bonjour (_ipp._tcp.local)...';
      case LanDiscoveryPhase.subnetScan:
        return strings.isSi
            ? 'LAN IP පරීක්ෂා කරමින් (${progress.scannedHosts}/${progress.totalHosts})...'
            : 'Scanning LAN subnet (${progress.scannedHosts}/${progress.totalHosts} hosts)...';
      case LanDiscoveryPhase.completed:
        return strings.isSi
            ? 'සෙවීම අවසන් (${progress.discovered.length} ක් හමු විය)'
            : 'Scan complete (${progress.discovered.length} printer(s) found)';
    }
  }

  Widget _buildDiscoveredList(
    BuildContext context,
    PrintersState state,
    PrintersController controller,
    AppStrings strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final discovered = state.discoveryProgress?.discovered ?? const [];

    if (discovered.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              state.isDiscoveringLan
                  ? (strings.isSi
                      ? 'දේශීය ජාලයේ මුද්‍රණ යන්ත්‍ර සොයමින් පවතී...'
                      : 'Searching local network in background isolate...')
                  : (strings.isSi
                      ? 'LAN මුද්‍රණ යන්ත්‍ර සෙවීමට "Scan Local Network" ඔබන්න.'
                      : 'Click "Scan Local Network" to discover printers on your LAN without internet.'),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: discovered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = discovered[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(Icons.print_rounded, color: colorScheme.primary),
            title: Text(
              item.displayTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${item.ipAddress}:${item.port} • ${item.discoveryMethod} • ${item.latencyMs}ms',
            ),
            trailing: FilledButton.tonal(
              onPressed: () async {
                await controller.addNetworkPrinter(
                  host: item.ipAddress,
                  port: item.port,
                  protocol: item.protocol,
                  nickname: item.deviceName,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(strings.isSi ? 'එක් කරන්න' : 'Add'),
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionTestResultCard extends StatelessWidget {
  const _ConnectionTestResultCard({
    required this.result,
    required this.langCode,
  });

  final ConnectionTestResult result;
  final String langCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = result.isSuccess
        ? Colors.green.withOpacity(0.14)
        : colorScheme.errorContainer;
    final fg = result.isSuccess
        ? Colors.green.shade800
        : colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            result.isSuccess
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.localizedMessage(langCode),
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
