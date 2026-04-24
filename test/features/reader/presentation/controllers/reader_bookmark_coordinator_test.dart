import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/library/data/library_repository.dart';
import 'package:lectio/features/library/domain/library_item.dart';
import 'package:lectio/features/reader/domain/document_bookmark.dart';
import 'package:lectio/features/reader/presentation/controllers/reader_bookmark_coordinator.dart';
import 'package:lectio/features/reader/presentation/widgets/bookmark_ui.dart';

class _FakeLibraryRepository implements LibraryRepository {
  List<DocumentBookmark> fetchedBookmarks = const [];
  DocumentBookmark? bookmarkToAdd;
  DocumentBookmark? updatedBookmark;
  final removedBookmarks = <DocumentBookmark>[];

  @override
  Future<List<DocumentBookmark>> fetchBookmarks(LibraryItem item) async {
    return fetchedBookmarks;
  }

  @override
  Future<DocumentBookmark?> addBookmark({
    required LibraryItem item,
    required int pageNumber,
    int? sentenceIndex,
    String sentenceText = '',
    String label = '',
    String note = '',
  }) async {
    return bookmarkToAdd;
  }

  @override
  Future<void> removeBookmark(DocumentBookmark bookmark) async {
    removedBookmarks.add(bookmark);
  }

  @override
  Future<DocumentBookmark?> updateBookmark({
    required DocumentBookmark bookmark,
    required String label,
    required String note,
  }) async {
    return updatedBookmark;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ReaderBookmarkCoordinator', () {
    const coordinator = ReaderBookmarkCoordinator();
    const item = LibraryItem(title: 'Physics');

    DocumentBookmark bookmark({
      int? id,
      required int page,
      int? sentence,
      String label = '',
    }) {
      return DocumentBookmark(
        id: id,
        documentId: 1,
        pageNumber: page,
        sentenceIndex: sentence,
        label: label,
        createdAt: DateTime(2024, 1, 1),
      );
    }

    test('loadBookmarks returns fetched values', () async {
      final repository = _FakeLibraryRepository()
        ..fetchedBookmarks = [bookmark(id: 1, page: 2)];

      final result = await coordinator.loadBookmarks(
        item: item,
        repository: repository,
      );

      expect(result, hasLength(1));
      expect(result.first.pageNumber, 2);
    });

    test('addBookmark appends and sorts bookmarks', () async {
      final repository = _FakeLibraryRepository()
        ..bookmarkToAdd = bookmark(id: 2, page: 1);

      final result = await coordinator.addBookmark(
        item: item,
        repository: repository,
        currentBookmarks: [bookmark(id: 1, page: 3)],
        pageNumber: 1,
        sentenceIndex: null,
        sentenceText: 'Intro',
        details: const BookmarkDetails(label: 'Start', note: 'Important'),
      );

      expect(result.map((bookmark) => bookmark.pageNumber), [1, 3]);
    });

    test('removeBookmarksForContext removes all matching entries', () async {
      final repository = _FakeLibraryRepository();
      final first = bookmark(id: 1, page: 4, sentence: 1);
      final second = bookmark(id: 2, page: 4, sentence: 1);
      final third = bookmark(id: 3, page: 5, sentence: 1);

      final result = await coordinator.removeBookmarksForContext(
        repository: repository,
        currentBookmarks: [first, second, third],
        pageNumber: 4,
        sentenceIndex: 1,
      );

      expect(repository.removedBookmarks, [first, second]);
      expect(result, [third]);
    });

    test('removeBookmark removes single bookmark by id', () async {
      final repository = _FakeLibraryRepository();
      final first = bookmark(id: 1, page: 2);
      final second = bookmark(id: 2, page: 3);

      final result = await coordinator.removeBookmark(
        repository: repository,
        currentBookmarks: [first, second],
        bookmark: first,
      );

      expect(repository.removedBookmarks, [first]);
      expect(result, [second]);
    });

    test('editBookmark replaces updated bookmark in list', () async {
      final original = bookmark(id: 1, page: 2, label: 'Old');
      final replacement = bookmark(id: 1, page: 2, label: 'New');
      final repository = _FakeLibraryRepository()..updatedBookmark = replacement;

      final result = await coordinator.editBookmark(
        repository: repository,
        currentBookmarks: [original, bookmark(id: 2, page: 3)],
        bookmark: original,
        details: const BookmarkDetails(label: 'New', note: 'Updated'),
      );

      expect(result.first.label, 'New');
      expect(result.last.pageNumber, 3);
    });
  });
}
