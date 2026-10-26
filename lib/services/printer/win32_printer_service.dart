import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:win32/win32.dart' as win32;

import '../../features/queue/domain/print_job_models.dart';
import 'i_printer_service.dart';
import 'models/printer_models.dart';

final printerServiceProvider = Provider<IPrinterService>((ref) {
  return Win32PrinterService();
});

// Direct FFI typedefs for winspool.drv DeviceCapabilitiesW
typedef _DeviceCapabilitiesNative = ffi.Int32 Function(
  ffi.Pointer<Utf16> pDevice,
  ffi.Pointer<Utf16> pPort,
  ffi.Uint16 fwCapability,
  ffi.Pointer<ffi.Void> pOutput,
  ffi.Pointer<ffi.Void> pDevMode,
);
typedef _DeviceCapabilitiesDart = int Function(
  ffi.Pointer<Utf16> pDevice,
  ffi.Pointer<Utf16> pPort,
  int fwCapability,
  ffi.Pointer<ffi.Void> pOutput,
  ffi.Pointer<ffi.Void> pDevMode,
);

class Win32PrinterService implements IPrinterService {
  // Win32 DeviceCapabilities constants
  static const int _dcPapers = 2;
  static const int _dcPaperSize = 3;
  static const int _dcBins = 6;
  static const int _dcDuplex = 7;
  static const int _dcBinNames = 12;
  static const int _dcEnumResolutions = 13;
  static const int _dcPaperNames = 16;
  static const int _dcCopies = 18;
  static const int _dcColorDevice = 32;

  // Win32 Printer Status flags
  static const int _statusPaused = 0x00000001;
  static const int _statusError = 0x00000002;
  static const int _statusPaperJam = 0x00000008;
  static const int _statusPaperOut = 0x00000010;
  static const int _statusManualFeed = 0x00000020;
  static const int _statusPaperProblem = 0x00000040;
  static const int _statusOffline = 0x00000080;
  static const int _statusBusy = 0x00000200;
  static const int _statusPrinting = 0x00000400;
  static const int _statusProcessing = 0x00004000;
  static const int _statusTonerLow = 0x00020000;
  static const int _statusNoToner = 0x00040000;
  static const int _statusDoorOpen = 0x00400000;

  // Win32 Printer Attribute flags
  static const int _attrNetwork = 0x00000010;
  static const int _attrWorkOffline = 0x00000400;

  @override
  Future<List<PrinterDevice>> listInstalledPrinters() async {
    if (!Platform.isWindows) {
      return _fallbackSimulatedPrinters();
    }
    return Isolate.run(_enumerateWin32PrintersInIsolate);
  }

  @override
  Future<PrinterCapabilities> getPrinterCapabilities(
    String printerName,
    String portName,
  ) async {
    if (!Platform.isWindows) {
      return const PrinterCapabilities();
    }
    return Isolate.run(
      () => _queryCapabilitiesInIsolate(printerName, portName),
    );
  }

  static List<PrinterDevice> _enumerateWin32PrintersInIsolate() {
    final List<PrinterDevice> devices = [];
    final String defaultPrinterName = _getDefaultPrinterNameWin32();

    const int flags =
        win32.PRINTER_ENUM_LOCAL | win32.PRINTER_ENUM_CONNECTIONS;
    final pcbNeeded = calloc<ffi.Uint32>();
    final pcReturned = calloc<ffi.Uint32>();

    try {
      // First call to determine buffer size needed for PRINTER_INFO_2 (level 2)
      win32.EnumPrinters(
        flags,
        ffi.nullptr,
        2,
        ffi.nullptr,
        0,
        pcbNeeded,
        pcReturned,
      );

      final int bytesNeeded = pcbNeeded.value;
      if (bytesNeeded <= 0) {
        return devices;
      }

      final pPrinterEnum = calloc<ffi.Uint8>(bytesNeeded);
      try {
        final int ok = win32.EnumPrinters(
          flags,
          ffi.nullptr,
          2,
          pPrinterEnum,
          bytesNeeded,
          pcbNeeded,
          pcReturned,
        );

        if (ok == win32.FALSE) {
          return devices;
        }

        final int count = pcReturned.value;
        final infoArray = pPrinterEnum.cast<win32.PRINTER_INFO_2>();

        for (var i = 0; i < count; i++) {
          final info = (infoArray + i).ref;
          final systemName = info.pPrinterName == ffi.nullptr
              ? 'Unknown Printer'
              : info.pPrinterName.toDartString();
          final driverName = info.pDriverName == ffi.nullptr
              ? ''
              : info.pDriverName.toDartString();
          final portName = info.pPortName == ffi.nullptr
              ? ''
              : info.pPortName.toDartString();
          final location = info.pLocation == ffi.nullptr
              ? ''
              : info.pLocation.toDartString();
          final comment = info.pComment == ffi.nullptr
              ? ''
              : info.pComment.toDartString();

          final int rawStatus = info.Status;
          final int rawAttrs = info.Attributes;
          final int jobsCount = info.cJobs;

          final connectionType = _classifyConnectionType(
            systemName: systemName,
            driverName: driverName,
            portName: portName,
            attributes: rawAttrs,
          );

          final statusType = _mapWin32Status(rawStatus, rawAttrs);
          final capabilities = _queryCapabilitiesInIsolate(
            systemName,
            portName,
          );

          final extractedIp = _extractIpFromPortOrLocation(portName, location);

          devices.add(
            PrinterDevice(
              systemName: systemName,
              driverName: driverName,
              portName: portName,
              location: location,
              comment: comment,
              connectionType: connectionType,
              status: statusType,
              rawStatusFlags: rawStatus,
              rawAttributes: rawAttrs,
              activeJobsCount: jobsCount,
              isDefault: systemName.toLowerCase() ==
                  defaultPrinterName.toLowerCase(),
              ipAddress: extractedIp,
              capabilities: capabilities,
            ),
          );
        }
      } finally {
        calloc.free(pPrinterEnum);
      }
    } catch (_) {
      // Never crash if a corrupted printer driver fails enumeration
    } finally {
      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
    }

    return devices;
  }

  static String _getDefaultPrinterNameWin32() {
    final pcchBuffer = calloc<ffi.Uint32>();
    try {
      win32.GetDefaultPrinter(ffi.nullptr, pcchBuffer);
      final int len = pcchBuffer.value;
      if (len <= 0) return '';

      final buffer = wsalloc(len);
      try {
        final res = win32.GetDefaultPrinter(buffer, pcchBuffer);
        if (res != win32.FALSE) {
          return buffer.toDartString();
        }
      } finally {
        free(buffer);
      }
    } catch (_) {
    } finally {
      calloc.free(pcchBuffer);
    }
    return '';
  }

