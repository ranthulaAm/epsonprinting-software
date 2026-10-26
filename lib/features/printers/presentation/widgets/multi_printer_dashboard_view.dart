import 'package:flutter/material.dart';
import '../../domain/snmp_printer_mib_models.dart';
import '../../domain/printer_routing_engine_models.dart';
import '../../data/printer_intelligence_snmp_routing_service.dart';

/// Interactive Multi-Printer Fleet Dashboard View.
/// Supports live SNMP/IPP telemetry, special negative supply values (-1, -2, -3),
/// specialty badges, failover confirmation, and subnet scan consent guardrails.
class MultiPrinterDashboardView extends StatefulWidget {
  final List<DashboardPrinterCardData> initialPrinters;
  final bool isSinhala;
  final Function(JobRoutingRequest request)? onRouteJobRequested;
  final Function(String cidr)? onSubnetScanAuthorized;

  const MultiPrinterDashboardView({
    super.key,
    this.initialPrinters = const [],
    this.isSinhala = false,
    this.onRouteJobRequested,
    this.onSubnetScanAuthorized,
  });

  @override
  State<MultiPrinterDashboardView> createState() => _MultiPrinterDashboardViewState();
}

class _MultiPrinterDashboardViewState extends State<MultiPrinterDashboardView> {
  late List<DashboardPrinterCardData> _printers;
  late PrinterIntelligenceSnmpRoutingService _routingService;
  late bool _isSinhala;
  double _lowSupplyThreshold = 15.0;

  @override
  void initState() {
    super.initState();
    _isSinhala = widget.isSinhala;
    _routingService = PrinterIntelligenceSnmpRoutingService();
    _printers = widget.initialPrinters.isNotEmpty
        ? List.from(widget.initialPrinters)
        : _buildDefaultFleet();
  }

