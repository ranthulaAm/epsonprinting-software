import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import '../../features/workspace/domain/print_queue_item.dart';
import 'models/printer_models.dart';

class DevModeVerificationReport {
  const DevModeVerificationReport({
    required this.printerName,
    required this.driverAcceptedDevMode,
    required this.requestedDuplex,
    required this.appliedDuplexCode,
    required this.requestedPaperSize,
    required this.appliedPaperSizeCode,
    required this.appliedWidthTenthsMm,
    required this.appliedHeightTenthsMm,
    required this.notes,
  });

  final String printerName;
  final bool driverAcceptedDevMode;
  final DuplexMode requestedDuplex;
  final int appliedDuplexCode; // 1=DMDUP_SIMPLEX, 2=DMDUP_VERTICAL, 3=DMDUP_HORIZONTAL
  final String requestedPaperSize;
  final int appliedPaperSizeCode;
  final int appliedWidthTenthsMm;
  final int appliedHeightTenthsMm;
  final List<String> notes;

  bool get duplexVerified => switch (requestedDuplex) {
        DuplexMode.none => appliedDuplexCode == 1,
        DuplexMode.longEdge => appliedDuplexCode == 2,
        DuplexMode.shortEdge => appliedDuplexCode == 3,
      };
}

/// Applies `FilePrintSettings` directly to a Windows printer's native `DEVMODEW`
/// via `OpenPrinterW` and `DocumentPropertiesW(DM_IN_BUFFER | DM_OUT_BUFFER)`,
/// then reads back the driver-validated `DEVMODEW` to verify what the driver
/// accepted vs. ignored/clamped.
abstract final class Win32DevModeConfigurator {
  // Win32 DEVMODE dmFields bitmasks
  static const int _dmOrientation = 0x00000001;
  static const int _dmPaperSize = 0x00000002;
  static const int _dmPaperLength = 0x00000004;
  static const int _dmPaperWidth = 0x00000008;
  static const int _dmCopies = 0x00000100;
  static const int _dmDefaultSource = 0x00000200;
  static const int _dmPrintQuality = 0x00000400;
  static const int _dmColor = 0x00000800;
  static const int _dmDuplex = 0x00001000;
  static const int _dmCollate = 0x00008000;

  // Win32 DocumentProperties mode flags
  static const int _dmOutBuffer = 2;
  static const int _dmInBuffer = 8;

