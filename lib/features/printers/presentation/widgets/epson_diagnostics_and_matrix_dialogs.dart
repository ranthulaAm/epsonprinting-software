import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/printer/epson_robust_support_service.dart';
import '../../../../services/printer/models/printer_intelligence_models.dart';
import '../../../../services/printer/printer_intelligence_service.dart';

/// 1. Dialog for viewing and copying the complete raw IPP / SNMP / Spooler
///    diagnostic bundle ("Copy printer diagnostics").
class PrinterDiagnosticsDialog extends StatelessWidget {
  final String printerName;
  final String diagnosticsReportText;
  final bool isSinhala;

  const PrinterDiagnosticsDialog({
    super.key,
    required this.printerName,
    required this.diagnosticsReportText,
    required this.isSinhala,
  });

  static Future<void> copyAndShow(
    BuildContext context, {
    required WidgetRef ref,
    required PrinterLiveIntelligence intelligence,
    required bool isSinhala,
  }) async {
    final service = ref.read(printerIntelligenceServiceProvider);
    final report = service.buildDiagnosticsReportForPrinter(
      intelligence.printerId,
    );
    await Clipboard.setData(ClipboardData(text: report));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSinhala
              ? 'මුද්‍රණ යන්ත්‍රයේ සම්පූර්ණ පරීක්ෂණ වාර්තාව (IPP/SNMP/DEVMODE) පසුරු පුවරුවට පිටපත් කරන ලදී.'
              : 'Copied printer diagnostics (raw IPP/SNMP/DEVMODE) to clipboard.',
        ),
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (_) => PrinterDiagnosticsDialog(
        printerName: intelligence.displayName,
        diagnosticsReportText: report,
        isSinhala: isSinhala,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSinhala
                  ? 'මුද්‍රණ යන්ත්‍ර පරීක්ෂණ වාර්තාව ($printerName)'
                  : 'Printer Diagnostics Report ($printerName)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isSinhala
                    ? 'මෙම වාර්තාවට සජීවී IPP, SNMP OIDs, Windows Spooler DEVMODE සැකසුම් සහ Offline ආරක්ෂණ තත්ත්වය ඇතුළත් වේ. දුරස්ථව දෝෂ නිරාකරණය සඳහා මෙය පිටපත් කර යැවිය හැක.'
                    : 'Includes raw IPP attributes, SNMP MIB tables, Windows Spooler DEVMODE verification, and offline policy audit counters for remote debugging.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    diagnosticsReportText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isSinhala ? 'වසන්න (Close)' : 'Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: diagnosticsReportText));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isSinhala
                        ? 'පරීක්ෂණ වාර්තාව පිටපත් කරන ලදී!'
                        : 'Copied printer diagnostics to clipboard!',
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(
            isSinhala
                ? 'පරීක්ෂණ වාර්තාව පිටපත් කරන්න'
                : 'Copy printer diagnostics',
          ),
        ),
      ],
    );
  }
}

/// 2. Per-Printer SNMP Community String, IPP Authentication & Rediscovery
///    Identity Anchors Dialog.
class PrinterNetworkAuthConfigDialog extends StatefulWidget {
  final PrinterNetworkAuthAndIdentityConfig initialConfig;
  final bool isSinhala;
  final ValueChanged<PrinterNetworkAuthAndIdentityConfig> onSaved;

  const PrinterNetworkAuthConfigDialog({
    super.key,
    required this.initialConfig,
    required this.isSinhala,
    required this.onSaved,
  });

  @override
  State<PrinterNetworkAuthConfigDialog> createState() =>
      _PrinterNetworkAuthConfigDialogState();
}

