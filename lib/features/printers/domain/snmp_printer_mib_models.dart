/// RFC 3805 Printer MIB & RFC 2790 Host Resources MIB Object Identifiers (OIDs).
class PrinterMibOids {
  // Host Resources MIB (RFC 2790)
  static const String hrDeviceDescr = '1.3.6.1.2.1.25.3.2.1.3';
  static const String hrPrinterStatus = '1.3.6.1.2.1.25.3.5.1.1';
  static const String hrPrinterDetectedErrorState = '1.3.6.1.2.1.25.3.5.1.2';

  // Printer MIB (RFC 3805 / RFC 1759)
  static const String prtGeneralSerialNumber = '1.3.6.1.2.1.43.5.1.1.17';
  static const String prtMarkerLifeCount = '1.3.6.1.2.1.43.10.2.1.4';
  
  // Supplies Table (.43.11.1.1)
  static const String prtMarkerSuppliesDescription = '1.3.6.1.2.1.43.11.1.1.6';
  static const String prtMarkerSuppliesMaxCapacity = '1.3.6.1.2.1.43.11.1.1.8';
  static const String prtMarkerSuppliesLevel = '1.3.6.1.2.1.43.11.1.1.9';

  // Alerts Table (.43.18.1.1)
  static const String prtAlertCode = '1.3.6.1.2.1.43.18.1.1.7';
  static const String prtAlertDescription = '1.3.6.1.2.1.43.18.1.1.8';

  // Input Tray Table (.43.8.2.1)
  static const String prtInputName = '1.3.6.1.2.1.43.8.2.1.18';
  static const String prtInputMediaName = '1.3.6.1.2.1.43.8.2.1.12';
  static const String prtInputMediaType = '1.3.6.1.2.1.43.8.2.1.19';
  static const String prtInputCurrentLevel = '1.3.6.1.2.1.43.8.2.1.10';
  static const String prtInputMaxCapacity = '1.3.6.1.2.1.43.8.2.1.9';
}

/// Represents the status display of an individual consumable channel.
enum SnmpSupplyStatusType {
  /// Exact or calculated percentage (0% to 100%).
  percentage,

  /// Level is -1 (other / present / OK).
  presentOk,

  /// Level is -3 (some remaining / sufficient).
  someRemaining,

  /// Level is 0 or below critical threshold.
  lowOrEmpty,

  /// Level is -2 (unknown / not reported).
  notReported,
}

/// Individual ink, toner, or waste tank consumable entry parsed from SNMP or IPP.
class ParsedSnmpSupplyEntry {
  final int tableIndex;
  final String description;
  final int rawLevel;
  final int rawMaxCapacity;
  final SnmpSupplyStatusType statusType;
  final double? calculatedPercentage;
  final bool isMaintenanceBox;
  final bool isEstimate;
  final String colorHex;

  const ParsedSnmpSupplyEntry({
    required this.tableIndex,
    required this.description,
    required this.rawLevel,
    required this.rawMaxCapacity,
    required this.statusType,
    this.calculatedPercentage,
    this.isMaintenanceBox = false,
    this.isEstimate = false,
    this.colorHex = '#212121',
  });

  /// Formats the supply status string honestly in English and Sinhala.
  String getDisplayString({bool isSinhala = false}) {
    final estimateTag = isEstimate ? (isSinhala ? ' (ඇස්තමේන්තුව)' : ' (estimate)') : '';

    switch (statusType) {
      case SnmpSupplyStatusType.percentage:
        final pct = calculatedPercentage?.toStringAsFixed(0) ?? '0';
        return '$pct%$estimateTag';
      case SnmpSupplyStatusType.presentOk:
        return isSinhala ? 'ප්‍රමාණවත් (OK)' : 'OK';
      case SnmpSupplyStatusType.someRemaining:
        return isSinhala ? 'ඉතිරිව ඇත (OK)' : 'Some Remaining (OK)';
      case SnmpSupplyStatusType.lowOrEmpty:
        return isSinhala ? 'අඩුයි (Low)' : 'Low';
      case SnmpSupplyStatusType.notReported:
        return isSinhala ? 'වාර්තා නොවේ' : 'Not reported';
    }
  }

  Map<String, dynamic> toJson() => {
    'tableIndex': tableIndex,
    'description': description,
    'rawLevel': rawLevel,
    'rawMaxCapacity': rawMaxCapacity,
    'statusType': statusType.name,
    'calculatedPercentage': calculatedPercentage,
    'isMaintenanceBox': isMaintenanceBox,
    'isEstimate': isEstimate,
    'colorHex': colorHex,
  };
}