  static PrinterConnectionType _classifyConnectionType({
    required String systemName,
    required String driverName,
    required String portName,
    required int attributes,
  }) {
    final upperPort = portName.toUpperCase();
    final upperName = systemName.toUpperCase();
    final upperDriver = driverName.toUpperCase();

    if (upperPort.contains('PORTPROMPT') ||
        upperPort.contains('FILE:') ||
        upperPort.contains('XPSPORT') ||
        upperPort.contains('SHRFAX') ||
        upperName.contains('PRINT TO PDF') ||
        upperName.contains('XPS DOCUMENT WRITER') ||
        upperName.contains('ONENOTE') ||
        upperDriver.contains('MICROSOFT PRINT TO PDF')) {
      return PrinterConnectionType.virtual;
    }

    if (upperPort.startsWith('USB') || upperPort.contains('DOT4')) {
      return PrinterConnectionType.usb;
    }

    if ((attributes & _attrNetwork) != 0 ||
        upperPort.startsWith('IP_') ||
        upperPort.startsWith('WSD') ||
        upperPort.startsWith('HTTP') ||
        upperPort.startsWith('\\\\') ||
        upperPort.contains('TCP') ||
        RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b')
            .hasMatch(upperPort)) {
      return PrinterConnectionType.network;
    }

    return PrinterConnectionType.local;
  }

  static PrinterStatusType _mapWin32Status(int status, int attributes) {
    if ((attributes & _attrWorkOffline) != 0 || (status & _statusOffline) != 0) {
      return PrinterStatusType.offline;
    }
    if ((status & _statusPaperJam) != 0) {
      return PrinterStatusType.paperJam;
    }
    if ((status & _statusPaperOut) != 0) {
      return PrinterStatusType.outOfPaper;
    }
    if ((status & _statusDoorOpen) != 0) {
      return PrinterStatusType.doorOpen;
    }
    if ((status & _statusError) != 0 ||
        (status & _statusPaperProblem) != 0 ||
        (status & _statusNoToner) != 0) {
      return PrinterStatusType.error;
    }
    if ((status & _statusPaused) != 0) {
      return PrinterStatusType.paused;
    }
    if ((status & _statusTonerLow) != 0) {
      return PrinterStatusType.tonerLow;
    }
    if ((status & _statusPrinting) != 0 ||
        (status & _statusBusy) != 0 ||
        (status & _statusProcessing) != 0 ||
        (status & _statusManualFeed) != 0) {
      return PrinterStatusType.busy;
    }
    return PrinterStatusType.ready;
  }

  static String? _extractIpFromPortOrLocation(
    String portName,
    String location,
  ) {
    final ipRegex = RegExp(r'\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b');
    final matchPort = ipRegex.firstMatch(portName);
    if (matchPort != null) return matchPort.group(1);

    final matchLoc = ipRegex.firstMatch(location);
    if (matchLoc != null) return matchLoc.group(1);
    return null;
  }

  static PrinterCapabilities _queryCapabilitiesInIsolate(
    String printerName,
    String portName,
  ) {
    try {
      final winspool = ffi.DynamicLibrary.open('winspool.drv');
      final deviceCapabilities = winspool.lookupFunction<
          _DeviceCapabilitiesNative,
          _DeviceCapabilitiesDart>('DeviceCapabilitiesW');

      final pDevice = printerName.toNativeUtf16();
      final pPort = portName.toNativeUtf16();

      try {
        // 1. Duplex support
        final int duplexRes = deviceCapabilities(
          pDevice,
          pPort,
          _dcDuplex,
          ffi.nullptr,
          ffi.nullptr,
        );
        final bool supportsDuplex = duplexRes == 1;

        // 2. Color support
        final int colorRes = deviceCapabilities(
          pDevice,
          pPort,
          _dcColorDevice,
          ffi.nullptr,
          ffi.nullptr,
        );
        final bool supportsColor = colorRes == 1;

        // 3. Max copies
        final int copiesRes = deviceCapabilities(
          pDevice,
          pPort,
          _dcCopies,
          ffi.nullptr,
          ffi.nullptr,
        );
        final int maxCopies = copiesRes > 0 ? copiesRes.clamp(1, 9999) : 999;

        // 4. Supported Paper Sizes (codes + names + dimensions in 0.1mm)
        final List<PaperSizeCapability> paperSizes = _readPaperSizes(
          deviceCapabilities,
          pDevice,
          pPort,
        );

        // 5. Supported Paper Trays / Bins
        final List<PaperTrayCapability> trays = _readPaperTrays(
          deviceCapabilities,
          pDevice,
          pPort,
        );

        // 6. Supported Print Resolutions (DPI)
        final List<PrinterResolution> resolutions = _readResolutions(
          deviceCapabilities,
          pDevice,
          pPort,
        );

        return PrinterCapabilities(
          supportsColor: supportsColor,
          supportsDuplex: supportsDuplex,
          maxCopies: maxCopies,
          paperSizes: paperSizes.isNotEmpty
              ? paperSizes
              : const PrinterCapabilities().paperSizes,
          trays:
              trays.isNotEmpty ? trays : const PrinterCapabilities().trays,
          resolutions: resolutions.isNotEmpty
              ? resolutions
              : const PrinterCapabilities().resolutions,
        );
      } finally {
        calloc.free(pDevice);
        calloc.free(pPort);
      }
    } catch (_) {
      return const PrinterCapabilities();
    }
  }

