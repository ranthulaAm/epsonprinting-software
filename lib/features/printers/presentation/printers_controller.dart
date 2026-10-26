import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/printer/models/printer_models.dart';
import '../../workspace/domain/print_queue_item.dart';
import '../data/printer_repository.dart';

class PrintersState {
  const PrintersState({
    this.printers = const [],
    this.lastUsedByFileType = const {},
    this.isRefreshing = false,
    this.isTestingConnection = false,
    this.latestConnectionTest,
    this.isDiscoveringLan = false,
    this.discoveryProgress,
    this.userConsentedSubnetScan = false,
    this.activeHealthReport,
    this.isRunningHealthCheck = false,
    this.errorBanner,
  });

  final List<PrinterDevice> printers;
  final Map<PrintDocumentType, String> lastUsedByFileType;
  final bool isRefreshing;
  final bool isTestingConnection;
  final ConnectionTestResult? latestConnectionTest;
  final bool isDiscoveringLan;
  final LanDiscoveryProgress? discoveryProgress;
  final bool userConsentedSubnetScan;
  final PrinterHealthReport? activeHealthReport;
  final bool isRunningHealthCheck;
  final String? errorBanner;

  int get readyCount =>
      printers.where((p) => p.isAvailableForPrinting).length;
  int get offlineOrErrorCount =>
      printers.where((p) => !p.isAvailableForPrinting).length;

  PrintersState copyWith({
    List<PrinterDevice>? printers,
    Map<PrintDocumentType, String>? lastUsedByFileType,
    bool? isRefreshing,
    bool? isTestingConnection,
    ConnectionTestResult? latestConnectionTest,
    bool clearConnectionTest = false,
    bool? isDiscoveringLan,
    LanDiscoveryProgress? discoveryProgress,
    bool clearDiscoveryProgress = false,
    bool? userConsentedSubnetScan,
    PrinterHealthReport? activeHealthReport,
    bool clearHealthReport = false,
    bool? isRunningHealthCheck,
    String? errorBanner,
    bool clearErrorBanner = false,
  }) {
    return PrintersState(
      printers: printers ?? this.printers,
      lastUsedByFileType: lastUsedByFileType ?? this.lastUsedByFileType,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      latestConnectionTest: clearConnectionTest
          ? null
          : (latestConnectionTest ?? this.latestConnectionTest),
      isDiscoveringLan: isDiscoveringLan ?? this.isDiscoveringLan,
      discoveryProgress: clearDiscoveryProgress
          ? null
          : (discoveryProgress ?? this.discoveryProgress),
      userConsentedSubnetScan:
          userConsentedSubnetScan ?? this.userConsentedSubnetScan,
      activeHealthReport: clearHealthReport
          ? null
          : (activeHealthReport ?? this.activeHealthReport),
      isRunningHealthCheck: isRunningHealthCheck ?? this.isRunningHealthCheck,
      errorBanner:
          clearErrorBanner ? null : (errorBanner ?? this.errorBanner),
    );
  }
}

final printersControllerProvider =
    StateNotifierProvider<PrintersController, PrintersState>((ref) {
  final repo = ref.watch(printerRepositoryProvider);
  final controller = PrintersController(repository: repo);
  controller.refreshPrinters();
  return controller;
});

class PrintersController extends StateNotifier<PrintersState> {
  PrintersController({required PrinterRepository repository})
      : _repository = repository,
        super(const PrintersState());

  final PrinterRepository _repository;
  StreamSubscription<LanDiscoveryProgress>? _discoverySub;

  Future<void> refreshPrinters() async {
    state = state.copyWith(isRefreshing: true, clearErrorBanner: true);
    try {
      final printers = await _repository.fetchAllPrinters();
      final lastUsed = await _repository.loadLastUsedMap();
      state = state.copyWith(
        printers: printers,
        lastUsedByFileType: lastUsed,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorBanner: 'Could not refresh printers from spooler: $e',
      );
    }
  }

  Future<void> toggleFavorite(String systemName) async {
    final target =
        state.printers.where((p) => p.systemName == systemName).firstOrNull;
    if (target == null) return;

    final nextFav = !target.isFavorite;
    await _repository.setFavorite(systemName, nextFav);
    await refreshPrinters();
  }

  Future<void> updateNickname(String systemName, String? nickname) async {
    await _repository.setNickname(systemName, nickname);
    await refreshPrinters();
  }

  Future<void> rememberPrinterForFileType(
    PrintDocumentType docType,
    String printerSystemName,
  ) async {
    await _repository.recordLastUsedForDocumentType(docType, printerSystemName);
    final updatedMap =
        Map<PrintDocumentType, String>.from(state.lastUsedByFileType)
          ..[docType] = printerSystemName;
    state = state.copyWith(lastUsedByFileType: updatedMap);
  }

  PrinterDevice? preferredPrinterForFileType(PrintDocumentType? docType) {
    return _repository.resolvePreferredPrinter(
      docType: docType,
      printers: state.printers,
      lastUsedByType: state.lastUsedByFileType,
    );
  }

  void setSubnetScanConsent(bool consented) {
    state = state.copyWith(userConsentedSubnetScan: consented);
  }

  void clearConnectionTest() {
    state = state.copyWith(clearConnectionTest: true);
  }

  Future<ConnectionTestResult> testNetworkConnection({
    required String host,
    required int port,
    required NetworkPrintProtocol protocol,
  }) async {
    state = state.copyWith(
      isTestingConnection: true,
      clearConnectionTest: true,
    );
    final result = await _repository.testConnection(
      host: host,
      port: port,
      protocol: protocol,
    );
    state = state.copyWith(
      isTestingConnection: false,
      latestConnectionTest: result,
    );
    return result;
  }

  Future<PrinterDevice> addNetworkPrinter({
    required String host,
    required int port,
    required NetworkPrintProtocol protocol,
    String? nickname,
  }) async {
    final added = await _repository.addNetworkPrinter(
      host: host,
      port: port,
      protocol: protocol,
      nickname: nickname,
    );
    await refreshPrinters();
    return added;
  }

  Future<void> startLanDiscovery() async {
    await _discoverySub?.cancel();
    state = state.copyWith(
      isDiscoveringLan: true,
      discoveryProgress: const LanDiscoveryProgress(
        phase: LanDiscoveryPhase.mdnsQuery,
        progress: 0.05,
        scannedHosts: 0,
        totalHosts: 1,
        discovered: [],
      ),
    );

    final stream = _repository.discoverLanPrinters(
      includeSubnetScan: state.userConsentedSubnetScan,
    );

    _discoverySub = stream.listen(
      (progressUpdate) {
        final isDone = progressUpdate.phase == LanDiscoveryPhase.completed;
        state = state.copyWith(
          isDiscoveringLan: !isDone,
          discoveryProgress: progressUpdate,
        );
      },
      onError: (_) {
        state = state.copyWith(isDiscoveringLan: false);
      },
      onDone: () {
        state = state.copyWith(isDiscoveringLan: false);
      },
    );
  }

  Future<void> stopLanDiscovery() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    state = state.copyWith(isDiscoveringLan: false);
  }

  Future<PrinterHealthReport> runHealthCheck(PrinterDevice printer) async {
    state = state.copyWith(
      isRunningHealthCheck: true,
      clearHealthReport: true,
    );
    final report = await _repository.runHealthCheck(printer);
    state = state.copyWith(
      isRunningHealthCheck: false,
      activeHealthReport: report,
    );
    return report;
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    super.dispose();
  }
}
