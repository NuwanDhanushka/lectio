import 'package:path/path.dart' as p;

import '../../notebook/domain/document_note.dart';
import '../../reader/domain/document_bookmark.dart';
import '../../reader/domain/page_summary.dart';
import '../domain/library_item.dart';

export 'in_memory_library_repository.dart';
export 'sqlite_library_repository.dart';

const String _libraryFolderName = 'library';

abstract class LibraryRepository {
  Future<LibrarySnapshot> fetchSnapshot();
  Future<LibraryItem> addDocument(LibraryItem item);
  Future<List<BookmarkSnapshotEntry>> fetchBookmarkSnapshot();
  Future<List<DocumentNotebookSnapshotEntry>> fetchNotebookSnapshot();
  Future<List<DocumentBookmark>> fetchBookmarks(LibraryItem item);
  Future<DocumentBookmark?> addBookmark({
    required LibraryItem item,
    required int pageNumber,
    String label = '',
    int? sentenceIndex,
    String sentenceText = '',
    String note = '',
  });
  Future<DocumentBookmark?> updateBookmark({
    required DocumentBookmark bookmark,
    required String label,
    required String note,
  });
  Future<void> removeBookmark(DocumentBookmark bookmark);
  Future<PageSummary?> fetchPageSummary({
    required LibraryItem item,
    required int pageNumber,
  });
  Future<PageSummary?> savePageSummary({
    required LibraryItem item,
    required int pageNumber,
    required String summary,
  });
  Future<void> removePageSummary({
    required LibraryItem item,
    required int pageNumber,
  });
  Future<DocumentNote?> addDocumentNote({
    required LibraryItem item,
    required DocumentNoteKind kind,
    required int pageNumber,
    int? sentenceIndex,
    String sentenceText = '',
    String outlineTitle = '',
    String title = '',
    required String body,
  });
  Future<List<DocumentNote>> fetchDocumentNotes(LibraryItem item);
  Future<void> removeDocumentNote(DocumentNote note);
  Future<LibraryItem?> updateReadingProgress({
    required LibraryItem item,
    required double progress,
    DateTime? lastAccessedAt,
  });
  Future<void> removeDocument(LibraryItem item);
}

class LibrarySnapshot {
  const LibrarySnapshot({
    required this.recentItems,
    required this.totalItems,
    required this.totalBytes,
    required this.lastSyncedAt,
  });

  const LibrarySnapshot.empty()
      : recentItems = const [],
        totalItems = 0,
        totalBytes = 0,
        lastSyncedAt = null;

  final List<LibraryItem> recentItems;
  final int totalItems;
  final int totalBytes;
  final DateTime? lastSyncedAt;
}

class BookmarkSnapshotEntry {
  const BookmarkSnapshotEntry({
    required this.item,
    required this.bookmark,
  });

  final LibraryItem item;
  final DocumentBookmark bookmark;
}

class DocumentNotebookSnapshotEntry {
  const DocumentNotebookSnapshotEntry({
    required this.item,
    required this.notes,
  });

  final LibraryItem item;
  final List<DocumentNote> notes;
}

String canonicalizeStoredLibraryPath(String storedPath) {
  if (storedPath.isEmpty) {
    return storedPath;
  }

  if (!p.isAbsolute(storedPath)) {
    return p.normalize(storedPath);
  }

  final documentsMarker = '${p.separator}Documents${p.separator}';
  final documentsIndex = storedPath.lastIndexOf(documentsMarker);
  if (documentsIndex >= 0) {
    return p.normalize(
      storedPath.substring(documentsIndex + documentsMarker.length),
    );
  }

  final libraryMarker = '${p.separator}$_libraryFolderName${p.separator}';
  final libraryIndex = storedPath.lastIndexOf(libraryMarker);
  if (libraryIndex >= 0) {
    return p.normalize(storedPath.substring(libraryIndex + 1));
  }

  return storedPath;
}

String resolveStoredLibraryPath({
  required String storedPath,
  required String documentsPath,
}) {
  if (storedPath.isEmpty) {
    return storedPath;
  }

  if (p.isAbsolute(storedPath)) {
    return p.normalize(storedPath);
  }

  return p.normalize(p.join(documentsPath, storedPath));
}
