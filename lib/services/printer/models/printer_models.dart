enum PrinterConnectionType {
  usb,
  network,
  virtual,
  local,
}

enum PrinterStatusType {
  ready,
  busy,
  paused,
  offline,
  outOfPaper,
  paperJam,
  tonerLow,
  doorOpen,
  error,
}

enum NetworkPrintProtocol {
  raw9100, // HP JetDirect / RAW Socket Port 9100
  ipp631, // Internet Printing Protocol Port 631
}

class PaperSizeCapability {
  const PaperSizeCapability({
    required this.code,
    required this.name,
    required this.widthMm,
    required this.heightMm,
  });

  final int code; // Win32 DMPAPER_* code
  final String name;
  final double widthMm;
  final double heightMm;

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'widthMm': widthMm,
        'heightMm': heightMm,
      };

  factory PaperSizeCapability.fromMap(Map<String, dynamic> map) {
    return PaperSizeCapability(
      code: (map['code'] as num?)?.toInt() ?? 9,
      name: map['name'] as String? ?? 'A4',
      widthMm: (map['widthMm'] as num?)?.toDouble() ?? 210.0,
      heightMm: (map['heightMm'] as num?)?.toDouble() ?? 297.0,
    );
  }
}

class PaperTrayCapability {
  const PaperTrayCapability({
    required this.code,
    required this.name,
  });

  final int code; // Win32 DMBIN_* code
  final String name;

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
      };

  factory PaperTrayCapability.fromMap(Map<String, dynamic> map) {
    return PaperTrayCapability(
      code: (map['code'] as num?)?.toInt() ?? 7,
      name: map['name'] as String? ?? 'Auto Select',
    );
  }
}

class PrinterResolution {
  const PrinterResolution({
    required this.xdpi,
    required this.ydpi,
  });

  final int xdpi;
  final int ydpi;

  String get label => xdpi == ydpi ? '$xdpi DPI' : '$xdpi x $ydpi DPI';

  Map<String, dynamic> toMap() => {'xdpi': xdpi, 'ydpi': ydpi};

  factory PrinterResolution.fromMap(Map<String, dynamic> map) {
    return PrinterResolution(
      xdpi: (map['xdpi'] as num?)?.toInt() ?? 600,
      ydpi: (map['ydpi'] as num?)?.toInt() ?? 600,
    );
  }
}

class PrinterCapabilities {
  const PrinterCapabilities({
    this.supportsColor = true,
    this.supportsDuplex = false,
    this.maxCopies = 999,
    this.paperSizes = const [
      PaperSizeCapability(code: 9, name: 'A4', widthMm: 210, heightMm: 297),
      PaperSizeCapability(
          code: 1, name: 'Letter', widthMm: 215.9, heightMm: 279.4),
      PaperSizeCapability(
          code: 5, name: 'Legal', widthMm: 215.9, heightMm: 355.6),
    ],
    this.trays = const [
      PaperTrayCapability(code: 7, name: 'Auto Select'),
      PaperTrayCapability(code: 1, name: 'Tray 1'),
    ],
    this.resolutions = const [
      PrinterResolution(xdpi: 300, ydpi: 300),
      PrinterResolution(xdpi: 600, ydpi: 600),
    ],
  });

  final bool supportsColor;
  final bool supportsDuplex;
  final int maxCopies;
  final List<PaperSizeCapability> paperSizes;
  final List<PaperTrayCapability> trays;
  final List<PrinterResolution> resolutions;

  PrinterResolution get maxResolution {
    if (resolutions.isEmpty) {
      return const PrinterResolution(xdpi: 600, ydpi: 600);
    }
    return resolutions.reduce((a, b) => a.xdpi >= b.xdpi ? a : b);
  }
}

class PrinterDevice {
  const PrinterDevice({
    required this.systemName,
    required this.driverName,
    required this.portName,
    required this.connectionType,
    required this.status,
    this.customNickname,
    this.location = '',
    this.comment = '',
    this.rawStatusFlags = 0,
    this.rawAttributes = 0,
    this.activeJobsCount = 0,
    this.isDefault = false,
    this.isFavorite = false,
    this.ipAddress,
    this.networkPort,
    this.networkProtocol,
    this.capabilities = const PrinterCapabilities(),
  });

  final String systemName;
  final String? customNickname;
  final String driverName;
  final String portName;
  final String location;
  final String comment;
  final PrinterConnectionType connectionType;
  final PrinterStatusType status;
  final int rawStatusFlags;
  final int rawAttributes;
  final int activeJobsCount;
  final bool isDefault;
  final bool isFavorite;
  final String? ipAddress;
  final int? networkPort;
  final NetworkPrintProtocol? networkProtocol;
  final PrinterCapabilities capabilities;