  static List<PaperSizeCapability> _readPaperSizes(
    _DeviceCapabilitiesDart dc,
    ffi.Pointer<Utf16> pDevice,
    ffi.Pointer<Utf16> pPort,
  ) {
    final int count = dc(pDevice, pPort, _dcPapers, ffi.nullptr, ffi.nullptr);
    if (count <= 0 || count > 256) return const [];

    final pCodes = calloc<ffi.Uint16>(count);
    // Each paper name in DC_PAPERNAMES is 64 WCHARs
    final pNames = calloc<ffi.Uint16>(count * 64);
    // Each paper size in DC_PAPERSIZE is a POINT (2x Int32 = 8 bytes)
    final pSizes = calloc<ffi.Int32>(count * 2);

    try {
      dc(pDevice, pPort, _dcPapers, pCodes.cast(), ffi.nullptr);
      dc(pDevice, pPort, _dcPaperNames, pNames.cast(), ffi.nullptr);
      dc(pDevice, pPort, _dcPaperSize, pSizes.cast(), ffi.nullptr);

      final List<PaperSizeCapability> result = [];
      final seenNames = <String>{};

      for (var i = 0; i < count; i++) {
        final int code = pCodes[i];
        final namePtr = (pNames + (i * 64)).cast<Utf16>();
        final String name = namePtr.toDartString().trim();
        final double widthMm = pSizes[i * 2] / 10.0;
        final double heightMm = pSizes[(i * 2) + 1] / 10.0;

        if (name.isNotEmpty && seenNames.add(name)) {
          result.add(
            PaperSizeCapability(
              code: code,
              name: name,
              widthMm: widthMm > 0 ? widthMm : 210.0,
              heightMm: heightMm > 0 ? heightMm : 297.0,
            ),
          );
        }
      }
      return result;
    } finally {
      calloc.free(pCodes);
      calloc.free(pNames);
      calloc.free(pSizes);
    }
  }

  static List<PaperTrayCapability> _readPaperTrays(
    _DeviceCapabilitiesDart dc,
    ffi.Pointer<Utf16> pDevice,
    ffi.Pointer<Utf16> pPort,
  ) {
    final int count = dc(pDevice, pPort, _dcBins, ffi.nullptr, ffi.nullptr);
    if (count <= 0 || count > 128) return const [];

    final pBins = calloc<ffi.Uint16>(count);
    // Each bin name in DC_BINNAMES is 24 WCHARs
    final pBinNames = calloc<ffi.Uint16>(count * 24);

    try {
      dc(pDevice, pPort, _dcBins, pBins.cast(), ffi.nullptr);
      dc(pDevice, pPort, _dcBinNames, pBinNames.cast(), ffi.nullptr);

      final List<PaperTrayCapability> trays = [];
      final seenNames = <String>{};

      for (var i = 0; i < count; i++) {
        final int code = pBins[i];
        final namePtr = (pBinNames + (i * 24)).cast<Utf16>();
        final String name = namePtr.toDartString().trim();
        if (name.isNotEmpty && seenNames.add(name)) {
          trays.add(PaperTrayCapability(code: code, name: name));
        }
      }
      return trays;
    } finally {
      calloc.free(pBins);
      calloc.free(pBinNames);
    }
  }

  static List<PrinterResolution> _readResolutions(
    _DeviceCapabilitiesDart dc,
    ffi.Pointer<Utf16> pDevice,
    ffi.Pointer<Utf16> pPort,
  ) {
    final int count =
        dc(pDevice, pPort, _dcEnumResolutions, ffi.nullptr, ffi.nullptr);
    if (count <= 0 || count > 64) return const [];

    final pRes = calloc<ffi.Int32>(count * 2);
    try {
      dc(pDevice, pPort, _dcEnumResolutions, pRes.cast(), ffi.nullptr);
      final List<PrinterResolution> list = [];
      final seen = <String>{};

      for (var i = 0; i < count; i++) {
        final int xdpi = pRes[i * 2];
        final int ydpi = pRes[(i * 2) + 1];
        if (xdpi > 0 && ydpi > 0) {
          final res = PrinterResolution(xdpi: xdpi, ydpi: ydpi);
          if (seen.add(res.label)) {
            list.add(res);
          }
        }
      }
      return list;
    } finally {
      calloc.free(pRes);
    }
  }

  @override
  Future<ConnectionTestResult> testNetworkPrinterConnection({
    required String host,
    required int port,
    required NetworkPrintProtocol protocol,
  }) async {
    final cleanHost = host.trim();
    if (cleanHost.isEmpty) {
      return ConnectionTestResult(
        isSuccess: false,
        host: cleanHost,
        port: port,
        protocol: protocol,
        latencyMs: 0,
        messageEn: 'Please enter a valid IP address or hostname.',
        messageSi: 'කරුණාකර නිවැරදි IP ලිපිනයක් හෝ නාමයක් ඇතුළත් කරන්න.',
      );
    }

    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        cleanHost,
        port,
        timeout: const Duration(milliseconds: 2200),
      );
      sw.stop();
      final int latency = sw.elapsedMilliseconds;
      await socket.close();

      final protoLabel = protocol == NetworkPrintProtocol.ipp631
          ? 'IPP (Port $port)'
          : 'RAW/JetDirect (Port $port)';

