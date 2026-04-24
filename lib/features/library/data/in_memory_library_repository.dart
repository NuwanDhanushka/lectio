import '../../notebook/domain/document_note.dart';
import '../../reader/domain/document_bookmark.dart';
import '../../reader/domain/page_summary.dart';
import '../domain/library_item.dart';
import 'library_repository.dart';

class InMemoryLibraryRepository implements LibraryRepository {
  InMemoryLibraryRepository({List<LibraryItem>? seedItems})
      : _items = [...?seedItems];

  final List<LibraryItem> _items;
  final List<DocumentBookmark> _bookmarks = [];
  final List<PageSummary> _pageSummaries = [];
  final List<DocumentNote> _documentNotes = [];

  @override
  Future<LibrarySnapshot> fetchSnapshot() async {
    final items = [..._items]
      ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));

    return LibrarySnapshot(
      recentItems: items,
      totalItems: items.length,
      totalBytes: items.fold<int>(0, (sum, item) => sum + item.fileSizeBytes),
      lastSyncedAt: DateTime.now(),
    );
  }

  @override
  Future<LibraryItem> addDocument(LibraryItem item) async {
    final nextId = (_items.map((candidate) => candidate.id ?? 0).fold<int>(
              0,
              (maxId, id) => id > maxId ? id : maxId,
            )) +
        1;
    final storedItem = LibraryItem(
      id: nextId,
      title: item.title,
      fileName: item.fileName,
      filePath: item.filePath,
      format: item.format,
      progress: item.progress,
      fileSizeBytes: item.fileSizeBytes,
      importedAt: item.importedAt,
      lastAccessedAt: item.lastAccessedAt,
    );
    _items.add(storedItem);
    return storedItem;
  }

  @override
  Future<List<BookmarkSnapshotEntry>> fetchBookmarkSnapshot() async {
    final itemsById = {
      for (final item in _items)
        if (item.id != null) item.id!: item,
    };
    final entries = _bookmarks
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
    entries.sort(
      (a, b) => b.bookmark.createdAt.compareTo(a.bookmark.createdAt),
    );
    return entries;
  }

  @override
  Future<List<DocumentNotebookSnapshotEntry>> fetchNotebookSnapshot() async {
    final itemsById = {
      for (final item in _items)
        if (item.id != null) item.id!: item,
    };
    final notesByDocument = <int, List<DocumentNote>>{};
    for (final note in _documentNotes) {
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
          notes: entry.value
            ..sort((a, b) {
              final pageComparison = a.pageNumber.compareTo(b.pageNumber);
              if (pageComparison != 0) {
                return pageComparison;
              }
              return b.createdAt.compareTo(a.createdAt);
            }),
        ),
    ];
  }

  @override
  Future<List<DocumentBookmark>> fetchBookmarks(LibraryItem item) async {
    return _bookmarks
        .where((bookmark) => bookmark.documentId == item.id)
        .toList(growable: false)
      ..sort((a, b) {
        final pageComparison = a.pageNumber.compareTo(b.pageNumber);
        if (pageComparison != 0) {
          return pageComparison;
        }
        return (a.sentenceIndex ?? -1).compareTo(b.sentenceIndex ?? -1);
      });
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
    final existingIndex = _bookmarks.indexWhere(
      (bookmark) =>
          bookmark.documentId == item.id &&
          bookmark.pageNumber == pageNumber &&
          bookmark.sentenceIndex == sentenceIndex,
    );
    if (existingIndex >= 0) {
      return _bookmarks[existingIndex];
    }

    final bookmark = DocumentBookmark(
      id: _bookmarks.length + 1,
      documentId: item.id,
      pageNumber: pageNumber,
      sentenceIndex: sentenceIndex,
      sentenceText: sentenceText.trim(),
      label: label.trim(),
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    _bookmarks.add(bookmark);
    return bookmark;
  }

  @override
  Future<DocumentBookmark?> updateBookmark({
    required DocumentBookmark bookmark,
    required String label,
    required String note,
  }) async {
    final index =
        _bookmarks.indexWhere((candidate) => candidate.id == bookmark.id);
    if (index < 0) {
      return null;
    }

    final updated = DocumentBookmark(
      id: bookmark.id,
      documentId: bookmark.documentId,
      pageNumber: bookmark.pageNumber,
      sentenceIndex: bookmark.sentenceIndex,
      sentenceText: bookmark.sentenceText,
      label: label.trim(),
      note: note.trim(),
      createdAt: bookmark.createdAt,
    );
    _bookmarks[index] = updated;
    return updated;
  }

  @override
  Future<void> removeBookmark(DocumentBookmark bookmark) async {
    _bookmarks.removeWhere((candidate) => candidate.id == bookmark.id);
  }

  @override
  Future<PageSummary?> fetchPageSummary({
    required LibraryItem item,
    required int pageNumber,
  }) async {
    return _pageSummaries
        .where((summary) =>
            summary.documentId == item.id && summary.pageNumber == pageNumber)
        .firstOrNull;
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

    final now = DateTime.now();
    final existingIndex = _pageSummaries.indexWhere((candidate) =>
        candidate.documentId == item.id && candidate.pageNumber == pageNumber);
    if (existingIndex >= 0) {
      final existing = _pageSummaries[existingIndex];
      final updated = PageSummary(
        id: existing.id,
        documentId: existing.documentId,
        pageNumber: existing.pageNumber,
        summary: summary.trim(),
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      _pageSummaries[existingIndex] = updated;
      return updated;
    }

    final pageSummary = PageSummary(
      id: _pageSummaries.length + 1,
      documentId: item.id,
      pageNumber: pageNumber,
      summary: summary.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _pageSummaries.add(pageSummary);
    return pageSummary;
  }

  @override
  Future<void> removePageSummary({
    required LibraryItem item,
    required int pageNumber,
  }) async {
    _pageSummaries.removeWhere(
      (summary) =>
          summary.documentId == item.id && summary.pageNumber == pageNumber,
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
      id: _documentNotes.length + 1,
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
    _documentNotes.add(note);
    return note;
  }

  @override
  Future<List<DocumentNote>> fetchDocumentNotes(LibraryItem item) async {
    return _documentNotes
        .where((note) => note.documentId == item.id)
        .toList(growable: false)
      ..sort((a, b) {
        final pageComparison = a.pageNumber.compareTo(b.pageNumber);
        if (pageComparison != 0) {
          return pageComparison;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  @override
  Future<void> removeDocumentNote(DocumentNote note) async {
    _documentNotes.removeWhere((candidate) => candidate.id == note.id);
  }

  @override
  Future<LibraryItem?> updateReadingProgress({
    required LibraryItem item,
    required double progress,
    DateTime? lastAccessedAt,
  }) async {
    final normalizedProgress = progress.clamp(0.0, 1.0);
    final accessedAt = lastAccessedAt ?? DateTime.now();
    final index = _items.indexWhere((candidate) {
      if (candidate.id != null && item.id != null) {
        return candidate.id == item.id;
      }

      return candidate.filePath == item.filePath &&
          candidate.title == item.title &&
          candidate.fileName == item.fileName;
    });
    if (index < 0) {
      return null;
    }

    final updatedItem = LibraryItem(
      id: _items[index].id,
      title: _items[index].title,
      fileName: _items[index].fileName,
      filePath: _items[index].filePath,
      format: _items[index].format,
      progress: normalizedProgress,
      fileSizeBytes: _items[index].fileSizeBytes,
      importedAt: _items[index].importedAt,
      lastAccessedAt: accessedAt,
    );
    _items[index] = updatedItem;
    return updatedItem;
  }

  @override
  Future<void> removeDocument(LibraryItem item) async {
    _items.removeWhere((candidate) {
      if (candidate.id != null && item.id != null) {
        return candidate.id == item.id;
      }

      return candidate.filePath == item.filePath &&
          candidate.title == item.title &&
          candidate.fileName == item.fileName;
    });
  }
}
