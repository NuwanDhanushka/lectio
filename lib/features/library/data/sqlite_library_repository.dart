import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../notebook/domain/document_note.dart';
import '../../reader/domain/document_bookmark.dart';
import '../../reader/domain/page_summary.dart';
import '../domain/library_item.dart';
import 'library_repository.dart';

class SqliteLibraryRepository implements LibraryRepository {
  SqliteLibraryRepository._();

  static final SqliteLibraryRepository instance = SqliteLibraryRepository._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'lectio.db');

    _database = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            format TEXT NOT NULL,
            progress REAL NOT NULL,
            file_size_bytes INTEGER NOT NULL,
            imported_at TEXT NOT NULL,
            last_accessed_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id INTEGER NOT NULL,
            page_number INTEGER NOT NULL,
            sentence_index INTEGER,
            sentence_text TEXT NOT NULL DEFAULT '',
            label TEXT NOT NULL DEFAULT '',
            note TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL
          )
        ''');
        await _createPageSummariesTable(db);
        await _createDocumentNotesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE bookmarks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              document_id INTEGER NOT NULL,
              page_number INTEGER NOT NULL,
              sentence_index INTEGER,
              sentence_text TEXT NOT NULL DEFAULT '',
              label TEXT NOT NULL DEFAULT '',
              note TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await _addColumnIfMissing(
            db,
            tableName: 'bookmarks',
            columnName: 'label',
            definition: "label TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 4) {
          await _addColumnIfMissing(
            db,
            tableName: 'bookmarks',
            columnName: 'sentence_index',
            definition: 'sentence_index INTEGER',
          );
          await _addColumnIfMissing(
            db,
            tableName: 'bookmarks',
            columnName: 'sentence_text',
            definition: "sentence_text TEXT NOT NULL DEFAULT ''",
          );
          await _addColumnIfMissing(
            db,
            tableName: 'bookmarks',
            columnName: 'note',
            definition: "note TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 5) {
          await _createPageSummariesTable(db);
        }
        if (oldVersion < 6) {
          await _createDocumentNotesTable(db);
        }
      },
    );

    return _database!;
  }

  Future<void> _createPageSummariesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS page_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        page_number INTEGER NOT NULL,
        summary TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(document_id, page_number)
      )
    ''');
  }

  Future<void> _createDocumentNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        kind TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        sentence_index INTEGER,
        sentence_text TEXT NOT NULL DEFAULT '',
        outline_title TEXT NOT NULL DEFAULT '',
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _addColumnIfMissing(
    Database db, {
    required String tableName,
    required String columnName,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final hasColumn = columns.any((column) => column['name'] == columnName);
    if (hasColumn) {
      return;
    }

    await db.execute('ALTER TABLE $tableName ADD COLUMN $definition');
  }

  @override
  Future<LibrarySnapshot> fetchSnapshot() async {
    final db = await database;
    final appDirectory = await getApplicationDocumentsDirectory();
    final maps = await db.query(
      'documents',
      orderBy: 'last_accessed_at DESC',
    );

    final items = <LibraryItem>[];
    for (final map in maps) {
      final storedItem = LibraryItem.fromMap(map);
      final canonicalStoredPath = canonicalizeStoredLibraryPath(
        storedItem.filePath,
      );

      if (storedItem.id != null && canonicalStoredPath != storedItem.filePath) {
        await db.update(
          'documents',
          {'file_path': canonicalStoredPath},
          where: 'id = ?',
          whereArgs: [storedItem.id],
        );
      }

      items.add(
        LibraryItem(
          id: storedItem.id,
          title: storedItem.title,
          fileName: storedItem.fileName,
          filePath: resolveStoredLibraryPath(
            storedPath: canonicalStoredPath,
            documentsPath: appDirectory.path,
          ),
          format: storedItem.format,
          progress: storedItem.progress,
          fileSizeBytes: storedItem.fileSizeBytes,
          importedAt: storedItem.importedAt,
          lastAccessedAt: storedItem.lastAccessedAt,
        ),
      );
    }
    final totalBytes = items.fold<int>(
      0,
      (sum, item) => sum + item.fileSizeBytes,
    );

    return LibrarySnapshot(
      recentItems: items,
      totalItems: items.length,
      totalBytes: totalBytes,
      lastSyncedAt: DateTime.now(),
    );
  }

  @override
  Future<LibraryItem> addDocument(LibraryItem item) async {
    final db = await database;
    final insertedId = await db.insert('documents', item.toMap());

    return LibraryItem(
      id: insertedId,
      title: item.title,
      fileName: item.fileName,
      filePath: item.filePath,
      format: item.format,
      progress: item.progress,
      fileSizeBytes: item.fileSizeBytes,
      importedAt: item.importedAt,
      lastAccessedAt: item.lastAccessedAt,
    );
  }

  @override
  Future<List<BookmarkSnapshotEntry>> fetchBookmarkSnapshot() async {
    final snapshot = await fetchSnapshot();
    final itemsById = {
      for (final item in snapshot.recentItems)
        if (item.id != null) item.id!: item,
    };
    final db = await database;
    final maps = await db.query(
      'bookmarks',
      orderBy: 'created_at DESC, page_number ASC',
    );

    return maps
        .map(DocumentBookmark.fromMap)
        .where((bookmark) => bookmark.documentId != null)
        .map((bookmark) {
          final item = itemsById[bookmark.documentId];
          if (item == null) {
            return null;
          }
          return BookmarkSnapshotEntry(item: item, bookmark: bookmark);
        })
        .whereType<BookmarkSnapshotEntry>()
        .toList(growable: false);
  }

  @override
  Future<List<DocumentNotebookSnapshotEntry>> fetchNotebookSnapshot() async {
    final snapshot = await fetchSnapshot();
    final itemsById = {
      for (final item in snapshot.recentItems)
        if (item.id != null) item.id!: item,
    };
    final db = await database;
    final maps = await db.query(
      'document_notes',
      orderBy: 'document_id ASC, page_number ASC, created_at DESC',
    );

    final notesByDocument = <int, List<DocumentNote>>{};
    for (final note in maps.map(DocumentNote.fromMap)) {
      final documentId = note.documentId;
      if (documentId == null || !itemsById.containsKey(documentId)) {
        continue;
      }
      notesByDocument.putIfAbsent(documentId, () => []).add(note);
    }

    return [
      for (final entry in notesByDocument.entries)
        DocumentNotebookSnapshotEntry(
          item: itemsById[entry.key]!,
          notes: entry.value,
        ),
    ];
  }

  @override
  Future<List<DocumentBookmark>> fetchBookmarks(LibraryItem item) async {
    if (item.id == null) {
      return const [];
    }

    final db = await database;
    final maps = await db.query(
      'bookmarks',
      where: 'document_id = ?',
      whereArgs: [item.id],
      orderBy: 'page_number ASC, sentence_index ASC, created_at ASC',
    );
    return maps
        .map((map) => DocumentBookmark.fromMap(map))
        .toList(growable: false);
  }

  @override
  Future<DocumentBookmark?> addBookmark({
    required LibraryItem item,
    required int pageNumber,
    String label = '',
    int? sentenceIndex,
    String sentenceText = '',
    String note = '',
  }) async {
    if (item.id == null) {
      return null;
    }

    final db = await database;
    final existing = await db.query(
      'bookmarks',
      where: sentenceIndex == null
          ? 'document_id = ? AND page_number = ? AND sentence_index IS NULL'
          : 'document_id = ? AND page_number = ? AND sentence_index = ?',
      whereArgs: sentenceIndex == null
          ? [item.id, pageNumber]
          : [item.id, pageNumber, sentenceIndex],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return DocumentBookmark.fromMap(existing.first);
    }

    final bookmark = DocumentBookmark(
      documentId: item.id,
      pageNumber: pageNumber,
      sentenceIndex: sentenceIndex,
      sentenceText: sentenceText.trim(),
      label: label.trim(),
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    final id = await db.insert('bookmarks', bookmark.toMap());
    return DocumentBookmark(
      id: id,
      documentId: bookmark.documentId,
      pageNumber: bookmark.pageNumber,
      sentenceIndex: bookmark.sentenceIndex,
      sentenceText: bookmark.sentenceText,
      label: bookmark.label,
      note: bookmark.note,
      createdAt: bookmark.createdAt,
    );
  }

  @override
  Future<DocumentBookmark?> updateBookmark({
    required DocumentBookmark bookmark,
    required String label,
    required String note,
  }) async {
    if (bookmark.id == null) {
      return null;
    }

    final normalizedLabel = label.trim();
    final normalizedNote = note.trim();
    final db = await database;
    await db.update(
      'bookmarks',
      {
        'label': normalizedLabel,
        'note': normalizedNote,
      },
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
    return DocumentBookmark(
      id: bookmark.id,
      documentId: bookmark.documentId,
      pageNumber: bookmark.pageNumber,
      sentenceIndex: bookmark.sentenceIndex,
      sentenceText: bookmark.sentenceText,
      label: normalizedLabel,
      note: normalizedNote,
      createdAt: bookmark.createdAt,
    );
  }

  @override
  Future<void> removeBookmark(DocumentBookmark bookmark) async {
    if (bookmark.id == null) {
      return;
    }

    final db = await database;
    await db.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
  }

  @override
  Future<PageSummary?> fetchPageSummary({
    required LibraryItem item,
    required int pageNumber,
  }) async {
    if (item.id == null) {
      return null;
    }

    final db = await database;
    final maps = await db.query(
      'page_summaries',
      where: 'document_id = ? AND page_number = ?',
      whereArgs: [item.id, pageNumber],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return PageSummary.fromMap(maps.first);
  }

  @override
  Future<PageSummary?> savePageSummary({
    required LibraryItem item,
    required int pageNumber,
    required String summary,
  }) async {
    if (item.id == null || summary.trim().isEmpty) {
      return null;
    }

    final db = await database;
    final now = DateTime.now();
    final existing = await fetchPageSummary(
      item: item,
      pageNumber: pageNumber,
    );
    if (existing == null) {
      final pageSummary = PageSummary(
        documentId: item.id,
        pageNumber: pageNumber,
        summary: summary.trim(),
        createdAt: now,
        updatedAt: now,
      );
      final id = await db.insert('page_summaries', pageSummary.toMap());
      return PageSummary(
        id: id,
        documentId: pageSummary.documentId,
        pageNumber: pageSummary.pageNumber,
        summary: pageSummary.summary,
        createdAt: pageSummary.createdAt,
        updatedAt: pageSummary.updatedAt,
      );
    }

    await db.update(
      'page_summaries',
      {
        'summary': summary.trim(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [existing.id],
    );
    return PageSummary(
      id: existing.id,
      documentId: existing.documentId,
      pageNumber: existing.pageNumber,
      summary: summary.trim(),
      createdAt: existing.createdAt,
      updatedAt: now,
    );
  }

  @override
  Future<void> removePageSummary({
    required LibraryItem item,
    required int pageNumber,
  }) async {
    if (item.id == null) {
      return;
    }

    final db = await database;
    await db.delete(
      'page_summaries',
      where: 'document_id = ? AND page_number = ?',
      whereArgs: [item.id, pageNumber],
    );
  }

  @override
  Future<DocumentNote?> addDocumentNote({
    required LibraryItem item,
    required DocumentNoteKind kind,
    required int pageNumber,
    int? sentenceIndex,
    String sentenceText = '',
    String outlineTitle = '',
    String title = '',
    required String body,
  }) async {
    if (item.id == null || body.trim().isEmpty) {
      return null;
    }

    final note = DocumentNote(
      documentId: item.id,
      kind: kind,
      pageNumber: pageNumber,
      sentenceIndex: sentenceIndex,
      sentenceText: sentenceText.trim(),
      outlineTitle: outlineTitle.trim(),
      title: title.trim(),
      body: body.trim(),
      createdAt: DateTime.now(),
    );
    final db = await database;
    final id = await db.insert('document_notes', note.toMap());
    return DocumentNote(
      id: id,
      documentId: note.documentId,
      kind: note.kind,
      pageNumber: note.pageNumber,
      sentenceIndex: note.sentenceIndex,
      sentenceText: note.sentenceText,
      outlineTitle: note.outlineTitle,
      title: note.title,
      body: note.body,
      createdAt: note.createdAt,
    );
  }

  @override
  Future<List<DocumentNote>> fetchDocumentNotes(LibraryItem item) async {
    if (item.id == null) {
      return const [];
    }

    final db = await database;
    final maps = await db.query(
      'document_notes',
      where: 'document_id = ?',
      whereArgs: [item.id],
      orderBy: 'page_number ASC, created_at DESC',
    );
    return maps.map(DocumentNote.fromMap).toList(growable: false);
  }

  @override
  Future<void> removeDocumentNote(DocumentNote note) async {
    if (note.id == null) {
      return;
    }

    final db = await database;
    await db.delete(
      'document_notes',
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  @override
  Future<LibraryItem?> updateReadingProgress({
    required LibraryItem item,
    required double progress,
    DateTime? lastAccessedAt,
  }) async {
    final normalizedProgress = progress.clamp(0.0, 1.0);
    final accessedAt = lastAccessedAt ?? DateTime.now();
    final updatedItem = LibraryItem(
      id: item.id,
      title: item.title,
      fileName: item.fileName,
      filePath: canonicalizeStoredLibraryPath(item.filePath),
      format: item.format,
      progress: normalizedProgress,
      fileSizeBytes: item.fileSizeBytes,
      importedAt: item.importedAt,
      lastAccessedAt: accessedAt,
    );

    final db = await database;
    if (item.id != null) {
      await db.update(
        'documents',
        {
          'progress': normalizedProgress,
          'last_accessed_at': accessedAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );
    } else {
      final storedPath = canonicalizeStoredLibraryPath(item.filePath);
      await db.update(
        'documents',
        {
          'progress': normalizedProgress,
          'last_accessed_at': accessedAt.toIso8601String(),
        },
        where: 'file_path = ? OR file_path = ?',
        whereArgs: [item.filePath, storedPath],
      );
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    return LibraryItem(
      id: updatedItem.id,
      title: updatedItem.title,
      fileName: updatedItem.fileName,
      filePath: resolveStoredLibraryPath(
        storedPath: updatedItem.filePath,
        documentsPath: appDirectory.path,
      ),
      format: updatedItem.format,
      progress: updatedItem.progress,
      fileSizeBytes: updatedItem.fileSizeBytes,
      importedAt: updatedItem.importedAt,
      lastAccessedAt: updatedItem.lastAccessedAt,
    );
  }

  @override
  Future<void> removeDocument(LibraryItem item) async {
    final db = await database;
    final documentId = item.id ?? await _documentIdForItem(item);

    await db.transaction((txn) async {
      if (documentId != null) {
        await txn.delete(
          'bookmarks',
          where: 'document_id = ?',
          whereArgs: [documentId],
        );
        await txn.delete(
          'page_summaries',
          where: 'document_id = ?',
          whereArgs: [documentId],
        );
        await txn.delete(
          'document_notes',
          where: 'document_id = ?',
          whereArgs: [documentId],
        );
        await txn.delete(
          'documents',
          where: 'id = ?',
          whereArgs: [documentId],
        );
        return;
      }

      if (item.filePath.isNotEmpty) {
        final storedPath = canonicalizeStoredLibraryPath(item.filePath);
        await txn.delete(
          'documents',
          where: 'file_path = ? OR file_path = ?',
          whereArgs: [item.filePath, storedPath],
        );
      }
    });

    if (item.filePath.isEmpty) {
      return;
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final file = File(
      resolveStoredLibraryPath(
        storedPath: canonicalizeStoredLibraryPath(item.filePath),
        documentsPath: appDirectory.path,
      ),
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<int?> _documentIdForItem(LibraryItem item) async {
    if (item.id != null) {
      return item.id;
    }
    if (item.filePath.isEmpty) {
      return null;
    }

    final db = await database;
    final storedPath = canonicalizeStoredLibraryPath(item.filePath);
    final maps = await db.query(
      'documents',
      columns: ['id'],
      where: 'file_path = ? OR file_path = ?',
      whereArgs: [item.filePath, storedPath],
      limit: 1,
    );
    if (maps.isEmpty) {
      return null;
    }
    return maps.first['id'] as int?;
  }
}