  List<DashboardPrinterCardData> _buildDefaultFleet() {
    return [
      DashboardPrinterCardData(
        id: 'epson_l3250_usb',
        name: 'Front Counter L3250',
        modelName: 'Epson EcoTank L3250',
        interfaceType: PrinterInterfaceType.usb,
        state: FleetPrinterState.ready,
        activeQueueLength: 1,
        loadedPaperSummary: 'Rear Tray: A4 Plain Paper (80 gsm)',
        specialtyBadges: ['Borderless 4x6', 'Wi-Fi Direct', 'EcoTank'],
        totalLifePagesCount: 14250,
        inkChannels: [
          const ParsedSnmpSupplyEntry(
            tableIndex: 1,
            description: 'Black Ink (BK)',
            rawLevel: 75,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 75.0,
            isEstimate: true,
            colorHex: '#1A1A1A',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 2,
            description: 'Cyan Ink (C)',
            rawLevel: 60,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 60.0,
            isEstimate: true,
            colorHex: '#0099FF',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 3,
            description: 'Magenta Ink (M)',
            rawLevel: 45,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 45.0,
            isEstimate: true,
            colorHex: '#E91E63',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 4,
            description: 'Yellow Ink (Y)',
            rawLevel: 80,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 80.0,
            isEstimate: true,
            colorHex: '#FDD835',
          ),
        ],
        maintenanceBox: const ParsedSnmpSupplyEntry(
          tableIndex: 5,
          description: 'Waste Ink Pad Life',
          rawLevel: 25,
          rawMaxCapacity: 100,
          statusType: SnmpSupplyStatusType.percentage,
          calculatedPercentage: 25.0,
          isMaintenanceBox: true,
          isEstimate: true,
          colorHex: '#78909C',
        ),
      ),
      DashboardPrinterCardData(
        id: 'epson_l8050_net',
        name: 'Studio Photo L8050',
        modelName: 'Epson EcoTank L8050',
        interfaceType: PrinterInterfaceType.wifi,
        ipAddress: '192.168.1.120',
        state: FleetPrinterState.ready,
        activeQueueLength: 0,
        loadedPaperSummary: 'Rear Tray: 4x6 Premium Glossy Photo',
        specialtyBadges: ['CD/DVD', 'PVC ID Card', 'Borderless A4', '6-Color Photo'],
        totalLifePagesCount: 8920,
        inkChannels: [
          const ParsedSnmpSupplyEntry(
            tableIndex: 1,
            description: 'Black Ink (BK)',
            rawLevel: 90,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 90.0,
            isEstimate: true,
            colorHex: '#1A1A1A',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 2,
            description: 'Cyan Ink (C)',
            rawLevel: 85,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 85.0,
            isEstimate: true,
            colorHex: '#0099FF',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 3,
            description: 'Magenta Ink (M)',
            rawLevel: 70,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 70.0,
            isEstimate: true,
            colorHex: '#E91E63',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 4,
            description: 'Yellow Ink (Y)',
            rawLevel: 88,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 88.0,
            isEstimate: true,
            colorHex: '#FDD835',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 5,
            description: 'Light Cyan (LC)',
            rawLevel: 65,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 65.0,
            isEstimate: true,
            colorHex: '#80D8FF',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 6,
            description: 'Light Magenta (LM)',
            rawLevel: 62,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 62.0,
            isEstimate: true,
            colorHex: '#F48FB1',
          ),
        ],
        maintenanceBox: const ParsedSnmpSupplyEntry(
          tableIndex: 7,
          description: 'Maintenance Box (User Replaceable)',
          rawLevel: 32,
          rawMaxCapacity: 100,
          statusType: SnmpSupplyStatusType.percentage,
          calculatedPercentage: 32.0,
          isMaintenanceBox: true,
          colorHex: '#78909C',
        ),
      ),
      DashboardPrinterCardData(
        id: 'epson_wf_c5890_office',
        name: 'Production WF-C5890',
        modelName: 'Epson WorkForce Pro WF-C5890',
        interfaceType: PrinterInterfaceType.ethernet,
        ipAddress: '192.168.1.150',
        state: FleetPrinterState.printing,
        activeQueueLength: 4,
        loadedPaperSummary: 'Cassette 1: A4 Plain 80gsm | Cassette 2: A4 Letterhead',
        specialtyBadges: ['Auto Duplex', 'RIPS Ink Pack', 'Pigment', 'High Speed'],
        totalLifePagesCount: 48310,
        inkChannels: [
          // Demonstrating RFC 3805 negative special value handling
          const ParsedSnmpSupplyEntry(
            tableIndex: 1,
            description: 'Black High Capacity Pack (BK)',
            rawLevel: -1,
            rawMaxCapacity: -2,
            statusType: SnmpSupplyStatusType.presentOk,
            colorHex: '#1A1A1A',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 2,
            description: 'Cyan High Capacity Pack (C)',
            rawLevel: -3,
            rawMaxCapacity: -2,
            statusType: SnmpSupplyStatusType.someRemaining,
            colorHex: '#0099FF',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 3,
            description: 'Magenta High Capacity Pack (M)',
            rawLevel: -3,
            rawMaxCapacity: -2,
            statusType: SnmpSupplyStatusType.someRemaining,
            colorHex: '#E91E63',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 4,
            description: 'Yellow High Capacity Pack (Y)',
            rawLevel: 12,
            rawMaxCapacity: 100,
            statusType: SnmpSupplyStatusType.percentage,
            calculatedPercentage: 12.0,
            colorHex: '#FDD835',
          ),
        ],
        maintenanceBox: const ParsedSnmpSupplyEntry(
          tableIndex: 5,
          description: 'Maintenance Box',
          rawLevel: 78,
          rawMaxCapacity: 100,
          statusType: SnmpSupplyStatusType.percentage,
          calculatedPercentage: 78.0,
          isMaintenanceBox: true,
          colorHex: '#78909C',
        ),
      ),
      DashboardPrinterCardData(
        id: 'epson_sc_p900_wide',
        name: 'Pro Art SC-P900',
        modelName: 'Epson SureColor SC-P900',
        interfaceType: PrinterInterfaceType.ethernet,
        ipAddress: '192.168.1.200',
        state: FleetPrinterState.offline,
        activeQueueLength: 0,
        loadedPaperSummary: 'Top Feeder: A3+ Exhibition Fiber Paper',
        specialtyBadges: ['A2+ / A3+', '10-Color UltraChrome', 'Roll Unit', 'Rigid Board (1.5mm)'],
        totalLifePagesCount: 3120,
        activeAlerts: [
          PrinterHardwareAlert(
            code: 1001,
            severity: SnmpAlertSeverity.critical,
            rawDescription: 'Power off / Offline',
            plainLanguageEn: 'Printer is offline or turned off',
            plainLanguageSi: 'ප්‍රින්ටරය ක්‍රියාවිරහිතයි හෝ සම්බන්ධතාවය ඇනහිට ඇත',
          ),
        ],
        inkChannels: [
          const ParsedSnmpSupplyEntry(
            tableIndex: 1,
            description: 'Photo Black (PK)',
            rawLevel: -2,
            rawMaxCapacity: -2,
            statusType: SnmpSupplyStatusType.notReported,
            colorHex: '#000000',
          ),
          const ParsedSnmpSupplyEntry(
            tableIndex: 2,
            description: 'Matte Black (MK)',
            rawLevel: -2,
            rawMaxCapacity: -2,
            statusType: SnmpSupplyStatusType.notReported,
            colorHex: '#263238',
          ),
        ],
      ),
    ];
  }

