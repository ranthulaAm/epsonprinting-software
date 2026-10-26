import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../features/workspace/domain/print_queue_item.dart';

final queuePersistenceProvider = Provider<IQueuePersistence>((ref) {
  return SqliteQueuePersistence();
});

abstract interface class IQueuePersistence {
  Future<void> init();
  Future<List<PrintQueueItem>> loadQueue();
  Future<void> saveQueue(List<PrintQueueItem> items);
  Future<void> clearQueue();
  void dispose();
}

/// Industrial-grade ACID SQLite persistence for the print queue.
/// Never crashes even if the database file is locked or corrupted; falls back
/// gracefully to an in-memory SQLite database if disk access fails.
class SqliteQueuePersistence implements IQueuePersistence {
  Database? _db;
  final String? overrideDbPath;

  SqliteQueuePersistence({this.overrideDbPath});

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
        dbPath = p.join(supportDir.path, 'print_helper_queue.sqlite');
      }
      _db = sqlite3.open(dbPath);
    } catch (_) {
      // Fallback to in-memory database so the app never crashes on restricted disks
      _db = sqlite3.openInMemory();
    }

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS print_queue (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        extension TEXT NOT NULL,
        doc_type TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        page_count INTEGER NOT NULL,
        added_at TEXT NOT NULL,
        settings_json TEXT NOT NULL,
        thumbnail_blob BLOB,
        text_snippet TEXT,
        sort_order INTEGER NOT NULL
      );
    ''');
  }

  @override
  Future<List<PrintQueueItem>> loadQueue() async {
    await init();
    final db = _db;
    if (db == null) return const [];

    try {
      final ResultSet resultSet = db.select(
        'SELECT * FROM print_queue ORDER BY sort_order ASC;',
      );
      final List<PrintQueueItem> loaded = [];
      for (final Row row in resultSet) {
        final item = PrintQueueItem.fromStorageRow(row);
        // Verify file still exists on disk before restoring it into active queue
        if (File(item.filePath).existsSync()) {
          loaded.add(item);
        }
      }
      return loaded;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveQueue(List<PrintQueueItem> items) async {
    await init();
    final db = _db;
    if (db == null) return;

    try {
      db.execute('BEGIN TRANSACTION;');
      db.execute('DELETE FROM print_queue;');
      final stmt = db.prepare('''
        INSERT INTO print_queue (
          id, file_path, file_name, extension, doc_type,
          file_size_bytes, page_count, added_at, settings_json,
          thumbnail_blob, text_snippet, sort_order
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''');

      try {
        for (var i = 0; i < items.length; i++) {
          final map = items[i].toStorageRow(i);
          stmt.execute([
            map['id'],
            map['file_path'],
            map['file_name'],
            map['extension'],
            map['doc_type'],
            map['file_size_bytes'],
            map['page_count'],
            map['added_at'],
            map['settings_json'],
            map['thumbnail_blob'],
            map['text_snippet'],
            map['sort_order'],
          ]);
        }
      } finally {
        stmt.dispose();
      }
      db.execute('COMMIT;');
    } catch (_) {
      try {
        db.execute('ROLLBACK;');
      } catch (_) {}
    }
  }

  @override
  Future<void> clearQueue() async {
    await init();
    _db?.execute('DELETE FROM print_queue;');
  }

  @override
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