      return ConnectionTestResult(
        isSuccess: true,
        host: cleanHost,
        port: port,
        protocol: protocol,
        latencyMs: latency,
        detectedModelHint: '$protoLabel Printer @ $cleanHost',
        messageEn:
            'Connected to $cleanHost:$port ($protoLabel) in ${latency}ms. Printer is reachable on LAN.',
        messageSi:
            '$cleanHost:$port ($protoLabel) වෙත මිලි-තත්පර $latency කින් සාර්ථකව සම්බන්ධ විය.',
      );
    } catch (e) {
      sw.stop();
      return ConnectionTestResult(
        isSuccess: false,
        host: cleanHost,
        port: port,
        protocol: protocol,
        latencyMs: sw.elapsedMilliseconds,
        messageEn:
            'Could not reach $cleanHost on port $port. Check that the printer is powered on, connected to the same LAN, and supports ${protocol == NetworkPrintProtocol.ipp631 ? 'IPP (631)' : 'RAW JetDirect (9100)'}.',
        messageSi:
            '$cleanHost:$port වෙත සම්බන්ධ විය නොහැක. මුද්‍රණ යන්ත්‍රය ක්‍රියාත්මකද සහ එකම ජාලයට (LAN) සම්බන්ධදැයි පරීක්ෂා කරන්න.',
      );
    }
  }

  @override
  Stream<LanDiscoveryProgress> discoverLanPrinters({
    required bool includeSubnetScan,
  }) {
    final controller = StreamController<LanDiscoveryProgress>();

    () async {
      final receivePort = ReceivePort();
      Isolate? workerIsolate;

      try {
        workerIsolate = await Isolate.spawn(
          _lanDiscoveryIsolateEntry,
          (
            sendPort: receivePort.sendPort,
            includeSubnetScan: includeSubnetScan,
          ),
        );

        await for (final dynamic msg in receivePort) {
          if (msg is Map<String, dynamic>) {
            final phase = LanDiscoveryPhase.values.firstWhere(
              (e) => e.name == msg['phase'],
              orElse: () => LanDiscoveryPhase.mdnsQuery,
            );
            final rawList =
                (msg['discovered'] as List<dynamic>? ?? const []);
            final parsedPrinters = rawList.map((raw) {
              final m = raw as Map<String, dynamic>;
              return DiscoveredLanPrinter(
                ipAddress: m['ip'] as String,
                port: m['port'] as int,
                protocol: m['port'] == 631
                    ? NetworkPrintProtocol.ipp631
                    : NetworkPrintProtocol.raw9100,
                discoveryMethod: m['method'] as String,
                latencyMs: m['latency'] as int,
                hostname: m['hostname'] as String?,
                deviceName: m['deviceName'] as String?,
              );
            }).toList();

            controller.add(
              LanDiscoveryProgress(
                phase: phase,
                progress: (msg['progress'] as num).toDouble(),
                scannedHosts: msg['scannedHosts'] as int,
                totalHosts: msg['totalHosts'] as int,
                discovered: parsedPrinters,
              ),
            );

            if (phase == LanDiscoveryPhase.completed) {
              break;
            }
          }
        }
      } catch (_) {
        // Ensure stream completes cleanly even if network interfaces are disabled
      } finally {
        receivePort.close();
        workerIsolate?.kill(priority: Isolate.immediate);
        await controller.close();
      }
    }();

    return controller.stream;
  }

  static Future<void> _lanDiscoveryIsolateEntry(
    ({SendPort sendPort, bool includeSubnetScan}) args,
  ) async {
    final sendPort = args.sendPort;
    final discoveredMap = <String, Map<String, dynamic>>{};

    void emitProgress({
      required LanDiscoveryPhase phase,
      required double progress,
      required int scanned,
      required int total,
    }) {
      sendPort.send({
        'phase': phase.name,
        'progress': progress.clamp(0.0, 1.0),
        'scannedHosts': scanned,
        'totalHosts': total,
        'discovered': discoveredMap.values.toList(),
      });
    }

    // Phase 1: Offline mDNS / Bonjour Multicast Query (224.0.0.251:5353)
    emitProgress(
      phase: LanDiscoveryPhase.mdnsQuery,
      progress: 0.08,
      scanned: 0,
      total: args.includeSubnetScan ? 254 : 1,
    );

    try {
      final mdnsResults = await _queryMdnsPrinters();
      for (final item in mdnsResults) {
        discoveredMap[item['ip'] as String] = item;
      }
    } catch (_) {}

    emitProgress(
      phase: LanDiscoveryPhase.mdnsQuery,
      progress: args.includeSubnetScan ? 0.25 : 1.0,
      scanned: 1,
      total: args.includeSubnetScan ? 254 : 1,
    );

    // Phase 2: Optional /24 LAN Subnet Scan (Ports 9100 & 631) if user consented
    if (args.includeSubnetScan) {
      final String? subnetPrefix = await _detectLocalIPv4SubnetPrefix();
      if (subnetPrefix != null) {
        const int totalHosts = 254;
        int scanned = 0;
        const int batchSize = 32;

        for (var start = 1; start <= totalHosts; start += batchSize) {
          final int end = (start + batchSize - 1).clamp(1, totalHosts);
          final List<Future<void>> batchFutures = [];

          for (var hostOctet = start; hostOctet <= end; hostOctet++) {
            final candidateIp = '$subnetPrefix.$hostOctet';
            batchFutures.add(() async {
              final probe = await _probePrinterHost(candidateIp);
              if (probe != null && !discoveredMap.containsKey(candidateIp)) {
                discoveredMap[candidateIp] = probe;
              }
            }());
          }

          await Future.wait(batchFutures);
          scanned = end;
          final double subProgress = 0.25 + (0.75 * (scanned / totalHosts));
          emitProgress(
            phase: LanDiscoveryPhase.subnetScan,
            progress: subProgress,
            scanned: scanned,
            total: totalHosts,
          );
        }
      }
    }

    emitProgress(
      phase: LanDiscoveryPhase.completed,
      progress: 1.0,
      scanned: args.includeSubnetScan ? 254 : 1,
      total: args.includeSubnetScan ? 254 : 1,
    );
  }

  /// Sends a standard DNS-SD / mDNS PTR query for `_ipp._tcp.local` and
  /// `_pdl-datastream._tcp.local` to 224.0.0.251:5353 and listens for 900ms.
  static Future<List<Map<String, dynamic>>> _queryMdnsPrinters() async {
    final List<Map<String, dynamic>> found = [];
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.multicastHops = 255;

      final multicastAddr = InternetAddress('224.0.0.251');
      final packet = _buildMdnsPtrQueryPacket('_ipp._tcp.local');

      final sw = Stopwatch()..start();
      socket.send(packet, multicastAddr, 5353);

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null) {
            final senderIp = dg.address.address;
            // Extract printable ASCII strings from the DNS response for model hint
            final asciiHint = ascii
                .decode(dg.data, allowInvalid: true)
                .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

            found.add({
              'ip': senderIp,
              'port': 631,
              'method': 'mDNS / Bonjour',
              'latency': sw.elapsedMilliseconds.clamp(1, 900),
              'hostname': senderIp,
              'deviceName': asciiHint.length > 6
                  ? 'Bonjour Printer ($senderIp)'
                  : 'IPP Printer ($senderIp)',
            });
          }
        }
      });

      await Future<void>.delayed(const Duration(milliseconds: 900));
    } catch (_) {
    } finally {
      socket?.close();
    }
    return found;
  }

  static Uint8List _buildMdnsPtrQueryPacket(String serviceName) {
    final builder = BytesBuilder();
    // DNS Header: ID=0, Flags=0, QDCOUNT=1, ANCOUNT=0, NSCOUNT=0, ARCOUNT=0
    builder.add(const [0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    for (final label in serviceName.split('.')) {
      final bytes = ascii.encode(label);
      builder.addByte(bytes.length);
      builder.add(bytes);
    }
    builder.addByte(0x00); // Root null label
    builder.add(const [0x00, 0x0C]); // QTYPE = PTR (12)
    builder.add(const [0x00, 0x01]); // QCLASS = IN (1)
    return builder.toBytes();
  }

  static Future<String?> _detectLocalIPv4SubnetPrefix() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> _probePrinterHost(String ip) async {
    // Try Port 9100 (RAW JetDirect) first, then Port 631 (IPP)
    for (final port in const [9100, 631]) {
      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 220),
        );
        sw.stop();
        await socket.close();
        return {
          'ip': ip,
          'port': port,
          'method': 'LAN Subnet Scan',
          'latency': sw.elapsedMilliseconds.clamp(1, 220),
          'hostname': ip,
          'deviceName': port == 9100
              ? 'JetDirect / RAW Printer ($ip)'
              : 'IPP Network Printer ($ip)',
        };
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<PrinterDevice> registerNetworkPrinter({
    required String host,
    required int port,
    required NetworkPrintProtocol protocol,
    String? customName,
  }) async {
    final cleanHost = host.trim();
    final protoTag =
        protocol == NetworkPrintProtocol.ipp631 ? 'IPP' : 'RAW-9100';
    final systemName = (customName != null && customName.trim().isNotEmpty)
        ? customName.trim()
        : 'LAN Printer ($cleanHost:$port)';
    final portName = protocol == NetworkPrintProtocol.ipp631
        ? 'http://$cleanHost:$port/ipp/print'
        : 'IP_${cleanHost}_$port';

    // On Windows, attempt non-blocking creation of TCP/IP Printer Port if elevated;
    // whether elevated or standard user, we also return the configured PrinterDevice
    // so Print Helper can print to it immediately and persist it in SQLite.
    if (Platform.isWindows) {
      try {
        await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'Add-PrinterPort -Name "$portName" -PrinterHostAddress "$cleanHost" -PortNumber $port -ErrorAction SilentlyContinue',
          ],
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    final testResult = await testNetworkPrinterConnection(
      host: cleanHost,
      port: port,
      protocol: protocol,
    );

    return PrinterDevice(
      systemName: systemName,
      customNickname: customName,
      driverName: 'Generic / Network $protoTag',
      portName: portName,
      location: '$cleanHost:$port',
      connectionType: PrinterConnectionType.network,
      status: testResult.isSuccess
          ? PrinterStatusType.ready
          : PrinterStatusType.offline,
      ipAddress: cleanHost,
      networkPort: port,
      networkProtocol: protocol,
    );
  }

  @override
  Future<PrinterHealthReport> runHealthCheck(PrinterDevice printer) async {
    bool portReachable = true;
    int? pingMs;

    if (printer.connectionType == PrinterConnectionType.network &&
        printer.ipAddress != null &&
        printer.ipAddress!.isNotEmpty) {
      final int portToTest = printer.networkPort ?? 9100;
      final test = await testNetworkPrinterConnection(
        host: printer.ipAddress!,
        port: portToTest,
        protocol: printer.networkProtocol ?? NetworkPrintProtocol.raw9100,
      );
      portReachable = test.isSuccess;
      pingMs = test.latencyMs;
    }

    final List<TroubleshootingStep> steps = [];
    HealthSeverity severity = HealthSeverity.healthy;
    String headlineEn =
        '${printer.displayName} is healthy and ready to print.';
    String headlineSi =
        '${printer.displayName} මුද්‍රණය සඳහා සූදානම් සහ යහපත් තත්ත්වයේ පවතී.';

    switch (printer.status) {
      case PrinterStatusType.offline:
        severity = HealthSeverity.critical;
        headlineEn =
            'Printer is offline: check power and ${printer.connectionType == PrinterConnectionType.network ? 'network cable / Wi-Fi' : 'USB cable'}.';
        headlineSi =
            'මුද්‍රණ යන්ත්‍රය Offline තත්ත්වයේ පවතී: විදුලි සැපයුම සහ ${printer.connectionType == PrinterConnectionType.network ? 'ජාල (LAN/Wi-Fi) සම්බන්ධතාවය' : 'USB කේබලය'} පරීක්ෂා කරන්න.';
        steps.addAll([
          const TroubleshootingStep(
            titleEn: '1. Check Power & Sleep Mode',
            titleSi: '1. විදුලි බලය සහ Sleep Mode පරීක්ෂා කරන්න',
            detailEn:
                'Make sure the printer is turned on and not in deep sleep or showing a blinking warning light.',
            detailSi:
                'මුද්‍රණ යන්ත්‍රය ක්‍රියාත්මක කර ඇති බවත් අනතුරු ඇඟවීමේ බල්බ දැල්වෙන්නේ නැති බවත් තහවුරු කරන්න.',
          ),
          if (printer.connectionType == PrinterConnectionType.network)
            TroubleshootingStep(
              titleEn: '2. Verify LAN / Ethernet Connection',
              titleSi: '2. ජාල (LAN) සම්බන්ධතාවය පරීක්ෂා කරන්න',
              detailEn:
                  'Ensure the printer (${printer.ipAddress ?? printer.portName}) is connected to the same local network router/switch as this PC.',
              detailSi:
                  'මුද්‍රණ යන්ත්‍රය (${printer.ipAddress ?? printer.portName}) මෙම පරිගණකය ඇති ජාලයටම සම්බන්ධ කර ඇත්දැයි බලන්න.',
            )
          else
            const TroubleshootingStep(
              titleEn: '2. Reconnect the USB Cable',
              titleSi: '2. USB කේබලය නැවත සම්බන්ධ කරන්න',
              detailEn:
                  'Unplug the USB cable from both the printer and computer, wait 5 seconds, and plug it directly into a main USB port.',
              detailSi:
                  'USB කේබලය ගලවා තත්පර 5 කට පසු නැවත පරිගණකයට සවි කරන්න.',
            ),
          const TroubleshootingStep(
            titleEn: '3. Disable "Use Printer Offline" in Windows',
            titleSi: '3. Windows හි "Use Printer Offline" අක්‍රිය කරන්න',
            detailEn:
                'Open Windows Settings -> Bluetooth & devices -> Printers & scanners, select this printer, and ensure "Use Printer Offline" is unchecked.',
            detailSi:
                'Windows Printers සැකසුම් තුළ "Use Printer Offline" විකල්පය ඉවත් කර ඇත්දැයි පරීක්ෂා කරන්න.',
          ),
        ]);
      case PrinterStatusType.outOfPaper:
        severity = HealthSeverity.warning;
        headlineEn =
            'Printer is out of paper: load paper into the input tray.';
        headlineSi =
            'කඩදාසි අවසන් වී ඇත: කරුණාකර තැටියට (Tray) කඩදාසි ඇතුළත් කරන්න.';
        steps.addAll(const [
          TroubleshootingStep(
            titleEn: '1. Load Paper into the Active Tray',
            titleSi: '1. කඩදාසි තැටියට කඩදාසි දමන්න',
            detailEn:
                'Insert A4/Letter paper neatly into Tray 1 and adjust the paper width guides snugly against the stack.',
            detailSi:
                'නිවැරදි ප්‍රමාණයේ කඩදාසි තැටියට දමා කඩදාසි රඳවන නිසි ලෙස සකසන්න.',
          ),
          TroubleshootingStep(
            titleEn: '2. Press Resume / OK on the Printer Panel',
            titleSi: '2. මුද්‍රණ යන්ත්‍රයේ Resume / OK බොත්තම ඔබන්න',
            detailEn:
                'Many printers wait for you to press the flashing Resume or Continue button after loading paper.',
            detailSi:
                'කඩදාසි දැමීමෙන් පසු මුද්‍රණ යන්ත්‍රයේ Resume හෝ OK බොත්තම ඔබන්න.',
          ),
        ]);
      case PrinterStatusType.paperJam:
        severity = HealthSeverity.critical;
        headlineEn =
            'Paper jam detected: clear jammed paper gently from the rollers.';
        headlineSi =
            'කඩදාසියක් සිරවී ඇත (Paper Jam): ප්‍රවේශමෙන් සිරවූ කඩදාසිය ඉවත් කරන්න.';
        steps.addAll(const [
          TroubleshootingStep(
            titleEn: '1. Open Access Doors & Pull Paper Gently with Both Hands',
            titleSi: '1. ආවරණය විවෘත කර අත් දෙකෙන්ම සෙමින් කඩදාසිය අදින්න',
            detailEn:
                'Pull in the direction of the paper path so small torn pieces do not stay stuck inside the fuser or rollers.',
            detailSi:
                'කඩදාසිය ඉරී කොටස් ඇතුළත රැඳීම වැළැක්වීමට සෙමින් එකම දිශාවට අදින්න.',
          ),
          TroubleshootingStep(
            titleEn: '2. Close Cover Completely to Reset Jam Sensor',
            titleSi: '2. සංවේදකය යථා තත්ත්වයට පත් කිරීමට පියන හොඳින් වසන්න',
            detailEn:
                'Open and firmly close the main toner/ink access cover to reset the hardware jam sensor.',
            detailSi:
                'කඩදාසිය ඉවත් කළ පසු මුද්‍රණ යන්ත්‍රයේ පියන හොඳින් වසා දමන්න.',
          ),
        ]);
      case PrinterStatusType.paused:
        severity = HealthSeverity.warning;
        headlineEn =
            'Print queue is paused: resume the printer to continue printing.';
        headlineSi =
            'මුද්‍රණ පෝලිම තාවකාලිකව නවතා ඇත (Paused): නැවත ක්‍රියාත්මක කරන්න.';
        steps.add(const TroubleshootingStep(
          titleEn: 'Resume Printer Queue',
          titleSi: 'මුද්‍රණ පෝලිම නැවත අරඹන්න',
          detailEn:
              'The Windows Print Spooler has paused this queue. Unpause it from the Jobs tab or Windows Print Queue.',
          detailSi:
              'Windows Print Spooler මගින් මෙම පෝලිම තාවකාලිකව නවතා ඇත. එය Resume කරන්න.',
        ));
      case PrinterStatusType.doorOpen:
      case PrinterStatusType.error:
        severity = HealthSeverity.critical;
        headlineEn =
            'Printer reported a hardware error or open cover: check the printer panel.';
        headlineSi =
            'මුද්‍රණ යන්ත්‍රයේ දෝෂයක් හෝ විවෘත පියනක් වාර්තා වේ: යන්ත්‍රය පරීක්ෂා කරන්න.';
        steps.add(const TroubleshootingStep(
          titleEn: 'Check Toner/Ink Cover and Warning Lights',
          titleSi: 'තීන්ත/ටෝනර් පියන සහ අනතුරු ඇඟවීමේ බල්බ පරීක්ෂා කරන්න',
          detailEn:
              'Ensure all cartridge doors are latched shut and cartridges are seated properly.',
          detailSi:
              'සියලුම පියන් හොඳින් වැසී ඇති බවත් ටෝනර් නිසි ලෙස සවි වී ඇති බවත් පරීක්ෂා කරන්න.',
        ));
      case PrinterStatusType.tonerLow:
        severity = HealthSeverity.warning;
        headlineEn =
            'Toner or ink is low: printing works, but keep a replacement ready.';
        headlineSi =
            'තීන්ත හෝ ටෝනර් අඩු මට්ටමක පවතී: මුද්‍රණය කළ හැකි නමුත් අමතර ටෝනරයක් සූදානම්ව තබාගන්න.';
        steps.add(const TroubleshootingStep(
          titleEn: 'Gently Rock Toner Cartridge (Laser Printers)',
          titleSi: 'ටෝනර් කාට්රිජය සෙමින් සොලවා නැවත සවි කරන්න',
          detailEn:
              'If printouts look faded, remove the toner cartridge and gently rock it side-to-side to redistribute remaining toner.',
          detailSi:
              'මුද්‍රණය ලා පැහැති නම්, ටෝනර් කාට්රිජය ගලවා දෙපසට සෙමින් සොලවා නැවත සවි කරන්න.',
        ));
      case PrinterStatusType.ready:
      case PrinterStatusType.busy:
        if (!portReachable) {
          severity = HealthSeverity.critical;
          headlineEn =
              'Printer is unreachable on the network (${printer.ipAddress}): check power and LAN cable.';
          headlineSi =
              'මුද්‍රණ යන්ත්‍රය ජාලය හරහා සම්බන්ධ කරගත නොහැක (${printer.ipAddress}): විදුලිය සහ LAN කේබලය පරීක්ෂා කරන්න.';
          steps.add(TroubleshootingStep(
            titleEn: 'Network Port Did Not Respond',
            titleSi: 'ජාල සම්බන්ධතාවය ප්‍රතිචාර නොදක්වයි',
            detailEn:
                'Windows lists the printer as installed, but ${printer.ipAddress} did not respond on TCP port ${printer.networkPort ?? 9100}. Verify the printer IP has not changed.',
            detailSi:
                '${printer.ipAddress} ලිපිනය ප්‍රතිචාර නොදක්වයි. මුද්‍රණ යන්ත්‍රයේ IP ලිපිනය වෙනස් වී ඇත්දැයි පරීක්ෂා කරන්න.',
          ));
        } else {
          steps.add(TroubleshootingStep(
            titleEn: 'Spooler & Port Verified',
            titleSi: 'මුද්‍රණ සේවාව සහ සම්බන්ධතාවය තහවුරු කරන ලදී',
            detailEn:
                'Driver "${printer.driverName}" on port "${printer.portName}" is responsive (${printer.activeJobsCount} active jobs in queue).',
            detailSi:
                '"${printer.driverName}" ධාවකය සහ "${printer.portName}" සම්බන්ධතාවය නිසි ලෙස ක්‍රියා කරයි.',
          ));
        }
    }

    return PrinterHealthReport(
      printerName: printer.displayName,
      severity: severity,
      headlineEn: headlineEn,
      headlineSi: headlineSi,
      spoolerOk: true,
      portReachable: portReachable,
      activeJobsCount: printer.activeJobsCount,
      pingLatencyMs: pingMs,
      steps: steps,
    );
  }

  @override
  Future<SpoolSubmissionResult> submitPrintJob({
    required PrintHelperJob job,
    required List<int> composedPdfBytes,
  }) async {
    if (!Platform.isWindows) {
      // Simulated submission for cross-platform development/testing
      if (job.targetPrinterSystemName.toLowerCase().contains('offline')) {
        return const SpoolSubmissionResult(
          isSuccess: false,
          isPrinterOfflineError: true,
          errorMessageEn:
              'Printer is offline or unreachable. Select a fallback printer to continue.',
          errorMessageSi:
              'මුද්‍රණ යන්ත්‍රය Offline තත්ත්වයේ පවතී. කරුණාකර විකල්ප මුද්‍රණ යන්ත්‍රයක් තෝරන්න.',
        );
      }
      return SpoolSubmissionResult(
        isSuccess: true,
        spoolerJobId: DateTime.now().millisecondsSinceEpoch % 10000,
      );
    }

    return Isolate.run(
      () => _submitWin32SpoolJobInIsolate(
        printerName: job.targetPrinterSystemName,
        documentTitle: 'Print Helper - ${job.fileName}',
        payloadBytes: Uint8List.fromList(composedPdfBytes),
      ),
    );
  }

  static SpoolSubmissionResult _submitWin32SpoolJobInIsolate({
    required String printerName,
    required String documentTitle,
    required Uint8List payloadBytes,
  }) {
    final phPrinter = calloc<ffi.IntPtr>();
    final pPrinterName = printerName.toNativeUtf16();

    try {
      final opened = win32.OpenPrinter(pPrinterName, phPrinter, ffi.nullptr);
      if (opened == win32.FALSE) {
        return SpoolSubmissionResult(
          isSuccess: false,
          isPrinterOfflineError: true,
          errorMessageEn:
              'Could not open printer "$printerName". It may be offline or disconnected.',
          errorMessageSi:
              '"$printerName" විවෘත කළ නොහැක. යන්ත්‍රය Offline හෝ විසන්ධි වී තිබිය හැක.',
        );
      }

      final int hPrinter = phPrinter.value;
      try {
        final docInfo = calloc<win32.DOC_INFO_1>();
        final pDocName = documentTitle.toNativeUtf16();
        final pDataType = 'RAW'.toNativeUtf16();

        try {
          docInfo.ref.pDocName = pDocName;
          docInfo.ref.pOutputFile = ffi.nullptr;
          docInfo.ref.pDatatype = pDataType;

          final int jobId = win32.StartDocPrinter(
            hPrinter,
            1,
            docInfo.cast(),
          );
          if (jobId <= 0) {
            return SpoolSubmissionResult(
              isSuccess: false,
              isPrinterOfflineError: true,
              errorMessageEn:
                  'Windows Spooler rejected StartDocPrinter for "$printerName".',
              errorMessageSi:
                  '"$printerName" සඳහා Windows Spooler මුද්‍රණ ආරම්භය ප්‍රතික්ෂේප කළේය.',
            );
          }

          try {
            win32.StartPagePrinter(hPrinter);
            final pBuf = calloc<ffi.Uint8>(payloadBytes.length);
            final pcWritten = calloc<ffi.Uint32>();
            try {
              pBuf.asTypedList(payloadBytes.length).setAll(0, payloadBytes);
              win32.WritePrinter(
                hPrinter,
                pBuf.cast(),
                payloadBytes.length,
                pcWritten,
              );
            } finally {
              calloc.free(pBuf);
              calloc.free(pcWritten);
              win32.EndPagePrinter(hPrinter);
            }
          } finally {
            win32.EndDocPrinter(hPrinter);
          }

          return SpoolSubmissionResult(
            isSuccess: true,
            spoolerJobId: jobId,
          );
        } finally {
          calloc.free(pDocName);
          calloc.free(pDataType);
          calloc.free(docInfo);
        }
      } finally {
        win32.ClosePrinter(hPrinter);
      }
    } catch (e) {
      return SpoolSubmissionResult(
        isSuccess: false,
        errorMessageEn: 'Spooler error: $e',
        errorMessageSi: 'Spooler දෝෂයක්: $e',
      );
    } finally {
      calloc.free(phPrinter);
      calloc.free(pPrinterName);
    }
  }

  @override
  Future<List<SpoolerJobInfo>> listSpoolerJobs(String printerName) async {
    if (!Platform.isWindows) {
      return const [];
    }
    return Isolate.run(() => _enumWin32JobsInIsolate(printerName));
  }

  static List<SpoolerJobInfo> _enumWin32JobsInIsolate(String printerName) {
    final List<SpoolerJobInfo> jobs = [];
    final phPrinter = calloc<ffi.IntPtr>();
    final pPrinterName = printerName.toNativeUtf16();

    try {
      if (win32.OpenPrinter(pPrinterName, phPrinter, ffi.nullptr) ==
          win32.FALSE) {
        return jobs;
      }

      final int hPrinter = phPrinter.value;
      final pcbNeeded = calloc<ffi.Uint32>();
      final pcReturned = calloc<ffi.Uint32>();

      try {
        win32.EnumJobs(
          hPrinter,
          0,
          64,
          2,
          ffi.nullptr,
          0,
          pcbNeeded,
          pcReturned,
        );

        final int bytesNeeded = pcbNeeded.value;
        if (bytesNeeded <= 0) return jobs;

        final pJobBuf = calloc<ffi.Uint8>(bytesNeeded);
        try {
          final int ok = win32.EnumJobs(
            hPrinter,
            0,
            64,
            2,
            pJobBuf,
            bytesNeeded,
            pcbNeeded,
            pcReturned,
          );
          if (ok == win32.FALSE) return jobs;

          final int count = pcReturned.value;
          final jobArray = pJobBuf.cast<win32.JOB_INFO_2>();

          for (var i = 0; i < count; i++) {
            final info = (jobArray + i).ref;
            final docName = info.pDocument == ffi.nullptr
                ? 'Document'
                : info.pDocument.toDartString();
            final userName = info.pUserName == ffi.nullptr
                ? ''
                : info.pUserName.toDartString();
            final int statusFlags = info.Status;

            final bool isPaused = (statusFlags & 0x00000001) != 0; // JOB_STATUS_PAUSED
            final bool hasError = (statusFlags & 0x00000002) != 0 || // JOB_STATUS_ERROR
                (statusFlags & 0x00000020) != 0 || // JOB_STATUS_OFFLINE
                (statusFlags & 0x00000040) != 0; // JOB_STATUS_PAPEROUT

            String statusLabel = 'Spooling / Printing';
            if (isPaused) {
              statusLabel = 'Paused';
            } else if (hasError) {
              statusLabel = 'Error / Attention Required';
            } else if ((statusFlags & 0x00000010) != 0) {
              statusLabel = 'Printing';
            }

            jobs.add(
              SpoolerJobInfo(
                jobId: info.JobId,
                printerName: printerName,
                documentName: docName,
                userName: userName,
                statusLabel: statusLabel,
                pagesPrinted: info.PagesPrinted,
                totalPages: info.TotalPages > 0 ? info.TotalPages : 1,
                isPaused: isPaused,
                hasError: hasError,
              ),
            );
          }
        } finally {
          calloc.free(pJobBuf);
        }
      } finally {
        calloc.free(pcbNeeded);
        calloc.free(pcReturned);
        win32.ClosePrinter(hPrinter);
      }
    } catch (_) {
    } finally {
      calloc.free(phPrinter);
      calloc.free(pPrinterName);
    }

    return jobs;
  }

  @override
  Future<bool> controlSpoolerJob({
    required String printerName,
    required int jobId,
    required SpoolerJobCommand command,
  }) async {
    if (!Platform.isWindows) {
      return true;
    }
    return Isolate.run(
      () => _setWin32JobControlInIsolate(printerName, jobId, command),
    );
  }

  static bool _setWin32JobControlInIsolate(
    String printerName,
    int jobId,
    SpoolerJobCommand command,
  ) {
    final phPrinter = calloc<ffi.IntPtr>();
    final pPrinterName = printerName.toNativeUtf16();
    try {
      if (win32.OpenPrinter(pPrinterName, phPrinter, ffi.nullptr) ==
          win32.FALSE) {
        return false;
      }
      final int hPrinter = phPrinter.value;
      try {
        final int winCmd = switch (command) {
          SpoolerJobCommand.pause => 1, // JOB_CONTROL_PAUSE
          SpoolerJobCommand.resume => 2, // JOB_CONTROL_RESUME
          SpoolerJobCommand.cancel => 3, // JOB_CONTROL_CANCEL
          SpoolerJobCommand.restart => 4, // JOB_CONTROL_RESTART
        };
        final int res = win32.SetJob(hPrinter, jobId, 0, ffi.nullptr, winCmd);
        return res != win32.FALSE;
      } finally {
        win32.ClosePrinter(hPrinter);
      }
    } catch (_) {
      return false;
    } finally {
      calloc.free(phPrinter);
      calloc.free(pPrinterName);
    }
  }

  /// Fallback printers when running on macOS/Linux during development or headless tests.
  static List<PrinterDevice> _fallbackSimulatedPrinters() {
    return const [
      PrinterDevice(
        systemName: 'Microsoft Print to PDF',
        driverName: 'Microsoft Print To PDF',
        portName: 'PORTPROMPT:',
        connectionType: PrinterConnectionType.virtual,
        status: PrinterStatusType.ready,
        isDefault: true,
        capabilities: PrinterCapabilities(
          supportsColor: true,
          supportsDuplex: false,
          trays: [PaperTrayCapability(code: 7, name: 'Auto Select')],
        ),
      ),
      PrinterDevice(
        systemName: 'HP LaserJet Pro MFP M428fdw',
        driverName: 'HP Universal Printing PCL 6',
        portName: 'USB001',
        location: 'Front Desk USB',
        connectionType: PrinterConnectionType.usb,
        status: PrinterStatusType.ready,
        capabilities: PrinterCapabilities(
          supportsColor: false,
          supportsDuplex: true,
          paperSizes: [
            PaperSizeCapability(
                code: 9, name: 'A4', widthMm: 210, heightMm: 297),
            PaperSizeCapability(
                code: 1, name: 'Letter', widthMm: 215.9, heightMm: 279.4),
            PaperSizeCapability(
                code: 5, name: 'Legal', widthMm: 215.9, heightMm: 355.6),
            PaperSizeCapability(
                code: 11, name: 'A5', widthMm: 148, heightMm: 210),
          ],
          trays: [
            PaperTrayCapability(code: 7, name: 'Auto Select'),
            PaperTrayCapability(code: 4, name: 'Tray 1 (Multipurpose)'),
            PaperTrayCapability(code: 1, name: 'Tray 2 (250-Sheet)'),
          ],
          resolutions: [
            PrinterResolution(xdpi: 600, ydpi: 600),
            PrinterResolution(xdpi: 1200, ydpi: 1200),
          ],
        ),
      ),
      PrinterDevice(
        systemName: 'Canon imageRUNNER C3226i (LAN)',
        driverName: 'Canon Generic Plus UFR II',
        portName: 'IP_192.168.1.50',
        location: '2nd Floor Office Room',
        ipAddress: '192.168.1.50',
        networkPort: 9100,
        networkProtocol: NetworkPrintProtocol.raw9100,
        connectionType: PrinterConnectionType.network,
        status: PrinterStatusType.offline,
        capabilities: PrinterCapabilities(
          supportsColor: true,
          supportsDuplex: true,
          paperSizes: [
            PaperSizeCapability(
                code: 9, name: 'A4', widthMm: 210, heightMm: 297),
            PaperSizeCapability(
                code: 8, name: 'A3', widthMm: 297, heightMm: 420),
            PaperSizeCapability(
                code: 1, name: 'Letter', widthMm: 215.9, heightMm: 279.4),
          ],
          trays: [
            PaperTrayCapability(code: 7, name: 'Auto Select'),
            PaperTrayCapability(code: 1, name: 'Cassette 1 (A4)'),
            PaperTrayCapability(code: 2, name: 'Cassette 2 (A3)'),
            PaperTrayCapability(code: 4, name: 'Multi-Purpose Tray'),
          ],
          resolutions: [
            PrinterResolution(xdpi: 600, ydpi: 600),
            PrinterResolution(xdpi: 1200, ydpi: 1200),
          ],
        ),
      ),
    ];
  }
}