  void _triggerSubnetScanDialog() {
    final subnetController = TextEditingController(text: '192.168.1.0/24');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF1976D2), size: 22),
            const SizedBox(width: 8),
            Text(_isSinhala
                ? 'ජාල පරිලෝකනය සඳහා අවසරය'
                : 'Subnet Discovery Permission Required'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSinhala
                    ? 'මෙම ක්‍රියාවලියේදී තෝරාගත් උපජාලයේ (Subnet) ලිපින 254 කටම SNMP (Port 161) සහ IPP (Port 631) සංඥා යවනු ලැබේ. ජාල ආරක්ෂණ පද්ධති අනතුරු ඇඟවීම් වැළැක්වීමට කරුණාකර තහවුරු කරන්න.'
                    : 'This operation will probe up to 254 host IP addresses across the specified CIDR range on SNMP (UDP 161) and IPP (TCP 631) to discover connected printers. Probing unapproved corporate networks may trigger firewall alerts.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF424242)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subnetController,
                decoration: InputDecoration(
                  labelText: _isSinhala ? 'උපජාල CIDR පරාසය' : 'Target Subnet CIDR',
                  hintText: '192.168.1.0/24',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.network_check),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD0D7DE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFF0969DA)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSinhala
                            ? 'ප්‍රජා නාමය (Community): "public" (පළමු උත්සාහය), Timeout: 1500ms'
                            : 'SNMP Community: "public" (first pass), Timeout: 1500ms, max 10 concurrent probes.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1F2328)),
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
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isSinhala ? 'අවලංගු කරන්න' : 'Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0969DA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.radar, size: 18),
            label: Text(_isSinhala ? 'පරිලෝකනය අනුමත කරන්න' : 'Authorize & Scan Subnet'),
            onPressed: () {
              final cidr = subnetController.text.trim();
              SubnetScanPermissionManager.grantConsent(cidr);
              Navigator.pop(ctx);
              if (widget.onSubnetScanAuthorized != null) {
                widget.onSubnetScanAuthorized!(cidr);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isSinhala
                      ? '$cidr ජාලය සාර්ථකව පරිලෝකනය කෙරේ...'
                      : 'Scanning authorized subnet $cidr...'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _testRoutingDecision(JobRoutingRequest request) {
    final decision = _routingService.routeJob(request: request, fleet: _printers);
    if (decision.requiresOperatorConfirmation) {
      _showFailoverConfirmationDialog(decision, request);
    } else {
      _showRoutingSuccessSnackBar(decision);
    }
  }

  void _showFailoverConfirmationDialog(
      RoutingDecisionResult decision, JobRoutingRequest request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: Color(0xFFD32F2F), size: 24),
            const SizedBox(width: 8),
            Text(_isSinhala
                ? 'ස්වයංක්‍රීයව වෙනත් ප්‍රින්ටරයකට මාරු කිරීම'
                : 'Job Rerouting Confirmation Required'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFE65100), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSinhala
                                ? 'මුල් ප්‍රින්ටරය කාර්යබහුලයි හෝ ක්‍රියාවිරහිතයි!'
                                : 'Original target printer is offline or unavailable!',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFFB71C1C)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isSinhala
                                ? decision.confirmationPromptSi ?? ''
                                : decision.confirmationPromptEn ?? '',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF3E2723)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isSinhala ? 'තීරණයට හේතුව (One-line reason):' : 'Routing Decision Rationale:',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD0D7DE)),
                ),
                child: Text(
                  _isSinhala ? decision.rationaleSentenceSi : decision.rationaleSentenceEn,
                  style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: Color(0xFF0969DA),
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoPill(
                      label: _isSinhala ? 'මුල් ඉලක්කය' : 'Preferred Target',
                      value: decision.originalPreferredPrinterId ?? 'Unknown',
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFD32F2F),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInfoPill(
                      label: _isSinhala ? 'යෝජිත විකල්පය' : 'Proposed Failover',
                      value: decision.selectedPrinterName,
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isSinhala ? 'පෝලිමේම තබන්න' : 'Keep in Current Queue'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0969DA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: Text(_isSinhala ? 'රැකියාව මාරු කරන්න' : 'Approve & Reroute Job'),
            onPressed: () {
              Navigator.pop(ctx);
              _showRoutingSuccessSnackBar(decision);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showRoutingSuccessSnackBar(RoutingDecisionResult decision) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            const Icon(Icons.alt_route, color: Color(0xFF38BDF8), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isSinhala ? decision.rationaleSentenceSi : decision.rationaleSentenceEn,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isSinhala ? 'ප්‍රින්ටර් පාලක මැදිරිය සහ මාර්ගගත කිරීම' : 'Multi-Printer Fleet Dashboard & Routing',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          // Subnet Scan Action
          TextButton.icon(
            icon: const Icon(Icons.radar, size: 16),
            label: Text(_isSinhala ? 'උපජාල සොයන්න' : 'Scan Subnet'),
            onPressed: _triggerSubnetScanDialog,
          ),
          const SizedBox(width: 8),
          // Test Routing Action
          PopupMenuButton<String>(
            tooltip: _isSinhala ? 'මාර්ගගත කිරීම පරීක්ෂා කරන්න' : 'Simulate Incoming Job',
            icon: const Icon(Icons.play_arrow_outlined),
            onSelected: (val) {
              if (val == 'pvc') {
                _testRoutingDecision(const JobRoutingRequest(
                  jobId: 'sim_pvc_01',
                  documentTitle: 'Staff ID Badges',
                  classification: PrintJobClassification.pvcIdCard,
                  isColor: true,
                  pageCount: 2,
                  paperSize: 'CR80',
                  preferredPrinterId: 'epson_l3250_usb',
                ));
              } else if (val == 'cd') {
                _testRoutingDecision(const JobRoutingRequest(
                  jobId: 'sim_cd_02',
                  documentTitle: 'Wedding Album DVD',
                  classification: PrintJobClassification.cdDvdDisc,
                  isColor: true,
                  pageCount: 1,
                  paperSize: '12cmDisc',
                  preferredPrinterId: 'epson_l3250_usb',
                ));
              } else if (val == 'heavy_doc') {
                _testRoutingDecision(const JobRoutingRequest(
                  jobId: 'sim_doc_03',
                  documentTitle: 'Annual Financial Report',
                  classification: PrintJobClassification.documentTextMono,
                  isColor: false,
                  pageCount: 150,
                  paperSize: 'A4',
                  requiresDuplex: true,
                  preferredPrinterId: 'epson_l3250_usb',
                ));
              } else if (val == 'offline_reroute') {
                _testRoutingDecision(const JobRoutingRequest(
                  jobId: 'sim_art_04',
                  documentTitle: 'Gallery Canvas Art',
                  classification: PrintJobClassification.photoBorderless,
                  isColor: true,
                  pageCount: 1,
                  paperSize: 'A3',
                  requiresBorderless: true,
                  preferredPrinterId: 'epson_sc_p900_wide',
                ));
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'pvc',
                child: Text(_isSinhala ? 'PVC කාඩ්පත් රැකියාව (L8050 අවශ්‍යයි)' : 'Test PVC ID Card Job'),
              ),
              PopupMenuItem(
                value: 'cd',
                child: Text(_isSinhala ? 'CD/DVD තැටි මුද්‍රණය (L8050 අවශ්‍යයි)' : 'Test CD/DVD Disc Job'),
              ),
              PopupMenuItem(
                value: 'heavy_doc',
                child: Text(_isSinhala ? 'පිටු 150 වාර්තාව (WF-C5890 අවශ්‍යයි)' : 'Test 150-Page High-Volume Job'),
              ),
              PopupMenuItem(
                value: 'offline_reroute',
                child: Text(_isSinhala ? 'අක්‍රිය ප්‍රින්ටරයක රැකියාවක් මාරු කිරීම' : 'Test Failover from Offline SC-P900'),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_isSinhala ? Icons.language : Icons.translate),
            tooltip: _isSinhala ? 'Switch to English' : 'සිංහල භාෂාවට මාරු වන්න',
            onPressed: () {
              setState(() {
                _isSinhala = !_isSinhala;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Fleet Status Summary Header
          SliverToBoxAdapter(
            child: _buildFleetSummaryBanner(),
          ),
          // Printer Cards Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 540,
                mainAxisExtent: 410,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final printer = _printers[index];
                  return _buildPrinterCard(printer);
                },
                childCount: _printers.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetSummaryBanner() {
    final readyCount = _printers.where((p) => p.state == FleetPrinterState.ready).length;
    final printingCount = _printers.where((p) => p.state == FleetPrinterState.printing).length;
    final offlineCount = _printers.where((p) => p.state == FleetPrinterState.offline).length;
    final lowSupplyCount = _printers.where((p) => p.hasLowSupplyAlert).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildSummaryMetric(
            label: _isSinhala ? 'මුළු ප්‍රින්ටර්' : 'Fleet Total',
            count: '${_printers.length}',
            color: const Color(0xFF0F172A),
          ),
          _buildSummaryDivider(),
          _buildSummaryMetric(
            label: _isSinhala ? 'සූදානම්' : 'Ready',
            count: '$readyCount',
            color: const Color(0xFF16A34A),
          ),
          _buildSummaryDivider(),
          _buildSummaryMetric(
            label: _isSinhala ? 'මුද්‍රණය වේ' : 'Active Printing',
            count: '$printingCount',
            color: const Color(0xFF2563EB),
          ),
          _buildSummaryDivider(),
          _buildSummaryMetric(
            label: _isSinhala ? 'ක්‍රියාවිරහිත' : 'Offline',
            count: '$offlineCount',
            color: const Color(0xFFDC2626),
          ),
          _buildSummaryDivider(),
          _buildSummaryMetric(
            label: _isSinhala ? 'තීන්ත අඩුයි' : 'Low Supplies',
            count: '$lowSupplyCount',
            color: lowSupplyCount > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
          ),
          const Spacer(),
          // Low Supply Threshold Config
          Text(
            _isSinhala ? 'අවම සීමාව:' : 'Alert Threshold:',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 6),
          DropdownButton<double>(
            value: _lowSupplyThreshold,
            isDense: true,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            items: const [
              DropdownMenuItem(value: 10.0, child: Text('10%')),
              DropdownMenuItem(value: 15.0, child: Text('15%')),
              DropdownMenuItem(value: 20.0, child: Text('20%')),
              DropdownMenuItem(value: 25.0, child: Text('25%')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _lowSupplyThreshold = val;
                  _printers = _printers
                      .map((p) => p.copyWith(lowSupplyThresholdPct: val))
                      .toList();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({required String label, required String count, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      height: 32,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildPrinterCard(DashboardPrinterCardData printer) {
    final statusColor = _statusColor(printer.state);
    final statusText = _statusLabel(printer.state);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: printer.hasLowSupplyAlert ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: printer.hasLowSupplyAlert ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name, Interface, State dot, Queue Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      printer.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      printer.modelName,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildInterfaceChip(printer),
              const SizedBox(width: 8),
              _buildQueueBadge(printer.activeQueueLength),
            ],
          ),
          const SizedBox(height: 8),

          // State and IP Row
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
              ),
              if (printer.ipAddress != null) ...[
                const SizedBox(width: 8),
                Text(
                  printer.ipAddress!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                ),
              ],
              const Spacer(),
              if (printer.totalLifePagesCount > 0)
                Text(
                  '${printer.totalLifePagesCount} ${_isSinhala ? "පිටු" : "pgs"}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Active alerts banner if present
          if (printer.activeAlerts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _isSinhala
                          ? printer.activeAlerts.first.plainLanguageSi
                          : printer.activeAlerts.first.plainLanguageEn,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Specialty Badges Row
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: printer.specialtyBadges.map((badge) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Ink / Toner Channels Meter
          Text(
            _isSinhala ? 'තීන්ත මට්ටම් (Ink / Consumables)' : 'Ink & Consumable Levels',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          _buildInkChannelsGrid(printer),
          const SizedBox(height: 8),

          // Maintenance Box Gauge
          if (printer.maintenanceBox != null)
            _buildMaintenanceBoxMeter(printer.maintenanceBox!),

          const Spacer(),

          // Loaded Paper Tray summary
          if (printer.loadedPaperSummary != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers_outlined, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      printer.loadedPaperSummary!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInterfaceChip(DashboardPrinterCardData printer) {
    IconData icon;
    String label;
    switch (printer.interfaceType) {
      case PrinterInterfaceType.usb:
        icon = Icons.usb;
        label = 'USB';
        break;
      case PrinterInterfaceType.wifi:
        icon = Icons.wifi;
        label = 'Wi-Fi';
        break;
      case PrinterInterfaceType.ethernet:
        icon = Icons.settings_ethernet;
        label = 'LAN';
        break;
      case PrinterInterfaceType.virtual:
        icon = Icons.cloud_queue;
        label = 'Virtual';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildQueueBadge(int count) {
    final hasJobs = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: hasJobs ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: hasJobs ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.format_list_numbered, size: 11, color: hasJobs ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            '$count ${_isSinhala ? "රැකියා" : "jobs"}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: hasJobs ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInkChannelsGrid(DashboardPrinterCardData printer) {
    return LayoutBuilder(builder: (context, constraints) {
      final channels = printer.inkChannels;
      if (channels.isEmpty) {
        return Text(
          _isSinhala ? 'තීන්ත දත්ත නොමැත' : 'No ink data reported',
          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
        );
      }
      return Column(
        children: channels.map((channel) {
          final color = _parseColor(channel.colorHex);
          final displayTxt = _formatSupplyLevelDisplay(channel);

          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26, width: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 90,
                  child: Text(
                    channel.description.split('(').first.trim(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: channel.calculatedPercentage != null
                        ? FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (channel.calculatedPercentage! / 100).clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  displayTxt,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: channel.statusType == SnmpSupplyStatusType.lowOrEmpty
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildMaintenanceBoxMeter(ParsedSnmpSupplyEntry mbox) {
    final fullness = mbox.calculatedPercentage ?? 0.0;
    final isFull = fullness >= 85.0;

    return Row(
      children: [
        const Icon(Icons.delete_outline, size: 12, color: Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          _isSinhala ? 'නඩත්තු පෙට්ටිය (M-Box):' : 'Maintenance Box:',
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (fullness / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isFull ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${fullness.toInt()}%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isFull ? const Color(0xFFDC2626) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  String _formatSupplyLevelDisplay(ParsedSnmpSupplyEntry entry) {
    final estimateTag = entry.isEstimate ? (_isSinhala ? ' (ඇස්තමේන්තුව)' : ' (est)') : '';
    switch (entry.statusType) {
      case SnmpSupplyStatusType.percentage:
        return '${entry.calculatedPercentage!.toInt()}%$estimateTag';
      case SnmpSupplyStatusType.presentOk:
        return _isSinhala ? 'හරි (OK)' : 'OK';
      case SnmpSupplyStatusType.someRemaining:
        return _isSinhala ? 'ප්‍රමාණවත්' : 'Some Remaining';
      case SnmpSupplyStatusType.lowOrEmpty:
        return _isSinhala ? 'අඩුයි / හිස්' : 'Low / Empty';
      case SnmpSupplyStatusType.notReported:
        return _isSinhala ? 'වාර්තා නැත' : 'Not reported';
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Color _statusColor(FleetPrinterState state) {
    switch (state) {
      case FleetPrinterState.ready:
        return const Color(0xFF16A34A);
      case FleetPrinterState.printing:
        return const Color(0xFF2563EB);
      case FleetPrinterState.paused:
        return const Color(0xFFD97706);
      case FleetPrinterState.paperOut:
      case FleetPrinterState.doorOpen:
      case FleetPrinterState.error:
      case FleetPrinterState.offline:
        return const Color(0xFFDC2626);
    }
  }

  String _statusLabel(FleetPrinterState state) {
    switch (state) {
      case FleetPrinterState.ready:
        return _isSinhala ? 'සූදානම්' : 'Ready';
      case FleetPrinterState.printing:
        return _isSinhala ? 'මුද්‍රණය වේ' : 'Printing';
      case FleetPrinterState.paused:
        return _isSinhala ? 'තාවකාලිකව නවතා ඇත' : 'Paused';
      case FleetPrinterState.paperOut:
        return _isSinhala ? 'කඩදාසි අවසන්' : 'Paper Out';
      case FleetPrinterState.doorOpen:
        return _isSinhala ? 'පියන විවෘතයි' : 'Cover Open';
      case FleetPrinterState.error:
        return _isSinhala ? 'දෝෂයක්' : 'Hardware Error';
      case FleetPrinterState.offline:
        return _isSinhala ? 'ක්‍රියාවිරහිතයි' : 'Offline';
    }
  }
}