  /// Returns the user's custom nickname if set, otherwise the system printer name.
  String get displayName =>
      (customNickname != null && customNickname!.trim().isNotEmpty)
          ? customNickname!.trim()
          : systemName;

  bool get hasNickname =>
      customNickname != null && customNickname!.trim().isNotEmpty;

  bool get isAvailableForPrinting =>
      status == PrinterStatusType.ready ||
      status == PrinterStatusType.busy ||
      status == PrinterStatusType.tonerLow;

  PrinterDevice copyWith({
    String? systemName,
    String? customNickname,
    bool clearNickname = false,
    String? driverName,
    String? portName,
    String? location,
    String? comment,
    PrinterConnectionType? connectionType,
    PrinterStatusType? status,
    int? rawStatusFlags,
    int? rawAttributes,
    int? activeJobsCount,
    bool? isDefault,
    bool? isFavorite,
    String? ipAddress,
    int? networkPort,
    NetworkPrintProtocol? networkProtocol,
    PrinterCapabilities? capabilities,
  }) {
    return PrinterDevice(
      systemName: systemName ?? this.systemName,
      customNickname:
          clearNickname ? null : (customNickname ?? this.customNickname),
      driverName: driverName ?? this.driverName,
      portName: portName ?? this.portName,
      location: location ?? this.location,
      comment: comment ?? this.comment,
      connectionType: connectionType ?? this.connectionType,
      status: status ?? this.status,
      rawStatusFlags: rawStatusFlags ?? this.rawStatusFlags,
      rawAttributes: rawAttributes ?? this.rawAttributes,
      activeJobsCount: activeJobsCount ?? this.activeJobsCount,
      isDefault: isDefault ?? this.isDefault,
      isFavorite: isFavorite ?? this.isFavorite,
      ipAddress: ipAddress ?? this.ipAddress,
      networkPort: networkPort ?? this.networkPort,
      networkProtocol: networkProtocol ?? this.networkProtocol,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}

class ConnectionTestResult {
  const ConnectionTestResult({
    required this.isSuccess,
    required this.host,
    required this.port,
    required this.protocol,
    required this.latencyMs,
    required this.messageEn,
    required this.messageSi,
    this.detectedModelHint,
  });

  final bool isSuccess;
  final String host;
  final int port;
  final NetworkPrintProtocol protocol;
  final int latencyMs;
  final String messageEn;
  final String messageSi;
  final String? detectedModelHint;

  String localizedMessage(String lang) => lang == 'si' ? messageSi : messageEn;
}

class DiscoveredLanPrinter {
  const DiscoveredLanPrinter({
    required this.ipAddress,
    required this.port,
    required this.protocol,
    required this.discoveryMethod,
    required this.latencyMs,
    this.hostname,
    this.deviceName,
  });

  final String ipAddress;
  final int port;
  final NetworkPrintProtocol protocol;
  final String discoveryMethod; // 'mDNS / Bonjour' or 'LAN Subnet Scan'
  final int latencyMs;
  final String? hostname;
  final String? deviceName;

  String get displayTitle =>
      deviceName ?? hostname ?? 'Network Printer ($ipAddress)';
}

enum LanDiscoveryPhase {
  mdnsQuery,
  subnetScan,
  completed,
}

class LanDiscoveryProgress {
  const LanDiscoveryProgress({
    required this.phase,
    required this.progress,
    required this.scannedHosts,
    required this.totalHosts,
    required this.discovered,
  });

  final LanDiscoveryPhase phase;
  final double progress; // 0.0 -> 1.0
  final int scannedHosts;
  final int totalHosts;
  final List<DiscoveredLanPrinter> discovered;
}

enum HealthSeverity {
  healthy,
  warning,
  critical,
}

class TroubleshootingStep {
  const TroubleshootingStep({
    required this.titleEn,
    required this.titleSi,
    required this.detailEn,
    required this.detailSi,
  });

  final String titleEn;
  final String titleSi;
  final String detailEn;
  final String detailSi;

  String title(String lang) => lang == 'si' ? titleSi : titleEn;
  String detail(String lang) => lang == 'si' ? detailSi : detailEn;
}

class PrinterHealthReport {
  const PrinterHealthReport({
    required this.printerName,
    required this.severity,
    required this.headlineEn,
    required this.headlineSi,
    required this.spoolerOk,
    required this.portReachable,
    required this.activeJobsCount,
    required this.steps,
    this.pingLatencyMs,
  });

  final String printerName;
  final HealthSeverity severity;
  final String headlineEn;
  final String headlineSi;
  final bool spoolerOk;
  final bool portReachable;
  final int activeJobsCount;
  final int? pingLatencyMs;
  final List<TroubleshootingStep> steps;

  String headline(String lang) => lang == 'si' ? headlineSi : headlineEn;
}
