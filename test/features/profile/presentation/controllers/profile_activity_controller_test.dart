import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/library/data/library_repository.dart';
import 'package:lectio/features/library/domain/library_item.dart';
import 'package:lectio/features/notebook/data/notebook_export_service.dart';
import 'package:lectio/features/notebook/domain/document_note.dart';
import 'package:lectio/features/profile/presentation/controllers/profile_activity_controller.dart';
import 'package:lectio/features/profile/presentation/widgets/profile_bookmark_activity.dart';
import 'package:lectio/features/reader/domain/document_bookmark.dart';

class _FakeLibraryRepository implements LibraryRepository {
  List<BookmarkSnapshotEntry> bookmarkSnapshot = const [];
  List<DocumentNotebookSnapshotEntry> notebookSnapshot = const [];
  List<DocumentNote> documentNotes = const [];

  @override
  Future<List<BookmarkSnapshotEntry>> fetchBookmarkSnapshot() async {
    return bookmarkSnapshot;
  }

  @override
  Future<List<DocumentNotebookSnapshotEntry>> fetchNotebookSnapshot() async {
    return notebookSnapshot;
  }

  @override
  Future<List<DocumentNote>> fetchDocumentNotes(LibraryItem item) async {
    return documentNotes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotebookExportService extends NotebookExportService {
  LibraryItem? sharedPdfItem;
  LibraryItem? sharedDocxItem;
  List<DocumentNote>? sharedPdfNotes;
  List<DocumentNote>? sharedDocxNotes;

  @override
  Future<void> shareNotebookPdf({
    required LibraryItem item,
    required List<DocumentNote> notes,
  }) async {
    sharedPdfItem = item;
    sharedPdfNotes = notes;
  }

  @override
  Future<void> shareNotebookDocx({
    required LibraryItem item,
    required List<DocumentNote> notes,
  }) async {
    sharedDocxItem = item;
    sharedDocxNotes = notes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clipboardChannel = SystemChannels.platform;
  String? clipboardText;

  setUp(() async {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, (call) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments;
        if (arguments is Map) {
          clipboardText = arguments['text'] as String?;
        }
        return true;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, null);
  });

  group('ProfileActivityController', () {
    late _FakeLibraryRepository repository;
    late _FakeNotebookExportService exportService;
    late ProfileActivityController controller;

    const physics =
        LibraryItem(id: 1, title: 'Physics', fileName: 'physics.pdf');
    const chemistry =
        LibraryItem(id: 2, title: 'Chemistry', fileName: 'chemistry.pdf');

    DocumentBookmark bookmark({
      int? id,
      required int page,
      int? sentenceIndex,
      String note = '',
    }) {
      return DocumentBookmark(
        id: id,
        documentId: 1,
        pageNumber: page,
        sentenceIndex: sentenceIndex,
        note: note,
        createdAt: DateTime(2024, 1, 1),
      );
    }

    DocumentNote note({
      int? id,
      required int page,
      String title = 'Note',
    }) {
      return DocumentNote(
        id: id,
        documentId: 1,
        kind: DocumentNoteKind.summary,
        pageNumber: page,
        title: title,
        body: 'Body',
        createdAt: DateTime(2024, 1, 1),
      );
    }

    setUp(() {
      repository = _FakeLibraryRepository();
      exportService = _FakeNotebookExportService();
      controller = ProfileActivityController(
        repository: repository,
        notebookExportService: exportService,
      );
    });

    test('load populates snapshots and clears loading state', () async {
      repository
        ..bookmarkSnapshot = [
          BookmarkSnapshotEntry(
              item: physics, bookmark: bookmark(id: 1, page: 2)),
        ]
        ..notebookSnapshot = [
          DocumentNotebookSnapshotEntry(
              item: chemistry, notes: [note(id: 1, page: 3)]),
        ];

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.bookmarks, hasLength(1));
      expect(controller.notebooks, hasLength(1));
    });

    test('setFilter narrows visible bookmarks', () async {
      repository.bookmarkSnapshot = [
        BookmarkSnapshotEntry(
          item: physics,
          bookmark: bookmark(id: 1, page: 2, note: 'Review later'),
        ),
        BookmarkSnapshotEntry(
          item: chemistry,
          bookmark: bookmark(id: 2, page: 4, sentenceIndex: 1),
        ),
      ];

      await controller.load();
      controller.setFilter(ActivityBookmarkFilter.notes);

      expect(controller.visibleBookmarks, hasLength(1));
      expect(controller.visibleBookmarks.single.item.title, 'Physics');
    });

    test('toggleNotebookSelectionMode selects all and clears on cancel',
        () async {
      repository.notebookSnapshot = [
        DocumentNotebookSnapshotEntry(
            item: physics, notes: [note(id: 1, page: 1)]),
        DocumentNotebookSnapshotEntry(
            item: chemistry, notes: [note(id: 2, page: 2)]),
      ];

      await controller.load();
      controller.toggleNotebookSelectionMode();

      expect(controller.isNotebookSelectionMode, isTrue);
      expect(controller.selectedNotebookKeys, hasLength(2));

      controller.toggleNotebookSelectionMode();

      expect(controller.isNotebookSelectionMode, isFalse);
      expect(controller.selectedNotebookKeys, isEmpty);
    });

    test('copyBookmarksExport writes markdown to clipboard and returns message',
        () async {
      repository.bookmarkSnapshot = [
        BookmarkSnapshotEntry(
            item: physics, bookmark: bookmark(id: 1, page: 2)),
      ];

      await controller.load();
      final message = await controller.copyBookmarksExport();

      expect(message, 'Copied 1 bookmark to clipboard.');
      expect(clipboardText, contains('# Lectio Bookmarks'));
      expect(clipboardText, contains('Physics'));
    });

    test(
        'exportDocumentNotebook returns empty-notes message when document has no notes',
        () async {
      repository.documentNotes = const [];

      final message = await controller.exportDocumentNotebook(
          physics, NotebookExportFormat.pdf);

      expect(message, 'Physics has no notebook notes yet.');
      expect(controller.exportingNotebookDocumentId, isNull);
    });

    test('exportSelectedNotebooks exports combined notes for selected entries',
        () async {
      repository.notebookSnapshot = [
        DocumentNotebookSnapshotEntry(
            item: physics, notes: [note(id: 1, page: 1)]),
        DocumentNotebookSnapshotEntry(
            item: chemistry, notes: [note(id: 2, page: 2)]),
      ];

      await controller.load();
      controller.toggleNotebookSelectionMode();

      final message =
          await controller.exportSelectedNotebooks(NotebookExportFormat.docx);

      expect(message, isNull);
      expect(exportService.sharedDocxItem?.title, 'Selected Lectio Notebooks');
      expect(exportService.sharedDocxNotes, hasLength(2));
      expect(controller.isExportingSelectedNotebooks, isFalse);
    });
  });
}