  // Standard Win32 DMPAPER_* codes
  static int paperSizeCodeForName(
    String name,
    List<PaperSizeCapability> driverSizes,
  ) {
    final fromDriver = driverSizes
        .where((s) => s.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (fromDriver != null) return fromDriver.code;

    switch (name) {
      case 'Letter':
        return 1; // DMPAPER_LETTER
      case 'Legal':
        return 5; // DMPAPER_LEGAL
      case 'A3':
        return 8; // DMPAPER_A3
      case 'A4':
        return 9; // DMPAPER_A4
      case 'A5':
        return 11; // DMPAPER_A5
      case 'Custom':
        return 256; // DMPAPER_USER
      default:
        return 9; // Default A4
    }
  }

  static int duplexCodeForMode(DuplexMode mode) {
    switch (mode) {
      case DuplexMode.none:
        return 1; // DMDUP_SIMPLEX
      case DuplexMode.longEdge:
        return 2; // DMDUP_VERTICAL (Long-Edge Book Flip)
      case DuplexMode.shortEdge:
        return 3; // DMDUP_HORIZONTAL (Short-Edge Calendar/Notepad Flip)
    }
  }

  static DevModeVerificationReport verifyAndApplyDevMode({
    required PrinterDevice printer,
    required FilePrintSettings settings,
  }) {
    final int targetPaperCode = paperSizeCodeForName(
      settings.paperSize,
      printer.capabilities.paperSizes,
    );
    final int targetDuplexCode = duplexCodeForMode(settings.duplex);
    final dims = settings.effectivePaperDimensionsMm;
    final int widthTenths = (dims.widthMm * 10).round();
    final int heightTenths = (dims.heightMm * 10).round();

    if (!Platform.isWindows) {
      // Simulated verification when running on non-Windows host or unit tests
      final bool isVirtualPdf =
          printer.connectionType == PrinterConnectionType.virtual;
      final int effectiveDuplex =
          (isVirtualPdf || !printer.capabilities.supportsDuplex)
              ? 1
              : targetDuplexCode;
      final bool customRejectedByVirtual =
          isVirtualPdf && settings.paperSize == 'Custom';

      return DevModeVerificationReport(
        printerName: printer.systemName,
        driverAcceptedDevMode: true,
        requestedDuplex: settings.duplex,
        appliedDuplexCode: effectiveDuplex,
        requestedPaperSize: settings.paperSize,
        appliedPaperSizeCode: customRejectedByVirtual ? 9 : targetPaperCode,
        appliedWidthTenthsMm: widthTenths,
        appliedHeightTenthsMm: heightTenths,
        notes: [
          if (isVirtualPdf && settings.duplex != DuplexMode.none)
            'Virtual PDF driver ignored DMDUP_VERTICAL/HORIZONTAL and reset dmDuplex to 1 (DMDUP_SIMPLEX).',
          if (customRejectedByVirtual)
            'Microsoft Print to PDF rejected arbitrary DMPAPER_USER (256) dimensions in DEVMODEW; handled via Print Helper PDF page composition instead.',
        ],
      );
    }

    final phPrinter = calloc<ffi.IntPtr>();
    final pPrinterName = printer.systemName.toNativeUtf16();

    try {
      final opened = win32.OpenPrinter(pPrinterName, phPrinter, ffi.nullptr);
      if (opened == win32.FALSE) {
        return DevModeVerificationReport(
          printerName: printer.systemName,
          driverAcceptedDevMode: false,
          requestedDuplex: settings.duplex,
          appliedDuplexCode: 1,
          requestedPaperSize: settings.paperSize,
          appliedPaperSizeCode: targetPaperCode,
          appliedWidthTenthsMm: widthTenths,
          appliedHeightTenthsMm: heightTenths,
          notes: const ['OpenPrinterW failed for target device.'],
        );
      }

      final int hPrinter = phPrinter.value;
      try {
        final int devModeBytes = win32.DocumentProperties(
          win32.NULL,
          hPrinter,
          pPrinterName,
          ffi.nullptr,
          ffi.nullptr,
          0,
        );
        if (devModeBytes <= 0) {
          return DevModeVerificationReport(
            printerName: printer.systemName,
            driverAcceptedDevMode: false,
            requestedDuplex: settings.duplex,
            appliedDuplexCode: 1,
            requestedPaperSize: settings.paperSize,
            appliedPaperSizeCode: targetPaperCode,
            appliedWidthTenthsMm: widthTenths,
            appliedHeightTenthsMm: heightTenths,
            notes: const ['DocumentPropertiesW returned 0 buffer size.'],
          );
        }

        final pDevModeRaw = calloc<ffi.Uint8>(devModeBytes);
        try {
          final pDevMode = pDevModeRaw.cast<win32.DEVMODE>();
          final int gotDefault = win32.DocumentProperties(
            win32.NULL,
            hPrinter,
            pPrinterName,
            pDevMode,
            ffi.nullptr,
            _dmOutBuffer,
          );

          if (gotDefault < 0) {
            return DevModeVerificationReport(
              printerName: printer.systemName,
              driverAcceptedDevMode: false,
              requestedDuplex: settings.duplex,
              appliedDuplexCode: 1,
              requestedPaperSize: settings.paperSize,
              appliedPaperSizeCode: targetPaperCode,
              appliedWidthTenthsMm: widthTenths,
              appliedHeightTenthsMm: heightTenths,
              notes: const ['Failed to retrieve default DEVMODEW.'],
            );
          }

          // Populate requested fields in DEVMODEW
          int dmFields = pDevMode.ref.dmFields;
          dmFields |= _dmOrientation |
              _dmPaperSize |
              _dmCopies |
              _dmCollate |
              _dmColor |
              _dmDuplex |
              _dmPrintQuality;

          pDevMode.ref.dmOrientation =
              settings.orientation == PageOrientation.landscape ? 2 : 1;
          pDevMode.ref.dmPaperSize = targetPaperCode;

          if (settings.paperSize == 'Custom') {
            dmFields |= _dmPaperWidth | _dmPaperLength;
            pDevMode.ref.dmPaperWidth = widthTenths;
            pDevMode.ref.dmPaperLength = heightTenths;
          }

          pDevMode.ref.dmCopies = settings.copies.clamp(1, 999);
          pDevMode.ref.dmCollate = settings.collate ? 1 : 0;
          pDevMode.ref.dmColor = settings.isColor ? 2 : 1; // 2=DMCOLOR_COLOR, 1=DMCOLOR_MONOCHROME
          pDevMode.ref.dmDuplex = targetDuplexCode;
          pDevMode.ref.dmPrintQuality = switch (settings.quality) {
            PrintQualityMode.draft => -1, // DMRES_DRAFT
            PrintQualityMode.normal => -3, // DMRES_MEDIUM
            PrintQualityMode.high => -4, // DMRES_HIGH
          };

          final matchedTray = printer.capabilities.trays
              .where((t) => t.name == settings.paperTray)
              .firstOrNull;
          if (matchedTray != null) {
            dmFields |= _dmDefaultSource;
            pDevMode.ref.dmDefaultSource = matchedTray.code;
          }

          pDevMode.ref.dmFields = dmFields;

          // Ask the printer driver to validate and merge our modified DEVMODEW
          final int mergeRes = win32.DocumentProperties(
            win32.NULL,
            hPrinter,
            pPrinterName,
            pDevMode,
            pDevMode,
            _dmInBuffer | _dmOutBuffer,
          );

          final notes = <String>[];
          if (pDevMode.ref.dmDuplex != targetDuplexCode) {
            notes.add(
              'Driver overrode requested dmDuplex=$targetDuplexCode with ${pDevMode.ref.dmDuplex}.',
            );
          }
          if (pDevMode.ref.dmPaperSize != targetPaperCode) {
            notes.add(
              'Driver overrode requested dmPaperSize=$targetPaperCode with ${pDevMode.ref.dmPaperSize}.',
            );
          }

          return DevModeVerificationReport(
            printerName: printer.systemName,
            driverAcceptedDevMode: mergeRes >= 0,
            requestedDuplex: settings.duplex,
            appliedDuplexCode: pDevMode.ref.dmDuplex,
            requestedPaperSize: settings.paperSize,
            appliedPaperSizeCode: pDevMode.ref.dmPaperSize,
            appliedWidthTenthsMm: pDevMode.ref.dmPaperWidth,
            appliedHeightTenthsMm: pDevMode.ref.dmPaperLength,
            notes: notes,
          );
        } finally {
          calloc.free(pDevModeRaw);
        }
      } finally {
        win32.ClosePrinter(hPrinter);
      }
    } finally {
      calloc.free(phPrinter);
      calloc.free(pPrinterName);
    }
  }
}
