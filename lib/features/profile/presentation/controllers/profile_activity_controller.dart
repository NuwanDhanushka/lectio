import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../../notebook/data/notebook_export_service.dart';
import '../widgets/profile_bookmark_activity.dart';

class ProfileActivityController extends ChangeNotifier {
  ProfileActivityController({
    required LibraryRepository repository,
    NotebookExportService notebookExportService = const NotebookExportService(),
  })  : _repository = repository,
        _notebookExportService = notebookExportService;

  final LibraryRepository _repository;
  final NotebookExportService _notebookExportService;

  List<BookmarkSnapshotEntry> _bookmarks = const [];
  List<DocumentNotebookSnapshotEntry> _notebooks = const [];
  final Set<int?> _collapsedDocumentIds = {};
  final Set<int> _selectedNotebookKeys = {};
  ActivityBookmarkFilter _filter = ActivityBookmarkFilter.all;
  bool _isLoading = true;
  bool _isNotebookSelectionMode = false;
  bool _isExportingSelectedNotebooks = false;
  int? _exportingNotebookDocumentId;

  List<BookmarkSnapshotEntry> get bookmarks => _bookmarks;
  List<DocumentNotebookSnapshotEntry> get notebooks => _notebooks;
  Set<int?> get collapsedDocumentIds => _collapsedDocumentIds;
  Set<int> get selectedNotebookKeys => _selectedNotebookKeys;
  ActivityBookmarkFilter get filter => _filter;
  bool get isLoading => _isLoading;
  bool get isNotebookSelectionMode => _isNotebookSelectionMode;
  bool get isExportingSelectedNotebooks => _isExportingSelectedNotebooks;
  int? get exportingNotebookDocumentId => _exportingNotebookDocumentId;

  List<BookmarkSnapshotEntry> get visibleBookmarks {
    return _bookmarks.where((entry) {
      final bookmark = entry.bookmark;
      return switch (_filter) {
        ActivityBookmarkFilter.all => true,
        ActivityBookmarkFilter.notes => bookmark.note.isNotEmpty,
        ActivityBookmarkFilter.sentences => bookmark.sentenceIndex != null,
        ActivityBookmarkFilter.pages => bookmark.sentenceIndex == null,
      };
    }).toList(growable: false);
  }

  List<BookmarkDocumentGroup> get groupedBookmarks {
    return groupBookmarksByDocument(visibleBookmarks);
  }

  Future<void> load() async {
    final bookmarks = await _repository.fetchBookmarkSnapshot();
    final notebooks = await _repository.fetchNotebookSnapshot();
    _bookmarks = bookmarks;
    _notebooks = notebooks;
    _isLoading = false;
    notifyListeners();
  }

  void setFilter(ActivityBookmarkFilter filter) {
    if (_filter == filter) {
      return;
    }
    _filter = filter;
    notifyListeners();
  }

  void toggleCollapsedDocument(int? documentId) {
    if (!_collapsedDocumentIds.add(documentId)) {
      _collapsedDocumentIds.remove(documentId);
    }
    notifyListeners();
  }

  void toggleNotebookSelectionMode() {
    _isNotebookSelectionMode = !_isNotebookSelectionMode;
    if (_isNotebookSelectionMode) {
      _selectedNotebookKeys
        ..clear()
        ..addAll(_notebooks.map((entry) => notebookSelectionKey(entry.item)));
    } else {
      _selectedNotebookKeys.clear();
    }
    notifyListeners();
  }

  void toggleSelectAllNotebooks() {
    if (_selectedNotebookKeys.length == _notebooks.length) {
      _selectedNotebookKeys.clear();
    } else {
      _selectedNotebookKeys
        ..clear()
        ..addAll(_notebooks.map((entry) => notebookSelectionKey(entry.item)));
    }
    notifyListeners();
  }

  void toggleNotebookSelection(DocumentNotebookSnapshotEntry entry) {
    final key = notebookSelectionKey(entry.item);
    if (!_selectedNotebookKeys.add(key)) {
      _selectedNotebookKeys.remove(key);
    }
    notifyListeners();
  }

  Future<String?> copyBookmarksExport() async {
    final entries = visibleBookmarks;
    if (entries.isEmpty) {
      return null;
    }
    await Clipboard.setData(
        ClipboardData(text: exportBookmarksAsMarkdown(entries)));
    return 'Copied ${entries.length} bookmark${entries.length == 1 ? '' : 's'} to clipboard.';
  }

  Future<String?> copyDocumentBookmarksExport(
      BookmarkDocumentGroup group) async {
    if (group.entries.isEmpty) {
      return null;
    }
    await Clipboard.setData(
      ClipboardData(text: exportBookmarksAsMarkdown(group.entries)),
    );
    return 'Copied ${group.item.title} bookmarks to clipboard.';
  }

  Future<String?> exportDocumentNotebook(
    LibraryItem item,
    NotebookExportFormat format,
  ) async {
    if (_exportingNotebookDocumentId == item.id) {
      return null;
    }

    _exportingNotebookDocumentId = item.id;
    notifyListeners();

    try {
      final notes = await _repository.fetchDocumentNotes(item);
      if (notes.isEmpty) {
        return '${item.title} has no notebook notes yet.';
      }

      switch (format) {
        case NotebookExportFormat.pdf:
          await _notebookExportService.shareNotebookPdf(
              item: item, notes: notes);
        case NotebookExportFormat.docx:
          await _notebookExportService.shareNotebookDocx(
            item: item,
            notes: notes,
          );
      }
      return null;
    } catch (_) {
      return 'Could not export notebook.';
    } finally {
      _exportingNotebookDocumentId = null;
      notifyListeners();
    }
  }

  Future<String?> exportSelectedNotebooks(NotebookExportFormat format) async {
    if (_selectedNotebookKeys.isEmpty || _isExportingSelectedNotebooks) {
      return null;
    }

    final selectedNotebooks = _notebooks
        .where(
          (entry) => _selectedNotebookKeys.contains(
            notebookSelectionKey(entry.item),
          ),
        )
        .toList(growable: false);
    if (selectedNotebooks.isEmpty) {
      return null;
    }

    _isExportingSelectedNotebooks = true;
    notifyListeners();

    try {
      final exportItem = LibraryItem(
        title: selectedNotebooks.length == 1
            ? selectedNotebooks.single.item.title
            : 'Selected Lectio Notebooks',
        fileName: 'Lectio notebooks',
        format: 'DOC',
      );
      final notes = notesForSelectedNotebookExport(selectedNotebooks);

      switch (format) {
        case NotebookExportFormat.pdf:
          await _notebookExportService.shareNotebookPdf(
            item: exportItem,
            notes: notes,
          );
        case NotebookExportFormat.docx:
          await _notebookExportService.shareNotebookDocx(
            item: exportItem,
            notes: notes,
          );
      }
      return null;
    } catch (_) {
      return 'Could not export selected notebooks.';
    } finally {
      _isExportingSelectedNotebooks = false;
      notifyListeners();
    }
  }
}
