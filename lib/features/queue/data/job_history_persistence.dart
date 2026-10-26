import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/print_job_models.dart';

final jobHistoryPersistenceProvider = Provider<IJobHistoryPersistence>((ref) {
  return SqliteJobHistoryPersistence();
});

abstract interface class IJobHistoryPersistence {
  Future<void> init();
  Future<void> recordJobInHistory(PrintHelperJob job);
  Future<List<PrintHelperJob>> loadHistory({String searchQuery = ''});
  Future<void> clearAllHistory();
  Future<void> applyRetentionPolicy(HistoryRetentionPolicy policy);

  Future<HistoryRetentionPolicy> loadRetentionPolicy();
  Future<void> saveRetentionPolicy(HistoryRetentionPolicy policy);

  Future<HotFolderConfig> loadHotFolderConfig();
  Future<void> saveHotFolderConfig(HotFolderConfig config);

  String buildCsvContent(List<PrintHelperJob> jobs);
  Future<File> exportHistoryToCsvFile({
    required String targetPath,
    required List<PrintHelperJob> jobs,
  });

  void dispose();
}

class SqliteJobHistoryPersistence implements IJobHistoryPersistence {
  SqliteJobHistoryPersistence({this.overrideDbPath});

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
        dbPath = p.join(supportDir.path, 'print_helper_jobs.sqlite');
      }
      _db = sqlite3.open(dbPath);
    } catch (_) {
      _db = sqlite3.openInMemory();
    }

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS job_history (
        id TEXT PRIMARY KEY,
        batch_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        doc_type TEXT NOT NULL,
        total_pages INTEGER NOT NULL,
        pages_printed INTEGER NOT NULL,
        printer_sys_name TEXT NOT NULL,
        printer_display_name TEXT NOT NULL,
        settings_json TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        error_message TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS queue_config_kv (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
  }

  @override
  Future<void> recordJobInHistory(PrintHelperJob job) async {
    await init();
    final db = _db;
    if (db == null) return;

    final row = job.toHistoryRow();
    db.execute(
      '''
      INSERT INTO job_history (
        id, batch_id, file_path, file_name, doc_type,
        total_pages, pages_printed, printer_sys_name, printer_display_name,
        settings_json, status, created_at, completed_at, error_message, retry_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        pages_printed = excluded.pages_printed,
        printer_sys_name = excluded.printer_sys_name,
        printer_display_name = excluded.printer_display_name,
        status = excluded.status,
        completed_at = excluded.completed_at,
        error_message = excluded.error_message,
        retry_count = excluded.retry_count;
      ''',
      [
        row['id'],
        row['batch_id'],
        row['file_path'],
        row['file_name'],
        row['doc_type'],
        row['total_pages'],
        row['pages_printed'],
        row['printer_sys_name'],
        row['printer_display_name'],
        row['settings_json'],
        row['status'],
        row['created_at'],
        row['completed_at'],
        row['error_message'],
        row['retry_count'],
      ],
    );
  }

  @override
  Future<List<PrintHelperJob>> loadHistory({String searchQuery = ''}) async {
    await init();
    final db = _db;
    if (db == null) return const [];

    final q = searchQuery.trim().toLowerCase();
    final ResultSet rows;
    if (q.isEmpty) {
      rows = db.select(
        'SELECT * FROM job_history ORDER BY created_at DESC LIMIT 500;',
      );
    } else {
      final likePattern = '%$q%';
      rows = db.select(
        '''
        SELECT * FROM job_history
        WHERE LOWER(file_name) LIKE ?
           OR LOWER(printer_display_name) LIKE ?
           OR LOWER(printer_sys_name) LIKE ?
           OR LOWER(status) LIKE ?
        ORDER BY created_at DESC
        LIMIT 500;
        ''',
        [likePattern, likePattern, likePattern, likePattern],
      );
    }

    return rows.map((r) => PrintHelperJob.fromHistoryRow(r)).toList();
  }

  @override
  Future<void> clearAllHistory() async {
    await init();
    _db?.execute('DELETE FROM job_history;');
  }

  @override
  Future<void> applyRetentionPolicy(HistoryRetentionPolicy policy) async {
    await init();
    final db = _db;
    if (db == null || policy == HistoryRetentionPolicy.keepAll) return;

    final int days = switch (policy) {
      HistoryRetentionPolicy.keepAll => 36500,
      HistoryRetentionPolicy.days7 => 7,
      HistoryRetentionPolicy.days30 => 30,
      HistoryRetentionPolicy.days90 => 90,
    };

    final cutoff = DateTime.now().subtract(Duration(days: days));
    db.execute(
      'DELETE FROM job_history WHERE created_at < ?;',
      [cutoff.toIso8601String()],
    );
  }

  @override
  Future<HistoryRetentionPolicy> loadRetentionPolicy() async {
    await init();
    final db = _db;
    if (db == null) return HistoryRetentionPolicy.keepAll;

    final rows = db.select(
      'SELECT value FROM queue_config_kv WHERE key = ?;',
      ['retention_policy'],
    );
    if (rows.isEmpty) return HistoryRetentionPolicy.keepAll;
    final raw = rows.first['value'] as String? ?? 'keepAll';
    return HistoryRetentionPolicy.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => HistoryRetentionPolicy.keepAll,
    );
  }

  @override
  Future<void> saveRetentionPolicy(HistoryRetentionPolicy policy) async {
    await init();
    _db?.execute(
      '''
      INSERT INTO queue_config_kv (key, value) VALUES ('retention_policy', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
      ''',
      [policy.name],
    );
    await applyRetentionPolicy(policy);
  }

  @override
  Future<HotFolderConfig> loadHotFolderConfig() async {
    await init();
    final db = _db;
    if (db == null) return const HotFolderConfig();

    final rows = db.select(
      'SELECT value FROM queue_config_kv WHERE key = ?;',
      ['hot_folder_json'],
    );
    if (rows.isEmpty) return const HotFolderConfig();

    try {
      final map = jsonDecode(rows.first['value'] as String)
          as Map<String, dynamic>;
      return HotFolderConfig(
        enabled: map['enabled'] as bool? ?? false,
        folderPath: map['folderPath'] as String? ?? '',
        presetId: map['presetId'] as String? ?? 'builtin_duplex_bw_draft',
        targetPrinterSystemName:
            map['targetPrinterSystemName'] as String? ?? '',
      );
    } catch (_) {
      return const HotFolderConfig();
    }
  }

  @override
  Future<void> saveHotFolderConfig(HotFolderConfig config) async {
    await init();
    final jsonStr = jsonEncode({
      'enabled': config.enabled,
      'folderPath': config.folderPath,
      'presetId': config.presetId,
      'targetPrinterSystemName': config.targetPrinterSystemName,
    });
    _db?.execute(
      '''
      INSERT INTO queue_config_kv (key, value) VALUES ('hot_folder_json', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
      ''',
      [jsonStr],
    );
  }

  @override
  String buildCsvContent(List<PrintHelperJob> jobs) {
    final buf = StringBuffer();
    // Header row
    buf.writeln(
      'Job ID,File Name,Document Type,Printer,Copies,Total Pages,Pages Printed,Color Mode,Duplex,Paper Size,Status,Created At,Completed At,Error Message',
    );
    for (final j in jobs) {
      final s = j.settings;
      final fields = [
        _escapeCsv(j.id),
        _escapeCsv(j.fileName),
        _escapeCsv(j.documentType.name),
        _escapeCsv(j.targetPrinterDisplayName),
        '${s.copies}',
        '${j.effectiveTotalPages}',
        '${j.pagesPrinted}',
        s.isColor ? 'Color' : 'B&W',
        _escapeCsv(s.duplex.name),
        _escapeCsv(s.paperSize),
        _escapeCsv(j.status.name),
        _escapeCsv(j.createdAt.toIso8601String()),
        _escapeCsv(j.completedAt?.toIso8601String() ?? ''),
        _escapeCsv(j.errorMessage ?? ''),
      ];
      buf.writeln(fields.join(','));
    }
    return buf.toString();
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Future<File> exportHistoryToCsvFile({
    required String targetPath,
    required List<PrintHelperJob> jobs,
  }) async {
    final csvText = buildCsvContent(jobs);
    final file = File(targetPath);
    await file.parent.create(recursive: true);
    // Prepend UTF-8 BOM (0xEF, 0xBB, 0xBF) so Microsoft Excel renders Sinhala characters accurately
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(csvText)];
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
