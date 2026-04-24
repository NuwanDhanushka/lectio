import 'package:flutter/material.dart';

import '../../../library/data/library_repository.dart';
import '../../../library/domain/library_item.dart';
import '../../domain/document_bookmark.dart';
import '../widgets/bookmark_ui.dart';
import 'reader_bookmark_coordinator.dart';

typedef ReaderBookmarkListSetter = void Function(
    List<DocumentBookmark> bookmarks);
typedef ReaderMessageCallback = void Function(String message);

class ReaderBookmarkFlowCoordinator {
  const ReaderBookmarkFlowCoordinator();

  Future<BookmarkDetails?> promptForBookmarkDetails({
    required BuildContext context,
    required int pageNumber,
    String initialLabel = '',
    String initialNote = '',
    String sentenceText = '',
  }) {
    return showDialog<BookmarkDetails>(
      context: context,
      builder: (context) {
        return BookmarkDetailsDialog(
          pageNumber: pageNumber,
          initialLabel: initialLabel,
          initialNote: initialNote,
          sentenceText: sentenceText,
        );
      },
    );
  }

  Future<void> toggleCurrentPageBookmark({
    required BuildContext context,
    required LibraryItem? item,
    required LibraryRepository? repository,
    required bool viewerReady,
    required int currentPage,
    required int? sentenceIndex,
    required String sentenceText,
    required List<DocumentBookmark> currentBookmarks,
    required ReaderBookmarkCoordinator bookmarkCoordinator,
    required Future<void> Function() ensureSpeechSegmentsForCurrentPage,
    required bool Function() isMounted,
    required ReaderBookmarkListSetter updateBookmarks,
    required ReaderMessageCallback showMessage,
  }) async {
    if (item == null || repository == null || !viewerReady) {
      return;
    }

    await ensureSpeechSegmentsForCurrentPage();
    if (!isMounted() || !context.mounted) {
      return;
    }

    final existing = currentBookmarks.any(
      (bookmark) =>
          bookmark.pageNumber == currentPage &&
          bookmark.sentenceIndex == sentenceIndex,
    );

    if (existing) {
      final updatedBookmarks =
          await bookmarkCoordinator.removeBookmarksForContext(
        repository: repository,
        currentBookmarks: currentBookmarks,
        pageNumber: currentPage,
        sentenceIndex: sentenceIndex,
      );
      if (!isMounted()) {
        return;
      }
      updateBookmarks(updatedBookmarks);
      showMessage('Removed bookmark for page $currentPage.');
      return;
    }

    final details = await promptForBookmarkDetails(
      context: context,
      pageNumber: currentPage,
      sentenceText: sentenceText,
    );
    if (!isMounted() || details == null) {
      return;
    }

    final updatedBookmarks = await bookmarkCoordinator.addBookmark(
      item: item,
      repository: repository,
      currentBookmarks: currentBookmarks,
      pageNumber: currentPage,
      sentenceIndex: sentenceIndex,
      sentenceText: sentenceText,
      details: details,
    );
    if (!isMounted()) {
      return;
    }

    updateBookmarks(updatedBookmarks);
    showMessage('Saved bookmark for page $currentPage.');
  }

  Future<void> editBookmark({
    required BuildContext context,
    required LibraryRepository? repository,
    required List<DocumentBookmark> currentBookmarks,
    required DocumentBookmark bookmark,
    required ReaderBookmarkCoordinator bookmarkCoordinator,
    required bool Function() isMounted,
    required ReaderBookmarkListSetter updateBookmarks,
    required ReaderMessageCallback showMessage,
  }) async {
    if (repository == null) {
      return;
    }

    final details = await promptForBookmarkDetails(
      context: context,
      pageNumber: bookmark.pageNumber,
      initialLabel: bookmark.label,
      initialNote: bookmark.note,
      sentenceText: bookmark.sentenceText,
    );
    if (!isMounted() || details == null) {
      return;
    }

    final updatedBookmarks = await bookmarkCoordinator.editBookmark(
      repository: repository,
      currentBookmarks: currentBookmarks,
      bookmark: bookmark,
      details: details,
    );
    if (!isMounted()) {
      return;
    }

    updateBookmarks(updatedBookmarks);
    showMessage('Updated bookmark for page ${bookmark.pageNumber}.');
  }
}