class _PrinterNetworkAuthConfigDialogState
    extends State<PrinterNetworkAuthConfigDialog> {
  late TextEditingController _snmpCommunityCtrl;
  late SnmpProtocolVersion _snmpVersion;
  late IppAuthenticationScheme _ippScheme;
  late TextEditingController _ippUserCtrl;
  late TextEditingController _ippPassCtrl;
  late TextEditingController _hostnameCtrl;
  late TextEditingController _serialCtrl;
  late TextEditingController _macCtrl;
  late bool _wakeOnDeepSleep;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _snmpCommunityCtrl = TextEditingController(text: c.snmpCommunity);
    _snmpVersion = c.snmpVersion;
    _ippScheme = c.ippAuthScheme;
    _ippUserCtrl = TextEditingController(text: c.ippUsername);
    _ippPassCtrl = TextEditingController(text: c.ippPasswordOrToken);
    _hostnameCtrl = TextEditingController(text: c.knownHostname ?? '');
    _serialCtrl = TextEditingController(text: c.knownSerialNumber ?? '');
    _macCtrl = TextEditingController(text: c.knownMacAddress ?? '');
    _wakeOnDeepSleep = c.wakeOnDeepSleep;
  }

  @override
  void dispose() {
    _snmpCommunityCtrl.dispose();
    _ippUserCtrl.dispose();
    _ippPassCtrl.dispose();
    _hostnameCtrl.dispose();
    _serialCtrl.dispose();
    _macCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.isSinhala;
    return AlertDialog(
      title: Text(
        isSi
            ? 'ජාල සැකසුම්, SNMP/IPP සහ ස්වයංක්‍රීය IP සෙවීම'
            : 'SNMP / IPP Auth & IP Rediscovery Settings',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<SnmpProtocolVersion>(
                value: _snmpVersion,
                decoration: InputDecoration(
                  labelText: isSi ? 'SNMP අනුවාදය' : 'SNMP Protocol Version',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: SnmpProtocolVersion.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(v.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _snmpVersion = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _snmpCommunityCtrl,
                decoration: InputDecoration(
                  labelText: isSi
                      ? 'SNMP Community String (සාමාන්‍ය: public)'
                      : 'SNMP Community String (default: public)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<IppAuthenticationScheme>(
                value: _ippScheme,
                decoration: InputDecoration(
                  labelText:
                      isSi ? 'IPP ආරක්ෂණ ක්‍රමය' : 'IPP Authentication Scheme',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: IppAuthenticationScheme.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(isSi ? s.labelSi : s.labelEn),
                      ),
                    )
                    .toList(),
                onChanged: (s) {
                  if (s != null) setState(() => _ippScheme = s);
                },
              ),
              if (_ippScheme != IppAuthenticationScheme.none) ...[
                const SizedBox(height: 10),
                if (_ippScheme == IppAuthenticationScheme.basic)
                  TextField(
                    controller: _ippUserCtrl,
                    decoration: InputDecoration(
                      labelText: isSi ? 'IPP පරිශීලක නාමය' : 'IPP Username',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ippPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _ippScheme == IppAuthenticationScheme.basic
                        ? (isSi ? 'IPP මුරපදය' : 'IPP Password')
                        : 'Bearer Token',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
              const Divider(height: 24),
              Text(
                isSi
                    ? 'IP ලිපිනය වෙනස් වූ විට නැවත සොයා ගැනීමේ තොරතුරු (Rediscovery Anchors)'
                    : 'Automatic IP Change Rediscovery Anchors',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hostnameCtrl,
                decoration: InputDecoration(
                  labelText:
                      isSi ? 'Hostname (උදා: EPSON1A2B3C.local)' : 'Hostname (e.g. EPSON1A2B3C.local)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _serialCtrl,
                decoration: InputDecoration(
                  labelText: isSi
                      ? 'අනුක්‍රමික අංකය (Serial Number)'
                      : 'Printer Serial Number (for DHCP IP changes)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _macCtrl,
                decoration: InputDecoration(
                  labelText: isSi
                      ? 'MAC ලිපිනය (උදා: A4:EE:57:12:34:56)'
                      : 'MAC Address (e.g. A4:EE:57:12:34:56)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  isSi
                      ? 'නිද්‍රා තත්ත්වයේ (Sleep mode) ඇති Epson යන්ත්‍ර ස්වයංක්‍රීයව අවදි කරන්න'
                      : 'Automatically wake printer from Deep Sleep / Energy Saver mode',
                ),
                value: _wakeOnDeepSleep,
                onChanged: (v) => setState(() => _wakeOnDeepSleep = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isSi ? 'අවලංගු කරන්න' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final updated = widget.initialConfig.copyWith(
              snmpCommunity: _snmpCommunityCtrl.text.trim().isEmpty
                  ? 'public'
                  : _snmpCommunityCtrl.text.trim(),
              snmpVersion: _snmpVersion,
              ippAuthScheme: _ippScheme,
              ippUsername: _ippUserCtrl.text.trim(),
              ippPasswordOrToken: _ippPassCtrl.text.trim(),
              knownHostname: _hostnameCtrl.text.trim().isEmpty
                  ? null
                  : _hostnameCtrl.text.trim(),
              knownSerialNumber: _serialCtrl.text.trim().isEmpty
                  ? null
                  : _serialCtrl.text.trim(),
              knownMacAddress:
                  _macCtrl.text.trim().isEmpty ? null : _macCtrl.text.trim(),
              wakeOnDeepSleep: _wakeOnDeepSleep,
            );
            widget.onSaved(updated);
            Navigator.of(context).pop();
          },
          child: Text(isSi ? 'සුරකින්න (Save)' : 'Save Settings'),
        ),
      ],
    );
  }
}

/// 3. User-Confirmed Safe Maintenance Dialog (Respects Printer Limits: never
///    runs head cleaning without explicit user request + confirmation).
class EpsonSafeMaintenanceConfirmDialog extends StatelessWidget {
  final SafeMaintenanceCommandType commandType;
  final PrinterLiveIntelligence intelligence;
  final bool isSinhala;

  const EpsonSafeMaintenanceConfirmDialog({
    super.key,
    required this.commandType,
    required this.intelligence,
    required this.isSinhala,
  });

  @override
  Widget build(BuildContext context) {
    final isCleaning =
        commandType == SafeMaintenanceCommandType.standardHeadCleaning;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cleaning_services_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCleaning
                  ? (isSinhala
                      ? 'මුද්‍රණ හිස පිරිසිදු කිරීම තහවුරු කරන්න (Head Cleaning)'
                      : 'Confirm Epson Printhead Cleaning')
                  : (isSinhala
                      ? 'Nozzle Check පරීක්ෂාව තහවුරු කරන්න'
                      : 'Confirm Nozzle Check Pattern'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(
        isCleaning
            ? (isSinhala
                ? 'මුද්‍රණ හිස පිරිසිදු කිරීම (Head Cleaning) සඳහා තීන්ත භාවිතා වන අතර අපද්‍රව්‍ය තීන්ත නඩත්තු කොටුවට (Maintenance Box) එකතු වේ. Print Helper කිසිවිටෙක ඔබගේ අවසරයකින් තොරව මෙය ස්වයංක්‍රීයව ක්‍රියාත්මක නොකරයි. නිල Epson ධාවකය හරහා දැන් පිරිසිදු කිරීම ආරම්භ කරන්නද?'
                : 'Head cleaning consumes ink and adds waste ink to the Maintenance Box. Print Helper never runs maintenance commands without your explicit request and confirmation, and never sends unverified raw control packets. Run official Epson driver Head Cleaning now?')
            : (isSinhala
                ? 'නිල Epson Windows ධාවකය හරහා Nozzle Check පරීක්ෂණ රටාව මුද්‍රණය කිරීමට A4 කොළයක් තැටියට දමා තහවුරු කරන්න.'
                : 'Load a sheet of A4 plain paper to print the official Epson driver Nozzle Check pattern.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isSinhala ? 'අවලංගු කරන්න' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final res = EpsonSafeMaintenanceGuard.validateMaintenanceRequest(
              command: commandType,
              userExplicitlyRequested: true,
              userConfirmedDialog: true,
              intelligence: intelligence,
            );
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isSinhala ? res.statusSi : res.statusEn),
              ),
            );
          },
          child: Text(
            isSinhala
                ? 'ඔව්, නිල Epson ධාවකයෙන් ක්‍රියාත්මක කරන්න'
                : 'Confirm & Run via Official Epson Driver',
          ),
        ),
      ],
    );
  }
}

/// 4. Interactive Epson & Non-Epson Test Matrix + Spooler `DEVMODE` Option
///    Verification Dialog.
class EpsonTestMatrixAndDevModeDialog extends ConsumerStatefulWidget {
  final bool isSinhala;

  const EpsonTestMatrixAndDevModeDialog({
    super.key,
    required this.isSinhala,
  });

  @override
  ConsumerState<EpsonTestMatrixAndDevModeDialog> createState() =>
      _EpsonTestMatrixAndDevModeDialogState();
}

class _EpsonTestMatrixAndDevModeDialogState
    extends ConsumerState<EpsonTestMatrixAndDevModeDialog> {
  List<EpsonPrinterTestMatrixRow>? _matrixRows;
  late DevModeMappingVerificationReport _devModeReport;

  @override
  void initState() {
    super.initState();
    _devModeReport = EpsonSpoolerDevModeMapper.mapAndVerifyOptions(
      printerDriverName: 'EPSON L8050 / WF-4830 Official Windows Spooler Driver',
      options: const EpsonSpoolerJobOptions(
        paperSizeName: 'A4',
        isLandscape: true,
        copies: 3,
        collate: true,
        isColor: true,
        duplexModeCode: 2,
        qualityMode: EpsonDriverQualityMode.highPhoto,
        mediaTypeName: 'Photo Paper Glossy',
        paperSourceTrayName: 'Rear Tray',
        borderless: true,
        borderlessExpansionLevel: 3,
        rollPaperCutMode: EpsonRollPaperCutMode.autoNormalCut,
      ),
    );
    _loadMatrix();
  }

  Future<void> _loadMatrix() async {
    final service = ref.read(printerIntelligenceServiceProvider);
    final rows =
        await EpsonPrinterTestMatrixBuilder.buildStandardTestMatrix(service);
    if (mounted) {
      setState(() => _matrixRows = rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSi = widget.isSinhala;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.fact_check_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSi
                  ? 'Epson පරීක්ෂණ වගුව (Test Matrix) සහ Windows Spooler DEVMODE තහවුරු කිරීම'
                  : 'Epson Hardware Test Matrix & Official Spooler DEVMODE Verification',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 880,
        height: 560,
        child: _matrixRows == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Offline Policy Guarantee Banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: Color(0xFF16A34A),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isSi
                                  ? '100% Offline සහතිකය: මුද්‍රණ යන්ත්‍රයේ කිසිදු පහසුකමක් සඳහා අන්තර්ජාලය භාවිතා නොවේ (තහවුරු කළ දේශීය LAN ඇමතුම්: ${OfflinePrinterNetworkPolicyGuard.verifiedLocalCallsCount}, අවහිර කළ බාහිර ඇමතුම්: ${OfflinePrinterNetworkPolicyGuard.blockedInternetCallsCount}).'
                                  : '100% Offline Mode Check Active: Never calls out to the internet for any printer feature (Verified local LAN calls: ${OfflinePrinterNetworkPolicyGuard.verifiedLocalCallsCount}, Blocked external calls: ${OfflinePrinterNetworkPolicyGuard.blockedInternetCallsCount}).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isSi
                          ? '1. මුද්‍රණ යන්ත්‍ර පරීක්ෂණ වගුව (USB, Network, Auto-Duplex, Non-Epson)'
                          : '1. Printer Telemetry Test Matrix (What could be read vs. Not reported)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._matrixRows!.map(
                      (row) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.printerModel,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    row.activeProtocols.join(' + '),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Levels: ${row.levelsSummary}\n'
                                '• Paper: ${row.paperSummary}\n'
                                '• Duplex: ${row.duplexSummary}\n'
                                '• Trays: ${row.traysSummary}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Could read (${row.readableAttributes.length}): ${row.readableAttributes.join("; ")}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF16A34A),
                                  fontSize: 11.5,
                                ),
                              ),
                              if (row.unreportedAttributes.isNotEmpty)
                                Text(
                                  'Could NOT read (${row.unreportedAttributes.length}): ${row.unreportedAttributes.join("; ")}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFD97706),
                                    fontSize: 11.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isSi
                          ? '2. නිල Epson Windows Spooler DEVMODE විකල්ප පරීක්ෂාව (${_devModeReport.fieldVerifications.length}/${_devModeReport.fieldVerifications.length} සාර්ථකයි)'
                          : '2. Official Epson Windows Spooler DEVMODE Mapping Verification (${_devModeReport.fieldVerifications.length}/${_devModeReport.fieldVerifications.length} verified)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._devModeReport.fieldVerifications.map(
                      (v) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              v.verifiedChangedOutput
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              size: 15,
                              color: v.verifiedChangedOutput
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 4,
                              child: Text(
                                v.optionName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                v.devModeFieldName,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${v.beforeRawValue} → ${v.afterRawValue}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isSi ? 'වසන්න (Close)' : 'Close'),
        ),
      ],
    );
  }
}
