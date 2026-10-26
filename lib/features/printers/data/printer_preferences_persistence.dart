import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../services/printer/models/printer_models.dart';
import '../../workspace/domain/print_queue_item.dart';

final printerPreferencesPersistenceProvider =
    Provider<IPrinterPreferencesPersistence>((ref) {
  return SqlitePrinterPreferencesPersistence();
});

class SavedPrinterPref {
  const SavedPrinterPref({
    required this.systemName,
    this.nickname,
    this.isFavorite = false,
  });

  final String systemName;
  final String? nickname;
  final bool isFavorite;
}

class SavedNetworkPrinterRecord {
  const SavedNetworkPrinterRecord({
    required this.systemName,
    required this.host,
    required this.port,
    required this.protocol,
    this.nickname,
  });

  final String systemName;
  final String host;
  final int port;
  final NetworkPrintProtocol protocol;
  final String? nickname;
}

abstract interface class IPrinterPreferencesPersistence {
  Future<void> init();
  Future<Map<String, SavedPrinterPref>> loadPrinterPrefs();
  Future<void> setFavorite(String systemName, bool isFavorite);
  Future<void> setNickname(String systemName, String? nickname);

  Future<Map<PrintDocumentType, String>> loadLastUsedByFileType();
  Future<void> setLastUsedForFileType(
    PrintDocumentType docType,
    String systemName,
  );

  Future<List<SavedNetworkPrinterRecord>> loadManualNetworkPrinters();
  Future<void> saveManualNetworkPrinter(SavedNetworkPrinterRecord record);
  Future<void> removeManualNetworkPrinter(String systemName);

  void dispose();
}

class SqlitePrinterPreferencesPersistence
    implements IPrinterPreferencesPersistence {
  SqlitePrinterPreferencesPersistence({this.overrideDbPath});

  final String? overrideDbPath;
  Database? _db;

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
        dbPath = p.join(supportDir.path, 'print_helper_printers.sqlite');
      }
      _db = sqlite3.open(dbPath);
    } catch (_) {
      _db = sqlite3.openInMemory();
    }

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS printer_prefs (
        system_name TEXT PRIMARY KEY,
        nickname TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS last_used_by_filetype (
        doc_type TEXT PRIMARY KEY,
        system_name TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS manual_network_printers (
        system_name TEXT PRIMARY KEY,
        host TEXT NOT NULL,
        port INTEGER NOT NULL,
        protocol TEXT NOT NULL,
        nickname TEXT
      );
    ''');
  }

  @override
  Future<Map<String, SavedPrinterPref>> loadPrinterPrefs() async {
    await init();
    final db = _db;
    if (db == null) return const {};

    final rows = db.select('SELECT * FROM printer_prefs;');
    final map = <String, SavedPrinterPref>{};
    for (final row in rows) {
      final sysName = row['system_name'] as String;
      map[sysName] = SavedPrinterPref(
        systemName: sysName,
        nickname: row['nickname'] as String?,
        isFavorite: (row['is_favorite'] as int? ?? 0) != 0,
      );
    }
    return map;
  }

  @override
  Future<void> setFavorite(String systemName, bool isFavorite) async {
    await init();
    final db = _db;
    if (db == null) return;

    final existing = db.select(
      'SELECT nickname FROM printer_prefs WHERE system_name = ?;',
      [systemName],
    );
    final String? nickname =
        existing.isNotEmpty ? existing.first['nickname'] as String? : null;

    db.execute(
      '''
      INSERT INTO printer_prefs (system_name, nickname, is_favorite)
      VALUES (?, ?, ?)
      ON CONFLICT(system_name) DO UPDATE SET is_favorite = excluded.is_favorite;
      ''',
      [systemName, nickname, isFavorite ? 1 : 0],
    );
  }

  @override
  Future<void> setNickname(String systemName, String? nickname) async {
    await init();
    final db = _db;
    if (db == null) return;

    final clean =
        (nickname == null || nickname.trim().isEmpty) ? null : nickname.trim();
    final existing = db.select(
      'SELECT is_favorite FROM printer_prefs WHERE system_name = ?;',
      [systemName],
    );
    final int fav =
        existing.isNotEmpty ? (existing.first['is_favorite'] as int? ?? 0) : 0;

    db.execute(
      '''
      INSERT INTO printer_prefs (system_name, nickname, is_favorite)
      VALUES (?, ?, ?)
      ON CONFLICT(system_name) DO UPDATE SET nickname = excluded.nickname;
      ''',
      [systemName, clean, fav],
    );
  }

  @override
  Future<Map<PrintDocumentType, String>> loadLastUsedByFileType() async {
    await init();
    final db = _db;
    if (db == null) return const {};

    final rows = db.select('SELECT * FROM last_used_by_filetype;');
    final map = <PrintDocumentType, String>{};
    for (final row in rows) {
      final docTypeName = row['doc_type'] as String;
      final sysName = row['system_name'] as String;
      final match = PrintDocumentType.values
          .where((e) => e.name == docTypeName)
          .firstOrNull;
      if (match != null) {
        map[match] = sysName;
      }
    }
    return map;
  }

  @override
  Future<void> setLastUsedForFileType(
    PrintDocumentType docType,
    String systemName,
  ) async {
    await init();
    final db = _db;
    if (db == null) return;

    db.execute(
      '''
      INSERT INTO last_used_by_filetype (doc_type, system_name)
      VALUES (?, ?)
      ON CONFLICT(doc_type) DO UPDATE SET system_name = excluded.system_name;
      ''',
      [docType.name, systemName],
    );
  }

  @override
  Future<List<SavedNetworkPrinterRecord>> loadManualNetworkPrinters() async {
    await init();
    final db = _db;
    if (db == null) return const [];

    final rows = db.select('SELECT * FROM manual_network_printers;');
    return rows.map((row) {
      final protoName = row['protocol'] as String? ?? 'raw9100';
      return SavedNetworkPrinterRecord(
        systemName: row['system_name'] as String,
        host: row['host'] as String,
        port: (row['port'] as num).toInt(),
        protocol: NetworkPrintProtocol.values.firstWhere(
          (e) => e.name == protoName,
          orElse: () => NetworkPrintProtocol.raw9100,
        ),
        nickname: row['nickname'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> saveManualNetworkPrinter(
    SavedNetworkPrinterRecord record,
  ) async {
    await init();
    final db = _db;
    if (db == null) return;

    db.execute(
      '''
      INSERT INTO manual_network_printers (system_name, host, port, protocol, nickname)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(system_name) DO UPDATE SET
        host = excluded.host,
        port = excluded.port,
        protocol = excluded.protocol,
        nickname = excluded.nickname;
      ''',
      [
        record.systemName,
        record.host,
        record.port,
        record.protocol.name,
        record.nickname,
      ],
    );
  }

  @override
  Future<void> removeManualNetworkPrinter(String systemName) async {
    await init();
    _db?.execute(
      'DELETE FROM manual_network_printers WHERE system_name = ?;',
      [systemName],
    );
  }

  @override
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
