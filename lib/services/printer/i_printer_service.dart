import '../../features/queue/domain/print_job_models.dart';
import 'models/printer_models.dart';

abstract interface class IPrinterService {
  /// Enumerates all installed local, USB, network, and virtual printers from the
  /// OS print spooler, including live status flags, default printer flag, and
  /// per-printer capabilities (paper sizes, trays, duplex, color, DPI).
  /// Runs in a background isolate so slow network drivers never block the UI.
  Future<List<PrinterDevice>> listInstalledPrinters();

  /// Queries detailed hardware capabilities for a specific printer driver/port.
  Future<PrinterCapabilities> getPrinterCapabilities(
    String printerName,
    String portName,
  );

  /// Tests direct TCP/IPP connectivity to a network printer by IP or hostname
  /// on port 9100 (RAW/JetDirect) or 631 (IPP) without requiring internet.
  Future<ConnectionTestResult> testNetworkPrinterConnection({
    required String host,
    required int port,
    required NetworkPrintProtocol protocol,
  });

  /// Discovers printers on the local area network (LAN) completely offline.
  /// Always performs mDNS/Bonjour multicast discovery (`224.0.0.251:5353`),
  /// and if [includeSubnetScan] is true (with user consent), performs a fast
  /// isolated `/24` subnet scan on ports 9100 and 631.
  Stream<LanDiscoveryProgress> discoverLanPrinters({
    required bool includeSubnetScan,
  });

  /// Registers a network printer in the Windows Spooler (or returns a configured
  /// direct network PrinterDevice if running without administrator privileges).
  Future<PrinterDevice> registerNetworkPrinter({
    required String host,
    required int port,
    required NetworkPrintProtocol protocol,
    String? customName,
  });

  /// Runs a comprehensive diagnostic health check on [printer] and returns
  /// plain-language troubleshooting steps in English and Sinhala.
  Future<PrinterHealthReport> runHealthCheck(PrinterDevice printer);

  /// Submits a print job to the Windows Print Spooler (`StartDocPrinterW` /
  /// `WritePrinter` / `EndDocPrinter` or direct RAW/IPP socket for direct LAN
  /// printers) inside a background isolate.
  Future<SpoolSubmissionResult> submitPrintJob({
    required PrintHelperJob job,
    required List<int> composedPdfBytes,
  });

  /// Lists live OS print spooler jobs (`EnumJobsW` level 2 `JOB_INFO_2`) for
  /// [printerName].
  Future<List<SpoolerJobInfo>> listSpoolerJobs(String printerName);

  /// Controls a specific job in the Windows Print Spooler (`SetJobW` with
  /// `JOB_CONTROL_PAUSE`, `RESUME`, `CANCEL`, or `RESTART`).
  Future<bool> controlSpoolerJob({
    required String printerName,
    required int jobId,
    required SpoolerJobCommand command,
  });
}
