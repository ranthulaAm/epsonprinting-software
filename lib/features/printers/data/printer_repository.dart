import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/printer/i_printer_service.dart';
import '../../../services/printer/models/printer_models.dart';
import '../../../services/printer/win32_printer_service.dart';
import '../../workspace/domain/print_queue_item.dart';
import 'printer_preferences_persistence.dart';

final printerRepositoryProvider = Provider<PrinterRepository>((ref) {
  return PrinterRepository(
    printerService: ref.watch(printerServiceProvider),
    persistence: ref.watch(printerPreferencesPersistenceProvider),
  );
});

class PrinterRepository {
  const PrinterRepository({
    required IPrinterService printerService,
    required IPrinterPreferencesPersistence persistence,
  })  : _printerService = printerService,
        _persistence = persistence;

  final IPrinterService _printerService;
  final IPrinterPreferencesPersistence _persistence;

  /// Loads all OS spooler printers + saved direct LAN printers, enriches them
  /// with user nicknames and favorites, and sorts Favorites -> Default -> Ready.
  Future<List<PrinterDevice>> fetchAllPrinters() async {
    final spoolerPrinters = await _printerService.listInstalledPrinters();
    final prefsMap = await _persistence.loadPrinterPrefs();
    final manualLanRecords = await _persistence.loadManualNetworkPrinters();

    final byName = <String, PrinterDevice>{};

    for (final printer in spoolerPrinters) {
      final pref = prefsMap[printer.systemName];
      byName[printer.systemName] = printer.copyWith(
        customNickname: pref?.nickname,
        isFavorite: pref?.isFavorite ?? false,
      );
    }

    // Merge any manually added network printers that aren't already listed by spooler
    for (final rec in manualLanRecords) {
      if (!byName.containsKey(rec.systemName)) {
        final pref = prefsMap[rec.systemName];
        final test = await _printerService.testNetworkPrinterConnection(
          host: rec.host,
          port: rec.port,
          protocol: rec.protocol,
        );
        byName[rec.systemName] = PrinterDevice(
          systemName: rec.systemName,
          customNickname: pref?.nickname ?? rec.nickname,
          isFavorite: pref?.isFavorite ?? false,
          driverName:
              'Direct LAN (${rec.protocol == NetworkPrintProtocol.ipp631 ? 'IPP' : 'RAW 9100'})',
          portName: '${rec.host}:${rec.port}',
          location: rec.host,
          connectionType: PrinterConnectionType.network,
          status: test.isSuccess
              ? PrinterStatusType.ready
              : PrinterStatusType.offline,
          ipAddress: rec.host,
          networkPort: rec.port,
          networkProtocol: rec.protocol,
        );
      }
    }

    final merged = byName.values.toList();
    merged.sort(_comparePrinters);
    return merged;
  }

  static int _comparePrinters(PrinterDevice a, PrinterDevice b) {
    if (a.isFavorite != b.isFavorite) {
      return a.isFavorite ? -1 : 1;
    }
    if (a.isDefault != b.isDefault) {
      return a.isDefault ? -1 : 1;
    }
    if (a.isAvailableForPrinting != b.isAvailableForPrinting) {
      return a.isAvailableForPrinting ? -1 : 1;
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  Future<Map<PrintDocumentType, String>> loadLastUsedMap() {
    return _persistence.loadLastUsedByFileType();
  }

  Future<void> setFavorite(String systemName, bool isFavorite) {
    return _persistence.setFavorite(systemName, isFavorite);
  }

  Future<void> setNickname(String systemName, String? nickname) {
    return _persistence.setNickname(systemName, nickname);
  }

  Future<void> recordLastUsedForDocumentType(
    PrintDocumentType docType,
    String printerSystemName,
  ) {
    return _persistence.setLastUsedForFileType(docType, printerSystemName);
  }

  /// Resolves the best printer for a given [PrintDocumentType]:
  /// 1. Last-used printer for that exact file type (if installed)
  /// 2. First Favorite printer that is ready
  /// 3. OS Default printer
  /// 4. First available printer
  PrinterDevice? resolvePreferredPrinter({
    required PrintDocumentType? docType,
    required List<PrinterDevice> printers,
    required Map<PrintDocumentType, String> lastUsedByType,
  }) {
    if (printers.isEmpty) return null;

    if (docType != null) {
      final rememberedName = lastUsedByType[docType];
      if (rememberedName != null) {
        final match = printers
            .where((p) => p.systemName == rememberedName)
            .firstOrNull;
        if (match != null) return match;
      }
    }

    final favReady = printers
        .where((p) => p.isFavorite && p.isAvailableForPrinting)
        .firstOrNull;
    if (favReady != null) return favReady;

    final defaultPrinter = printers.where((p) => p.isDefault).firstOrNull;
    if (defaultPrinter != null) return defaultPrinter;

    return printers.first;
  }

  Future<ConnectionTestResult> testConnection({
    required String host,
    required int port,
    required NetworkPrintProtocol protocol,
  }) {
    return _printerService.testNetworkPrinterConnection(
      host: host,
      port: port,
      protocol: protocol,
    );
  }

  Stream<LanDiscoveryProgress> discoverLanPrinters({
    required bool includeSubnetScan,
  }) {
    return _printerService.discoverLanPrinters(
      includeSubnetScan: includeSubnetScan,
    );
  }

  Future<PrinterDevice> addNetworkPrinter({
    required String host,
    required int port,
    required NetworkPrintProtocol protocol,
    String? nickname,
  }) async {
    final device = await _printerService.registerNetworkPrinter(
      host: host,
      port: port,
      protocol: protocol,
      customName: nickname,
    );

    await _persistence.saveManualNetworkPrinter(
      SavedNetworkPrinterRecord(
        systemName: device.systemName,
        host: host.trim(),
        port: port,
        protocol: protocol,
        nickname: nickname,
      ),
    );
    if (nickname != null && nickname.trim().isNotEmpty) {
      await _persistence.setNickname(device.systemName, nickname.trim());
    }
    return device;
  }

  Future<PrinterHealthReport> runHealthCheck(PrinterDevice printer) {
    return _printerService.runHealthCheck(printer);
  }
}
