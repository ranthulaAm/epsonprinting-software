import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/diagnostics/diagnostic_logger.dart';

enum EngineComponentId {
  pdfium,
  qpdf,
  tesseractOcr,
  libreOffice,
}

class OfflineEngineComponent {
  const OfflineEngineComponent({
    required this.id,
    required this.name,
    required this.version,
    required this.licenseSpdx,
    required this.isBundledInBase,
    required this.isInstalled,
    required this.executablePath,
    required this.approximateSizeMb,
    required this.capabilitiesSummaryEn,
    required this.capabilitiesSummarySi,
  });

  final EngineComponentId id;
  final String name;
  final String version;
  final String licenseSpdx;
  final bool isBundledInBase;
  final bool isInstalled;
  final String? executablePath;
  final int approximateSizeMb;
  final String capabilitiesSummaryEn;
  final String capabilitiesSummarySi;

  OfflineEngineComponent copyWith({
    bool? isInstalled,
    String? executablePath,
  }) {
    return OfflineEngineComponent(
      id: id,
      name: name,
      version: version,
      licenseSpdx: licenseSpdx,
      isBundledInBase: isBundledInBase,
      isInstalled: isInstalled ?? this.isInstalled,
      executablePath: executablePath ?? this.executablePath,
      approximateSizeMb: approximateSizeMb,
      capabilitiesSummaryEn: capabilitiesSummaryEn,
      capabilitiesSummarySi: capabilitiesSummarySi,
    );
  }
}

/// Manages permissive external PDF & OCR engines (`PDFium`, `qpdf`, `Tesseract sin+eng`, `LibreOffice`).
/// Allows optional components to be auto-detected on the system or installed from an offline `.phpack` bundle.
class LocalComponentManager extends StateNotifier<List<OfflineEngineComponent>> {
  LocalComponentManager() : super(_initialComponents) {
    detectSystemComponents();
  }

  static const List<OfflineEngineComponent> _initialComponents =
      <OfflineEngineComponent>[
    OfflineEngineComponent(
      id: EngineComponentId.pdfium,
      name: 'Google PDFium (via pdfrx)',
      version: '129.0.6668',
      licenseSpdx: 'BSD-3-Clause / MIT',
      isBundledInBase: true,
      isInstalled: true,
      executablePath: 'Built-in Native FFI (pdfium.dll)',
      approximateSizeMb: 14,
      capabilitiesSummaryEn:
          '60fps PDF rendering, zoom, outlines/bookmarks, Unicode Sinhala/English text search & selection.',
      capabilitiesSummarySi:
          'වේගවත් PDF පෙරදසුන, පිටු සලකුණු (Bookmarks), සිංහල/ඉංග්‍රීසි පෙළ සෙවීම සහ පිටපත් කිරීම.',
    ),
    OfflineEngineComponent(
      id: EngineComponentId.qpdf,
      name: 'qpdf Structural PDF Engine',
      version: '11.9.1',
      licenseSpdx: 'Apache-2.0',
      isBundledInBase: true,
      isInstalled: true,
      executablePath: 'qpdf (Isolated Child Process + Pure-Dart Fallback)',
      approximateSizeMb: 7,
      capabilitiesSummaryEn:
          'Merge, split, extract, delete, rotate, reorder, AES-256 encrypt/decrypt, linearize, and XRef repair.',
      capabilitiesSummarySi:
          'PDF ඒකාබද්ධ කිරීම (Merge), වෙන් කිරීම (Split), මුරපද යෙදීම, පිටු කරකැවීම සහ දෝෂ අලුත්වැඩියා කිරීම (Repair).',
    ),
    OfflineEngineComponent(
      id: EngineComponentId.tesseractOcr,
      name: 'Tesseract OCR Engine (sin + eng)',
      version: '5.4.0',
      licenseSpdx: 'Apache-2.0',
      isBundledInBase: false,
      isInstalled: false,
      executablePath: null,
      approximateSizeMb: 38,
      capabilitiesSummaryEn:
          'Offline Sinhala (සිංහල) & English Optical Character Recognition and searchable PDF creation.',
      capabilitiesSummarySi:
          'අන්තර්ජාලය නොමැතිව සිංහල සහ ඉංග්‍රීසි ස්කෑන් කළ ලේඛනවල අකුරු හඳුනාගැනීම (OCR).',
    ),
    OfflineEngineComponent(
      id: EngineComponentId.libreOffice,
      name: 'LibreOffice Headless Conversion Engine',
      version: '24.8.2',
      licenseSpdx: 'MPL-2.0 (Isolated CLI)',
      isBundledInBase: false,
      isInstalled: false,
      executablePath: null,
      approximateSizeMb: 190,
      capabilitiesSummaryEn:
          'Offline Word/Excel/PowerPoint (.docx, .xlsx, .pptx) to PDF and PDF to Office conversion.',
      capabilitiesSummarySi:
          'Word, Excel සහ PowerPoint ගොනු Offline ලෙස PDF බවට පරිවර්තනය කිරීම.',
    ),
  ];