/// SNMP Security and Connection Configuration per printer.
class SnmpConnectionConfig {
  /// Target host IPv4, IPv6, or local hostname.
  final String host;

  /// SNMP UDP port (default: 161).
  final int port;

  /// SNMP Version (v1, v2c, v3).
  final String version;

  /// Community string for v1/v2c (default: "public").
  final String community;

  /// SNMPv3 Security Name / User.
  final String? securityName;

  /// SNMPv3 Auth Key.
  final String? authKey;

  /// SNMPv3 Privacy Key.
  final String? privKey;

  /// Socket timeout in milliseconds (short timeout to prevent UI freezes).
  final int timeoutMs;

  /// Polling interval in seconds (low frequency to avoid loading printers).
  final int pollingIntervalSeconds;

  const SnmpConnectionConfig({
    required this.host,
    this.port = 161,
    this.version = 'v2c',
    this.community = 'public',
    this.securityName,
    this.authKey,
    this.privKey,
    this.timeoutMs = 1500,
    this.pollingIntervalSeconds = 45,
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'version': version,
    'community': community,
    'securityName': securityName,
    'timeoutMs': timeoutMs,
    'pollingIntervalSeconds': pollingIntervalSeconds,
  };
}

/// Human-readable printer alert parsed from RFC 3805 prtAlertTable.
class PrinterHardwareAlert {
  final int alertCode;
  final String rawDescription;
  final String messageEn;
  final String messageSi;
  final bool isCritical;

  const PrinterHardwareAlert({
    required this.alertCode,
    required this.rawDescription,
    required this.messageEn,
    required this.messageSi,
    this.isCritical = false,
  });

  factory PrinterHardwareAlert.fromPrtAlert({
    required int code,
    required String rawDesc,
  }) {
    final lower = rawDesc.toLowerCase();

    if (lower.contains('jam') || code == 8) {
      return PrinterHardwareAlert(
        alertCode: code,
        rawDescription: rawDesc,
        messageEn: 'Paper Jam: Clear path and press Resume',
        messageSi: 'කඩදාසිය හිරවී ඇත: කඩදාසිය ඉවත් කර Resume ඔබන්න',
        isCritical: true,
      );
    }

    if (lower.contains('empty') || lower.contains('out of paper') || code == 9) {
      return PrinterHardwareAlert(
        alertCode: code,
        rawDescription: rawDesc,
        messageEn: 'Paper Out: Load sheets into feed tray',
        messageSi: 'කඩදාසි අවසන්: කඩදාසි තැටියට කොළ පුරවන්න',
        isCritical: true,
      );
    }

    if (lower.contains('door') || lower.contains('cover') || code == 5) {
      return PrinterHardwareAlert(
        alertCode: code,
        rawDescription: rawDesc,
        messageEn: 'Cover Open: Close printer front/scanner cover',
        messageSi: 'පියන ඇරී ඇත: කරුණාකර ප්‍රින්ටරයේ පියන වසන්න',
        isCritical: true,
      );
    }

    if (lower.contains('tray') || lower.contains('misaligned')) {
      return PrinterHardwareAlert(
        alertCode: code,
        rawDescription: rawDesc,
        messageEn: 'Tray Misaligned: Re-insert paper or disc tray',
        messageSi: 'තැටිය නිවැරදිව තබා නැත: තැටිය නැවත කෙලින් ඇතුල් කරන්න',
        isCritical: false,
      );
    }

    if (lower.contains('waste') || lower.contains('maintenance box') || lower.contains('pad')) {
      return PrinterHardwareAlert(
        alertCode: code,
        rawDescription: rawDesc,
        messageEn: 'Maintenance Box Full: Replace waste ink container',
        messageSi: 'අපද්‍රව්‍ය තීන්ත පෙට්ටිය පිරී ඇත: අලුත් පෙට්ටියක් යොදන්න',
        isCritical: true,
      );
    }

    return PrinterHardwareAlert(
      alertCode: code,
      rawDescription: rawDesc,
      messageEn: rawDesc.isNotEmpty ? rawDesc : 'Attention Required',
      messageSi: 'ප්‍රින්ටරයේ අවධානය අවශ්‍යයි',
      isCritical: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'alertCode': alertCode,
    'rawDescription': rawDescription,
    'messageEn': messageEn,
    'messageSi': messageSi,
    'isCritical': isCritical,
  };
}
