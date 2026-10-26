import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../workspace/domain/print_queue_item.dart';

class PrintPreset {
  const PrintPreset({
    required this.id,
    required this.name,
    required this.descriptionEn,
    required this.descriptionSi,
    required this.settings,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final String descriptionEn;
  final String descriptionSi;
  final FilePrintSettings settings;
  final bool isBuiltIn;

  String description(String lang) =>
      lang == 'si' ? descriptionSi : descriptionEn;
}

final presetsPersistenceProvider = Provider<IPresetsPersistence>((ref) {
  return SqlitePresetsPersistence();
});

abstract interface class IPresetsPersistence {
  Future<void> init();
  Future<List<PrintPreset>> loadPresets();
  Future<PrintPreset> saveCustomPreset({
    required String name,
    required String description,
    required FilePrintSettings settings,
  });
  Future<void> deletePreset(String id);
  void dispose();
}

class SqlitePresetsPersistence implements IPresetsPersistence {
  SqlitePresetsPersistence({this.overrideDbPath});

  final String? overrideDbPath;
  Database? _db;
  static const _uuid = Uuid();

  static const List<PrintPreset> builtInPresets = [
    PrintPreset(
      id: 'builtin_duplex_bw_draft',
      name: 'A4 B&W double-sided',
      descriptionEn:
          'Long-edge two-sided, Monochrome (B&W), Draft/Normal quality to save ink/toner and paper.',
      descriptionSi:
          'කඩදාසි සහ තීන්ත ඉතිරි කිරීමට දෙපැත්තම (Long-Edge), A4 කළු-සුදු මුද්‍රණය.',
      isBuiltIn: true,
      settings: FilePrintSettings(
        duplex: DuplexMode.longEdge,
        isColor: false,
        quality: PrintQualityMode.draft,
        paperSize: 'A4',
        mediaType: 'Plain Paper',
      ),
    ),
    PrintPreset(
      id: 'builtin_standard_color',
      name: 'A4 color single',
      descriptionEn:
          'Single-sided A4 Portrait, full Color, Normal quality, Fit to page.',
      descriptionSi:
          'සාමාන්‍ය A4 එක් පැත්තක් පමණක් වර්ණ (Color) මුද්‍රණය.',
      isBuiltIn: true,
      settings: FilePrintSettings(
        duplex: DuplexMode.none,
        isColor: true,
        quality: PrintQualityMode.normal,
        paperSize: 'A4',
        mediaType: 'Plain Paper',
      ),
    ),
    PrintPreset(
      id: 'builtin_photo_4x6_glossy',
      name: 'Photo 4x6 glossy',
      descriptionEn:
          'Borderless 4x6 in (10x15 cm) Photo Paper Glossy, High quality, full Color.',
      descriptionSi:
          'දාර රහිත (Borderless) 4x6 අඟල් ඡායාරූප කඩදාසි (Photo Glossy) ඉහළම තත්ත්වයේ වර්ණ මුද්‍රණය.',
      isBuiltIn: true,
      settings: FilePrintSettings(
        duplex: DuplexMode.none,
        isColor: true,
        quality: PrintQualityMode.high,
        paperSize: '4x6 in (10x15 cm)',
        mediaType: 'Photo Paper Glossy',
        marginPreset: MarginPreset.none,
      ),
    ),
    PrintPreset(
      id: 'builtin_a4_bw_single',
      name: 'A4 B&W single',
      descriptionEn:
          'Single-sided A4 Portrait, Monochrome (B&W), Normal quality.',
      descriptionSi:
          'A4 එක් පැත්තක් පමණක් කළු-සුදු (B&W) සාමාන්‍ය මුද්‍රණය.',
      isBuiltIn: true,
      settings: FilePrintSettings(
        duplex: DuplexMode.none,
        isColor: false,
        quality: PrintQualityMode.normal,
        paperSize: 'A4',
        mediaType: 'Plain Paper',
      ),
    ),
    PrintPreset(
      id: 'builtin_2up_handout',
      name: '2-up Handout (Eco Save)',
      descriptionEn:
          '2 pages per sheet, Double-sided B&W, with page numbers in footer.',
      descriptionSi:
          'එක් පිටුවක පිටු 2 බැගින් දෙපැත්තම කළු-සුදු මුද්‍රණය (පිටු අංක සහිතව).',
      isBuiltIn: true,
      settings: FilePrintSettings(
        layoutMode: SheetLayoutMode.nUp,
        pagesPerSheet: 2,
        duplex: DuplexMode.longEdge,
        isColor: false,
        showPageNumbers: true,
      ),
    ),
    PrintPreset(
      id: 'builtin_booklet_fold',
      name: 'Folded Booklet (Saddle-Stitch)',
      descriptionEn:
          'Landscape 2-up booklet imposition with short-edge duplex flip for center folding.',
      descriptionSi:
          'මැදින් නවා පොතක් ලෙස සැකසිය හැකි Booklet මුද්‍රණ සැකසුම.',
      isBuiltIn: true,
      settings: FilePrintSettings(
        layoutMode: SheetLayoutMode.booklet,
        orientation: PageOrientation.landscape,
        duplex: DuplexMode.shortEdge,
        isColor: true,
      ),
    ),
    PrintPreset(
      id: 'builtin_sinhala_confidential',
      name: 'Confidential Watermark (රහසිගතයි)',
      descriptionEn:
          'Adds a diagonal "රහසිගතයි / CONFIDENTIAL" watermark, header, and page numbers.',
      descriptionSi:
          '"රහසිගතයි / CONFIDENTIAL" දිය සලකුණ (Watermark) සහ පිටු අංක එක් කරයි.',
      isBuiltIn: true,
      settings: FilePrintSettings(
        watermarkText: 'රහසිගතයි / CONFIDENTIAL',
        watermarkOpacity: 0.16,
        headerText: 'නිල ලේඛනය — Official Document',
        showPageNumbers: true,
      ),
    ),
  ];

  @override
  Future<void> init() async {
    if (_db != null) return;
    try {
      final String dbPath;
      if (overrideDbPath != null) {
        dbPath = overrideDbPath!;
      } else {
        final supportDir = await getApplicationSupportDirectory();
        await supportDir.create(recursive: true);
        dbPath = p.join(supportDir.path, 'print_helper_presets.sqlite');
      }
      _db = sqlite3.open(dbPath);
    } catch (_) {
      _db = sqlite3.openInMemory();
    }

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS custom_presets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        settings_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
  }

  @override
  Future<List<PrintPreset>> loadPresets() async {
    await init();
    final db = _db;
    if (db == null) return builtInPresets;

    final rows = db.select(
      'SELECT * FROM custom_presets ORDER BY created_at DESC;',
    );
    final customList = <PrintPreset>[];
    for (final row in rows) {
      Map<String, dynamic> map = {};
      try {
        map =
            jsonDecode(row['settings_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
      final desc = row['description'] as String? ?? '';
      customList.add(
        PrintPreset(
          id: row['id'] as String,
          name: row['name'] as String,
          descriptionEn: desc,
          descriptionSi: desc,
          settings: FilePrintSettings.fromMap(map),
          isBuiltIn: false,
        ),
      );
    }

    return [...builtInPresets, ...customList];
  }

  @override
  Future<PrintPreset> saveCustomPreset({
    required String name,
    required String description,
    required FilePrintSettings settings,
  }) async {
    await init();
    final id = 'custom_${_uuid.v4()}';
    final cleanName = name.trim().isEmpty ? 'Custom Preset' : name.trim();
    final cleanDesc = description.trim().isEmpty
        ? _autoSummary(settings)
        : description.trim();

    _db?.execute(
      '''
      INSERT INTO custom_presets (id, name, description, settings_json, created_at)
      VALUES (?, ?, ?, ?, ?);
      ''',
      [
        id,
        cleanName,
        cleanDesc,
        jsonEncode(settings.toMap()),
        DateTime.now().toIso8601String(),
      ],
    );

    return PrintPreset(
      id: id,
      name: cleanName,
      descriptionEn: cleanDesc,
      descriptionSi: cleanDesc,
      settings: settings,
      isBuiltIn: false,
    );
  }

  static String _autoSummary(FilePrintSettings s) {
    final parts = <String>[
      s.paperSize,
      s.orientation == PageOrientation.landscape ? 'Landscape' : 'Portrait',
      s.isColor ? 'Color' : 'B&W',
      switch (s.duplex) {
        DuplexMode.none => '1-Sided',
        DuplexMode.longEdge => 'Duplex (Long-Edge)',
        DuplexMode.shortEdge => 'Duplex (Short-Edge)',
      },
      if (s.layoutMode == SheetLayoutMode.nUp) '${s.pagesPerSheet}-up',
      if (s.layoutMode == SheetLayoutMode.booklet) 'Booklet',
      if (s.layoutMode == SheetLayoutMode.poster)
        'Poster ${s.posterGridSize}x${s.posterGridSize}',
      if (s.quality == PrintQualityMode.draft) 'Draft',
    ];
    return parts.join(' • ');
  }

  @override
  Future<void> deletePreset(String id) async {
    await init();
    _db?.execute('DELETE FROM custom_presets WHERE id = ?;', [id]);
  }

  @override
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}

final presetsControllerProvider =
    StateNotifierProvider<PresetsController, List<PrintPreset>>((ref) {
  final persistence = ref.watch(presetsPersistenceProvider);
  final controller = PresetsController(persistence);
  controller.load();
  return controller;
});

class PresetsController extends StateNotifier<List<PrintPreset>> {
  PresetsController(this._persistence)
      : super(SqlitePresetsPersistence.builtInPresets);

  final IPresetsPersistence _persistence;

  Future<void> load() async {
    state = await _persistence.loadPresets();
  }

  Future<PrintPreset> savePreset({
    required String name,
    String description = '',
    required FilePrintSettings settings,
  }) async {
    final created = await _persistence.saveCustomPreset(
      name: name,
      description: description,
      settings: settings,
    );
    await load();
    return created;
  }

  Future<void> deletePreset(String id) async {
    await _persistence.deletePreset(id);
    await load();
  }
}