  Future<void> detectSystemComponents() async {
    final updated = <OfflineEngineComponent>[];
    for (final comp in state) {
      if (comp.id == EngineComponentId.qpdf) {
        final qpdfPath = await _findExecutable(
          binaryName: Platform.isWindows ? 'qpdf.exe' : 'qpdf',
          windowsCandidatePaths: const <String>[
            r'C:\Program Files\qpdf\bin\qpdf.exe',
            r'tools\qpdf\bin\qpdf.exe',
          ],
        );
        updated.add(
          comp.copyWith(
            isInstalled: true,
            executablePath:
                qpdfPath ?? 'Pure-Dart + PDFium Engine (qpdf CLI ready)',
          ),
        );
      } else if (comp.id == EngineComponentId.tesseractOcr) {
        final tessPath = await _findExecutable(
          binaryName: Platform.isWindows ? 'tesseract.exe' : 'tesseract',
          windowsCandidatePaths: const <String>[
            r'C:\Program Files\Tesseract-OCR\tesseract.exe',
            r'tools\tesseract\tesseract.exe',
          ],
        );
        updated.add(
          comp.copyWith(
            isInstalled: tessPath != null,
            executablePath: tessPath,
          ),
        );
      } else if (comp.id == EngineComponentId.libreOffice) {
        final loPath = await _findExecutable(
          binaryName: Platform.isWindows ? 'soffice.exe' : 'soffice',
          windowsCandidatePaths: const <String>[
            r'C:\Program Files\LibreOffice\program\soffice.exe',
            r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
          ],
        );
        updated.add(
          comp.copyWith(
            isInstalled: loPath != null,
            executablePath: loPath,
          ),
        );
      } else {
        updated.add(comp);
      }
    }
    state = updated;
  }

  /// Registers an offline component package (`.phpack` or local folder) selected by the user.
  Future<bool> registerOfflinePackagePath(
    EngineComponentId id,
    String localPackageOrExePath,
  ) async {
    final file = File(localPackageOrExePath);
    final dir = Directory(localPackageOrExePath);
    if (!await file.exists() && !await dir.exists()) {
      return false;
    }

    state = state.map((comp) {
      if (comp.id == id) {
        return comp.copyWith(
          isInstalled: true,
          executablePath: p.normalize(localPackageOrExePath),
        );
      }
      return comp;
    }).toList();

    DiagnosticLogger.instance.info(
      'ComponentManager',
      'Registered offline engine component ${id.name} at $localPackageOrExePath',
    );
    return true;
  }

  String? executableFor(EngineComponentId id) {
    final match = state.where((c) => c.id == id).firstOrNull;
    return match?.executablePath;
  }

  Future<String?> _findExecutable({
    required String binaryName,
    required List<String> windowsCandidatePaths,
  }) async {
    for (final candidate in windowsCandidatePaths) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        <String>[binaryName],
      );
      if (result.exitCode == 0) {
        final firstLine = result.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .firstWhere((s) => s.isNotEmpty, orElse: () => '');
        if (firstLine.isNotEmpty && await File(firstLine).exists()) {
          return firstLine;
        }
      }
    } catch (_) {
      // Ignore if where/which fails
    }
    return null;
  }
}

final componentManagerProvider =
    StateNotifierProvider<LocalComponentManager, List<OfflineEngineComponent>>(
        (ref) {
  return LocalComponentManager();
});
