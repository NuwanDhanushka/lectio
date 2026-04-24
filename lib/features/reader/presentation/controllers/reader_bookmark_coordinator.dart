import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../domain/document_bookmark.dart';
import '../../domain/reader_page_analysis.dart';
import '../widgets/bookmark_ui.dart';

class ReaderBookmarkCoordinator {
  const ReaderBookmarkCoordinator();

  Future<List<DocumentBookmark>> loadBookmarks({
    required LibraryItem? item,
    required LibraryRepository? repository,
  }) async {
    if (item == null || repository == null) {
      return const [];
    }

    return repository.fetchBookmarks(item);
  }

  Future<List<DocumentBookmark>> addBookmark({
    required LibraryItem? item,
    required LibraryRepository? repository,
    required List<DocumentBookmark> currentBookmarks,
    required int pageNumber,
    required int? sentenceIndex,
    required String sentenceText,
    required BookmarkDetails details,
  }) async {
    if (item == null || repository == null) {
      return currentBookmarks;
    }

    final bookmark = await repository.addBookmark(
      item: item,
      pageNumber: pageNumber,
      sentenceIndex: sentenceIndex,
      sentenceText: sentenceText,
      label: details.label,
      note: details.note,
    );
    if (bookmark == null) {
      return currentBookmarks;
    }

    return [...currentBookmarks, bookmark]..sort(compareBookmarks);
  }

  Future<List<DocumentBookmark>> removeBookmarksForContext({
    required LibraryRepository? repository,
    required List<DocumentBookmark> currentBookmarks,
    required int pageNumber,
    required int? sentenceIndex,
  }) async {
    if (repository == null) {
      return currentBookmarks;
    }

    final existing = currentBookmarks.where(
      (bookmark) =>
          bookmark.pageNumber == pageNumber &&
          bookmark.sentenceIndex == sentenceIndex,
    );
    if (existing.isEmpty) {
      return currentBookmarks;
    }

    for (final bookmark in existing) {
      await repository.removeBookmark(bookmark);
    }

    return currentBookmarks
        .where((bookmark) =>
            bookmark.pageNumber != pageNumber ||
            bookmark.sentenceIndex != sentenceIndex)
        .toList(growable: false);
  }

  Future<List<DocumentBookmark>> removeBookmark({
    required LibraryRepository? repository,
    required List<DocumentBookmark> currentBookmarks,
    required DocumentBookmark bookmark,
  }) async {
    if (repository == null) {
      return currentBookmarks;
    }

    await repository.removeBookmark(bookmark);
    return currentBookmarks
        .where((candidate) => candidate.id != bookmark.id)
        .toList(growable: false);
  }

  Future<List<DocumentBookmark>> editBookmark({
    required LibraryRepository? repository,
    required List<DocumentBookmark> currentBookmarks,
    required DocumentBookmark bookmark,
    required BookmarkDetails details,
  }) async {
    if (repository == null) {
      return currentBookmarks;
    }

    final updated = await repository.updateBookmark(
      bookmark: bookmark,
      label: details.label,
      note: details.note,
    );
    if (updated == null) {
      return currentBookmarks;
    }

    return currentBookmarks
        .map((candidate) => candidate.id == updated.id ? updated : candidate)
        .toList(growable: false);
  }
}
